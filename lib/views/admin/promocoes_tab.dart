import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:acaiteria_front/core/constants/api_constants.dart';
import 'package:acaiteria_front/features/auth/services/imgbb_service.dart';
import 'package:acaiteria_front/features/auth/services/produto_service.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:showcaseview/showcaseview.dart';

class PromocoesTab extends StatefulWidget {
  const PromocoesTab({super.key});

  @override
  State<PromocoesTab> createState() => _PromocoesTabState();
}

class _PromocoesTabState extends State<PromocoesTab> {
  List<dynamic> _promocoes = [];
  List<dynamic> _catalogos = [];
  bool _isLoading = true;
  bool _isDarkMode = true;
  final ProdutoService _produtoService = ProdutoService();

  final FlutterTts _flutterTts = FlutterTts();
  final GlobalKey _keyNovo = GlobalKey();
  final GlobalKey _keyLista = GlobalKey();

  final List<String> _textosMascote = [
    "Aqui é a central das promoções! Você cria banners incríveis que chamam a atenção do cliente assim que ele abre o cardápio.",
    "Para criar um novo banner promocional, clique aqui!"
  ];

  Color get accentColor => const Color(0xFFE040FB);
  Color get bgColor => _isDarkMode ? const Color(0xFF1E1E2C) : const Color(0xFFF4F6F8);
  Color get cardColor => _isDarkMode ? const Color(0xFF27293D) : Colors.white;
  Color get textColor => _isDarkMode ? Colors.white : Colors.black87;
  Color get textSecColor => _isDarkMode ? Colors.white54 : Colors.grey[600]!;

  @override
  void initState() {
    super.initState();
    _flutterTts.setLanguage("pt-BR");
    _carregarDados();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
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
                  child: Text(texto, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor, height: 1.4)),
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
            ),
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
                        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
                        child: Text(
                          "Olá! Sou o mascote da Açaiteria Shalom! 🍇\n\n"
                          "Aqui é onde criamos as Promoções e Banners do aplicativo.\n\n"
                          "Quer fazer um rápido Tour Guiado?",
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
                          ShowCaseWidget.of(showcaseContext).startShowCase([_keyLista, _keyNovo]);
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

  String get _baseUrl {
    String url = ApiConstants.baseUrl.trim();
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    if (url.endsWith('/api')) url = url.substring(0, url.length - 4);
    return url;
  }

  String _formatarDataDisplay(DateTime? d) {
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _formatarDataAPI(DateTime? d) {
    if (d == null) return '';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _carregarDados() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final resCat = await http.get(Uri.parse('$_baseUrl/api/catalogo'));
      if (resCat.statusCode == 200) {
        _catalogos = jsonDecode(resCat.body);
      }
      
      final resPromo = await http.get(Uri.parse('$_baseUrl/api/promocoes'));
      if (resPromo.statusCode == 200) {
        _promocoes = jsonDecode(resPromo.body);
      }
    } catch (e) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _salvarPromocao(Map<String, dynamic> promocao, BuildContext modalContext, {int? id}) async {
    try {
      http.Response response;
      if (id == null) {
        response = await http.post(
          Uri.parse('$_baseUrl/api/promocoes'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(promocao),
        );
      } else {
        response = await http.put(
          Uri.parse('$_baseUrl/api/promocoes/$id'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(promocao),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        _carregarDados();
        if (Navigator.canPop(modalContext)) {
          Navigator.pop(modalContext);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Promoção salva com sucesso!'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao salvar promoção no servidor.'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro de conexão ao salvar promoção.'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _excluirPromocao(int id) async {
    try {
      final response = await http.delete(Uri.parse('$_baseUrl/api/promocoes/$id'));
      if (response.statusCode == 200) {
        _carregarDados();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Promoção excluída!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {}
  }

  Future<void> _alternarStatus(int id, Map<String, dynamic> promocao, bool novoStatus) async {
    promocao['ativa'] = novoStatus;
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/api/promocoes/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(promocao),
      );
      if (response.statusCode == 200) {
        _carregarDados();
      }
    } catch (e) {}
  }

  void _abrirFormulario({Map<String, dynamic>? promocao}) {
    final tituloController = TextEditingController(text: promocao?['titulo'] ?? '');
    final descController = TextEditingController(text: promocao?['descricao'] ?? '');
    final buscaProdutoController = TextEditingController();
    final descontoGeralController = TextEditingController(); 
    
    final ScrollController scrollListaBusca = ScrollController();
    
    bool isAtiva = promocao?['ativa'] ?? false;
    String imagemUrl = promocao?['imagem_url'] ?? '';
    bool isUploadingImage = false;
    bool isSearchingProducts = false;
    bool isSavingData = false; 
    List<dynamic> resultadosBusca = [];
    
    List<int> catalogosSelecionados = [];
    if (promocao != null && promocao['catalogos_ids'] != null) {
      catalogosSelecionados = List<int>.from(promocao['catalogos_ids']);
    }
    
    Map<int, Map<String, dynamic>> produtosSelecionados = {};
    Map<int, TextEditingController> precosControllers = {};
    Map<int, TextEditingController> descontosControllers = {};

    if (promocao != null && promocao['produtos'] != null) {
      for (var p in promocao['produtos']) {
        int pId = p['produto_id'] ?? p['id'];
        double precoOrig = double.tryParse((p['preco_original'] ?? 0).toString()) ?? 0.0;
        double precoPromo = double.tryParse((p['preco_promocional'] ?? 0).toString()) ?? 0.0;
        double percentual = double.tryParse((p['percentual_desconto'] ?? 0).toString()) ?? 0.0;

        if (percentual == 0.0 && precoOrig > 0 && precoPromo > 0) {
          percentual = ((precoOrig - precoPromo) / precoOrig) * 100;
        }

        produtosSelecionados[pId] = {
          'id': pId,
          'nome': p['nome_produto'] ?? p['nome'] ?? '',
          'preco_original': precoOrig,
          'imagem_url': p['imagem_url'] ?? '',
        };
        precosControllers[pId] = TextEditingController(text: precoPromo.toStringAsFixed(2));
        descontosControllers[pId] = TextEditingController(text: percentual.toStringAsFixed(0));
      }
    }

    DateTime? dataInicio;
    if (promocao?['data_inicio'] != null && promocao!['data_inicio'].toString().isNotEmpty) {
      dataInicio = DateTime.tryParse(promocao['data_inicio']);
    }

    DateTime? dataFim;
    if (promocao?['data_fim'] != null && promocao!['data_fim'].toString().isNotEmpty) {
      dataFim = DateTime.tryParse(promocao['data_fim']);
    }

    showDialog(
      context: context,
      useSafeArea: false, 
      builder: (BuildContext modalContext) {
        final screenWidth = MediaQuery.of(modalContext).size.width;
        final bool isMobile = screenWidth < 800;

        return StatefulBuilder(
          builder: (context, setStateModal) {

            void scrollVerticalBusca(double offset) {
              if (scrollListaBusca.hasClients) {
                final target = scrollListaBusca.offset + offset;
                scrollListaBusca.animateTo(
                  target.clamp(0.0, scrollListaBusca.position.maxScrollExtent),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            }

            Future<void> escolherFoto() async {
              final picker = ImagePicker();
              final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
              
              if (pickedFile != null) {
                setStateModal(() => isUploadingImage = true); 
                try {
                  final bytes = await pickedFile.readAsBytes();
                  final rawBase64 = base64Encode(bytes); 
                  final urlHospedada = await ImgbbService.uploadImage(rawBase64);
                  if (urlHospedada != null) {
                    setStateModal(() => imagemUrl = urlHospedada);
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falha ao subir imagem.'), backgroundColor: Colors.red));
                } finally {
                  setStateModal(() => isUploadingImage = false); 
                }
              }
            }

            Future<void> pesquisarProdutos() async {
              setStateModal(() => isSearchingProducts = true);
              try {
                final result = await _produtoService.buscarProdutos(1, nome: buscaProdutoController.text.trim(), limit: 50);
                setStateModal(() {
                  resultadosBusca = result['produtos'] ?? [];
                  resultadosBusca.removeWhere((e) => produtosSelecionados.containsKey(e['id'] ?? e['ID']));
                  isSearchingProducts = false;
                });
              } catch (e) {
                setStateModal(() => isSearchingProducts = false);
              }
            }

            void adicionarProduto(dynamic prod) {
              int id = prod['id'] ?? prod['ID'];
              if (!produtosSelecionados.containsKey(id)) {
                setStateModal(() {
                  double precoOrig = double.tryParse((prod['price'] ?? prod['Price'] ?? 0).toString()) ?? 0.0;
                  produtosSelecionados[id] = {
                    'id': id,
                    'nome': prod['name'] ?? prod['Name'] ?? '',
                    'preco_original': precoOrig,
                    'imagem_url': prod['image_url'] ?? prod['ImageURL'] ?? '',
                  };
                  precosControllers[id] = TextEditingController(text: precoOrig.toStringAsFixed(2));
                  descontosControllers[id] = TextEditingController(text: '0');
                  resultadosBusca.removeWhere((e) => (e['id'] ?? e['ID']) == id);
                });
              }
            }

            void adicionarTodosOsProdutos() {
              setStateModal(() {
                for (var prod in resultadosBusca) {
                  int id = prod['id'] ?? prod['ID'];
                  if (!produtosSelecionados.containsKey(id)) {
                    double precoOrig = double.tryParse((prod['price'] ?? prod['Price'] ?? 0).toString()) ?? 0.0;
                    produtosSelecionados[id] = {
                      'id': id,
                      'nome': prod['name'] ?? prod['Name'] ?? '',
                      'preco_original': precoOrig,
                      'imagem_url': prod['image_url'] ?? prod['ImageURL'] ?? '',
                    };
                    precosControllers[id] = TextEditingController(text: precoOrig.toStringAsFixed(2));
                    descontosControllers[id] = TextEditingController(text: '0');
                  }
                }
                resultadosBusca.clear();
              });
            }

            void aplicarDescontoMassa() {
              double percentual = double.tryParse(descontoGeralController.text.replaceAll(',', '.')) ?? 0.0;
              if (percentual > 0) {
                setStateModal(() {
                  produtosSelecionados.forEach((key, item) {
                    double pOrig = item['preco_original'];
                    double pNovo = pOrig - (pOrig * (percentual / 100));
                    precosControllers[key]!.text = pNovo.toStringAsFixed(2);
                    descontosControllers[key]!.text = percentual.toStringAsFixed(0);
                  });
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Desconto de $percentual% aplicado a todos!'), backgroundColor: Colors.green),
                );
                descontoGeralController.clear();
              }
            }

            void removerProduto(int id) {
              setStateModal(() {
                produtosSelecionados.remove(id);
                precosControllers.remove(id);
                descontosControllers.remove(id);
              });
            }

            return Dialog(
              backgroundColor: cardColor,
              insetPadding: isMobile ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              shape: isMobile ? const RoundedRectangleBorder(borderRadius: BorderRadius.zero) : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: _isDarkMode ? Colors.white10 : Colors.transparent)),
              child: SizedBox(
                width: isMobile ? double.infinity : 800,
                height: isMobile ? double.infinity : MediaQuery.of(context).size.height * 0.85,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: _isDarkMode ? Colors.white10 : Colors.grey[200]!)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(promocao == null ? 'NOVA PROMOÇÃO' : 'EDITAR PROMOÇÃO', style: TextStyle(color: accentColor, fontWeight: FontWeight.w900, fontSize: 18)),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(modalContext), color: textSecColor),
                        ],
                      ),
                    ),
                    
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: tituloController,
                              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                labelText: 'Título da Promoção', 
                                labelStyle: TextStyle(color: textSecColor),
                                filled: true,
                                fillColor: bgColor,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                prefixIcon: Icon(Icons.campaign, color: accentColor),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: descController,
                              maxLines: 2,
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                labelText: 'Descrição / Detalhes', 
                                labelStyle: TextStyle(color: textSecColor),
                                filled: true,
                                fillColor: bgColor,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            Text('Vincular a Catálogos', style: TextStyle(color: textSecColor, fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilterChip(
                                    label: const Text('Todos (Padrão)'),
                                    labelStyle: TextStyle(color: catalogosSelecionados.isEmpty ? Colors.white : textColor, fontWeight: FontWeight.bold, fontSize: 12),
                                    selected: catalogosSelecionados.isEmpty,
                                    selectedColor: accentColor,
                                    checkmarkColor: Colors.white,
                                    backgroundColor: _isDarkMode ? const Color(0xFF27293D) : Colors.grey[200],
                                    onSelected: (val) {
                                      setStateModal(() {
                                        catalogosSelecionados.clear();
                                      });
                                    },
                                  ),
                                  ..._catalogos.map((cat) {
                                    int cId = cat['id'] ?? cat['ID'];
                                    String cNome = cat['nome'] ?? cat['nome_catalogo'] ?? cat['name'] ?? 'Catálogo $cId';
                                    bool isSel = catalogosSelecionados.contains(cId);
                                    return FilterChip(
                                      label: Text(cNome),
                                      labelStyle: TextStyle(color: isSel ? Colors.white : textColor, fontWeight: FontWeight.bold, fontSize: 12),
                                      selected: isSel,
                                      selectedColor: accentColor,
                                      checkmarkColor: Colors.white,
                                      backgroundColor: _isDarkMode ? const Color(0xFF27293D) : Colors.grey[200],
                                      onSelected: (val) {
                                        setStateModal(() {
                                          if (val) {
                                            catalogosSelecionados.add(cId);
                                          } else {
                                            catalogosSelecionados.remove(cId);
                                          }
                                        });
                                      },
                                    );
                                  }),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final data = await showDatePicker(
                                        context: modalContext,
                                        initialDate: dataInicio ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2030),
                                      );
                                      if (data != null) setStateModal(() => dataInicio = data);
                                    },
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: 'Data de Início',
                                        labelStyle: TextStyle(color: textSecColor),
                                        filled: true,
                                        fillColor: bgColor,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                        prefixIcon: Icon(Icons.calendar_today, color: accentColor),
                                      ),
                                      child: Text(dataInicio == null ? 'Imediato' : _formatarDataDisplay(dataInicio), style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final data = await showDatePicker(
                                        context: modalContext,
                                        initialDate: dataFim ?? (dataInicio ?? DateTime.now()),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2030),
                                      );
                                      if (data != null) setStateModal(() => dataFim = data);
                                    },
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: 'Data de Fim',
                                        labelStyle: TextStyle(color: textSecColor),
                                        filled: true,
                                        fillColor: bgColor,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                        prefixIcon: Icon(Icons.event_busy, color: accentColor),
                                      ),
                                      child: Text(dataFim == null ? 'Sem limite' : _formatarDataDisplay(dataFim), style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (dataInicio != null || dataFim != null)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => setStateModal(() { dataInicio = null; dataFim = null; }),
                                  child: const Text('Limpar datas', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            const SizedBox(height: 16),
                            Text('Imagem do Cartaz', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (imagemUrl.isNotEmpty)
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        width: 150, height: 150,
                                        margin: const EdgeInsets.only(right: 16),
                                        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: _isDarkMode ? Colors.white24 : Colors.grey[300]!)),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: imagemUrl.startsWith('data:image') 
                                              ? Image.memory(base64Decode(imagemUrl.split(',')[1]), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.broken_image, color: textSecColor, size: 40))
                                              : Image.network(imagemUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.broken_image, color: textSecColor, size: 40)),
                                        ),
                                      ),
                                      Positioned(
                                        top: -8, right: 8, 
                                        child: GestureDetector(
                                          onTap: () => setStateModal(() => imagemUrl = ''), 
                                          child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 16))
                                        )
                                      ),
                                    ],
                                  ),
                                if (imagemUrl.isEmpty)
                                  isUploadingImage
                                      ? Container(width: 150, height: 150, decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: accentColor.withOpacity(0.3))), child: Center(child: CircularProgressIndicator(color: accentColor, strokeWidth: 2)))
                                      : InkWell(
                                          onTap: escolherFoto,
                                          child: Container(
                                            width: 150, height: 150, 
                                            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: accentColor.withOpacity(0.3))), 
                                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, color: accentColor, size: 36), const SizedBox(height: 8), Text('Enviar Foto', style: TextStyle(color: accentColor, fontSize: 13, fontWeight: FontWeight.bold))])
                                          ),
                                        ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Divider(color: _isDarkMode ? Colors.white10 : Colors.grey[300]),
                            const SizedBox(height: 8),
                            Text('Produtos em Promoção', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: buscaProdutoController,
                                    style: TextStyle(color: textColor),
                                    decoration: InputDecoration(
                                      hintText: 'Buscar produto para adicionar...',
                                      hintStyle: TextStyle(color: textSecColor),
                                      filled: true,
                                      fillColor: bgColor,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    ),
                                    onSubmitted: (_) => pesquisarProdutos(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                    onPressed: pesquisarProdutos,
                                    icon: const Icon(Icons.search),
                                    label: const Text('Buscar', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (isSearchingProducts)
                              Center(child: CircularProgressIndicator(color: accentColor))
                            else if (resultadosBusca.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: adicionarTodosOsProdutos, 
                                      icon: const Icon(Icons.playlist_add_check, color: Colors.blueAccent),
                                      label: const Text('Adicionar Todos', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  Container(
                                    height: 200,
                                    decoration: BoxDecoration(border: Border.all(color: _isDarkMode ? Colors.white10 : Colors.grey[200]!), borderRadius: BorderRadius.circular(12)),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: RawScrollbar(
                                            controller: scrollListaBusca,
                                            thumbVisibility: true,
                                            thumbColor: accentColor.withOpacity(0.5),
                                            radius: const Radius.circular(8),
                                            child: ListView.separated(
                                              controller: scrollListaBusca,
                                              padding: const EdgeInsets.all(8),
                                              itemCount: resultadosBusca.length,
                                              separatorBuilder: (context, index) => Divider(height: 1, color: _isDarkMode ? Colors.white10 : Colors.grey[200]),
                                              itemBuilder: (context, index) {
                                                final prod = resultadosBusca[index];
                                                final String imgUrl = prod['image_url'] ?? prod['ImageURL'] ?? '';
                                                final List<String> f = imgUrl.split('|||').where((s) => s.isNotEmpty).toList();

                                                return ListTile(
                                                  leading: ClipRRect(
                                                    borderRadius: BorderRadius.circular(6),
                                                    child: SizedBox(
                                                      width: 40, height: 40,
                                                      child: f.isEmpty || f.first == 'null'
                                                        ? Container(color: bgColor, child: Icon(Icons.fastfood, color: textSecColor, size: 20))
                                                        : (f.first.startsWith('data:image') 
                                                            ? Image.memory(base64Decode(f.first.split(',')[1]), fit: BoxFit.cover)
                                                            : Image.network(f.first, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.broken_image, color: textSecColor)))
                                                    )
                                                  ),
                                                  title: Text(prod['name'] ?? prod['Name'] ?? '', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                                                  subtitle: Text('R\$ ${double.tryParse((prod['price'] ?? prod['Price'] ?? 0).toString())?.toStringAsFixed(2).replaceAll('.', ',')}', style: TextStyle(color: textSecColor, fontSize: 12)),
                                                  trailing: ElevatedButton(
                                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12), visualDensity: VisualDensity.compact),
                                                    onPressed: () => adicionarProduto(prod),
                                                    child: const Text('Add', style: TextStyle(fontSize: 11)),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                        Container(
                                          width: 40,
                                          decoration: BoxDecoration(
                                            border: Border(left: BorderSide(color: _isDarkMode ? Colors.white10 : Colors.grey[200]!)),
                                            color: _isDarkMode ? const Color(0xFF1A1A24) : Colors.grey[50],
                                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(12))
                                          ),
                                          child: Column(
                                            children: [
                                              Expanded(
                                                child: InkWell(
                                                  onTap: () => scrollVerticalBusca(-150),
                                                  child: Center(child: Icon(Icons.arrow_drop_up, size: 32, color: accentColor)),
                                                ),
                                              ),
                                              Divider(height: 1, color: _isDarkMode ? Colors.white10 : Colors.grey[300]),
                                              Expanded(
                                                child: InkWell(
                                                  onTap: () => scrollVerticalBusca(150),
                                                  child: Center(child: Icon(Icons.arrow_drop_down, size: 32, color: accentColor)),
                                                ),
                                              ),
                                            ]
                                          )
                                        )
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            if (produtosSelecionados.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: accentColor.withOpacity(0.3))),
                                child: Row(
                                  children: [
                                    const Icon(Icons.discount, color: Colors.green),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: descontoGeralController,
                                        keyboardType: TextInputType.number,
                                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                                        decoration: InputDecoration(
                                          hintText: 'Aplicar desconto em % para todos...',
                                          hintStyle: TextStyle(color: textSecColor, fontSize: 13),
                                          isDense: true,
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
                                      onPressed: aplicarDescontoMassa,
                                      child: const Text('Aplicar a Todos', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    )
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: _isDarkMode ? Colors.white10 : Colors.grey[300]!)),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: produtosSelecionados.length,
                                  separatorBuilder: (context, index) => Divider(height: 1, color: _isDarkMode ? Colors.white10 : Colors.grey[300]),
                                  itemBuilder: (context, index) {
                                    int key = produtosSelecionados.keys.elementAt(index);
                                    var item = produtosSelecionados[key]!;
                                    
                                    final String imgUrl = item['imagem_url'] ?? '';
                                    final List<String> f = imgUrl.split('|||').where((s) => s.isNotEmpty).toList();

                                    return Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: isMobile 
                                          ? Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    ClipRRect(borderRadius: BorderRadius.circular(6), child: SizedBox(width: 30, height: 30, child: f.isEmpty || f.first == 'null' ? Container(color: cardColor, child: Icon(Icons.fastfood, color: textSecColor, size: 16)) : (f.first.startsWith('data:image') ? Image.memory(base64Decode(f.first.split(',')[1]), fit: BoxFit.cover) : Image.network(f.first, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.broken_image, color: textSecColor))))),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(item['nome'], style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                                                          Text('Original: R\$ ${item['preco_original'].toStringAsFixed(2).replaceAll('.', ',')}', style: TextStyle(color: textSecColor, fontSize: 11)),
                                                        ],
                                                      ),
                                                    ),
                                                    IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20), onPressed: () => removerProduto(key)),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: TextField(
                                                        controller: descontosControllers[key],
                                                        keyboardType: TextInputType.number,
                                                        style: TextStyle(color: accentColor, fontWeight: FontWeight.w900, fontSize: 14),
                                                        decoration: InputDecoration(
                                                          labelText: '% Desc',
                                                          labelStyle: TextStyle(color: textSecColor, fontSize: 11),
                                                          isDense: true,
                                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                          border: const OutlineInputBorder(),
                                                          suffixText: '%',
                                                          suffixStyle: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 12),
                                                        ),
                                                        onChanged: (val) {
                                                          double desc = double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
                                                          double pOrig = item['preco_original'];
                                                          double pNovo = pOrig - (pOrig * (desc / 100));
                                                          precosControllers[key]!.text = pNovo.toStringAsFixed(2);
                                                        },
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: TextField(
                                                        controller: precosControllers[key],
                                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 14),
                                                        decoration: InputDecoration(
                                                          labelText: 'R\$ Promo',
                                                          labelStyle: TextStyle(color: textSecColor, fontSize: 11),
                                                          isDense: true,
                                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                          border: const OutlineInputBorder(),
                                                          prefixText: 'R\$ ',
                                                          prefixStyle: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                                                        ),
                                                        onChanged: (val) {
                                                          double pNovo = double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
                                                          double pOrig = item['preco_original'];
                                                          if (pOrig > 0) {
                                                            double desc = ((pOrig - pNovo) / pOrig) * 100;
                                                            descontosControllers[key]!.text = desc.toStringAsFixed(0);
                                                          }
                                                        },
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              ],
                                            )
                                          : Row(
                                              children: [
                                                ClipRRect(borderRadius: BorderRadius.circular(6), child: SizedBox(width: 40, height: 40, child: f.isEmpty || f.first == 'null' ? Container(color: cardColor, child: Icon(Icons.fastfood, color: textSecColor, size: 20)) : (f.first.startsWith('data:image') ? Image.memory(base64Decode(f.first.split(',')[1]), fit: BoxFit.cover) : Image.network(f.first, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.broken_image, color: textSecColor))))),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  flex: 2,
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(item['nome'], style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                                                      Text('Original: R\$ ${item['preco_original'].toStringAsFixed(2).replaceAll('.', ',')}', style: TextStyle(color: textSecColor, fontSize: 11)),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  flex: 1,
                                                  child: TextField(
                                                    controller: descontosControllers[key],
                                                    keyboardType: TextInputType.number,
                                                    style: TextStyle(color: accentColor, fontWeight: FontWeight.w900, fontSize: 14),
                                                    decoration: InputDecoration(
                                                      labelText: '% Desc',
                                                      labelStyle: TextStyle(color: textSecColor, fontSize: 11),
                                                      isDense: true,
                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                      border: const OutlineInputBorder(),
                                                      suffixText: '%',
                                                      suffixStyle: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 12),
                                                    ),
                                                    onChanged: (val) {
                                                      double desc = double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
                                                      double pOrig = item['preco_original'];
                                                      double pNovo = pOrig - (pOrig * (desc / 100));
                                                      precosControllers[key]!.text = pNovo.toStringAsFixed(2);
                                                    },
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  flex: 1,
                                                  child: TextField(
                                                    controller: precosControllers[key],
                                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 14),
                                                    decoration: InputDecoration(
                                                      labelText: 'R\$ Promo',
                                                      labelStyle: TextStyle(color: textSecColor, fontSize: 11),
                                                      isDense: true,
                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                      border: const OutlineInputBorder(),
                                                      prefixText: 'R\$ ',
                                                      prefixStyle: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                                                    ),
                                                    onChanged: (val) {
                                                      double pNovo = double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
                                                      double pOrig = item['preco_original'];
                                                      if (pOrig > 0) {
                                                        double desc = ((pOrig - pNovo) / pOrig) * 100;
                                                        descontosControllers[key]!.text = desc.toStringAsFixed(0);
                                                      }
                                                    },
                                                  ),
                                                ),
                                                IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20), onPressed: () => removerProduto(key)),
                                              ],
                                            ),
                                    );
                                  },
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            Material(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(10),
                              child: SwitchListTile(
                                title: Text('Ativar Promoção no Catálogo', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                                subtitle: Text('Aparecerá para o cliente se o prazo for válido.', style: TextStyle(fontSize: 12, color: textSecColor)),
                                value: isAtiva,
                                activeColor: accentColor,
                                onChanged: (val) {
                                  setStateModal(() {
                                    isAtiva = val;
                                  });
                                },
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                    
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: _isDarkMode ? Colors.white10 : Colors.grey[200]!)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(modalContext),
                            child: Text('Cancelar', style: TextStyle(color: textSecColor, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                            onPressed: isUploadingImage || isSavingData ? null : () async {
                              if (tituloController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O título é obrigatório'), backgroundColor: Colors.red));
                                return;
                              }
                              if (imagemUrl.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A imagem do cartaz é obrigatória!'), backgroundColor: Colors.red));
                                return;
                              }

                              setStateModal(() => isSavingData = true);

                              List<Map<String, dynamic>> listaProdutos = [];
                              produtosSelecionados.forEach((key, value) {
                                double precoPromo = double.tryParse(precosControllers[key]!.text.replaceAll(',', '.')) ?? value['preco_original'];
                                double percentual = double.tryParse(descontosControllers[key]!.text.replaceAll(',', '.')) ?? 0.0;
                                listaProdutos.add({
                                  'produto_id': key,
                                  'preco_promocional': precoPromo,
                                  'percentual_desconto': percentual,
                                });
                              });

                              await _salvarPromocao({
                                'titulo': tituloController.text.trim(),
                                'descricao': descController.text.trim(),
                                'imagem_url': imagemUrl,
                                'ativa': isAtiva,
                                'data_inicio': _formatarDataAPI(dataInicio),
                                'data_fim': _formatarDataAPI(dataFim),
                                'catalogos_ids': catalogosSelecionados,
                                'produtos': listaProdutos,
                              }, modalContext, id: promocao?['id']);
                              
                              if (mounted) {
                                setStateModal(() => isSavingData = false);
                              }
                            },
                            icon: isSavingData ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save_outlined, size: 20),
                            label: Text(isSavingData ? 'Salvando...' : 'Salvar Promoção', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
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
            foregroundColor: textColor, 
            elevation: 1,
            leading: IconButton(
              icon: Icon(Icons.menu, color: textColor),
              tooltip: 'Abrir Menu',
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
            title: Row(
              children: [
                Container(
                  width: 35,
                  height: 35,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(image: AssetImage('assets/images/logo.jpg'), fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 12),
                Text('AÇAITERIA SHALOM BANNER', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 16, color: textColor)),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode, color: textColor),
                tooltip: 'Alternar Tema',
                onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
              ),
            ],
          ),
          body: Stack(
            children: [
              _isLoading
                  ? Center(child: CircularProgressIndicator(color: accentColor))
                  : _promocoes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.campaign_outlined, size: 80, color: textSecColor.withOpacity(0.5)),
                              const SizedBox(height: 16),
                              Text('Nenhuma promoção cadastrada', style: TextStyle(fontSize: 18, color: textSecColor, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Showcase.withWidget(
                            key: _keyLista,
                            container: _buildTooltipMascote(showcaseContext, _textosMascote[0], false),
                            child: GridView.builder(
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 400,
                                childAspectRatio: 0.85,
                                crossAxisSpacing: 24,
                                mainAxisSpacing: 24,
                              ),
                              itemCount: _promocoes.length,
                              itemBuilder: (context, index) {
                                final p = _promocoes[index];
                                final img = p['imagem_url']?.toString() ?? '';
                                
                                String validade = 'Sem limite de validade';
                                if (p['data_inicio'] != null && p['data_inicio'].toString().isNotEmpty) {
                                  validade = 'A partir de ${_formatarDataDisplay(DateTime.tryParse(p['data_inicio']))}';
                                  if (p['data_fim'] != null && p['data_fim'].toString().isNotEmpty) {
                                    validade += ' até ${_formatarDataDisplay(DateTime.tryParse(p['data_fim']))}';
                                  }
                                } else if (p['data_fim'] != null && p['data_fim'].toString().isNotEmpty) {
                                  validade = 'Válido até ${_formatarDataDisplay(DateTime.tryParse(p['data_fim']))}';
                                }

                                return Card(
                                  color: cardColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: _isDarkMode ? Colors.white10 : Colors.transparent)),
                                  elevation: 4,
                                  clipBehavior: Clip.antiAlias,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: img.isEmpty
                                            ? Container(color: bgColor, child: Icon(Icons.image, size: 60, color: textSecColor))
                                            : img.startsWith('data:image')
                                                ? Image.memory(base64Decode(img.split(',')[1]), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: bgColor, child: Icon(Icons.broken_image, size: 60, color: textSecColor)))
                                                : Image.network(img, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: bgColor, child: Icon(Icons.broken_image, size: 60, color: textSecColor))),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(child: Text(p['titulo'] ?? '', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                                Switch(
                                                  value: p['ativa'] ?? false,
                                                  activeColor: accentColor,
                                                  onChanged: (val) => _alternarStatus(p['id'], p, val),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(validade, style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 8),
                                            Text(p['descricao'] ?? '', style: TextStyle(color: textSecColor, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                                            const SizedBox(height: 16),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.edit, color: Colors.blueAccent),
                                                  tooltip: 'Editar',
                                                  onPressed: () => _abrirFormulario(promocao: p),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                                                  tooltip: 'Excluir',
                                                  onPressed: () {
                                                    showDialog(
                                                      context: context,
                                                      builder: (ctx) => AlertDialog(
                                                        backgroundColor: cardColor,
                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                        title: Text('Excluir Promoção?', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                                        content: Text('Essa ação não pode ser desfeita.', style: TextStyle(color: textSecColor)),
                                                        actions: [
                                                          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancelar', style: TextStyle(color: textSecColor))),
                                                          ElevatedButton(
                                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                                            onPressed: () {
                                                              Navigator.pop(ctx);
                                                              _excluirPromocao(p['id']);
                                                            },
                                                            child: const Text('Excluir', style: TextStyle(fontWeight: FontWeight.bold)),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
              Positioned(
                bottom: 100,
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
          floatingActionButton: Showcase.withWidget(
            key: _keyNovo,
            container: _buildTooltipMascote(showcaseContext, _textosMascote[1], true),
            child: FloatingActionButton.extended(
              onPressed: () => _abrirFormulario(),
              backgroundColor: accentColor,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Nova Promoção', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        );
      }
    );
  }
}