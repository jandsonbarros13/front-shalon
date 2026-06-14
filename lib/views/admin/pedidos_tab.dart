import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:acaiteria_front/features/auth/services/pedido_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PedidosTab extends StatefulWidget {
  const PedidosTab({super.key});

  @override
  State<PedidosTab> createState() => _PedidosTabState();
}

class _PedidosTabState extends State<PedidosTab> {
  final _pedidoService = PedidoService();
  List<dynamic> _pedidos = [];
  int _totalPedidos = 0;
  bool _isLoading = true;
  Timer? _timerAutoRefresh;

  int _paginaAtual = 1;
  final int _itensPorPagina = 10;

  @override
  void initState() {
    super.initState();
    _carregarPedidos();
    _timerAutoRefresh = Timer.periodic(const Duration(seconds: 15), (timer) {
      _carregarPedidos(silencioso: true);
    });
  }

  @override
  void dispose() {
    _timerAutoRefresh?.cancel();
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
        
        int totalPaginas = (_totalPedidos / _itensPorPagina).ceil();
        if (_paginaAtual > totalPaginas && totalPaginas > 0) {
          _paginaAtual = totalPaginas;
          _carregarPedidos(silencioso: silencioso);
        }
      });
    }
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
          const SnackBar(content: Text('Número de telefone do cliente é inválido.'), backgroundColor: Colors.orange),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tituloModal, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(mensagemModal),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: corBotao, foregroundColor: Colors.white),
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
                    const SnackBar(content: Text('Erro ao atualizar status do pedido.'), backgroundColor: Colors.red),
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
    final corTema = const Color(0xFF4A0E4E);
    final itens = p['itens'] as List? ?? [];
    final double valorTotal = double.tryParse(p['valor_total'].toString()) ?? 0.0;
    final String status = p['status'] ?? 'Pendente';
    final bool isEntrega = p['tipo_entrega'] == 'Entrega';

    showDialog(
      context: context,
      builder: (context) => Dialog(
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
                  color: corTema,
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
                            const Text('INFORMAÇÕES DO CLIENTE', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey)),
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
                            const Text('PAGAMENTO', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey)),
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
                        Container(width: 1, height: 250, color: Colors.grey[300], margin: const EdgeInsets.symmetric(horizontal: 24)),
                      if (isMobile)
                        const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Divider()),
                      Expanded(
                        flex: isMobile ? 0 : 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('ITENS DO PEDIDO', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey)),
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
                                      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                                      child: Text(qtdTexto, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text('${item['nome']}', style: const TextStyle(fontSize: 15))),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('TOTAL DO PEDIDO', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text('R\$ ${valorTotal.toStringAsFixed(2).replaceAll('.', ',')}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: corTema)),
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
                  color: Colors.grey[50],
                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
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
                      _btnAcao('Cancelar Pedido', Icons.cancel, Colors.red, () => _acaoComModalDetalhe(p, () => _confirmarMudarStatus(
                        id: p['id'], novoStatus: 'Cancelado', tituloModal: 'Cancelar Pedido', mensagemModal: 'Tem certeza de que deseja cancelar o pedido #${p['id']}?', corBotao: Colors.red, 
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

  Color _getCorStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pendente': return Colors.orange;
      case 'preparando': return Colors.blue;
      case 'saiu para entrega': return Colors.purple;
      case 'pronto para retirada': return Colors.teal;
      case 'concluído': return Colors.green;
      case 'cancelado': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final corTema = const Color(0xFF4A0E4E);
    final larguraTela = MediaQuery.of(context).size.width;
    final isMobile = larguraTela < 600;

    int totalPaginas = (_totalPedidos / _itensPorPagina).ceil();
    if (totalPaginas == 0) totalPaginas = 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text('Fila de Pedidos', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        foregroundColor: corTema,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar Lista',
            onPressed: () => _carregarPedidos(),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            color: Colors.white,
            child: Row(
              children: [
                Container(
                  width: 50, height: 50,
                  decoration: const BoxDecoration(shape: BoxShape.circle, image: DecorationImage(image: AssetImage('assets/images/logo.jpg'), fit: BoxFit.cover)),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Açaiteria Shalom', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF4A0E4E))),
                    Text('Gestão de Pedidos', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: corTema))
                : _pedidos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text('Nenhum pedido no momento', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey[600]), textAlign: TextAlign.center),
                            const SizedBox(height: 8),
                            Text('Aguardando os clientes fazerem pedidos na vitrine...', style: TextStyle(color: Colors.grey[500]), textAlign: TextAlign.center),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              padding: EdgeInsets.all(isMobile ? 12.0 : 24.0),
                              itemCount: _pedidos.length,
                              itemBuilder: (context, index) {
                                final p = _pedidos[index];
                                final double valorTotal = double.tryParse(p['valor_total'].toString()) ?? 0.0;
                                final String status = p['status'] ?? 'Pendente';

                                return Card(
                                  elevation: 2,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: _getCorStatus(status).withOpacity(0.3), width: 1),
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
                                      title: Text(p['cliente_nome'] ?? 'Cliente', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Row(
                                          children: [
                                            Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                                            const SizedBox(width: 4),
                                            Text('${p['data']}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
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
                                              child: Text('R\$ ${valorTotal.toStringAsFixed(2).replaceAll('.', ',')}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: corTema)),
                                            ),
                                          Container(
                                            decoration: BoxDecoration(color: corTema.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                            child: IconButton(
                                              icon: Icon(Icons.visibility, color: corTema),
                                              tooltip: 'Ver Detalhes do Pedido',
                                              onPressed: () => _mostrarModalDetalhes(p),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          _buildControlePaginacao(totalPaginas, corTema),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _linhaDetalhe(IconData icon, String texto) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(child: Text(texto, style: const TextStyle(fontSize: 14))),
      ],
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

  Widget _buildControlePaginacao(int totalPaginas, Color corTema) {
    if (totalPaginas <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, -2))]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 20),
            color: _paginaAtual > 1 ? corTema : Colors.grey[300],
            onPressed: _paginaAtual > 1 ? () {
              setState(() => _paginaAtual--);
              _carregarPedidos();
            } : null,
          ),
          const SizedBox(width: 16),
          Text(
            'Página $_paginaAtual de $totalPaginas',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800], fontSize: 14),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 20),
            color: _paginaAtual < totalPaginas ? corTema : Colors.grey[300],
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