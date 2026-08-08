import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:acaiteria_front/features/auth/services/produto_service.dart';
import 'package:acaiteria_front/features/auth/services/vendas_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:showcaseview/showcaseview.dart';

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
  final _emailClienteController = TextEditingController();
  final _focoCodigo = FocusNode();

  List<Map<String, dynamic>> _carrinho = [];
  Map<String, dynamic>? _produtoUltimoLancado;
  bool _buscando = false;
  double _descontoVenda = 0.0;
  bool _isDarkMode = true; 

  final FlutterTts _flutterTts = FlutterTts();
  final GlobalKey _keyBusca = GlobalKey();
  final GlobalKey _keyCarrinho = GlobalKey();
  final GlobalKey _keyAcoes = GlobalKey();
  final GlobalKey _keyFinalizar = GlobalKey();

  final List<String> _textosMascote = [
    "Bem-vindo ao Caixa! Na barra superior, digite o nome ou código do produto e aperte Enter. Escolha a quantidade e depois clique em Lançar.",
    "Aqui no centro ficam os itens do pedido. Você pode alterar as quantidades ou excluir algo que tenha lançado errado.",
    "No menu lateral, coloque os dados do cliente, incluindo o e-mail para novidades! Você também pode aplicar descontos, cancelar itens, cancelar a venda inteira ou lançar um Valor Avulso.",
    "Tudo certo? Confira o total e clique em Finalizar Venda para escolher a forma de pagamento e fechar o pedido!"
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
    _focoCodigo.requestFocus();
    _flutterTts.setLanguage("pt-BR");
  }

  @override
  void dispose() {
    _codigoInputController.dispose();
    _quantidadeController.dispose();
    _nomeClienteController.dispose();
    _telefoneClienteController.dispose();
    _emailClienteController.dispose();
    _focoCodigo.dispose();
    _flutterTts.stop();
    super.dispose();
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
                    _focoCodigo.requestFocus();
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
                      _focoCodigo.requestFocus();
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
                          "Neste Frente de Caixa (PDV) você pode:\n"
                          "• Buscar produtos e lançar no pedido\n"
                          "• Fazer Lançamento Avulso para vendas rápidas\n"
                          "• Inserir e-mail e WhatsApp do cliente\n"
                          "• Aplicar descontos ou cancelar itens/vendas\n\n"
                          "Quer fazer um Tour Guiado rápido para aprender tudo na prática?",
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
                            _keyCarrinho,
                            _keyAcoes,
                            _keyFinalizar,
                          ]);
                        },
                        icon: const Icon(Icons.slideshow, size: 24),
                        label: const Text('Iniciar Treinamento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _focoCodigo.requestFocus();
                        },
                        child: const Text('Apenas Ler (Sair)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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

  void _abrirModalVendaAvulsa() {
    final nomeController = TextEditingController(text: 'SORVETE');
    final valorController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Lançar Venda Avulsa (Direta)', style: TextStyle(color: accentColor, fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeController,
                textCapitalization: TextCapitalization.characters,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Descrição do Item',
                  labelStyle: TextStyle(color: textSecColor),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: valorController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
                decoration: InputDecoration(
                  labelText: 'Valor Total (R\$)',
                  labelStyle: TextStyle(color: textSecColor),
                  prefixText: 'R\$ ',
                  prefixStyle: const TextStyle(color: Colors.green, fontSize: 22, fontWeight: FontWeight.bold),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
              ),
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
      final resultado = await _produtoService.buscarProdutos(1, nome: termo, limit: 30, semFoto: false);
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
      
      final resAdicionais = await _produtoService.buscarProdutos(1, limit: 100, semFoto: false);
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
    int maxGratuitos = int.tryParse(acaiBase['max_adicionais_gratuitos']?.toString() ?? '0') ?? 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            double qtdProdutosBase = double.tryParse(pesoBaseController.text.replaceAll(',', '.')) ?? 0.0;
            double precoBaseUnitario = double.tryParse((acaiBase['price'] ?? 0).toString()) ?? 0.0;
            double subtotalBase = precoBaseUnitario * qtdProdutosBase;
            
            List<Map<String, dynamic>> singleAddons = [];
            for (var ad in adicionaisEscolhidos) {
              int count = ad['quantidade'].toInt();
              for (int i = 0; i < count; i++) {
                singleAddons.add(ad);
              }
            }
            singleAddons.sort((a, b) => (a['preco'] as double).compareTo(b['preco'] as double));

            double subtotalAdicionais = 0.0;
            for (int i = 0; i < singleAddons.length; i++) {
              if (i >= maxGratuitos) {
                subtotalAdicionais += singleAddons[i]['preco'];
              }
            }
            
            double totalDoItemMontado = subtotalBase + subtotalAdicionais;

            return AlertDialog(
              backgroundColor: cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MONTAGEM: ${(acaiBase['name'] ?? '').toString().toUpperCase()}',
                          style: TextStyle(color: accentColor, fontWeight: FontWeight.w900, fontSize: 18),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Total da Balança: R\$ ${nav(totalDoItemMontado)}',
                          style: const TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 160,
                    child: TextField(
                      controller: pesoBaseController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                      decoration: InputDecoration(
                        labelText: 'PESO (KG)',
                        labelStyle: TextStyle(fontSize: 11, color: accentColor, fontWeight: FontWeight.bold),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),
                  )
                ],
              ),
              content: SizedBox(
                width: 900,
                height: 600,
                child: Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Selecione os adicionais (Utilize + e - para alterar a quantidade):', style: TextStyle(fontWeight: FontWeight.bold, color: textSecColor)),
                              if (maxGratuitos > 0)
                                Text('Você tem $maxGratuitos opções grátis!', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView.builder(
                              itemCount: adicionais.length,
                              itemBuilder: (context, idx) {
                                final ad = adicionais[idx];
                                final precoAd = double.tryParse((ad['price'] ?? 0).toString()) ?? 0.0;
                                final idAd = ad['id'] ?? ad['ID'];
                                final unidade = (ad['unidade_medida'] ?? 'Unid').toString();
                                final String imgUrl = ad['image_url'] ?? ad['ImageURL'] ?? '';
                                final List<String> fotos = imgUrl.split('|||').where((s) => s.isNotEmpty).toList();

                                final idxEscolhido = adicionaisEscolhidos.indexWhere((item) => item['id'] == idAd);
                                double qtdAtual = idxEscolhido >= 0 ? adicionaisEscolhidos[idxEscolhido]['quantidade'] : 0.0;

                                return Card(
                                  elevation: 0,
                                  color: isDark 
                                    ? (idx % 2 == 0 ? const Color(0xFF1E1E2C) : const Color(0xFF2A2D3E))
                                    : (idx % 2 == 0 ? Colors.white : const Color(0xFFF8F9FA)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(color: qtdAtual > 0 ? accentColor : Colors.transparent, width: 1.5)
                                  ),
                                  margin: const EdgeInsets.symmetric(vertical: 3),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: SizedBox(
                                            width: 45, height: 45,
                                            child: fotos.isEmpty || fotos.first == 'null'
                                              ? Container(color: Colors.grey[300], child: const Icon(Icons.fastfood, color: Colors.grey))
                                              : (fotos.first.startsWith('data:image')
                                                  ? Image.memory(base64Decode(fotos.first.split(',')[1]), fit: BoxFit.cover)
                                                  : Image.network(fotos.first, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.broken_image)))
                                          )
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text((ad['name'] ?? '').toString().toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                                              const SizedBox(height: 2),
                                              Text('R\$ ${precoAd.toStringAsFixed(2)} / $unidade', style: TextStyle(color: textSecColor, fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          decoration: BoxDecoration(
                                            border: Border.all(color: isDark ? Colors.white24 : Colors.grey[300]!),
                                            borderRadius: BorderRadius.circular(8),
                                            color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              InkWell(
                                                onTap: qtdAtual > 0 ? () {
                                                  setModalState(() {
                                                    if (qtdAtual <= 1) {
                                                      adicionaisEscolhidos.removeAt(idxEscolhido);
                                                    } else {
                                                      adicionaisEscolhidos[idxEscolhido]['quantidade'] -= 1;
                                                    }
                                                  });
                                                } : null,
                                                borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                  child: Icon(Icons.remove, size: 20, color: qtdAtual > 0 ? Colors.red : Colors.grey[400]),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 30,
                                                child: Text('${qtdAtual.toInt()}', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: qtdAtual > 0 ? accentColor : Colors.grey)),
                                              ),
                                              InkWell(
                                                onTap: () {
                                                  setModalState(() {
                                                    if (idxEscolhido >= 0) {
                                                      adicionaisEscolhidos[idxEscolhido]['quantidade'] += 1;
                                                    } else {
                                                      adicionaisEscolhidos.add({
                                                        'id': idAd,
                                                        'nome': ad['name'] ?? '',
                                                        'preco': precoAd,
                                                        'quantidade': 1.0,
                                                        'unidade': unidade,
                                                      });
                                                    }
                                                  });
                                                },
                                                borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                                child: const Padding(
                                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                  child: Icon(Icons.add, size: 20, color: Colors.green),
                                                ),
                                              ),
                                            ],
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
                    VerticalDivider(width: 24, thickness: 1, color: isDark ? Colors.white10 : Colors.black12),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Resumo da Balança:', style: TextStyle(fontWeight: FontWeight.bold, color: textSecColor)),
                          const SizedBox(height: 8),
                          Text('• AÇAÍ BASE: ${qtdProdutosBase.toStringAsFixed(3)} kg', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                          Divider(color: isDark ? Colors.white10 : Colors.black12),
                          Expanded(
                            child: adicionaisEscolhidos.isEmpty
                              ? Center(child: Text('Nenhum adicional selecionado', style: TextStyle(color: isDark ? Colors.white30 : Colors.grey, fontStyle: FontStyle.italic)))
                              : ListView.builder(
                                  itemCount: adicionaisEscolhidos.length,
                                  itemBuilder: (context, i) {
                                    final item = adicionaisEscolhidos[i];
                                    final formatoQtd = item['quantidade'].toInt().toString();
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('• ', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
                                          Expanded(child: Text('${item['nome'].toString().toUpperCase()} (${item['unidade']})', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor))),
                                          Text('x$formatoQtd', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                        ],
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
                  style: ElevatedButton.styleFrom(backgroundColor: accentColor, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
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
    int maxGratuitos = int.tryParse(produto['max_adicionais_gratuitos']?.toString() ?? '0') ?? 0;
    
    setState(() {
      _produtoUltimoLancado = Map<String, dynamic>.from(produto);
      final idProduto = produto['id'] ?? produto['ID'];
      double precoBaseUnitario = double.tryParse((produto['price'] ?? 0).toString()) ?? 0.0;
      
      double subtotalItemCompleto = precoBaseUnitario * qtd;

      String nomeCompleto = '${(produto['name'] ?? '').toString().toUpperCase()} (${qtd.toStringAsFixed(3)} KG)';
      
      if (adicionais.isNotEmpty) {
        final nomesAdicionais = adicionais.map((a) => '${a['quantidade'].toInt()}x ${a['nome']}').join(', ');
        nomeCompleto += ' COM [$nomesAdicionais]';
        
        List<Map<String, dynamic>> singleAddons = [];
        for (var ad in adicionais) {
          int count = ad['quantidade'].toInt();
          for (int i = 0; i < count; i++) {
            singleAddons.add(ad);
          }
        }
        singleAddons.sort((a, b) => (a['preco'] as double).compareTo(b['preco'] as double));

        double subtotalAdicionais = 0.0;
        for (int i = 0; i < singleAddons.length; i++) {
          if (i >= maxGratuitos) {
            subtotalAdicionais += singleAddons[i]['preco'];
          }
        }
        subtotalItemCompleto += subtotalAdicionais;
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
    _focoCodigo.requestFocus();
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
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Selecione o Produto Base', style: TextStyle(color: accentColor, fontWeight: FontWeight.w900)),
          content: SizedBox(
            width: 500,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: produtos.length,
              itemBuilder: (context, idx) {
                final prod = produtos[idx];
                final preco = double.tryParse((prod['price'] ?? 0).toString()) ?? 0.0;
                final String imgUrl = prod['image_url'] ?? prod['ImageURL'] ?? '';
                final List<String> fotos = imgUrl.split('|||').where((s) => s.isNotEmpty).toList();

                return Card(
                  color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 40, height: 40,
                        child: fotos.isEmpty || fotos.first == 'null'
                          ? Container(color: Colors.grey[300], child: const Icon(Icons.fastfood, color: Colors.grey))
                          : (fotos.first.startsWith('data:image')
                              ? Image.memory(base64Decode(fotos.first.split(',')[1]), fit: BoxFit.cover)
                              : Image.network(fotos.first, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.broken_image)))
                      )
                    ),
                    title: Text((prod['name'] ?? '').toString().toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                    subtitle: Text('Categoria: ${prod['category']} | R\$ ${preco.toStringAsFixed(2)}', style: TextStyle(color: textSecColor)),
                    trailing: Icon(Icons.arrow_forward_ios, size: 16, color: accentColor),
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
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Aplicar Desconto (R\$)', style: TextStyle(color: accentColor, fontWeight: FontWeight.w900)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), 
            labelText: 'Valor do Desconto',
            labelStyle: TextStyle(color: textSecColor),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accentColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () {
              setState(() => _descontoVenda = double.tryParse(ctrl.text) ?? 0.0);
              Navigator.pop(context);
              _focoCodigo.requestFocus();
            },
            child: const Text('Aplicar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  void _addAoCarrinhoBotoes(Map<String, dynamic> item, double novaQtd) {
    setState(() { item['quantidade'] = novaQtd; });
  }

  void _mensagemPopup(String msg, Color col) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: col, behavior: SnackBarBehavior.floating));
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
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Venda Concluída!', style: TextStyle(fontWeight: FontWeight.w900, color: accentColor)),
          content: Text('Deseja gerar e imprimir o cupom desta venda?', style: TextStyle(color: textColor)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _limparCaixa();
              },
              child: const Text('NÃO', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
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
      _emailClienteController.clear();
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
            double valorRecebido = double.tryParse(valorRecebidoController.text.replaceAll(',', '.')) ?? _totalGeral;
            double troco = valorRecebido - _totalGeral;
            if (troco < 0) troco = 0;

            return AlertDialog(
              backgroundColor: cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('FECHAMENTO DE CAIXA', style: TextStyle(fontWeight: FontWeight.w900, color: accentColor)),
              content: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total da Venda: R\$ ${_totalGeral.toStringAsFixed(2).replaceAll('.', ',')}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textColor)),
                    const SizedBox(height: 24),
                    Text('Forma de Pagamento:', style: TextStyle(fontWeight: FontWeight.bold, color: textSecColor)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: formaSelecionada,
                      dropdownColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
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
                      const SizedBox(height: 24),
                      Text('Valor Entregue pelo Cliente:', style: TextStyle(fontWeight: FontWeight.bold, color: textSecColor)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: valorRecebidoController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), 
                          prefixText: 'R\$ ',
                          prefixStyle: TextStyle(color: textSecColor, fontSize: 22, fontWeight: FontWeight.bold)
                        ),
                        onChanged: (text) {
                          setDialogState(() {});
                        },
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E2C) : Colors.amber[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.withOpacity(0.5))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('TROCO:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: textColor)),
                            Text('R\$ ${troco.toStringAsFixed(2).replaceAll('.', ',')}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 28, color: Colors.red)),
                          ],
                        ),
                      )
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () { 
                    Navigator.pop(context); 
                    _focoCodigo.requestFocus(); 
                  }, 
                  child: const Text('VOLTAR', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: () async {
                    Navigator.pop(context);
                    setState(() => _buscando = true);

                    final nCliente = _nomeClienteController.text.trim().isEmpty ? 'Consumidor Final' : _nomeClienteController.text.trim();
                    final tCliente = _telefoneClienteController.text.trim();
                    final eCliente = _emailClienteController.text.trim();

                    final listaItensMapeados = _carrinho.map((item) => {
                      'produto_id': item['id'],
                      'quantidade': item['quantidade'],
                      'subtotal': item['preco'],
                      'nome_avulso': item['nome'],
                    }).toList();

                    final dadosVenda = {
                      'cliente_nome': nCliente,
                      'cliente_telefone': tCliente,
                      'cliente_email': eCliente,
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
                  child: const Text('EMITIR CUPOM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                )
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTextFieldCustomizado(TextEditingController controller, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: textSecColor, fontSize: 13),
          prefixIcon: Icon(icon, color: accentColor, size: 20),
          filled: true,
          fillColor: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF1F3F4),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _itemMenuCustom(String rotulo, VoidCallback click, Color colorBg, Color colorText) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorBg,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: click,
          child: Text(rotulo, style: TextStyle(color: colorText, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      onStart: (index, key) => _playAudioForStep(index),
      onComplete: (index, key) => _flutterTts.stop(),
      onFinish: () {
        _flutterTts.stop();
        _focoCodigo.requestFocus();
      },
      builder: (showcaseContext) {
        return Scaffold(
          backgroundColor: bgColor,
          body: Stack(
            children: [
              Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark 
                            ? [const Color(0xFF1E1E2C), const Color(0xFF2A2D3E)] 
                            : [accentColor, accentColor.withOpacity(0.8)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ],
                      border: Border(bottom: BorderSide(color: accentColor.withOpacity(0.5), width: 2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.menu, color: Colors.white, size: 28),
                              tooltip: 'Abrir Menu',
                              onPressed: () {
                                context.findRootAncestorStateOfType<ScaffoldState>()?.openDrawer();
                              },
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 45, height: 45,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(color: Colors.white.withOpacity(0.3), blurRadius: 8, spreadRadius: 1)
                                ],
                                image: const DecorationImage(image: AssetImage('assets/images/logo.jpg'), fit: BoxFit.cover),
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('AÇAITERIA SHALOM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16)),
                                Text('PONTO DE VENDA (PDV)', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 10)),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: Colors.white),
                              tooltip: 'Alternar Tema',
                              onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.greenAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.point_of_sale, color: Colors.greenAccent, size: 16),
                                  SizedBox(width: 8),
                                  Text('CAIXA ABERTO', style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                ],
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 320,
                          color: cardColor,
                          padding: const EdgeInsets.all(24),
                          child: Showcase.withWidget(
                            key: _keyAcoes,
                            container: _buildTooltipMascote(showcaseContext, _textosMascote[2], false),
                            child: Column(
                              children: [
                                Container(
                                  width: 130, height: 130,
                                  margin: const EdgeInsets.only(bottom: 30, top: 10),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: accentColor.withOpacity(0.3), blurRadius: 20, spreadRadius: 2)],
                                    border: Border.all(color: accentColor, width: 3),
                                    image: const DecorationImage(image: AssetImage('assets/images/logo.jpg'), fit: BoxFit.cover),
                                  ),
                                ),
                                _buildTextFieldCustomizado(_nomeClienteController, 'Nome do Cliente', Icons.person),
                                _buildTextFieldCustomizado(_telefoneClienteController, 'Telefone/WhatsApp', Icons.phone),
                                _buildTextFieldCustomizado(_emailClienteController, 'E-mail (Novidades/Recibos)', Icons.email),
                                
                                const Spacer(),
                                
                                _itemMenuCustom('LANÇAR VALOR AVULSO', _abrirModalVendaAvulsa, isDark ? Colors.green.withOpacity(0.2) : const Color(0xFFE8F5E9), Colors.green),
                                _itemMenuCustom('DESCONTO (R\$)', _abrirDialogDesconto, isDark ? Colors.orange.withOpacity(0.2) : Colors.orange[50]!, Colors.orange),
                                _itemMenuCustom('CANCELAR ITEM', () { if (_carrinho.isNotEmpty) setState(() => _carrinho.removeLast()); }, isDark ? Colors.red.withOpacity(0.1) : Colors.red[50]!, Colors.redAccent),
                                _itemMenuCustom('CANCELAR VENDA', () { setState(() { _carrinho.clear(); _produtoUltimoLancado = null; _descontoVenda = 0; _nomeClienteController.clear(); _telefoneClienteController.clear(); _emailClienteController.clear(); }); }, isDark ? Colors.red.withOpacity(0.2) : Colors.red[100]!, Colors.red),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(30),
                            child: Column(
                              children: [
                                Showcase.withWidget(
                                  key: _keyBusca,
                                  container: _buildTooltipMascote(showcaseContext, _textosMascote[0], false),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 4,
                                        child: TextField(
                                          controller: _codigoInputController,
                                          focusNode: _focoCodigo,
                                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                                          decoration: InputDecoration(
                                            labelText: 'CÓDIGO OU NOME DO PRODUTO (BASE)',
                                            labelStyle: TextStyle(fontSize: 13, color: textSecColor),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!)),
                                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!)),
                                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accentColor, width: 2)),
                                            filled: true, fillColor: cardColor,
                                            contentPadding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
                                          ),
                                          onSubmitted: (_) => _tentarLancarProduto(),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 1,
                                        child: TextField(
                                          controller: _quantidadeController,
                                          keyboardType: TextInputType.number,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                                          decoration: InputDecoration(
                                            labelText: 'PESO (KG)',
                                            labelStyle: TextStyle(fontSize: 13, color: textSecColor),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!)),
                                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!)),
                                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accentColor, width: 2)),
                                            filled: true, fillColor: cardColor,
                                            contentPadding: const EdgeInsets.symmetric(vertical: 22),
                                          ),
                                          onSubmitted: (_) => _tentarLancarProduto(),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: accentColor,
                                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 22),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                        ),
                                        onPressed: _tentarLancarProduto,
                                        child: const Text('LANÇAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
                                      )
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 30),
                                Expanded(
                                  child: Showcase.withWidget(
                                    key: _keyCarrinho,
                                    container: _buildTooltipMascote(showcaseContext, _textosMascote[1], false),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!, width: 2),
                                        borderRadius: BorderRadius.circular(16),
                                        color: cardColor,
                                      ),
                                      child: _carrinho.isEmpty
                                        ? Center(child: Text('CAIXA AGUARDANDO LANÇAMENTO...', style: TextStyle(color: isDark ? Colors.white30 : Colors.grey[400], fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 16)))
                                        : Column(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                                decoration: BoxDecoration(
                                                  border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!, width: 2)),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Text('ITEM', style: TextStyle(fontWeight: FontWeight.bold, color: textSecColor, fontSize: 12)),
                                                    const Spacer(),
                                                    Text('QTD', style: TextStyle(fontWeight: FontWeight.bold, color: textSecColor, fontSize: 12)),
                                                    const SizedBox(width: 80),
                                                    Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, color: textSecColor, fontSize: 12)),
                                                    const SizedBox(width: 60),
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                child: ListView.builder(
                                                  itemCount: _carrinho.length,
                                                  itemBuilder: (context, idx) {
                                                    final item = _carrinho[idx];
                                                    return Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                                      decoration: BoxDecoration(
                                                        color: isDark 
                                                          ? (idx % 2 == 0 ? Colors.transparent : const Color(0xFF1E1E2C))
                                                          : (idx % 2 == 0 ? Colors.transparent : const Color(0xFFF9F9F9)),
                                                        border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFEEEEEE))),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Container(
                                                            width: 30, height: 30,
                                                            alignment: Alignment.center,
                                                            decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                                            child: Text('${idx + 1}', style: TextStyle(fontWeight: FontWeight.w900, color: accentColor)),
                                                          ),
                                                          const SizedBox(width: 20),
                                                          Expanded(child: Text(item['nome'].toString().toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor))),
                                                          Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              IconButton(
                                                                icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 24),
                                                                onPressed: () {
                                                                  if (item['quantidade'] > 1) {
                                                                    _addAoCarrinhoBotoes(item, item['quantidade'] - 1);
                                                                  } else {
                                                                    setState(() => _carrinho.removeAt(idx));
                                                                  }
                                                                },
                                                              ),
                                                              SizedBox(width: 30, child: Text('${item['quantidade'].toStringAsFixed(0)}', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: textColor))),
                                                              IconButton(
                                                                icon: const Icon(Icons.add_circle_outline, color: Colors.green, size: 24),
                                                                onPressed: () => _addAoCarrinhoBotoes(item, item['quantidade'] + 1),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(width: 40),
                                                          SizedBox(
                                                            width: 100,
                                                            child: Text('R\$ ${(item['preco'] * item['quantidade']).toStringAsFixed(2).replaceAll('.', ',')}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: accentColor), textAlign: TextAlign.right),
                                                          ),
                                                          const SizedBox(width: 20),
                                                          IconButton(
                                                            icon: const Icon(Icons.delete_forever, color: Colors.red, size: 24),
                                                            onPressed: () => setState(() => _carrinho.removeAt(idx)),
                                                          )
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 30),
                                Showcase.withWidget(
                                  key: _keyFinalizar,
                                  container: _buildTooltipMascote(showcaseContext, _textosMascote[3], true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 25),
                                    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 20, offset: const Offset(0, 5))]),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Subtotal: R\$ ${_subtotal.toStringAsFixed(2).replaceAll('.', ',')}', style: TextStyle(fontSize: 16, color: textSecColor, fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 4),
                                            Text('Desconto: R\$ ${_descontoVenda.toStringAsFixed(2).replaceAll('.', ',')}', style: const TextStyle(fontSize: 16, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            Text('TOTAL: ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textSecColor)),
                                            Text('R\$ ${_totalGeral.toStringAsFixed(2).replaceAll('.', ',')}', style: TextStyle(fontSize: 50, fontWeight: FontWeight.w900, color: accentColor)),
                                          ],
                                        ),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFFFD700),
                                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 25),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                          ),
                                          onPressed: _finalizarVenda,
                                          icon: const Icon(Icons.check_circle, color: Colors.black, size: 28),
                                          label: const Text('FINALIZAR VENDA', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1)),
                                        )
                                      ],
                                    ),
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
              Positioned(
                bottom: 120, 
                right: 40,
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
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                          child: const Icon(Icons.help_outline, color: Colors.white, size: 40),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}