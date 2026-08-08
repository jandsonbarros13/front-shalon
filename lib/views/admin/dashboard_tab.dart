import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:http/http.dart' as http;
import 'package:acaiteria_front/core/constants/api_constants.dart';
import 'package:acaiteria_front/features/auth/services/pedido_service.dart';
import 'package:acaiteria_front/features/auth/services/vendas_service.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final _pedidoService = PedidoService();
  final _vendasService = VendasService();
  final FlutterTts _flutterTts = FlutterTts();
  
  bool _isLoading = true;
  bool _isDarkMode = true;
  bool _mostrarFiltros = false;

  double _vendaLiquida = 0.0;
  int _vendasAberto = 0;
  double _maiorVenda = 0.0;
  int _qtdPedidos = 0;

  int _qtdPix = 0;
  int _qtdCartao = 0;
  int _qtdDinheiro = 0;
  int _qtdEntrega = 0;
  int _qtdRetirada = 0;
  int _qtdConcluidos = 0;
  int _pedidosPendentes = 0;
  
  List<MapEntry<String, double>> _faturamentoDiario = [];
  List<Map<String, dynamic>> _topVendasRs = [];
  List<Map<String, dynamic>> _topQtd = [];
  List<Map<String, dynamic>> _topClientes = [];
  Map<String, dynamic>? _empresa;

  String _filtroSelecionado = 'Este Mês';
  String? _dataInicioQuery;
  String? _dataFimQuery;

  final GlobalKey _keyFiltros = GlobalKey();
  final GlobalKey _keyCards = GlobalKey();
  final GlobalKey _keyGraficos = GlobalKey();
  final GlobalKey _keyRanking = GlobalKey();
  final GlobalKey _keyDonuts = GlobalKey();

  final List<String> _textosMascote = [
    "Olá, parceiro! Sou o mascote da Açaiteria Shalom! Clicando em 'Filtros' lá em cima, você pode ver os dados de Hoje, do Mês ou escolher um período específico.",
    "Nesses 4 blocos principais no topo, você acompanha o faturamento total, os pedidos em aberto, sua maior venda e o volume de clientes.",
    "Aqui no gráfico principal, você vê o Faturamento Diário para acompanhar os picos de vendas da sua loja.",
    "Fique de olho no nosso Top 5 de Produtos e nos Clientes VIP para fidelizar quem compra mais!",
    "Por fim, nestes gráficos de rosca, você entende o status das vendas, as formas de pagamento mais usadas e os canais de entrega!"
  ];

  @override
  void initState() {
    super.initState();
    _flutterTts.setLanguage("pt-BR");
    _aplicarFiltroRapido('Este Mês');
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  String _formatarData(DateTime data) {
    return "${data.year}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}";
  }

  void _aplicarFiltroRapido(String tipo) {
    final agora = DateTime.now();
    setState(() {
      _filtroSelecionado = tipo;
      if (tipo == 'Hoje') {
        _dataInicioQuery = _formatarData(agora);
        _dataFimQuery = _formatarData(agora);
      } else if (tipo == 'Este Mês') {
        final inicioMes = DateTime(agora.year, agora.month, 1);
        _dataInicioQuery = _formatarData(inicioMes);
        _dataFimQuery = _formatarData(agora);
      } else if (tipo == 'Este Ano') {
        final inicioAno = DateTime(agora.year, 1, 1);
        _dataInicioQuery = _formatarData(inicioAno);
        _dataFimQuery = _formatarData(agora);
      }
    });
    _carregarMetricas();
  }

  Future<void> _abrirSeletorDataPersonalizado(Color accentColor) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: accentColor, onPrimary: Colors.white),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _filtroSelecionado = 'Personalizado';
        _dataInicioQuery = _formatarData(picked.start);
        _dataFimQuery = _formatarData(picked.end);
      });
      _carregarMetricas();
    }
  }

  Future<void> _carregarMetricas() async {
    setState(() => _isLoading = true);
    
    try {
      String urlBaseLimpa = ApiConstants.baseUrl.trim();
      if (urlBaseLimpa.endsWith('/')) urlBaseLimpa = urlBaseLimpa.substring(0, urlBaseLimpa.length - 1);
      if (urlBaseLimpa.endsWith('/api')) urlBaseLimpa = urlBaseLimpa.substring(0, urlBaseLimpa.length - 4);
      
      final urlEmp = Uri.parse('$urlBaseLimpa/api/empresa');
      final responseEmp = await http.get(urlEmp);
      if (responseEmp.statusCode == 200) {
        var dados = jsonDecode(responseEmp.body);
        if (dados is List && dados.isNotEmpty) {
          _empresa = dados[0];
        } else if (dados is Map<String, dynamic>) {
          _empresa = dados;
        }
      }

      final resultados = await Future.wait([
        _pedidoService.listarPedidos(1, dataInicio: _dataInicioQuery, dataFim: _dataFimQuery, limit: 1000),
        _vendasService.listarVendas(1, limit: 1000) 
      ]);

      List<dynamic> todosPedidos = resultados[0]['pedidos'] ?? [];
      List<dynamic> todasVendas = resultados[1]['vendas'] ?? [];

      DateTime? dtInicio = _dataInicioQuery != null ? DateTime.parse(_dataInicioQuery!) : null;
      DateTime? dtFim = _dataFimQuery != null ? DateTime.parse(_dataFimQuery!).add(const Duration(days: 1)) : null;

      List<dynamic> transacoes = [...todosPedidos, ...todasVendas].where((t) {
        if (dtInicio == null || dtFim == null) return true;
        final dataStr = (t['data'] ?? '').toString();
        if (dataStr.length >= 5) {
          int dia = int.tryParse(dataStr.substring(0, 2)) ?? 1;
          int mes = int.tryParse(dataStr.substring(3, 5)) ?? 1;
          DateTime dtTransacao = DateTime(DateTime.now().year, mes, dia);
          return dtTransacao.isAfter(dtInicio.subtract(const Duration(days: 1))) && dtTransacao.isBefore(dtFim);
        }
        return true;
      }).toList();

      double vLiquidaCalc = 0.0;
      int vAbertoCalc = 0;
      double mVendaCalc = 0.0;
      int qPedidosCalc = 0;

      int pix = 0, cartao = 0, dinheiro = 0;
      int entrega = 0, retirada = 0;
      int concluidosCalc = 0, pendentesCalc = 0;

      Map<String, double> fatDiarioMap = {};
      Map<String, double> produtosValMap = {};
      Map<String, int> produtosQtdMap = {};
      Map<String, double> clientesMap = {};

      for (var t in transacoes) {
        final status = (t['status'] ?? '').toString().toLowerCase();
        final double valor = double.tryParse((t['valor_total'] ?? 0).toString()) ?? 0.0;
        final clienteNome = t['cliente_nome'] ?? 'Consumidor Final';
        final formaPgto = (t['forma_pagamento'] ?? '').toString().toLowerCase();
        final tipoEnvio = (t['tipo_entrega'] ?? '').toString().toLowerCase();
        final dataStr = (t['data'] ?? '').toString(); 
        final String diaMes = dataStr.length >= 5 ? dataStr.substring(0, 5) : '00/00';

        if (status != 'cancelado') {
          vLiquidaCalc += valor;
          qPedidosCalc++;
          if (valor > mVendaCalc) mVendaCalc = valor;

          if (status == 'pendente' || status == 'preparando') {
            vAbertoCalc++;
            pendentesCalc++;
          } else {
            concluidosCalc++;
          }

          if (formaPgto.contains('pix')) pix++;
          else if (formaPgto.contains('cart') || formaPgto.contains('cred') || formaPgto.contains('deb')) cartao++;
          else dinheiro++;

          if (tipoEnvio.contains('entreg')) entrega++;
          else retirada++;

          fatDiarioMap[diaMes] = (fatDiarioMap[diaMes] ?? 0) + valor;
          clientesMap[clienteNome] = (clientesMap[clienteNome] ?? 0) + valor;

          List<dynamic> itens = t['itens'] ?? [];
          for (var item in itens) {
            String nomeItem = item['nome'] ?? 'Item Avulso';
            double subtotal = double.tryParse(item['subtotal'].toString()) ?? 0.0;
            double qtd = double.tryParse(item['quantidade'].toString()) ?? 1.0;

            produtosValMap[nomeItem] = (produtosValMap[nomeItem] ?? 0) + subtotal;
            produtosQtdMap[nomeItem] = (produtosQtdMap[nomeItem] ?? 0) + qtd.toInt();
          }
        }
      }

      var fatDiarioList = fatDiarioMap.entries.toList();
      fatDiarioList = fatDiarioList.reversed.toList();

      var listProdVal = produtosValMap.entries.map((e) => {'nome': e.key, 'valor': e.value}).toList();
      listProdVal.sort((a, b) => (b['valor'] as double).compareTo(a['valor'] as double));
      
      var listProdQtd = produtosQtdMap.entries.map((e) => {'nome': e.key, 'qtd': e.value}).toList();
      listProdQtd.sort((a, b) => (b['qtd'] as int).compareTo(a['qtd'] as int));

      var listClientes = clientesMap.entries.map((e) => {'nome': e.key, 'valor': e.value}).toList();
      listClientes.sort((a, b) => (b['valor'] as double).compareTo(a['valor'] as double));

      setState(() {
        _vendaLiquida = vLiquidaCalc;
        _vendasAberto = vAbertoCalc;
        _maiorVenda = mVendaCalc;
        _qtdPedidos = qPedidosCalc;
        
        _qtdPix = pix;
        _qtdCartao = cartao;
        _qtdDinheiro = dinheiro;
        _qtdEntrega = entrega;
        _qtdRetirada = retirada;
        _qtdConcluidos = concluidosCalc;
        _pedidosPendentes = pendentesCalc;

        _faturamentoDiario = fatDiarioList;
        _topVendasRs = listProdVal.take(5).toList();
        _topQtd = listProdQtd.take(5).toList();
        _topClientes = listClientes.take(5).toList();
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
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
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15, spreadRadius: 3)],
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
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor, height: 1.4),
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
                  label: Text(isLast ? 'Concluir' : 'Próximo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
        final isMobile = MediaQuery.of(context).size.width < 600;

        Widget caixaTexto = Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
          child: Text(
            "Olá, parceiro! Sou o mascote da Açaiteria Shalom! 🍇✨\n\n"
            "Preparei um Tour Guiado para te apresentar nosso novo Painel de Inteligência (BI). "
            "Vou te mostrar passo a passo como visualizar seu faturamento, acompanhar o gráfico diário e identificar seus melhores clientes.\n\n"
            "Clique no botão abaixo para começarmos!",
            style: TextStyle(fontSize: 15, color: textColor, height: 1.5, fontWeight: FontWeight.w500),
          ),
        );

        Widget botaoIniciar = ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: () {
            Navigator.of(ctx).pop();
            ShowCaseWidget.of(showcaseContext).startShowCase([
              _keyFiltros,
              _keyCards,
              _keyGraficos,
              _keyRanking,
              _keyDonuts,
            ]);
          },
          icon: const Icon(Icons.slideshow, size: 24),
          label: const Text('Ver e Ouvir Explicação', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        );

        Widget botaoFechar = OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: textColor,
            side: BorderSide(color: textMuted, width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Agora não', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        );

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
                Flexible(
                  child: SingleChildScrollView(
                    child: isMobile
                        ? Column(
                            children: [
                              Image.asset(
                                'assets/images/mascote_acenando.gif',
                                width: 100, height: 100, fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Icon(Icons.sentiment_satisfied_alt, size: 80, color: accentColor),
                              ),
                              const SizedBox(height: 16),
                              caixaTexto,
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Image.asset(
                                'assets/images/mascote_acenando.gif',
                                width: 100, height: 100, fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Icon(Icons.sentiment_satisfied_alt, size: 80, color: accentColor),
                              ),
                              const SizedBox(width: 16),
                              Expanded(child: caixaTexto),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [botaoIniciar, const SizedBox(height: 12), botaoFechar],
                      )
                    : Row(
                        children: [Expanded(child: botaoIniciar), const SizedBox(width: 12), Expanded(child: botaoFechar)],
                      )
              ],
            ),
          ),
        );
      },
    );
  }

  Color get bgColor => _isDarkMode ? const Color(0xFF1E1E2C) : const Color(0xFFF4F6F8);
  Color get cardColor => _isDarkMode ? const Color(0xFF27293D) : Colors.white;
  Color get textColor => _isDarkMode ? Colors.white : const Color(0xFF333333);
  Color get textMuted => _isDarkMode ? Colors.white54 : Colors.grey[600]!;
  Color get accentColor => _isDarkMode ? const Color(0xFFE91E63) : const Color(0xFF4A0E4E); 

  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.of(context).size.width;
    final isDesktop = largura > 1100;

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
                    'AÇAITERIA SHALOM BI', 
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              Showcase.withWidget(
                key: _keyFiltros,
                container: _buildTooltipMascote(showcaseContext, _textosMascote[0], false),
                child: Center(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(color: textMuted.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: const Size(0, 36),
                    ),
                    onPressed: () => setState(() => _mostrarFiltros = !_mostrarFiltros),
                    icon: Icon(_mostrarFiltros ? Icons.visibility_off : Icons.filter_alt, size: 16),
                    label: Text(_mostrarFiltros ? 'Ocultar Filtros' : 'Filtros', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode, color: textColor),
                onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
                tooltip: 'Alternar Tema',
              ),
              IconButton(
                icon: Icon(Icons.refresh, color: textColor),
                onPressed: _carregarMetricas,
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: _isLoading
              ? Center(child: CircularProgressIndicator(color: accentColor))
              : Stack(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_mostrarFiltros) ...[
                            _buildTopFilters(),
                            const SizedBox(height: 16),
                          ],

                          Showcase.withWidget(
                            key: _keyCards,
                            container: _buildTooltipMascote(showcaseContext, _textosMascote[1], false),
                            child: isDesktop ? _buildTopCardsDesktop() : _buildTopCardsMobile(),
                          ),
                          const SizedBox(height: 16),

                          Showcase.withWidget(
                            key: _keyGraficos,
                            container: _buildTooltipMascote(showcaseContext, _textosMascote[2], false),
                            child: _buildLineChartCard(),
                          ),
                          const SizedBox(height: 16),

                          Showcase.withWidget(
                            key: _keyRanking,
                            container: _buildTooltipMascote(showcaseContext, _textosMascote[3], false),
                            child: isDesktop ? _buildBottomRankingsDesktop() : _buildBottomRankingsMobile(),
                          ),
                          const SizedBox(height: 16),

                          Showcase.withWidget(
                            key: _keyDonuts,
                            container: _buildTooltipMascote(showcaseContext, _textosMascote[4], true),
                            child: _buildDonutChartsRow(isDesktop),
                          ),
                          
                          _buildFooter(),
                        ],
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
                                color: accentColor.withOpacity(0.5),
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
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 80, height: 80,
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
      },
    );
  }

  Widget _buildTopFilters() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buildFilterBtn('Hoje'),
          _buildFilterBtn('Este Mês'),
          _buildFilterBtn('Este Ano'),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _abrirSeletorDataPersonalizado(accentColor),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[700]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_dataInicioQuery != null ? '${_dataInicioQuery!.split('-').reversed.join('/')} - ${_dataFimQuery!.split('-').reversed.join('/')}' : 'Período Personalizado', style: TextStyle(color: textColor, fontSize: 12)),
                  const SizedBox(width: 8),
                  Icon(Icons.calendar_today, color: textMuted, size: 16),
                ],
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () {
              setState(() => _mostrarFiltros = false);
              _carregarMetricas();
            },
            child: const Text('APLICAR FILTRO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          )
        ],
      ),
    );
  }

  Widget _buildFilterBtn(String label) {
    bool isSel = _filtroSelecionado == label;
    return InkWell(
      onTap: () => _aplicarFiltroRapido(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: isSel ? accentColor : Colors.grey[700]!),
          borderRadius: BorderRadius.circular(20),
          color: isSel ? accentColor.withOpacity(0.1) : Colors.transparent,
        ),
        child: Text(label, style: TextStyle(color: isSel ? accentColor : textMuted, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  Widget _buildTopCardsDesktop() {
    return Row(
      children: [
        Expanded(child: _buildMetricCard('VENDA LÍQUIDA', 'R\$ ${_vendaLiquida.toStringAsFixed(2).replaceAll('.', ',')}', Icons.monetization_on_outlined, accentColor)),
        const SizedBox(width: 16),
        Expanded(child: _buildMetricCard('VENDAS EM ABERTO', '$_vendasAberto', Icons.error_outline, Colors.amber)),
        const SizedBox(width: 16),
        Expanded(child: _buildMetricCard('MAIOR VENDA', 'R\$ ${_maiorVenda.toStringAsFixed(2).replaceAll('.', ',')}', Icons.emoji_events_outlined, Colors.blueAccent)),
        const SizedBox(width: 16),
        Expanded(child: _buildMetricCard('QTD PEDIDOS', '$_qtdPedidos', Icons.shopping_cart_outlined, accentColor)),
      ],
    );
  }

  Widget _buildTopCardsMobile() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.6,
      children: [
        _buildMetricCard('VENDA LÍQUIDA', 'R\$ ${_vendaLiquida.toStringAsFixed(2).replaceAll('.', ',')}', Icons.monetization_on_outlined, accentColor),
        _buildMetricCard('VENDAS EM ABERTO', '$_vendasAberto', Icons.error_outline, Colors.amber),
        _buildMetricCard('MAIOR VENDA', 'R\$ ${_maiorVenda.toStringAsFixed(2).replaceAll('.', ',')}', Icons.emoji_events_outlined, Colors.blueAccent),
        _buildMetricCard('QTD PEDIDOS', '$_qtdPedidos', Icons.shopping_cart_outlined, accentColor),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color sideColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: sideColor, width: 4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: sideColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLineChartCard() {
    return Container(
      height: 350,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('FATURAMENTO DIÁRIO NO PERÍODO', style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Container(width: 20, height: 8, color: accentColor),
                  const SizedBox(width: 8),
                  Text('Venda Total', style: TextStyle(color: textColor, fontSize: 12)),
                ],
              )
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _faturamentoDiario.isEmpty 
              ? Center(child: Text('Sem dados no período', style: TextStyle(color: textMuted)))
              : CustomPaint(
                  size: Size.infinite,
                  painter: _LineChartPainter(
                    dados: _faturamentoDiario,
                    lineColor: accentColor,
                    textColor: textMuted,
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomRankingsDesktop() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildRankingList('TOP 5 VENDAS (R\$)', _topVendasRs, isCurrency: true, badgeColor: accentColor)),
        const SizedBox(width: 16),
        Expanded(child: _buildRankingList('TOP 5 QUANTIDADE', _topQtd, isCurrency: false, badgeColor: Colors.purpleAccent)),
        const SizedBox(width: 16),
        Expanded(child: _buildRankingList('TOP 5 CLIENTES (R\$)', _topClientes, isCurrency: true, badgeColor: Colors.blueAccent)),
      ],
    );
  }

  Widget _buildBottomRankingsMobile() {
    return Column(
      children: [
        _buildRankingList('TOP 5 VENDAS (R\$)', _topVendasRs, isCurrency: true, badgeColor: accentColor),
        const SizedBox(height: 16),
        _buildRankingList('TOP 5 QUANTIDADE', _topQtd, isCurrency: false, badgeColor: Colors.purpleAccent),
        const SizedBox(height: 16),
        _buildRankingList('TOP 5 CLIENTES (R\$)', _topClientes, isCurrency: true, badgeColor: Colors.blueAccent),
      ],
    );
  }

  Widget _buildRankingList(String title, List<Map<String, dynamic>> items, {required bool isCurrency, required Color badgeColor}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (items.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Text('Nenhum dado', style: TextStyle(color: textMuted))),
          ...items.asMap().entries.map((e) {
            int rank = e.key + 1;
            var data = e.value;
            String valStr = isCurrency 
              ? (data['valor'] as double).toStringAsFixed(2).replaceAll('.', ',')
              : (data['qtd'] as int).toString();

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Container(
                    width: 24, height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(4)),
                    child: Text('$rank', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(data['nome'], style: TextStyle(color: textColor, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Text(valStr, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDonutChartsRow(bool isDesktop) {
    List<Widget> charts = [
      _buildGraficoRosca('STATUS VENDAS', [
        _BarData('Fechadas', _qtdConcluidos, Colors.tealAccent[400]!),
        _BarData('Abertas', _pedidosPendentes, Colors.amber),
      ]),
      _buildGraficoRosca('FORMAS DE PAGTO', [
        _BarData('Pix', _qtdPix, Colors.teal),
        _BarData('Cartão', _qtdCartao, Colors.indigo),
        _BarData('Dinheiro', _qtdDinheiro, Colors.blueGrey),
      ]),
      _buildGraficoRosca('CANAIS DE DISTRIB.', [
        _BarData('Entrega', _qtdEntrega, Colors.purple),
        _BarData('Retirada', _qtdRetirada, Colors.orange),
      ]),
    ];

    if (isDesktop) {
      return Row(
        children: [
          Expanded(child: charts[0]), const SizedBox(width: 16),
          Expanded(child: charts[1]), const SizedBox(width: 16),
          Expanded(child: charts[2]),
        ],
      );
    } else {
      return Column(
        children: [
          charts[0], const SizedBox(height: 16),
          charts[1], const SizedBox(height: 16),
          charts[2],
        ],
      );
    }
  }

  Widget _buildGraficoRosca(String titulo, List<_BarData> dados) {
    int total = dados.fold(0, (sum, item) => sum + item.valor);

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textMuted)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(120, 120),
                        painter: _DonutChartPainter(dados, total, cardColor),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Total', style: TextStyle(fontSize: 10, color: textMuted, fontWeight: FontWeight.bold)),
                          Text('$total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor)),
                        ],
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: dados.length,
                  itemBuilder: (context, idx) {
                    final item = dados[idx];
                    final percent = total > 0 ? ((item.valor / total) * 100).toStringAsFixed(1) : '0.0';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Container(width: 12, height: 12, decoration: BoxDecoration(color: item.cor, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(item.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor), overflow: TextOverflow.ellipsis)),
                          Text('$percent%', style: TextStyle(fontSize: 12, color: textMuted, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  },
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final String rua = _empresa?['logradouro']?.toString() ?? 'Rua Josias Gondim';
    final String num = _empresa?['numero']?.toString() ?? '711';
    final String bairro = _empresa?['bairro']?.toString() ?? 'Santa Clara';
    final String cidade = _empresa?['cidade']?.toString() ?? 'Canindé - CE';
    final String tel = _empresa?['whatsapp']?.toString() ?? '(85) 99999-9999';
    final String insta = _empresa?['instagram']?.toString() ?? '@acaiteriashalom2026';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      margin: const EdgeInsets.only(top: 24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border(top: BorderSide(color: accentColor, width: 2)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceEvenly,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 24,
        runSpacing: 16,
        children: [
          Text('POWERED BY Açaiteria Shalom', style: TextStyle(color: textMuted, fontWeight: FontWeight.bold, fontSize: 12)),
          Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.location_on, color: accentColor, size: 16), const SizedBox(width: 8), Text('$rua, $num - $bairro, $cidade', style: TextStyle(color: textMuted, fontSize: 12))]),
          Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.phone, color: accentColor, size: 16), const SizedBox(width: 8), Text(tel, style: TextStyle(color: textMuted, fontSize: 12))]),
          Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.camera_alt, color: accentColor, size: 16), const SizedBox(width: 8), Text(insta, style: TextStyle(color: textMuted, fontSize: 12))]),
        ],
      ),
    );
  }
}

class _BarData {
  final String label;
  final int valor;
  final Color cor;
  _BarData(this.label, this.valor, this.cor);
}

class _DonutChartPainter extends CustomPainter {
  final List<_BarData> dados;
  final int total;
  final Color bgColor;

  _DonutChartPainter(this.dados, this.total, this.bgColor);

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) {
      final paint = Paint()
        ..color = Colors.grey[800]!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20;
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2, paint);
      return;
    }

    double startAngle = -pi / 2; 
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    
    for (var item in dados) {
      if (item.valor == 0) continue;
      
      final sweepAngle = (item.valor / total) * 2 * pi;
      final paint = Paint()
        ..color = item.cor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20;
      
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      
      startAngle += sweepAngle;
      canvas.drawArc(rect, startAngle - 0.05, 0.05, false, Paint()..color=bgColor..style=PaintingStyle.stroke..strokeWidth=21);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _LineChartPainter extends CustomPainter {
  final List<MapEntry<String, double>> dados;
  final Color lineColor;
  final Color textColor;

  _LineChartPainter({required this.dados, required this.lineColor, required this.textColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (dados.isEmpty) return;

    final double maxVal = dados.map((e) => e.value).reduce(max);
    const double leftMargin = 40.0; 
    const double bottomMargin = 30.0;
    final double graphWidth = size.width - leftMargin;
    final double graphHeight = size.height - bottomMargin;

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final gridPaint = Paint()
      ..color = textColor.withOpacity(0.1)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    int ySteps = 4;
    for (int i = 0; i <= ySteps; i++) {
      double yVal = (maxVal / ySteps) * i;
      double yPos = graphHeight - (graphHeight * (i / ySteps));

      canvas.drawLine(Offset(leftMargin, yPos), Offset(size.width, yPos), gridPaint);

      textPainter.text = TextSpan(
        text: yVal >= 1000 ? '${(yVal/1000).toStringAsFixed(1)}k' : yVal.toInt().toString(),
        style: TextStyle(color: textColor, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, yPos - 6)); 
    }

    final path = Path();
    final fillPath = Path();

    double stepX = dados.length > 1 ? graphWidth / (dados.length - 1) : graphWidth;

    for (int i = 0; i < dados.length; i++) {
      double xPos = leftMargin + (i * stepX);
      double yPos = graphHeight - (maxVal > 0 ? (dados[i].value / maxVal) * graphHeight : 0);

      if (i == 0) {
        path.moveTo(xPos, yPos);
        fillPath.moveTo(xPos, graphHeight);
        fillPath.lineTo(xPos, yPos);
      } else {
        double prevX = leftMargin + ((i - 1) * stepX);
        double prevY = graphHeight - (maxVal > 0 ? (dados[i-1].value / maxVal) * graphHeight : 0);
        
        double controlX1 = prevX + (stepX / 2);
        double controlY1 = prevY;
        double controlX2 = prevX + (stepX / 2);
        double controlY2 = yPos;

        path.cubicTo(controlX1, controlY1, controlX2, controlY2, xPos, yPos);
        fillPath.cubicTo(controlX1, controlY1, controlX2, controlY2, xPos, yPos);
      }

      canvas.drawCircle(Offset(xPos, yPos), 3, Paint()..color = lineColor);

      if (dados.length < 15 || i % (dados.length ~/ 10) == 0 || i == dados.length - 1) {
        textPainter.text = TextSpan(
          text: dados[i].key,
          style: TextStyle(color: textColor, fontSize: 9),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(xPos - (textPainter.width / 2), graphHeight + 10));
      }
    }

    fillPath.lineTo(leftMargin + graphWidth, graphHeight);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [lineColor.withOpacity(0.4), lineColor.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(leftMargin, 0, graphWidth, graphHeight));

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}