import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:acaiteria_front/core/constants/api_constants.dart';
import 'package:acaiteria_front/features/auth/services/produto_service.dart';
import 'package:acaiteria_front/features/auth/services/produto_cache.dart';
import 'package:acaiteria_front/features/auth/services/imgbb_service.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:showcaseview/showcaseview.dart';

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
  final _maxAdicionaisGratuitosController = TextEditingController(text: '0');
  final ScrollController _scrollAdicionaisCtrl = ScrollController();

  List<String> _fotos = [];
  String _unidadeMedida = 'Unidade';
  String _categoria = 'Açai';
  bool _isSaving = false;
  bool _loadingDados = false; 
  bool _isUploadingImage = false;

  List<dynamic> _resultadosBusca = [];
  bool _buscaRealizada = false;

  final List<int> _adicionaisSelecionadosIds = [];
  final List<int> _produtosComboSelecionadosIds = [];

  List<String> _categorias = ['Açai', 'Cremes', 'Adicionais', 'Gelatos', 'Bebidas', 'Combos'];
  final List<String> _unidades = ['Unidade', 'Kg', 'Grama'];

  final FlutterTts _flutterTts = FlutterTts();
  final GlobalKey _keyCampos = GlobalKey();
  final GlobalKey _keyLista = GlobalKey();
  final GlobalKey _keySalvar = GlobalKey();

  final List<String> _textosMascote = [
    "Esta é a tela de Cadastro de Produtos! Preencha o nome, categoria, preço e estoque do seu item.",
    "Se for um Açaí, Creme ou Combo, você pode pesquisar e selecionar os adicionais aqui. Use as setas laterais para descer a lista se o mouse não estiver ajudando!",
    "Depois de adicionar uma foto bem bonita, clique aqui embaixo em Salvar para colocar o produto no cardápio!"
  ];

  @override
  void initState() {
    super.initState();
    _flutterTts.setLanguage("pt-BR");
    _inicializarFormulario();
  }

  Future<void> _inicializarFormulario() async {
    await _carregarCategorias();

    if (widget.produtoParaEditar != null) {
      setState(() => _loadingDados = true);
      
      final idStr = widget.produtoParaEditar!['id'] ?? widget.produtoParaEditar!['ID'];
      final int id = int.tryParse(idStr.toString()) ?? 0;
      
      final p = await _produtoService.buscarProdutoPorId(id) ?? widget.produtoParaEditar!;
      
      setState(() {
        _nomeController.text = p['name'] ?? p['Name'] ?? '';
        _descricaoController.text = p['description'] ?? p['Description'] ?? '';
        _precoController.text = (p['price'] ?? p['Price'] ?? '').toString();
        _estoqueController.text = (p['estoque'] ?? p['Estoque'] ?? '').toString();
        _maxAdicionaisGratuitosController.text = (p['max_adicionais_gratuitos'] ?? 0).toString();
        
        String catOriginal = p['category'] ?? p['Category'] ?? 'Açai';
        if (!_categorias.contains(catOriginal) && catOriginal.isNotEmpty) {
          _categorias.add(catOriginal);
          _categorias.sort();
        }
        _categoria = catOriginal.isEmpty ? 'Açai' : catOriginal;

        String un = (p['unidade_medida'] ?? p['UnidadeMedida'] ?? '').toString().toLowerCase();
        if (un == 'kg' || un == 'quilo') {
          _unidadeMedida = 'Kg';
        } else if (un == 'grama' || un == 'g') {
          _unidadeMedida = 'Grama';
        } else {
          _unidadeMedida = 'Unidade';
        }

        _adicionaisSelecionadosIds.clear();
        if (p['adicionais_ids'] != null) {
          for (var item in p['adicionais_ids']) {
            final val = int.tryParse(item.toString());
            if (val != null) _adicionaisSelecionadosIds.add(val);
          }
        }
        
        _produtosComboSelecionadosIds.clear();
        if (p['combo_itens_ids'] != null) {
          for (var item in p['combo_itens_ids']) {
            final val = int.tryParse(item.toString());
            if (val != null) _produtosComboSelecionadosIds.add(val);
          }
        }

        _fotos.clear();
        String imgUrl = p['image_url'] ?? p['ImageURL'] ?? p['imageURL'] ?? '';
        if (imgUrl.isNotEmpty && imgUrl != 'null') {
          _fotos = imgUrl.split('|||').where((s) => s.isNotEmpty).toList();
        }
      });
      await _executarPesquisaAPI();
    }
  }

  Future<void> _carregarCategorias() async {
    try {
      String urlBaseLimpa = ApiConstants.baseUrl.trim();
      if (urlBaseLimpa.endsWith('/')) {
        urlBaseLimpa = urlBaseLimpa.substring(0, urlBaseLimpa.length - 1);
      }
      if (urlBaseLimpa.endsWith('/api')) {
        urlBaseLimpa = urlBaseLimpa.substring(0, urlBaseLimpa.length - 4);
      }

      final url = Uri.parse('$urlBaseLimpa/api/categorias');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> dados = jsonDecode(response.body);
        Set<String> catSet = {};
        for (var item in dados) {
          if (item['nome'] != null) {
            catSet.add(item['nome'].toString().trim());
          }
        }
        
        if (mounted) {
          setState(() {
            if (catSet.isNotEmpty) {
              _categorias = catSet.toList()..sort();
            }
            if (!_categorias.contains(_categoria) && _categorias.isNotEmpty) {
              _categoria = _categorias.first;
            }
          });
        }
      }
    } catch (e) {
      print('Erro ao carregar categorias da API: $e');
    }
  }

  Future<String?> _mostrarDialogNovaCategoria() {
    TextEditingController ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova Categoria'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'Ex: Sobremesas', 
            border: OutlineInputBorder()
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text('Cancelar')
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A0E4E), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), 
            child: const Text('Adicionar')
          ),
        ],
      ),
    );
  }

  Future<void> _executarPesquisaAPI() async {
    final termo = _buscaFiltroController.text.trim();
    
    String catBusca = '';
    if (_categoria == 'Açai' || _categoria == 'Cremes') {
      catBusca = 'Adicionais';
    }

    setState(() => _loadingDados = true);

    final resultado = await _produtoService.buscarProdutos(1, nome: termo, categoria: catBusca, limit: 30);
    
    if (mounted) {
      setState(() {
        _resultadosBusca = resultado['produtos'] ?? [];
        _buscaRealizada = true;
        _loadingDados = false;
      });
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    _precoController.dispose();
    _estoqueController.dispose();
    _buscaFiltroController.dispose();
    _maxAdicionaisGratuitosController.dispose();
    _scrollAdicionaisCtrl.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  void _scrollAdicionais(double offset) {
    if (_scrollAdicionaisCtrl.hasClients) {
      final double target = _scrollAdicionaisCtrl.offset + offset;
      _scrollAdicionaisCtrl.animateTo(
        target.clamp(0.0, _scrollAdicionaisCtrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
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
    const corTema = Color(0xFF4A0E4E);
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 15, spreadRadius: 3)],
          border: Border.all(color: corTema, width: 3),
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
                  decoration: BoxDecoration(color: corTema.withOpacity(0.1), shape: BoxShape.circle),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/mascote_acenando.gif',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.record_voice_over, color: corTema),
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
                    backgroundColor: corTema,
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
                          "Aqui é onde a mágica acontece. Você pode criar novos produtos, escolher quais adicionais eles têm e ajustar tudo direitinho!\n\n"
                          "Quer fazer um Tour Guiado rápido?",
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
                            _keyCampos,
                            _keyLista,
                            _keySalvar,
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

  Future<void> _escolherFoto() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (pickedFile != null) {
      setState(() => _isUploadingImage = true); 
      
      try {
        final bytes = await pickedFile.readAsBytes();
        final rawBase64 = base64Encode(bytes); 

        final urlHospedada = await ImgbbService.uploadImage(rawBase64);

        if (urlHospedada != null) {
          setState(() {
            _fotos.add(urlHospedada); 
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Falha ao subir imagem pro servidor.'), backgroundColor: Colors.red)
            );
          }
        }
      } catch (e) {
        print("Erro ao processar a imagem: $e");
      } finally {
        setState(() => _isUploadingImage = false); 
      }
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
      'max_adicionais_gratuitos': int.tryParse(_maxAdicionaisGratuitosController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
      'image_url': _fotos.join('|||'),
      'size': '',
      'is_destaque': false,
      'adicionais_ids': (_categoria == 'Açai' || _categoria == 'Cremes') ? _adicionaisSelecionadosIds : [],
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

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.produtoParaEditar != null;
    const corTema = Color(0xFF4A0E4E);

    return ShowCaseWidget(
      onStart: (index, key) => _playAudioForStep(index),
      onComplete: (index, key) => _flutterTts.stop(),
      onFinish: () => _flutterTts.stop(),
      builder: (showcaseContext) {
        return Scaffold(
          backgroundColor: const Color(0xFFF4F6F8),
          appBar: AppBar(backgroundColor: corTema, foregroundColor: Colors.white, title: Text(isEdit ? 'Editar Produto' : 'Novo Produto', style: const TextStyle(fontWeight: FontWeight.w900))),
          body: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 120),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 750),
                      padding: const EdgeInsets.all(16.0),
                      child: Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Showcase.withWidget(
                                  key: _keyCampos,
                                  container: _buildTooltipMascote(showcaseContext, _textosMascote[0], false),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                              value: _categorias.contains(_categoria) ? _categoria : (_categorias.isNotEmpty ? _categorias.first : null),
                                              decoration: const InputDecoration(labelText: 'Categoria', prefixIcon: Icon(Icons.category_outlined, color: corTema), border: OutlineInputBorder()),
                                              items: [
                                                ..._categorias.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                                                const DropdownMenuItem(
                                                  value: 'nova_categoria', 
                                                  child: Row(children: [Icon(Icons.add_circle_outline, size: 18, color: corTema), SizedBox(width: 8), Text('Nova Categoria...', style: TextStyle(color: corTema, fontWeight: FontWeight.bold))])
                                                ),
                                              ],
                                              onChanged: (v) async {
                                                if (v == 'nova_categoria') {
                                                  String? nova = await _mostrarDialogNovaCategoria();
                                                  if (nova != null && nova.isNotEmpty) {
                                                    setState(() {
                                                      String formatada = nova[0].toUpperCase() + nova.substring(1);
                                                      if (!_categorias.contains(formatada)) {
                                                        _categorias.add(formatada);
                                                        _categorias.sort();
                                                      }
                                                      _categoria = formatada;
                                                      _buscaFiltroController.clear();
                                                      _resultadosBusca.clear();
                                                      _buscaRealizada = false;
                                                    });
                                                  } else {
                                                    setState(() {}); 
                                                  }
                                                } else {
                                                  setState(() { 
                                                    _categoria = v!; 
                                                    _buscaFiltroController.clear();
                                                    _resultadosBusca.clear();
                                                    _buscaRealizada = false;
                                                  });
                                                }
                                              },
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
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (_categoria == 'Açai' || _categoria == 'Cremes') ...[
                                  TextFormField(
                                    controller: _maxAdicionaisGratuitosController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    decoration: const InputDecoration(
                                      labelText: 'Qtd. de Adicionais Gratuitos',
                                      helperText: 'Ex: 3 (Os 3 primeiros são grátis, o 4º em diante cobra o valor do item)',
                                      prefixIcon: Icon(Icons.star_outline, color: corTema),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                if (_categoria == 'Açai' || _categoria == 'Combos' || _categoria == 'Cremes') ...[
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  Showcase.withWidget(
                                    key: _keyLista,
                                    container: _buildTooltipMascote(showcaseContext, _textosMascote[1], false),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text((_categoria == 'Açai' || _categoria == 'Cremes') ? 'Pesquisar e Selecionar Adicionais' : 'Pesquisar e Selecionar Itens do Combo', style: const TextStyle(color: corTema, fontSize: 14, fontWeight: FontWeight.bold)),
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
                                                onSubmitted: (_) => _executarPesquisaAPI(),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            SizedBox(
                                              height: 48,
                                              child: ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(backgroundColor: corTema, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                                onPressed: _executarPesquisaAPI,
                                                icon: const Icon(Icons.search),
                                                label: const Text('Buscar', style: TextStyle(fontWeight: FontWeight.bold)),
                                              ),
                                            )
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        if (_loadingDados)
                                          const SizedBox(height: 110, child: Center(child: CircularProgressIndicator(color: corTema)))
                                        else if (_buscaRealizada || isEdit)
                                          SizedBox(
                                            height: 300, 
                                            child: _resultadosBusca.isEmpty 
                                                ? const Center(child: Text('Nenhum item encontrado na pesquisa.', style: TextStyle(fontSize: 14, color: Colors.grey)))
                                                : Container(
                                                    decoration: BoxDecoration(
                                                      border: Border.all(color: Colors.grey[200]!),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          child: ListView.separated(
                                                            controller: _scrollAdicionaisCtrl,
                                                            padding: const EdgeInsets.all(12),
                                                            itemCount: _resultadosBusca.length,
                                                            separatorBuilder: (context, index) => const Divider(height: 16),
                                                            itemBuilder: (context, index) {
                                                              final item = _resultadosBusca[index];
                                                              final int id = item['id'] ?? item['ID'];
                                                              final bool sel = (_categoria == 'Açai' || _categoria == 'Cremes') ? _adicionaisSelecionadosIds.contains(id) : _produtosComboSelecionadosIds.contains(id);
                                                              final String adNome = item['name'] ?? item['Name'] ?? '';
                                                              final double adPreco = double.tryParse((item['price'] ?? item['Price'] ?? 0).toString()) ?? 0.0;
                                                              final String imgUrl = item['image_url'] ?? item['ImageURL'] ?? '';
                                                              final List<String> f = imgUrl.split('|||').where((s) => s.isNotEmpty).toList();

                                                              String textoPreco = (_categoria == 'Açai' || _categoria == 'Cremes') 
                                                                  ? '+R\$ ${adPreco.toStringAsFixed(2).replaceAll('.', ',')}'
                                                                  : (item['category'] ?? item['Category'] ?? '');

                                                              return InkWell(
                                                                onTap: () {
                                                                  setState(() {
                                                                    if (_categoria == 'Açai' || _categoria == 'Cremes') {
                                                                      sel ? _adicionaisSelecionadosIds.remove(id) : _adicionaisSelecionadosIds.add(id);
                                                                    } else {
                                                                      sel ? _produtosComboSelecionadosIds.remove(id) : _produtosComboSelecionadosIds.add(id);
                                                                    }
                                                                  });
                                                                },
                                                                child: Row(
                                                                  children: [
                                                                    ClipRRect(
                                                                      borderRadius: BorderRadius.circular(8),
                                                                      child: SizedBox(
                                                                        width: 50, height: 50,
                                                                        child: f.isEmpty || f.first == 'null'
                                                                            ? Container(color: Colors.grey[200], child: Icon(Icons.fastfood, color: Colors.grey[400]))
                                                                            : (f.first.startsWith('data:image') 
                                                                                ? Image.memory(base64Decode(f.first.split(',')[1]), fit: BoxFit.cover)
                                                                                : Image.network(f.first, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.broken_image, color: Colors.grey[400])))
                                                                      )
                                                                    ),
                                                                    const SizedBox(width: 12),
                                                                    Expanded(
                                                                      child: Column(
                                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                                        children: [
                                                                          Text(adNome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                                                                          const SizedBox(height: 4),
                                                                          Text(textoPreco, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 13)),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                    Container(
                                                                      width: 24, height: 24,
                                                                      decoration: BoxDecoration(
                                                                        shape: BoxShape.circle,
                                                                        border: Border.all(color: sel ? corTema : Colors.grey[400]!, width: 2),
                                                                        color: sel ? corTema : Colors.transparent,
                                                                      ),
                                                                      child: sel ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                                                                    )
                                                                  ],
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                        Container(
                                                          width: 40,
                                                          decoration: BoxDecoration(
                                                            border: Border(left: BorderSide(color: Colors.grey[200]!)),
                                                            color: Colors.grey[50],
                                                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(12))
                                                          ),
                                                          child: Column(
                                                            children: [
                                                              Expanded(
                                                                child: InkWell(
                                                                  onTap: () => _scrollAdicionais(-200),
                                                                  child: const Center(child: Icon(Icons.arrow_drop_up, size: 32, color: corTema)),
                                                                ),
                                                              ),
                                                              const Divider(height: 1),
                                                              Expanded(
                                                                child: InkWell(
                                                                  onTap: () => _scrollAdicionais(200),
                                                                  child: const Center(child: Icon(Icons.arrow_drop_down, size: 32, color: corTema)),
                                                                ),
                                                              ),
                                                            ]
                                                          )
                                                        )
                                                      ],
                                                    ),
                                                  ),
                                          )
                                        else
                                          const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('Use o campo acima para pesquisar itens.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)))),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 8),
                                const Text('Fotos do Produto', style: TextStyle(color: corTema, fontSize: 14, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 12),
                                _loadingDados
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
                                          _isUploadingImage
                                              ? Container(width: 85, height: 85, decoration: BoxDecoration(color: const Color(0xFFF1F3F5), borderRadius: BorderRadius.circular(8), border: Border.all(color: corTema.withOpacity(0.3))), child: const Center(child: CircularProgressIndicator(color: corTema, strokeWidth: 2)))
                                              : InkWell(
                                                  onTap: _escolherFoto,
                                                  child: Container(width: 85, height: 85, decoration: BoxDecoration(color: const Color(0xFFF1F3F5), borderRadius: BorderRadius.circular(8), border: Border.all(color: corTema.withOpacity(0.3))), child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, color: corTema, size: 24), SizedBox(height: 4), Text('Adicionar', style: TextStyle(color: corTema, fontSize: 10, fontWeight: FontWeight.bold))])),
                                                ),
                                        ],
                                      ),
                                const SizedBox(height: 24),
                                Showcase.withWidget(
                                  key: _keySalvar,
                                  container: _buildTooltipMascote(showcaseContext, _textosMascote[2], true),
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: 46,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: corTema, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                                      onPressed: _isSaving ? null : _salvar,
                                      icon: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save_outlined),
                                      label: Text(isEdit ? 'SALVAR ALTERAÇÕES' : 'CADASTRAR PRODUTO', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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