import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:acaiteria_front/core/constants/api_constants.dart';
import 'package:acaiteria_front/features/auth/services/catalogo_service.dart';
import 'package:acaiteria_front/features/auth/services/produto_service.dart';
import 'package:acaiteria_front/features/auth/services/imgbb_service.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:showcaseview/showcaseview.dart';

class FormCatalogoPage extends StatefulWidget {
  final Map<String, dynamic>? catalogoParaEditar;

  const FormCatalogoPage({super.key, this.catalogoParaEditar});

  @override
  State<FormCatalogoPage> createState() => _FormCatalogoPageState();
}

class _FormCatalogoPageState extends State<FormCatalogoPage> {
  final _catalogoService = CatalogoService();
  final _produtoService = ProdutoService(); 
  
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _descricaoController = TextEditingController();
  final TextEditingController _pesquisaController = TextEditingController();

  String _corTema = '#4A0E4E';
  String _corLetras = '#FFFFFF';
  String _fotoCapa = '';
  bool _isSaving = false;
  bool _isUploadingCapa = false; 
  
  bool _isLoadingEdit = true;
  bool _isSearching = false;
  bool _isDarkMode = true;
  
  List<dynamic> _resultadosPesquisa = [];
  int? _produtoSelecionadoId; 
  List<dynamic> _produtosSelecionados = []; 
  
  final Map<int, TextEditingController> _precoControllers = {};
  final Map<int, TextEditingController> _estoqueControllers = {};
  final Map<int, TextEditingController> _obsControllers = {};

  final FlutterTts _flutterTts = FlutterTts();
  final GlobalKey _keyCampos = GlobalKey();
  final GlobalKey _keyCores = GlobalKey();
  final GlobalKey _keyProdutos = GlobalKey();
  final GlobalKey _keySalvar = GlobalKey();

  final List<String> _textosMascote = [
    "Aqui você define o nome do seu catálogo e a frase de chamariz para os seus clientes.",
    "Nesta parte, você personaliza as cores para ficarem com a cara da sua marca e escolhe uma foto de capa bem chamativa!",
    "Pesquise e adicione os produtos que você quer mostrar neste catálogo. Você pode até definir preços e estoques diferentes do padrão da loja!",
    "Quando tudo estiver do seu jeito, é só clicar em Salvar para colocar o catálogo no ar!"
  ];

  final List<String> _opcoesCorTema = [
    '#4A0E4E', '#800080', '#E1306C', '#FF0000', '#FF8C00', '#25D366', '#000000', '#1E90FF', 
  ];

  final List<String> _opcoesCorLetras = [
    '#FFFFFF', '#F1F3F5', '#000000', '#FFD700', 
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
    if (widget.catalogoParaEditar != null) {
      final cat = widget.catalogoParaEditar!;
      _tituloController.text = cat['titulo'] ?? '';
      _descricaoController.text = cat['descricao'] ?? '';
      _corTema = cat['cor_tema'] ?? '#4A0E4E';
      _corLetras = cat['cor_letras'] ?? '#FFFFFF';
      _fotoCapa = cat['foto_capa'] ?? '';
      _carregarDadosDaEdicao(cat['id'], cat['chave']);
    } else {
      _isLoadingEdit = false;
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _tituloController.dispose();
    _descricaoController.dispose();
    _pesquisaController.dispose();
    for (var p in _precoControllers.values) { p.dispose(); }
    for (var e in _estoqueControllers.values) { e.dispose(); }
    for (var o in _obsControllers.values) { o.dispose(); }
    super.dispose();
  }

  Color _hexToColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return accentColor;
    }
  }

  Future<void> _carregarDadosDaEdicao(int id, String chave) async {
    try {
      String urlBaseLimpa = ApiConstants.baseUrl.trim();
      if (urlBaseLimpa.endsWith('/')) {
        urlBaseLimpa = urlBaseLimpa.substring(0, urlBaseLimpa.length - 1);
      }
      if (urlBaseLimpa.endsWith('/api')) {
        urlBaseLimpa = urlBaseLimpa.substring(0, urlBaseLimpa.length - 4);
      }

      final urlCat = Uri.parse('$urlBaseLimpa/api/catalogo/$id');
      final resCat = await http.get(urlCat);
      
      final urlPub = Uri.parse('$urlBaseLimpa/api/catalogo-publico/$chave');
      final resPub = await http.get(urlPub);

      if (resCat.statusCode == 200 && resPub.statusCode == 200) {
        final pivotData = jsonDecode(resCat.body)['produtos'] as List;
        final pubData = jsonDecode(resPub.body)['produtos'] as List;

        for (var pEdicao in pivotData) {
          final int pId = pEdicao['produto_id'] ?? 0;
          final originalInfo = pubData.where((p) => p['id'] == pId).firstOrNull;
          
          if (originalInfo != null) {
            _produtosSelecionados.add({
              'id': pId,
              'name': originalInfo['name'],
              'price': originalInfo['price'],
              'estoque': originalInfo['estoque'],
              'image_url': originalInfo['image_url'],
            });
            _precoControllers[pId] = TextEditingController(text: (pEdicao['preco_personalizado'] ?? '').toString());
            _estoqueControllers[pId] = TextEditingController(text: (pEdicao['estoque_personalizado'] ?? '').toString());
            _obsControllers[pId] = TextEditingController(text: pEdicao['observacao'] ?? '');
          }
        }
      }
      setState(() => _isLoadingEdit = false);
    } catch (_) {
      setState(() => _isLoadingEdit = false);
    }
  }

  Future<void> _pesquisarProdutosNoBanco(String termo) async {
    if (termo.isEmpty) return;
    
    setState(() {
      _isSearching = true;
      _produtoSelecionadoId = null; 
      _resultadosPesquisa = [];
    });

    try {
      final resultado = await _produtoService.buscarProdutos(1, nome: termo, limit: 50);
      final List<dynamic> dados = resultado['produtos'] ?? [];

      setState(() {
        _resultadosPesquisa = dados.where((p) {
          final int pId = int.tryParse((p['id'] ?? p['ID'] ?? 0).toString()) ?? 0;
          return !_produtosSelecionados.any((sel) => sel['id'] == pId);
        }).toList();
        
        _isSearching = false;
      });
    } catch (_) {
      setState(() => _isSearching = false);
    }
  }

  void _adicionarProdutoAoCatalogo(Map<String, dynamic> produto) {
    final int id = int.tryParse((produto['id'] ?? produto['ID'] ?? 0).toString()) ?? 0;
    setState(() {
      _produtosSelecionados.insert(0, {
        'id': id,
        'name': produto['name'] ?? produto['Name'] ?? 'Sem Nome',
        'price': produto['price'] ?? produto['Price'] ?? 0,
        'estoque': produto['estoque'] ?? produto['Estoque'] ?? 0,
        'image_url': produto['image_url'] ?? produto['ImageURL'] ?? '',
      }); 
      _precoControllers[id] = TextEditingController(text: (produto['price'] ?? produto['Price'] ?? '').toString());
      _estoqueControllers[id] = TextEditingController(text: (produto['estoque'] ?? produto['Estoque'] ?? '').toString());
      _obsControllers[id] = TextEditingController(text: '');
      
      _produtoSelecionadoId = null;
      _resultadosPesquisa = [];
      _pesquisaController.clear();
    });
  }

  void _removerProdutoDoCatalogo(int id) {
    setState(() {
      _produtosSelecionados.removeWhere((p) => p['id'] == id);
      _precoControllers[id]?.dispose();
      _estoqueControllers[id]?.dispose();
      _obsControllers[id]?.dispose();
      
      _precoControllers.remove(id);
      _estoqueControllers.remove(id);
      _obsControllers.remove(id);
    });
  }

  Future<void> _escolherFotoCapa() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (pickedFile != null) {
      setState(() => _isUploadingCapa = true); 
      
      try {
        final bytes = await pickedFile.readAsBytes();
        final rawBase64 = base64Encode(bytes); 
        
        final urlHospedada = await ImgbbService.uploadImage(rawBase64);

        if (urlHospedada != null) {
          setState(() {
            _fotoCapa = urlHospedada; 
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Falha ao subir capa pro servidor.', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.redAccent)
            );
          }
        }
      } catch (e) {
        debugPrint("Erro ao processar a capa: $e");
      } finally {
        setState(() => _isUploadingCapa = false); 
      }
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    List<Map<String, dynamic>> produtosParaSalvar = [];
    for (var p in _produtosSelecionados) {
      final id = p['id'];
      produtosParaSalvar.add({
        'id': id,
        'preco': double.tryParse(_precoControllers[id]?.text.replaceAll(',', '.') ?? '0') ?? 0.0,
        'estoque': int.tryParse(_estoqueControllers[id]?.text ?? '0') ?? 0,
        'observacao': _obsControllers[id]?.text.trim() ?? '',
      });
    }

    String chaveGerada = widget.catalogoParaEditar?['chave'] ?? _tituloController.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

    final dadosCatalogo = {
      'id': widget.catalogoParaEditar?['id'] ?? 0,
      'chave': chaveGerada,
      'titulo': _tituloController.text.trim(),
      'descricao': _descricaoController.text.trim(),
      'cor_tema': _corTema,
      'cor_letras': _corLetras,
      'foto_capa': _fotoCapa,
      'produtos': produtosParaSalvar, 
    };

    final resultado = await _catalogoService.salvarCatalogo(dadosCatalogo);
    
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (resultado['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Catálogo salvo com sucesso!', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.green));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: ${resultado['message']}', style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.redAccent));
    }
  }

  void _playAudioForStep(int? index) async {
    await _flutterTts.stop();
    await Future.delayed(const Duration(milliseconds: 300));
    if (index != null && index >= 0 && index < _textosMascote.length) {
      await _flutterTts.speak(_textosMascote[index]);
    }
  }

  Widget _buildTooltipMascote(BuildContext context, String texto, bool isLast, Color corTemaDinamica) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 15, spreadRadius: 3)],
          border: Border.all(color: corTemaDinamica, width: 3),
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
                  decoration: BoxDecoration(color: corTemaDinamica.withOpacity(0.1), shape: BoxShape.circle),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/mascote_acenando.gif',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(Icons.record_voice_over, color: corTemaDinamica),
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
                    backgroundColor: corTemaDinamica,
                    foregroundColor: _hexToColor(_corLetras),
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
            )
          ],
        ),
      ),
    );
  }

  void _mostrarMensagemMascote(BuildContext showcaseContext, Color corTemaDinamica) {
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
              border: Border.all(color: corTemaDinamica, width: 3),
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
                      errorBuilder: (_, __, ___) => Icon(Icons.sentiment_satisfied_alt, size: 80, color: corTemaDinamica),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E2C) : Colors.grey[100], borderRadius: BorderRadius.circular(16)),
                        child: Text(
                          "Olá! Sou o mascote da Açaiteria Shalom! 🍇\n\n"
                          "Aqui é onde a mágica acontece. Você pode personalizar as cores, a capa e escolher a dedo os produtos deste catálogo.\n\n"
                          "Quer fazer um Tour Guiado rápido?",
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
                          backgroundColor: corTemaDinamica,
                          foregroundColor: _hexToColor(_corLetras),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          ShowCaseWidget.of(showcaseContext).startShowCase([
                            _keyCampos,
                            _keyCores,
                            _keyProdutos,
                            _keySalvar,
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

  Widget _buildColorPicker(String title, String currentValue, List<String> options, Function(String) onSelect) {
    final corTemaDinamica = _hexToColor(_corTema);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: corTemaDinamica, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: options.map((hex) {
            final isSelected = currentValue == hex;
            final isWhite = hex == '#FFFFFF' || hex == '#F1F3F5';
            return InkWell(
              onTap: () => onSelect(hex),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _hexToColor(hex),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? corTemaDinamica : (isWhite ? Colors.grey[300]! : Colors.transparent), 
                    width: isSelected ? 3 : 1
                  ),
                  boxShadow: isSelected ? [BoxShadow(color: corTemaDinamica.withOpacity(0.3), blurRadius: 8, spreadRadius: 2)] : [],
                ),
                child: isSelected 
                  ? Icon(Icons.check, color: isWhite ? Colors.black : Colors.white) 
                  : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.catalogoParaEditar != null;
    final corTemaDinamica = _hexToColor(_corTema);
    final corLetrasDinamica = _hexToColor(_corLetras);

    return ShowCaseWidget(
      onStart: (index, key) => _playAudioForStep(index),
      onComplete: (index, key) => _flutterTts.stop(),
      onFinish: () => _flutterTts.stop(),
      builder: (showcaseContext) {
        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: corTemaDinamica,
            foregroundColor: corLetrasDinamica,
            title: Text(isEdit ? 'Editar Catálogo' : 'Novo Catálogo', style: const TextStyle(fontWeight: FontWeight.w900)),
            elevation: 0,
            actions: [
              IconButton(
                icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: corLetrasDinamica),
                tooltip: 'Alternar Tema',
                onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
              ),
            ],
          ),
          body: Stack(
            children: [
              Positioned.fill(
                child: _isLoadingEdit 
                  ? Center(child: CircularProgressIndicator(color: corTemaDinamica))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 120),
                      child: Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 900),
                          padding: const EdgeInsets.all(16.0),
                          child: Card(
                            color: cardColor,
                            elevation: isDark ? 4 : 2,
                            shadowColor: Colors.black.withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: isDark ? Colors.white10 : Colors.transparent),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isEdit ? 'Atualizar Dados do Catálogo' : 'Criar Novo Catálogo',
                                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: corTemaDinamica, letterSpacing: -0.5),
                                    ),
                                    const SizedBox(height: 32),
                                    Showcase.withWidget(
                                      key: _keyCampos,
                                      container: _buildTooltipMascote(showcaseContext, _textosMascote[0], false, corTemaDinamica),
                                      child: Column(
                                        children: [
                                          TextFormField(
                                            controller: _tituloController,
                                            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                                            decoration: InputDecoration(
                                              labelText: 'Título do Catálogo (Nome da Loja)',
                                              labelStyle: TextStyle(color: textSecColor),
                                              filled: true,
                                              fillColor: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF1F3F4),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: corTemaDinamica, width: 2), borderRadius: BorderRadius.circular(8)),
                                            ),
                                            validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
                                          ),
                                          const SizedBox(height: 24),
                                          TextFormField(
                                            controller: _descricaoController,
                                            maxLines: 2,
                                            style: TextStyle(color: textColor),
                                            decoration: InputDecoration(
                                              labelText: 'Descrição / Slogan',
                                              labelStyle: TextStyle(color: textSecColor),
                                              filled: true,
                                              fillColor: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF1F3F4),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: corTemaDinamica, width: 2), borderRadius: BorderRadius.circular(8)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                    Showcase.withWidget(
                                      key: _keyCores,
                                      container: _buildTooltipMascote(showcaseContext, _textosMascote[1], false, corTemaDinamica),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(24),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF8F9FA),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                _buildColorPicker('Escolha a Cor do Tema', _corTema, _opcoesCorTema, (hex) => setState(() => _corTema = hex)),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                                                  child: Divider(color: isDark ? Colors.white10 : Colors.grey[300]),
                                                ),
                                                _buildColorPicker('Escolha a Cor das Letras (Botões e Títulos)', _corLetras, _opcoesCorLetras, (hex) => setState(() => _corLetras = hex)),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 32),
                                          Text('Foto de Capa do Catálogo (Banner)', style: TextStyle(color: corTemaDinamica, fontSize: 14, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 12),
                                          Wrap(
                                            crossAxisAlignment: WrapCrossAlignment.end,
                                            spacing: 16,
                                            runSpacing: 16,
                                            children: [
                                              ConstrainedBox(
                                                constraints: const BoxConstraints(maxWidth: 300),
                                                child: Container(
                                                  height: 140,
                                                  width: double.infinity,
                                                  decoration: BoxDecoration(
                                                    color: isDark ? const Color(0xFF1E1E2C) : Colors.grey[200],
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: isDark ? Colors.white24 : Colors.grey[300]!),
                                                  ),
                                                  child: _isUploadingCapa 
                                                      ? Center(child: CircularProgressIndicator(color: corTemaDinamica))
                                                      : _fotoCapa.isEmpty
                                                          ? Icon(Icons.wallpaper, color: textSecColor.withOpacity(0.5), size: 40)
                                                          : ClipRRect(
                                                              borderRadius: BorderRadius.circular(8),
                                                              child: _fotoCapa.startsWith('data:image')
                                                                  ? Image.memory(base64Decode(_fotoCapa.split(',')[1]), fit: BoxFit.cover)
                                                                  : Image.network(_fotoCapa, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image)),
                                                            ),
                                                ),
                                              ),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  ElevatedButton.icon(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF1F3F5),
                                                      foregroundColor: corTemaDinamica,
                                                      elevation: 0,
                                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        side: BorderSide(color: corTemaDinamica.withOpacity(0.3)),
                                                      ),
                                                    ),
                                                    onPressed: _isUploadingCapa ? null : _escolherFotoCapa, 
                                                    icon: _isUploadingCapa 
                                                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                                        : const Icon(Icons.add_a_photo, size: 18),
                                                    label: Text(
                                                      _isUploadingCapa ? 'Enviando...' : (_fotoCapa.isEmpty ? 'Escolher Capa' : 'Alterar Capa'), 
                                                      style: const TextStyle(fontWeight: FontWeight.bold)
                                                    ),
                                                  ),
                                                  if (_fotoCapa.isNotEmpty && !_isUploadingCapa) ...[
                                                    const SizedBox(width: 8),
                                                    IconButton(
                                                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                                                      onPressed: () => setState(() => _fotoCapa = ''),
                                                      tooltip: 'Remover Capa',
                                                    ),
                                                  ]
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 40),
                                    Divider(color: isDark ? Colors.white10 : Colors.grey[300]),
                                    const SizedBox(height: 16),
                                    Showcase.withWidget(
                                      key: _keyProdutos,
                                      container: _buildTooltipMascote(showcaseContext, _textosMascote[2], false, corTemaDinamica),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Localizar e Adicionar Produto', style: TextStyle(color: corTemaDinamica, fontSize: 18, fontWeight: FontWeight.w900)),
                                          const SizedBox(height: 16),
                                          Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF1E1E2C) : corTemaDinamica.withOpacity(0.05),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: corTemaDinamica.withOpacity(0.2)),
                                            ),
                                            child: Wrap(
                                              crossAxisAlignment: WrapCrossAlignment.end,
                                              spacing: 16,
                                              runSpacing: 16,
                                              children: [
                                                SizedBox(
                                                  width: 250,
                                                  child: TextFormField(
                                                    controller: _pesquisaController,
                                                    style: TextStyle(color: textColor),
                                                    decoration: InputDecoration(
                                                      labelText: 'Cód. ou Descrição',
                                                      labelStyle: TextStyle(color: textSecColor),
                                                      filled: true,
                                                      fillColor: cardColor,
                                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: corTemaDinamica, width: 2)),
                                                      suffixIcon: _isSearching 
                                                        ? const Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(strokeWidth: 2))
                                                        : IconButton(
                                                            icon: const Icon(Icons.search, color: Colors.redAccent),
                                                            onPressed: () => _pesquisarProdutosNoBanco(_pesquisaController.text),
                                                          ),
                                                    ),
                                                    onFieldSubmitted: (v) => _pesquisarProdutosNoBanco(v),
                                                  ),
                                                ),
                                                
                                                SizedBox(
                                                  width: 320,
                                                  child: DropdownButtonFormField<int>(
                                                    isExpanded: true,
                                                    dropdownColor: cardColor,
                                                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                                                    decoration: InputDecoration(
                                                      labelText: 'Produto',
                                                      labelStyle: TextStyle(color: textSecColor),
                                                      filled: true,
                                                      fillColor: cardColor,
                                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: corTemaDinamica, width: 2)),
                                                    ),
                                                    hint: Text('Selecione...', style: TextStyle(color: textSecColor)),
                                                    value: _produtoSelecionadoId,
                                                    items: _resultadosPesquisa.map((p) {
                                                      final int id = int.tryParse((p['id'] ?? p['ID'] ?? 0).toString()) ?? 0;
                                                      final String nome = p['name'] ?? p['Name'] ?? 'Sem Nome';
                                                      return DropdownMenuItem<int>(
                                                        value: id,
                                                        child: Text(nome, overflow: TextOverflow.ellipsis),
                                                      );
                                                    }).toList(),
                                                    onChanged: (val) {
                                                      setState(() => _produtoSelecionadoId = val);
                                                    },
                                                  ),
                                                ),
                                                SizedBox(
                                                  height: 56, 
                                                  child: ElevatedButton.icon(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: const Color(0xFFD32F2F),
                                                      foregroundColor: Colors.white,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                      padding: const EdgeInsets.symmetric(horizontal: 24),
                                                    ),
                                                    icon: const Icon(Icons.add_circle_outline),
                                                    label: const Text('Adicionar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                                    onPressed: _produtoSelecionadoId == null ? null : () {
                                                      final produto = _resultadosPesquisa.firstWhere(
                                                        (p) => int.tryParse((p['id'] ?? p['ID']).toString()) == _produtoSelecionadoId
                                                      );
                                                      _adicionarProdutoAoCatalogo(produto);
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 32),
                                          _produtosSelecionados.isEmpty
                                              ? Center(child: Padding(
                                                  padding: const EdgeInsets.all(32.0),
                                                  child: Text('Nenhum produto adicionado. Use a barra de pesquisa acima.', style: TextStyle(color: textSecColor)),
                                                ))
                                              : ListView.separated(
                                                  shrinkWrap: true,
                                                  physics: const NeverScrollableScrollPhysics(),
                                                  itemCount: _produtosSelecionados.length,
                                                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                                                  itemBuilder: (context, index) {
                                                    final p = _produtosSelecionados[index];
                                                    final int id = p['id'] ?? 0;
                                                    final String nome = p['name'] ?? 'Sem nome';
                                                    final String urlCompleta = p['image_url'] ?? '';
                                                    final List<String> fotos = urlCompleta.split('|||').where((s) => s.isNotEmpty).toList();

                                                    return Container(
                                                      decoration: BoxDecoration(
                                                        color: cardColor,
                                                        borderRadius: BorderRadius.circular(12),
                                                        border: Border.all(color: corTemaDinamica, width: 1.5),
                                                        boxShadow: [BoxShadow(color: corTemaDinamica.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
                                                      ),
                                                      child: Column(
                                                        children: [
                                                          ListTile(
                                                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                            leading: Container(
                                                              width: 50,
                                                              height: 50,
                                                              decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E2C) : Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                                                              child: ClipRRect(
                                                                borderRadius: BorderRadius.circular(8),
                                                                child: fotos.isEmpty || fotos.first == 'null'
                                                                    ? Icon(Icons.fastfood, color: textSecColor)
                                                                    : fotos.first.startsWith('data:image')
                                                                        ? Image.memory(base64Decode(fotos.first.split(',')[1]), fit: BoxFit.cover)
                                                                        : Image.network(fotos.first, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.image)),
                                                              ),
                                                            ),
                                                            title: Text(nome, style: TextStyle(fontWeight: FontWeight.bold, color: corTemaDinamica)),
                                                            subtitle: Text('Preço Base: R\$ ${p['price']} | Estoque: ${p['estoque']}', style: TextStyle(fontSize: 12, color: textSecColor)),
                                                            trailing: IconButton(
                                                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                                              onPressed: () => _removerProdutoDoCatalogo(id),
                                                            ),
                                                          ),
                                                          Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[300]),
                                                          Padding(
                                                            padding: const EdgeInsets.all(16.0),
                                                            child: Column(
                                                              children: [
                                                                Wrap(
                                                                  spacing: 16,
                                                                  runSpacing: 16,
                                                                  children: [
                                                                    SizedBox(
                                                                      width: 150,
                                                                      child: TextFormField(
                                                                        controller: _precoControllers[id],
                                                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                                                                        decoration: InputDecoration(
                                                                          labelText: 'Preço Personalizado',
                                                                          labelStyle: TextStyle(color: textSecColor),
                                                                          isDense: true,
                                                                          filled: true,
                                                                          fillColor: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF1F3F4),
                                                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                                                          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: corTemaDinamica), borderRadius: BorderRadius.circular(8)),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    SizedBox(
                                                                      width: 150,
                                                                      child: TextFormField(
                                                                        controller: _estoqueControllers[id],
                                                                        keyboardType: TextInputType.number,
                                                                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                                                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                                                                        decoration: InputDecoration(
                                                                          labelText: 'Qtd. neste catálogo',
                                                                          labelStyle: TextStyle(color: textSecColor),
                                                                          isDense: true,
                                                                          filled: true,
                                                                          fillColor: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF1F3F4),
                                                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                                                          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: corTemaDinamica), borderRadius: BorderRadius.circular(8)),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                                const SizedBox(height: 16),
                                                                TextFormField(
                                                                  controller: _obsControllers[id],
                                                                  style: TextStyle(color: textColor),
                                                                  decoration: InputDecoration(
                                                                    labelText: 'Observação (Ex: Apenas Delivery, Promoção)',
                                                                    labelStyle: TextStyle(color: textSecColor),
                                                                    isDense: true,
                                                                    filled: true,
                                                                    fillColor: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF1F3F4),
                                                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                                                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: corTemaDinamica), borderRadius: BorderRadius.circular(8)),
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
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 40),
                                    Showcase.withWidget(
                                      key: _keySalvar,
                                      container: _buildTooltipMascote(showcaseContext, _textosMascote[3], true, corTemaDinamica),
                                      child: SizedBox(
                                        width: double.infinity,
                                        height: 56,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: corTemaDinamica,
                                            foregroundColor: corLetrasDinamica,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: _isSaving ? null : _salvar,
                                          child: _isSaving 
                                            ? CircularProgressIndicator(color: corLetrasDinamica)
                                            : Text(
                                                isEdit ? 'SALVAR ALTERAÇÕES' : 'CRIAR CATÁLOGO', 
                                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)
                                              ),
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
                  onTap: () => _mostrarMensagemMascote(showcaseContext, corTemaDinamica),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: corTemaDinamica.withOpacity(0.3),
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
                          decoration: BoxDecoration(color: corTemaDinamica, shape: BoxShape.circle),
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