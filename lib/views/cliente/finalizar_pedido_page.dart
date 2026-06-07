import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acaiteria_front/features/auth/services/pedido_service.dart';

class FinalizarPedidoPage extends StatefulWidget {
  final Map<String, dynamic> catalogo;
  final Map<int, double> carrinho;
  final Map<int, String> observacoes;
  final double valorTotal;

  const FinalizarPedidoPage({
    super.key,
    required this.catalogo,
    required this.carrinho,
    required this.observacoes,
    required this.valorTotal,
  });

  @override
  State<FinalizarPedidoPage> createState() => _FinalizarPedidoPageState();
}

class _FinalizarPedidoPageState extends State<FinalizarPedidoPage> {
  final _formKey = GlobalKey<FormState>();
  final _pedidoService = PedidoService();
  
  final _nomeController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _cepController = TextEditingController();
  final _ruaController = TextEditingController();
  final _numeroController = TextEditingController();
  final _bairroController = TextEditingController();
  final _referenciaController = TextEditingController();
  final _trocoController = TextEditingController();

  String _tipoEntrega = 'Entrega'; 
  String _formaPagamento = 'Pix'; 
  bool _precisaTroco = false;
  bool _isSaving = false;
  bool _isCarregandoLocalizacao = false;
  bool _isCarregandoCep = false;

  @override
  void initState() {
    super.initState();
    _recuperarDadosCache();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _telefoneController.dispose();
    _cepController.dispose();
    _ruaController.dispose();
    _numeroController.dispose();
    _bairroController.dispose();
    _referenciaController.dispose();
    _trocoController.dispose();
    super.dispose();
  }

  Future<void> _recuperarDadosCache() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nomeController.text = prefs.getString('cache_nome') ?? '';
      _telefoneController.text = prefs.getString('cache_telefone') ?? '';
      _cepController.text = prefs.getString('cache_cep') ?? '';
      _ruaController.text = prefs.getString('cache_rua') ?? '';
      _numeroController.text = prefs.getString('cache_numero') ?? '';
      _bairroController.text = prefs.getString('cache_bairro') ?? '';
      _referenciaController.text = prefs.getString('cache_referencia') ?? '';
      _tipoEntrega = prefs.getString('cache_tipo_entrega') ?? 'Entrega';
      _formaPagamento = prefs.getString('cache_forma_pagamento') ?? 'Pix';
    });
  }

  Future<void> _salvarDadosCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cache_nome', _nomeController.text.trim());
    await prefs.setString('cache_telefone', _telefoneController.text.trim());
    await prefs.setString('cache_cep', _cepController.text.trim());
    await prefs.setString('cache_rua', _ruaController.text.trim());
    await prefs.setString('cache_numero', _numeroController.text.trim());
    await prefs.setString('cache_bairro', _bairroController.text.trim());
    await prefs.setString('cache_referencia', _referenciaController.text.trim());
    await prefs.setString('cache_tipo_entrega', _tipoEntrega);
    await prefs.setString('cache_forma_pagamento', _formaPagamento);
  }

  Future<void> _buscarCep(String cep) async {
    String cepLimpo = cep.replaceAll(RegExp(r'\D'), '');
    if (cepLimpo.length != 8) {
      _mostrarAviso('Digite um CEP válido com 8 dígitos.');
      return;
    }

    setState(() => _isCarregandoCep = true);

    try {
      final url = Uri.parse('https://viacep.com.br/ws/$cepLimpo/json/');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final dados = jsonDecode(response.body);
        if (dados['erro'] == true) {
          _mostrarAviso('CEP não encontrado.');
          return;
        }

        setState(() {
          _ruaController.text = dados['logradouro'] ?? '';
          _bairroController.text = dados['bairro'] ?? '';
        });
        await _salvarDadosCache();
      }
    } catch (_) {
      _mostrarAviso('Erro ao buscar o CEP. Digite o endereço manualmente.');
    } finally {
      setState(() => _isCarregandoCep = false);
    }
  }

  Future<void> _obterLocalizacaoAtual() async {
    if (html.window.navigator.geolocation == null) {
      _mostrarAviso('Geolocalização não é suportada pelo seu navegador.');
      return;
    }

    setState(() => _isCarregandoLocalizacao = true);

    try {
      final position = await html.window.navigator.geolocation.getCurrentPosition();
      final coords = position.coords;
      if (coords != null && coords.latitude != null && coords.longitude != null) {
        await _buscarEnderecoPorCoordenadas(coords.latitude as double, coords.longitude as double);
      } else {
        setState(() => _isCarregandoLocalizacao = false);
        _mostrarAviso('Não foi possível obter as coordenadas.');
      }
    } catch (_) {
      setState(() => _isCarregandoLocalizacao = false);
      _mostrarAviso('Permissão de localização negada ou indisponível.');
    }
  }

  Future<void> _buscarEnderecoPorCoordenadas(double lat, double lng) async {
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1');
      final response = await http.get(url, headers: {'User-Agent': 'AcaiteriaShalomApp'});

      if (response.statusCode == 200) {
        final dados = jsonDecode(response.body);
        final address = dados['address'];

        if (address != null) {
          setState(() {
            _ruaController.text = address['road'] ?? address['pedestrian'] ?? '';
            _bairroController.text = address['suburb'] ?? address['neighbourhood'] ?? address['village'] ?? '';
            _numeroController.text = address['house_number'] ?? '';
            String cepBruto = address['postcode'] ?? '';
            _cepController.text = cepBruto.replaceAll(RegExp(r'\D'), '');
          });
          await _salvarDadosCache();
        }
      }
    } catch (e) {
      print(e);
    } finally {
      setState(() => _isCarregandoLocalizacao = false);
    }
  }

  void _abrirSiteCorreios() {
    html.window.open('https://buscacepinter.correios.com.br/app/endereco/index.php', '_blank');
  }

  void _mostrarAviso(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: Colors.orange),
    );
  }

  Color _hexToColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF4A0E4E);
    }
  }

  Future<void> _processarPedido(Color corTema) async {
    if (!_formKey.currentState!.validate()) return;
    
    await _salvarDadosCache();
    setState(() => _isSaving = true);

    List<Map<String, dynamic>> itensDb = [];
    final produtos = widget.catalogo['produtos'] as List;

    for (var p in produtos) {
      int id = p['id'];
      if (widget.carrinho.containsKey(id)) {
        double qtd = widget.carrinho[id]!;
        String obs = widget.observacoes[id] ?? '';
        double preco = double.tryParse(p['price'].toString()) ?? 0.0;
        String un = (p['unidade_medida'] ?? '').toString().toLowerCase();
        
        double subtotalItem = (un == 'kg' || un == 'grama' || un == 'g') ? (preco / 1000.0) * qtd : preco * qtd;

        itensDb.add({
          'produto_id': id,
          'quantidade': qtd,
          'subtotal': subtotalItem,
          'unidade': un,
          'nome': p['name'] + (obs.isNotEmpty ? ' (Obs: $obs)' : ''),
        });
      }
    }

    final dadosPedido = {
      'cliente_nome': _nomeController.text.trim(),
      'cliente_telefone': _telefoneController.text.trim(),
      'tipo_entrega': _tipoEntrega,
      'endereco_rua': _tipoEntrega == 'Entrega' ? _ruaController.text.trim() : '',
      'endereco_numero': _tipoEntrega == 'Entrega' ? _numeroController.text.trim() : '',
      'endereco_bairro': _tipoEntrega == 'Entrega' ? _bairroController.text.trim() : '',
      'endereco_referencia': _tipoEntrega == 'Entrega' ? _referenciaController.text.trim() : '',
      'forma_pagamento': _formaPagamento,
      'troco_para': double.tryParse(_trocoController.text.replaceAll(',', '.')) ?? 0.0,
      'valor_total': widget.valorTotal,
      'itens': itensDb,
    };

    final resultado = await _pedidoService.salvarPedido(dadosPedido);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (resultado['success'] == true) {
      int idPedidoBanco = resultado['pedido_id'] ?? 0;
      
      StringBuffer mensagem = StringBuffer();
      mensagem.writeln('🍇 *NOVO PEDIDO - AÇAITERIA SHALOM* 🍇');
      mensagem.writeln('\n📋 *Pedido Nº:* #$idPedidoBanco');
      mensagem.writeln('\n👤 *Cliente:* ${_nomeController.text.trim()}');
      mensagem.writeln('📞 *Telefone:* ${_telefoneController.text.trim()}');
      mensagem.writeln('\n🛵 *Forma de Entrega:* $_tipoEntrega');
      
      if (_tipoEntrega == 'Entrega') {
        if (_cepController.text.isNotEmpty) {
          mensagem.writeln('📮 *CEP:* ${_cepController.text.trim()}');
        }
        mensagem.writeln('📍 *Endereço:* Rua ${_ruaController.text.trim()}, Nº ${_numeroController.text.trim()}');
        mensagem.writeln('🏘️ *Bairro:* ${_bairroController.text.trim()}');
        if (_referenciaController.text.isNotEmpty) {
          mensagem.writeln('📌 *Referência:* ${_referenciaController.text.trim()}');
        }
      }

      mensagem.writeln('\n🛒 *ITENS DO PEDIDO:*');
      for (var p in produtos) {
        int id = p['id'];
        if (widget.carrinho.containsKey(id)) {
          String un = (p['unidade_medida'] ?? '').toString().toLowerCase();
          double qtd = widget.carrinho[id]!;
          String obs = widget.observacoes[id] ?? '';

          if (un == 'kg' || un == 'grama' || un == 'g') {
            mensagem.writeln('• ${p['name']} (${qtd.toInt()}g)');
          } else {
            mensagem.writeln('• ${qtd.toInt()}x ${p['name']}');
          }
          if (obs.isNotEmpty) {
            mensagem.writeln('   📝 Obs: $obs');
          }
        }
      }

      mensagem.writeln('\n💳 *Forma de Pagamento:* $_formaPagamento');
      if (_formaPagamento == 'Dinheiro' && _precisaTroco) {
        mensagem.writeln('💵 *Troco para:* R\$ ${_trocoController.text.trim()}');
      }
      mensagem.writeln('\n💰 *TOTAL DO PEDIDO:* R\$ ${widget.valorTotal.toStringAsFixed(2).replaceAll('.', ',')}');

      String textoFormatado = Uri.encodeComponent(mensagem.toString());
      String numeroDestino = _telefoneController.text.trim().replaceAll(RegExp(r'[^\d]'), '');
      
      if (!numeroDestino.startsWith('55') && numeroDestino.isNotEmpty) {
        numeroDestino = '55$numeroDestino';
      }

      String urlSmart = 'https://wa.me/$numeroDestino?text=$textoFormatado';
      html.window.open(urlSmart, '_blank');

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pedido enviado com sucesso!'), backgroundColor: Colors.green));
      Navigator.pop(context, true);

    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao processar pedido. Tente novamente.'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 800;
    final corTema = _hexToColor(widget.catalogo['cor_theme'] ?? widget.catalogo['cor_tema'] ?? '#4A0E4E');
    final corLetras = _hexToColor(widget.catalogo['cor_letras'] ?? '#FFFFFF');
    final produtos = widget.catalogo['produtos'] as List;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: corTema,
        foregroundColor: corLetras,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: isMobile ? 36 : 40, 
              height: isMobile ? 36 : 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
                image: const DecorationImage(image: AssetImage('assets/images/logo.jpg'), fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Text('FECHAR PEDIDO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: isMobile ? 16 : 20, letterSpacing: 1)),
          ],
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1100),
          padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                if (!isMobile)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: _buildFormularioDados(corTema, isMobile)),
                      const SizedBox(width: 32),
                      Expanded(flex: 5, child: _buildResumoCarrinho(produtos, corTema, isMobile)),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildResumoCarrinho(produtos, corTema, isMobile),
                      const SizedBox(height: 16),
                      _buildFormularioDados(corTema, isMobile),
                    ],
                  ),
                SizedBox(height: isMobile ? 24 : 40),
                SizedBox(
                  height: isMobile ? 50 : 60,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      elevation: 4,
                    ),
                    onPressed: _isSaving ? null : () => _processarPedido(corTema),
                    icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Icon(Icons.send, size: isMobile ? 20 : 28),
                    label: Text(_isSaving ? 'PROCESSANDO...' : 'ENVIAR PEDIDO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: isMobile ? 14 : 18, letterSpacing: 1)),
                  ),
                ),
                if (isMobile) const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormularioDados(Color corTema, bool isMobile) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Seus Dados', style: TextStyle(fontSize: isMobile ? 18 : 20, fontWeight: FontWeight.w900, color: corTema)),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nomeController,
              onChanged: (_) => _salvarDadosCache(),
              decoration: InputDecoration(labelText: 'Seu Nome completo', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
              validator: (v) => v!.isEmpty ? 'Por favor, digite seu nome' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _telefoneController,
              onChanged: (_) => _salvarDadosCache(),
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: 'Telefone / WhatsApp', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
              validator: (v) => v!.isEmpty ? 'Por favor, digite seu telefone' : null,
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 16.0), child: Divider()),
            
            Text('Como quer receber?', style: TextStyle(fontSize: isMobile ? 18 : 20, fontWeight: FontWeight.w900, color: corTema)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Center(child: Text('🛵 Entrega', style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 13 : 14))),
                    selected: _tipoEntrega == 'Entrega',
                    selectedColor: corTema.withOpacity(0.2),
                    onSelected: (val) {
                      setState(() => _tipoEntrega = 'Entrega');
                      _salvarDadosCache();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: Center(child: Text('🏪 Retirar na Loja', style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 13 : 14))),
                    selected: _tipoEntrega == 'Retirada',
                    selectedColor: corTema.withOpacity(0.2),
                    onSelected: (val) {
                      setState(() => _tipoEntrega = 'Retirada');
                      _salvarDadosCache();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            if (_tipoEntrega == 'Entrega') ...[
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  side: BorderSide(color: corTema),
                  foregroundColor: corTema,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _isCarregandoLocalizacao ? null : _obterLocalizacaoAtual,
                icon: _isCarregandoLocalizacao
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: corTema))
                    : const Icon(Icons.my_location),
                label: Text(_isCarregandoLocalizacao ? 'Buscando Localização...' : 'Usar Minha Localização Atual', style: TextStyle(fontSize: isMobile ? 13 : 14)),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cepController,
                      onChanged: (_) => _salvarDadosCache(),
                      keyboardType: TextInputType.number,
                      validator: (v) => _tipoEntrega == 'Entrega' && v!.isEmpty ? 'Por favor, informe o CEP' : null,
                      decoration: InputDecoration(
                        labelText: 'CEP',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        suffixIcon: _isCarregandoCep
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : IconButton(
                                icon: const Icon(Icons.search),
                                onPressed: () => _buscarCep(_cepController.text),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _abrirSiteCorreios,
                child: const Text(
                  'Não sei meu CEP',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: TextFormField(
                      controller: _ruaController,
                      onChanged: (_) => _salvarDadosCache(),
                      decoration: InputDecoration(labelText: 'Rua / Av.', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                      validator: (v) => _tipoEntrega == 'Entrega' && v!.isEmpty ? 'Obrigatório' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _numeroController,
                      onChanged: (_) => _salvarDadosCache(),
                      decoration: InputDecoration(labelText: 'Nº', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                      validator: (v) => _tipoEntrega == 'Entrega' && v!.isEmpty ? 'Obrigatório' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bairroController,
                onChanged: (_) => _salvarDadosCache(),
                decoration: InputDecoration(labelText: 'Bairro', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                validator: (v) => _tipoEntrega == 'Entrega' && v!.isEmpty ? 'Por favor, informe o bairro' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _referenciaController,
                onChanged: (_) => _salvarDadosCache(),
                decoration: InputDecoration(labelText: 'Ponto de referência (Opcional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
              ),
            ],
            const Padding(padding: EdgeInsets.symmetric(vertical: 16.0), child: Divider()),
            
            Text('Forma de Pagamento', style: TextStyle(fontSize: isMobile ? 18 : 20, fontWeight: FontWeight.w900, color: corTema)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _formaPagamento,
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
              items: ['Pix', 'Cartão de Crédito/Débito', 'Dinheiro']
                  .map((f) => DropdownMenuItem(value: f, child: Text(f, style: TextStyle(fontSize: isMobile ? 14 : 16))))
                  .toList(),
              onChanged: (v) {
                setState(() => _formaPagamento = v!);
                _salvarDadosCache();
              },
            ),
            if (_formaPagamento == 'Dinheiro') ...[
              const SizedBox(height: 16),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Precisa de troco?', style: TextStyle(fontWeight: FontWeight.bold)),
                value: _precisaTroco,
                activeColor: corTema,
                onChanged: (v) => setState(() => _precisaTroco = v!),
              ),
              if (_precisaTroco)
                TextFormField(
                  controller: _trocoController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Troco para quanto?', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                  validator: (v) => _formaPagamento == 'Dinheiro' && _precisaTroco && v!.isEmpty ? 'Informe o valor' : null,
                ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildResumoCarrinho(List<dynamic> produtos, Color corTema, bool isMobile) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resumo do Pedido', style: TextStyle(fontSize: isMobile ? 18 : 20, fontWeight: FontWeight.w900, color: corTema)),
            const SizedBox(height: 20),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: produtos.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final p = produtos[index];
                int id = p['id'];
                
                if (!widget.carrinho.containsKey(id)) return const SizedBox.shrink();

                double qtdOuPeso = widget.carrinho[id]!;
                String obs = widget.observacoes[id] ?? '';
                double preco = double.tryParse(p['price'].toString()) ?? 0.0;
                String un = (p['unidade_medida'] ?? '').toString().toLowerCase();
                bool isPeso = un == 'kg' || un == 'grama' || un == 'g';

                double subtotalItem = isPeso ? (preco / 1000.0) * qtdOuPeso : preco * qtdOuPeso;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(
                              isPeso ? '${qtdOuPeso.toInt()}g' : '${qtdOuPeso.toInt()} unidade(s)',
                              style: const TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                            if (obs.isNotEmpty)
                              Text('📝 Obs: $obs', style: TextStyle(color: Colors.purple[700], fontSize: 12, fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('R\$ ${subtotalItem.toStringAsFixed(2).replaceAll('.', ',')}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                );
              },
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 16.0), child: Divider()),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: isMobile ? 16 : 20)),
                Text('R\$ ${widget.valorTotal.toStringAsFixed(2).replaceAll('.', ',')}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: isMobile ? 22 : 24, color: corTema)),
              ],
            )
          ],
        ),
      ),
    );
  }
}