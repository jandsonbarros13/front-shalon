import 'package:flutter/material.dart';
import 'package:acaiteria_front/features/auth/services/empresa_service.dart';

class EmpresaTab extends StatefulWidget {
  const EmpresaTab({super.key});

  @override
  State<EmpresaTab> createState() => _EmpresaTabState();
}

class _EmpresaTabState extends State<EmpresaTab> {
  final _formKey = GlobalKey<FormState>();
  final _empresaService = EmpresaService();

  // Controllers
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

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    const corTema = Color(0xFF4A0E4E);

    if (_carregando) {
      return const Center(
        child: CircularProgressIndicator(color: corTema),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // DADOS GERAIS
                  Card(
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

                  const SizedBox(height: 24),

                  // REGRAS E APARÊNCIA
                  Card(
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

                  const SizedBox(height: 24),

                  // ENDEREÇO
                  Card(
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
    );
  }
}