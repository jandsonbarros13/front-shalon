import 'package:flutter/material.dart';
import 'package:acaiteria_front/features/auth/services/usuario_service.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:showcaseview/showcaseview.dart';

class UsuariosTab extends StatefulWidget {
  const UsuariosTab({super.key});

  @override
  State<UsuariosTab> createState() => _UsuariosTabState();
}

class _UsuariosTabState extends State<UsuariosTab> {
  final _usuarioService = UsuarioService();
  List<dynamic> _usuarios = [];
  bool _isLoading = true;

  final FlutterTts _flutterTts = FlutterTts();
  final GlobalKey _keyLista = GlobalKey();
  final GlobalKey _keyNovo = GlobalKey();

  final List<String> _textosMascote = [
    "Aqui você gerencia quem tem acesso ao painel do sistema. Você pode editar ou excluir os usuários existentes.",
    "Para dar acesso a um novo funcionário, basta clicar neste botão amarelo!"
  ];

  @override
  void initState() {
    super.initState();
    _flutterTts.setLanguage("pt-BR");
    _carregarUsuarios();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
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
                          "Aqui você controla quem pode acessar o sistema. É muito importante manter essas informações seguras!\n\n"
                          "Quer que eu te mostre como funciona rapidinho?",
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

  @override
  Widget build(BuildContext context) {
    final corTema = const Color(0xFF4A0E4E);

    return ShowCaseWidget(
      onStart: (index, key) => _playAudioForStep(index),
      onComplete: (index, key) => _flutterTts.stop(),
      onFinish: () => _flutterTts.stop(),
      builder: (showcaseContext) {
        return Scaffold(
          backgroundColor: const Color(0xFFF4F6F8),
          body: Stack(
            children: [
              _isLoading
                  ? Center(child: CircularProgressIndicator(color: corTema))
                  : Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Gerencie os acessos ao painel da Açaiteria.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                          const SizedBox(height: 24),
                          Expanded(
                            child: Showcase.withWidget(
                              key: _keyLista,
                              container: _buildTooltipMascote(showcaseContext, _textosMascote[0], false),
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
                          ),
                        ],
                      ),
                    ),
              Positioned(
                bottom: 100,
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
                          decoration: BoxDecoration(color: corTema, shape: BoxShape.circle),
                          child: const Icon(Icons.help_outline, color: Colors.white, size: 35),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: Showcase.withWidget(
            key: _keyNovo,
            container: _buildTooltipMascote(showcaseContext, _textosMascote[1], true),
            child: FloatingActionButton.extended(
              onPressed: () => _mostrarDialogUsuario(),
              backgroundColor: corTema,
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text('Novo Usuário', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        );
      }
    );
  }
}