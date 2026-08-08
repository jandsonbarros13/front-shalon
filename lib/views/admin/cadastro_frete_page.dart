import 'package:flutter/material.dart';
import 'package:acaiteria_front/features/auth/services/frete_service.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:showcaseview/showcaseview.dart';

class CadastroFretePage extends StatefulWidget {
  const CadastroFretePage({super.key});

  @override
  State<CadastroFretePage> createState() => _CadastroFretePageState();
}

class _CadastroFretePageState extends State<CadastroFretePage> {
  final _freteService = FreteService();
  bool _carregando = true;
  List<dynamic> _bairros = [];
  bool _isDarkMode = true;

  final FlutterTts _flutterTts = FlutterTts();
  final GlobalKey _keyLista = GlobalKey();

  final List<String> _textosMascote = [
    "Nesta tela você controla as taxas de entrega para cada bairro de Canindé. Altere os valores no lápis ou ative/desative a entrega usando a chave verde!"
  ];

  bool get isDark => _isDarkMode;
  Color get accentColor => isDark ? const Color(0xFFE040FB) : const Color(0xFF4A0E4E);
  Color get bgColor => isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF4F6F8);
  Color get cardColor => isDark ? const Color(0xFF27293D) : Colors.white;
  Color get textColor => isDark ? Colors.white : Colors.black87;
  Color get textSecColor => isDark ? Colors.white54 : Colors.grey[600]!;

  @override
  void initState() {
    super.initState();
    _flutterTts.setLanguage("pt-BR");
    _buscarDadosDoBanco();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _buscarDadosDoBanco() async {
    setState(() => _carregando = true);
    final dados = await _freteService.listarFretesDoBanco();
    if (mounted) {
      setState(() {
        _bairros = dados;
        _carregando = false;
      });
    }
  }

  void _abrirEditorDeTaxa(Map<String, dynamic> bairro) {
    final editarTaxaCtrl = TextEditingController(text: (bairro['taxa'] ?? 0.0).toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Atualizar Taxa - ${bairro['bairro']}', style: TextStyle(color: accentColor, fontWeight: FontWeight.w900)),
        content: TextField(
          controller: editarTaxaCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            labelText: 'Valor da Entrega (R\$)', 
            labelStyle: TextStyle(color: textSecColor),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!), borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: accentColor, width: 2), borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
            ),
            onPressed: () async {
              if (editarTaxaCtrl.text.isNotEmpty) {
                final double novaTaxa = double.tryParse(editarTaxaCtrl.text.replaceAll(',', '.')) ?? 0.0;
                final int id = bairro['id'];
                final bool statusAtual = bairro['ativo'] ?? true;

                final sucesso = await _freteService.atualizarStatusETaxaDoBairro(id, novaTaxa, statusAtual);
                if (sucesso) {
                  Navigator.pop(context);
                  _buscarDadosDoBanco();
                }
              }
            },
            child: const Text('Salvar Nova Taxa', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _alternarAtivacaoBairro(Map<String, dynamic> bairro, bool novoStatus) async {
    final int id = bairro['id'];
    final double taxaAtual = double.tryParse(bairro['taxa'].toString()) ?? 0.0;

    final sucesso = await _freteService.atualizarStatusETaxaDoBairro(id, taxaAtual, novoStatus);
    if (sucesso) {
      _buscarDadosDoBanco();
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
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 15, spreadRadius: 3)],
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
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor, height: 1.4),
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
                  label: const Text('Parar Tour', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
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
                  label: Text(isLast ? 'Concluir' : 'Próximo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      'assets/images/mascote_acenando.gif',
                      width: 100, height: 100, fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(Icons.sentiment_satisfied_alt, size: 80, color: accentColor),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E2C) : Colors.grey[100], borderRadius: BorderRadius.circular(16)),
                        child: Text(
                          "Olá! Sou o mascote da Açaiteria Shalom! 🍇\n\n"
                          "Aqui você gerencia todos os valores de entrega da loja para a cidade.\n\n"
                          "Quer fazer um Tour Guiado rápido para ver como ajustar?",
                          style: TextStyle(fontSize: 14, color: textSecColor, height: 1.5, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          ShowCaseWidget.of(showcaseContext).startShowCase([
                            _keyLista,
                          ]);
                        },
                        icon: const Icon(Icons.slideshow, size: 24),
                        label: const Text('Sim, Iniciar Tour', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      )
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textColor,
                          side: BorderSide(color: textSecColor, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Agora não', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      )
                    ),
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
                    'CONFIGURAÇÃO DE FRETE', 
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: textColor),
                tooltip: 'Alternar Tema',
                onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: accentColor.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.local_shipping, color: accentColor, size: 16),
                    const SizedBox(width: 8),
                    Text('${_bairros.length} BAIRROS', style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ],
                ),
              )
            ],
          ),
          body: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      color: cardColor,
                      elevation: isDark ? 4 : 2,
                      shadowColor: Colors.black.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: isDark ? Colors.white10 : Colors.transparent),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(Icons.map, color: accentColor, size: 32),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Controle de Praças de Entrega', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: accentColor)),
                                  const SizedBox(height: 4),
                                  Text('Sede Operacional: Canindé / CE', style: TextStyle(color: textSecColor, fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text('Tabela de Taxas de Frete no Banco', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _carregando
                          ? Center(child: CircularProgressIndicator(color: accentColor))
                          : _bairros.isEmpty
                              ? Center(child: Text('Nenhum bairro encontrado no banco de dados.', style: TextStyle(color: textSecColor)))
                              : Showcase.withWidget(
                                  key: _keyLista,
                                  container: _buildTooltipMascote(showcaseContext, _textosMascote[0], true),
                                  child: Card(
                                    color: cardColor,
                                    elevation: isDark ? 4 : 2,
                                    shadowColor: Colors.black.withOpacity(0.1),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(color: isDark ? Colors.white10 : Colors.transparent),
                                    ),
                                    child: ListView.separated(
                                      itemCount: _bairros.length,
                                      separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
                                      itemBuilder: (context, index) {
                                        final bairro = _bairros[index];
                                        final double taxa = bairro['taxa'] != null ? double.tryParse(bairro['taxa'].toString()) ?? 0.0 : 0.0;
                                        final bool ativo = bairro['ativo'] ?? true;

                                        return ListTile(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                          leading: Container(
                                            width: 48, height: 48,
                                            decoration: BoxDecoration(
                                              color: (ativo ? Colors.indigo : Colors.grey).withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(12)
                                            ),
                                            child: Icon(
                                              Icons.delivery_dining, 
                                              color: ativo ? Colors.indigoAccent : Colors.grey,
                                            ),
                                          ),
                                          title: Text(
                                            bairro['bairro'] ?? '', 
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: ativo ? textColor : textSecColor,
                                              decoration: ativo ? null : TextDecoration.lineThrough,
                                            )
                                          ),
                                          subtitle: Padding(
                                            padding: const EdgeInsets.only(top: 6.0),
                                            child: Text(
                                              ativo ? 'Taxa: R\$ ${taxa.toStringAsFixed(2).replaceAll('.', ',')}' : 'Entrega Desativada para este Bairro',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold, 
                                                fontSize: 13,
                                                color: ativo ? accentColor : Colors.redAccent,
                                              ),
                                            ),
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (ativo)
                                                IconButton(
                                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                                  tooltip: 'Editar Taxa',
                                                  onPressed: () => _abrirEditorDeTaxa(bairro),
                                                ),
                                              const SizedBox(width: 8),
                                              Switch(
                                                value: ativo,
                                                activeColor: Colors.green,
                                                inactiveThumbColor: Colors.redAccent,
                                                inactiveTrackColor: Colors.redAccent.withOpacity(0.3),
                                                onChanged: (valor) => _alternarAtivacaoBairro(bairro, valor),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                    ),
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
                          color: accentColor.withOpacity(0.3),
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
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 70, height: 70,
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
      }
    );
  }
}