import 'package:flutter/material.dart';
import 'package:acaiteria_front/features/auth/services/catalogo_service.dart';
import 'package:url_launcher/url_launcher.dart';
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

  @override
  void initState() {
    super.initState();
    _carregarCatalogos();
  }

  Future<void> _carregarCatalogos() async {
    setState(() => _loading = true);
    final lista = await _catalogoService.listarCatalogos();
    setState(() {
      _catalogos = lista;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final String urlBase = Uri.base.origin;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
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
      body: Padding(
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
                      : ListView.builder(
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
          ],
        ),
      ),
    );
  }
}