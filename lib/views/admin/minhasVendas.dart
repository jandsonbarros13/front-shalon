import 'dart:convert';
import 'dart:html' as html; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:acaiteria_front/features/auth/services/vendas_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:showcaseview/showcaseview.dart';

class MinhasVendas extends StatefulWidget {
  const MinhasVendas({super.key});

  @override
  State<MinhasVendas> createState() => _MinhasVendasState();
}

class _MinhasVendasState extends State<MinhasVendas> {
  final _vendasService = VendasService();
  final TextEditingController _buscaController = TextEditingController();
  
  List<dynamic> _vendas = [];
  List<dynamic> _vendasFiltradas = [];
  
  bool _loading = true;
  int _paginaAtual = 1;
  bool _temMais = true;
  bool _isDarkMode = true; 

  final List<String> _statusValidos = [
    'Finalizado', 
    'Cancelado'
  ];

  final FlutterTts _flutterTts = FlutterTts();
  final GlobalKey _keyBusca = GlobalKey();
  final GlobalKey _keyLista = GlobalKey();

  final List<String> _textosMascote = [
    "Bem-vindo ao seu Histórico de Vendas! Aqui em cima, você pode digitar o número do cupom ou o nome do cliente para achar uma venda rapidamente.",
    "Nesta lista ficam as vendas de balcão. Clique na venda para ver os detalhes e nos três pontinhos para enviar via WhatsApp, E-mail, Reimprimir ou Cancelar!"
  ];

  bool get isDark => _isDarkMode;
  Color get accentColor => isDark ? const Color(0xFFE040FB) : const Color(0xFF4A0E4E);
  Color get bgColor => isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF4F6F8);
  Color get cardColor => isDark ? const Color(0xFF27293D) : Colors.white;
  Color get textColor => isDark ? Colors.white : Colors.black87;
  Color get textSecColor => isDark ? Colors.white54 : Colors.grey[600]!;

  @override
  void initState() {
    super.initState();
    _flutterTts.setLanguage("pt-BR");
    _carregarVendas();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _carregarVendas({bool carregarMais = false}) async {
    if (carregarMais) {
      _paginaAtual++;
    } else {
      _paginaAtual = 1;
      setState(() => _loading = true);
    }

    try {
      final resultado = await _vendasService.listarVendas(_paginaAtual);
      final listagem = resultado['vendas'] as List? ?? [];

      setState(() {
        if (carregarMais) {
          final listaCompleta = [..._vendas, ...listagem];
          listaCompleta.sort((a, b) => (b['id'] ?? 0).compareTo(a['id'] ?? 0));
          _vendas = listaCompleta;
        } else {
          listagem.sort((a, b) => (b['id'] ?? 0).compareTo(a['id'] ?? 0));
          _vendas = listagem;
        }
        
        _filtrarVendas(_buscaController.text);
        _temMais = listagem.length >= 10;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filtrarVendas(String query) {
    if (query.isEmpty) {
      setState(() {
        _vendasFiltradas = List.from(_vendas);
      });
      return;
    }

    final q = query.toLowerCase().trim();
    setState(() {
      _vendasFiltradas = _vendas.where((v) {
        final nome = (v['cliente_nome'] ?? '').toString().toLowerCase();
        final id = (v['id'] ?? '').toString();
        return nome.contains(q) || id.contains(q);
      }).toList();
    });
  }

  Color _getCorStatus(String status) {
    switch (status.toLowerCase()) {
      case 'finalizado': return Colors.greenAccent[700] ?? Colors.green;
      case 'cancelado': return Colors.redAccent;
      default: return Colors.grey;
    }
  }

  Future<void> _alterarStatusVenda(int id, String novoStatus) async {
    setState(() {
      final indexOriginal = _vendas.indexWhere((v) => v['id'] == id);
      if (indexOriginal >= 0) _vendas[indexOriginal]['status'] = novoStatus;
      _filtrarVendas(_buscaController.text);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Venda #$id alterada para: $novoStatus!', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: novoStatus == 'Cancelado' ? Colors.redAccent : Colors.green,
        duration: const Duration(seconds: 2),
      )
    );

    try {
      await _vendasService.atualizarStatus(id, novoStatus);
    } catch (e) {
      debugPrint("Erro ao atualizar status no banco: $e");
    }
  }

  void _dialogWhatsApp(Map<String, dynamic> v) {
    final telefoneController = TextEditingController(text: v['cliente_telefone'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Enviar via WhatsApp', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: telefoneController,
          keyboardType: TextInputType.phone,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            labelText: 'Número com DDD (Ex: 85999999999)',
            labelStyle: TextStyle(color: textSecColor),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!), borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () {
              Navigator.pop(ctx);
              _enviarWhatsApp(telefoneController.text, v);
            },
            child: const Text('Enviar Msg', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _enviarWhatsApp(String telefone, Map<String, dynamic> v) {
    String telLimpo = telefone.replaceAll(RegExp(r'\D'), '');
    if (telLimpo.isEmpty) return;
    if (!telLimpo.startsWith('55') && telLimpo.length >= 10) telLimpo = '55$telLimpo';
    
    final total = double.tryParse((v['valor_total'] ?? 0).toString()) ?? 0.0;
    final msg = 'Olá! Agradecemos sua compra na *Açaiteria Shalom*.\n\nSeu pedido *#${v['id']}* no valor de *R\$ ${total.toStringAsFixed(2).replaceAll('.', ',')}* foi finalizado com sucesso! 🍇\n\nVolte sempre!';
    
    final url = 'https://api.whatsapp.com/send?phone=$telLimpo&text=${Uri.encodeComponent(msg)}';
    html.window.open(url, '_blank');
  }

  void _dialogEmail(Map<String, dynamic> v) {
    final emailController = TextEditingController(text: v['cliente_email'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Enviar via E-mail', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            labelText: 'Endereço de E-mail do Cliente',
            labelStyle: TextStyle(color: textSecColor),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!), borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () {
              Navigator.pop(ctx);
              _enviarEmail(emailController.text, v);
            },
            child: const Text('Enviar E-mail', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _enviarEmail(String email, Map<String, dynamic> v) {
    if (email.trim().isEmpty) return;
    
    final total = double.tryParse((v['valor_total'] ?? 0).toString()) ?? 0.0;
    final subject = 'Comprovante de Compra - Açaiteria Shalom #${v['id']}';
    final body = 'Olá!\n\nAgradecemos sua compra na Açaiteria Shalom.\nSeu pedido #${v['id']} no valor de R\$ ${total.toStringAsFixed(2).replaceAll('.', ',')} foi registrado com sucesso.\n\nVolte sempre! 🍇';
    
    final url = 'mailto:$email?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}';
    html.window.open(url, '_blank');
  }

  void _confirmarCancelarVenda(int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancelar Venda', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
        content: Text('Tem certeza de que deseja cancelar a venda #$id? Esta ação irá alterar as métricas financeiras.', style: TextStyle(color: textColor)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Voltar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () {
              Navigator.pop(ctx);
              _alterarStatusVenda(id, 'Cancelado');
            },
            child: const Text('Sim, Cancelar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _formatarFormaPagamento(String? forma) {
    if (forma == null || forma.isEmpty) return 'Não Especificada';
    switch (forma.toLowerCase()) {
      case 'dinheiro': return '💵 Dinheiro';
      case 'credito': return '💳 Cartão de Crédito';
      case 'debito': return '💳 Cartão de Débito';
      case 'pix': return '📱 Pix';
      default: return forma;
    }
  }

  void _playAudioForStep(int? index) async {
    await _flutterTts.stop();
    await Future.delayed(const Duration(milliseconds: 300));
    if (index != null && index >= 0 && index < _textosMascote.length) {
      await _flutterTts.speak(_textosMascote[index]);
    }
  }

  Widget _buildTooltipMascote(BuildContext context, String texto, bool isLast) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 15, spreadRadius: 3)],
          border: Border.all(color: accentColor, width: 3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(color: accentColor.withOpacity(0.1), shape: BoxShape.circle),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/mascote_acenando.gif',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(Icons.record_voice_over, color: accentColor),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    texto,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor, height: 1.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () {
                    _flutterTts.stop();
                    ShowCaseWidget.of(context).dismiss();
                  },
                  icon: const Icon(Icons.cancel, size: 20, color: Colors.redAccent),
                  label: const Text('Parar Tour', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: () {
                    _flutterTts.stop();
                    if (isLast) {
                      ShowCaseWidget.of(context).dismiss();
                    } else {
                      ShowCaseWidget.of(context).next();
                    }
                  },
                  icon: Icon(isLast ? Icons.check_circle : Icons.arrow_forward_ios, size: 16),
                  label: Text(isLast ? 'Concluir' : 'Próximo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  void _mostrarMensagemMascote(BuildContext showcaseContext) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 600),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: accentColor, width: 3),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      'assets/images/mascote_acenando.gif',
                      width: 100, height: 100, fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(Icons.sentiment_satisfied_alt, size: 80, color: accentColor),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E2C) : Colors.grey[100], borderRadius: BorderRadius.circular(16)),
                        child: Text(
                          "Olá! Sou o mascote da Açaiteria Shalom! 🍇\n\n"
                          "Esta é a tela de Minhas Vendas do PDV. Aqui você pode:\n"
                          "• Pesquisar vendas por ID ou nome\n"
                          "• Clicar nos três pontinhos para opções rápidas\n"
                          "• Enviar o recibo via WhatsApp ou E-mail\n\n"
                          "Quer que eu te mostre como funciona rapidinho?",
                          style: TextStyle(fontSize: 14, color: textSecColor, height: 1.5, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          ShowCaseWidget.of(showcaseContext).startShowCase([
                            _keyBusca,
                            _keyLista,
                          ]);
                        },
                        icon: const Icon(Icons.slideshow, size: 24),
                        label: const Text('Sim, Iniciar Tour', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      )
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textColor,
                          side: BorderSide(color: textSecColor, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Agora não', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      )
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _reimprimirCupomPdf(Map<String, dynamic> v) async {
    final id = v['id'] ?? 0;
    final pdf = pw.Document();
    final total = double.tryParse((v['valor_total'] ?? 0).toString()) ?? 0.0;
    final desconto = double.tryParse((v['desconto'] ?? 0).toString()) ?? 0.0;
    final data = (v['data'] ?? '').toString();
    final cliente = v['cliente_nome'] ?? 'Consumidor Final';
    final fone = v['cliente_telefone'] ?? '';
    final formaPgto = _formatarFormaPagamento(v['forma_pagamento'] ?? '');
    final itens = v['itens'] ?? v['items'] as List? ?? [];

    pw.ImageProvider? logoImage;
    try {
      final ByteData bytes = await rootBundle.load('assets/images/logo.jpg');
      logoImage = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {}

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(12),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: logoImage != null
                    ? pw.Container(width: 55, height: 55, child: pw.Image(logoImage))
                    : pw.SizedBox.shrink(),
              ),
              pw.SizedBox(height: 4),
              pw.Center(child: pw.Text('AÇAITERIA SHALOM', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))),
              pw.Center(child: pw.Text('REIMPRESSÃO DE CUPOM PDV', style: const pw.TextStyle(fontSize: 8, decoration: pw.TextDecoration.underline))),
              pw.SizedBox(height: 6),
              pw.Text('CUPOM DOC #$id', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.Text('DATA: $data', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('CLIENTE: $cliente', style: const pw.TextStyle(fontSize: 9)),
              if (fone.toString().isNotEmpty) pw.Text('FONE: $fone', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('PAGAMENTO: $formaPgto', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.Center(child: pw.Text('ITENS DO PEDIDO', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
              pw.SizedBox(height: 4),
              
              ...itens.map((item) {
                final nomeItem = item['nome'] ?? item['product_name'] ?? 'ITEM';
                final rawQtd = double.tryParse((item['quantidade'] ?? item['quantity'] ?? 1).toString()) ?? 1.0;
                final subtotalItem = double.tryParse((item['subtotal'] ?? item['price'] ?? 0).toString()) ?? 0.0;
                final unidade = (item['unidade'] ?? 'Unid').toString();
                
                String qtdTexto = unidade.toLowerCase() == 'kg'
                    ? '${(rawQtd).toStringAsFixed(3)} kg'
                    : '${rawQtd.toStringAsFixed(0)}x';

                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(nomeItem.toString().toUpperCase(), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(qtdTexto, style: const pw.TextStyle(fontSize: 9)),
                          pw.Text('R\$ ${subtotalItem.toStringAsFixed(2).replaceAll('.', ',')}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              if (desconto > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('DESCONTO:', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('-R\$ ${desconto.toStringAsFixed(2).replaceAll('.', ',')}', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL GERAL:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.Text('R\$ ${total.toStringAsFixed(2).replaceAll('.', ',')}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Center(child: pw.Text('Obrigado pela preferência!', style: const pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic))),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'Cupom_Reimpresso_$id.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      onStart: (index, key) => _playAudioForStep(index),
      onComplete: (index, key) => _flutterTts.stop(),
      onFinish: () => _flutterTts.stop(),
      builder: (showcaseContext) {
        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: cardColor,
            elevation: 0,
            leading: Builder(
              builder: (BuildContext context) {
                return IconButton(
                  icon: Icon(Icons.menu, color: textColor),
                  onPressed: () {
                    context.findRootAncestorStateOfType<ScaffoldState>()?.openDrawer();
                  },
                  tooltip: 'Abrir Menu Lateral',
                );
              },
            ),
            title: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: accentColor, width: 2),
                    image: const DecorationImage(image: AssetImage('assets/images/logo.jpg'), fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'HISTÓRICO DE VENDAS', 
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: textColor),
                tooltip: 'Alternar Tema',
                onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: accentColor.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.history, color: accentColor, size: 16),
                    const SizedBox(width: 8),
                    Text('${_vendasFiltradas.length} REGISTROS', style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ],
                ),
              )
            ],
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  Container(
                    width: double.infinity,
                    color: cardColor,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    child: Showcase.withWidget(
                      key: _keyBusca,
                      container: _buildTooltipMascote(showcaseContext, _textosMascote[0], false),
                      child: TextField(
                        controller: _buscaController,
                        onChanged: _filtrarVendas,
                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: 'Pesquise por ID da Venda ou Nome do Cliente...',
                          hintStyle: TextStyle(color: textSecColor),
                          prefixIcon: Icon(Icons.search, color: accentColor),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF1F3F4),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                        ),
                      ),
                    ),
                  ),

                  Expanded(
                    child: _loading
                      ? Center(child: CircularProgressIndicator(color: accentColor))
                      : _vendasFiltradas.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.history_toggle_off, size: 64, color: textSecColor.withOpacity(0.5)),
                                  const SizedBox(height: 16),
                                  Text(
                                    _buscaController.text.isNotEmpty 
                                      ? 'Nenhuma venda encontrada para esta pesquisa.'
                                      : 'Nenhuma venda registrada no PDV ainda.', 
                                    style: TextStyle(color: textSecColor, fontSize: 16, fontWeight: FontWeight.bold)
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: accentColor,
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                                    ),
                                    onPressed: () {
                                      _buscaController.clear();
                                      _carregarVendas();
                                    },
                                    icon: const Icon(Icons.refresh, color: Colors.white),
                                    label: const Text('Atualizar Histórico', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  )
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(24),
                              itemCount: _vendasFiltradas.length + (_temMais && _buscaController.text.isEmpty ? 1 : 0),
                              itemBuilder: (context, idx) {
                                if (idx == _vendasFiltradas.length) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                      child: TextButton.icon(
                                        onPressed: () => _carregarVendas(carregarMais: true),
                                        icon: Icon(Icons.add, color: accentColor),
                                        label: Text('Carregar Mais', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  );
                                }

                                final v = _vendasFiltradas[idx];
                                final id = v['id'] ?? 0;
                                final total = double.tryParse((v['valor_total'] ?? 0).toString()) ?? 0.0;
                                final data = (v['data'] ?? '').toString();
                                final cliente = v['cliente_nome'] ?? 'Consumidor Final';
                                final formaPgto = v['forma_pagamento'] ?? '';
                                final itens = v['itens'] ?? v['items'] as List? ?? [];
                                
                                final statusAtual = (v['status'] ?? 'Finalizado').toString();
                                
                                final statusFormatado = _statusValidos.firstWhere(
                                  (s) => s.toLowerCase() == statusAtual.toLowerCase(),
                                  orElse: () => 'Finalizado'
                                );
                                final corStatus = _getCorStatus(statusAtual);

                                Widget cardVenda = Card(
                                  color: cardColor,
                                  elevation: 4,
                                  shadowColor: Colors.black.withOpacity(0.1),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: isDark ? Colors.white10 : Colors.transparent),
                                  ),
                                  child: ExpansionTile(
                                    iconColor: accentColor,
                                    collapsedIconColor: textSecColor,
                                    leading: Container(
                                      width: 48, height: 48,
                                      decoration: BoxDecoration(color: const Color(0xFFFFD700).withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                                      child: const Icon(Icons.receipt_long, color: Color(0xFFFFD700)),
                                    ),
                                    title: Text('Venda #$id - $cliente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 6),
                                        Text('Data: $data | Pgto: ${_formatarFormaPagamento(formaPgto)}', style: TextStyle(color: textSecColor, fontSize: 13)),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: corStatus.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: corStatus.withOpacity(0.5))
                                          ),
                                          child: Text(
                                            statusFormatado.toUpperCase(),
                                            style: TextStyle(color: corStatus, fontWeight: FontWeight.w900, fontSize: 11),
                                          ),
                                        )
                                      ],
                                    ),
                                    trailing: Text('R\$ ${total.toStringAsFixed(2).replaceAll('.', ',')}', 
                                      style: TextStyle(fontWeight: FontWeight.w900, color: accentColor, fontSize: 20)),
                                    children: [
                                      Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
                                      Container(
                                        color: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFFAFAFA),
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                        child: Column(
                                          children: [
                                            ...itens.map((item) {
                                              final nomeItem = item['nome'] ?? item['product_name'] ?? 'ITEM';
                                              final rawQtd = double.tryParse((item['quantidade'] ?? item['quantity'] ?? 1).toString()) ?? 1.0;
                                              final subtotalItem = double.tryParse((item['subtotal'] ?? item['price'] ?? 0).toString()) ?? 0.0;
                                              final unidade = (item['unidade'] ?? 'Unid').toString();

                                              String qtdTexto = unidade.toLowerCase() == 'kg'
                                                  ? '${(rawQtd).toStringAsFixed(3)} kg'
                                                  : '${rawQtd.toStringAsFixed(0)}x';

                                              return Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 6),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text("$qtdTexto $nomeItem", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                                                    Text("R\$ ${subtotalItem.toStringAsFixed(2).replaceAll('.', ',')}", style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                                                  ],
                                                ),
                                              );
                                            }),
                                            const SizedBox(height: 16),
                                            Divider(color: isDark ? Colors.white10 : Colors.grey[300]),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text('Situação: ', style: TextStyle(fontWeight: FontWeight.bold, color: textSecColor)),
                                                    Container(
                                                      height: 40,
                                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                                      decoration: BoxDecoration(
                                                        color: cardColor,
                                                        border: Border.all(color: isDark ? Colors.white24 : Colors.grey[300]!),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: DropdownButtonHideUnderline(
                                                        child: DropdownButton<String>(
                                                          value: statusFormatado,
                                                          icon: Icon(Icons.arrow_drop_down, color: accentColor),
                                                          dropdownColor: cardColor,
                                                          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                                                          items: _statusValidos.map((s) {
                                                            return DropdownMenuItem(
                                                              value: s,
                                                              child: Text(s),
                                                            );
                                                          }).toList(),
                                                          onChanged: (novoValor) {
                                                            if (novoValor != null && novoValor != statusFormatado) {
                                                              _alterarStatusVenda(id, novoValor);
                                                            }
                                                          },
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: cardColor,
                                                    border: Border.all(color: isDark ? Colors.white24 : Colors.grey[300]!),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: PopupMenuButton<String>(
                                                    icon: Icon(Icons.more_vert, color: accentColor),
                                                    tooltip: 'Ações da Venda',
                                                    color: cardColor,
                                                    offset: const Offset(0, 40),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                    onSelected: (valor) {
                                                      if (valor == 'wpp') _dialogWhatsApp(v);
                                                      if (valor == 'email') _dialogEmail(v);
                                                      if (valor == 'print') _reimprimirCupomPdf(v);
                                                      if (valor == 'cancel') _confirmarCancelarVenda(id);
                                                    },
                                                    itemBuilder: (context) => [
                                                      PopupMenuItem(value: 'wpp', child: Row(children: [const Icon(Icons.message, color: Colors.green), const SizedBox(width: 12), Text('WhatsApp', style: TextStyle(color: textColor, fontWeight: FontWeight.bold))])),
                                                      PopupMenuItem(value: 'email', child: Row(children: [const Icon(Icons.email, color: Colors.blue), const SizedBox(width: 12), Text('E-mail', style: TextStyle(color: textColor, fontWeight: FontWeight.bold))])),
                                                      PopupMenuItem(value: 'print', child: Row(children: [Icon(Icons.print, color: textColor), const SizedBox(width: 12), Text('Reimprimir', style: TextStyle(color: textColor, fontWeight: FontWeight.bold))])),
                                                      if (statusFormatado != 'Cancelado')
                                                        PopupMenuItem(value: 'cancel', child: Row(children: [const Icon(Icons.cancel, color: Colors.red), const SizedBox(width: 12), Text('Cancelar', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))])),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                if (idx == 0) {
                                  return Showcase.withWidget(
                                    key: _keyLista,
                                    container: _buildTooltipMascote(showcaseContext, _textosMascote[1], true),
                                    child: cardVenda,
                                  );
                                }

                                return cardVenda;
                              },
                            ),
                  ),
                ],
              ),
              
              Positioned(
                bottom: 24,
                right: 24,
                child: GestureDetector(
                  onTap: () => _mostrarMensagemMascote(showcaseContext),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: const Offset(0, 5),
                        )
                      ]
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: Image.asset(
                        'assets/images/mascote_acenando.gif',
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 70, height: 70,
                          decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                          child: const Icon(Icons.help_outline, color: Colors.white, size: 35),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}