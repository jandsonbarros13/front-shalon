import 'package:flutter/material.dart';
import 'package:acaiteria_front/features/auth/services/usuario_service.dart';

class UsuariosTab extends StatefulWidget {
  const UsuariosTab({super.key});

  @override
  State<UsuariosTab> createState() => _UsuariosTabState();
}

class _UsuariosTabState extends State<UsuariosTab> {
  final _usuarioService = UsuarioService();
  List<dynamic> _usuarios = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarUsuarios();
  }

  Future<void> _carregarUsuarios() async {
    setState(() => _isLoading = true);
    final lista = await _usuarioService.listarUsuarios();
    if (mounted) {
      setState(() {
        _usuarios = lista;
        _isLoading = false;
      });
    }
  }

  void _mostrarDialogUsuario({Map<String, dynamic>? usuario}) {
    final nomeController = TextEditingController(text: usuario?['nome'] ?? '');
    final usernameController = TextEditingController(text: usuario?['username'] ?? '');
    final passwordController = TextEditingController();
    final corTema = const Color(0xFF4A0E4E);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(usuario == null ? 'Novo Usuário' : 'Editar Usuário', style: TextStyle(color: corTema, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nomeController,
                    decoration: const InputDecoration(labelText: 'Nome Completo', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: usernameController,
                    decoration: const InputDecoration(labelText: 'Usuário (Username)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: usuario == null ? 'Senha (Password)' : 'Nova Senha (deixe em branco para não alterar)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: corTema, foregroundColor: Colors.white),
              onPressed: () async {
                if (nomeController.text.isEmpty || usernameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nome e Username são obrigatórios!'), backgroundColor: Colors.orange));
                  return;
                }

                if (usuario == null && passwordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A senha é obrigatória para novos usuários!'), backgroundColor: Colors.orange));
                  return;
                }

                Navigator.pop(context);
                setState(() => _isLoading = true);

                bool sucesso;
                if (usuario == null) {
                  final novoUsuario = {
                    'nome': nomeController.text,
                    'username': usernameController.text,
                    'password': passwordController.text,
                  };
                  sucesso = await _usuarioService.adicionarUsuario(novoUsuario);
                } else {
                  final usuarioEditado = {
                    'id': usuario['id'],
                    'nome': nomeController.text,
                    'username': usernameController.text,
                    if (passwordController.text.isNotEmpty) 'password': passwordController.text,
                  };
                  sucesso = await _usuarioService.editarUsuario(usuarioEditado);
                }

                if (sucesso) {
                  _carregarUsuarios();
                } else {
                  setState(() => _isLoading = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao salvar usuário.'), backgroundColor: Colors.red));
                  }
                }
              },
              child: const Text('Salvar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _excluirUsuario(int id, String nome) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Usuário', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Tem certeza que deseja excluir o acesso de $nome?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              final sucesso = await _usuarioService.excluirUsuario(id);
              if (sucesso) {
                _carregarUsuarios();
              } else {
                setState(() => _isLoading = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao excluir usuário.'), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final corTema = const Color(0xFF4A0E4E);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: corTema))
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Gerencie os acessos ao painel da Açaiteria.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: _usuarios.isEmpty
                          ? const Center(child: Text('Nenhum usuário cadastrado.', style: TextStyle(color: Colors.grey)))
                          : ListView.separated(
                              itemCount: _usuarios.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final u = _usuarios[index];

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  leading: CircleAvatar(
                                    backgroundColor: corTema,
                                    foregroundColor: Colors.white,
                                    child: const Icon(Icons.person),
                                  ),
                                  title: Text(u['nome'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                  subtitle: Text('Username: ${u['username'] ?? ''}', style: TextStyle(color: Colors.grey[600])),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue),
                                        onPressed: () => _mostrarDialogUsuario(usuario: u),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _excluirUsuario(u['id'], u['nome']),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarDialogUsuario(),
        backgroundColor: corTema,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Novo Usuário', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}