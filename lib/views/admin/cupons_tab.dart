import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:acaiteria_front/core/constants/api_constants.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:showcaseview/showcaseview.dart';

class CuponsTab extends StatefulWidget {
  const CuponsTab({super.key});

  @override
  State<CuponsTab> createState() => _CuponsTabState();
}

class _CuponsTabState extends State<CuponsTab> {
  List<dynamic> _cupons = [];
  List<dynamic> _catalogos = [];
  bool _isLoading = true;
  bool _isDarkMode = true;

  final FlutterTts _flutterTts = FlutterTts();
  final GlobalKey _keyNovo = GlobalKey();
  final GlobalKey _keyLista = GlobalKey();

  final List<String> _textosMascote = [
    "Aqui você pode gerenciar todos os cupons de desconto. Os cupons criados podem ser usados pelos clientes na hora de fechar o pedido.",
    "Para gerar um código novo e aplicá-lo a um catálogo, clique aqui no botão."
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
                          "Nesta tela você cria e controla os Cupons de Desconto!\n\n"
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

  String _gerarCodigoAleatorio() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return String.fromCharCodes(Iterable.generate(8, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  Future<void> _carregarDados() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final resCat = await http.get(Uri.parse('$_baseUrl/api/catalogo'));
      if (resCat.statusCode == 200) {
        _catalogos = jsonDecode(resCat.body);
      }

      final response = await http.get(Uri.parse('$_baseUrl/api/cupons'));
      if (response.statusCode == 200) {
        _cupons = jsonDecode(response.body);
      }
    } catch (e) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _salvarCupom(Map<String, dynamic> cupom, BuildContext modalContext, {int? id}) async {
    try {
      http.Response response;
      if (id == null) {
        response = await http.post(
          Uri.parse('$_baseUrl/api/cupons'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(cupom),
        );
      } else {
        response = await http.put(
          Uri.parse('$_baseUrl/api/cupons/$id'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(cupom),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        _carregarDados();
        if (Navigator.canPop(modalContext)) {
          Navigator.pop(modalContext);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cupom salvo com sucesso!'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao salvar cupom. Talvez o código já exista.'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro de conexão ao salvar cupom.'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _excluirCupom(int id) async {
    try {
      final response = await http.delete(Uri.parse('$_baseUrl/api/cupons/$id'));
      if (response.statusCode == 200) {
        _carregarDados();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cupom excluído!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao excluir.'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _alternarStatus(int id, Map<String, dynamic> cupom, bool novoStatus) async {
    cupom['ativo'] = novoStatus;
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/api/cupons/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(cupom),
      );
      if (response.statusCode == 200) {
        _carregarDados();
      }
    } catch (e) {}
  }

  void _abrirFormulario({Map<String, dynamic>? cupom}) {
    final codigoController = TextEditingController(text: cupom?['codigo'] ?? '');
    final descontoController = TextEditingController(text: cupom?['percentual_desconto']?.toString() ?? '');
    
    bool isAtivo = cupom?['ativo'] ?? true;
    DateTime? dataValidade;
    bool isSavingData = false;
    
    List<int> catalogosSelecionados = [];
    if (cupom != null && cupom['catalogos_ids'] != null) {
      catalogosSelecionados = List<int>.from(cupom['catalogos_ids']);
    }
    
    if (cupom?['data_validade'] != null && cupom!['data_validade'].toString().isNotEmpty) {
      dataValidade = DateTime.tryParse(cupom['data_validade']);
    }

    showDialog(
      context: context,
      useSafeArea: false,
      builder: (BuildContext modalContext) {
        final screenWidth = MediaQuery.of(modalContext).size.width;
        final bool isMobile = screenWidth < 600;

        return StatefulBuilder(
          builder: (context, setStateModal) {
            return Dialog(
              backgroundColor: cardColor,
              insetPadding: isMobile ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              shape: isMobile ? const RoundedRectangleBorder(borderRadius: BorderRadius.zero) : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: _isDarkMode ? Colors.white10 : Colors.transparent)),
              child: SizedBox(
                width: isMobile ? double.infinity : 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _isDarkMode ? Colors.white10 : Colors.grey[200]!))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(cupom == null ? 'NOVO CUPOM' : 'EDITAR CUPOM', style: TextStyle(color: accentColor, fontWeight: FontWeight.w900, fontSize: 18)),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(modalContext), color: textSecColor),
                        ],
                      ),
                    ),
                    
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: codigoController,
                                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, letterSpacing: 2.0),
                                    textCapitalization: TextCapitalization.characters,
                                    decoration: InputDecoration(
                                      labelText: 'Código do Cupom', 
                                      labelStyle: TextStyle(color: textSecColor, letterSpacing: 0),
                                      filled: true,
                                      fillColor: bgColor,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                      prefixIcon: Icon(Icons.local_activity, color: accentColor),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                  child: IconButton(
                                    tooltip: 'Gerar código aleatório',
                                    icon: Icon(Icons.autorenew, color: accentColor),
                                    onPressed: () {
                                      setStateModal(() {
                                        codigoController.text = _gerarCodigoAleatorio();
                                      });
                                    },
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: descontoController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                labelText: 'Percentual de Desconto (%)', 
                                labelStyle: TextStyle(color: textSecColor),
                                filled: true,
                                fillColor: bgColor,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                prefixIcon: Icon(Icons.percent, color: accentColor),
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

                            InkWell(
                              onTap: () async {
                                final data = await showDatePicker(
                                  context: modalContext,
                                  initialDate: dataValidade ?? DateTime.now(),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime(2030),
                                );
                                if (data != null) setStateModal(() => dataValidade = data);
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Data de Validade (Opcional)',
                                  labelStyle: TextStyle(color: textSecColor),
                                  filled: true,
                                  fillColor: bgColor,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                  prefixIcon: Icon(Icons.event, color: accentColor),
                                ),
                                child: Text(dataValidade == null ? 'Sem validade' : _formatarDataDisplay(dataValidade), style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            if (dataValidade != null)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => setStateModal(() => dataValidade = null),
                                  child: const Text('Remover validade', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            const SizedBox(height: 16),
                            Material(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(10),
                              child: SwitchListTile(
                                title: Text('Cupom Ativo', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                                value: isAtivo,
                                activeColor: accentColor,
                                onChanged: (val) {
                                  setStateModal(() => isAtivo = val);
                                },
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                    
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: _isDarkMode ? Colors.white10 : Colors.grey[200]!))),
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
                            onPressed: isSavingData ? null : () async {
                              if (codigoController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O código é obrigatório'), backgroundColor: Colors.red));
                                return;
                              }
                              if (descontoController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O desconto é obrigatório'), backgroundColor: Colors.red));
                                return;
                              }

                              setStateModal(() => isSavingData = true);
                              double desconto = double.tryParse(descontoController.text.replaceAll(',', '.')) ?? 0.0;

                              await _salvarCupom({
                                'codigo': codigoController.text.trim(),
                                'percentual_desconto': desconto,
                                'data_validade': _formatarDataAPI(dataValidade),
                                'catalogos_ids': catalogosSelecionados,
                                'ativo': isAtivo,
                              }, modalContext, id: cupom?['id']);
                              
                              if (mounted) {
                                setStateModal(() => isSavingData = false);
                              }
                            },
                            icon: isSavingData ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save_outlined, size: 20),
                            label: Text(isSavingData ? 'Salvando...' : 'Salvar Cupom', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                  width: 35, height: 35,
                  decoration: const BoxDecoration(shape: BoxShape.circle, image: DecorationImage(image: AssetImage('assets/images/logo.jpg'), fit: BoxFit.cover)),
                ),
                const SizedBox(width: 12),
                Text('GESTÃO DE CUPONS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 16, color: textColor)),
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
                  : _cupons.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.local_activity_outlined, size: 80, color: textSecColor.withOpacity(0.5)),
                              const SizedBox(height: 16),
                              Text('Nenhum cupom cadastrado', style: TextStyle(fontSize: 18, color: textSecColor, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      : Showcase.withWidget(
                          key: _keyLista,
                          container: _buildTooltipMascote(showcaseContext, _textosMascote[0], false),
                          child: ListView.separated(
                              padding: const EdgeInsets.all(24.0),
                              itemCount: _cupons.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final c = _cupons[index];
                                String validade = c['data_validade'] == null || c['data_validade'].toString().isEmpty 
                                    ? 'Sem validade' 
                                    : 'Válido até ${_formatarDataDisplay(DateTime.tryParse(c['data_validade']))}';
                                
                                return Container(
                                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: _isDarkMode ? Colors.white10 : Colors.transparent)),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                    leading: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(color: accentColor.withOpacity(0.1), shape: BoxShape.circle),
                                      child: Icon(Icons.local_activity, color: accentColor),
                                    ),
                                    title: Row(
                                      children: [
                                        Text(c['codigo'], style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: textColor, letterSpacing: 1.5)),
                                        const SizedBox(width: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                          child: Text('-${c['percentual_desconto']}%', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                                        ),
                                      ],
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(validade, style: TextStyle(color: textSecColor, fontSize: 13)),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Switch(
                                          value: c['ativo'] ?? true,
                                          activeColor: accentColor,
                                          onChanged: (val) => _alternarStatus(c['id'], c, val),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blueAccent),
                                          onPressed: () => _abrirFormulario(cupom: c),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                backgroundColor: cardColor,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                title: Text('Excluir Cupom?', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                                content: Text('Tem certeza que deseja apagar o cupom ${c['codigo']}?', style: TextStyle(color: textSecColor)),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancelar', style: TextStyle(color: textSecColor))),
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                                                    onPressed: () {
                                                      Navigator.pop(ctx);
                                                      _excluirCupom(c['id']);
                                                    },
                                                    child: const Text('Excluir'),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
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
              label: const Text('Novo Cupom', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        );
      }
    );
  }
}