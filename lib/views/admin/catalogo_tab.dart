import 'package:flutter/material.dart';
import 'package:acaiteria_front/features/auth/services/catalogo_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:showcaseview/showcaseview.dart';
import 'form_catalogo_page.dart';

class CatalogoTab extends StatefulWidget {
  const CatalogoTab({super.key});

  @override
  State<CatalogoTab> createState() => _CatalogoTabState();
}

class _CatalogoTabState extends State<CatalogoTab> {
  final _catalogoService = CatalogoService();
  List<dynamic> _catalogos = [];
  bool _loading = true;

  final FlutterTts _flutterTts = FlutterTts();
  final GlobalKey _keyNovo = GlobalKey();
  final GlobalKey _keyLista = GlobalKey();

  final List<String> _textosMascote = [
    "Bem-vindo ao Gerenciador de Catálogos! Aqui ficam todos os seus cardápios online. Você pode criar um link diferente para o Instagram e outro para o WhatsApp, por exemplo!",
    "Para criar um novo catálogo totalmente personalizado, basta clicar neste botão amarelo."
  ];

  @override
  void initState() {
    super.initState();
    _flutterTts.setLanguage("pt-BR");
    _carregarCatalogos();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _carregarCatalogos() async {
    setState(() => _loading = true);
    final lista = await _catalogoService.listarCatalogos();
    setState(() {
      _catalogos = lista;
      _loading = false;
    });
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
                          "Esta é a tela de Catálogos Digitais. Aqui você pode ter vários cardápios diferentes rodando ao mesmo tempo.\n\n"
                          "Quer fazer um Tour Guiado para ver como funciona?",
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
                            _keyNovo,
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
    final String urlBase = Uri.base.origin;
    const corTema = Color(0xFF4A0E4E);

    return ShowCaseWidget(
      onStart: (index, key) => _playAudioForStep(index),
      onComplete: (index, key) => _flutterTts.stop(),
      onFinish: () => _flutterTts.stop(),
      builder: (showcaseContext) {
        return Scaffold(
          floatingActionButton: Showcase.withWidget(
            key: _keyNovo,
            container: _buildTooltipMascote(showcaseContext, _textosMascote[1], true),
            child: FloatingActionButton.extended(
              backgroundColor: const Color(0xFFFFD700),
              onPressed: () async {
                final atualizou = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FormCatalogoPage()),
                );
                if (atualizou == true) _carregarCatalogos();
              },
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text('CRIAR NOVO CATÁLOGO', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ),
          body: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Gerenciador de Catálogos Digitais', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF4A0E4E))),
                    const Text('Crie e controle múltiplos cardápios online independentes', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 24),
                    Expanded(
                      child: _loading
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A0E4E)))
                          : _catalogos.isEmpty
                              ? const Center(child: Text('Nenhum catálogo digital criado ainda.'))
                              : Showcase.withWidget(
                                  key: _keyLista,
                                  container: _buildTooltipMascote(showcaseContext, _textosMascote[0], false),
                                  child: ListView.builder(
                                    itemCount: _catalogos.length,
                                    itemBuilder: (context, index) {
                                      final cat = _catalogos[index];
                                      final url = "$urlBase/#/catalogo/${cat['chave']}";

                                      return Card(
                                        margin: const EdgeInsets.symmetric(vertical: 8),
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        child: ListTile(
                                          leading: const Icon(Icons.menu_book, color: Color(0xFF4A0E4E), size: 32),
                                          title: Text(cat['titulo'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                          subtitle: InkWell(
                                            onTap: () async {
                                              final uri = Uri.parse(url);
                                              if (await canLaunchUrl(uri)) {
                                                await launchUrl(uri, webOnlyWindowName: '_blank');
                                              }
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.only(top: 4.0),
                                              child: Text(
                                                url,
                                                style: const TextStyle(
                                                  color: Colors.blue, 
                                                  fontWeight: FontWeight.bold,
                                                  decoration: TextDecoration.underline,
                                                ),
                                              ),
                                            ),
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit, color: Colors.blue),
                                                onPressed: () async {
                                                  final atualizou = await Navigator.push(
                                                    context,
                                                    MaterialPageRoute(builder: (context) => FormCatalogoPage(catalogoParaEditar: cat)),
                                                  );
                                                  if (atualizou == true) _carregarCatalogos();
                                                },
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete, color: Colors.red),
                                                onPressed: () async {
                                                  await _catalogoService.deletarCatalogo(cat['id'] ?? cat['ID']);
                                                  _carregarCatalogos();
                                                },
                                              ),
                                            ],
                                          ),
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
                bottom: 100, 
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
                          decoration: const BoxDecoration(color: corTema, shape: BoxShape.circle),
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