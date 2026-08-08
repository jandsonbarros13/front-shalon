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
  bool _isDarkMode = true; 

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
      final cardColor = _isDarkMode ? const Color(0xFF27293D) : Colors.white;
      final textColor = _isDarkMode ? Colors.white : const Color(0xFF333333);
      final accentColor = _isDarkMode ? const Color(0xFFE040FB) : const Color(0xFF4A0E4E);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.notification_important, color: Colors.amber, size: 28),
              const SizedBox(width: 8),
              Text('Novo Pedido Chegou!', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
            ],
          ),
          content: Text('Um cliente acabou de enviar um pedido novo. Deseja ir para a tela de Pedidos agora?', style: TextStyle(color: textColor.withOpacity(0.8))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Ficar Aqui', style: TextStyle(color: textColor.withOpacity(0.6))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white),
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
      final cardColor = _isDarkMode ? const Color(0xFF27293D) : Colors.white;
      final textColor = _isDarkMode ? Colors.white : const Color(0xFF333333);
      final accentColor = _isDarkMode ? const Color(0xFFE040FB) : const Color(0xFF4A0E4E);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue, size: 28),
              const SizedBox(width: 8),
              Text('Pedidos em Aberto', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
            ],
          ),
          content: Text('Você tem $quantidade pedido(s) pendente(s) aguardando preparo na fila.', style: TextStyle(color: textColor.withOpacity(0.8))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Fechar', style: TextStyle(color: textColor.withOpacity(0.6))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white),
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

  Widget _buildItemMenu(IconData icone, String titulo, int indice, Color accentColor, Color textColor) {
    bool isSelected = _abaSelecionada == indice;
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(icone, color: isSelected ? accentColor : textColor.withOpacity(0.6), size: 22),
      title: Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? accentColor : textColor)),
      selected: isSelected,
      selectedTileColor: accentColor.withOpacity(0.15),
      onTap: () {
        setState(() => _abaSelecionada = indice);
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _isDarkMode ? const Color(0xFF1E1E2C) : const Color(0xFFF4F6F8);
    final cardColor = _isDarkMode ? const Color(0xFF27293D) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : const Color(0xFF333333);
    final accentColor = _isDarkMode ? const Color(0xFFE040FB) : const Color(0xFF4A0E4E);

    return Theme(
      data: _isDarkMode ? ThemeData.dark().copyWith(
        scaffoldBackgroundColor: bgColor,
        cardColor: cardColor,
        colorScheme: ColorScheme.dark(
          primary: accentColor,
          surface: cardColor,
          background: bgColor,
        ),
      ) : ThemeData.light().copyWith(
        scaffoldBackgroundColor: bgColor,
        cardColor: cardColor,
        colorScheme: ColorScheme.light(
          primary: accentColor,
          surface: cardColor,
          background: bgColor,
        ),
      ),
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].contains(_abaSelecionada)
            ? null 
            : AppBar(
                title: Text(_titulos[_abaSelecionada], style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                backgroundColor: cardColor,
                centerTitle: true,
                elevation: 1,
                iconTheme: IconThemeData(color: textColor),
                actions: [
                  IconButton(
                    icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode, color: textColor),
                    tooltip: 'Alternar Tema',
                    onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
                  ),
                ],
              ),
        drawer: Drawer(
          backgroundColor: cardColor,
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: BoxDecoration(color: cardColor),
                margin: EdgeInsets.zero,
                currentAccountPicture: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: accentColor, width: 2),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/logo.jpg'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                accountName: Text('Açaiteria Shalom', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                accountEmail: Text('Painel Administrativo', style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 12)),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: [
                    _buildItemMenu(Icons.dashboard, 'Dashboard', 0, accentColor, textColor),
                    _buildItemMenu(Icons.point_of_sale, 'Vendas (PDV)', 1, accentColor, textColor),
                    _buildItemMenu(Icons.history_toggle_off, 'Histórico de Vendas', 2, accentColor, textColor),
                    _buildItemMenu(Icons.category, 'Controle de Tipos/Categorias', 3, accentColor, textColor),
                    _buildItemMenu(Icons.icecream_outlined, 'Controle de Produtos', 4, accentColor, textColor),
                    _buildItemMenu(Icons.list_alt, 'Pedidos da Loja', 5, accentColor, textColor),
                    _buildItemMenu(Icons.auto_stories, 'Catálogo Digital', 6, accentColor, textColor),
                    _buildItemMenu(Icons.people, 'Controle de Usuários', 7, accentColor, textColor),
                    _buildItemMenu(Icons.local_shipping, 'Configuração de Frete', 8, accentColor, textColor),
                    _buildItemMenu(Icons.business, 'Dados da Empresa', 9, accentColor, textColor),
                  ],
                ),
              ),
              Divider(height: 1, color: textColor.withOpacity(0.1)),
              ListTile(
                dense: true,
                leading: const Icon(Icons.logout, color: Colors.redAccent, size: 22),
                title: const Text('Sair do Painel', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
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
      ),
    );
  }
}