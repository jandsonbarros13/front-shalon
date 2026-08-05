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

  final FlutterTts _flutterTts = FlutterTts();
  final GlobalKey _keyLista = GlobalKey();
  final GlobalKey _keyNovo = GlobalKey();

  final List<String> _textosMascote = [
    "Aqui você gerencia todas as categorias do seu cardápio, como Açaí, Bebidas e Adicionais. Você pode editar ou excluir clicando nos ícones ao lado.",
    "E para criar uma nova categoria, é só clicar neste botão amarelo de Nova Categoria!"
  ];

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
                          "Esta é a tela de Categorias. Aqui você organiza seu cardápio criando seções como 'Açaí', 'Bebidas' ou 'Adicionais'.\n\n"
                          "Quer fazer um Tour Guiado para ver como funciona?",
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
                            _keyLista,
                            _keyNovo,
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

  void _abrirModalCategoria({Map<String, dynamic>? categoria}) {
    final nomeController = TextEditingController(text: categoria != null ? categoria['nome'] : '');
    final bool isEdicao = categoria != null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isEdicao ? 'Editar Categoria' : 'Nova Categoria',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A0E4E)),
        ),
        content: TextField(
          controller: nomeController,
          decoration: const InputDecoration(
            labelText: 'Nome da Categoria',
            hintText: 'Ex: Sobremesas',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A0E4E), foregroundColor: Colors.white),
            onPressed: () async {
              if (nomeController.text.trim().isEmpty) return;
              
              Navigator.pop(context);
              setState(() => _isLoading = true);

              bool sucesso;
              if (isEdicao) {
                sucesso = await _categoriaService.editarCategoria(categoria['id'], nomeController.text);
              } else {
                sucesso = await _categoriaService.cadastrarCategoria(nomeController.text);
              }

              if (sucesso) {
                _carregarCategorias();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Categoria salva com sucesso!'), backgroundColor: Colors.green));
              } else {
                setState(() => _isLoading = false);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao salvar categoria.'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Salvar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmarExclusao(int id, String nome) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Categoria?'),
        content: Text('Tem certeza que deseja remover a categoria "$nome"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              final sucesso = await _categoriaService.deletarCategoria(id);
              if (sucesso) {
                _carregarCategorias();
              } else {
                setState(() => _isLoading = false);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao excluir categoria.'), backgroundColor: Colors.red));
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
    const corTema = Color(0xFF4A0E4E);

    return ShowCaseWidget(
      onStart: (index, key) => _playAudioForStep(index),
      onComplete: (index, key) => _flutterTts.stop(),
      onFinish: () => _flutterTts.stop(),
      builder: (showcaseContext) {
        return Scaffold(
          backgroundColor: Colors.grey[100],
          floatingActionButton: Showcase.withWidget(
            key: _keyNovo,
            container: _buildTooltipMascote(showcaseContext, _textosMascote[1], true),
            child: FloatingActionButton.extended(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add),
              label: const Text('Nova Categoria', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _abrirModalCategoria(),
            ),
          ),
          body: Stack(
            children: [
              _isLoading
                  ? const Center(child: CircularProgressIndicator(color: corTema))
                  : Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Gerenciamento de Tipos / Categorias', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: corTema)),
                          const SizedBox(height: 8),
                          const Text('Crie ou edite as categorias que aparecerão no catálogo e nos filtros.', style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 24),
                          Expanded(
                            child: _categorias.isEmpty
                                ? const Center(child: Text('Nenhuma categoria cadastrada.'))
                                : Showcase.withWidget(
                                    key: _keyLista,
                                    container: _buildTooltipMascote(showcaseContext, _textosMascote[0], false),
                                    child: Card(
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      child: ListView.separated(
                                        itemCount: _categorias.length,
                                        separatorBuilder: (context, index) => const Divider(height: 1),
                                        itemBuilder: (context, index) {
                                          final cat = _categorias[index];
                                          return ListTile(
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                            leading: CircleAvatar(
                                              backgroundColor: corTema.withOpacity(0.1),
                                              child: const Icon(Icons.category, color: corTema),
                                            ),
                                            title: Text(cat['nome'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                                  tooltip: 'Editar',
                                                  onPressed: () => _abrirModalCategoria(categoria: cat),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete, color: Colors.red),
                                                  tooltip: 'Excluir',
                                                  onPressed: () => _confirmarExclusao(cat['id'], cat['nome']),
                                                ),
                                              ],
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

              // Botão do Mascote Flutuante
              Positioned(
                bottom: 100, // Posicionado acima do botão "Nova Categoria"
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