import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:acaiteria_front/features/auth/services/produto_service.dart';
import 'cadastro_produto_page.dart';

class ProdutosTab extends StatefulWidget {
  const ProdutosTab({super.key});

  @override
  State<ProdutosTab> createState() => _ProdutosTabState();
}

class _ProdutosTabState extends State<ProdutosTab> {
  final _produtoService = ProdutoService();
  final _buscaController = TextEditingController();
  List<dynamic> _produtos = [];
  bool _loading = true;
  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    _carregarProdutos();
  }

  Future<void> _carregarProdutos({String nome = ''}) async {
    setState(() => _loading = true);
    final lista = await _produtoService.buscarProdutos(nome: nome);
    setState(() {
      _produtos = lista;
      _loading = false;
    });
  }

  void _abrirDialogEstoque(Map<String, dynamic> produto) {
    final estoqueCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Adicionar Estoque - ${produto['name']}', style: const TextStyle(color: Color(0xFF4A0E4E), fontWeight: FontWeight.bold)),
        content: TextField(
          controller: estoqueCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Quantidade a somar',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700)),
            onPressed: () async {
              if (estoqueCtrl.text.isNotEmpty) {
                int qtdNova = int.parse(estoqueCtrl.text);
                int qtdAtual = produto['estoque'] ?? 0;
                
                produto['estoque'] = qtdAtual + qtdNova;
                await _produtoService.editarProduto(produto['id'] ?? produto['ID'], produto);
                
                if (mounted) {
                  Navigator.pop(context);
                  _carregarProdutos(nome: _buscaController.text);
                }
              }
            },
            child: const Text('Salvar', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _abrirDialogEditar(Map<String, dynamic> produto) async {
    final atualizou = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CadastroProdutoPage(produtoParaEditar: produto),
      ),
    );
    if (atualizou == true) {
      _carregarProdutos(nome: _buscaController.text);
    }
  }

  void _confirmarExclusao(Map<String, dynamic> produto) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Produto?'),
        content: Text('Tem certeza que deseja remover "${produto['name']}" do cardápio?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _produtoService.deletarProduto(produto['id'] ?? produto['ID']);
              if (mounted) {
                Navigator.pop(context);
                _carregarProdutos(nome: _buscaController.text);
              }
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    final titleRow = Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFFFD700),
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
              'Gestão de Cardápio',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ],
    );

    final searchBar = TextField(
      controller: _buscaController,
      maxLines: 1,
      decoration: InputDecoration(
        labelText: 'Buscar açaí por nome...',
        prefixIcon: const Icon(Icons.search, color: Color(0xFF4A0E4E)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        suffixIcon: IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            _buscaController.clear();
            _carregarProdutos();
          },
        ),
      ),
      onChanged: (text) => _carregarProdutos(nome: text),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleRow,
          const SizedBox(height: 16),
          searchBar,
        ],
      );
    } else {
      return Row(
        children: [
          titleRow,
          const Spacer(),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: searchBar,
              ),
            ),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final larguraTela = MediaQuery.of(context).size.width;
    final isMobile = larguraTela < 600;
    
    int colunasGrid = 1;
    double proporcaoCard = 1.05;

    if (larguraTela > 1200) {
      colunasGrid = 4;
      proporcaoCard = 1.15;
    } else if (larguraTela > 800) {
      colunasGrid = 3;
      proporcaoCard = 1.1;
    } else if (larguraTela > 550) {
      colunasGrid = 2;
      proporcaoCard = 1.05;
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFFD700),
        onPressed: () async {
          final atualizou = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CadastroProdutoPage()),
          );
          if (atualizou == true) {
            _carregarProdutos();
          }
        },
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
        child: Column(
          children: [
            _buildHeader(isMobile),
            SizedBox(height: isMobile ? 16 : 24),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A0E4E)))
                  : _produtos.isEmpty
                      ? const Center(child: Text('Nenhum açaí cadastrado no cardápio.'))
                      : GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: colunasGrid,
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 20,
                            childAspectRatio: proporcaoCard,
                          ),
                          itemCount: _produtos.length,
                          itemBuilder: (context, index) {
                            final p = _produtos[index];
                            final String urlCompleta = p['image_url'] ?? '';
                            List<String> fotos = urlCompleta.split('|||').where((s) => s.isNotEmpty).toList();
                            final isHovered = _hoveredIndex == index;

                            return MouseRegion(
                              onEnter: (_) => setState(() => _hoveredIndex = index),
                              onExit: (_) => setState(() => _hoveredIndex = null),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                transform: isHovered && !isMobile
                                    ? (Matrix4.identity()..translate(0, -6, 0)) 
                                    : Matrix4.identity(),
                                child: Card(
                                  elevation: isHovered && !isMobile ? 12 : 4,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                  clipBehavior: Clip.antiAlias,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Stack(
                                          children: [
                                            Container(
                                              width: double.infinity,
                                              color: const Color(0xFFF5F5F5),
                                              child: fotos.isEmpty
                                                  ? const Icon(Icons.icecream, size: 50, color: Color(0xFF4A0E4E))
                                                  : CarrosselFotosWidget(fotos: fotos),
                                            ),
                                            Positioned(
                                              top: 8,
                                              right: 8,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF4A0E4E),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  'R\$ ${double.parse(p['price'].toString()).toStringAsFixed(2)}',
                                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p['name'],
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF4A0E4E)),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              p['description'] ?? '',
                                              style: TextStyle(color: Colors.grey[600], fontSize: 11),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Icon(Icons.layers_outlined, size: 14, color: Colors.grey[600]),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Estoque: ${p['estoque']}',
                                                  style: TextStyle(color: Colors.grey[700], fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Divider(height: 1, color: Colors.grey[200]),
                                      Container(
                                        color: Colors.grey[50],
                                        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.add_box_outlined, color: Colors.green, size: 20),
                                              tooltip: 'Adicionar Estoque',
                                              onPressed: () => _abrirDialogEstoque(p),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                                              tooltip: 'Editar Produto',
                                              onPressed: () => _abrirDialogEditar(p),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                              tooltip: 'Excluir Produto',
                                              onPressed: () => _confirmarExclusao(p),
                                            ),
                                          ],
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
          ],
        ),
      ),
    );
  }
}

class CarrosselFotosWidget extends StatefulWidget {
  final List<String> fotos;
  const CarrosselFotosWidget({super.key, required this.fotos});

  @override
  State<CarrosselFotosWidget> createState() => _CarrosselFotosWidgetState();
}

class _CarrosselFotosWidgetState extends State<CarrosselFotosWidget> {
  final PageController _pageController = PageController();
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    if (widget.fotos.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
        if (_pageController.hasClients) {
          _currentPage++;
          if (_currentPage >= widget.fotos.length) {
            _currentPage = 0;
          }
          _pageController.animateToPage(
            _currentPage,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.fotos.length,
      onPageChanged: (index) => _currentPage = index,
      itemBuilder: (context, index) {
        final String foto = widget.fotos[index];
        final bool isBase64 = foto.startsWith('data:image');
        return isBase64
            ? Image.memory(foto.contains(',') ? base64Decode(foto.split(',')[1]) : base64Decode(foto), fit: BoxFit.contain)
            : Image.network(foto, fit: BoxFit.contain);
      },
    );
  }
}