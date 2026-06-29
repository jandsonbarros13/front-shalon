import 'dart:async';
import 'dart:js' as js;
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'admin/dashboard_tab.dart';
import 'admin/venda.dart';
import 'admin/minhasVendas.dart';
import 'admin/produtos_tab.dart';
import 'admin/pedidos_tab.dart';
import 'admin/catalogo_tab.dart';
import 'admin/usuarios_tab.dart';
import 'admin/cadastro_frete_page.dart';
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
    'Controle de Produtos',
    'Pedidos da Loja',
    'Catálogo Digital',
    'Controle de Usuários',
    'Configuração de Frete'
  ];

  final List<Widget> _abas = [
    const DashboardTab(),
    const VendaPage(),
    const MinhasVendas(),
    const ProdutosTab(),
    const PedidosTab(),
    const CatalogoTab(),
    const UsuariosTab(),
    const CadastroFretePage(),
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
    } catch (e) {
      print("Erro na escuta global: $e");
    }
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
                setState(() => _abaSelecionada = 4);
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
                setState(() => _abaSelecionada = 4);
              },
              child: const Text('Ver Pedidos', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
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
              accountName: const Text('Açaiteria Shalom', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              accountEmail: const Text('Painel Administrativo', style: TextStyle(color: Colors.white70)),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard, color: corTema),
              title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
              selected: _abaSelecionada == 0,
              selectedTileColor: const Color(0xFFFFD700).withOpacity(0.15),
              onTap: () {
                setState(() => _abaSelecionada = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.point_of_sale, color: corTema),
              title: const Text('Vendas (PDV)', style: TextStyle(fontWeight: FontWeight.bold)),
              selected: _abaSelecionada == 1,
              selectedTileColor: const Color(0xFFFFD700).withOpacity(0.15),
              onTap: () {
                setState(() => _abaSelecionada = 1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history_toggle_off, color: corTema),
              title: const Text('Minhas Vendas', style: TextStyle(fontWeight: FontWeight.bold)),
              selected: _abaSelecionada == 2,
              selectedTileColor: const Color(0xFFFFD700).withOpacity(0.15),
              onTap: () {
                setState(() => _abaSelecionada = 2);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.icecream_outlined, color: corTema),
              title: const Text('Produtos', style: TextStyle(fontWeight: FontWeight.bold)),
              selected: _abaSelecionada == 3,
              selectedTileColor: const Color(0xFFFFD700).withOpacity(0.15),
              onTap: () {
                setState(() => _abaSelecionada = 3);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.list_alt, color: corTema),
              title: const Text('Pedidos', style: TextStyle(fontWeight: FontWeight.bold)),
              selected: _abaSelecionada == 4,
              selectedTileColor: const Color(0xFFFFD700).withOpacity(0.15),
              onTap: () {
                setState(() => _abaSelecionada = 4);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_stories, color: corTema),
              title: const Text('Catálogo', style: TextStyle(fontWeight: FontWeight.bold)),
              selected: _abaSelecionada == 5,
              selectedTileColor: const Color(0xFFFFD700).withOpacity(0.15),
              onTap: () {
                setState(() => _abaSelecionada = 5);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people, color: corTema),
              title: const Text('Usuários', style: TextStyle(fontWeight: FontWeight.bold)),
              selected: _abaSelecionada == 6,
              selectedTileColor: const Color(0xFFFFD700).withOpacity(0.15),
              onTap: () {
                setState(() => _abaSelecionada = 6);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_shipping, color: corTema),
              title: const Text('Configurar Frete', style: TextStyle(fontWeight: FontWeight.bold)),
              selected: _abaSelecionada == 7,
              selectedTileColor: const Color(0xFFFFD700).withOpacity(0.15),
              onTap: () {
                setState(() => _abaSelecionada = 7);
                Navigator.pop(context);
              },
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sair do Painel', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
            ),
            const SizedBox(height: 16),
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