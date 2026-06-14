import 'package:flutter/material.dart';
import 'package:acaiteria_front/features/auth/services/pedido_service.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final _pedidoService = PedidoService();
  
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

  @override
  void initState() {
    super.initState();
    final agora = DateTime.now();
    _dataInicioQuery = _formatarData(agora);
    _dataFimQuery = _formatarData(agora);
    _carregarMetricas();
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
    final PickerDateRange? picked = await showDialog<PickerDateRange>(
      context: context,
      builder: (context) {
        DateTime? inicio;
        DateTime? fim;
        return AlertDialog(
          title: const Text('Selecionar Período', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: corTema, foregroundColor: Colors.white),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (d != null) inicio = d;
                },
                icon: const Icon(Icons.date_range),
                label: const Text('Data Inicial'),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: corTema, foregroundColor: Colors.white),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (d != null) fim = d;
                },
                icon: const Icon(Icons.date_range),
                label: const Text('Data Final'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            TextButton(
              onPressed: () {
                if (inicio != null && fim != null) {
                  Navigator.pop(context, PickerDateRange(inicio!, fim!));
                }
              },
              child: const Text('Filtrar', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        );
      }
    );

    if (picked != null) {
      setState(() {
        _filtroSelecionado = 'Personalizado';
        _dataInicioQuery = _formatarData(picked.inicio);
        _dataFimQuery = _formatarData(picked.fim);
      });
      _carregarMetricas();
    }
  }

  Future<void> _carregarMetricas() async {
    setState(() => _isLoading = true);
    
    try {
      final resultado = await _pedidoService.listarPedidos(1, dataInicio: _dataInicioQuery, dataFim: _dataFimQuery, limit: 0);
      final pedidos = resultado['pedidos'] as List? ?? [];
      
      double faturamentoCalc = 0.0;
      int pendentesCalc = 0;
      int concluidosCalc = 0;
      
      int pix = 0, cartao = 0, dinheiro = 0;
      int entrega = 0, retirada = 0;

      Map<String, Map<String, dynamic>> clientesMap = {};

      for (var p in pedidos) {
        final status = (p['status'] ?? '').toString();
        final double valor = double.tryParse(p['valor_total'].toString()) ?? 0.0;
        final clienteNome = p['cliente_nome'] ?? 'Desconhecido';
        final clienteTel = p['cliente_telefone'] ?? '';
        final chaveCliente = '$clienteNome-$clienteTel';
        final formaPgto = (p['forma_pagamento'] ?? '').toString().toLowerCase();
        final tipoEnvio = (p['tipo_entrega'] ?? '').toString().toLowerCase();

        if (status != 'Cancelado') {
          if (status == 'Concluído') {
            faturamentoCalc += valor;
            concluidosCalc++;

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
          } else {
            pendentesCalc++;
          }

          if (formaPgto.contains('pix')) {
            pix++;
          } else if (formaPgto.contains('cart')) {
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

      double ticketCalc = concluidosCalc > 0 ? (faturamentoCalc / concluidosCalc) : 0.0;

      List<Map<String, dynamic>> listaClientes = clientesMap.values.toList();
      listaClientes.sort((a, b) => b['total_gasto'].compareTo(a['total_gasto']));

      setState(() {
        _faturamentoTotal = faturamentoCalc;
        _pedidosPendentes = pendentesCalc;
        _totalPedidosValidos = concluidosCalc + pendentesCalc;
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

  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.of(context).size.width;
    final corTema = const Color(0xFF4A0E4E);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
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
          
          Card(
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
          const SizedBox(height: 24),
          
          if (_isLoading)
            SizedBox(height: 400, child: Center(child: CircularProgressIndicator(color: corTema)))
          else ...[
            GridView.count(
              crossAxisCount: largura > 1200 ? 4 : (largura > 700 ? 2 : 1),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: largura > 1200 ? 2.0 : 2.5,
              children: [
                _buildCard('Faturamento (Concluídos)', 'R\$ ${_faturamentoTotal.toStringAsFixed(2).replaceAll('.', ',')}', Icons.monetization_on, Colors.green),
                _buildCard('Fila de Preparo', '$_pedidosPendentes', Icons.hourglass_empty, Colors.amber[700]!),
                _buildCard('Ticket Médio', 'R\$ ${_ticketMedio.toStringAsFixed(2).replaceAll('.', ',')}', Icons.receipt_long, Colors.purple),
                _buildCard('Total de Pedidos', '$_totalPedidosValidos', Icons.shopping_bag, Colors.blue),
              ],
            ),
            const SizedBox(height: 28),

            GridView.count(
              crossAxisCount: largura > 1100 ? 3 : 1,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: largura > 1100 ? 1.4 : 2.2,
              children: [
                _buildGraficoBarras('Formas de Pagamento', [
                  _BarData('Pix', _qtdPix, Colors.teal),
                  _BarData('Cartão', _qtdCartao, Colors.indigo),
                  _BarData('Dinheiro', _qtdDinheiro, Colors.blueGrey),
                ]),
                _buildGraficoBarras('Canais de Distribuição', [
                  _BarData('🛵 Entrega', _qtdEntrega, Colors.purple),
                  _BarData('🏪 Retirada', _qtdRetirada, Colors.orange),
                ]),
                _buildGraficoBarras('Eficiência Operacional', [
                  _BarData('✅ Concluídos', _qtdConcluidos, Colors.green),
                  _BarData('⏳ Na Fila', _pedidosPendentes, Colors.amber),
                ]),
              ],
            ),
            const SizedBox(height: 28),
            largura > 900 
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildRankingClientes(corTema)),
                    const SizedBox(width: 24),
                    Expanded(flex: 2, child: _buildCaixaAvisos(corTema)),
                  ],
                )
              : Column(
                  children: [
                    _buildRankingClientes(corTema),
                    const SizedBox(height: 24),
                    _buildCaixaAvisos(corTema),
                  ],
                )
          ]
        ],
      ),
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

  Widget _buildGraficoBarras(String titulo, List<_BarData> dados) {
    int maxValor = 0;
    for (var d in dados) {
      if (d.valor > maxValor) maxValor = d.valor;
    }
    if (maxValor == 0) maxValor = 1;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF4A0E4E))),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: dados.length,
                itemBuilder: (context, idx) {
                  final item = dados[idx];
                  double percentual = item.valor / maxValor;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(item.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('${item.valor} ped.', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Stack(
                          children: [
                            Container(
                              height: 12,
                              width: double.infinity,
                              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(6)),
                            ),
                            FractionallySizedBox(
                              widthFactor: percentual,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 500),
                                height: 12,
                                decoration: BoxDecoration(
                                  color: item.cor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            )
                          ],
                        )
                      ],
                    ),
                  );
                },
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
                Text('Top 5 Clientes VIP', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: corTema)),
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

class PickerDateRange {
  final DateTime inicio;
  final DateTime fim;
  PickerDateRange(this.inicio, this.fim);
}