import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acaiteria_front/features/auth/services/produto_service.dart';
import 'package:acaiteria_front/features/auth/services/produto_cache.dart';

class CadastroProdutoPage extends StatefulWidget {
  final Map<String, dynamic>? produtoParaEditar;

  const CadastroProdutoPage({super.key, this.produtoParaEditar});

  @override
  State<CadastroProdutoPage> createState() => _CadastroProdutoPageState();
}

class _CadastroProdutoPageState extends State<CadastroProdutoPage> {
  final _produtoService = ProdutoService();
  final _cache = ProdutoCache();
  final _formKey = GlobalKey<FormState>();
  
  final _nomeController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _precoController = TextEditingController();
  final _estoqueController = TextEditingController();
  final _buscaFiltroController = TextEditingController();

  List<String> _fotos = [];
  String _unidadeMedida = 'Unidade';
  String _categoria = 'Montados';
  bool _isSaving = false;
  bool _loadingFotoEdicao = false;

  List<dynamic> _todosAdicionaisCache = [];
  List<dynamic> _todosProdutosComboCache = [];
  List<dynamic> _resultadosBusca = [];
  bool _buscaRealizada = false;

  final List<int> _adicionaisSelecionadosIds = [];
  final List<int> _produtosComboSelecionadosIds = [];

  final List<String> _categorias = ['Montados', 'Combos', 'Bebidas', 'Produtos', 'Adicionais'];
  final List<String> _unidades = ['Unidade', 'Kg', 'Grama'];

  @override
  void initState() {
    super.initState();
    _carregarCacheEInicializarFormulario();
  }

  Future<void> _carregarCacheEInicializarFormulario() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheAdicionais = prefs.getString('cache_json_adicionais');
    final cacheCombos = prefs.getString('cache_json_combos');

    if (cacheAdicionais != null && cacheCombos != null) {
      _todosAdicionaisCache = jsonDecode(cacheAdicionais);
      _todosProdutosComboCache = jsonDecode(cacheCombos);
      _atualizarCacheBackground(prefs); 
    } else {
      await _atualizarCacheBackground(prefs);
    }

    if (widget.produtoParaEditar != null) {
      setState(() => _loadingFotoEdicao = true);
      final p = widget.produtoParaEditar!;
      _nomeController.text = p['name'] ?? '';
      _descricaoController.text = p['description'] ?? '';
      _precoController.text = (p['price'] ?? '').toString();
      _estoqueController.text = (p['estoque'] ?? '').toString();
      _categoria = p['category'] ?? 'Montados';

      String un = (p['unidade_medida'] ?? '').toString().toLowerCase();
      if (un == 'kg' || un == 'quilo') {
        _unidadeMedida = 'Kg';
      } else if (un == 'grama' || un == 'g') {
        _unidadeMedida = 'Grama';
      } else {
        _unidadeMedida = 'Unidade';
      }

      if (p['adicionais_ids'] != null) {
        for (var id in p['adicionais_ids']) {
          _adicionaisSelecionadosIds.add(id as int);
        }
      }
      if (p['combo_itens_ids'] != null) {
        for (var id in p['combo_itens_ids']) {
          _produtosComboSelecionadosIds.add(id as int);
        }
      }

      _mostrarSelecionadosPorPadrao();

      // Carregamento instantâneo da foto a partir da memória
      String imgUrl = p['image_url'] ?? p['ImageURL'] ?? p['imageURL'] ?? '';
      if (imgUrl.isNotEmpty) {
        _fotos = imgUrl.split('|||').where((s) => s.isNotEmpty).toList();
      }

      if (mounted) {
        setState(() => _loadingFotoEdicao = false);
      }
    }
  }

  Future<void> _atualizarCacheBackground(SharedPreferences prefs) async {
    try {
      final resultado = await _produtoService.buscarProdutos(1, limit: 1000);
      final todos = resultado['produtos'] as List? ?? [];
      if (todos.isNotEmpty) {
        _todosAdicionaisCache = todos.where((p) => p['category'] == 'Adicionais' || p['Category'] == 'Adicionais').toList();
        _todosProdutosComboCache = todos.where((p) => p['category'] != 'Combos' && p['Category'] != 'Combos').toList();
        
        await prefs.setString('cache_json_adicionais', jsonEncode(_todosAdicionaisCache));
        await prefs.setString('cache_json_combos', jsonEncode(_todosProdutosComboCache));
      }
    } catch (_) {}
  }

  void _mostrarSelecionadosPorPadrao() {
    setState(() {
      _buscaRealizada = true;
      if (_categoria == 'Montados') {
        _resultadosBusca = _todosAdicionaisCache.where((ad) => _adicionaisSelecionadosIds.contains(ad['id'] ?? ad['ID'])).toList();
      } else if (_categoria == 'Combos') {
        _resultadosBusca = _todosProdutosComboCache.where((prod) => _produtosComboSelecionadosIds.contains(prod['id'] ?? prod['ID'])).toList();
      }
    });
  }

  void _executarPesquisa() {
    final termo = _buscaFiltroController.text.trim().toLowerCase();
    
    if (termo.isEmpty) {
      _mostrarSelecionadosPorPadrao();
      return;
    }

    setState(() {
      _buscaRealizada = true;
      if (_categoria == 'Montados') {
        _resultadosBusca = _todosAdicionaisCache.where((ad) {
          final nome = (ad['name'] ?? ad['Name'] ?? '').toString().toLowerCase();
          return nome.contains(termo) || _adicionaisSelecionadosIds.contains(ad['id'] ?? ad['ID']);
        }).toList();
      } else if (_categoria == 'Combos') {
        _resultadosBusca = _todosProdutosComboCache.where((prod) {
          final nome = (prod['name'] ?? prod['Name'] ?? '').toString().toLowerCase();
          return nome.contains(termo) || _produtosComboSelecionadosIds.contains(prod['id'] ?? prod['ID']);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    _precoController.dispose();
    _estoqueController.dispose();
    _buscaFiltroController.dispose();
    super.dispose();
  }

  Future<void> _escolherFoto() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 40);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      final base64Image = 'data:${pickedFile.mimeType ?? "image/jpeg"};base64,${base64Encode(bytes)}';
      setState(() {
        _fotos.add(base64Image);
      });
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    String precoLimpo = _precoController.text.replaceAll('R\$', '').trim().replaceAll(',', '.');

    final dadosProduto = {
      if (widget.produtoParaEditar != null) 'id': widget.produtoParaEditar!['id'] ?? widget.produtoParaEditar!['ID'],
      'name': _nomeController.text.trim(),
      'description': _descricaoController.text.trim(),
      'category': _categoria,
      'unidade_medida': _unidadeMedida,
      'price': double.tryParse(precoLimpo) ?? 0.0,
      'estoque': int.tryParse(_estoqueController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
      'image_url': _fotos.join('|||'),
      'size': '',
      'is_destaque': false,
      'adicionais_ids': _categoria == 'Montados' ? _adicionaisSelecionadosIds : [],
      'combo_itens_ids': _categoria == 'Combos' ? _produtosComboSelecionadosIds : [],
    };

    dynamic resultado;
    if (widget.produtoParaEditar != null) {
      resultado = await _produtoService.editarProduto(widget.produtoParaEditar!['id'] ?? widget.produtoParaEditar!['ID'], dadosProduto);
    } else {
      resultado = await _produtoService.cadastrarProduto(dadosProduto);
    }

    setState(() => _isSaving = false);

    if (resultado != null && resultado['success'] == true) {
      if (widget.produtoParaEditar == null && resultado['id'] != null) {
        dadosProduto['id'] = resultado['id'];
      }
      _cache.invalidarEAtualizar(dadosProduto);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvo com sucesso!'), backgroundColor: Colors.green));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao salvar o produto.'), backgroundColor: Colors.red));
    }
  }

  Widget _buildCardSelecao(int id, String nome, String labelExtra, String imgUrl, bool selecionado, VoidCallback onTap) {
    List<String> f = imgUrl.split('|||').where((s) => s.isNotEmpty).toList();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 130,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selecionado ? const Color(0xFFFFD700).withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selecionado ? const Color(0xFFFFD700) : Colors.grey[300]!, width: selecionado ? 2 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 55, height: 50,
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(6)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: f.isEmpty
                    ? const Icon(Icons.fastfood_outlined, color: Color(0xFF4A0E4E), size: 20)
                    : f.first.startsWith('data:image')
                        ? Image.memory(base64Decode(f.first.split(',')[1]), fit: BoxFit.cover)
                        : Image.network(f.first, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)),
              ),
            ),
            const SizedBox(height: 4),
            Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(labelExtra, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.produtoParaEditar != null;
    const corTema = Color(0xFF4A0E4E);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(backgroundColor: corTema, foregroundColor: Colors.white, title: Text(isEdit ? 'Editar Produto' : 'Novo Produto', style: const TextStyle(fontWeight: FontWeight.w900))),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 750),
          padding: const EdgeInsets.all(16.0),
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Text(isEdit ? 'Atualizar Dados' : 'Cadastrar Novo Produto', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: corTema)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nomeController,
                      decoration: const InputDecoration(labelText: 'Nome do Produto', prefixIcon: Icon(Icons.shopping_bag_outlined, color: corTema), border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _categoria,
                            decoration: const InputDecoration(labelText: 'Categoria', prefixIcon: Icon(Icons.category_outlined, color: corTema), border: OutlineInputBorder()),
                            items: _categorias.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (v) => setState(() { 
                              _categoria = v!; 
                              _buscaFiltroController.clear();
                              _buscaRealizada = false;
                              _resultadosBusca.clear();
                            }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _unidadeMedida,
                            decoration: const InputDecoration(labelText: 'Venda por', prefixIcon: Icon(Icons.scale_outlined, color: corTema), border: OutlineInputBorder()),
                            items: _unidades.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                            onChanged: (v) => setState(() => _unidadeMedida = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(controller: _descricaoController, maxLines: 2, decoration: const InputDecoration(labelText: 'Descrição', border: OutlineInputBorder())),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _precoController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Preço (R\$)', prefixIcon: Icon(Icons.attach_money, color: corTema), border: OutlineInputBorder()),
                            validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _estoqueController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(labelText: 'Estoque', prefixIcon: Icon(Icons.inventory_2_outlined, color: corTema), border: OutlineInputBorder()),
                            validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                          ),
                        ),
                      ],
                    ),
                    if (_categoria == 'Montados' || _categoria == 'Combos') ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(_categoria == 'Montados' ? 'Pesquisar e Selecionar Adicionais' : 'Pesquisar e Selecionar Itens do Combo', style: const TextStyle(color: corTema, fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _buscaFiltroController,
                              decoration: InputDecoration(
                                hintText: 'Digite o nome para buscar...', 
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                              onSubmitted: (_) => _executarPesquisa(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: corTema, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                              onPressed: _executarPesquisa,
                              icon: const Icon(Icons.search),
                              label: const Text('Buscar', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_buscaRealizada || isEdit)
                        SizedBox(
                          height: 110,
                          child: _resultadosBusca.isEmpty 
                              ? const Center(child: Text('Nenhum item encontrado na pesquisa.', style: TextStyle(fontSize: 12, color: Colors.grey)))
                              : ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: _resultadosBusca.map((item) {
                                    final int id = item['id'] ?? item['ID'];
                                    final bool sel = _categoria == 'Montados' ? _adicionaisSelecionadosIds.contains(id) : _produtosComboSelecionadosIds.contains(id);
                                    final String labelExtra = _categoria == 'Montados' ? '+R\$ ${item['price']}' : (item['category'] ?? item['Category'] ?? '');
                                    
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: _buildCardSelecao(id, item['name'] ?? item['Name'] ?? '', labelExtra, item['image_url'] ?? '', sel, () {
                                        setState(() { 
                                          if (_categoria == 'Montados') {
                                            sel ? _adicionaisSelecionadosIds.remove(id) : _adicionaisSelecionadosIds.add(id); 
                                          } else {
                                            sel ? _produtosComboSelecionadosIds.remove(id) : _produtosComboSelecionadosIds.add(id); 
                                          }
                                        });
                                      }),
                                    );
                                  }).toList(),
                                ),
                        )
                      else
                        const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('Use o campo acima para pesquisar itens.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)))),
                    ],
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text('Fotos do Produto', style: TextStyle(color: corTema, fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _loadingFotoEdicao
                        ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: corTema))))
                        : Wrap(
                            spacing: 8, runSpacing: 8,
                            children: [
                              ..._fotos.asMap().entries.map((entry) {
                                int idx = entry.key;
                                String f = entry.value;
                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 85, height: 85,
                                      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[300]!)),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: f.startsWith('data:image')
                                            ? Image.memory(base64Decode(f.split(',')[1]), fit: BoxFit.cover)
                                            : Image.network(f, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)),
                                      ),
                                    ),
                                    Positioned(top: -4, right: -4, child: GestureDetector(onTap: () => setState(() => _fotos.removeAt(idx)), child: Container(padding: const EdgeInsets.all(3), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 10)))),
                                  ],
                                );
                              }),
                              InkWell(
                                onTap: _escolherFoto,
                                child: Container(width: 85, height: 85, decoration: BoxDecoration(color: const Color(0xFFF1F3F5), borderRadius: BorderRadius.circular(8), border: Border.all(color: corTema.withOpacity(0.3))), child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, color: corTema, size: 24), SizedBox(height: 4), Text('Adicionar', style: TextStyle(color: corTema, fontSize: 10, fontWeight: FontWeight.bold))])),
                              ),
                            ],
                          ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: corTema, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                        onPressed: _isSaving ? null : _salvar,
                        icon: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save_outlined),
                        label: Text(isEdit ? 'SALVAR ALTERAÇÕES' : 'CADASTRAR PRODUTO', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}