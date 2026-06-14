import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:acaiteria_front/core/constants/api_constants.dart';
import 'carrinho_page.dart';

class CatalogoClientePage extends StatefulWidget {
  final String chaveUrl;

  const CatalogoClientePage({super.key, required this.chaveUrl});

  @override
  State<CatalogoClientePage> createState() => _CatalogoClientePageState();
}

class _CatalogoClientePageState extends State<CatalogoClientePage> {
  bool _isLoading = true;
  Map<String, dynamic>? _catalogo;
  int? _hoveredIndex;
  
  final Map<int, double> _carrinho = {};
  final Map<int, String> _observacoes = {};
  final Map<int, List<int>> _adicionaisEscolhidosPorItem = {};

  String _categoriaSelecionada = 'Tudo';
  final List<String> _abasFiltro = ['Tudo', 'Montados', 'Combos', 'Bebidas', 'Produtos'];

  int _paginaAtual = 1;
  final int _itensPorPagina = 12;

  bool _isSearching = false;
  String _termoBusca = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregarCatalogo();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _hexToColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return const Color(0xFF4A0E4E); 
    }
  }

  Future<void> _carregarCatalogo() async {
    try {
      String urlBaseLimpa = ApiConstants.baseUrl.trim();
      if (urlBaseLimpa.endsWith('/')) {
        urlBaseLimpa = urlBaseLimpa.substring(0, urlBaseLimpa.length - 1);
      }
      if (urlBaseLimpa.endsWith('/api')) {
        urlBaseLimpa = urlBaseLimpa.substring(0, urlBaseLimpa.length - 4);
      }

      final url = Uri.parse('$urlBaseLimpa/api/catalogo-publico/${widget.chaveUrl}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          _catalogo = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _atualizarCarrinho(int id, double quantidade, String obs, List<int> adicionaisIds) {
    setState(() {
      if (quantidade <= 0) {
        _carrinho.remove(id);
        _observacoes.remove(id);
        _adicionaisEscolhidosPorItem.remove(id);
      } else {
        _carrinho[id] = quantidade;
        if (obs.isNotEmpty) {
          _observacoes[id] = obs;
        } else {
          _observacoes.remove(id);
        }
        if (adicionaisIds.isNotEmpty) {
          _adicionaisEscolhidosPorItem[id] = List.from(adicionaisIds);
        } else {
          _adicionaisEscolhidosPorItem.remove(id);
        }
      }
    });
  }

  Future<void> _abrirCarrinho() async {
    if (_carrinho.isEmpty) return;

    final pedidoFinalizado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CarrinhoPage(
          catalogo: _catalogo!,
          carrinho: _carrinho,
          observacoes: _observacoes,
          adicionaisEscolhidos: _adicionaisEscolhidosPorItem,
        ),
      ),
    );

    if (pedidoFinalizado == true) {
      setState(() {
        _carrinho.clear();
        _observacoes.clear();
        _adicionaisEscolhidosPorItem.clear();
      });
    } else {
      setState(() {});
    }
  }

  int get _quantidadeTotalItens {
    int total = 0;
    if (_catalogo != null && _catalogo!['produtos'] != null) {
      for (var p in _catalogo!['produtos']) {
        int id = p['id'] ?? p['ID'];
        if (_carrinho.containsKey(id) && _carrinho[id]! > 0) {
          String un = (p['unidade_medida'] ?? '').toString().toLowerCase();
          if (un == 'kg' || un == 'grama' || un == 'g') {
            total += 1; 
          } else {
            total += _carrinho[id]!.toInt(); 
          }
        }
      }
    }
    return total;
  }

  double get _valorTotalCarrinho {
    double total = 0.0;
    if (_catalogo != null && _catalogo!['produtos'] != null) {
      final List<dynamic> todos = _catalogo!['produtos'];
      for (var p in todos) {
        int id = p['id'] ?? p['ID'];
        if (_carrinho.containsKey(id) && _carrinho[id]! > 0) {
          double quantidadeOuPeso = _carrinho[id]!;
          double precoProduto = double.tryParse(p['price'].toString()) ?? 0.0;
          String un = (p['unidade_medida'] ?? '').toString().toLowerCase();

          if (un == 'kg' || un == 'grama' || un == 'g') {
            total += (precoProduto / 1000.0) * quantidadeOuPeso;
          } else {
            total += precoProduto * quantidadeOuPeso;
          }

          if (_adicionaisEscolhidosPorItem.containsKey(id) && p['adicionais'] != null && p['adicionais'] is List) {
            final escolhas = _adicionaisEscolhidosPorItem[id]!;
            final List<dynamic> ads = p['adicionais'];
            
            for (var ad in ads) {
              if (escolhas.contains(ad['id'] ?? ad['ID'])) {
                double precoAd = double.tryParse(ad['price'].toString()) ?? 0.0;
                total += precoAd * (checkPeso(un) ? 1 : quantidadeOuPeso);
              }
            }
          }
        }
      }
    }
    return total;
  }

  bool checkPeso(String un) {
    String check = un.toLowerCase();
    return check == 'kg' || check == 'grama' || check == 'g';
  }

  void _abrirInstagram() async {
    final Uri url = Uri.parse('https://instagram.com/acaiteriashalom2026');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  List<dynamic> _filtrarProdutos() {
    if (_catalogo == null || _catalogo!['produtos'] == null) return [];
    final List<dynamic> todos = _catalogo!['produtos'];
    List<dynamic> filtrados = todos.where((p) => p['category'] != 'Adicionais').toList();

    if (_categoriaSelecionada != 'Tudo') {
      filtrados = filtrados.where((p) => p['category'].toString().toLowerCase() == _categoriaSelecionada.toLowerCase()).toList();
    }

    if (_termoBusca.isNotEmpty) {
      filtrados = filtrados.where((p) => (p['name'] ?? '').toString().toLowerCase().contains(_termoBusca.toLowerCase())).toList();
    }

    return filtrados;
  }

  String? _buscarPrimeiraImagemDaCategoria(String categoria) {
    if (_catalogo == null || _catalogo!['produtos'] == null) return null;
    final List<dynamic> todos = _catalogo!['produtos'];
    try {
      final itens = todos.where((p) => p['category'] != 'Adicionais' && (categoria == 'Tudo' || p['category'].toString().toLowerCase() == categoria.toLowerCase())).toList();
      if (itens.isNotEmpty) {
        String urlCompleta = (itens.first['image_url'] ?? '').toString();
        if (urlCompleta.isNotEmpty && urlCompleta != 'null') {
          return urlCompleta.split('|||').first;
        }
      }
    } catch (_) {}
    return null;
  }

  void _mostrarDetalhesProduto(Map<String, dynamic> p, Color corTema, Color corLetras, bool isMobile) {
    int id = p['id'] ?? p['ID'];
    String un = (p['unidade_medida'] ?? '').toString().toLowerCase();
    bool isUnidadePeso = checkPeso(un);
    final String categoria = p['category'] ?? 'Montados';
    
    double quantidadeOuPeso = _carrinho[id] ?? (isUnidadePeso ? 0.0 : 1.0);
    final obsController = TextEditingController(text: _observacoes[id] ?? '');
    final pesoController = TextEditingController(text: quantidadeOuPeso > 0 ? quantidadeOuPeso.toInt().toString() : '');

    List<dynamic> adicionaisDoProduto = p['adicionais'] ?? [];
    List<dynamic> subprodutosDoCombo = p['produtos_combo'] ?? [];

    List<int> adicionaisSelecionadosLocais = List.from(_adicionaisEscolhidosPorItem[id] ?? []);

    showDialog(
      context: context,
      useSafeArea: false,
      builder: (context) => Dialog(
        insetPadding: isMobile 
            ? EdgeInsets.zero 
            : EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.1, 
                vertical: MediaQuery.of(context).size.height * 0.05
              ),
        shape: isMobile 
            ? const RoundedRectangleBorder(borderRadius: BorderRadius.zero) 
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: StatefulBuilder(
          builder: (context, setModalState) {
            
            double qtdAtual = isUnidadePeso ? (double.tryParse(pesoController.text) ?? 0.0) : quantidadeOuPeso;
            double precoProduto = double.tryParse(p['price'].toString()) ?? 0.0;
            
            double valorBaseCalculado = isUnidadePeso 
                ? (qtdAtual > 0 ? (precoProduto / 1000.0) * qtdAtual : precoProduto)
                : precoProduto * qtdAtual;

            double custoAdicionais = 0.0;
            for (var adId in adicionaisSelecionadosLocais) {
              var ad = adicionaisDoProduto.firstWhere((a) => (a['id'] ?? a['ID']) == adId, orElse: () => null);
              if (ad != null) {
                double precoAd = double.tryParse(ad['price'].toString()) ?? 0.0;
                custoAdicionais += precoAd * (isUnidadePeso ? 1 : qtdAtual);
              }
            }
            double totalFinalExibido = valorBaseCalculado + custoAdicionais;

            final Widget imagemDestaque = Stack(
              fit: StackFit.expand,
              children: [
                p['image_url'] == null || p['image_url'].isEmpty
                    ? Icon(Icons.fastfood, size: 100, color: corTema.withOpacity(0.3))
                    : CarrosselFotosPublicoWidget(fotos: p['image_url'].toString().split('|||').where((s) => s.isNotEmpty).toList()),
                Positioned(
                  top: isMobile ? 32 : 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: corTema, borderRadius: BorderRadius.circular(30)),
                    child: Text(categoria.toUpperCase(), style: TextStyle(color: corLetras, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
                  ),
                ),
                if (isMobile)
                  Positioned(
                    top: 24,
                    right: 16,
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.black),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  )
              ],
            );

            return Container(
              color: Colors.white,
              width: isMobile ? double.infinity : MediaQuery.of(context).size.width * 0.8,
              height: isMobile ? double.infinity : MediaQuery.of(context).size.height * 0.9,
              child: isMobile 
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 250,
                        width: double.infinity,
                        child: imagemDestaque,
                      ),
                      Expanded(
                        child: _buildConteudoDetalhes(p, corTema, corLetras, isMobile, un, isUnidadePeso, categoria, adicionaisDoProduto, subprodutosDoCombo, adicionaisSelecionadosLocais, obsController, pesoController, quantidadeOuPeso, totalFinalExibido, id, setModalState),
                      )
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 400,
                        child: imagemDestaque,
                      ),
                      Expanded(
                        child: _buildConteudoDetalhes(p, corTema, corLetras, isMobile, un, isUnidadePeso, categoria, adicionaisDoProduto, subprodutosDoCombo, adicionaisSelecionadosLocais, obsController, pesoController, quantidadeOuPeso, totalFinalExibido, id, setModalState),
                      ),
                    ],
                  ),
            );
          }
        ),
      ),
    );
  }

  Widget _buildConteudoDetalhes(Map<String, dynamic> p, Color corTema, Color corLetras, bool isMobile, String un, bool isUnidadePeso, String categoria, List<dynamic> adicionaisDoProduto, List<dynamic> subprodutosDoCombo, List<int> adicionaisSelecionadosLocais, TextEditingController obsController, TextEditingController pesoController, double quantidadeOuPeso, double totalFinalExibido, int id, StateSetter setModalState) {
    return Padding(
      padding: EdgeInsets.all(isMobile ? 20.0 : 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(p['name'] ?? '', style: TextStyle(fontWeight: FontWeight.w900, fontSize: isMobile ? 24 : 32, color: corTema, height: 1.1))),
              if (!isMobile)
                IconButton(icon: const Icon(Icons.close, color: Colors.grey, size: 28), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 6),
          Text('Venda por: ${un.toUpperCase()}', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(p['description'] ?? '', style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)),
                
                if (categoria == 'Montados') ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline, color: corTema, size: 20),
                        const SizedBox(width: 8),
                        Text('ADICIONAIS E RECHEIOS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: corTema, letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  adicionaisDoProduto.isEmpty
                      ? const Text('Nenhum adicional vinculado a este produto.', style: TextStyle(color: Colors.grey, fontSize: 14, fontStyle: FontStyle.italic))
                      : SizedBox(
                          height: 160,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: adicionaisDoProduto.length,
                            itemBuilder: (context, index) {
                              final ad = adicionaisDoProduto[index];
                              final int adId = ad['id'] ?? ad['ID'];
                              final String adNome = ad['name'] ?? '';
                              final double adPreco = double.tryParse(ad['price'].toString()) ?? 0.0;
                              final bool adSelecionado = adicionaisSelecionadosLocais.contains(adId);
                              final String imgUrl = ad['image_url'] ?? '';
                              final List<String> f = imgUrl.split('|||').where((s) => s.isNotEmpty).toList();

                              return Container(
                                width: 120,
                                margin: const EdgeInsets.only(right: 12),
                                child: InkWell(
                                  onTap: () {
                                    setModalState(() {
                                      if (adSelecionado) {
                                        adicionaisSelecionadosLocais.remove(adId);
                                      } else {
                                        adicionaisSelecionadosLocais.add(adId);
                                      }
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      color: adSelecionado ? corTema.withOpacity(0.15) : Colors.white,
                                      border: Border.all(
                                        color: adSelecionado ? corTema : Colors.grey[300]!,
                                        width: adSelecionado ? 2 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Stack(
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            Expanded(
                                              flex: 5,
                                              child: ClipRRect(
                                                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                                                child: f.isEmpty
                                                    ? Container(color: Colors.grey[100], child: Icon(Icons.fastfood, color: Colors.grey[400], size: 30))
                                                    : (f.first.startsWith('data:image')
                                                        ? Image.memory(base64Decode(f.first.split(',')[1]), fit: BoxFit.cover)
                                                        : Image.network(f.first, fit: BoxFit.cover, errorBuilder: (_,__,___) => Icon(Icons.broken_image, color: Colors.grey[400]))),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 4,
                                              child: Padding(
                                                padding: const EdgeInsets.all(6.0),
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(adNome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                                                    const Spacer(),
                                                    Text('+R\$ ${adPreco.toStringAsFixed(2).replaceAll('.', ',')}', style: TextStyle(color: corTema, fontWeight: FontWeight.w900, fontSize: 12)),
                                                  ],
                                                ),
                                              ),
                                            )
                                          ],
                                        ),
                                        if (adSelecionado)
                                          Positioned(
                                            top: 6,
                                            right: 6,
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(color: corTema, shape: BoxShape.circle),
                                              child: Icon(Icons.check, color: corLetras, size: 14),
                                            ),
                                          )
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ],

                if (categoria == 'Combos') ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Icon(Icons.inventory_2_outlined, color: corTema, size: 20),
                        const SizedBox(width: 8),
                        Text('ITENS DESTE COMBO:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: corTema, letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  subprodutosDoCombo.isEmpty
                      ? const Text('Lista vazia.', style: TextStyle(color: Colors.grey, fontSize: 14, fontStyle: FontStyle.italic))
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: subprodutosDoCombo.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final sub = subprodutosDoCombo[index];
                            final String subImg = sub['image_url'] ?? '';
                            final List<String> sf = subImg.split('|||').where((s) => s.isNotEmpty).toList();

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                              leading: Container(
                                width: 50, height: 50,
                                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: sf.isEmpty
                                    ? Icon(Icons.fastfood, color: Colors.grey[400])
                                    : (sf.first.startsWith('data:image') 
                                        ? Image.memory(base64Decode(sf.first.split(',')[1]), fit: BoxFit.cover)
                                        : Image.network(sf.first, fit: BoxFit.cover)),
                                )
                              ),
                              title: Text(sub['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              subtitle: Text((sub['category'] ?? '').toString().toUpperCase(), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            );
                          },
                        ),
                ],

                const SizedBox(height: 24),
                const Text('OBSERVAÇÕES (OPCIONAL):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                const SizedBox(height: 8),
                TextField(
                  controller: obsController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Ex: Sem leite em pó, embalar separado...',
                    hintStyle: const TextStyle(fontSize: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('R\$ ${totalFinalExibido.toStringAsFixed(2).replaceAll('.', ',')}', style: TextStyle(color: corTema, fontWeight: FontWeight.w900, fontSize: isMobile ? 26 : 34)),
                if (isUnidadePeso)
                  Container(
                    height: 50,
                    width: 140,
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!, width: 2), borderRadius: BorderRadius.circular(12)),
                    child: TextFormField(
                      controller: pesoController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                      decoration: const InputDecoration(border: InputBorder.none, hintText: '0', suffixText: 'g', contentPadding: EdgeInsets.only(bottom: 5)),
                      onChanged: (val) {
                        setModalState(() {}); 
                      },
                    ),
                  )
                else
                  Container(
                    height: 50,
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!, width: 2), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        IconButton(icon: const Icon(Icons.remove, size: 22), onPressed: () { if (quantidadeOuPeso > 1) setModalState(() => quantidadeOuPeso--); }),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text('${quantidadeOuPeso.toInt()}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                        ),
                        IconButton(icon: const Icon(Icons.add, size: 22), onPressed: () => setModalState(() => quantidadeOuPeso++)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: corTema, 
                foregroundColor: corLetras, 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4
              ),
              onPressed: () {
                
                double qtdFinal = isUnidadePeso ? (double.tryParse(pesoController.text) ?? 0.0) : quantidadeOuPeso;
                
                if (qtdFinal <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Por favor, informe a quantidade desejada!', style: TextStyle(fontWeight: FontWeight.bold)),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }
                
                _atualizarCarrinho(id, qtdFinal, obsController.text.trim(), adicionaisSelecionadosLocais);
                Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Adicionado ao carrinho com sucesso! 🛒', style: TextStyle(fontWeight: FontWeight.bold)),
                  backgroundColor: Colors.green,
                ));
              },
              child: Text('ADICIONAR AO CARRINHO', style: TextStyle(color: corLetras, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleFiltroItem(String aba, Color corTema) {
    bool selecionada = _categoriaSelecionada == aba;
    String? imgUrl = _buscarPrimeiraImagemDaCategoria(aba);

    return GestureDetector(
      onTap: () => setState(() {
        _categoriaSelecionada = aba;
        _paginaAtual = 1;
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selecionada ? corTema : Colors.grey[300]!,
                  width: selecionada ? 3.5 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: selecionada ? corTema.withOpacity(0.4) : Colors.black.withOpacity(0.04),
                    blurRadius: selecionada ? 10 : 4,
                    spreadRadius: selecionada ? 1 : 0,
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: Container(
                  color: Colors.white,
                  child: imgUrl == null
                      ? Image.asset('assets/images/logo.jpg', fit: BoxFit.cover)
                      : imgUrl.startsWith('data:image')
                          ? Image.memory(base64Decode(imgUrl.split(',')[1]), fit: BoxFit.cover)
                          : Image.network(imgUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Image.asset('assets/images/logo.jpg', fit: BoxFit.cover)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              aba,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selecionada ? FontWeight.w900 : FontWeight.bold,
                color: selecionada ? corTema : Colors.grey[700],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildControlePaginacao(int totalItens, Color corTema) {
    int totalPaginas = (totalItens / _itensPorPagina).ceil();
    if (totalPaginas <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 20),
            color: _paginaAtual > 1 ? corTema : Colors.grey[300],
            onPressed: _paginaAtual > 1 ? () => setState(() => _paginaAtual--) : null,
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
            onPressed: _paginaAtual < totalPaginas ? () => setState(() => _paginaAtual++) : null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF4A0E4E))));
    }
    if (_catalogo == null) {
      return const Scaffold(body: Center(child: Text('Catálogo não encontrado.')));
    }

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 800;

    final corTema = _hexToColor(_catalogo!['cor_tema'] ?? '#4A0E4E');
    final corLetras = _hexToColor(_catalogo!['cor_letras'] ?? '#FFFFFF');
    final String fotoCapa = _catalogo!['foto_capa'] ?? '';

    final todosFiltrados = _filtrarProdutos();
    
    int inicioIdx = (_paginaAtual - 1) * _itensPorPagina;
    int fimIdx = inicioIdx + _itensPorPagina;
    if (fimIdx > todosFiltrados.length) fimIdx = todosFiltrados.length;
    
    final produtosPaginados = todosFiltrados.isEmpty ? [] : todosFiltrados.sublist(inicioIdx, fimIdx);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        automaticallyImplyLeading: false, 
        backgroundColor: corTema,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.3),
        toolbarHeight: isMobile ? 70 : 85,
        title: Row(
          children: [
            Container(
              width: isMobile ? 45 : 55, 
              height: isMobile ? 45 : 55,
              decoration: const BoxDecoration(
                shape: BoxShape.circle, 
                image: DecorationImage(image: AssetImage('assets/images/logo.jpg'), fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                (_catalogo!['titulo'] ?? '').toUpperCase(), 
                style: TextStyle(color: corLetras, fontWeight: FontWeight.w900, fontSize: isMobile ? 16 : 22, letterSpacing: 0.5),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: corLetras, size: isMobile ? 24 : 28),
            onPressed: () => setState(() => _isSearching = !_isSearching)
          ),
          IconButton(
            icon: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/instagran.jpg', 
                width: isMobile ? 24 : 28, 
                height: isMobile ? 24 : 28, 
                fit: BoxFit.cover, 
                errorBuilder: (c,e,s) => Icon(Icons.camera_alt_outlined, color: corLetras)
              ),
            ), 
            onPressed: _abrirInstagram
          ),
          const SizedBox(width: 4),
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.shopping_bag_outlined, color: corLetras, size: isMobile ? 26 : 28), 
                onPressed: _quantidadeTotalItens > 0 ? _abrirCarrinho : null,
              ),
              if (_quantidadeTotalItens > 0)
                Positioned(
                  right: 4, top: isMobile ? 10 : 12, 
                  child: Container(
                    padding: const EdgeInsets.all(4), 
                    decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle), 
                    child: Text('$_quantidadeTotalItens', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))
                  ),
                )
            ],
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: isMobile ? 240 : 420, 
              decoration: BoxDecoration(color: corTema.withOpacity(0.1)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (fotoCapa.isNotEmpty)
                    fotoCapa.startsWith('data:image') 
                      ? Image.memory(base64Decode(fotoCapa.split(',')[1]), fit: BoxFit.cover, errorBuilder: (_,__,___) => const SizedBox()) 
                      : Image.network(fotoCapa, fit: BoxFit.cover, errorBuilder: (_,__,___) => const SizedBox())
                  else
                    Center(child: Icon(Icons.image, size: 80, color: corTema.withOpacity(0.3))),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 24, 
                    left: isMobile ? 16 : 40,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_catalogo!['titulo'] ?? '', style: TextStyle(color: Colors.white, fontSize: isMobile ? 28 : 48, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text(_catalogo!['descricao'] ?? '', style: TextStyle(color: Colors.white70, fontSize: isMobile ? 14 : 18)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_isSearching)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Digite o nome do produto...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onSubmitted: (v) {
                          setState(() {
                            _termoBusca = v;
                            _paginaAtual = 1;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: corTema,
                        foregroundColor: corLetras,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      onPressed: () {
                        setState(() {
                          _termoBusca = _searchController.text.trim();
                          _paginaAtual = 1;
                        });
                      },
                      child: const Icon(Icons.search),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _termoBusca = '';
                          _isSearching = false;
                          _paginaAtual = 1;
                        });
                      },
                      child: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              height: 110,
              child: Center(
                child: ListView(
                  shrinkWrap: true,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: _abasFiltro.map((aba) => _buildCircleFiltroItem(aba, corTema)).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxWidth: 1400),
              padding: EdgeInsets.symmetric(vertical: isMobile ? 20 : 32, horizontal: isMobile ? 16 : 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.restaurant_menu, color: corTema, size: isMobile ? 22 : 28),
                      const SizedBox(width: 8),
                      Text(
                        _categoriaSelecionada == 'Tudo' ? 'NOSSO CARDÁPIO COMPLETO' : 'CATEGORIA: ${_categoriaSelecionada.toUpperCase()}', 
                        style: TextStyle(fontSize: isMobile ? 18 : 24, fontWeight: FontWeight.w900, color: corTema),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (produtosPaginados.isEmpty)
                    SizedBox(
                      height: 220,
                      child: Center(child: Text('Nenhum produto encontrado.', style: TextStyle(color: Colors.grey[600], fontSize: 15))),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: screenWidth > 1100 ? 4 : (screenWidth > 750 ? 3 : 2),
                        crossAxisSpacing: isMobile ? 12 : 24, 
                        mainAxisSpacing: isMobile ? 12 : 24, 
                        childAspectRatio: isMobile ? 0.63 : 0.68,
                      ),
                      itemCount: produtosPaginados.length,
                      itemBuilder: (context, index) {
                        final p = produtosPaginados[index];
                        final String nome = p['name'] ?? '';
                        final String desc = p['description'] ?? '';
                        final double preco = double.tryParse(p['price'].toString()) ?? 0.0;
                        final String urlCompleta = (p['image_url'] ?? '').toString();
                        final List<String> fotos = urlCompleta == 'null' ? [] : urlCompleta.split('|||').where((s) => s.isNotEmpty).toList();

                        return Card(
                          color: Colors.white, 
                          elevation: _hoveredIndex == index && !isMobile ? 12 : 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          clipBehavior: Clip.antiAlias, 
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: MouseRegion(
                                  onEnter: (_) => setState(() => _hoveredIndex = index),
                                  onExit: (_) => setState(() => _hoveredIndex = null),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: fotos.isEmpty
                                        ? Icon(Icons.fastfood, size: 40, color: corTema.withOpacity(0.2))
                                        : CarrosselFotosPublicoWidget(fotos: fotos),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(isMobile ? 10.0 : 16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(nome, style: TextStyle(fontWeight: FontWeight.w900, fontSize: isMobile ? 14 : 16, color: corTema), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 2),
                                    Text(desc, style: TextStyle(color: Colors.grey[700], fontSize: isMobile ? 11 : 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 6),
                                    Text('R\$ ${preco.toStringAsFixed(2).replaceAll('.', ',')}', style: TextStyle(color: corTema, fontWeight: FontWeight.w900, fontSize: isMobile ? 15 : 18)),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 34,
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(color: corTema),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                          padding: EdgeInsets.zero,
                                        ),
                                        onPressed: () => _mostrarDetalhesProduto(p, corTema, corLetras, isMobile),
                                        child: Text('VER OPÇÕES', style: TextStyle(color: corTema, fontWeight: FontWeight.w900, fontSize: 11)),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),
                        );
                      },
                    ),
                  _buildControlePaginacao(todosFiltrados.length, corTema),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              color: const Color(0xFF151515),
              padding: EdgeInsets.symmetric(vertical: isMobile ? 40 : 60, horizontal: isMobile ? 24 : 60),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(width: 60, height: 60, decoration: const BoxDecoration(shape: BoxShape.circle, image: DecorationImage(image: AssetImage('assets/images/logo.jpg'), fit: BoxFit.cover))),
                            const SizedBox(height: 16),
                            Text("Açaiteria Shalom", style: TextStyle(color: corLetras, fontWeight: FontWeight.w900, fontSize: 24)),
                            const SizedBox(height: 12),
                            const Text('Diretamente do Pará, o melhor açaí aqui em Canindé. Açaí Premium, Cremes diversos e Gelatos Italianos!', style: TextStyle(color: Colors.grey, height: 1.5, fontSize: 14), textAlign: TextAlign.center),
                            const SizedBox(height: 32),
                            Text('LOCALIZAÇÃO E REDES', style: TextStyle(color: corTema, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.2)),
                            const SizedBox(height: 12),
                            const Text('Rua Josias Gondim - 711\nSanta Clara, Canindé - CE', style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5), textAlign: TextAlign.center),
                            const SizedBox(height: 8),
                            const Text('Instagram: @acaiteriashalom2026', style: TextStyle(color: Colors.white70, fontSize: 14)),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(width: 50, height: 50, decoration: const BoxDecoration(shape: BoxShape.circle, image: DecorationImage(image: AssetImage('assets/images/logo.jpg'), fit: BoxFit.cover))),
                                      const SizedBox(width: 16),
                                      Text("Açaiteria Shalom", style: TextStyle(color: corLetras, fontWeight: FontWeight.w900, fontSize: 22)),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  const Text('Diretamente do Pará, o melhor açaí aqui em Canindé.\nAçaí Premium, Cremes diversos e Gelatos Italianos!', style: TextStyle(color: Colors.grey, height: 1.6, fontSize: 14)),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('LOCALIZAÇÃO E REDES', style: TextStyle(color: corTema, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5)),
                                  const SizedBox(height: 16),
                                  const Text('Rua Josias Gondim - 711\nSanta Clara, Canindé - CE', style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5), textAlign: TextAlign.right),
                                  const SizedBox(height: 8),
                                  const Text('Instagram: @acaiteriashalom2026', style: TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.right),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              color: Colors.black,
              padding: EdgeInsets.only(top: 24, bottom: _quantidadeTotalItens > 0 ? 96 : 24),
              child: Center(
                child: Text('Desenvolvido por Pedro Barros • 2026', style: TextStyle(color: corTema.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.bold))
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _quantidadeTotalItens > 0
          ? Container(
              constraints: const BoxConstraints(maxWidth: 850),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: corTema, 
                  foregroundColor: corLetras,
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  padding: EdgeInsets.zero,
                ),
                onPressed: _abrirCarrinho,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(24)),
                        child: Text('$_quantidadeTotalItens itens', style: TextStyle(color: corLetras, fontWeight: FontWeight.w900, fontSize: 13)),
                      ),
                      Text('VER MEU CARRINHO', style: TextStyle(color: corLetras, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5)),
                      Text('R\$ ${_valorTotalCarrinho.toStringAsFixed(2).replaceAll('.', ',')}', style: TextStyle(color: corLetras, fontWeight: FontWeight.w900, fontSize: 15)),
                    ],
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class CarrosselFotosPublicoWidget extends StatefulWidget {
  final List<String> fotos;
  const CarrosselFotosPublicoWidget({super.key, required this.fotos});

  @override
  State<CarrosselFotosPublicoWidget> createState() => _CarrosselFotosPublicoWidgetState();
}

class _CarrosselFotosPublicoWidgetState extends State<CarrosselFotosPublicoWidget> {
  final PageController _pageController = PageController();
  Timer? _timer;
  int _currentPage = 0;
  final List<Uint8List> _cachedBytes = [];

  @override
  void initState() {
    super.initState();
    _processarEPrevinirPisca();
  }

  void _processarEPrevinirPisca() {
    for (var f in widget.fotos) {
      if (f.startsWith('data:image') && f.contains(',')) {
        try {
          _cachedBytes.add(base64Decode(f.split(',')[1]));
        } catch (_) {}
      }
    }
  }

  void _iniciarCarrossel() {
    if (widget.fotos.length <= 1) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted && _pageController.hasClients) {
        _currentPage++;
        if (_currentPage >= widget.fotos.length) { _currentPage = 0; }
        _pageController.animateToPage(
          _currentPage, 
          duration: const Duration(milliseconds: 600), 
          curve: Curves.easeInOut
        );
      }
    });
  }

  void _pararCarrossel() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _pararCarrossel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _iniciarCarrossel(),
      onExit: (_) => _pararCarrossel(),
      child: GestureDetector(
        onTapDown: (_) => _iniciarCarrossel(),
        onTapUp: (_) => _pararCarrossel(),
        onTapCancel: () => _pararCarrossel(),
        child: PageView.builder(
          controller: _pageController,
          physics: widget.fotos.length > 1 ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics(),
          itemCount: widget.fotos.length,
          onPageChanged: (index) => _currentPage = index,
          itemBuilder: (context, index) {
            final String foto = widget.fotos[index];
            
            if (foto.startsWith('data:image')) {
              if (_cachedBytes.length > index) {
                return Image.memory(_cachedBytes[index], fit: BoxFit.cover);
              }
              try {
                return Image.memory(base64Decode(foto.split(',')[1]), fit: BoxFit.cover);
              } catch (_) {
                return Container(color: Colors.grey[200], child: const Icon(Icons.fastfood, color: Colors.grey));
              }
            }
            
            return Image.network(
              foto, 
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Image.asset('assets/images/logo.jpg', fit: BoxFit.cover),
            );
          },
        ),
      ),
    );
  }
}