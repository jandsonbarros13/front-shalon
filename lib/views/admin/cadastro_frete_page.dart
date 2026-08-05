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

  final FlutterTts _flutterTts = FlutterTts();
  final GlobalKey _keyLista = GlobalKey();

  final List<String> _textosMascote = [
    "Nesta tela você controla as taxas de entrega para cada bairro de Canindé. Altere os valores no lápis ou ative/desative a entrega usando a chave verde!"
  ];

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
    const corTema = Color(0xFF4A0E4E);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Atualizar Taxa - ${bairro['bairro']}', style: const TextStyle(color: corTema, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: editarTaxaCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Valor da Entrega (R\$)', 
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700)),
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
            child: const Text('Salvar Nova Taxa', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
    const corTema = Color(0xFF4A0E4E);
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 15, spreadRadius: 3)],
          border: Border.all(color: corTema, width: 3),
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
                  decoration: BoxDecoration(color: corTema.withOpacity(0.1), shape: BoxShape.circle),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/mascote_acenando.gif',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.record_voice_over, color: corTema),
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
                    backgroundColor: corTema,
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      'assets/images/mascote_acenando.gif',
                      width: 100, height: 100, fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(Icons.sentiment_satisfied_alt, size: 80, color: corTema),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(16)),
                        child: Text(
                          "Olá! Sou o mascote da Açaiteria Shalom! 🍇\n\n"
                          "Aqui você gerencia todos os valores de entrega da loja para a cidade.\n\n"
                          "Quer fazer um Tour Guiado rápido para ver como ajustar?",
                          style: TextStyle(fontSize: 15, color: Colors.grey[800], height: 1.5, fontWeight: FontWeight.w500),
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
                          backgroundColor: corTema,
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
                        label: const Text('Sim, Iniciar Tour', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      )
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: corTema,
                          side: BorderSide(color: corTema, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Agora não', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
    const corTema = Color(0xFF4A0E4E);

    return ShowCaseWidget(
      onStart: (index, key) => _playAudioForStep(index),
      onComplete: (index, key) => _flutterTts.stop(),
      onFinish: () => _flutterTts.stop(),
      builder: (showcaseContext) {
        return Scaffold(
          body: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(Icons.map, color: corTema, size: 32),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Controle de Praças de Entrega', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: corTema)),
                                  SizedBox(height: 4),
                                  Text('Sede Operacional: Canindé / CE', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text('Tabela de Taxas de Frete no Banco', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: corTema)),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _carregando
                          ? const Center(child: CircularProgressIndicator(color: corTema))
                          : _bairros.isEmpty
                              ? const Center(child: Text('Nenhum bairro encontrado no banco de dados.'))
                              : Showcase.withWidget(
                                  key: _keyLista,
                                  container: _buildTooltipMascote(showcaseContext, _textosMascote[0], true),
                                  child: ListView.separated(
                                    itemCount: _bairros.length,
                                    separatorBuilder: (_, __) => const Divider(),
                                    itemBuilder: (context, index) {
                                      final bairro = _bairros[index];
                                      final double taxa = bairro['taxa'] != null ? double.tryParse(bairro['taxa'].toString()) ?? 0.0 : 0.0;
                                      final bool ativo = bairro['ativo'] ?? true;

                                      return ListTile(
                                        leading: Icon(
                                          Icons.delivery_dining, 
                                          color: ativo ? Colors.indigo : Colors.grey,
                                        ),
                                        title: Text(
                                          bairro['bairro'] ?? '', 
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: ativo ? Colors.black : Colors.grey,
                                            decoration: ativo ? null : TextDecoration.lineThrough,
                                          )
                                        ),
                                        subtitle: Text(
                                          ativo ? 'Taxa: R\$ ${taxa.toStringAsFixed(2)}' : 'Entrega Desativada para este Bairro',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold, 
                                            color: ativo ? corTema : Colors.red,
                                          ),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (ativo)
                                              IconButton(
                                                icon: const Icon(Icons.edit, color: corTema),
                                                onPressed: () => _abrirEditorDeTaxa(bairro),
                                              ),
                                            const SizedBox(width: 8),
                                            Switch(
                                              value: ativo,
                                              activeColor: Colors.green,
                                              inactiveThumbColor: Colors.red,
                                              onChanged: (valor) => _alternarAtivacaoBairro(bairro, valor),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
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
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 70, height: 70,
                          decoration: BoxDecoration(color: corTema, shape: BoxShape.circle),
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