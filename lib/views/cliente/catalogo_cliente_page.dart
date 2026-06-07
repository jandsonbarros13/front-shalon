import 'dart:convert';
import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
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
  int _paginaAtual = 1;
  final int _produtosPorPagina = 10;

  @override
  void initState() {
    super.initState();
    _carregarCatalogo();
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

  void _atualizarCarrinho(int id, double quantidade, String obs) {
    setState(() {
      if (quantidade <= 0) {
        _carrinho.remove(id);
        _observacoes.remove(id);
      } else {
        _carrinho[id] = quantidade;
        if (obs.isNotEmpty) {
          _observacoes[id] = obs;
        } else {
          _observacoes.remove(id);
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
        ),
      ),
    );

    if (pedidoFinalizado == true) {
      setState(() {
        _carrinho.clear();
        _observacoes.clear();
      });
    } else {
      setState(() {});
    }
  }

  int get _quantidadeTotalItens {
    int total = 0;
    if (_catalogo != null && _catalogo!['produtos'] != null) {
      for (var p in _catalogo!['produtos']) {
        int id = p['id'];
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
      for (var p in _catalogo!['produtos']) {
        int id = p['id'];
        if (_carrinho.containsKey(id) && _carrinho[id]! > 0) {
          double quantidadeOuPeso = _carrinho[id]!;
          double precoProduto = double.tryParse(p['price'].toString()) ?? 0.0;
          String un = (p['unidade_medida'] ?? '').toString().toLowerCase();

          if (un == 'kg' || un == 'grama' || un == 'g') {
            total += (precoProduto / 1000.0) * quantidadeOuPeso;
          } else {
            total += precoProduto * quantidadeOuPeso;
          }
        }
      }
    }
    return total;
  }

  void _abrirInstagram() {
    html.window.open('https://instagram.com/acaiteriashalom2026', '_blank');
  }

  List<dynamic> get _produtosPaginados {
    if (_catalogo == null || _catalogo!['produtos'] == null) return [];
    final todosProdutos = _catalogo!['produtos'] as List;
    if (todosProdutos.isEmpty) return [];

    int inicio = (_paginaAtual - 1) * _produtosPorPagina;
    if (inicio >= todosProdutos.length) {
      inicio = 0;
      _paginaAtual = 1;
    }
    
    int fim = inicio + _produtosPorPagina;
    if (fim > todosProdutos.length) fim = todosProdutos.length;
    
    return todosProdutos.sublist(inicio, fim);
  }

  Widget _buildPaginacao(int totalProdutos, Color corTema, bool isMobile) {
    int totalPaginas = (totalProdutos / _produtosPorPagina).ceil();
    if (totalPaginas <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40.0),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: List.generate(totalPaginas, (index) {
          int pagina = index + 1;
          bool isSelecionada = _paginaAtual == pagina;
          return SizedBox(
            width: isMobile ? 40 : null,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelecionada ? corTema : Colors.white,
                foregroundColor: isSelecionada ? Colors.white : corTema,
                side: BorderSide(color: corTema, width: 1.5),
                elevation: isSelecionada ? 4 : 0,
                padding: isMobile ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => setState(() => _paginaAtual = pagina),
              child: Text('$pagina', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          );
        }),
      ),
    );
  }

  void _mostrarDetalhesProduto(Map<String, dynamic> p, Color corTema, Color corLetras, bool isMobile) {
    int id = p['id'];
    String un = (p['unidade_medida'] ?? '').toString().toLowerCase();
    bool isPeso = un == 'kg' || un == 'grama' || un == 'g';
    
    double quantidadeOuPeso = _carrinho[id] ?? (isPeso ? 0.0 : 1.0);
    final obsController = TextEditingController(text: _observacoes[id] ?? '');
    final pesoController = TextEditingController(text: quantidadeOuPeso > 0 ? quantidadeOuPeso.toInt().toString() : '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          contentPadding: EdgeInsets.zero,
          insetPadding: EdgeInsets.all(isMobile ? 16.0 : 40.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          clipBehavior: Clip.antiAlias,
          content: SizedBox(
            width: isMobile ? double.infinity : 900,
            height: isMobile ? MediaQuery.of(context).size.height * 0.85 : 500,
            child: Flex(
              direction: isMobile ? Axis.vertical : Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isMobile)
                  SizedBox(
                    height: 180,
                    child: Container(
                      color: Colors.grey[100],
                      child: p['image_url'] == null || p['image_url'].isEmpty
                          ? Icon(Icons.fastfood, size: 80, color: corTema.withOpacity(0.5))
                          : Image.network(
                              p['image_url'].split('|||').first, 
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Image.asset('assets/images/logo.jpg', fit: BoxFit.cover),
                            ),
                    ),
                  )
                else
                  Expanded(
                    flex: 5,
                    child: Container(
                      color: Colors.grey[100],
                      child: p['image_url'] == null || p['image_url'].isEmpty
                          ? Icon(Icons.fastfood, size: 80, color: corTema.withOpacity(0.5))
                          : Image.network(
                              p['image_url'].split('|||').first, 
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Image.asset('assets/images/logo.jpg', fit: BoxFit.cover),
                            ),
                    ),
                  ),
                Expanded(
                  flex: isMobile ? 1 : 6,
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 20.0 : 32.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(p['name'] ?? '', style: TextStyle(fontWeight: FontWeight.w900, fontSize: isMobile ? 22 : 28, color: corTema))),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red), 
                              onPressed: () => Navigator.pop(context),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(color: corTema.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                          child: Text(un.toUpperCase(), style: TextStyle(color: corTema, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p['description'] ?? '', style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.5)),
                                const SizedBox(height: 16),
                                const Text('Observações:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: obsController,
                                  maxLines: 2,
                                  decoration: InputDecoration(
                                    hintText: 'Ex: Sem leite em pó, caprichar no morango...',
                                    hintStyle: const TextStyle(fontSize: 13),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.all(12),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                        Text('R\$ ${(double.tryParse(p['price'].toString()) ?? 0.0).toStringAsFixed(2).replaceAll('.', ',')}', style: TextStyle(color: corTema, fontWeight: FontWeight.w900, fontSize: isMobile ? 26 : 32)),
                        const SizedBox(height: 16),
                        if (isMobile)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (isPeso)
                                Container(
                                  height: 50,
                                  decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
                                  child: TextFormField(
                                    controller: pesoController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                    decoration: const InputDecoration(border: InputBorder.none, hintText: '0', suffixText: 'g', contentPadding: EdgeInsets.only(bottom: 6)),
                                    onChanged: (val) => quantidadeOuPeso = double.tryParse(val) ?? 0.0,
                                  ),
                                )
                              else
                                Container(
                                  height: 50,
                                  decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      IconButton(icon: const Icon(Icons.remove, size: 20), onPressed: () { if (quantidadeOuPeso > 1) setModalState(() => quantidadeOuPeso--); }),
                                      Text('${quantidadeOuPeso.toInt()}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                      IconButton(icon: const Icon(Icons.add, size: 20), onPressed: () => setModalState(() => quantidadeOuPeso++)),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 50,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: corTema, foregroundColor: corLetras, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                  onPressed: () {
                                    _atualizarCarrinho(id, quantidadeOuPeso, obsController.text.trim());
                                    Navigator.pop(context);
                                  },
                                  child: const Text('ADICIONAR', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                                ),
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              if (isPeso)
                                Container(
                                  height: 50,
                                  width: 150,
                                  decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
                                  child: TextFormField(
                                    controller: pesoController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                    decoration: const InputDecoration(border: InputBorder.none, hintText: '0', suffixText: 'g', contentPadding: EdgeInsets.only(bottom: 6)),
                                    onChanged: (val) => quantidadeOuPeso = double.tryParse(val) ?? 0.0,
                                  ),
                                )
                              else
                                Container(
                                  height: 50,
                                  decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
                                  child: Row(
                                    children: [
                                      IconButton(icon: const Icon(Icons.remove, size: 20), onPressed: () { if (quantidadeOuPeso > 1) setModalState(() => quantidadeOuPeso--); }),
                                      Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: Text('${quantidadeOuPeso.toInt()}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                                      IconButton(icon: const Icon(Icons.add, size: 20), onPressed: () => setModalState(() => quantidadeOuPeso++)),
                                    ],
                                  ),
                                ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: SizedBox(
                                  height: 50,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: corTema, foregroundColor: corLetras, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                    onPressed: () {
                                      _atualizarCarrinho(id, quantidadeOuPeso, obsController.text.trim());
                                      Navigator.pop(context);
                                    },
                                    child: const Text('ADICIONAR AO CARRINHO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                                  ),
                                ),
                              )
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
    final bool isMobile = screenWidth < 600;
    final bool isTablet = screenWidth < 900;

    final corTema = _hexToColor(_catalogo!['cor_tema'] ?? '#4A0E4E');
    final corLetras = _hexToColor(_catalogo!['cor_letras'] ?? '#FFFFFF');
    final List<dynamic> todosProdutos = _catalogo!['produtos'] ?? [];
    final produtosExibidos = _produtosPaginados;
    final String fotoCapa = _catalogo!['foto_capa'] ?? '';

    return Container(
      color: const Color(0xFF141414),
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          automaticallyImplyLeading: false, 
          backgroundColor: Colors.white,
          elevation: 2,
          shadowColor: corTema.withOpacity(0.3),
          toolbarHeight: isMobile ? 70 : 90,
          title: Row(
            children: [
              Container(
                width: isMobile ? 45 : 65, 
                height: isMobile ? 45 : 65,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, border: Border.all(color: corTema, width: isMobile ? 2 : 3),
                  boxShadow: [BoxShadow(color: corTema.withOpacity(0.3), blurRadius: 8, spreadRadius: 1)],
                  image: const DecorationImage(image: AssetImage('assets/images/logo.jpg'), fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  (_catalogo!['titulo'] ?? '').toUpperCase(), 
                  style: TextStyle(color: corTema, fontWeight: FontWeight.w900, fontSize: isMobile ? 18 : 24, letterSpacing: 1),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            if (!isTablet) ...[
              Container(
                width: 300, height: 45, padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(24), border: Border.all(color: corTema.withOpacity(0.2))),
                child: Row(children: [Icon(Icons.search, color: corTema.withOpacity(0.6), size: 20), const SizedBox(width: 8), Text('Buscar no cardápio...', style: TextStyle(color: corTema.withOpacity(0.6), fontSize: 14))]),
              ),
              const SizedBox(width: 16),
            ],
            if (!isMobile) IconButton(icon: const Icon(Icons.wechat, color: Colors.green, size: 28), onPressed: () {}),
            IconButton(icon: Icon(Icons.camera_alt_outlined, color: corTema, size: isMobile ? 24 : 28), onPressed: _abrirInstagram),
            const SizedBox(width: 4),
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.shopping_bag_outlined, color: corTema, size: isMobile ? 26 : 30), 
                  onPressed: _quantidadeTotalItens > 0 ? _abrirCarrinho : null,
                ),
                if (_quantidadeTotalItens > 0)
                  Positioned(
                    right: 4, top: isMobile ? 10 : 12, 
                    child: Container(
                      padding: const EdgeInsets.all(4), 
                      decoration: BoxDecoration(color: corTema, shape: BoxShape.circle), 
                      child: Text('$_quantidadeTotalItens', style: TextStyle(color: corLetras, fontSize: 10, fontWeight: FontWeight.bold))
                    ),
                  )
              ],
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                height: isMobile ? 300 : 550, 
                decoration: BoxDecoration(color: corTema.withOpacity(0.1)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (fotoCapa.isNotEmpty)
                      fotoCapa.startsWith('data:image') 
                        ? Image.memory(base64Decode(fotoCapa.split(',')[1]), fit: BoxFit.cover, errorBuilder: (_,__,___) => const SizedBox()) 
                        : Image.network(fotoCapa, fit: BoxFit.cover, errorBuilder: (_,__,___) => const SizedBox())
                    else
                      Center(child: Icon(Icons.image, size: 100, color: corTema.withOpacity(0.3))),
                    
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                        ),
                      ),
                    ),
                    
                    Positioned(
                      bottom: isMobile ? 24 : 60, 
                      left: isMobile ? 20 : (screenWidth > 1600 ? (screenWidth - 1600) / 2 + 24 : 40),
                      right: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_catalogo!['titulo'] ?? '', style: TextStyle(color: Colors.white, fontSize: isMobile ? 36 : 64, fontWeight: FontWeight.w900, shadows: const [Shadow(color: Colors.black, blurRadius: 15)])),
                          const SizedBox(height: 8),
                          Text(_catalogo!['descricao'] ?? '', style: TextStyle(color: Colors.white, fontSize: isMobile ? 16 : 24, shadows: const [Shadow(color: Colors.black, blurRadius: 15)])),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (isTablet)
                Padding(
                  padding: const EdgeInsets.only(top: 24.0, left: 24.0, right: 24.0),
                  child: Container(
                    height: 50, padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!)),
                    child: Row(children: [Icon(Icons.search, color: Colors.grey[400], size: 24), const SizedBox(width: 12), Expanded(child: Text('Buscar no cardápio...', style: TextStyle(color: Colors.grey[400], fontSize: 16)))]),
                  ),
                ),

              Container(
                constraints: const BoxConstraints(maxWidth: 1600),
                padding: EdgeInsets.symmetric(vertical: isMobile ? 40 : 60, horizontal: isMobile ? 20 : 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.star, color: corTema, size: isMobile ? 28 : 36),
                        const SizedBox(width: 12),
                        Expanded(child: Text('NOSSO CARDÁPIO', style: TextStyle(fontSize: isMobile ? 24 : 32, fontWeight: FontWeight.w900, color: corTema))),
                      ],
                    ),
                    const SizedBox(height: 32),
                    
                    if (todosProdutos.isEmpty)
                      Center(child: Text('Nenhum produto disponível.', style: TextStyle(color: corTema, fontSize: 18)))
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: screenWidth > 1200 ? 5 : (screenWidth > 900 ? 4 : (screenWidth > 600 ? 3 : 2)),
                          crossAxisSpacing: isMobile ? 16 : 32, 
                          mainAxisSpacing: isMobile ? 16 : 32, 
                          childAspectRatio: isMobile ? 0.65 : 0.70,
                        ),
                        itemCount: produtosExibidos.length,
                        itemBuilder: (context, index) {
                          final p = produtosExibidos[index];
                          final String nome = p['name'] ?? '';
                          final String desc = p['description'] ?? '';
                          final double preco = double.tryParse(p['price'].toString()) ?? 0.0;
                          final String urlCompleta = (p['image_url'] ?? '').toString();
                          final List<String> fotos = urlCompleta == 'null' ? [] : urlCompleta.split('|||').where((s) => s.isNotEmpty).toList();
                          final isHovered = _hoveredIndex == index;

                          return MouseRegion(
                            onEnter: (_) => setState(() => _hoveredIndex = index),
                            onExit: (_) => setState(() => _hoveredIndex = null),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                              transform: isHovered && !isMobile ? (Matrix4.identity()..translate(0, -10, 0)..scale(1.03)) : Matrix4.identity(),
                              child: GestureDetector(
                                onTap: () => _mostrarDetalhesProduto(p, corTema, corLetras, isMobile),
                                child: Card(
                                  color: Colors.white, 
                                  elevation: isHovered && !isMobile ? 20 : 4,
                                  shadowColor: isHovered ? corTema.withOpacity(0.6) : Colors.black12,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isMobile ? 12 : 20), side: BorderSide(color: isHovered ? corTema.withOpacity(0.5) : Colors.transparent, width: 2)),
                                  clipBehavior: Clip.antiAlias, 
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: fotos.isEmpty
                                              ? Icon(Icons.fastfood, size: 50, color: corTema.withOpacity(0.3))
                                              : CarrosselFotosPublicoWidget(fotos: fotos),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.all(isMobile ? 12.0 : 20.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(nome, style: TextStyle(fontWeight: FontWeight.w900, fontSize: isMobile ? 15 : 18, color: corTema), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            const SizedBox(height: 4),
                                            Text(desc, style: TextStyle(color: Colors.grey[700], fontSize: isMobile ? 12 : 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                                            const SizedBox(height: 8),
                                            Text('R\$ ${preco.toStringAsFixed(2).replaceAll('.', ',')}', style: TextStyle(color: corTema, fontWeight: FontWeight.w900, fontSize: isMobile ? 16 : 20)),
                                            const SizedBox(height: 12),
                                            SizedBox(
                                              width: double.infinity,
                                              height: isMobile ? 36 : 42,
                                              child: OutlinedButton(
                                                style: OutlinedButton.styleFrom(
                                                  backgroundColor: corTema.withOpacity(0.05),
                                                  side: BorderSide(color: corTema),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  padding: EdgeInsets.zero,
                                                ),
                                                onPressed: () => _mostrarDetalhesProduto(p, corTema, corLetras, isMobile),
                                                child: Text('ADICIONAR', style: TextStyle(color: corTema, fontWeight: FontWeight.w900, fontSize: isMobile ? 12 : 14)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    _buildPaginacao(todosProdutos.length, corTema, isMobile),
                  ],
                ),
              ),

              Container(
                width: double.infinity,
                color: const Color(0xFF151515), 
                padding: EdgeInsets.symmetric(vertical: isMobile ? 60 : 80, horizontal: isMobile ? 24 : 60),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1600),
                    child: screenWidth > 900 
                    ? Row( 
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFooterColunaLoja(isMobile),
                          _buildFooterColunaContato(corTema),
                        ],
                      )
                    : Column( 
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFooterColunaLoja(isMobile),
                          const SizedBox(height: 40),
                          _buildFooterColunaContato(corTema),
                        ],
                      )
                  ),
                ),
              ),
              
              Container(
                width: double.infinity,
                color: Colors.black,
                padding: EdgeInsets.only(
                  top: 24,
                  bottom: _quantidadeTotalItens > 0 ? (isMobile ? 100 : 120) : 24,
                ),
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
                constraints: const BoxConstraints(maxWidth: 900),
                margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
                height: isMobile ? 60 : 70,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366), 
                    foregroundColor: Colors.white,
                    elevation: 10,
                    shadowColor: const Color(0xFF25D366).withOpacity(0.6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36)),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: _abrirCarrinho,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 12.0 : 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 8),
                          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(24)),
                          child: Text('$_quantidadeTotalItens itens', style: TextStyle(fontWeight: FontWeight.w900, fontSize: isMobile ? 14 : 16)),
                        ),
                        if (!isMobile)
                          const Row(
                            children: [
                              Text('SEGUIR PARA ENTREGA', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5)),
                              SizedBox(width: 12),
                              Icon(Icons.arrow_forward_ios, size: 20),
                            ],
                          )
                        else
                          const Text('VER CARRINHO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5)),
                        Text('R\$ ${_valorTotalCarrinho.toStringAsFixed(2).replaceAll('.', ',')}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: isMobile ? 16 : 20)),
                      ],
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildFooterColunaLoja(bool isMobile) {
    return SizedBox(
      width: isMobile ? double.infinity : 500,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 60, height: 60, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), image: const DecorationImage(image: AssetImage('assets/images/logo.jpg'), fit: BoxFit.cover))),
              const SizedBox(width: 16),
              Expanded(child: Text("Açaiteria Shalom", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: isMobile ? 24 : 28))),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Diretamente do Pará, o melhor açaí aqui em Canindé. Açaí Premium, Cremes diversos e Gelatos Italianos!', style: TextStyle(color: Colors.grey, height: 1.8, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildFooterColunaContato(Color corTema) {
    return SizedBox(
      width: 400,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LOCALIZAÇÃO E REDES', style: TextStyle(color: corTema, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5)),
          const SizedBox(height: 24),
          _buildFooterRow(Icons.location_on, 'Rua Josias Gondim - 711, Santa Clara\nCanindé - CE'),
          const SizedBox(height: 16),
          _buildFooterRow(Icons.camera_alt, '@acaiteriashalom2026'),
          const SizedBox(height: 16),
          _buildFooterRow(Icons.access_time_filled, 'Aberto hoje!'),
        ],
      ),
    );
  }

  Widget _buildFooterRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        const SizedBox(width: 16),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, height: 1.5, fontSize: 15))),
      ],
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

  @override
  void initState() {
    super.initState();
    if (widget.fotos.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
        if (mounted && _pageController.hasClients) {
          _currentPage++;
          if (_currentPage >= widget.fotos.length) { _currentPage = 0; }
          _pageController.animateToPage(_currentPage, duration: const Duration(milliseconds: 800), curve: Curves.easeInOut);
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
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.fotos.length,
      onPageChanged: (index) => _currentPage = index,
      itemBuilder: (context, index) {
        final String foto = widget.fotos[index];
        return foto.startsWith('data:image')
            ? Image.memory(
                base64Decode(foto.split(',')[1]), 
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(color: Colors.grey[200], child: const Icon(Icons.fastfood, color: Colors.grey, size: 50)),
              )
            : Image.network(
                foto, 
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Image.asset('assets/images/logo.jpg', fit: BoxFit.cover),
              );
      },
    );
  }
}