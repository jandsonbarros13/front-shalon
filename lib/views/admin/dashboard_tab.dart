import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:acaiteria_front/features/auth/services/pedido_service.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final _pedidoService = PedidoService();
  final FlutterTts _flutterTts = FlutterTts();
  
  final GlobalKey _keyFiltros = GlobalKey();
  final GlobalKey _keyCards = GlobalKey();
  final GlobalKey _keyGraficos = GlobalKey();
  final GlobalKey _keyRanking = GlobalKey();

  bool _isLoading = true;
  double _faturamentoTotal = 0.0;
  int _pedidosPendentes = 0;
  int _totalPedidosValidos = 0;
  double _ticketMedio = 0.0;
  
  List<Map<String, dynamic>> _topClientes = [];

  int _qtdPix = 0;
  int _qtdCartao = 0;
  int _qtdDinheiro = 0;
  int _qtdEntrega = 0;
  int _qtdRetirada = 0;
  int _qtdConcluidos = 0;

  String _filtroSelecionado = 'Hoje';
  String? _dataInicioQuery;
  String? _dataFimQuery;

  final List<String> _textosMascote = [
    "Olá, parceiro! Sou o mascote da Açaiteria Shalom! Lá em cima, você pode usar os filtros rápidos para ver os dados de Hoje, da Semana ou escolher um período específico.",
    "Nos blocos principais, você acompanha o dinheiro que está entrando e a nossa Fila de Preparo. Não deixe a fila crescer muito!",
    "Aqui nos gráficos de rosca, você entende exatamente como seus clientes preferem pagar e se estão pedindo Entrega ou Retirada.",
    "E por fim, fique de olho no nosso Ranking de Clientes VIP para fidelizar quem compra mais!"
  ];

  @override
  void initState() {
    super.initState();
    _flutterTts.setLanguage("pt-BR");
    final agora = DateTime.now();
    _dataInicioQuery = _formatarData(agora);
    _dataFimQuery = _formatarData(agora);
    _carregarMetricas();
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
      } else if (tipo == 'Ontem') {
        final ontem = agora.subtract(const Duration(days: 1));
        _dataInicioQuery = _formatarData(ontem);
        _dataFimQuery = _formatarData(ontem);
      } else if (tipo == '7Dias') {
        final seteDiasAtras = agora.subtract(const Duration(days: 7));
        _dataInicioQuery = _formatarData(seteDiasAtras);
        _dataFimQuery = _formatarData(agora);
      } else if (tipo == '30Dias') {
        final trintaDiasAtras = agora.subtract(const Duration(days: 30));
        _dataInicioQuery = _formatarData(trintaDiasAtras);
        _dataFimQuery = _formatarData(agora);
      } else {
        _dataInicioQuery = null;
        _dataFimQuery = null;
      }
    });
    _carregarMetricas();
  }

  Future<void> _abrirSeletorDataPersonalizado(Color corTema) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: corTema,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
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
      final int limiteRegistros = _filtroSelecionado == 'Tudo' ? 500 : 100;
      final resultado = await _pedidoService.listarPedidos(1, dataInicio: _dataInicioQuery, dataFim: _dataFimQuery, limit: limiteRegistros);
      final pedidos = resultado['pedidos'] as List? ?? [];
      
      double faturamentoCalc = 0.0;
      int pendentesCalc = 0;
      int concluidosCalc = 0;
      
      int pix = 0, cartao = 0, dinheiro = 0;
      int entrega = 0, retirada = 0;

      Map<String, Map<String, dynamic>> clientesMap = {};

      for (var p in pedidos) {
        final status = (p['status'] ?? p['Status'] ?? '').toString().toLowerCase();
        final double valor = double.tryParse((p['valor_total'] ?? p['ValorTotal'] ?? 0).toString()) ?? 0.0;
        final clienteNome = p['cliente_nome'] ?? p['ClienteNome'] ?? 'Desconhecido';
        final clienteTel = p['cliente_telefone'] ?? p['ClienteTelefone'] ?? '';
        final chaveCliente = '$clienteNome-$clienteTel';
        final formaPgto = (p['forma_pagamento'] ?? p['FormaPagamento'] ?? '').toString().toLowerCase();
        final tipoEnvio = (p['tipo_entrega'] ?? p['TipoEntrega'] ?? '').toString().toLowerCase();

        if (status != 'cancelado') {
          faturamentoCalc += valor;

          if (status == 'concluido' || status == 'concluído' || status == 'finalizado') {
            concluidosCalc++;
          } else {
            pendentesCalc++;
          }

          if (!clientesMap.containsKey(chaveCliente)) {
            clientesMap[chaveCliente] = {
              'nome': clienteNome,
              'telefone': clienteTel,
              'total_gasto': 0.0,
              'qtd_pedidos': 0,
            };
          }
          clientesMap[chaveCliente]!['total_gasto'] += valor;
          clientesMap[chaveCliente]!['qtd_pedidos'] += 1;

          if (formaPgto.contains('pix')) {
            pix++;
          } else if (formaPgto.contains('cart') || formaPgto.contains('cred') || formaPgto.contains('deb')) {
            cartao++;
          } else {
            dinheiro++;
          }

          if (tipoEnvio.contains('entreg')) {
            entrega++;
          } else {
            retirada++;
          }
        }
      }

      int totalVendasEfetivas = concluidosCalc + pendentesCalc;
      double ticketCalc = totalVendasEfetivas > 0 ? (faturamentoCalc / totalVendasEfetivas) : 0.0;

      List<Map<String, dynamic>> listaClientes = clientesMap.values.toList();
      listaClientes.sort((a, b) => b['total_gasto'].compareTo(a['total_gasto']));

      setState(() {
        _faturamentoTotal = faturamentoCalc;
        _pedidosPendentes = pendentesCalc;
        _totalPedidosValidos = totalVendasEfetivas;
        _ticketMedio = ticketCalc;
        _topClientes = listaClientes.take(5).toList();
        _qtdPix = pix;
        _qtdCartao = cartao;
        _qtdDinheiro = dinheiro;
        _qtdEntrega = entrega;
        _qtdRetirada = retirada;
        _qtdConcluidos = concluidosCalc;
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 15, spreadRadius: 3)],
          border: Border.all(color: const Color(0xFF4A0E4E), width: 3),
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
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A0E4E).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/mascote_acenando.gif',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.record_voice_over, color: Color(0xFF4A0E4E)),
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
                    backgroundColor: const Color(0xFF4A0E4E),
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
        final isMobile = MediaQuery.of(context).size.width < 600;

        Widget caixaTexto = Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            "Olá, parceiro! Sou o mascote da Açaiteria Shalom! 🍇✨\n\n"
            "Preparei um Tour Guiado para te apresentar nosso Painel de Inteligência. "
            "Vou te mostrar passo a passo como visualizar seu faturamento, acompanhar a fila de pedidos e identificar seus melhores clientes.\n\n"
            "Clique no botão abaixo para começarmos!",
            style: TextStyle(fontSize: 15, color: Colors.grey[800], height: 1.5, fontWeight: FontWeight.w500),
          ),
        );

        Widget botaoIniciar = ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: corTema,
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
            ]);
          },
          icon: const Icon(Icons.slideshow, size: 24),
          label: const Text(
            'Ver e Ouvir Explicação',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        );

        Widget botaoFechar = OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: corTema,
            side: BorderSide(color: corTema, width: 2),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: corTema, width: 3),
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
                                errorBuilder: (_, __, ___) => Icon(Icons.sentiment_satisfied_alt, size: 80, color: corTema),
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
                                errorBuilder: (_, __, ___) => Icon(Icons.sentiment_satisfied_alt, size: 80, color: corTema),
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
                        children: [
                          botaoIniciar,
                          const SizedBox(height: 12),
                          botaoFechar,
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: botaoIniciar),
                          const SizedBox(width: 12),
                          Expanded(child: botaoFechar),
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
    final largura = MediaQuery.of(context).size.width;
    final corTema = const Color(0xFF4A0E4E);

    return ShowCaseWidget(
      onStart: (index, key) => _playAudioForStep(index),
      onComplete: (index, key) => _flutterTts.stop(),
      onFinish: () => _flutterTts.stop(),
      builder: (showcaseContext) {
        return Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 24.0, bottom: 120.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60, height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: corTema, width: 2),
                          image: const DecorationImage(image: AssetImage('assets/images/logo.jpg'), fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Visão Estratégica (BI)', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: corTema, letterSpacing: 0.5)),
                            Text('Painel de Performance Geral • Shalom', style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 28),
                        color: corTema,
                        tooltip: 'Atualizar Dados',
                        onPressed: _carregarMetricas,
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  Showcase.withWidget(
                    key: _keyFiltros,
                    container: _buildTooltipMascote(showcaseContext, _textosMascote[0], false),
                    child: Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _buildFiltroButton('Hoje', 'Hoje'),
                            _buildFiltroButton('Ontem', 'Ontem'),
                            _buildFiltroButton('7Dias', 'Últimos 7 dias'),
                            _buildFiltroButton('30Dias', 'Últimos 30 dias'),
                            _buildFiltroButton('Tudo', 'Histórico Total'),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _filtroSelecionado == 'Personalizado' ? corTema : Colors.grey[200],
                                foregroundColor: _filtroSelecionado == 'Personalizado' ? Colors.white : Colors.black87,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _abrirSeletorDataPersonalizado(corTema),
                              icon: const Icon(Icons.calendar_month, size: 18),
                              label: const Text('Período Customizado'),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  if (_isLoading)
                    SizedBox(height: 400, child: Center(child: CircularProgressIndicator(color: corTema)))
                  else ...[
                    Showcase.withWidget(
                      key: _keyCards,
                      container: _buildTooltipMascote(showcaseContext, _textosMascote[1], false),
                      child: GridView.count(
                        crossAxisCount: largura > 1200 ? 4 : (largura > 700 ? 2 : 1),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: largura > 1200 ? 2.0 : 2.5,
                        children: [
                          _buildCard('Faturamento Total Acumulado', 'R\$ ${_faturamentoTotal.toStringAsFixed(2).replaceAll('.', ',')}', Icons.monetization_on, Colors.green),
                          _buildCard('Fila de Preparo', '$_pedidosPendentes', Icons.hourglass_empty, Colors.amber[700]!),
                          _buildCard('Ticket Médio', 'R\$ ${_ticketMedio.toStringAsFixed(2).replaceAll('.', ',')}', Icons.receipt_long, Colors.purple),
                          _buildCard('Total de Pedidos', '$_totalPedidosValidos', Icons.shopping_bag, Colors.blue),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    Showcase.withWidget(
                      key: _keyGraficos,
                      container: _buildTooltipMascote(showcaseContext, _textosMascote[2], false),
                      child: GridView.count(
                        crossAxisCount: largura > 1100 ? 3 : 1,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: largura > 1100 ? 1.4 : (largura > 600 ? 2.0 : 1.0),
                        children: [
                          _buildGraficoRosca('Formas de Pagamento', [
                            _BarData('Pix', _qtdPix, Colors.teal),
                            _BarData('Cartão', _qtdCartao, Colors.indigo),
                            _BarData('Dinheiro', _qtdDinheiro, Colors.blueGrey),
                          ]),
                          _buildGraficoRosca('Canais de Distribuição', [
                            _BarData('Entrega', _qtdEntrega, Colors.purple),
                            _BarData('Retirada', _qtdRetirada, Colors.orange),
                          ]),
                          _buildGraficoRosca('Eficiência (Status)', [
                            _BarData('Concluídos', _qtdConcluidos, Colors.green),
                            _BarData('Na Fila', _pedidosPendentes, Colors.amber),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    largura > 900 
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: _wrapWithRankingShowcase(showcaseContext, corTema)),
                            const SizedBox(width: 24),
                            Expanded(flex: 2, child: _buildCaixaAvisos(corTema)),
                          ],
                        )
                      : Column(
                          children: [
                            _wrapWithRankingShowcase(showcaseContext, corTema),
                            const SizedBox(height: 24),
                            _buildCaixaAvisos(corTema),
                          ],
                        )
                  ]
                ],
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
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 90, height: 90,
                        decoration: BoxDecoration(color: corTema, shape: BoxShape.circle),
                        child: const Icon(Icons.help_outline, color: Colors.white, size: 40),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _wrapWithRankingShowcase(BuildContext showcaseContext, Color corTema) {
    return Showcase.withWidget(
      key: _keyRanking,
      container: _buildTooltipMascote(showcaseContext, _textosMascote[3], true),
      child: _buildRankingClientes(corTema),
    );
  }

  Widget _buildFiltroButton(String tipo, String label) {
    final bool ativo = _filtroSelecionado == tipo;
    final corTema = const Color(0xFF4A0E4E);
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: ativo ? corTema : Colors.grey[200],
        foregroundColor: ativo ? Colors.white : Colors.black87,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () => _aplicarFiltroRapido(tipo),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 36),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraficoRosca(String titulo, List<_BarData> dados) {
    int total = dados.fold(0, (sum, item) => sum + item.valor);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF4A0E4E))),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final size = min(constraints.maxWidth, constraints.maxHeight);
                        return Center(
                          child: SizedBox(
                            width: size * 0.8,
                            height: size * 0.8,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CustomPaint(
                                  size: Size(size * 0.8, size * 0.8),
                                  painter: _DonutChartPainter(dados, total),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Total', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                                    Text('$total', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                                  ],
                                )
                              ],
                            ),
                          ),
                        );
                      }
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
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
                              Expanded(child: Text(item.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                              Text('$percent%', style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      },
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildRankingClientes(Color corTema) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events, color: Colors.amber[700], size: 28),
                const SizedBox(width: 8),
                Text('Top 5 Clientes VIP (Faturamento)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: corTema)),
              ],
            ),
            const SizedBox(height: 16),
            if (_topClientes.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Ainda não há clientes com pedidos concluídos neste período.', style: TextStyle(color: Colors.grey)),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _topClientes.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final cliente = _topClientes[index];
                  final bool isPrimeiro = index == 0;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: isPrimeiro ? Colors.amber : corTema.withOpacity(0.1),
                      child: Text('${index + 1}º', style: TextStyle(fontWeight: FontWeight.bold, color: isPrimeiro ? Colors.white : corTema)),
                    ),
                    title: Text(cliente['nome'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Text('${cliente['qtd_pedidos']} pedidos concluídos'),
                    trailing: Text(
                      'R\$ ${cliente['total_gasto'].toStringAsFixed(2).replaceAll('.', ',')}',
                      style: TextStyle(fontWeight: FontWeight.w900, color: Colors.green[700], fontSize: 16),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaixaAvisos(Color corTema) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fique de Olho 👀', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: corTema)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber)),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Você tem $_pedidosPendentes pedidos aguardando ou em preparo na cozinha. Não deixe atrasar!', style: const TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue)),
              child: const Row(
                children: [
                  Icon(Icons.trending_up, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(child: Text('Dica: Clientes VIP costumam gostar de mimos! Que tal mandar um cupom de desconto no WhatsApp deles?', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            )
          ],
        ),
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

  _DonutChartPainter(this.dados, this.total);

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) {
      final paint = Paint()
        ..color = Colors.grey[200]!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 25;
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
        ..strokeWidth = 25;
      
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}