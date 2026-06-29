import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:acaiteria_front/features/auth/services/pedido_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class MinhasVendas extends StatefulWidget {
  const MinhasVendas({super.key});

  @override
  State<MinhasVendas> createState() => _MinhasVendasState();
}

class _MinhasVendasState extends State<MinhasVendas> {
  final _pedidoService = PedidoService();
  List<dynamic> _vendas = [];
  bool _loading = true;
  int _paginaAtual = 1;
  bool _temMais = true;

  @override
  void initState() {
    super.initState();
    _carregarVendas();
  }

  Future<void> _carregarVendas({bool carregarMais = false}) async {
    if (carregarMais) {
      _paginaAtual++;
    } else {
      _paginaAtual = 1;
      setState(() => _loading = true);
    }

    try {
      final resultado = await _pedidoService.listarPedidos(_paginaAtual);
      final listagem = resultado['pedidos'] as List? ?? [];

      final apenasPdvValidos = listagem.where((p) {
        final tipoEntrega = (p['tipo_entrega'] ?? '').toString().toLowerCase();
        final status = (p['status'] ?? '').toString().toLowerCase();
        final total = double.tryParse((p['valor_total'] ?? 0).toString()) ?? 0.0;

        bool ehPdv = tipoEntrega == '' || tipoEntrega == 'balcao' || tipoEntrega == 'pdv' || status == 'pendente' || status == 'finalizado';
        
        return ehPdv && total > 0;
      }).toList();

      setState(() {
        if (carregarMais) {
          final listaCompleta = [..._vendas, ...apenasPdvValidos];
          listaCompleta.sort((a, b) => (b['id'] ?? 0).compareTo(a['id'] ?? 0));
          _vendas = listaCompleta;
        } else {
          apenasPdvValidos.sort((a, b) => (b['id'] ?? 0).compareTo(a['id'] ?? 0));
          _vendas = apenasPdvValidos;
        }
        _temMais = listagem.length >= 10;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
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
              pw.Center(child: pw.Text('REIMPRESSÃO DE CUPOM', style: const pw.TextStyle(fontSize: 8, decoration: pw.TextDecoration.underline))),
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
                    ? '${(rawQtd / 1000).toStringAsFixed(3)} kg'
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

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'Cupom_Reimpresso_$id.pdf');
  }

  @override
  Widget build(BuildContext context) {
    const corTema = Color(0xFF4A0E4E);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: corTema))
          : _vendas.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_toggle_off, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('Nenhuma venda válida encontrada no Histórico.', 
                        style: TextStyle(color: Colors.grey[500], fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: corTema),
                        onPressed: () => _carregarVendas(),
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        label: const Text('Atualizar Histórico', style: TextStyle(color: Colors.white)),
                      )
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      color: Colors.white,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.analytics_outlined, color: corTema),
                          const SizedBox(width: 8),
                          Text(
                            'Histórico Balcão (${_vendas.length} itens listados)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: corTema),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _vendas.length + (_temMais ? 1 : 0),
                        itemBuilder: (context, idx) {
                          if (idx == _vendas.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: TextButton.icon(
                                  onPressed: () => _carregarVendas(carregarMais: true),
                                  icon: const Icon(Icons.add, color: corTema),
                                  label: const Text('Carregar Mais', 
                                    style: TextStyle(color: corTema, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            );
                          }

                          final v = _vendas[idx];
                          final id = v['id'] ?? 0;
                          final total = double.tryParse((v['valor_total'] ?? 0).toString()) ?? 0.0;
                          final data = (v['data'] ?? '').toString();
                          final cliente = v['cliente_nome'] ?? 'Consumidor Final';
                          final formaPgto = v['forma_pagamento'] ?? '';
                          final itens = v['itens'] ?? v['items'] as List? ?? [];

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey[200]!),
                            ),
                            child: ExpansionTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFFFD700),
                                child: Icon(Icons.receipt_long, color: Colors.black),
                              ),
                              title: Text('Venda #$id - $cliente', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text('Data: $data | Pagamento: ${_formatarFormaPagamento(formaPgto)}'),
                              trailing: Text('R\$ ${total.toStringAsFixed(2).replaceAll('.', ',')}', 
                                style: const TextStyle(fontWeight: FontWeight.w900, color: corTema, fontSize: 16)),
                              children: [
                                const Divider(height: 1),
                                Container(
                                  color: const Color(0xFFFAFAFA),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Column(
                                    children: [
                                      ...itens.map((item) {
                                        final nomeItem = item['nome'] ?? item['product_name'] ?? 'ITEM';
                                        final rawQtd = double.tryParse((item['quantidade'] ?? item['quantity'] ?? 1).toString()) ?? 1.0;
                                        final subtotalItem = double.tryParse((item['subtotal'] ?? item['price'] ?? 0).toString()) ?? 0.0;
                                        final unidade = (item['unidade'] ?? 'Unid').toString();

                                        String qtdTexto = unidade.toLowerCase() == 'kg'
                                            ? '${(rawQtd / 1000).toStringAsFixed(3)} kg'
                                            : '${rawQtd.toStringAsFixed(0)}x';

                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text("$qtdTexto $nomeItem", style: const TextStyle(fontWeight: FontWeight.bold)),
                                              Text("R\$ ${subtotalItem.toStringAsFixed(2).replaceAll('.', ',')}"),
                                            ],
                                          ),
                                        );
                                      }),
                                      const Divider(),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: corTema,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                          ),
                                          icon: const Icon(Icons.print, size: 18),
                                          label: const Text('REIMPRIMIR CUPOM (PDF)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                          onPressed: () => _reimprimirCupomPdf(v),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}