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
  
  // Lista para o Ranking de Clientes
  List<Map<String, dynamic>> _topClientes = [];

  @override
  void initState() {
    super.initState();
    _carregarMetricas();
  }

  Future<void> _carregarMetricas() async {
    setState(() => _isLoading = true);
    
    try {
      final pedidos = await _pedidoService.listarPedidos();
      
      double faturamentoCalc = 0.0;
      int pendentesCalc = 0;
      int concluidosCalc = 0;
      
      // Mapeando gastos por cliente (Nome + Telefone como chave para não misturar homônimos)
      Map<String, Map<String, dynamic>> clientesMap = {};

      for (var p in pedidos) {
        final status = (p['status'] ?? '').toString();
        final double valor = double.tryParse(p['valor_total'].toString()) ?? 0.0;
        final clienteNome = p['cliente_nome'] ?? 'Desconhecido';
        final clienteTel = p['cliente_telefone'] ?? '';
        final chaveCliente = '$clienteNome-$clienteTel';

        if (status != 'Cancelado') {
          // Status da Loja
          if (status == 'Concluído') {
            faturamentoCalc += valor;
            concluidosCalc++;
          } else {
            pendentesCalc++;
          }

          // Agrupando para o Ranking
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
        }
      }

      // Calculando Ticket Médio
      double ticketCalc = concluidosCalc > 0 ? (faturamentoCalc / concluidosCalc) : 0.0;

      // Ordenando os clientes do que gastou mais para o que gastou menos
      List<Map<String, dynamic>> listaClientes = clientesMap.values.toList();
      listaClientes.sort((a, b) => b['total_gasto'].compareTo(a['total_gasto']));

      setState(() {
        _faturamentoTotal = faturamentoCalc;
        _pedidosPendentes = pendentesCalc;
        _totalPedidosValidos = concluidosCalc + pendentesCalc;
        _ticketMedio = ticketCalc;
        _topClientes = listaClientes.take(5).toList(); // Pega apenas os Top 5
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

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: corTema));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Visão Estratégica (BI)', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: corTema)),
              IconButton(
                icon: const Icon(Icons.refresh),
                color: corTema,
                tooltip: 'Atualizar Dados',
                onPressed: _carregarMetricas,
              )
            ],
          ),
          const SizedBox(height: 24),
          
          // Cards de Resumo
          GridView.count(
            crossAxisCount: largura > 1200 ? 4 : (largura > 700 ? 2 : 1),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: largura > 1200 ? 2.0 : 2.5,
            children: [
              _buildCard('Faturamento', 'R\$ ${_faturamentoTotal.toStringAsFixed(2).replaceAll('.', ',')}', Icons.monetization_on, Colors.green),
              _buildCard('Fila de Preparo', '$_pedidosPendentes', Icons.hourglass_empty, Colors.amber[700]!),
              _buildCard('Ticket Médio', 'R\$ ${_ticketMedio.toStringAsFixed(2).replaceAll('.', ',')}', Icons.receipt_long, Colors.purple),
              _buildCard('Total de Pedidos', '$_totalPedidosValidos', Icons.shopping_bag, Colors.blue),
            ],
          ),

          const SizedBox(height: 32),

          // Área Inferior dividida em duas colunas (Ranking e Gráfico Vazio)
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
        ],
      ),
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
                child: Text('Ainda não há clientes com pedidos concluídos.', style: TextStyle(color: Colors.grey)),
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
                    subtitle: Text('${cliente['qtd_pedidos']} pedidos realizados'),
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