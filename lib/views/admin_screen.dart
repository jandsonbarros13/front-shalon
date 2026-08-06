import 'dart:async';
import 'dart:js' as js;
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'admin/dashboard_tab.dart';
import 'admin/venda.dart';
import 'admin/minhasVendas.dart';
import 'admin/categorias_tab.dart';
import 'admin/produtos_tab.dart';
import 'admin/pedidos_tab.dart';
import 'admin/catalogo_tab.dart';
import 'admin/usuarios_tab.dart';
import 'admin/cadastro_frete_page.dart';
import 'admin/empresa_tab.dart';
import 'login_screen.dart';
import 'package:acaiteria_front/features/auth/services/pedido_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _abaSelecionada = 0;
  final _pedidoService = PedidoService();
  Timer? _timerGlobal;
  int _ultimoPedidoConhecido = 0;
  bool _isInitialLoad = true;

  final List<String> _titulos = [
    'Dashboard Shalom',
    'Ponto de Venda (PDV)',
    'Histórico de Vendas',
    'Controle de Tipos/Categorias',
    'Controle de Produtos',
    'Pedidos da Loja',
    'Catálogo Digital',
    'Controle de Usuários',
    'Configuração de Frete',
    'Dados da Empresa'
  ];

  final List<Widget> _abas = [
    const DashboardTab(),
    const VendaPage(),
    const MinhasVendas(),
    const CategoriasTab(),
    const ProdutosTab(),
    const PedidosTab(),
    const CatalogoTab(),
    const UsuariosTab(),
    const CadastroFretePage(),
    const EmpresaTab(),
  ];

  @override
  void initState() {
    super.initState();
    _solicitarPermissaoNotificacao();
    _iniciarEscutaGlobalPedidos();
  }

  @override
  void dispose() {
    _timerGlobal?.cancel();
    super.dispose();
  }

  void _solicitarPermissaoNotificacao() {
    if (html.Notification.supported && html.Notification.permission != 'granted' && html.Notification.permission != 'denied') {
      html.Notification.requestPermission();
    }
  }

  void _iniciarEscutaGlobalPedidos() {
    _verificarPedidos();
    _timerGlobal = Timer.periodic(const Duration(minutes: 5), (_) {
      _verificarPedidos();
    });
  }

  Future<void> _verificarPedidos() async {
    try {
      final resultado = await _pedidoService.listarPedidos(1);
      final pedidos = resultado['pedidos'] as List? ?? [];
      
      if (pedidos.isNotEmpty) {
        int maiorIdAtual = 0;
        int quantidadePendentes = 0;
        
        for (var p in pedidos) {
          if (p['id'] > maiorIdAtual) {
            maiorIdAtual = p['id'];
          }
          if (p['status'] == 'Pendente') {
            quantidadePendentes++;
          }
        }
        
        if (_isInitialLoad) {
          _ultimoPedidoConhecido = maiorIdAtual;
          _isInitialLoad = false;
          if (quantidadePendentes > 0) {
            _executarSomEVibracao();
            _mostrarNotificacaoPendentes(quantidadePendentes);
          }
        } else if (maiorIdAtual > _ultimoPedidoConhecido) {
          _ultimoPedidoConhecido = maiorIdAtual;
          _alertaNovoPedido(maiorIdAtual);
          _mostrarNotificacaoVisual();
        }
      }
    } catch (e) {}
  }

  void _executarSomEVibracao() {
    try {
      if (js.context.hasProperty('navigator') && js.context['navigator'].hasProperty('vibrate')) {
        js.context['navigator'].callMethod('vibrate', [js.JsArray.from([500, 200, 500, 200, 500])]);
      }
    } catch (_) {}

    try {
      final audio = html.AudioElement('https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3');
      audio.play();
      Timer(const Duration(seconds: 4), () {
        final audioRepetido = html.AudioElement('https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3');
        audioRepetido.play();
      });
    } catch (_) {}
  }

  void _alertaNovoPedido(int idPedido) {
    _executarSomEVibracao();
    if (html.Notification.supported && html.Notification.permission == 'granted') {
      html.Notification('🍇 NOVO PEDIDO: #$idPedido', body: 'Um novo pedido acabou de cair! Clique para ir para a fila de preparo.');
    }
  }

  void _mostrarNotificacaoVisual() {
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.notification_important, color: Colors.amber, size: 28),
              SizedBox(width: 8),
              Text('Novo Pedido Chegou!', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text('Um cliente acabou de enviar um pedido novo. Deseja ir para a tela de Pedidos agora?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ficar Aqui', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A0E4E), foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(context);
                setState(() => _abaSelecionada = 5);
              },
              child: const Text('Ver Pedidos', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  void _mostrarNotificacaoPendentes(int quantidade) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 28),
              SizedBox(width: 8),
              Text('Pedidos em Aberto', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text('Você tem $quantidade pedido(s) pendente(s) aguardando preparo na fila.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(context);
                setState(() => _abaSelecionada = 5);
              },
              child: const Text('Ver Pedidos', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildItemMenu(IconData icone, String titulo, int indice) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(icone, color: const Color(0xFF4A0E4E), size: 22),
      title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      selected: _abaSelecionada == indice,
      selectedTileColor: const Color(0xFFFFD700).withOpacity(0.15),
      onTap: () {
        setState(() => _abaSelecionada = indice);
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const corTema = Color(0xFF4A0E4E);

    return Scaffold(
      appBar: AppBar(
        title: Text(_titulos[_abaSelecionada], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: corTema,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: corTema),
              margin: EdgeInsets.zero,
              currentAccountPicture: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  image: const DecorationImage(
                    image: AssetImage('assets/images/logo.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              accountName: const Text('Açaiteria Shalom', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              accountEmail: const Text('Painel Administrativo', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  _buildItemMenu(Icons.dashboard, 'Dashboard', 0),
                  _buildItemMenu(Icons.point_of_sale, 'Vendas (PDV)', 1),
                  _buildItemMenu(Icons.history_toggle_off, 'Minhas Vendas', 2),
                  _buildItemMenu(Icons.category, 'Categorias / Tipos', 3),
                  _buildItemMenu(Icons.icecream_outlined, 'Produtos', 4),
                  _buildItemMenu(Icons.list_alt, 'Pedidos', 5),
                  _buildItemMenu(Icons.auto_stories, 'Catálogo', 6),
                  _buildItemMenu(Icons.people, 'Usuários', 7),
                  _buildItemMenu(Icons.local_shipping, 'Configurar Frete', 8),
                  _buildItemMenu(Icons.business, 'Empresa', 9),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              dense: true,
              leading: const Icon(Icons.logout, color: Colors.red, size: 22),
              title: const Text('Sair do Painel', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _abas[_abaSelecionada],
      ),
    );
  }
}