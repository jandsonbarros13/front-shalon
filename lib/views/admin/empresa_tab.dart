import 'package:flutter/material.dart';
import 'package:acaiteria_front/features/auth/services/empresa_service.dart';
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

  bool _carregando = true;
  bool _isSalvando = false;
  bool _isDarkMode = true;

  final FlutterTts _flutterTts = FlutterTts();
  final GlobalKey _keyGerais = GlobalKey();
  final GlobalKey _keyRegras = GlobalKey();
  final GlobalKey _keyEndereco = GlobalKey();

  final List<String> _textosMascote = [
    "Neste primeiro quadro, você preenche as informações básicas da sua loja, como Nome, CNPJ e os meios de contato para os clientes.",
    "Aqui é a parte de personalização e regras! Defina o valor mínimo para pedidos, sua chave PIX e a cor que vai estampar seu sistema.",
    "Por fim, coloque seu endereço completo e os horários de funcionamento. Ah, não esqueça de clicar no botão salvar no final da tela!"
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
    _carregarDadosEmpresa();
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
      });
    }

    if (mounted) {
      setState(() => _carregando = false);
    }
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
                          "Esta é a tela de Configurações da Empresa. Aqui você coloca todos os dados que os clientes vão ver no seu cardápio online.\n\n"
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
                    image: const DecorationImage(image: AssetImage('assets/images/logo.jpg'), fit: BoxFit.cover),
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
                            key: _keyRegras,
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
                                        Icon(Icons.tune, color: accentColor, size: 28),
                                        const SizedBox(width: 12),
                                        Text('Regras do Sistema & Personalização', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
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
                                          child: TextFormField(
                                            controller: _corTemaController,
                                            style: TextStyle(color: textColor),
                                            decoration: InputDecoration(
                                              labelText: 'Cor Primária (Hex)',
                                              labelStyle: TextStyle(color: textSecColor),
                                              hintText: '#4A0E4E',
                                              hintStyle: TextStyle(color: textSecColor.withOpacity(0.5)),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                              enabledBorder: OutlineInputBorder(
                                                borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderSide: BorderSide(color: accentColor, width: 2),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              prefixIcon: Icon(Icons.color_lens_outlined, color: accentColor),
                                            ),
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
                            key: _keyEndereco,
                            container: _buildTooltipMascote(showcaseContext, _textosMascote[2], true),
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