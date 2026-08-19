import 'package:flutter/material.dart';
import '../../features/auth/services/categoria_service.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:showcaseview/showcaseview.dart';

class CategoriasTab extends StatefulWidget {
  const CategoriasTab({super.key});

  @override
  State<CategoriasTab> createState() => _CategoriasTabState();
}

class _CategoriasTabState extends State<CategoriasTab> {
  final _categoriaService = CategoriaService();
  List<dynamic> _categorias = [];
  bool _isLoading = true;
  bool _isDarkMode = true; 

  final FlutterTts _flutterTts = FlutterTts();
  final GlobalKey _keyLista = GlobalKey();
  final GlobalKey _keyNovo = GlobalKey();

  final List<String> _textosMascote = [
    "Aqui você gerencia todas as categorias do seu cardápio, como Açaí, Bebidas e Adicionais. Você pode arrastar as categorias para mudar a ordem delas, ou editar e excluir clicando nos ícones.",
    "E para criar uma nova categoria, é só clicar neste botão de Nova Categoria!"
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
    _carregarCategorias();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _carregarCategorias() async {
    setState(() => _isLoading = true);
    final lista = await _categoriaService.listarCategorias();
    if (mounted) {
      setState(() {
        _categorias = lista;
        _isLoading = false;
      });
    }
  }

  Future<void> _salvarNovaOrdem() async {
    try {
      List<int> idsOrdenados = _categorias.map((c) => c['id'] as int).toList();
      
      await _categoriaService.atualizarOrdem(idsOrdenados);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ordem atualizada com sucesso!', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao salvar a nova ordem.', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 2),
          ),
        );
      }
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
                          "Esta é a tela de Categorias. Aqui você organiza seu cardápio criando seções como 'Açaí', 'Bebidas' ou 'Adicionais'.\n\n"
                          "Dica: Você pode segurar e arrastar uma categoria para mudar a ordem em que ela aparece para o cliente!\n\n"
                          "Quer fazer um Tour Guiado para ver como funciona?",
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
                            _keyLista,
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

  void _abrirModalCategoria({Map<String, dynamic>? categoria}) {
    final nomeController = TextEditingController(text: categoria != null ? categoria['nome'] : '');
    bool permiteAdicionais = categoria != null ? (categoria['permite_adicionais'] ?? false) : false;
    final bool isEdicao = categoria != null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder( // StatefulBuilder para atualizar o Switch dentro do Dialog
        builder: (context, setStateModal) {
          return AlertDialog(
            backgroundColor: cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              isEdicao ? 'Editar Categoria' : 'Nova Categoria',
              style: TextStyle(fontWeight: FontWeight.w900, color: accentColor),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomeController,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: 'Nome da Categoria',
                    hintText: 'Ex: Gelatos',
                    labelStyle: TextStyle(color: textSecColor),
                    hintStyle: TextStyle(color: textSecColor.withOpacity(0.5)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!), borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: accentColor, width: 2), borderRadius: BorderRadius.circular(10)),
                  ),
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black12 : Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? Colors.white24 : Colors.grey[300]!)
                  ),
                  child: SwitchListTile(
                    title: Text('Permite Adicionais e Extras?', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('Ative se os produtos dessa categoria poderão ter complementos (ex: coberturas, ingredientes extras).', style: TextStyle(color: textSecColor, fontSize: 12)),
                    value: permiteAdicionais,
                    activeColor: accentColor,
                    onChanged: (bool value) {
                      setStateModal(() {
                        permiteAdicionais = value;
                      });
                    },
                  ),
                )
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor, 
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                ),
                onPressed: () async {
                  if (nomeController.text.trim().isEmpty) return;
                  
                  Navigator.pop(context);
                  setState(() => _isLoading = true);

                  bool sucesso;
                  if (isEdicao) {
                    sucesso = await _categoriaService.editarCategoria(categoria['id'], nomeController.text, permiteAdicionais);
                  } else {
                    sucesso = await _categoriaService.cadastrarCategoria(nomeController.text, permiteAdicionais);
                  }

                  if (sucesso) {
                    _carregarCategorias();
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Categoria salva com sucesso!', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.green));
                  } else {
                    setState(() => _isLoading = false);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao salvar categoria.', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.redAccent));
                  }
                },
                child: const Text('Salvar', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      ),
    );
  }

  void _confirmarExclusao(int id, String nome) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Excluir Categoria?', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
        content: Text('Tem certeza que deseja remover a categoria "$nome"?', style: TextStyle(color: textColor)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent, 
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
            ),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              final sucesso = await _categoriaService.deletarCategoria(id);
              if (sucesso) {
                _carregarCategorias();
              } else {
                setState(() => _isLoading = false);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao excluir categoria.', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.redAccent));
              }
            },
            child: const Text('Excluir', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    'CONTROLE DE TIPOS / CATEGORIAS', 
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
                    Icon(Icons.category, color: accentColor, size: 16),
                    const SizedBox(width: 8),
                    Text('${_categorias.length} CADASTRADAS', style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ],
                ),
              )
            ],
          ),
          floatingActionButton: Showcase.withWidget(
            key: _keyNovo,
            container: _buildTooltipMascote(showcaseContext, _textosMascote[1], true),
            child: FloatingActionButton.extended(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
              elevation: 4,
              icon: const Icon(Icons.add, size: 24),
              label: const Text('Nova Categoria', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              onPressed: () => _abrirModalCategoria(),
            ),
          ),
          body: Stack(
            children: [
              _isLoading
                  ? Center(child: CircularProgressIndicator(color: accentColor))
                  : Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Gerenciamento de Tipos / Categorias', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textColor)),
                          const SizedBox(height: 8),
                          Text('Arraste as categorias para cima ou para baixo para alterar a ordem em que elas aparecem no catálogo.', style: TextStyle(color: textSecColor, fontSize: 15)),
                          const SizedBox(height: 30),
                          Expanded(
                            child: _categorias.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.category_outlined, size: 64, color: textSecColor.withOpacity(0.5)),
                                        const SizedBox(height: 16),
                                        Text('Nenhuma categoria cadastrada.', style: TextStyle(color: textSecColor, fontSize: 16, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  )
                                : Showcase.withWidget(
                                    key: _keyLista,
                                    container: _buildTooltipMascote(showcaseContext, _textosMascote[0], false),
                                    child: Card(
                                      color: cardColor,
                                      elevation: 4,
                                      shadowColor: Colors.black.withOpacity(0.1),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(color: isDark ? Colors.white10 : Colors.transparent),
                                      ),
                                      child: ReorderableListView.builder(
                                        buildDefaultDragHandles: false,
                                        itemCount: _categorias.length,
                                        onReorder: (oldIndex, newIndex) {
                                          setState(() {
                                            if (newIndex > oldIndex) {
                                              newIndex -= 1;
                                            }
                                            final item = _categorias.removeAt(oldIndex);
                                            _categorias.insert(newIndex, item);
                                          });
                                          _salvarNovaOrdem();
                                        },
                                        itemBuilder: (context, index) {
                                          final cat = _categorias[index];
                                          final bool permiteExtras = cat['permite_adicionais'] ?? false;
                                          return Container(
                                            key: ValueKey(cat['id']),
                                            decoration: BoxDecoration(
                                              border: Border(
                                                bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!)
                                              ),
                                              color: cardColor,
                                            ),
                                            child: ReorderableDragStartListener(
                                              index: index,
                                              child: ListTile(
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                                leading: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.drag_indicator, color: textSecColor),
                                                    const SizedBox(width: 16),
                                                    Container(
                                                      width: 48, height: 48,
                                                      decoration: BoxDecoration(
                                                        color: accentColor.withOpacity(0.15),
                                                        borderRadius: BorderRadius.circular(12)
                                                      ),
                                                      child: Icon(Icons.category, color: accentColor),
                                                    ),
                                                  ],
                                                ),
                                                title: Row(
                                                  children: [
                                                    Text(cat['nome'].toString().toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor)),
                                                    if (permiteExtras) ...[
                                                      const SizedBox(width: 8),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: Colors.green.withOpacity(0.2),
                                                          borderRadius: BorderRadius.circular(4),
                                                          border: Border.all(color: Colors.green.withOpacity(0.5))
                                                        ),
                                                        child: const Text('Com Adicionais', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                                                      )
                                                    ]
                                                  ],
                                                ),
                                                trailing: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                                      tooltip: 'Editar',
                                                      onPressed: () => _abrirModalCategoria(categoria: cat),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    IconButton(
                                                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                                                      tooltip: 'Excluir',
                                                      onPressed: () => _confirmarExclusao(cat['id'], cat['nome']),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),

              Positioned(
                bottom: 100, 
                right: 24,
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