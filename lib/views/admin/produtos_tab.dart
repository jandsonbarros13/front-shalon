import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:acaiteria_front/features/auth/services/produto_service.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:showcaseview/showcaseview.dart';
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
  int _totalProdutos = 0;
  bool _loading = true;
  int? _hoveredIndex;
  bool _isDarkMode = true;

  int _paginaAtual = 1;
  final int _itensPorPagina = 8;

  final FlutterTts _flutterTts = FlutterTts();
  final GlobalKey _keyBusca = GlobalKey();
  final GlobalKey _keyCard = GlobalKey();
  final GlobalKey _keyNovo = GlobalKey();

  final List<String> _textosMascote = [
    "Bem-vindo são seus Produtos! Aqui em cima, você pode pesquisar qualquer produto digitando o nome dele.",
    "Nesta lista ficam os seus produtos. Passe o mouse sobre a foto para ver mais imagens, e use os botões embaixo para adicionar estoque, editar ou excluir.",
    "Para adicionar um novo produto, é só clicar neste botão flutuante amarelo!"
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
    _carregarProdutos();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _buscaController.dispose();
    super.dispose();
  }

  Future<void> _carregarProdutos({String nome = '', bool isBusca = false}) async {
    if (isBusca) _paginaAtual = 1;
    setState(() => _loading = true);
    
    final resultado = await _produtoService.buscarProdutos(_paginaAtual, nome: nome, limit: _itensPorPagina);
    
    if (!mounted) return;

    setState(() {
      var prods = resultado['produtos'];
      _produtos = prods is List ? prods : [];
      _totalProdutos = int.tryParse(resultado['total'].toString()) ?? 0;
      _loading = false;

      int totalPaginas = (_totalProdutos / _itensPorPagina).ceil();
      if (_paginaAtual > totalPaginas && totalPaginas > 0) {
        _paginaAtual = totalPaginas;
        _carregarProdutos(nome: nome);
      }
    });
  }

  void _abrirDialogEstoque(Map<String, dynamic> produto) {
    final estoqueCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Adicionar Estoque - ${produto['name'] ?? produto['Name'] ?? ''}', style: TextStyle(color: accentColor, fontWeight: FontWeight.w900)),
        content: TextField(
          controller: estoqueCtrl,
          keyboardType: TextInputType.number,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            labelText: 'Quantidade a somar',
            labelStyle: TextStyle(color: textSecColor),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!), borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: accentColor, width: 2), borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              if (estoqueCtrl.text.isNotEmpty) {
                int qtdNova = int.tryParse(estoqueCtrl.text) ?? 0;
                int qtdAtual = int.tryParse((produto['estoque'] ?? produto['Estoque'] ?? 0).toString()) ?? 0;
                
                produto['estoque'] = qtdAtual + qtdNova;
                await _produtoService.editarProduto(produto['id'] ?? produto['ID'], produto);
                
                if (mounted) {
                  Navigator.pop(context);
                  _carregarProdutos(nome: _buscaController.text);
                }
              }
            },
            child: const Text('Salvar', style: TextStyle(fontWeight: FontWeight.bold)),
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
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Excluir Produto?', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Text('Tem certeza que deseja remover "${produto['name'] ?? produto['Name'] ?? ''}" do cardápio?', style: TextStyle(color: textColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              await _produtoService.deletarProduto(produto['id'] ?? produto['ID']);
              if (mounted) {
                Navigator.pop(context);
                _carregarProdutos(nome: _buscaController.text);
              }
            },
            child: const Text('Excluir', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Color _getBadgeColor(String categoria) {
    switch (categoria.toLowerCase()) {
      case 'adicionais': return Colors.orange[800]!;
      case 'cremes': return Colors.purple[700]!;
      case 'produtos': return Colors.teal[700]!;
      case 'bebidas': return Colors.blue[700]!;
      case 'combos': return Colors.red[700]!;
      default: return accentColor;
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
                          "Aqui é o seu cardápio. Você pode:\n"
                          "• Buscar e visualizar todos os produtos\n"
                          "• Adicionar estoque rapidamente\n"
                          "• Cadastrar, editar ou excluir itens\n\n"
                          "Quer fazer um Tour Guiado para ver como tudo funciona?",
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
                            _keyCard,
                            _keyNovo,
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

  Widget _buildHeader(BuildContext showcaseContext) {
    return Showcase.withWidget(
      key: _keyBusca,
      container: _buildTooltipMascote(showcaseContext, _textosMascote[0], false),
      child: TextField(
        controller: _buscaController,
        maxLines: 1,
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: 'Buscar açaí por nome...',
          hintStyle: TextStyle(color: textSecColor),
          prefixIcon: Icon(Icons.search, color: accentColor),
          filled: true,
          fillColor: cardColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          suffixIcon: IconButton(
            icon: Icon(Icons.clear, color: textSecColor),
            onPressed: () {
              _buscaController.clear();
              _carregarProdutos(isBusca: true);
            },
          ),
        ),
        onChanged: (text) => _carregarProdutos(nome: text, isBusca: true),
      ),
    );
  }

  Widget _buildControlePaginacao(int totalPaginas) {
    if (totalPaginas <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 20),
            color: _paginaAtual > 1 ? accentColor : textSecColor.withOpacity(0.3),
            onPressed: _paginaAtual > 1 ? () {
              setState(() => _paginaAtual--);
              _carregarProdutos(nome: _buscaController.text);
            } : null,
          ),
          const SizedBox(width: 16),
          Text(
            'Página $_paginaAtual de $totalPaginas',
            style: TextStyle(fontWeight: FontWeight.bold, color: textSecColor, fontSize: 14),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 20),
            color: _paginaAtual < totalPaginas ? accentColor : textSecColor.withOpacity(0.3),
            onPressed: _paginaAtual < totalPaginas ? () {
              setState(() => _paginaAtual++);
              _carregarProdutos(nome: _buscaController.text);
            } : null,
          ),
        ],
      ),
    );
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

    int totalPaginas = (_totalProdutos / _itensPorPagina).ceil();
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
                    'CONTROLE DE PRODUTOS', 
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
                    Icon(Icons.inventory, color: accentColor, size: 16),
                    const SizedBox(width: 8),
                    Text('$_totalProdutos CADASTRADOS', style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ],
                ),
              )
            ],
          ),
          floatingActionButton: Showcase.withWidget(
            key: _keyNovo,
            container: _buildTooltipMascote(showcaseContext, _textosMascote[2], true),
            child: FloatingActionButton(
              backgroundColor: const Color(0xFFFFD700),
              onPressed: () async {
                final atualizou = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CadastroProdutoPage()),
                );
                if (atualizou == true) {
                  _carregarProdutos(nome: _buscaController.text);
                }
              },
              child: const Icon(Icons.add, color: Colors.black, size: 28),
            ),
          ),
          body: Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Catálogo e Estoque', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textColor)),
                    const SizedBox(height: 8),
                    Text('Gerencie os produtos da loja, adicione estoque e ajuste preços.', style: TextStyle(color: textSecColor, fontSize: 15)),
                    const SizedBox(height: 24),
                    
                    _buildHeader(showcaseContext),

                    const SizedBox(height: 24),
                    Expanded(
                      child: _loading
                          ? Center(child: CircularProgressIndicator(color: accentColor))
                          : _produtos.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.fastfood_outlined, size: 64, color: textSecColor.withOpacity(0.5)),
                                      const SizedBox(height: 16),
                                      Text('Nenhum produto encontrado.', style: TextStyle(color: textSecColor, fontSize: 16, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                )
                              : Column(
                                  children: [
                                    Expanded(
                                      child: GridView.builder(
                                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: colunasGrid,
                                          crossAxisSpacing: 20,
                                          mainAxisSpacing: 20,
                                          childAspectRatio: proporcaoCard,
                                        ),
                                        itemCount: _produtos.length,
                                        itemBuilder: (context, index) {
                                          final p = _produtos[index];
                                          final String urlCompleta = (p['image_url'] ?? p['ImageURL'] ?? p['imageURL'] ?? '').toString();
                                          List<String> fotos = urlCompleta.split('|||').where((s) => s.isNotEmpty).toList();
                                          final isHovered = _hoveredIndex == index;
                                          final String categoria = (p['category'] ?? p['Category'] ?? 'Produtos').toString();
                                          final double preco = double.tryParse(p['price'].toString()) ?? 0.0;
                                          final int estoqueAtual = int.tryParse((p['estoque'] ?? p['Estoque'] ?? 0).toString()) ?? 0;

                                          Widget cardWidget = MouseRegion(
                                            onEnter: (_) => setState(() => _hoveredIndex = index),
                                            onExit: (_) => setState(() => _hoveredIndex = null),
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 200),
                                              transform: isHovered && !isMobile
                                                  ? (Matrix4.identity()..translate(0, -6, 0)) 
                                                  : Matrix4.identity(),
                                              child: Card(
                                                color: cardColor,
                                                elevation: isHovered && !isMobile ? 12 : 4,
                                                shadowColor: Colors.black.withOpacity(0.2),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(16),
                                                  side: BorderSide(color: isDark ? Colors.white10 : Colors.transparent),
                                                ),
                                                clipBehavior: Clip.antiAlias,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      child: Stack(
                                                        children: [
                                                          Container(
                                                            width: double.infinity,
                                                            color: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF5F5F5),
                                                            child: CarrosselFotosWidget(fotos: fotos),
                                                          ),
                                                          Positioned(
                                                            top: 8,
                                                            left: 8,
                                                            child: Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                              decoration: BoxDecoration(
                                                                color: _getBadgeColor(categoria),
                                                                borderRadius: BorderRadius.circular(12),
                                                              ),
                                                              child: Text(
                                                                categoria.toUpperCase(),
                                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9),
                                                              ),
                                                            ),
                                                          ),
                                                          Positioned(
                                                            top: 8,
                                                            right: 8,
                                                            child: Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                              decoration: BoxDecoration(
                                                                color: const Color(0xFFFFD700),
                                                                borderRadius: BorderRadius.circular(12),
                                                              ),
                                                              child: Text(
                                                                'R\$ ${preco.toStringAsFixed(2).replaceAll('.', ',')}',
                                                                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            p['name']?.toString().toUpperCase() ?? '',
                                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                          const SizedBox(height: 4),
                                                          Text(
                                                            p['description']?.toString() ?? 'Sem descrição',
                                                            style: TextStyle(color: textSecColor, fontSize: 11),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                          const SizedBox(height: 8),
                                                          Row(
                                                            children: [
                                                              Icon(Icons.layers_outlined, size: 14, color: textSecColor),
                                                              const SizedBox(width: 4),
                                                              Text(
                                                                'Estoque Atual: $estoqueAtual',
                                                                style: TextStyle(color: textSecColor, fontSize: 12, fontWeight: FontWeight.bold),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
                                                    Container(
                                                      color: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFFAFAFA),
                                                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                                        children: [
                                                          IconButton(
                                                            icon: const Icon(Icons.add_box_outlined, color: Colors.green, size: 22),
                                                            tooltip: 'Adicionar Estoque',
                                                            onPressed: () => _abrirDialogEstoque(p),
                                                          ),
                                                          IconButton(
                                                            icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 22),
                                                            tooltip: 'Editar Produto',
                                                            onPressed: () => _abrirDialogEditar(p),
                                                          ),
                                                          IconButton(
                                                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
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

                                          if (index == 0) {
                                            return Showcase.withWidget(
                                              key: _keyCard,
                                              container: _buildTooltipMascote(showcaseContext, _textosMascote[1], false),
                                              child: cardWidget,
                                            );
                                          }
                                          return cardWidget;
                                        },
                                      ),
                                    ),
                                    _buildControlePaginacao(totalPaginas),
                                  ],
                                ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 100,
                right: 20,
                child: GestureDetector(
                  onTap: () => _mostrarMensagemMascote(showcaseContext),
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
  final List<dynamic> _processedImages = [];

  @override
  void initState() {
    super.initState();
    _processarImagens();
  }

  void _processarImagens() {
    if (widget.fotos.isEmpty) return;
    for (var f in widget.fotos) {
      String foto = f.trim();
      if (foto.isEmpty || foto.contains('placeholder.com')) {
        continue;
      }
      if (foto.startsWith('http://') || foto.startsWith('https://')) {
        _processedImages.add(foto);
      } else {
        if (foto.contains(',')) foto = foto.split(',')[1];
        foto = foto.replaceAll('\n', '').replaceAll('\r', '').trim();
        try {
          _processedImages.add(base64Decode(foto));
        } catch (_) {}
      }
    }
  }

  void _iniciarCarrossel() {
    if (_processedImages.length <= 1) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted && _pageController.hasClients) {
        _currentPage++;
        if (_currentPage >= _processedImages.length) {
          _currentPage = 0;
        }
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _pararCarrossel() {
    _timer?.cancel();
    _timer = null;
    if (mounted && _pageController.hasClients && _currentPage != 0) {
      _currentPage = 0;
      _pageController.jumpToPage(0);
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
    if (_processedImages.isEmpty) {
      return Image.asset(
        'assets/images/logo.jpg',
        fit: BoxFit.cover,
      );
    }

    if (_processedImages.length == 1) {
      final img = _processedImages.first;
      if (img is String) {
        return Image.network(img, fit: BoxFit.cover, gaplessPlayback: true);
      }
      return Image.memory(img, fit: BoxFit.cover, gaplessPlayback: true);
    }

    return MouseRegion(
      onEnter: (_) => _iniciarCarrossel(),
      onExit: (_) => _pararCarrossel(),
      child: GestureDetector(
        onTapDown: (_) => _iniciarCarrossel(),
        onTapUp: (_) => _pararCarrossel(),
        onTapCancel: () => _pararCarrossel(),
        child: PageView.builder(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _processedImages.length,
          onPageChanged: (index) => _currentPage = index,
          itemBuilder: (context, index) {
            final img = _processedImages[index];
            if (img is String) {
              return Image.network(img, fit: BoxFit.cover, gaplessPlayback: true);
            }
            return Image.memory(img, fit: BoxFit.cover, gaplessPlayback: true);
          },
        ),
      ),
    );
  }
}