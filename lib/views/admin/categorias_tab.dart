import 'package:flutter/material.dart';
import '../../features/auth/services/categoria_service.dart';

class CategoriasTab extends StatefulWidget {
  const CategoriasTab({super.key});

  @override
  State<CategoriasTab> createState() => _CategoriasTabState();
}

class _CategoriasTabState extends State<CategoriasTab> {
  final _categoriaService = CategoriaService();
  List<dynamic> _categorias = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarCategorias();
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
              
              Navigator.pop(context); // Fecha o modal imediatamente
              setState(() => _isLoading = true);

              bool sucesso;
              if (isEdicao) {
                sucesso = await _categoriaService.editarCategoria(categoria['id'], nomeController.text);
              } else {
                sucesso = await _categoriaService.cadastrarCategoria(nomeController.text);
              }

              if (sucesso) {
                _carregarCategorias();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Categoria salva com sucesso!'), backgroundColor: Colors.green));
              } else {
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao salvar categoria.'), backgroundColor: Colors.red));
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
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao excluir categoria.'), backgroundColor: Colors.red));
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

    return Scaffold(
      backgroundColor: Colors.grey[100],
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFFFD700),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Nova Categoria', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _abrirModalCategoria(),
      ),
      body: _isLoading
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
                        : Card(
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
                ],
              ),
            ),
    );
  }
}