import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:acaiteria_front/core/constants/api_constants.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:showcaseview/showcaseview.dart';

class UsuariosTab extends StatefulWidget {
  const UsuariosTab({super.key});

  @override
  State<UsuariosTab> createState() => _UsuariosTabState();
}

class _UsuariosTabState extends State<UsuariosTab> {
  List<dynamic> _usuarios = [];
  bool _isLoading = true;
  bool _isDarkMode = true;

  final FlutterTts _flutterTts = FlutterTts();
  final GlobalKey _keyLista = GlobalKey();
  final GlobalKey _keyNovo = GlobalKey();

  final List<String> _textosMascote = [
    "Aqui você gerencia todos os usuários que têm acesso ao painel do sistema. Você pode editar permissões ou excluir um usuário.",
    "Para cadastrar um novo operador ou administrador, clique no botão Novo Usuário!"
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
    _carregarUsuarios();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  String _getUrlBase() {
    String urlBaseLimpa = ApiConstants.baseUrl.trim();
    if (urlBaseLimpa.endsWith('/')) {
      urlBaseLimpa = urlBaseLimpa.substring(0, urlBaseLimpa.length - 1);
    }
    if (urlBaseLimpa.endsWith('/api')) {
      urlBaseLimpa = urlBaseLimpa.substring(0, urlBaseLimpa.length - 4);
    }
    return urlBaseLimpa;
  }

  Future<void> _carregarUsuarios() async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('${_getUrlBase()}/api/usuarios');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _usuarios = data is List ? data : (data['usuarios'] ?? []);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
                          "Esta é a tela de Usuários. Aqui você gerencia quem tem acesso ao sistema.\n\n"
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

  void _abrirModalUsuario({Map<String, dynamic>? usuario}) {
    final nomeController = TextEditingController(text: usuario != null ? (usuario['nome'] ?? usuario['name'] ?? '') : '');
    final emailController = TextEditingController(text: usuario != null ? (usuario['email'] ?? '') : '');
    final senhaController = TextEditingController();
    String tipoSelecionado = usuario != null ? (usuario['tipo'] ?? usuario['role'] ?? 'Caixa') : 'Caixa';
    final bool isEdicao = usuario != null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            isEdicao ? 'Editar Usuário' : 'Novo Usuário',
            style: TextStyle(fontWeight: FontWeight.w900, color: accentColor),
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomeController,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: 'Nome',
                    labelStyle: TextStyle(color: textSecColor),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!), borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: 'E-mail de Acesso',
                    labelStyle: TextStyle(color: textSecColor),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!), borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: senhaController,
                  obscureText: true,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: isEdicao ? 'Nova Senha (Opcional)' : 'Senha',
                    labelStyle: TextStyle(color: textSecColor),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!), borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: tipoSelecionado,
                  dropdownColor: cardColor,
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Função / Perfil',
                    labelStyle: TextStyle(color: textSecColor),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!), borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Admin', child: Text('Administrador')),
                    DropdownMenuItem(value: 'Caixa', child: Text('Operador de Caixa')),
                  ],
                  onChanged: (val) => setModalState(() => tipoSelecionado = val ?? 'Caixa'),
                ),
              ],
            ),
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
                if (nomeController.text.trim().isEmpty || emailController.text.trim().isEmpty) return;
                if (!isEdicao && senhaController.text.trim().isEmpty) return;

                Navigator.pop(context);
                setState(() => _isLoading = true);

                try {
                  final dados = {
                    'nome': nomeController.text.trim(),
                    'email': emailController.text.trim(),
                    'tipo': tipoSelecionado,
                    if (senhaController.text.trim().isNotEmpty) 'senha': senhaController.text.trim(),
                  };

                  final url = isEdicao
                      ? Uri.parse('${_getUrlBase()}/api/usuarios/${usuario['id'] ?? usuario['ID']}')
                      : Uri.parse('${_getUrlBase()}/api/usuarios');
                  
                  final response = isEdicao
                      ? await http.put(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode(dados))
                      : await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode(dados));

                  if (response.statusCode == 200 || response.statusCode == 201) {
                    _carregarUsuarios();
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuário salvo com sucesso!', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.green));
                  } else {
                    setState(() => _isLoading = false);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao salvar usuário.', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.redAccent));
                  }
                } catch (e) {
                  setState(() => _isLoading = false);
                }
              },
              child: const Text('Salvar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarExclusao(int id, String nome) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Excluir Usuário?', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
        content: Text('Tem certeza que deseja remover o usuário "$nome"?', style: TextStyle(color: textColor)),
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
              try {
                final url = Uri.parse('${_getUrlBase()}/api/usuarios/$id');
                final response = await http.delete(url);
                if (response.statusCode == 200) {
                  _carregarUsuarios();
                } else {
                  setState(() => _isLoading = false);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao excluir usuário.', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.redAccent));
                }
              } catch (e) {
                setState(() => _isLoading = false);
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
                    'CONTROLE DE USUÁRIOS', 
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
                    Icon(Icons.people, color: accentColor, size: 16),
                    const SizedBox(width: 8),
                    Text('${_usuarios.length} REGISTRADOS', style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
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
              label: const Text('Novo Usuário', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              onPressed: () => _abrirModalUsuario(),
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
                          Text('Gerenciamento de Equipe', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textColor)),
                          const SizedBox(height: 8),
                          Text('Cadastre operadores de caixa ou administradores para acessar o painel.', style: TextStyle(color: textSecColor, fontSize: 15)),
                          const SizedBox(height: 30),
                          Expanded(
                            child: _usuarios.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.people_outline, size: 64, color: textSecColor.withOpacity(0.5)),
                                        const SizedBox(height: 16),
                                        Text('Nenhum usuário cadastrado.', style: TextStyle(color: textSecColor, fontSize: 16, fontWeight: FontWeight.bold)),
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
                                      child: ListView.separated(
                                        itemCount: _usuarios.length,
                                        separatorBuilder: (context, index) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
                                        itemBuilder: (context, index) {
                                          final u = _usuarios[index];
                                          final nome = u['nome'] ?? u['name'] ?? 'Usuário';
                                          final email = u['email'] ?? '';
                                          final tipo = u['tipo'] ?? u['role'] ?? 'Caixa';
                                          final id = u['id'] ?? u['ID'] ?? 0;

                                          return ListTile(
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                            leading: Container(
                                              width: 48, height: 48,
                                              decoration: BoxDecoration(
                                                color: accentColor.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(12)
                                              ),
                                              child: Icon(tipo.toString().toLowerCase() == 'admin' ? Icons.admin_panel_settings : Icons.person, color: accentColor),
                                            ),
                                            title: Text(nome.toString().toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor)),
                                            subtitle: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const SizedBox(height: 4),
                                                Text(email, style: TextStyle(color: textSecColor, fontSize: 13)),
                                                const SizedBox(height: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: (tipo.toString().toLowerCase() == 'admin' ? Colors.purple : Colors.teal).withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: (tipo.toString().toLowerCase() == 'admin' ? Colors.purple : Colors.teal).withOpacity(0.5)),
                                                  ),
                                                  child: Text(tipo.toString().toUpperCase(), style: TextStyle(color: tipo.toString().toLowerCase() == 'admin' ? Colors.purpleAccent : Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 10)),
                                                )
                                              ],
                                            ),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                                  tooltip: 'Editar',
                                                  onPressed: () => _abrirModalUsuario(usuario: u),
                                                ),
                                                const SizedBox(width: 8),
                                                IconButton(
                                                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                                                  tooltip: 'Excluir',
                                                  onPressed: () => _confirmarExclusao(id, nome),
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