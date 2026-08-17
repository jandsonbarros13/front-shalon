import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:acaiteria_front/core/constants/api_constants.dart';
import 'package:acaiteria_front/features/auth/services/pedido_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:showcaseview/showcaseview.dart';

class PedidosTab extends StatefulWidget {
  const PedidosTab({super.key});

  @override
  State<PedidosTab> createState() => _PedidosTabState();
}

class _PedidosTabState extends State<PedidosTab> {
  final _pedidoService = PedidoService();
  final TextEditingController _buscaController = TextEditingController();
  
  List<dynamic> _pedidos = [];
  List<dynamic> _pedidosFiltrados = [];
  Map<String, dynamic>? _empresaData;
  
  bool _loading = true;
  int _paginaAtual = 1;
  bool _temMais = true;
  bool _isDarkMode = true; 
  Timer? _timerAutoRefresh;

  final List<String> _statusValidos = [
    'Pendente',
    'Preparando',
    'Saiu para Entrega',
    'Pronto para Retirada',
    'Concluído',
    'Cancelado'
  ];

  final FlutterTts _flutterTts = FlutterTts();
  final GlobalKey _keyBusca = GlobalKey();
  final GlobalKey _keyLista = GlobalKey();

  final List<String> _textosMascote = [
    "Bem-vindo à Fila de Pedidos! Aqui você pesquisa rapidamente pelo ID ou nome do cliente.",
    "Nesta lista ficam os pedidos do App. Clique no pedido para ver detalhes, trocar o status, enviar WhatsApp, E-mail, Imprimir ou Cancelar!"
  ];

  bool get isDark => _isDarkMode;
  Color get accentColor => isDark ? const Color(0xFFE040FB) : const Color(0xFF4A0E4E);
  Color get bgColor => isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF4F6F8);
  Color get cardColor => isDark ? const Color(0xFF27293D) : Colors.white;
  Color get textColor => isDark ? Colors.white : Colors.black87;
  Color get textSecColor => isDark ? Colors.white54 : Colors.grey[600]!;

  String get _baseUrl {
    String url = ApiConstants.baseUrl.trim();
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    if (url.endsWith('/api')) url = url.substring(0, url.length - 4);
    return url;
  }

  @override
  void initState() {
    super.initState();
    _flutterTts.setLanguage("pt-BR");
    _carregarEmpresa();
    _carregarPedidos();
    _timerAutoRefresh = Timer.periodic(const Duration(seconds: 15), (timer) {
      _carregarPedidos(carregarMais: false, silencioso: true);
    });
  }

  @override
  void dispose() {
    _buscaController.dispose();
    _flutterTts.stop();
    _timerAutoRefresh?.cancel();
    super.dispose();
  }

  Future<void> _carregarEmpresa() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/empresa'));
      if (response.statusCode == 200) {
        setState(() {
          _empresaData = jsonDecode(response.body);
        });
      }
    } catch (_) {}
  }

  Future<void> _carregarPedidos({bool carregarMais = false, bool silencioso = false}) async {
    if (carregarMais) {
      _paginaAtual++;
    } else {
      _paginaAtual = 1;
      if (!silencioso) setState(() => _loading = true);
    }

    try {
      final resultado = await _pedidoService.listarPedidos(_paginaAtual);
      final listagem = resultado['pedidos'] as List? ?? [];

      if (mounted) {
        setState(() {
          if (carregarMais) {
            final listaCompleta = [..._pedidos, ...listagem];
            listaCompleta.sort((a, b) => (b['id'] ?? 0).compareTo(a['id'] ?? 0));
            _pedidos = listaCompleta;
          } else {
            listagem.sort((a, b) => (b['id'] ?? 0).compareTo(a['id'] ?? 0));
            _pedidos = listagem;
          }
          
          _filtrarPedidos(_buscaController.text);
          _temMais = listagem.length >= 10;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filtrarPedidos(String query) {
    if (query.isEmpty) {
      setState(() {
        _pedidosFiltrados = List.from(_pedidos);
      });
      return;
    }

    final q = query.toLowerCase().trim();
    setState(() {
      _pedidosFiltrados = _pedidos.where((p) {
        final nome = (p['cliente_nome'] ?? '').toString().toLowerCase();
        final id = (p['id'] ?? '').toString();
        return nome.contains(q) || id.contains(q);
      }).toList();
    });
  }

  Color _getCorStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pendente': return Colors.orange;
      case 'preparando': return Colors.blue;
      case 'saiu para entrega': return Colors.purple;
      case 'pronto para retirada': return Colors.teal;
      case 'concluído': return Colors.greenAccent[700] ?? Colors.green;
      case 'cancelado': return Colors.redAccent;
      default: return Colors.grey;
    }
  }

  Future<void> _alterarStatusPedido(int id, String novoStatus) async {
    setState(() {
      final indexOriginal = _pedidos.indexWhere((p) => p['id'] == id);
      if (indexOriginal >= 0) _pedidos[indexOriginal]['status'] = novoStatus;
      _filtrarPedidos(_buscaController.text);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pedido #$id alterado para: $novoStatus!', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: novoStatus == 'Cancelado' ? Colors.redAccent : Colors.blue,
        duration: const Duration(seconds: 2),
      )
    );

    try {
      await _pedidoService.atualizarStatus(id, novoStatus);
    } catch (e) {
      debugPrint("Erro ao atualizar status: $e");
    }
  }

  void _dialogWhatsApp(Map<String, dynamic> p) {
    final telefoneController = TextEditingController(text: p['cliente_telefone'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Avisar no WhatsApp', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: telefoneController,
          keyboardType: TextInputType.phone,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            labelText: 'Número com DDD',
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
              _enviarWhatsApp(telefoneController.text, p);
            },
            child: const Text('Enviar Msg', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _enviarWhatsApp(String telefone, Map<String, dynamic> p) {
    String telLimpo = telefone.replaceAll(RegExp(r'\D'), '');
    if (telLimpo.isEmpty) return;
    if (!telLimpo.startsWith('55') && telLimpo.length >= 10) telLimpo = '55$telLimpo';
    
    final nomeEmpresa = _empresaData?['nome_empresa'] ?? 'Açaiteria';
    final status = p['status'] ?? 'Pendente';
    
    String msgAdicional = '';
    if (status == 'Preparando') msgAdicional = 'Seu pedido foi aceito e já está sendo preparado!';
    else if (status == 'Saiu para Entrega') msgAdicional = 'Seu pedido acabou de sair para entrega. Fique atento!';
    else if (status == 'Pronto para Retirada') msgAdicional = 'Seu pedido já está pronto aguardando sua retirada!';
    else if (status == 'Concluído') msgAdicional = 'Seu pedido foi finalizado com sucesso. Muito obrigado!';
    else if (status == 'Cancelado') msgAdicional = 'Infelizmente seu pedido precisou ser cancelado. Por favor, entre em contato para mais detalhes.';
    else msgAdicional = 'Gostaria de falar sobre o seu pedido.';

    final msg = 'Olá, ${p['cliente_nome']}! Aqui é da *$nomeEmpresa*.\n\nSobre o seu pedido *#${p['id']}*:\n$msgAdicional';
    
    final url = 'https://api.whatsapp.com/send?phone=$telLimpo&text=${Uri.encodeComponent(msg)}';
    html.window.open(url, '_blank');
  }

  void _dialogEmail(Map<String, dynamic> p) {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Enviar Recibo por E-mail', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
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
              _enviarEmailBackend(emailController.text, p);
            },
            child: const Text('Enviar E-mail', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _enviarEmailBackend(String emailDestino, Map<String, dynamic> p) async {
    if (emailDestino.trim().isEmpty) return;

    try {
      String base64Logo = _empresaData?['logo_url']?.toString() ?? "";
      if (base64Logo.isEmpty) {
        try {
          final ByteData bytes = await rootBundle.load('assets/images/logo.jpg');
          base64Logo = 'data:image/jpeg;base64,${base64Encode(bytes.buffer.asUint8List())}';
        } catch (_) {}
      }

      bool isEntrega = p['tipo_entrega'] == 'Entrega';
      String enderecoCompleto = isEntrega
          ? '${p['endereco_rua'] ?? ''}, nº ${p['endereco_numero'] ?? ''} - ${p['endereco_bairro'] ?? ''} (Ref: ${p['endereco_referencia'] ?? ''})'
          : 'Retirada na Loja';

      List<Map<String, dynamic>> itensEmail = [];
      final itens = p['itens'] ?? [] as List;
      for (var item in itens) {
        itensEmail.add({
          'nome': item['nome'] ?? 'Item',
          'quantidade': double.tryParse((item['quantidade'] ?? 0).toString()) ?? 0.0,
          'preco': double.tryParse((item['subtotal'] ?? 0).toString()) ?? 0.0,
          'observacao': '',
          'adicionais': [],
        });
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/api/pedidos/email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'cliente_nome': p['cliente_nome'] ?? 'Cliente',
          'cliente_telefone': p['cliente_telefone'] ?? '',
          'endereco_entrega': enderecoCompleto,
          'forma_pagamento': _formatarFormaPagamento(p['forma_pagamento'] ?? ''),
          'valor_total': double.tryParse((p['valor_total'] ?? 0).toString()) ?? 0.0,
          'email_destino': emailDestino,
          'logo_base64': base64Logo,
          'itens': itensEmail,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('E-mail enviado com sucesso! 🚀'), backgroundColor: Colors.green),
          );
        }
      } else {
        throw Exception('Erro');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao enviar e-mail.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _confirmarCancelarPedido(int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancelar Pedido', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
        content: Text('Tem certeza de que deseja cancelar o pedido #$id?', style: TextStyle(color: textColor)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Voltar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () {
              Navigator.pop(ctx);
              _alterarStatusPedido(id, 'Cancelado');
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
                          "Esta é a tela da Fila de Pedidos. Aqui você pode:\n"
                          "• Pesquisar pedidos por ID ou nome\n"
                          "• Mudar o status rapidamente no próprio cartão\n"
                          "• Enviar o recibo e avisar via WhatsApp!\n\n"
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

  Future<void> _gerarEBaixarReciboPdf(Map<String, dynamic> p) async {
    final id = p['id'] ?? 0;
    final pdf = pw.Document();
    final itens = p['itens'] as List? ?? [];
    final double valorTotal = double.tryParse((p['valor_total'] ?? 0).toString()) ?? 0.0;
    final bool isEntrega = p['tipo_entrega'] == 'Entrega';
    final data = (p['data'] ?? '').toString();
    final cliente = p['cliente_nome'] ?? 'Cliente';
    final fone = p['cliente_telefone'] ?? '';
    final formaPgto = _formatarFormaPagamento(p['forma_pagamento'] ?? '');

    String nomeEmpresa = _empresaData?['nome_empresa'] ?? 'AÇAITERIA';
    String telEmpresa = _empresaData?['whatsapp'] ?? '';
    if (telEmpresa.isEmpty) telEmpresa = '(85) 99999-9999';

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
              pw.Center(child: pw.Text(nomeEmpresa.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))),
              pw.Center(child: pw.Text('WhatsApp: $telEmpresa', style: const pw.TextStyle(fontSize: 9))),
              pw.SizedBox(height: 6),
              pw.Text('PEDIDO APP #$id', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.Text('DATA: $data', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('CLIENTE: $cliente', style: const pw.TextStyle(fontSize: 9)),
              if (fone.isNotEmpty) pw.Text('CELULAR: $fone', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 4),
              if (isEntrega) ...[
                pw.Text('TIPO: ENTREGA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.Text('ENDEREÇO: ${p['endereco_rua']}, ${p['endereco_numero']}', style: const pw.TextStyle(fontSize: 9)),
                pw.Text('BAIRRO: ${p['endereco_bairro']}', style: const pw.TextStyle(fontSize: 9)),
                if ((p['endereco_referencia'] ?? '').isNotEmpty)
                  pw.Text('REF: ${p['endereco_referencia']}', style: const pw.TextStyle(fontSize: 9)),
              ] else ...[
                pw.Text('TIPO: RETIRADA NO LOCAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
              ],
              pw.SizedBox(height: 4),
              pw.Text('PAGAMENTO: $formaPgto', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
              if (p['forma_pagamento'] == 'Dinheiro' && (p['troco_para'] != null && p['troco_para'] > 0))
                pw.Text('LEVAR TROCO PARA: R\$ ${p['troco_para']}', style: const pw.TextStyle(fontSize: 9)),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.Center(child: pw.Text('ITENS DO PEDIDO', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
              pw.SizedBox(height: 4),
              
              ...itens.map((item) {
                final nomeItem = item['nome'] ?? 'ITEM';
                final rawQtd = double.tryParse((item['quantidade'] ?? 1).toString()) ?? 1.0;
                final subtotalItem = double.tryParse((item['subtotal'] ?? 0).toString()) ?? 0.0;
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
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL GERAL:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.Text('R\$ ${valorTotal.toStringAsFixed(2).replaceAll('.', ',')}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Center(child: pw.Text('Agradecemos a preferência!', style: const pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic))),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'Pedido_$id.pdf');
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
                    'FILA DE PEDIDOS', 
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
                    Icon(Icons.shopping_bag, color: accentColor, size: 16),
                    const SizedBox(width: 8),
                    Text('${_pedidosFiltrados.length} PEDIDOS', style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
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
                        onChanged: _filtrarPedidos,
                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: 'Pesquise por ID do Pedido ou Nome do Cliente...',
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
                      : _pedidosFiltrados.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inbox_outlined, size: 64, color: textSecColor.withOpacity(0.5)),
                                  const SizedBox(height: 16),
                                  Text(
                                    _buscaController.text.isNotEmpty 
                                      ? 'Nenhum pedido encontrado para esta pesquisa.'
                                      : 'Nenhum pedido na fila no momento.', 
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
                                      _carregarPedidos();
                                    },
                                    icon: const Icon(Icons.refresh, color: Colors.white),
                                    label: const Text('Atualizar Fila', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  )
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(24),
                              itemCount: _pedidosFiltrados.length + (_temMais && _buscaController.text.isEmpty ? 1 : 0),
                              itemBuilder: (context, idx) {
                                if (idx == _pedidosFiltrados.length) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                      child: TextButton.icon(
                                        onPressed: () => _carregarPedidos(carregarMais: true),
                                        icon: Icon(Icons.add, color: accentColor),
                                        label: Text('Carregar Mais', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  );
                                }

                                final p = _pedidosFiltrados[idx];
                                final id = p['id'] ?? 0;
                                final total = double.tryParse((p['valor_total'] ?? 0).toString()) ?? 0.0;
                                final data = (p['data'] ?? '').toString();
                                final cliente = p['cliente_nome'] ?? 'Cliente';
                                final formaPgto = _formatarFormaPagamento(p['forma_pagamento'] ?? '');
                                final tipoEntrega = p['tipo_entrega'] ?? 'Não Informado';
                                final bool isEntrega = tipoEntrega == 'Entrega';
                                final itens = p['itens'] as List? ?? [];
                                
                                final statusAtual = (p['status'] ?? 'Pendente').toString();
                                final statusFormatado = _statusValidos.firstWhere(
                                  (s) => s.toLowerCase() == statusAtual.toLowerCase(),
                                  orElse: () => 'Pendente'
                                );
                                final corStatus = _getCorStatus(statusAtual);

                                Widget cardPedido = Card(
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
                                      decoration: BoxDecoration(color: isEntrega ? Colors.orange.withOpacity(0.2) : Colors.teal.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                                      child: Icon(isEntrega ? Icons.delivery_dining : Icons.storefront, color: isEntrega ? Colors.orange : Colors.teal),
                                    ),
                                    title: Text('Pedido #$id - $cliente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 6),
                                        Text('Data: $data | Tipo: $tipoEntrega', style: TextStyle(color: textSecColor, fontSize: 13)),
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
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(Icons.phone, size: 16, color: textSecColor),
                                                const SizedBox(width: 8),
                                                Text(p['cliente_telefone'] ?? '', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                                const SizedBox(width: 24),
                                                Icon(Icons.payment, size: 16, color: textSecColor),
                                                const SizedBox(width: 8),
                                                Text(formaPgto, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                                if (p['forma_pagamento'] == 'Dinheiro' && (p['troco_para'] != null && p['troco_para'] > 0)) ...[
                                                  const SizedBox(width: 16),
                                                  Text('(Troco p/ R\$ ${p['troco_para']})', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                                                ]
                                              ],
                                            ),
                                            if (isEntrega) ...[
                                              const SizedBox(height: 12),
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Icon(Icons.location_on, size: 16, color: textSecColor),
                                                  const SizedBox(width: 8),
                                                  Expanded(child: Text('${p['endereco_rua']}, Nº ${p['endereco_numero']} - ${p['endereco_bairro']} \nRef: ${p['endereco_referencia'] ?? '-'}', style: TextStyle(color: textColor))),
                                                ],
                                              ),
                                            ],
                                            const SizedBox(height: 16),
                                            Divider(color: isDark ? Colors.white10 : Colors.grey[300]),
                                            ...itens.map((item) {
                                              final nomeItem = item['nome'] ?? 'ITEM';
                                              final rawQtd = double.tryParse((item['quantidade'] ?? 1).toString()) ?? 1.0;
                                              final subtotalItem = double.tryParse((item['subtotal'] ?? 0).toString()) ?? 0.0;
                                              final unidade = (item['unidade'] ?? 'Unid').toString();

                                              String qtdTexto = unidade.toLowerCase() == 'kg'
                                                  ? '${(rawQtd).toStringAsFixed(3)} kg'
                                                  : '${rawQtd.toStringAsFixed(0)}x';

                                              return Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 6),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(child: Text("$qtdTexto $nomeItem", style: TextStyle(fontWeight: FontWeight.bold, color: textColor))),
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
                                                              _alterarStatusPedido(id, novoValor);
                                                            }
                                                          },
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                
                                                Row(
                                                  children: [
                                                    if (statusFormatado != 'Cancelado')
                                                      Padding(
                                                        padding: const EdgeInsets.only(right: 8.0),
                                                        child: ElevatedButton.icon(
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: Colors.redAccent,
                                                            foregroundColor: Colors.white,
                                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                                            elevation: 0,
                                                          ),
                                                          onPressed: () => _confirmarCancelarPedido(id),
                                                          icon: const Icon(Icons.cancel, size: 16),
                                                          label: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                        ),
                                                      ),
                                                    Container(
                                                      decoration: BoxDecoration(
                                                        color: cardColor,
                                                        border: Border.all(color: isDark ? Colors.white24 : Colors.grey[300]!),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: PopupMenuButton<String>(
                                                        icon: Icon(Icons.more_vert, color: accentColor),
                                                        tooltip: 'Ações do Pedido',
                                                        color: cardColor,
                                                        offset: const Offset(0, 40),
                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                        onSelected: (valor) {
                                                          if (valor == 'wpp') _dialogWhatsApp(p);
                                                          if (valor == 'email') _dialogEmail(p);
                                                          if (valor == 'print') _gerarEBaixarReciboPdf(p);
                                                        },
                                                        itemBuilder: (context) => [
                                                          PopupMenuItem(value: 'wpp', child: Row(children: [const Icon(Icons.message, color: Colors.green), const SizedBox(width: 12), Text('WhatsApp', style: TextStyle(color: textColor, fontWeight: FontWeight.bold))])),
                                                          PopupMenuItem(value: 'email', child: Row(children: [const Icon(Icons.email, color: Colors.blue), const SizedBox(width: 12), Text('E-mail', style: TextStyle(color: textColor, fontWeight: FontWeight.bold))])),
                                                          PopupMenuItem(value: 'print', child: Row(children: [Icon(Icons.print, color: textColor), const SizedBox(width: 12), Text('Imprimir Recibo', style: TextStyle(color: textColor, fontWeight: FontWeight.bold))])),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
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
                                    child: cardPedido,
                                  );
                                }

                                return cardPedido;
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