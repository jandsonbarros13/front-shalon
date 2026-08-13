import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:acaiteria_front/features/auth/services/empresa_service.dart';
import 'package:acaiteria_front/features/auth/services/imgbb_service.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:showcaseview/showcaseview.dart';

class EmpresaTab extends StatefulWidget {
  const EmpresaTab({super.key});

  @override
  State<EmpresaTab> createState() => _EmpresaTabState();
}

class _EmpresaTabState extends State<EmpresaTab> {
  final _formKey = GlobalKey<FormState>();
  final _empresaService = EmpresaService();

  final _nomeController = TextEditingController();
  final _sloganController = TextEditingController();
  final _cnpjController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _chavePixController = TextEditingController();
  final _valorMinimoController = TextEditingController();
  final _corTemaController = TextEditingController();
  final _ruaController = TextEditingController();
  final _numeroController = TextEditingController();
  final _bairroController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _ufController = TextEditingController();
  final _horarioController = TextEditingController();
  final _instagramController = TextEditingController();

  String _logoUrl = '';
  String _mascoteUrl = '';
  bool _ifoodAtivo = false;
  bool _promocoesAtivo = true;
  bool _cuponsAtivo = true;

  bool _carregando = true;
  bool _isSalvando = false;
  bool _isDarkMode = true;
  bool _isUploadingLogo = false;
  bool _isUploadingMascote = false;

  final FlutterTts _flutterTts = FlutterTts();
  final GlobalKey _keyGerais = GlobalKey();
  final GlobalKey _keyImagens = GlobalKey();
  final GlobalKey _keyRegras = GlobalKey();
  final GlobalKey _keyEndereco = GlobalKey();

  final List<String> _textosMascote = [
    "Neste primeiro quadro, você preenche as informações básicas da sua loja, como Nome, CNPJ e os meios de contato para os clientes.",
    "Aqui você sobe a Logo da sua marca e o Mascote! Eles vão aparecer na tela inicial dos catálogos.",
    "Aqui ficam as regras e botões do sistema. Altere a cor, ligue ou desligue o botão do iFood, Promoções e Cupons de Desconto.",
    "Por fim, coloque seu endereço completo e os horários de funcionamento. Ah, não esqueça de clicar no botão salvar no final da tela!"
  ];

  bool get isDark => _isDarkMode;

  Color _hexToColor(String hex) {
    if (hex.isEmpty) return isDark ? const Color(0xFFE040FB) : const Color(0xFF4A0E4E);
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return isDark ? const Color(0xFFE040FB) : const Color(0xFF4A0E4E);
    }
  }

  Color get accentColor => _hexToColor(_corTemaController.text);
  Color get bgColor => isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF4F6F8);
  Color get cardColor => isDark ? const Color(0xFF27293D) : Colors.white;
  Color get textColor => isDark ? Colors.white : Colors.black87;
  Color get textSecColor => isDark ? Colors.white54 : Colors.grey[600]!;

  @override
  void initState() {
    super.initState();
    _flutterTts.setLanguage("pt-BR");
    _carregarDadosEmpresa();
  }

  ImageProvider _obterLogoProvider() {
    if (_logoUrl.isNotEmpty) {
      if (_logoUrl.startsWith('data:image')) {
        return MemoryImage(base64Decode(_logoUrl.split(',')[1].replaceAll(RegExp(r'\s+'), '')));
      }
      return NetworkImage(_logoUrl);
    }
    return const AssetImage('assets/images/logo.jpg');
  }

  Widget _buildMascoteImage(double size) {
    if (_mascoteUrl.isNotEmpty) {
      if (_mascoteUrl.startsWith('data:image')) {
        return Image.memory(
          base64Decode(_mascoteUrl.split(',')[1].replaceAll(RegExp(r'\s+'), '')),
          width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(Icons.sentiment_satisfied_alt, size: size, color: accentColor),
        );
      } else {
        return Image.network(
          _mascoteUrl,
          width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(Icons.sentiment_satisfied_alt, size: size, color: accentColor),
        );
      }
    }
    return Image.asset(
      'assets/images/mascote_acenando.gif',
      width: size, height: size, fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Icon(Icons.sentiment_satisfied_alt, size: size, color: accentColor),
    );
  }

  Future<void> _carregarDadosEmpresa() async {
    setState(() => _carregando = true);
    final dados = await _empresaService.obterEmpresa();

    if (dados != null && mounted) {
      setState(() {
        _nomeController.text = dados['nome_empresa'] ?? '';
        _sloganController.text = dados['slogan'] ?? '';
        _cnpjController.text = dados['cnpj'] ?? '';
        _whatsappController.text = dados['whatsapp'] ?? '';
        _emailController.text = dados['email'] ?? '';
        _chavePixController.text = dados['chave_pix'] ?? '';
        _valorMinimoController.text = (dados['valor_minimo_pedido'] ?? 10.00).toString();
        _corTemaController.text = dados['cor_tema'] ?? '#4A0E4E';
        _ruaController.text = dados['rua'] ?? '';
        _numeroController.text = dados['numero'] ?? '';
        _bairroController.text = dados['bairro'] ?? '';
        _cidadeController.text = dados['cidade'] ?? '';
        _ufController.text = dados['uf'] ?? '';
        _horarioController.text = dados['horario_funcionamento'] ?? '';
        _instagramController.text = dados['instagram'] ?? '';
        
        _logoUrl = dados['logo_url'] ?? '';
        _mascoteUrl = dados['mascote_url'] ?? '';
        _ifoodAtivo = dados['ifood_ativo'] ?? false;
        _promocoesAtivo = dados['promocoes_ativo'] ?? true;
        _cuponsAtivo = dados['cupons_ativo'] ?? true;
      });
    }

    if (mounted) {
      setState(() => _carregando = false);
    }
  }

  Future<void> _escolherImagem(bool isLogo) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      setState(() {
        if (isLogo) _isUploadingLogo = true;
        else _isUploadingMascote = true;
      });
      try {
        final bytes = await pickedFile.readAsBytes();
        final base64 = base64Encode(bytes);
        final urlHospedada = await ImgbbService.uploadImage(base64);
        
        if (urlHospedada != null) {
          setState(() {
            if (isLogo) _logoUrl = urlHospedada;
            else _mascoteUrl = urlHospedada;
          });
        } else {
          final ext = pickedFile.name.toLowerCase().endsWith('.gif') ? 'gif' : 'jpeg';
          final rawStr = 'data:image/$ext;base64,$base64';
          setState(() {
            if (isLogo) _logoUrl = rawStr;
            else _mascoteUrl = rawStr;
          });
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falha ao subir imagem.'), backgroundColor: Colors.red));
      } finally {
        setState(() {
          if (isLogo) _isUploadingLogo = false;
          else _isUploadingMascote = false;
        });
      }
    }
  }

  void _abrirSeletorDeCor() {
    final List<Color> cores = [
      const Color(0xFF4A0E4E), const Color(0xFFE040FB), Colors.purple, Colors.deepPurple,
      Colors.pink, Colors.red, Colors.orange, Colors.amber,
      Colors.green, Colors.teal, Colors.blue, Colors.indigo,
      Colors.blueGrey, Colors.brown, Colors.black, const Color(0xFF151515)
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: cardColor,
          title: Text('Escolha a Cor Tema', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          content: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: cores.map((cor) {
              return InkWell(
                onTap: () {
                  setState(() {
                    _corTemaController.text = '#${cor.value.toRadixString(16).substring(2).toUpperCase()}';
                  });
                  Navigator.pop(ctx);
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: cor, shape: BoxShape.circle, border: Border.all(color: Colors.white24, width: 2)),
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            )
          ],
        );
      }
    );
  }

  void _salvarConfiguracoes() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSalvando = true);

    final payload = {
      "id": 1,
      "nome_empresa": _nomeController.text.trim(),
      "slogan": _sloganController.text.trim(),
      "cnpj": _cnpjController.text.trim(),
      "whatsapp": _whatsappController.text.trim(),
      "email": _emailController.text.trim(),
      "chave_pix": _chavePixController.text.trim(),
      "valor_minimo_pedido": double.tryParse(_valorMinimoController.text.replaceAll(',', '.')) ?? 10.00,
      "cor_tema": _corTemaController.text.trim(),
      "rua": _ruaController.text.trim(),
      "numero": _numeroController.text.trim(),
      "bairro": _bairroController.text.trim(),
      "cidade": _cidadeController.text.trim(),
      "uf": _ufController.text.trim(),
      "horario_funcionamento": _horarioController.text.trim(),
      "instagram": _instagramController.text.trim(),
      "logo_url": _logoUrl,
      "mascote_url": _mascoteUrl,
      "ifood_ativo": _ifoodAtivo,
      "promocoes_ativo": _promocoesAtivo,
      "cupons_ativo": _cuponsAtivo,
    };

    bool sucesso = await _empresaService.salvarEmpresa(payload);

    if (!mounted) return;
    setState(() => _isSalvando = false);

    if (sucesso) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configurações salvas no banco com sucesso! 🍇', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao salvar dados. Verifique a conexão.', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _nomeController.dispose();
    _sloganController.dispose();
    _cnpjController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _chavePixController.dispose();
    _valorMinimoController.dispose();
    _corTemaController.dispose();
    _ruaController.dispose();
    _numeroController.dispose();
    _bairroController.dispose();
    _cidadeController.dispose();
    _ufController.dispose();
    _horarioController.dispose();
    _instagramController.dispose();
    super.dispose();
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
                    child: _buildMascoteImage(50),
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
            )
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
                    _buildMascoteImage(100),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E2C) : Colors.grey[100], borderRadius: BorderRadius.circular(16)),
                        child: Text(
                          "Olá! Sou o mascote da Açaiteria Shalom! 🍇\n\n"
                          "Esta é a tela de Configurações da Empresa. Aqui você coloca todos os dados e imagens que os clientes vão ver no seu cardápio online.\n\n"
                          "Quer que eu te mostre cada área?",
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
                            _keyGerais,
                            _keyImagens,
                            _keyRegras,
                            _keyEndereco,
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

  InputDecoration _inputDeco(String label, IconData icon, {String? prefix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: textSecColor),
      prefixText: prefix,
      prefixStyle: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      prefixIcon: Icon(icon, color: accentColor),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: accentColor, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildUploadArea(String label, String url, bool isUploading, bool isLogo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: textSecColor, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (url.isNotEmpty)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 120, height: 120,
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.white24 : Colors.grey[300]!)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: url.startsWith('data:image') 
                          ? Image.memory(base64Decode(url.split(',')[1].replaceAll(RegExp(r'\s+'), '')), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.broken_image, color: textSecColor, size: 40))
                          : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.broken_image, color: textSecColor, size: 40)),
                    ),
                  ),
                  Positioned(
                    top: -8, right: 8, 
                    child: GestureDetector(
                      onTap: () => setState(() {
                        if (isLogo) _logoUrl = '';
                        else _mascoteUrl = '';
                      }), 
                      child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 16))
                    )
                  ),
                ],
              ),
            if (url.isEmpty)
              isUploading
                  ? Container(width: 120, height: 120, decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: accentColor.withOpacity(0.3))), child: Center(child: CircularProgressIndicator(color: accentColor, strokeWidth: 2)))
                  : InkWell(
                      onTap: () => _escolherImagem(isLogo),
                      child: Container(
                        width: 120, height: 120, 
                        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: accentColor.withOpacity(0.3))), 
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, color: accentColor, size: 28), const SizedBox(height: 8), Text('Enviar Foto', style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.bold))])
                      ),
                    ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(
          child: CircularProgressIndicator(color: accentColor),
        ),
      );
    }

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
                    image: DecorationImage(image: _obterLogoProvider(), fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'DADOS DA EMPRESA', 
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
                    Icon(Icons.business, color: accentColor, size: 16),
                    const SizedBox(width: 8),
                    Text('CONFIGURAÇÕES', style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ],
                ),
              )
            ],
          ),
          body: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 24.0, bottom: 120.0),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Showcase.withWidget(
                            key: _keyGerais,
                            container: _buildTooltipMascote(showcaseContext, _textosMascote[0], false),
                            child: Card(
                              color: cardColor,
                              elevation: isDark ? 4 : 2,
                              shadowColor: Colors.black.withOpacity(0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: isDark ? Colors.white10 : Colors.transparent),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.store, color: accentColor, size: 28),
                                        const SizedBox(width: 12),
                                        Text('Dados Gerais da Empresa', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                                      ],
                                    ),
                                    Divider(height: 32, color: isDark ? Colors.white10 : Colors.grey[200]),
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: TextFormField(
                                            controller: _nomeController,
                                            style: TextStyle(color: textColor),
                                            decoration: _inputDeco('Nome da Empresa', Icons.business),
                                            validator: (v) => v == null || v.isEmpty ? 'Informe o nome' : null,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          flex: 2,
                                          child: TextFormField(
                                            controller: _sloganController,
                                            style: TextStyle(color: textColor),
                                            decoration: _inputDeco('Slogan / Descrição', Icons.subtitles),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: _cnpjController,
                                            style: TextStyle(color: textColor),
                                            decoration: _inputDeco('CNPJ / CPF', Icons.badge_outlined),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: TextFormField(
                                            controller: _whatsappController,
                                            style: TextStyle(color: textColor),
                                            decoration: _inputDeco('WhatsApp / Telefone', Icons.phone),
                                            validator: (v) => v == null || v.isEmpty ? 'Informe o contato' : null,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: TextFormField(
                                            controller: _emailController,
                                            style: TextStyle(color: textColor),
                                            decoration: _inputDeco('E-mail de Contato', Icons.email_outlined),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          Showcase.withWidget(
                            key: _keyImagens,
                            container: _buildTooltipMascote(showcaseContext, _textosMascote[1], false),
                            child: Card(
                              color: cardColor,
                              elevation: isDark ? 4 : 2,
                              shadowColor: Colors.black.withOpacity(0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: isDark ? Colors.white10 : Colors.transparent),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.photo_library, color: accentColor, size: 28),
                                        const SizedBox(width: 12),
                                        Text('Imagens e Identidade Visual', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                                      ],
                                    ),
                                    Divider(height: 32, color: isDark ? Colors.white10 : Colors.grey[200]),
                                    Row(
                                      children: [
                                        _buildUploadArea('Logo da Empresa', _logoUrl, _isUploadingLogo, true),
                                        const SizedBox(width: 32),
                                        _buildUploadArea('Mascote do Sistema', _mascoteUrl, _isUploadingMascote, false),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          Showcase.withWidget(
                            key: _keyRegras,
                            container: _buildTooltipMascote(showcaseContext, _textosMascote[2], false),
                            child: Card(
                              color: cardColor,
                              elevation: isDark ? 4 : 2,
                              shadowColor: Colors.black.withOpacity(0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: isDark ? Colors.white10 : Colors.transparent),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.tune, color: accentColor, size: 28),
                                        const SizedBox(width: 12),
                                        Text('Regras do Sistema & Configurações', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                                      ],
                                    ),
                                    Divider(height: 32, color: isDark ? Colors.white10 : Colors.grey[200]),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: _valorMinimoController,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                                            decoration: _inputDeco('Pedido Mínimo', Icons.attach_money, prefix: 'R\$ '),
                                            validator: (v) => v == null || v.isEmpty ? 'Informe o valor mínimo' : null,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: TextFormField(
                                            controller: _chavePixController,
                                            style: TextStyle(color: textColor),
                                            decoration: _inputDeco('Chave PIX Oficial', Icons.pix),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: InkWell(
                                            onTap: _abrirSeletorDeCor,
                                            child: IgnorePointer(
                                              child: TextFormField(
                                                controller: _corTemaController,
                                                style: TextStyle(color: textColor),
                                                decoration: InputDecoration(
                                                  labelText: 'Cor Primária (Hex)',
                                                  labelStyle: TextStyle(color: textSecColor),
                                                  hintText: '#4A0E4E',
                                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                                  enabledBorder: OutlineInputBorder(
                                                    borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  prefixIcon: Icon(Icons.color_lens_outlined, color: accentColor),
                                                  suffixIcon: Padding(
                                                    padding: const EdgeInsets.all(8.0),
                                                    child: Container(
                                                      decoration: BoxDecoration(color: _hexToColor(_corTemaController.text), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!)),
                                      child: Column(
                                        children: [
                                          SwitchListTile(
                                            title: Text('Botão do iFood no Catálogo', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                                            subtitle: Text('Ativa ou desativa o ícone de atalho para o iFood', style: TextStyle(fontSize: 12, color: textSecColor)),
                                            value: _ifoodAtivo,
                                            activeColor: Colors.redAccent,
                                            secondary: const Icon(Icons.delivery_dining, color: Colors.redAccent),
                                            onChanged: (val) => setState(() => _ifoodAtivo = val),
                                          ),
                                          Divider(color: isDark ? Colors.white10 : Colors.grey[300]),
                                          SwitchListTile(
                                            title: Text('Sistema de Banners/Promoções', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                                            subtitle: Text('Permite mostrar os pop-ups e banners de ofertas aos clientes', style: TextStyle(fontSize: 12, color: textSecColor)),
                                            value: _promocoesAtivo,
                                            activeColor: Colors.orange,
                                            secondary: const Icon(Icons.campaign, color: Colors.orange),
                                            onChanged: (val) => setState(() => _promocoesAtivo = val),
                                          ),
                                          Divider(color: isDark ? Colors.white10 : Colors.grey[300]),
                                          SwitchListTile(
                                            title: Text('Aceitar Cupons de Desconto', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                                            subtitle: Text('Mostra o campo para inserir cupons no carrinho', style: TextStyle(fontSize: 12, color: textSecColor)),
                                            value: _cuponsAtivo,
                                            activeColor: Colors.green,
                                            secondary: const Icon(Icons.local_activity, color: Colors.green),
                                            onChanged: (val) => setState(() => _cuponsAtivo = val),
                                          ),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          Showcase.withWidget(
                            key: _keyEndereco,
                            container: _buildTooltipMascote(showcaseContext, _textosMascote[3], true),
                            child: Card(
                              color: cardColor,
                              elevation: isDark ? 4 : 2,
                              shadowColor: Colors.black.withOpacity(0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: isDark ? Colors.white10 : Colors.transparent),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.location_on, color: accentColor, size: 28),
                                        const SizedBox(width: 12),
                                        Text('Endereço e Funcionamento', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                                      ],
                                    ),
                                    Divider(height: 32, color: isDark ? Colors.white10 : Colors.grey[200]),
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: TextFormField(
                                            controller: _ruaController,
                                            style: TextStyle(color: textColor),
                                            decoration: _inputDeco('Rua / Logradouro', Icons.map_outlined),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: TextFormField(
                                            controller: _numeroController,
                                            style: TextStyle(color: textColor),
                                            decoration: _inputDeco('Número', Icons.tag),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: _bairroController,
                                            style: TextStyle(color: textColor),
                                            decoration: _inputDeco('Bairro', Icons.holiday_village_outlined),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: TextFormField(
                                            controller: _cidadeController,
                                            style: TextStyle(color: textColor),
                                            decoration: _inputDeco('Cidade', Icons.location_city_outlined),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        SizedBox(
                                          width: 100,
                                          child: TextFormField(
                                            controller: _ufController,
                                            style: TextStyle(color: textColor),
                                            decoration: _inputDeco('UF', Icons.map),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: _horarioController,
                                            style: TextStyle(color: textColor),
                                            decoration: _inputDeco('Horário de Funcionamento', Icons.access_time),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: TextFormField(
                                            controller: _instagramController,
                                            style: TextStyle(color: textColor),
                                            decoration: _inputDeco('Instagram', Icons.camera_alt_outlined),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),

                          SizedBox(
                            height: 55,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 4,
                              ),
                              onPressed: _isSalvando ? null : _salvarConfiguracoes,
                              child: _isSalvando
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.save),
                                        SizedBox(width: 8),
                                        Text('SALVAR CONFIGURAÇÕES DA EMPRESA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 24,
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
                      child: _buildMascoteImage(70),
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