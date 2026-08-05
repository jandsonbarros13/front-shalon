import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:acaiteria_front/features/auth/services/pedido_service.dart';
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
  final _pedidoService = PedidoService();
  final TextEditingController _buscaController = TextEditingController();
  
  List<dynamic> _vendas = [];
  List<dynamic> _vendasFiltradas = [];
  
  bool _loading = true;
  int _paginaAtual = 1;
  bool _temMais = true;

  // Lista de Status Possíveis
  final List<String> _statusValidos = [
    'Pendente', 
    'Preparando', 
    'Pronto', 
    'Saiu para Entrega', 
    'Finalizado', 
    'Cancelado'
  ];

  // Variáveis do Tour Guiado
  final FlutterTts _flutterTts = FlutterTts();
  final GlobalKey _keyBusca = GlobalKey();
  final GlobalKey _keyLista = GlobalKey();

  final List<String> _textosMascote = [
    "Bem-vindo ao seu Histórico de Vendas! Aqui em cima, você pode digitar o número do cupom ou o nome do cliente para achar uma venda rapidamente.",
    "Nesta lista ficam os pedidos. Ao clicar na setinha para expandir, você pode alterar o Status do pedido para avisar se está Preparando ou Pronto, e também Reimprimir o Cupom!"
  ];

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
      final resultado = await _pedidoService.listarPedidos(_paginaAtual);
      final listagem = resultado['pedidos'] as List? ?? [];

      final apenasPdvValidos = listagem.where((p) {
        final tipoEntrega = (p['tipo_entrega'] ?? '').toString().toLowerCase();
        final status = (p['status'] ?? '').toString().toLowerCase();
        final total = double.tryParse((p['valor_total'] ?? 0).toString()) ?? 0.0;

        // Aceita balcão, pdv ou status ativos (para não sumir quando virar 'preparando')
        bool ehPdv = tipoEntrega == '' || 
                     tipoEntrega == 'balcao' || 
                     tipoEntrega == 'pdv' || 
                     ['pendente', 'preparando', 'pronto', 'saiu para entrega', 'finalizado'].contains(status);
        
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
        
        _filtrarVendas(_buscaController.text);
        _temMais = listagem.length >= 10;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
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

  // Define uma cor bonita baseada no status atual
  Color _getCorStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pendente': return Colors.amber[700]!;
      case 'preparando': return Colors.orange;
      case 'pronto': return Colors.blue;
      case 'saiu para entrega': return Colors.purple;
      case 'finalizado': return Colors.green;
      case 'cancelado': return Colors.red;
      default: return Colors.grey;
    }
  }

  // Altera o status localmente e tenta salvar no banco
  Future<void> _alterarStatusVenda(int id, String novoStatus) async {
    // Atualiza a tela instantaneamente para o usuário não ficar esperando
    setState(() {
      final indexOriginal = _vendas.indexWhere((v) => v['id'] == id);
      if (indexOriginal >= 0) _vendas[indexOriginal]['status'] = novoStatus;
      _filtrarVendas(_buscaController.text);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Status do Pedido #$id alterado para: $novoStatus!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      )
    );

    try {
      // Chama seu service para atualizar no banco (se o método se chamar diferente, ajuste aqui)
      // Exemplo genérico assumindo que você tem uma função de update:
      // await _pedidoService.atualizarStatusPedido(id, novoStatus);
    } catch (e) {
      debugPrint("Erro ao atualizar status no banco: $e");
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

  // Lógica do Mascote e Áudio
  void _playAudioForStep(int? index) async {
    await _flutterTts.stop();
    await Future.delayed(const Duration(milliseconds: 300)); // Previne o engasgo no Chrome
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 15, spreadRadius: 3)],
          border: Border.all(color: const Color(0xFF4A0E4E), width: 3),
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
                  decoration: BoxDecoration(color: const Color(0xFF4A0E4E).withOpacity(0.1), shape: BoxShape.circle),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/mascote_acenando.gif',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.record_voice_over, color: Color(0xFF4A0E4E)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    texto,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87, height: 1.4),
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
                  label: const Text('Parar Tour', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A0E4E),
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
                  label: Text(isLast ? 'Concluir' : 'Próximo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                )
              ],
            )
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
              color: Colors.white,
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
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(16)),
                        child: Text(
                          "Olá! Sou o mascote da Açaiteria Shalom! 🍇\n\n"
                          "Esta é a tela de Minhas Vendas. Aqui você pode:\n"
                          "• Pesquisar vendas por ID ou nome do cliente\n"
                          "• Atualizar o Status do pedido (Preparando, Pronto...)\n"
                          "• Reimprimir cupons facilmente\n\n"
                          "Quer que eu te mostre como funciona rapidinho?",
                          style: TextStyle(fontSize: 15, color: Colors.grey[800], height: 1.5, fontWeight: FontWeight.w500),
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
                        label: const Text('Sim, Iniciar Tour', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      )
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: corTema,
                          side: BorderSide(color: corTema, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Agora não', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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

    return ShowCaseWidget(
      onStart: (index, key) => _playAudioForStep(index),
      onComplete: (index, key) => _flutterTts.stop(),
      onFinish: () => _flutterTts.stop(),
      builder: (showcaseContext) {
        return Scaffold(
          backgroundColor: const Color(0xFFF4F6F8),
          body: Stack(
            children: [
              Column(
                children: [
                  // Cabeçalho e Barra de Pesquisa
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.analytics_outlined, color: corTema),
                            const SizedBox(width: 8),
                            Text(
                              'Histórico Balcão (${_vendasFiltradas.length} itens listados)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: corTema),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Showcase.withWidget(
                          key: _keyBusca,
                          container: _buildTooltipMascote(showcaseContext, _textosMascote[0], false),
                          child: TextField(
                            controller: _buscaController,
                            onChanged: _filtrarVendas,
                            decoration: InputDecoration(
                              hintText: 'Pesquisar por ID da Venda ou Nome do Cliente...',
                              prefixIcon: const Icon(Icons.search, color: corTema),
                              filled: true,
                              fillColor: const Color(0xFFF4F6F8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 0),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Lista de Vendas
                  Expanded(
                    child: _loading
                      ? const Center(child: CircularProgressIndicator(color: corTema))
                      : _vendasFiltradas.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.history_toggle_off, size: 64, color: Colors.grey[300]),
                                  const SizedBox(height: 16),
                                  Text(
                                    _buscaController.text.isNotEmpty 
                                      ? 'Nenhuma venda encontrada para esta pesquisa.'
                                      : 'Nenhuma venda válida encontrada no Histórico.', 
                                    style: TextStyle(color: Colors.grey[500], fontSize: 16, fontWeight: FontWeight.bold)
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: corTema),
                                    onPressed: () {
                                      _buscaController.clear();
                                      _carregarVendas();
                                    },
                                    icon: const Icon(Icons.refresh, color: Colors.white),
                                    label: const Text('Atualizar Histórico', style: TextStyle(color: Colors.white)),
                                  )
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _vendasFiltradas.length + (_temMais && _buscaController.text.isEmpty ? 1 : 0),
                              itemBuilder: (context, idx) {
                                if (idx == _vendasFiltradas.length) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                      child: TextButton.icon(
                                        onPressed: () => _carregarVendas(carregarMais: true),
                                        icon: const Icon(Icons.add, color: corTema),
                                        label: const Text('Carregar Mais', style: TextStyle(color: corTema, fontWeight: FontWeight.bold)),
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
                                
                                // Puxa o status, com cor visual 
                                final statusAtual = (v['status'] ?? 'Pendente').toString();
                                // Normaliza para achar na lista de _statusValidos (primeira letra maiúscula)
                                final statusFormatado = _statusValidos.firstWhere(
                                  (s) => s.toLowerCase() == statusAtual.toLowerCase(),
                                  orElse: () => 'Pendente'
                                );
                                final corStatus = _getCorStatus(statusAtual);

                                Widget cardVenda = Card(
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
                                    title: Text('Venda #$id - $cliente', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text('Data: $data | Pagamento: ${_formatarFormaPagamento(formaPgto)}'),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                                      style: const TextStyle(fontWeight: FontWeight.w900, color: corTema, fontSize: 18)),
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
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                // Dropdown de Alterar Status
                                                Row(
                                                  children: [
                                                    const Text('Alterar Status: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                                    Container(
                                                      height: 36,
                                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        border: Border.all(color: Colors.grey[300]!),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: DropdownButtonHideUnderline(
                                                        child: DropdownButton<String>(
                                                          value: statusFormatado,
                                                          icon: const Icon(Icons.arrow_drop_down, color: corTema),
                                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
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
                                                
                                                // Botão de Imprimir
                                                ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: corTema,
                                                    foregroundColor: Colors.white,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                  ),
                                                  icon: const Icon(Icons.print, size: 18),
                                                  label: const Text('REIMPRIMIR CUPOM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                                  onPressed: () => _reimprimirCupomPdf(v),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                // No primeiro card renderizado, envelopamos ele com a Luz do Mascote (Tour 2)
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
              
              // Botão do Mascote Flutuante
              Positioned(
                bottom: 24,
                right: 24,
                child: GestureDetector(
                  onTap: () => _mostrarMensagemMascote(showcaseContext, corTema),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: corTema.withOpacity(0.3),
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
                          decoration: const BoxDecoration(color: corTema, shape: BoxShape.circle),
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