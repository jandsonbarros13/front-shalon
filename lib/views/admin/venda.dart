import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:acaiteria_front/features/auth/services/produto_service.dart';
import 'package:acaiteria_front/features/auth/services/vendas_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class VendaPage extends StatefulWidget {
  const VendaPage({super.key});

  @override
  State<VendaPage> createState() => _VendaPageState();
}

class _VendaPageState extends State<VendaPage> {
  final _produtoService = ProdutoService();
  final _vendasService = VendasService();
  final _codigoInputController = TextEditingController();
  final _quantidadeController = TextEditingController(text: '1.000');
  final _nomeClienteController = TextEditingController();
  final _telefoneClienteController = TextEditingController();
  final _focoCodigo = FocusNode();

  List<Map<String, dynamic>> _carrinho = [];
  Map<String, dynamic>? _produtoUltimoLancado;
  bool _buscando = false;
  double _descontoVenda = 0.0;

  static const Color corTema = Color(0xFF4A0E4E);

  @override
  void initState() {
    super.initState();
    _focoCodigo.requestFocus();
  }

  @override
  void dispose() {
    _codigoInputController.dispose();
    _quantidadeController.dispose();
    _nomeClienteController.dispose();
    _telefoneClienteController.dispose();
    _focoCodigo.dispose();
    super.dispose();
  }

  void _abrirModalVendaAvulsa() {
    final nomeController = TextEditingController(text: 'SORVETE');
    final valorController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Lançar Venda Avulsa (Direta)', style: TextStyle(color: corTema, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Descrição do Item',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: valorController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
                decoration: const InputDecoration(
                  labelText: 'Valor Total (R\$)',
                  prefixText: 'R\$ ',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) {
                  final double? valor = double.tryParse(valorController.text.replaceAll(',', '.'));
                  if (valor != null && valor > 0) {
                    _inserirAvulsoNoCarrinho(nomeController.text.trim(), valor);
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: corTema),
              onPressed: () {
                final double? valor = double.tryParse(valorController.text.replaceAll(',', '.'));
                if (valor == null || valor <= 0) {
                  _mensagemPopup('Digite um valor válido!', Colors.red);
                  return;
                }
                _inserirAvulsoNoCarrinho(nomeController.text.trim(), valor);
                Navigator.pop(context);
              },
              child: const Text('LANÇAR NO CAIXA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        );
      },
    );
  }

  void _inserirAvulsoNoCarrinho(String nome, double valor) {
    setState(() {
      _carrinho.add({
        'id': 0,
        'nome': nome.isEmpty ? 'ITEM AVULSO' : nome.toUpperCase(),
        'preco': valor,
        'quantidade': 1.0,
        'image_url': '',
      });
    });
    _focoCodigo.requestFocus();
  }

  Future<void> _tentarLancarProduto() async {
    final termo = _codigoInputController.text.trim();
    if (termo.isEmpty) return;

    final double qtd = double.tryParse(_quantidadeController.text.replaceAll(',', '.')) ?? 1.0;

    setState(() => _buscando = true);

    try {
      final resultado = await _produtoService.buscarProdutos(1, nome: termo, limit: 30, semFoto: true);
      final List<dynamic> produtosEncontrados = resultado['produtos'] ?? [];

      if (produtosEncontrados.isEmpty) {
        _mensagemPopup('Nenhum produto encontrado!', Colors.red);
      } else if (produtosEncontrados.length == 1) {
        _verificarMontagemProduto(produtosEncontrados.first, qtd);
      } else {
        _abrirModalSelecaoProduto(produtosEncontrados, qtd);
      }
    } catch (_) {
      _mensagemPopup('Erro ao buscar produtos no servidor!', Colors.red);
    } finally {
      setState(() => _buscando = false);
      _focoCodigo.requestFocus();
    }
  }

  void _verificarMontagemProduto(dynamic produto, double qtd) async {
    final category = (produto['category'] ?? produto['Category'] ?? '').toString().toLowerCase();
    final nome = (produto['name'] ?? '').toString().toLowerCase();

    if (category.contains('montados') || category.contains('açai') || category.contains('açaí') || nome.contains('açai') || nome.contains('cupuaçu')) {
      setState(() => _buscando = true);
      
      final resAdicionais = await _produtoService.buscarProdutos(1, limit: 100, semFoto: true);
      final List<dynamic> todosProdutos = resAdicionais['produtos'] ?? [];
      
      final adicionaisDisponiveis = todosProdutos.where((p) {
        final cat = (p['category'] ?? p['Category'] ?? '').toString().toLowerCase();
        return cat.contains('adicional') || cat.contains('adicionais');
      }).toList();

      setState(() => _buscando = false);
      _abrirModalMontagemAcai(produto, adicionaisDisponiveis, qtd);
    } else {
      _inserirNoCarrinho(produto, qtd, []);
    }
  }

  void _abrirModalMontagemAcai(dynamic acaiBase, List<dynamic> adicionais, double qtdInicial) {
    List<Map<String, dynamic>> adicionaisEscolhidos = [];
    
    final pesoBaseController = TextEditingController(text: qtdInicial.toStringAsFixed(3).replaceAll('.', ','));
    final Map<int, TextEditingController> controladoresAdicionais = {};

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            double qtdProdutosBase = double.tryParse(pesoBaseController.text.replaceAll(',', '.')) ?? 0.0;
            double precoBaseUnitario = double.tryParse((acaiBase['price'] ?? 0).toString()) ?? 0.0;
            
            double subtotalBase = precoBaseUnitario * qtdProdutosBase;
            
            double subtotalAdicionais = 0.0;
            for (var ad in adicionaisEscolhidos) {
              subtotalAdicionais += (ad['preco'] * ad['quantidade']);
            }
            
            double totalDoItemMontado = subtotalBase + subtotalAdicionais;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MONTAGEM DE CARDÁPIO: ${(acaiBase['name'] ?? '').toString().toUpperCase()}',
                        style: const TextStyle(color: corTema, fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total da Balança: R\$ ${nav(totalDoItemMontado)}',
                        style: const TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(
                    width: 160,
                    child: TextField(
                      controller: pesoBaseController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: corTema),
                      decoration: InputDecoration(
                        labelText: 'PESO AÇAÍ (KG)',
                        labelStyle: const TextStyle(fontSize: 11, color: corTema, fontWeight: FontWeight.bold),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),
                  )
                ],
              ),
              content: SizedBox(
                width: 850,
                height: 500,
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Digite o peso ou quantidade dos adicionais:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView.builder(
                              itemCount: adicionais.length,
                              itemBuilder: (context, idx) {
                                final ad = adicionais[idx];
                                final precoAd = double.tryParse((ad['price'] ?? 0).toString()) ?? 0.0;
                                final idAd = ad['id'] ?? ad['ID'];
                                final unidade = (ad['unidade_medida'] ?? 'Unid').toString();
                                
                                final idxEscolhido = adicionaisEscolhidos.indexWhere((item) => item['id'] == idAd);
                                
                                if (!controladoresAdicionais.containsKey(idAd)) {
                                  controladoresAdicionais[idAd] = TextEditingController(text: '0,000');
                                }

                                return Card(
                                  elevation: 0,
                                  color: idx % 2 == 0 ? Colors.white : const Color(0xFFF8F9FA),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(color: idxEscolhido >= 0 ? corTema : Colors.grey[200]!, width: 1)
                                  ),
                                  margin: const EdgeInsets.symmetric(vertical: 3),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            dense: true,
                                            title: Text((ad['name'] ?? '').toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                            subtitle: Text('R\$ ${precoAd.toStringAsFixed(2)} / $unidade'),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 120,
                                          child: TextField(
                                            controller: controladoresAdicionais[idAd],
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                            decoration: InputDecoration(
                                              hintText: '0,000',
                                              suffixText: unidade.toLowerCase() == 'grama' || unidade.toLowerCase() == 'kg' ? 'kg' : 'un',
                                              contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                              border: const OutlineInputBorder(),
                                            ),
                                            onChanged: (text) {
                                              final double val = double.tryParse(text.replaceAll(',', '.')) ?? 0.0;
                                              setModalState(() {
                                                if (val > 0) {
                                                  if (idxEscolhido >= 0) {
                                                    adicionaisEscolhidos[idxEscolhido]['quantidade'] = val;
                                                  } else {
                                                    adicionaisEscolhidos.add({
                                                      'id': idAd,
                                                      'nome': ad['name'] ?? '',
                                                      'preco': precoAd,
                                                      'quantidade': val,
                                                      'unidade': unidade,
                                                    });
                                                  }
                                                } else {
                                                  if (idxEscolhido >= 0) {
                                                    adicionaisEscolhidos.removeAt(idxEscolhido);
                                                  }
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const VerticalDivider(width: 24, thickness: 1),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Resumo da Balança:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 8),
                          Text('• AÇAÍ BASE: ${qtdProdutosBase.toStringAsFixed(3)} kg', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                          const Divider(),
                          Expanded(
                            child: adicionaisEscolhidos.isEmpty
                              ? const Center(child: Text('Nenhum adicional pesado', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)))
                              : ListView.builder(
                                  itemCount: adicionaisEscolhidos.length,
                                  itemBuilder: (context, i) {
                                    final item = adicionaisEscolhidos[i];
                                    final formatoQtd = item['quantidade'].toStringAsFixed(3);
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Text(
                                        '• ${item['nome'].toString().toUpperCase()}: $formatoQtd ${item['unidade']}',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: corTema),
                                      ),
                                    );
                                  },
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCELAR', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: corTema, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                  onPressed: () {
                    _inserirNoCarrinho(acaiBase, qtdProdutosBase, adicionaisEscolhidos);
                    Navigator.pop(context);
                  },
                  child: const Text('CONFIRMAR PESAGEM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              ],
            );
          },
        );
      },
    );
  }

  String nav(double valor) {
    return valor.toStringAsFixed(2).replaceAll('.', ',');
  }

  void _inserirNoCarrinho(dynamic produto, double qtd, List<Map<String, dynamic>> adicionais) {
    setState(() {
      _produtoUltimoLancado = Map<String, dynamic>.from(produto);
      final idProduto = produto['id'] ?? produto['ID'];
      double precoBaseUnitario = double.tryParse((produto['price'] ?? 0).toString()) ?? 0.0;
      
      double subtotalItemCompleto = precoBaseUnitario * qtd;

      String nomeCompleto = '${(produto['name'] ?? '').toString().toUpperCase()} (${qtd.toStringAsFixed(3)} KG)';
      if (adicionais.isNotEmpty) {
        final nomesAdicionais = adicionais.map((a) => '${a['quantidade'].toStringAsFixed(3)} ${a['unidade']} de ${a['nome']}').join(', ');
        nomeCompleto += ' COM [$nomesAdicionais]';
        for (var ad in adicionais) {
          subtotalItemCompleto += (ad['preco'] * ad['quantidade']);
        }
      }

      _carrinho.add({
        'id': idProduto,
        'nome': nomeCompleto,
        'preco': subtotalItemCompleto,
        'quantidade': 1.0, 
        'image_url': produto['image_url'] ?? '',
      });
      
      _codigoInputController.clear();
      _quantidadeController.text = '1.000';
    });
  }

  Future<void> _gerarCupomBalcaoPdf(String idVenda, String cliente, String telefone, String formaPgto) async {
    final pdf = pw.Document();
    
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
              pw.Center(child: pw.Text('VENDA DE BALCÃO (PDV)', style: const pw.TextStyle(fontSize: 9))),
              pw.SizedBox(height: 6),
              pw.Text('CUPOM DOC #$idVenda', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.Text('CLIENTE: $cliente', style: const pw.TextStyle(fontSize: 10)),
              if (telefone.isNotEmpty) pw.Text('FONE: $telefone', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('PAGAMENTO: $formaPgto', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.Center(child: pw.Text('ITENS DO CUPOM', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
              pw.SizedBox(height: 4),
              ..._carrinho.map((item) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(item['nome'].toString().toUpperCase(), style: const pw.TextStyle(fontSize: 9)),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Total do Item:', style: pw.TextStyle(color: PdfColors.grey700, fontSize: 9)),
                          pw.Text('R\$ ${item['preco'].toStringAsFixed(2).replaceAll('.', ',')}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              if (_descontoVenda > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('DESCONTO:', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('-R\$ ${_descontoVenda.toStringAsFixed(2).replaceAll('.', ',')}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL GERAL:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text('R\$ ${_totalGeral.toStringAsFixed(2).replaceAll('.', ',')}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 15),
              pw.Center(child: pw.Text('Obrigado pela preferência!', style: const pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic))),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'Cupom_PDV_$idVenda.pdf');
  }

  void _abrirModalSelecaoProduto(List<dynamic> produtos, double qtd) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Selecione o Produto Base', style: TextStyle(color: corTema, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 500,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: produtos.length,
              itemBuilder: (context, idx) {
                final prod = produtos[idx];
                final preco = double.tryParse((prod['price'] ?? 0).toString()) ?? 0.0;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text((prod['name'] ?? '').toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Categoria: ${prod['category']} | R\$ ${preco.toStringAsFixed(2)}'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: corTema),
                    onTap: () {
                      Navigator.pop(context);
                      _verificarMontagemProduto(prod, qtd);
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () { Navigator.pop(context); _focoCodigo.requestFocus(); },
              child: const Text('CANCELAR', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            )
          ],
        );
      },
    );
  }

  void _abrirDialogDesconto() {
    final ctrl = TextEditingController(text: _descontoVenda.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aplicar Desconto (R\$)', style: TextStyle(color: corTema, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Valor do Desconto'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: corTema),
            onPressed: () {
              setState(() => _descontoVenda = double.tryParse(ctrl.text) ?? 0.0);
              Navigator.pop(context);
            },
            child: const Text('Aplicar', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _addAoCarrinhoBotoes(Map<String, dynamic> item, double novaQtd) {
    setState(() { item['quantidade'] = novaQtd; });
  }

  void _mensagemPopup(String msg, Color col) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: col));
  }

  double get _subtotal {
    return _carrinho.fold(0.0, (total, item) => total + (item['preco'] * item['quantidade']));
  }

  double get _totalGeral {
    double res = _subtotal - _descontoVenda;
    return res < 0 ? 0 : res;
  }

  void _abrirModalConfirmacaoCupom(String idVenda, String cliente, String telefone, String formaPgto) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Venda Concluída!', style: TextStyle(fontWeight: FontWeight.bold, color: corTema)),
          content: const Text('Deseja gerar e imprimir o cupom desta venda?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _limparCaixa();
              },
              child: const Text('NÃO', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () async {
                Navigator.pop(context);
                await _gerarCupomBalcaoPdf(idVenda, cliente, telefone, formaPgto);
                _limparCaixa();
              },
              child: const Text('SIM, IMPRIMIR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _limparCaixa() {
    setState(() {
      _carrinho.clear();
      _produtoUltimoLancado = null;
      _descontoVenda = 0;
      _nomeClienteController.clear();
      _telefoneClienteController.clear();
    });
    _focoCodigo.requestFocus();
  }

  void _finalizarVenda() async {
    if (_carrinho.isEmpty) return;

    String formaSelecionada = 'Dinheiro';
    final valorRecebidoController = TextEditingController(text: _totalGeral.toStringAsFixed(2));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            double valorRecebido = double.tryParse(valorRecebidoController.text) ?? _totalGeral;
            double troco = valorRecebido - _totalGeral;
            if (troco < 0) troco = 0;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('FECHAMENTO DE CAIXA', style: TextStyle(fontWeight: FontWeight.w900, color: corTema)),
              content: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total da Venda: R\$ ${_totalGeral.toStringAsFixed(2).replaceAll('.', ',')}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    const Text('Forma de Pagamento:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: formaSelecionada,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'Dinheiro', child: Text('💵 DINHEIRO')),
                        DropdownMenuItem(value: 'Credito', child: Text('💳 CARTÃO DE CRÉDITO')),
                        DropdownMenuItem(value: 'Debito', child: Text('💳 CARTÃO DE DÉBITO')),
                        DropdownMenuItem(value: 'Pix', child: Text('📱 PIX')),
                      ],
                      onChanged: (val) {
                        setDialogState(() {
                          formaSelecionada = val ?? 'Dinheiro';
                        });
                      },
                    ),
                    if (formaSelecionada == 'Dinheiro') ...[
                      const SizedBox(height: 20),
                      const Text('Valor Entregue pelo Cliente:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: valorRecebidoController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(border: OutlineInputBorder(), prefixText: 'R\$ '),
                        onChanged: (text) {
                          setDialogState(() {});
                        },
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('TROCO:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                            Text('R\$ ${troco.toStringAsFixed(2).replaceAll('.', ',')}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Colors.red)),
                          ],
                        ),
                      )
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('VOLTAR', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
                  onPressed: () async {
                    Navigator.pop(context);
                    setState(() => _buscando = true);

                    final nCliente = _nomeClienteController.text.trim().isEmpty ? 'Consumidor Final' : _nomeClienteController.text.trim();
                    final tCliente = _telefoneClienteController.text.trim();

                    final listaItensMapeados = _carrinho.map((item) => {
                      'produto_id': item['id'],
                      'quantidade': item['quantidade'],
                      'subtotal': item['preco'],
                      'nome_avulso': item['nome'],
                    }).toList();

                    final dadosVenda = {
                      'cliente_nome': nCliente,
                      'cliente_telefone': tCliente,
                      'tipo_entrega': 'Balcao',
                      'status': 'Finalizado',
                      'forma_pagamento': formaSelecionada,
                      'desconto': _descontoVenda,
                      'valor_total': _totalGeral,
                      'itens': listaItensMapeados,
                    };

                    final resposta = await _vendasService.finalizarVendaBalcao(dadosVenda);

                    setState(() => _buscando = false);

                    if (resposta['success'] == true || resposta['id'] != null) {
                      final String idVendaCriada = (resposta['id'] ?? 'NF').toString();
                      _mensagemPopup('Venda salva com sucesso!', Colors.green);
                      _abrirModalConfirmacaoCupom(idVendaCriada, nCliente, tCliente, formaSelecionada);
                    } else {
                      _mensagemPopup(resposta['message'] ?? 'Erro ao salvar venda.', Colors.red);
                      _focoCodigo.requestFocus();
                    }
                  },
                  child: const Text('EMITIR CUPOM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                )
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            color: corTema,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('AÇAITERIA SHALOM - PDV PROFISSIONAL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                Row(
                  children: [
                    Icon(Icons.circle, color: Colors.greenAccent, size: 12),
                    SizedBox(width: 8),
                    Text('SISTEMA ONLINE', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                )
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 300,
                  color: const Color(0xFFF8F9FA),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        width: 120, height: 120,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: corTema, width: 2),
                          image: const DecorationImage(image: AssetImage('assets/images/logo.jpg'), fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _nomeClienteController,
                        decoration: const InputDecoration(labelText: 'Nome do Cliente', prefixIcon: Icon(Icons.person, color: corTema)),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _telefoneClienteController,
                        decoration: const InputDecoration(labelText: 'Telefone/WhatsApp', prefixIcon: Icon(Icons.phone, color: corTema)),
                      ),
                      const Spacer(),
                      _itemMenu('LANÇAR VALOR AVULSO', _abrirModalVendaAvulsa, const Color(0xFFE8F5E9)),
                      _itemMenu('DESCONTO (R\$)', _abrirDialogDesconto, Colors.orange[50]),
                      _itemMenu('CANCELAR ITEM', () { if (_carrinho.isNotEmpty) setState(() => _carrinho.removeLast()); }, Colors.red[50]),
                      _itemMenu('CANCELAR VENDA', () { setState(() { _carrinho.clear(); _produtoUltimoLancado = null; _descontoVenda = 0; }); }, Colors.red[100]),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(25),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: TextField(
                                controller: _codigoInputController,
                                focusNode: _focoCodigo,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                decoration: const InputDecoration(
                                  labelText: 'CÓDIGO OU NOME DO PRODUTO (BASE)',
                                  labelStyle: TextStyle(fontSize: 14),
                                  border: OutlineInputBorder(),
                                  filled: true, fillColor: Color(0xFFF1F3F4),
                                ),
                                onSubmitted: (_) => _tentarLancarProduto(),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              flex: 1,
                              child: TextField(
                                controller: _quantidadeController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                decoration: const InputDecoration(labelText: 'PESO (KG)', border: OutlineInputBorder()),
                                onSubmitted: (_) => _tentarLancarProduto(),
                              ),
                            ),
                            const SizedBox(width: 15),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: corTema,
                                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 25),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                              ),
                              onPressed: _tentarLancarProduto,
                              child: const Text('LANÇAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                            )
                          ],
                        ),
                        const SizedBox(height: 25),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[200]!),
                              color: const Color(0xFFFCFCFC),
                            ),
                            child: _carrinho.isEmpty
                              ? Center(child: Text('CAIXA AGUARDANDO LANÇAMENTO...', style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold, letterSpacing: 2)))
                              : ListView.builder(
                                  itemCount: _carrinho.length,
                                  itemBuilder: (context, idx) {
                                    final item = _carrinho[idx];
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                                      decoration: BoxDecoration(
                                        color: idx % 2 == 0 ? Colors.white : const Color(0xFFF9F9F9),
                                        border: const Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
                                      ),
                                      child: Row(
                                        children: [
                                          Text('${idx + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: corTema)),
                                          const SizedBox(width: 20),
                                          Expanded(child: Text(item['nome'].toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                                                onPressed: () {
                                                  if (item['quantidade'] > 1) {
                                                    _addAoCarrinhoBotoes(item, item['quantidade'] - 1);
                                                  } else {
                                                    setState(() => _carrinho.removeAt(idx));
                                                  }
                                                },
                                              ),
                                              Text('${item['quantidade'].toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                              IconButton(
                                                icon: const Icon(Icons.add_circle_outline, color: Colors.green, size: 20),
                                                onPressed: () => _addAoCarrinhoBotoes(item, item['quantidade'] + 1),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 30),
                                          Text('R\$ ${(item['preco'] * item['quantidade']).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: corTema)),
                                          const SizedBox(width: 10),
                                          IconButton(
                                            icon: const Icon(Icons.delete_forever, color: Colors.red, size: 20),
                                            onPressed: () => setState(() => _carrinho.removeAt(idx)),
                                          )
                                        ],
                                      ),
                                    );
                                  },
                                ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Subtotal: R\$ ${_subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, color: Colors.grey)),
                                  Text('Desconto: R\$ ${_descontoVenda.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, color: Colors.red)),
                                ],
                              ),
                              Row(
                                children: [
                                  const Text('TOTAL: ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey)),
                                  Text('R\$ ${_totalGeral.toStringAsFixed(2).replaceAll('.', ',')}', style: const TextStyle(fontSize: 50, fontWeight: FontWeight.w900, color: corTema)),
                                ],
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFD700),
                                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 25),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                ),
                                onPressed: _finalizarVenda,
                                icon: const Icon(Icons.check_circle, color: Colors.black, size: 30),
                                label: const Text('FINALIZAR VENDA', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _itemMenu(String rotulo, VoidCallback click, Color? fundo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        height: 45,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: fundo,
            elevation: 0,
            side: BorderSide(color: Colors.grey[300]!),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: click,
          child: Text(rotulo, style: const TextStyle(color: corTema, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ),
    );
  }
}