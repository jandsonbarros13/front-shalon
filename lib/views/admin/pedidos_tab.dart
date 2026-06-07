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
  bool _isLoading = true;
  Timer? _timerAutoRefresh;

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
    
    final lista = await _pedidoService.listarPedidos();
    
    if (mounted) {
      setState(() {
        _pedidos = lista;
        _isLoading = false;
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
      html.window.open('whatsapp://send?phone=$telefoneLimpo&text=$textoUrl', '_self');
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
              pw.Center(child: pw.Text('ACAITERIA SHALOM', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
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
              final sucesso = await _pedidoService.atualizarStatus(id, novoStatus);
              if (sucesso) {
                _carregarPedidos(silencioso: true);
                if (onSuccess != null) onSuccess();
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Erro ao atualizar status.'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Confirmar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _aceitarEPrepararPedido(Map<String, dynamic> p) {
    _confirmarMudarStatus(
      id: p['id'],
      novoStatus: 'Preparando',
      tituloModal: 'Aceitar Pedido',
      mensagemModal: 'Deseja aceitar e iniciar o preparo do pedido #${p['id']}?',
      corBotao: Colors.blue,
      onSuccess: () {
        String nome = p['cliente_nome'] ?? 'Cliente';
        String msg = 'Olá $nome! Seu pedido #${p['id']} foi aceito pela Açaiteria Shalom e já está sendo preparado.\n\nEm breve mandaremos o status de finalizado.';
        _abrirWhatsApp(p['cliente_telefone'] ?? '', msg);
      },
    );
  }

  void _concluirPedido(Map<String, dynamic> p) {
    _confirmarMudarStatus(
      id: p['id'],
      novoStatus: 'Concluído',
      tituloModal: 'Concluir Pedido',
      mensagemModal: 'Deseja finalizar o pedido #${p['id']} e baixar a notinha?',
      corBotao: Colors.green,
      onSuccess: () async {
        await _gerarEBaixarReciboPdf(p);
        Future.delayed(const Duration(milliseconds: 500), () {
          String nome = p['cliente_nome'] ?? 'Cliente';
          String msg = 'Olá $nome! O seu pedido #${p['id']} na Açaiteria Shalom está finalizado!\n\nSegue em anexo a notinha do seu pedido. Agradecemos a preferência!';
          _abrirWhatsApp(p['cliente_telefone'] ?? '', msg);
        });
      },
    );
  }

  void _cancelarPedidoAdmin(Map<String, dynamic> p) {
    _confirmarMudarStatus(
      id: p['id'],
      novoStatus: 'Cancelado',
      tituloModal: 'Cancelar Pedido',
      mensagemModal: 'Tem certeza de que deseja cancelar o pedido #${p['id']}?',
      corBotao: Colors.red,
      onSuccess: () {
        String nome = p['cliente_nome'] ?? 'Cliente';
        String msg = 'Olá $nome. Infelizmente seu pedido #${p['id']} na Açaiteria Shalom precisou ser cancelado.\n\nCaso tenha alguma dúvida, por favor nos mande uma mensagem.';
        _abrirWhatsApp(p['cliente_telefone'] ?? '', msg);
      },
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
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: AssetImage('assets/images/logo.jpg'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Açaiteria Shalom',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF4A0E4E)),
                    ),
                    Text(
                      'Gestão de Pedidos',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
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
                    : Padding(
                        padding: EdgeInsets.all(isMobile ? 12.0 : 24.0),
                        child: ListView.separated(
                          itemCount: _pedidos.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final p = _pedidos[index];
                            final itens = p['itens'] as List? ?? [];
                            final double valorTotal = double.tryParse(p['valor_total'].toString()) ?? 0.0;
                            final String status = p['status'] ?? 'Pendente';
                            final bool isEntrega = p['tipo_entrega'] == 'Entrega';

                            return Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: _getCorStatus(status).withOpacity(0.5), width: 2),
                              ),
                              child: ExpansionTile(
                                shape: const Border(),
                                collapsedShape: const Border(),
                                childrenPadding: EdgeInsets.all(isMobile ? 16 : 24),
                                title: isMobile 
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '#${p['id']} - ${p['cliente_nome'] ?? 'Cliente'}', 
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              'R\$ ${valorTotal.toStringAsFixed(2).replaceAll('.', ',')}', 
                                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: corTema)
                                            ),
                                          ]
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('${p['data']} • ${p['tipo_entrega']}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(color: _getCorStatus(status), borderRadius: BorderRadius.circular(12)),
                                              child: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                                            ),
                                          ]
                                        )
                                      ]
                                    )
                                  : Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(color: _getCorStatus(status).withOpacity(0.1), shape: BoxShape.circle),
                                          child: Text('#${p['id']}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: _getCorStatus(status))),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(p['cliente_nome'] ?? 'Cliente', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                              Text('${p['data']} • ${p['tipo_entrega']}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          decoration: BoxDecoration(color: _getCorStatus(status), borderRadius: BorderRadius.circular(20)),
                                          child: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                        ),
                                        const SizedBox(width: 16),
                                        Text('R\$ ${valorTotal.toStringAsFixed(2).replaceAll('.', ',')}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: corTema)),
                                      ],
                                    ),
                                children: [
                                  const Divider(),
                                  isMobile
                                    ? Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('INFORMAÇÕES DO CLIENTE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                          const SizedBox(height: 8),
                                          _linhaDetalhe(Icons.phone, p['cliente_telefone'] ?? ''),
                                          if (isEntrega) ...[
                                            const SizedBox(height: 4),
                                            _linhaDetalhe(Icons.location_on, '${p['endereco_rua']}, Nº ${p['endereco_numero']} - ${p['endereco_bairro']}'),
                                            if ((p['endereco_referencia'] ?? '').isNotEmpty)
                                              _linhaDetalhe(Icons.pin_drop, 'Ref: ${p['endereco_referencia']}'),
                                          ],
                                          const SizedBox(height: 16),
                                          const Text('PAGAMENTO', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                          const SizedBox(height: 8),
                                          _linhaDetalhe(Icons.payment, p['forma_pagamento'] ?? ''),
                                          if (p['forma_pagamento'] == 'Dinheiro' && (p['troco_para'] != null && p['troco_para'] > 0))
                                            _linhaDetalhe(Icons.money, 'Levar troco para R\$ ${p['troco_para']}'),
                                          const SizedBox(height: 16),
                                          const Divider(),
                                          const SizedBox(height: 16),
                                          const Text('ITENS DO PEDIDO', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                          const SizedBox(height: 8),
                                          ...itens.map((item) {
                                            String un = (item['unidade'] ?? '').toString().toLowerCase();
                                            bool isPeso = un == 'kg' || un == 'grama' || un == 'g';
                                            double qtd = double.tryParse(item['quantidade'].toString()) ?? 0.0;
                                            
                                            String qtdTexto = isPeso ? '${qtd.toInt()}g' : '${qtd.toInt()}x';
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 4.0),
                                              child: Text('• $qtdTexto ${item['nome']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                            );
                                          }),
                                          const SizedBox(height: 24),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              if (status == 'Pendente') ...[
                                                _btnAcao('Aceitar e Preparar', Colors.blue, () => _aceitarEPrepararPedido(p)),
                                                _btnAcao('Cancelar', Colors.red, () => _cancelarPedidoAdmin(p)),
                                              ],
                                              if (status == 'Preparando' && isEntrega)
                                                _btnAcao('Saiu para Entrega', Colors.purple, () => _confirmarMudarStatus(id: p['id'], novoStatus: 'Saiu para Entrega', tituloModal: 'Confirmar Saída', mensagemModal: 'Marcar que o pedido #${p['id']} saiu para entrega?', corBotao: Colors.purple)),
                                              if (status == 'Preparando' && !isEntrega)
                                                _btnAcao('Pronto p/ Retirada', Colors.teal, () => _confirmarMudarStatus(id: p['id'], novoStatus: 'Pronto para Retirada', tituloModal: 'Pronto para Retirada', mensagemModal: 'Marcar que o pedido #${p['id']} está pronto para o cliente retirar?', corBotao: Colors.teal)),
                                              if (status == 'Preparando' || status == 'Saiu para Entrega' || status == 'Pronto para Retirada')
                                                _btnAcao('Concluir Pedido', Colors.green, () => _concluirPedido(p)),
                                              if (status == 'Concluído')
                                                _btnAcao('Baixar PDF p/ Impressão', Colors.grey, () => _gerarEBaixarReciboPdf(p)),
                                            ],
                                          )
                                        ],
                                      )
                                    : Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('INFORMAÇÕES DO CLIENTE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                                const SizedBox(height: 8),
                                                _linhaDetalhe(Icons.phone, p['cliente_telefone'] ?? ''),
                                                if (isEntrega) ...[
                                                  const SizedBox(height: 4),
                                                  _linhaDetalhe(Icons.location_on, '${p['endereco_rua']}, Nº ${p['endereco_numero']} - ${p['endereco_bairro']}'),
                                                  if ((p['endereco_referencia'] ?? '').isNotEmpty)
                                                    _linhaDetalhe(Icons.pin_drop, 'Ref: ${p['endereco_referencia']}'),
                                                ],
                                                const SizedBox(height: 16),
                                                const Text('PAGAMENTO', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                                const SizedBox(height: 8),
                                                _linhaDetalhe(Icons.payment, p['forma_pagamento'] ?? ''),
                                                if (p['forma_pagamento'] == 'Dinheiro' && (p['troco_para'] != null && p['troco_para'] > 0))
                                                  _linhaDetalhe(Icons.money, 'Levar troco para R\$ ${p['troco_para']}'),
                                              ],
                                            ),
                                          ),
                                          Container(width: 1, height: 150, color: Colors.grey[300], margin: const EdgeInsets.symmetric(horizontal: 24)),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('ITENS DO PEDIDO', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                                const SizedBox(height: 8),
                                                ...itens.map((item) {
                                                  String un = (item['unidade'] ?? '').toString().toLowerCase();
                                                  bool isPeso = un == 'kg' || un == 'grama' || un == 'g';
                                                  double qtd = double.tryParse(item['quantidade'].toString()) ?? 0.0;
                                                  
                                                  String qtdTexto = isPeso ? '${qtd.toInt()}g' : '${qtd.toInt()}x';
                                                  return Padding(
                                                    padding: const EdgeInsets.only(bottom: 4.0),
                                                    child: Text('• $qtdTexto ${item['nome']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                                  );
                                                }),
                                                const SizedBox(height: 24),
                                                Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  children: [
                                                    if (status == 'Pendente') ...[
                                                      _btnAcao('Aceitar e Preparar', Colors.blue, () => _aceitarEPrepararPedido(p)),
                                                      _btnAcao('Cancelar Pedido', Colors.red, () => _cancelarPedidoAdmin(p)),
                                                    ],
                                                    if (status == 'Preparando' && isEntrega)
                                                      _btnAcao('Saiu para Entrega', Colors.purple, () => _confirmarMudarStatus(id: p['id'], novoStatus: 'Saiu para Entrega', tituloModal: 'Confirmar Saída', mensagemModal: 'Marcar que o pedido #${p['id']} saiu para entrega?', corBotao: Colors.purple)),
                                                    if (status == 'Preparando' && !isEntrega)
                                                      _btnAcao('Pronto para Retirada', Colors.teal, () => _confirmarMudarStatus(id: p['id'], novoStatus: 'Pronto para Retirada', tituloModal: 'Pronto para Retirada', mensagemModal: 'Marcar que o pedido #${p['id']} está pronto para o cliente retirar?', corBotao: Colors.teal)),
                                                    if (status == 'Preparando' || status == 'Saiu para Entrega' || status == 'Pronto para Retirada')
                                                      _btnAcao('Concluir Pedido', Colors.green, () => _concluirPedido(p)),
                                                    if (status == 'Concluído')
                                                      _btnAcao('Baixar PDF p/ Impressão', Colors.grey, () => _gerarEBaixarReciboPdf(p)),
                                                  ],
                                                )
                                              ],
                                            ),
                                          ),
                                        ],
                                      )
                                ],
                              ),
                            );
                          },
                        ),
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

  Widget _btnAcao(String texto, Color cor, VoidCallback onTab) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: cor, foregroundColor: Colors.white, elevation: 0),
      onPressed: onTab,
      child: Text(texto, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}