import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acaiteria_front/features/auth/services/pedido_service.dart';
import 'package:acaiteria_front/features/auth/services/frete_service.dart';

class FinalizarPedidoPage extends StatefulWidget {
  final Map<String, dynamic> catalogo;
  final Map<int, double> carrinho;
  final Map<int, String> observacoes;
  final Map<int, List<int>> adicionaisEscolhidos;
  final double valorTotal;

  const FinalizarPedidoPage({
    super.key,
    required this.catalogo,
    required this.carrinho,
    required this.observacoes,
    required this.adicionaisEscolhidos,
    required this.valorTotal,
  });

  @override
  State<FinalizarPedidoPage> createState() => _FinalizarPedidoPageState();
}

class _FinalizarPedidoPageState extends State<FinalizarPedidoPage> {
  final _formKey = GlobalKey<FormState>();
  final _pedidoService = PedidoService();
  final _freteService = FreteService();
  
  final _nomeController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _cepController = TextEditingController();
  final _ruaController = TextEditingController();
  final _numeroController = TextEditingController();
  final _referenciaController = TextEditingController();
  final _trocoController = TextEditingController();

  List<dynamic> _bairrosAtivos = [];
  String? _bairroSelecionado;
  double _taxaEntrega = 0.0;

  String _tipoEntrega = 'Entrega'; 
  String _formaPagamento = 'Pix'; 
  bool _precisaTroco = false;
  bool _isSaving = false;
  bool _isCarregandoLocalizacao = false;
  bool _isCarregandoCep = false;
  bool _isCarregandoFretes = true;

  @override
  void initState() {
    super.initState();
    _carregarBairrosEFretes().then((_) => _recuperarDadosCache());
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _telefoneController.dispose();
    _cepController.dispose();
    _ruaController.dispose();
    _numeroController.dispose();
    _referenciaController.dispose();
    _trocoController.dispose();
    super.dispose();
  }

  double get _valorTotalComFrete {
    return widget.valorTotal + (_tipoEntrega == 'Entrega' ? _taxaEntrega : 0.0);
  }

  Future<void> _carregarBairrosEFretes() async {
    final dados = await _freteService.listarFretesDoBanco();
    if (mounted) {
      setState(() {
        _bairrosAtivos = dados.where((b) => b['ativo'] == true).toList();
        _isCarregandoFretes = false;
      });
    }
  }

  Future<void> _recuperarDadosCache() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nomeController.text = prefs.getString('cache_nome') ?? '';
      _telefoneController.text = prefs.getString('cache_telefone') ?? '';
      _cepController.text = prefs.getString('cache_cep') ?? '';
      _ruaController.text = prefs.getString('cache_rua') ?? '';
      _numeroController.text = prefs.getString('cache_numero') ?? '';
      _referenciaController.text = prefs.getString('cache_referencia') ?? '';
      _tipoEntrega = prefs.getString('cache_tipo_entrega') ?? 'Entrega';
      _formaPagamento = prefs.getString('cache_forma_pagamento') ?? 'Pix';
      
      String bairroCache = prefs.getString('cache_bairro') ?? '';
      if (bairroCache.isNotEmpty) {
        _tentarMatchDeBairro(bairroCache);
      }
    });
  }

  Future<void> _salvarDadosCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cache_nome', _nomeController.text.trim());
    await prefs.setString('cache_telefone', _telefoneController.text.trim());
    await prefs.setString('cache_cep', _cepController.text.trim());
    await prefs.setString('cache_rua', _ruaController.text.trim());
    await prefs.setString('cache_numero', _numeroController.text.trim());
    await prefs.setString('cache_bairro', _bairroSelecionado ?? '');
    await prefs.setString('cache_referencia', _referenciaController.text.trim());
    await prefs.setString('cache_tipo_entrega', _tipoEntrega);
    await prefs.setString('cache_forma_pagamento', _formaPagamento);
  }

  void _tentarMatchDeBairro(String nomeBairroEncontrado) {
    String limpo = nomeBairroEncontrado.trim().toLowerCase();
    final match = _bairrosAtivos.firstWhere(
      (b) => b['bairro'].toString().toLowerCase().contains(limpo) || limpo.contains(b['bairro'].toString().toLowerCase()),
      orElse: () => null,
    );

    if (match != null) {
      setState(() {
        _bairroSelecionado = match['bairro'];
        _taxaEntrega = double.tryParse(match['taxa'].toString()) ?? 0.0;
      });
    }
  }

  Future<void> _buscarCep(String cep) async {
    String cepLimpo = cep.replaceAll(RegExp(r'\D'), '');
    if (cepLimpo.length != 8) {
      return;
    }
    setState(() => _isCarregandoCep = true);
    try {
      final url = Uri.parse('https://viacep.com.br/ws/$cepLimpo/json/');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final dados = jsonDecode(response.body);
        if (dados['erro'] == true) return;
        setState(() {
          _ruaController.text = dados['logradouro'] ?? '';
        });
        if (dados['bairro'] != null) {
          _tentarMatchDeBairro(dados['bairro']);
        }
        await _salvarDadosCache();
      }
    } catch (_) {
    } finally {
      setState(() => _isCarregandoCep = false);
    }
  }

  Future<void> _obterLocalizacaoAtual() async {
    if (html.window.navigator.geolocation == null) return;
    setState(() => _isCarregandoLocalizacao = true);
    try {
      final position = await html.window.navigator.geolocation.getCurrentPosition();
      final coords = position.coords;
      if (coords != null && coords.latitude != null && coords.longitude != null) {
        await _buscarEnderecoPorCoordenadas(coords.latitude as double, coords.longitude as double);
      } else {
        setState(() => _isCarregandoLocalizacao = false);
      }
    } catch (_) {
      setState(() => _isCarregandoLocalizacao = false);
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
            _numeroController.text = address['house_number'] ?? '';
            String cepBruto = address['postcode'] ?? '';
            _cepController.text = cepBruto.replaceAll(RegExp(r'\D'), '');
          });
          String bairroBuscado = address['suburb'] ?? address['neighbourhood'] ?? address['village'] ?? '';
          if (bairroBuscado.isNotEmpty) {
            _tentarMatchDeBairro(bairroBuscado);
          }
          await _salvarDadosCache();
        }
      }
    } catch (e) {
    } finally {
      setState(() => _isCarregandoLocalizacao = false);
    }
  }

  void _abrirSiteCorreios() {
    html.window.open('https://buscacepinter.correios.com.br/app/endereco/index.php', '_blank');
  }

  Color _hexToColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF4A0E4E);
    }
  }

  String _gerarDetalhesItensHTML() {
    final produtos = widget.catalogo['produtos'] as List;
    String htmlItens = "";

    for (var p in produtos) {
      int id = p['id'] ?? p['ID'];
      if (widget.carrinho.containsKey(id)) {
        double qtd = widget.carrinho[id]!;
        String obs = widget.observacoes[id] ?? '';
        double preco = double.tryParse(p['price'].toString()) ?? 0.0;
        String un = (p['unidade_medida'] ?? '').toString().toLowerCase();
        bool isPeso = un == 'kg' || un == 'grama' || un == 'g';
        
        double subtotalItem = isPeso ? (preco / 1000.0) * qtd : preco * qtd;

        String nomeAdicionaisFormatados = '';
        if (widget.adicionaisEscolhidos.containsKey(id) && p['adicionais'] != null && p['adicionais'] is List) {
          final escolhas = widget.adicionaisEscolhidos[id]!;
          List<String> nomesAds = [];
          for (var ad in p['adicionais']) {
            if (escolhas.contains(ad['id'] ?? ad['ID'])) {
              double precoAd = double.tryParse(ad['price'].toString()) ?? 0.0;
              subtotalItem += precoAd * (isPeso ? 1 : qtd);
              nomesAds.add(ad['name'] ?? '');
            }
          }
          if (nomesAds.isNotEmpty) {
            nomeAdicionaisFormatados = ' (+ ${nomesAds.join(', ')})';
          }
        }

        String qtdText = isPeso ? '${qtd.toInt()}g' : '${qtd.toInt()} un';
        htmlItens += '''
          <div class="item">
            <span>$qtdText x ${p['name']} $nomeAdicionaisFormatados</span>
            <span>R\$ ${subtotalItem.toStringAsFixed(2).replaceAll('.', ',')}</span>
          </div>
        ''';
        if (obs.isNotEmpty) {
          htmlItens += '<div class="obs">Obs: $obs</div>';
        }
      }
    }
    return htmlItens;
  }

  Future<void> _gerarPdfRecibo(int idPedido) async {
    String base64Logo = "";
    try {
      final ByteData bytes = await rootBundle.load('assets/images/logo.jpg');
      base64Logo = base64Encode(bytes.buffer.asUint8List());
    } catch (_) {}

    String logoHtml = base64Logo.isNotEmpty 
        ? '<img src="data:image/jpeg;base64,$base64Logo" class="logo">' 
        : '';

    String htmlContent = '''
    <!DOCTYPE html>
    <html lang="pt-BR">
    <head>
      <meta charset="UTF-8">
      <title>Recibo #$idPedido - Açaiteria Shalom</title>
      <style>
        body { font-family: 'Courier New', Courier, monospace; max-width: 380px; margin: 0 auto; padding: 20px; color: #000; background: #fff;}
        .header { text-align: center; border-bottom: 1px dashed #000; padding-bottom: 15px; margin-bottom: 15px; }
        .header h2 { margin: 10px 0 5px 0; font-size: 20px; font-weight: bold; }
        .header p { margin: 3px 0; font-size: 13px; color: #222; }
        .logo { width: 75px; height: 75px; border-radius: 50%; object-fit: cover; filter: grayscale(100%); margin-bottom: 5px; }
        .info { margin-bottom: 20px; font-size: 14px; line-height: 1.6; border-bottom: 1px dashed #000; padding-bottom: 15px;}
        .item { display: flex; justify-content: space-between; margin-bottom: 8px; font-size: 14px; font-weight: bold;}
        .obs { font-size: 12px; color: #444; margin-bottom: 12px; padding-left: 10px; font-style: italic;}
        .total { border-top: 1px dashed #000; padding-top: 15px; font-weight: bold; font-size: 18px; margin-top: 15px; display: flex; justify-content: space-between;}
        .taxa { display: flex; justify-content: space-between; font-size: 14px; margin-top: 10px; color: #333;}
        .footer { text-align: center; margin-top: 30px; font-size: 12px; color: #555; border-top: 1px dashed #000; padding-top: 15px;}
        @media print { 
          body { width: 100%; margin: 0; padding: 0; max-width: 100%; } 
        }
      </style>
    </head>
    <body onload="window.print()">
      <div class="header">
        $logoHtml
        <h2>AÇAITERIA SHALOM</h2>
        <p>Rua Josias Gondim - 711</p>
        <p>Santa Clara, Canindé - CE</p>
        <p>WhatsApp: (85) 99999-9999</p>
        <p>Insta: @acaiteriashalom2026</p>
      </div>

      <div class="info">
        <b>PEDIDO Nº:</b> #$idPedido<br>
        <b>CLIENTE:</b> ${_nomeController.text.trim()}<br>
        <b>FONE:</b> ${_telefoneController.text.trim()}<br>
        <b>ENTREGA:</b> $_tipoEntrega<br>
        <b>PAGAMENTO:</b> $_formaPagamento
      </div>
      
      <div style="font-weight: bold; margin-bottom: 15px; text-align: center; font-size: 15px;">ITENS DO PEDIDO</div>
      
      ${_gerarDetalhesItensHTML()}
      
      <div class="taxa">
        <span>Subtotal:</span>
        <span>R\$ ${widget.valorTotal.toStringAsFixed(2).replaceAll('.', ',')}</span>
      </div>
      
      <div class="taxa">
        <span>Taxa de Entrega:</span>
        <span>R\$ ${_tipoEntrega == 'Entrega' ? _taxaEntrega.toStringAsFixed(2).replaceAll('.', ',') : '0,00'}</span>
      </div>

      <div class="total">
        <span>TOTAL:</span>
        <span>R\$ ${_valorTotalComFrete.toStringAsFixed(2).replaceAll('.', ',')}</span>
      </div>
      
      <div class="footer">
        <b>Obrigado pela preferência!</b><br><br>
        Acesse nosso app para pedir novamente.<br>
        <i>Desenvolvido por Pedro Barros</i>
      </div>
    </body>
    </html>
    ''';
    
    final blob = html.Blob([htmlContent], 'text/html; charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
  }

  void _enviarWhatsApp(int idPedido) {
    String numeroDestino = '5585999999999';
    String mensagem = 'Olá! Gostaria de acompanhar meu pedido *#$idPedido* feito pelo aplicativo.\n\nNome: ${_nomeController.text.trim()}';
    String urlSmart = 'https://wa.me/$numeroDestino?text=${Uri.encodeComponent(mensagem)}';
    html.window.open(urlSmart, '_blank');
  }

  void _mostrarModalSucesso(int idPedido, Color corTema) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450),
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90, height: 90,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle, 
                  image: DecorationImage(image: AssetImage('assets/images/logo.jpg'), fit: BoxFit.cover),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]
                ),
              ),
              const SizedBox(height: 24),
              const Text('Pedido Realizado!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.green)),
              const SizedBox(height: 8),
              Text('Seu pedido nº #$idPedido', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54)),
              const SizedBox(height: 24),
              const Text(
                'O seu pedido já foi recebido em nosso painel administrativo e está sendo preparado com muito carinho para você.', 
                textAlign: TextAlign.center, 
                style: TextStyle(color: Colors.black87, height: 1.5, fontSize: 14)
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: corTema, 
                    side: BorderSide(color: corTema, width: 1.5), 
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  onPressed: () => _gerarPdfRecibo(idPedido),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Ver Recibo do Pedido (PDF)', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366), 
                    foregroundColor: Colors.white, 
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  onPressed: () => _enviarWhatsApp(idPedido),
                  icon: const Icon(Icons.chat),
                  label: const Text('Dúvidas? Fale no WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () {
                  Navigator.pop(context); 
                  Navigator.pop(context, true); 
                },
                child: const Text('VOLTAR AO CATÁLOGO', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w900)),
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processarPedido(Color corTema) async {
    if (!_formKey.currentState!.validate()) return;
    
    await _salvarDadosCache();
    setState(() => _isSaving = true);

    List<Map<String, dynamic>> itensDb = [];
    final produtos = widget.catalogo['produtos'] as List;

    for (var p in produtos) {
      int id = p['id'] ?? p['ID'];
      if (widget.carrinho.containsKey(id)) {
        double qtd = widget.carrinho[id]!;
        String obs = widget.observacoes[id] ?? '';
        double preco = double.tryParse(p['price'].toString()) ?? 0.0;
        String un = (p['unidade_medida'] ?? '').toString().toLowerCase();
        bool isPeso = un == 'kg' || un == 'grama' || un == 'g';
        
        double subtotalItem = isPeso ? (preco / 1000.0) * qtd : preco * qtd;

        String nomeAdicionaisFormatados = '';
        if (widget.adicionaisEscolhidos.containsKey(id) && p['adicionais'] != null && p['adicionais'] is List) {
          final escolhas = widget.adicionaisEscolhidos[id]!;
          List<String> nomesAds = [];
          for (var ad in p['adicionais']) {
            if (escolhas.contains(ad['id'] ?? ad['ID'])) {
              double precoAd = double.tryParse(ad['price'].toString()) ?? 0.0;
              subtotalItem += precoAd * (isPeso ? 1 : qtd);
              nomesAds.add(ad['name'] ?? '');
            }
          }
          if (nomesAds.isNotEmpty) {
            nomeAdicionaisFormatados = ' (+ ${nomesAds.join(', ')})';
          }
        }

        itensDb.add({
          'produto_id': id,
          'quantidade': qtd,
          'subtotal': subtotalItem,
          'unidade': un,
          'nome': (p['name'] ?? '') + nomeAdicionaisFormatados + (obs.isNotEmpty ? ' (Obs: $obs)' : ''),
        });
      }
    }

    final dadosPedido = {
      'cliente_nome': _nomeController.text.trim(),
      'cliente_telefone': _telefoneController.text.trim(),
      'tipo_entrega': _tipoEntrega,
      'endereco_rua': _tipoEntrega == 'Entrega' ? _ruaController.text.trim() : '',
      'endereco_numero': _tipoEntrega == 'Entrega' ? _numeroController.text.trim() : '',
      'endereco_bairro': _tipoEntrega == 'Entrega' ? (_bairroSelecionado ?? '') : '',
      'endereco_referencia': _tipoEntrega == 'Entrega' ? _referenciaController.text.trim() : '',
      'forma_pagamento': _formaPagamento,
      'troco_para': double.tryParse(_trocoController.text.replaceAll(',', '.')) ?? 0.0,
      'taxa_entrega': _tipoEntrega == 'Entrega' ? _taxaEntrega : 0.0,
      'valor_total': _valorTotalComFrete,
      'itens': itensDb,
    };

    final resultado = await _pedidoService.salvarPedido(dadosPedido);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (resultado['success'] == true) {
      int idPedidoBanco = resultado['pedido_id'] ?? 0;
      _mostrarModalSucesso(idPedidoBanco, corTema);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Erro ao processar pedido. Tente novamente.'), 
        backgroundColor: Colors.red
      ));
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
                    icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Icon(Icons.check_circle, size: isMobile ? 20 : 28),
                    label: Text(_isSaving ? 'PROCESSANDO...' : 'FINALIZAR PEDIDO (R\$ ${_valorTotalComFrete.toStringAsFixed(2).replaceAll('.', ',')})', style: TextStyle(fontWeight: FontWeight.w900, fontSize: isMobile ? 14 : 16, letterSpacing: 1)),
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
              
              _isCarregandoFretes 
                  ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                  : DropdownButtonFormField<String>(
                      value: _bairroSelecionado,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: 'Bairro', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                      validator: (v) => _tipoEntrega == 'Entrega' && v == null ? 'Por favor, selecione seu bairro' : null,
                      items: _bairrosAtivos.map((b) {
                        final taxa = double.tryParse(b['taxa'].toString()) ?? 0.0;
                        final taxaStr = taxa == 0.0 ? 'Entrega Grátis' : 'Taxa: R\$ ${taxa.toStringAsFixed(2).replaceAll('.', ',')}';
                        return DropdownMenuItem<String>(
                          value: b['bairro'],
                          child: Text('${b['bairro']} - $taxaStr', style: TextStyle(fontSize: isMobile ? 14 : 16)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _bairroSelecionado = val;
                          final match = _bairrosAtivos.firstWhere((b) => b['bairro'] == val);
                          _taxaEntrega = double.tryParse(match['taxa'].toString()) ?? 0.0;
                        });
                        _salvarDadosCache();
                      },
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
                int id = p['id'] ?? p['ID'];
                
                if (!widget.carrinho.containsKey(id)) return const SizedBox.shrink();

                double qtdOuPeso = widget.carrinho[id]!;
                String obs = widget.observacoes[id] ?? '';
                double preco = double.tryParse(p['price'].toString()) ?? 0.0;
                String un = (p['unidade_medida'] ?? '').toString().toLowerCase();
                bool isPeso = un == 'kg' || un == 'grama' || un == 'g';

                double subtotalItem = isPeso ? (preco / 1000.0) * qtdOuPeso : preco * qtdOuPeso;

                List<String> nomesAdicionais = [];
                if (widget.adicionaisEscolhidos.containsKey(id) && p['adicionais'] != null && p['adicionais'] is List) {
                  final escolhas = widget.adicionaisEscolhidos[id]!;
                  for (var ad in p['adicionais']) {
                    if (escolhas.contains(ad['id'] ?? ad['ID'])) {
                      double precoAd = double.tryParse(ad['price'].toString()) ?? 0.0;
                      subtotalItem += precoAd * (isPeso ? 1 : qtdOuPeso);
                      nomesAdicionais.add(ad['name'] ?? '');
                    }
                  }
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(
                              isPeso ? '${qtdOuPeso.toInt()}g' : '${qtdOuPeso.toInt()} unidade(s)',
                              style: const TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                            if (nomesAdicionais.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Text('+ ${nomesAdicionais.join(", ")}', style: TextStyle(color: Colors.orange[800], fontSize: 12, fontWeight: FontWeight.bold)),
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
                Text('Subtotal dos Itens', style: TextStyle(fontSize: isMobile ? 14 : 16)),
                Text('R\$ ${widget.valorTotal.toStringAsFixed(2).replaceAll('.', ',')}', style: TextStyle(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.bold)),
              ],
            ),
            if (_tipoEntrega == 'Entrega')
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Taxa de Entrega', style: TextStyle(fontSize: isMobile ? 14 : 16)),
                    Text('R\$ ${_taxaEntrega.toStringAsFixed(2).replaceAll('.', ',')}', style: TextStyle(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.bold, color: Colors.red)),
                  ],
                ),
              ),
            
            const Padding(padding: EdgeInsets.symmetric(vertical: 12.0), child: Divider()),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: isMobile ? 16 : 20)),
                Text('R\$ ${_valorTotalComFrete.toStringAsFixed(2).replaceAll('.', ',')}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: isMobile ? 22 : 24, color: corTema)),
              ],
            )
          ],
        ),
      ),
    );
  }
}