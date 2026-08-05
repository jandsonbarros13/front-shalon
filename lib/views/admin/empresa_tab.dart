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

  final FlutterTts _flutterTts = FlutterTts();
  final GlobalKey _keyGerais = GlobalKey();
  final GlobalKey _keyRegras = GlobalKey();
  final GlobalKey _keyEndereco = GlobalKey();

  final List<String> _textosMascote = [
    "Neste primeiro quadro, você preenche as informações básicas da sua loja, como Nome, CNPJ e os meios de contato para os clientes.",
    "Aqui é a parte de personalização e regras! Defina o valor mínimo para pedidos, sua chave PIX e a cor que vai estampar seu sistema.",
    "Por fim, coloque seu endereço completo e os horários de funcionamento. Ah, não esqueça de clicar no botão salvar no final da tela!"
  ];

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
          backgroundColor: Colors.red,
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
                          "Esta é a tela de Configurações da Empresa. Aqui você coloca todos os dados que os clientes vão ver no seu cardápio online.\n\n"
                          "Quer que eu te mostre cada área?",
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
                            _keyGerais,
                            _keyRegras,
                            _keyEndereco,
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
    const corTema = Color(0xFF4A0E4E);

    if (_carregando) {
      return const Center(
        child: CircularProgressIndicator(color: corTema),
      );
    }

    return ShowCaseWidget(
      onStart: (index, key) => _playAudioForStep(index),
      onComplete: (index, key) => _flutterTts.stop(),
      onFinish: () => _flutterTts.stop(),
      builder: (showcaseContext) {
        return Scaffold(
          backgroundColor: Colors.grey[100],
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
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.store, color: corTema, size: 28),
                                        SizedBox(width: 12),
                                        Text('Dados Gerais da Empresa', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: corTema)),
                                      ],
                                    ),
                                    const Divider(height: 32),
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: TextFormField(
                                            controller: _nomeController,
                                            decoration: const InputDecoration(labelText: 'Nome da Empresa', border: OutlineInputBorder(), prefixIcon: Icon(Icons.business)),
                                            validator: (v) => v == null || v.isEmpty ? 'Informe o nome' : null,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          flex: 2,
                                          child: TextFormField(
                                            controller: _sloganController,
                                            decoration: const InputDecoration(labelText: 'Slogan / Descrição', border: OutlineInputBorder(), prefixIcon: Icon(Icons.subtitles)),
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
                                            decoration: const InputDecoration(labelText: 'CNPJ / CPF', border: OutlineInputBorder(), prefixIcon: Icon(Icons.badge_outlined)),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: TextFormField(
                                            controller: _whatsappController,
                                            decoration: const InputDecoration(labelText: 'WhatsApp / Telefone', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
                                            validator: (v) => v == null || v.isEmpty ? 'Informe o contato' : null,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: TextFormField(
                                            controller: _emailController,
                                            decoration: const InputDecoration(labelText: 'E-mail de Contato', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email_outlined)),
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
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.tune, color: corTema, size: 28),
                                        SizedBox(width: 12),
                                        Text('Regras do Sistema & Personalização', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: corTema)),
                                      ],
                                    ),
                                    const Divider(height: 32),
                                    Row(
                                      children: [
                                          Expanded(
                                          child: TextFormField(
                                              controller: _valorMinimoController,
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              decoration: const InputDecoration(
                                              labelText: 'Pedido Mínimo (R\$)',
                                              prefixText: 'R\$ ',           
                                              border: OutlineInputBorder(),
                                              prefixIcon: Icon(Icons.attach_money),
                                              ),
                                              validator: (v) => v == null || v.isEmpty ? 'Informe o valor mínimo' : null,
                                          ),
                                          ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: TextFormField(
                                            controller: _chavePixController,
                                            decoration: const InputDecoration(labelText: 'Chave PIX Oficial', border: OutlineInputBorder(), prefixIcon: Icon(Icons.pix)),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: TextFormField(
                                            controller: _corTemaController,
                                            decoration: const InputDecoration(
                                              labelText: 'Cor Primária (Hex)',
                                              hintText: '#4A0E4E',
                                              border: OutlineInputBorder(),
                                              prefixIcon: Icon(Icons.color_lens_outlined),
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
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.location_on, color: corTema, size: 28),
                                        SizedBox(width: 12),
                                        Text('Endereço e Funcionamento', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: corTema)),
                                      ],
                                    ),
                                    const Divider(height: 32),
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: TextFormField(
                                            controller: _ruaController,
                                            decoration: const InputDecoration(labelText: 'Rua / Logradouro', border: OutlineInputBorder()),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: TextFormField(
                                            controller: _numeroController,
                                            decoration: const InputDecoration(labelText: 'Número', border: OutlineInputBorder()),
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
                                            decoration: const InputDecoration(labelText: 'Bairro', border: OutlineInputBorder()),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: TextFormField(
                                            controller: _cidadeController,
                                            decoration: const InputDecoration(labelText: 'Cidade', border: OutlineInputBorder()),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        SizedBox(
                                          width: 90,
                                          child: TextFormField(
                                            controller: _ufController,
                                            decoration: const InputDecoration(labelText: 'UF', border: OutlineInputBorder()),
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
                                            decoration: const InputDecoration(labelText: 'Horário de Funcionamento', border: OutlineInputBorder(), prefixIcon: Icon(Icons.access_time)),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: TextFormField(
                                            controller: _instagramController,
                                            decoration: const InputDecoration(labelText: 'Instagram', border: OutlineInputBorder(), prefixIcon: Icon(Icons.camera_alt_outlined)),
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
                                backgroundColor: corTema,
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
        );
      }
    );
  }
}