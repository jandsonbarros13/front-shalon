import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  int _totalPedidos = 0;
  bool _isLoading = true;
  Timer? _timerAutoRefresh;
  bool _isDarkMode = true; 

  int _paginaAtual = 1;
  final int _itensPorPagina = 10;

  final FlutterTts _flutterTts = FlutterTts();
  final GlobalKey _keyBusca = GlobalKey();
  final GlobalKey _keyLista = GlobalKey();

  final List<String> _textosMascote = [
    "Bem-vindo à Fila de Pedidos! Aqui você pode pesquisar rapidamente pelo ID ou nome do cliente.",
    "Nesta lista ficam todos os pedidos recentes. Clique no ícone de olho para abrir os detalhes, alterar o status e até chamar o cliente no WhatsApp!"
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
    _carregarPedidos();
    _timerAutoRefresh = Timer.periodic(const Duration(seconds: 15), (timer) {
      _carregarPedidos(silencioso: true);
    });
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _timerAutoRefresh?.cancel();
    _buscaController.dispose();
    super.dispose();
  }

  Future<void> _carregarPedidos({bool silencioso = false}) async {
    if (!silencioso && mounted) {
      setState(() => _isLoading = true);
    }
    
    final resultado = await _pedidoService.listarPedidos(_paginaAtual);
    
    if (mounted) {
      setState(() {
        _pedidos = resultado['pedidos'] ?? [];
        _totalPedidos = resultado['total'] ?? 0;
        _isLoading = false;
        
        _filtrarPedidos(_buscaController.text);
        
        int totalPaginas = (_totalPedidos / _itensPorPagina).ceil();
        if (_paginaAtual > totalPaginas && totalPaginas > 0) {
          _paginaAtual = totalPaginas;
          _carregarPedidos(silencioso: silencioso);
        }
      });
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

  String _formatarTelefone(String telefoneRaw) {
    String telefoneLimpo = telefoneRaw.replaceAll(RegExp(r'\D'), '');
    if (!telefoneLimpo.startsWith('55') && telefoneLimpo.length >= 10) {
      telefoneLimpo = '55$telefoneLimpo';
    }
    return telefoneLimpo;
  }

  void _abrirWhatsApp(String telefone, String mensagem) {
    String telefoneLimpo = _formatarTelefone(telefone);
    if (telefoneLimpo.isNotEmpty) {
      String textoUrl = Uri.encodeComponent(mensagem);
      html.window.open('whatsapp://send?phone=$telefoneLimpo&text=$textoUrl', '_blank');
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Número de telefone do cliente é inválido.', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.orange),
        );
      }
    }
  }

  Future<void> _gerarEBaixarReciboPdf(Map<String, dynamic> p) async {
    final pdf = pw.Document();
    final itens = p['itens'] as List? ?? [];
    final double valorTotal = double.tryParse(p['valor_total'].toString()) ?? 0.0;
    final bool isEntrega = p['tipo_entrega'] == 'Entrega';

    pw.ImageProvider? logoImage;
    try {
      final ByteData bytes = await rootBundle.load('assets/images/logo.jpg');
      logoImage = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {}

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(16),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: logoImage != null
                    ? pw.Container(width: 60, height: 60, child: pw.Image(logoImage))
                    : pw.Container(
                        width: 60,
                        height: 60,
                        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                        child: pw.Center(child: pw.Text('LOGO', style: const pw.TextStyle(fontSize: 10))),
                      ),
              ),
              if (logoImage != null) pw.SizedBox(height: 5),
              pw.Center(child: pw.Text('AÇAITERIA SHALOM', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
              pw.Center(child: pw.Text('O melhor açaí de Canindé', style: const pw.TextStyle(fontSize: 10))),
              pw.SizedBox(height: 10),
              pw.Center(child: pw.Text('PEDIDO #${p['id']}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.Text('CLIENTE: ${p['cliente_nome']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('CELULAR: ${p['cliente_telefone']}'),
              pw.SizedBox(height: 5),
              if (isEntrega) ...[
                pw.Text('TIPO: ENTREGA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('ENDEREÇO: ${p['endereco_rua']}, ${p['endereco_numero']}'),
                pw.Text('BAIRRO: ${p['endereco_bairro']}'),
                if (p['endereco_cep'] != null && p['endereco_cep'].toString().isNotEmpty)
                  pw.Text('CEP: ${p['endereco_cep']}'),
                if ((p['endereco_referencia'] ?? '').isNotEmpty)
                  pw.Text('REF: ${p['endereco_referencia']}'),
              ] else ...[
                pw.Text('TIPO: RETIRADA NO LOCAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
              pw.SizedBox(height: 5),
              pw.Text('PAGAMENTO: ${p['forma_pagamento']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              if (p['forma_pagamento'] == 'Dinheiro' && (p['troco_para'] != null && p['troco_para'] > 0))
                pw.Text('LEVAR TROCO PARA: R\$ ${p['troco_para']}'),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.Center(child: pw.Text('ITENS DO PEDIDO', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 5),
              ...itens.map((item) {
                String un = (item['unidade'] ?? '').toString().toLowerCase();
                bool isPeso = un == 'kg' || un == 'grama' || un == 'g';
                double qtd = double.tryParse(item['quantidade'].toString()) ?? 0.0;
                double sub = double.tryParse(item['subtotal'].toString()) ?? 0.0;
                String qtdTexto = isPeso ? '${qtd.toInt()}g' : '${qtd.toInt()}x';
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(child: pw.Text('$qtdTexto ${item['nome']}')),
                      pw.Text('R\$ ${sub.toStringAsFixed(2).replaceAll('.', ',')}'),
                    ],
                  ),
                );
              }),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text('R\$ ${valorTotal.toStringAsFixed(2).replaceAll('.', ',')}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Center(child: pw.Text('Agradecemos a preferência!', style: const pw.TextStyle(fontSize: 10))),
            ],
          );
        },
      ),
    );
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'Pedido_${p['id']}.pdf');
  }

  Future<void> _confirmarMudarStatus({
    required int id,
    required String novoStatus,
    required String tituloModal,
    required String mensagemModal,
    required Color corBotao,
    VoidCallback? onSuccess,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tituloModal, style: TextStyle(fontWeight: FontWeight.bold, color: corBotao)),
        content: Text(mensagemModal, style: TextStyle(color: textColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: corBotao, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              Navigator.pop(dialogContext); 
              setState(() => _isLoading = true); 
              
              final sucesso = await _pedidoService.atualizarStatus(id, novoStatus);
              
              if (sucesso) {
                await _carregarPedidos(silencioso: false); 
                if (onSuccess != null) onSuccess();
              } else {
                setState(() => _isLoading = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Erro ao atualizar status do pedido.', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: const Text('Confirmar Ação', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _acaoComModalDetalhe(Map<String, dynamic> p, Function acaoReal) {
    Navigator.pop(context); 
    acaoReal();
  }

  void _mostrarModalDetalhes(Map<String, dynamic> p) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final itens = p['itens'] as List? ?? [];
    final double valorTotal = double.tryParse(p['valor_total'].toString()) ?? 0.0;
    final String status = p['status'] ?? 'Pendente';
    final bool isEntrega = p['tipo_entrega'] == 'Entrega';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: EdgeInsets.all(isMobile ? 16 : 40),
        child: Container(
          width: isMobile ? double.infinity : 800,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Pedido #${p['id']}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Flex(
                    direction: isMobile ? Axis.vertical : Axis.horizontal,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: isMobile ? 0 : 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('INFORMAÇÕES DO CLIENTE', style: TextStyle(fontWeight: FontWeight.w900, color: textSecColor)),
                            const SizedBox(height: 12),
                            _linhaDetalhe(Icons.person, p['cliente_nome'] ?? 'Cliente'),
                            const SizedBox(height: 8),
                            _linhaDetalhe(Icons.phone, p['cliente_telefone'] ?? ''),
                            const SizedBox(height: 8),
                            _linhaDetalhe(Icons.delivery_dining, p['tipo_entrega'] ?? ''),
                            
                            if (isEntrega) ...[
                              const SizedBox(height: 8),
                              _linhaDetalhe(Icons.location_on, '${p['endereco_rua']}, Nº ${p['endereco_numero']}\n${p['endereco_bairro']}'),
                              if ((p['endereco_referencia'] ?? '').isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: _linhaDetalhe(Icons.pin_drop, 'Ref: ${p['endereco_referencia']}'),
                                ),
                            ],
                            const SizedBox(height: 24),
                            Text('PAGAMENTO', style: TextStyle(fontWeight: FontWeight.w900, color: textSecColor)),
                            const SizedBox(height: 12),
                            _linhaDetalhe(Icons.payment, p['forma_pagamento'] ?? ''),
                            if (p['forma_pagamento'] == 'Dinheiro' && (p['troco_para'] != null && p['troco_para'] > 0))
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: _linhaDetalhe(Icons.money, 'Levar troco para R\$ ${p['troco_para']}'),
                              ),
                          ],
                        ),
                      ),
                      if (!isMobile)
                        Container(width: 1, height: 250, color: isDark ? Colors.white10 : Colors.grey[300], margin: const EdgeInsets.symmetric(horizontal: 24)),
                      if (isMobile)
                        Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Divider(color: isDark ? Colors.white10 : Colors.grey[300])),
                      Expanded(
                        flex: isMobile ? 0 : 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ITENS DO PEDIDO', style: TextStyle(fontWeight: FontWeight.w900, color: textSecColor)),
                            const SizedBox(height: 12),
                            ...itens.map((item) {
                              String un = (item['unidade'] ?? '').toString().toLowerCase();
                              bool isPeso = un == 'kg' || un == 'grama' || un == 'g';
                              double qtd = double.tryParse(item['quantidade'].toString()) ?? 0.0;
                              String qtdTexto = isPeso ? '${qtd.toInt()}g' : '${qtd.toInt()}x';
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: isDark ? const Color(0xFF1A1A24) : Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                                      child: Text(qtdTexto, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text('${item['nome']}', style: TextStyle(fontSize: 15, color: textColor))),
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
                                Text('TOTAL DO PEDIDO', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                                Text('R\$ ${valorTotal.toStringAsFixed(2).replaceAll('.', ',')}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: accentColor)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E2C) : Colors.grey[50],
                  border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!)),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    if (status == 'Pendente') ...[
                      _btnAcao('Aceitar e Preparar', Icons.check_circle, Colors.blue, () => _acaoComModalDetalhe(p, () => _confirmarMudarStatus(
                        id: p['id'], novoStatus: 'Preparando', tituloModal: 'Aceitar Pedido', mensagemModal: 'Deseja aceitar e iniciar o preparo do pedido #${p['id']}?', corBotao: Colors.blue, 
                        onSuccess: () => _abrirWhatsApp(p['cliente_telefone'] ?? '', 'Olá ${p['cliente_nome']}! Seu pedido #${p['id']} foi aceito pela Açaiteria Shalom e já está sendo preparado.')
                      ))),
                      _btnAcao('Cancelar Pedido', Icons.cancel, Colors.redAccent, () => _acaoComModalDetalhe(p, () => _confirmarMudarStatus(
                        id: p['id'], novoStatus: 'Cancelado', tituloModal: 'Cancelar Pedido', mensagemModal: 'Tem certeza de que deseja cancelar o pedido #${p['id']}?', corBotao: Colors.redAccent, 
                        onSuccess: () => _abrirWhatsApp(p['cliente_telefone'] ?? '', 'Olá ${p['cliente_nome']}. Infelizmente seu pedido #${p['id']} precisou ser cancelado.')
                      ))),
                    ],
                    if (status == 'Preparando' && isEntrega)
                      _btnAcao('Saiu para Entrega', Icons.two_wheeler, Colors.purple, () => _acaoComModalDetalhe(p, () => _confirmarMudarStatus(
                        id: p['id'], novoStatus: 'Saiu para Entrega', tituloModal: 'Confirmar Saída', mensagemModal: 'Marcar que o pedido #${p['id']} saiu para entrega?', corBotao: Colors.purple,
                        onSuccess: () => _abrirWhatsApp(p['cliente_telefone'] ?? '', 'Olá ${p['cliente_nome']}! O seu pedido #${p['id']} acabou de sair para entrega!')
                      ))),
                    if (status == 'Preparando' && !isEntrega)
                      _btnAcao('Pronto p/ Retirada', Icons.storefront, Colors.teal, () => _acaoComModalDetalhe(p, () => _confirmarMudarStatus(
                        id: p['id'], novoStatus: 'Pronto para Retirada', tituloModal: 'Pronto para Retirada', mensagemModal: 'Marcar que o pedido #${p['id']} está pronto para retirar?', corBotao: Colors.teal,
                        onSuccess: () => _abrirWhatsApp(p['cliente_telefone'] ?? '', 'Olá ${p['cliente_nome']}! O seu pedido #${p['id']} já está pronto e aguardando retirada na nossa loja!')
                      ))),
                    if (status == 'Preparando' || status == 'Saiu para Entrega' || status == 'Pronto para Retirada')
                      _btnAcao('Concluir Pedido', Icons.done_all, Colors.green, () => _acaoComModalDetalhe(p, () => _confirmarMudarStatus(
                        id: p['id'], novoStatus: 'Concluído', tituloModal: 'Concluir Pedido', mensagemModal: 'Deseja finalizar o pedido #${p['id']} e baixar a notinha?', corBotao: Colors.green, 
                        onSuccess: () async {
                          await _gerarEBaixarReciboPdf(p);
                        }
                      ))),
                    if (status == 'Concluído')
                      _btnAcao('Baixar Recibo (PDF)', Icons.receipt_long, Colors.grey[700]!, () {
                        Navigator.pop(context);
                        _gerarEBaixarReciboPdf(p);
                      }),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _linhaDetalhe(IconData icon, String texto) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: accentColor),
        const SizedBox(width: 8),
        Expanded(child: Text(texto, style: TextStyle(fontSize: 14, color: textColor))),
      ],
    );
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
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarMensagemMascote(BuildContext showcaseContext, Color corTema) {
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
              border: Border.all(color: corTema, width: 3),
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
                      errorBuilder: (_, __, ___) => Icon(Icons.sentiment_satisfied_alt, size: 80, color: corTema),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E2C) : Colors.grey[100], borderRadius: BorderRadius.circular(16)),
                        child: Text(
                          "Olá! Sou o mascote da Açaiteria Shalom! 🍇\n\n"
                          "Aqui você gerencia todos os pedidos dos clientes. Pode alterar os status, ver detalhes e chamar no WhatsApp!\n\n"
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
                          backgroundColor: corTema,
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

  @override
  Widget build(BuildContext context) {
    final larguraTela = MediaQuery.of(context).size.width;
    final isMobile = larguraTela < 600;

    int totalPaginas = (_totalPedidos / _itensPorPagina).ceil();
    if (totalPaginas == 0) totalPaginas = 1;

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
              IconButton(
                icon: Icon(Icons.refresh, color: textColor),
                tooltip: 'Atualizar Lista',
                onPressed: () => _carregarPedidos(),
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    color: cardColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Showcase.withWidget(
                          key: _keyBusca,
                          container: _buildTooltipMascote(showcaseContext, _textosMascote[0], false),
                          child: TextField(
                            controller: _buscaController,
                            onChanged: _filtrarPedidos,
                            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              hintText: 'Pesquisar por ID da Venda ou Nome do Cliente...',
                              hintStyle: TextStyle(color: textSecColor),
                              prefixIcon: Icon(Icons.search, color: accentColor),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF1F3F4),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _isLoading
                        ? Center(child: CircularProgressIndicator(color: accentColor))
                        : _pedidosFiltrados.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.inbox_outlined, size: 80, color: textSecColor.withOpacity(0.5)),
                                    const SizedBox(height: 16),
                                    Text('Nenhum pedido no momento', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textSecColor), textAlign: TextAlign.center),
                                    const SizedBox(height: 8),
                                    Text('Aguardando os clientes fazerem pedidos na vitrine...', style: TextStyle(color: textSecColor), textAlign: TextAlign.center),
                                  ],
                                ),
                              )
                            : Column(
                                children: [
                                  Expanded(
                                    child: ListView.builder(
                                      padding: EdgeInsets.all(isMobile ? 12.0 : 24.0),
                                      itemCount: _pedidosFiltrados.length,
                                      itemBuilder: (context, index) {
                                        final p = _pedidosFiltrados[index];
                                        final double valorTotal = double.tryParse(p['valor_total'].toString()) ?? 0.0;
                                        final String status = p['status'] ?? 'Pendente';

                                        Widget cardContent = Card(
                                          color: cardColor,
                                          elevation: isDark ? 4 : 2,
                                          shadowColor: Colors.black.withOpacity(0.1),
                                          margin: const EdgeInsets.only(bottom: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            side: BorderSide(color: isDark ? Colors.white10 : _getCorStatus(status).withOpacity(0.3), width: 1),
                                          ),
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: isMobile ? 8.0 : 16.0),
                                            child: ListTile(
                                              leading: Container(
                                                width: 50, height: 50,
                                                decoration: BoxDecoration(color: _getCorStatus(status).withOpacity(0.1), shape: BoxShape.circle),
                                                child: Center(
                                                  child: Text('#${p['id']}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _getCorStatus(status))),
                                                ),
                                              ),
                                              title: Text(p['cliente_nome'] ?? 'Cliente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                                              subtitle: Padding(
                                                padding: const EdgeInsets.only(top: 4.0),
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.access_time, size: 14, color: textSecColor),
                                                    const SizedBox(width: 4),
                                                    Text('${p['data']}', style: TextStyle(color: textSecColor, fontSize: 13)),
                                                    const SizedBox(width: 12),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(color: _getCorStatus(status), borderRadius: BorderRadius.circular(12)),
                                                      child: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (!isMobile)
                                                    Padding(
                                                      padding: const EdgeInsets.only(right: 16.0),
                                                      child: Text('R\$ ${valorTotal.toStringAsFixed(2).replaceAll('.', ',')}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: accentColor)),
                                                    ),
                                                  Container(
                                                    decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                                    child: IconButton(
                                                      icon: Icon(Icons.visibility, color: accentColor),
                                                      tooltip: 'Ver Detalhes do Pedido',
                                                      onPressed: () => _mostrarModalDetalhes(p),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );

                                        if (index == 0) {
                                          return Showcase.withWidget(
                                            key: _keyLista,
                                            container: _buildTooltipMascote(showcaseContext, _textosMascote[1], true),
                                            child: cardContent,
                                          );
                                        }
                                        return cardContent;
                                      },
                                    ),
                                  ),
                                  _buildControlePaginacao(totalPaginas, accentColor, cardColor, textColor, textSecColor, isDark),
                                ],
                              ),
                  ),
                ],
              ),
              Positioned(
                bottom: 24,
                right: 24,
                child: GestureDetector(
                  onTap: () => _mostrarMensagemMascote(showcaseContext, accentColor),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.3),
                          blurRadius: 15,
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

  Widget _btnAcao(String texto, IconData icone, Color cor, VoidCallback onTab) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: cor, 
        foregroundColor: Colors.white, 
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
      ),
      icon: Icon(icone, size: 18),
      label: Text(texto, style: const TextStyle(fontWeight: FontWeight.bold)),
      onPressed: onTab,
    );
  }

  Widget _buildControlePaginacao(int totalPaginas, Color accentColor, Color cardColor, Color textColor, Color textSecColor, bool isDark) {
    if (totalPaginas <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 4, offset: const Offset(0, -2))]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 20),
            color: _paginaAtual > 1 ? accentColor : textSecColor.withOpacity(0.3),
            onPressed: _paginaAtual > 1 ? () {
              setState(() => _paginaAtual--);
              _carregarPedidos();
            } : null,
          ),
          const SizedBox(width: 16),
          Text(
            'Página $_paginaAtual de $totalPaginas',
            style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 14),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 20),
            color: _paginaAtual < totalPaginas ? accentColor : textSecColor.withOpacity(0.3),
            onPressed: _paginaAtual < totalPaginas ? () {
              setState(() => _paginaAtual++);
              _carregarPedidos();
            } : null,
          ),
        ],
      ),
    );
  }
}