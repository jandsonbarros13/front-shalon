import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:acaiteria_front/features/auth/services/caixa_service.dart';

class CaixaTab extends StatefulWidget {
  const CaixaTab({super.key});

  @override
  State<CaixaTab> createState() => _CaixaTabState();
}

class _CaixaTabState extends State<CaixaTab> {
  final CaixaService _caixaService = CaixaService();
  
  bool _isLoading = true;
  bool _isCaixaAberto = false;
  
  double _saldoInicial = 0.0;
  double _totalDinheiro = 0.0;
  double _totalCartao = 0.0;
  double _totalPix = 0.0;
  
  double _totalSuprimento = 0.0;
  double _totalSangria = 0.0;
  
  bool _isDarkMode = true;

  double get _totalVendas => _totalDinheiro + _totalCartao + _totalPix;
  double get _saldoEmCaixa => _saldoInicial + _totalDinheiro + _totalSuprimento - _totalSangria; 

  bool get isDark => _isDarkMode;
  Color get accentColor => isDark ? const Color(0xFFE040FB) : const Color(0xFF4A0E4E);
  Color get bgColor => isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF4F6F8);
  Color get cardColor => isDark ? const Color(0xFF27293D) : Colors.white;
  Color get textColor => isDark ? Colors.white : Colors.black87;
  Color get textSecColor => isDark ? Colors.white54 : Colors.grey[600]!;

  final FlutterTts _flutterTts = FlutterTts();
  final GlobalKey _keyResumo = GlobalKey();
  final GlobalKey _keyAcoes = GlobalKey();
  final GlobalKey _keyGaveta = GlobalKey();
  final GlobalKey _keyHistorico = GlobalKey();

  final List<String> _textosMascote = [
    "Bem-vindo à Gestão de Caixa! Aqui você acompanha o resumo das suas vendas do dia separadas por Dinheiro, Cartão e PIX.",
    "Nesta área, você pode registrar Entradas (Suprimentos), Retiradas (Sangrias) e fazer a Abertura ou Fechamento do seu caixa.",
    "Aqui fica o Resumo Físico da Gaveta, mostrando o saldo inicial, as vendas em dinheiro e o total que deve ter fisicamente na gaveta agora.",
    "E por fim, você pode consultar o histórico de todas as aberturas e fechamentos de caixa anteriores e imprimir o relatório!"
  ];

  List<dynamic> _historicoCaixas = [];

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

  Future<void> _carregarDados() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final status = await _caixaService.obterStatusCaixa();
      final historico = await _caixaService.listarHistorico();

      if (mounted) {
        setState(() {
          _isCaixaAberto = status['isAberto'] ?? false;
          if (_isCaixaAberto && status['caixa'] != null) {
            _saldoInicial = double.tryParse(status['caixa']['saldo_inicial'].toString()) ?? 0.0;
            _totalSuprimento = double.tryParse(status['total_suprimento']?.toString() ?? '0') ?? 0.0;
            _totalSangria = double.tryParse(status['total_sangria']?.toString() ?? '0') ?? 0.0;
            _totalDinheiro = double.tryParse(status['total_dinheiro']?.toString() ?? '0') ?? 0.0;
            _totalCartao = double.tryParse(status['total_cartao']?.toString() ?? '0') ?? 0.0;
            _totalPix = double.tryParse(status['total_pix']?.toString() ?? '0') ?? 0.0;
          } else {
            _saldoInicial = 0.0;
            _totalSuprimento = 0.0;
            _totalSangria = 0.0;
            _totalDinheiro = 0.0;
            _totalCartao = 0.0;
            _totalPix = 0.0;
          }
          _historicoCaixas = historico;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatarData(dynamic dataISO) {
    if (dataISO == null || dataISO.toString().isEmpty) return '--';
    try {
      DateTime dt = DateTime.parse(dataISO.toString()).toLocal();
      String dia = dt.day.toString().padLeft(2, '0');
      String mes = dt.month.toString().padLeft(2, '0');
      String ano = dt.year.toString();
      String hora = dt.hour.toString().padLeft(2, '0');
      String min = dt.minute.toString().padLeft(2, '0');
      return '$dia/$mes/$ano $hora:$min';
    } catch (e) {
      return dataISO.toString();
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
        constraints: const BoxConstraints(maxWidth: 360),
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
                        decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E2C) : Colors.grey[100], borderRadius: BorderRadius.circular(16)),
                        child: Text(
                          "Olá! Sou o mascote da Açaiteria Shalom! 🍇\n\n"
                          "Esta é a tela de Caixa. Aqui você controla a entrada e saída do dinheiro e fechamentos.\n\n"
                          "Quer fazer um Tour Guiado para ver como funciona?",
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
                            _keyResumo,
                            _keyAcoes,
                            _keyGaveta,
                            _keyHistorico,
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

  void _abrirModalSangriaSuprimento(String tipo) {
    if (!_isCaixaAberto) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Abra o caixa primeiro!'), backgroundColor: Colors.red));
      return;
    }

    final valorController = TextEditingController();
    final motivoController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog( 
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          tipo == 'Sangria' ? 'Retirada de Caixa (Sangria)' : 'Entrada de Caixa (Suprimento)',
          style: TextStyle(fontWeight: FontWeight.w900, color: accentColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: valorController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
              decoration: InputDecoration(
                labelText: 'Valor (R\$)',
                labelStyle: TextStyle(color: textSecColor),
                prefixText: 'R\$ ',
                prefixStyle: TextStyle(color: textColor, fontSize: 24),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!), borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: motivoController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'Motivo / Observação',
                labelStyle: TextStyle(color: textSecColor),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!), borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: tipo == 'Sangria' ? Colors.redAccent : Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              double v = double.tryParse(valorController.text.replaceAll(',', '.')) ?? 0.0;
              if (v <= 0) return;

              Navigator.pop(dialogContext);
              if (mounted) setState(() => _isLoading = true);

              bool sucesso = await _caixaService.lancarMovimentacao(tipo, v, motivoController.text.trim());
              
              if (sucesso) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$tipo registrada com sucesso!'), backgroundColor: Colors.green));
                }
                await _carregarDados();
              } else {
                if (mounted) {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao registrar movimentação.'), backgroundColor: Colors.red));
                }
              }
            },
            child: Text('CONFIRMAR ${tipo.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _abrirFecharCaixa() {
    if (_isCaixaAberto) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: cardColor,
          title: Text('Fechar Caixa', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
          content: Text('Tem certeza que deseja fechar o caixa atual?', style: TextStyle(color: textColor)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                bool sucesso = await _caixaService.fecharCaixa();
                if (sucesso && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Caixa Fechado com sucesso!'), backgroundColor: Colors.green));
                }
                await _carregarDados();
              }, 
              child: const Text('Sim, Fechar')
            )
          ],
        )
      );
    } else {
      final valorController = TextEditingController(text: '0.00');
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: cardColor,
          title: Text('Abrir Caixa', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: valorController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: 'Saldo Inicial (Troco em gaveta)',
              labelStyle: TextStyle(color: textSecColor),
              prefixText: 'R\$ ',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () async {
                double v = double.tryParse(valorController.text.replaceAll(',', '.')) ?? 0.0;
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                bool sucesso = await _caixaService.abrirCaixa(v);
                if (sucesso && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Caixa Aberto!'), backgroundColor: Colors.green));
                }
                await _carregarDados();
              }, 
              child: const Text('Abrir Caixa', style: TextStyle(fontWeight: FontWeight.bold))
            )
          ],
        )
      );
    }
  }

  Future<void> _gerarRelatorioCaixaPdf(Map<String, dynamic> caixa) async {
    final pdf = pw.Document();
    
    pw.ImageProvider? logoImage;
    try {
      final ByteData bytes = await rootBundle.load('assets/images/logo.jpg');
      logoImage = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {}

    final bool aberto = caixa['status'] == 'Aberto';
    final double saldoInicial = double.tryParse(caixa['saldo_inicial']?.toString() ?? '0') ?? 0.0;
    final double saldoFinal = double.tryParse(caixa['saldo_final']?.toString() ?? '0') ?? 0.0;
    
    final double totalSuprimento = double.tryParse(caixa['total_suprimento']?.toString() ?? '0') ?? 0.0;
    final double totalSangria = double.tryParse(caixa['total_sangria']?.toString() ?? '0') ?? 0.0;
    final double totalDinheiro = double.tryParse(caixa['total_dinheiro']?.toString() ?? '0') ?? 0.0;
    final double totalCartao = double.tryParse(caixa['total_cartao']?.toString() ?? '0') ?? 0.0;
    final double totalPix = double.tryParse(caixa['total_pix']?.toString() ?? '0') ?? 0.0;
    
    final double totalVendas = totalDinheiro + totalCartao + totalPix;
    final double saldoEsperado = saldoInicial + totalDinheiro + totalSuprimento - totalSangria;

    final String abertura = _formatarData(caixa['data_abertura']);
    final String fechamento = aberto ? 'Em andamento' : _formatarData(caixa['data_fechamento']);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(12),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: logoImage != null
                    ? pw.Container(width: 55, height: 55, child: pw.Image(logoImage))
                    : pw.SizedBox.shrink(),
              ),
              pw.SizedBox(height: 4),
              pw.Center(child: pw.Text('AÇAITERIA SHALOM', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))),
              pw.Center(child: pw.Text('FECHAMENTO DE CAIXA', style: const pw.TextStyle(fontSize: 9))),
              pw.SizedBox(height: 10),
              
              pw.Text('CAIXA #${caixa['id']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.Text('Status: ${caixa['status'].toString().toUpperCase()}', style: const pw.TextStyle(fontSize: 10)),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              
              pw.Text('Abertura: $abertura', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Fechamento: $fechamento', style: const pw.TextStyle(fontSize: 10)),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              
              pw.Center(child: pw.Text('RESUMO DE VENDAS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
              pw.SizedBox(height: 4),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Dinheiro:', style: const pw.TextStyle(fontSize: 10)), pw.Text('R\$ ${totalDinheiro.toStringAsFixed(2).replaceAll('.', ',')}', style: const pw.TextStyle(fontSize: 10))]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Cartão:', style: const pw.TextStyle(fontSize: 10)), pw.Text('R\$ ${totalCartao.toStringAsFixed(2).replaceAll('.', ',')}', style: const pw.TextStyle(fontSize: 10))]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('PIX:', style: const pw.TextStyle(fontSize: 10)), pw.Text('R\$ ${totalPix.toStringAsFixed(2).replaceAll('.', ',')}', style: const pw.TextStyle(fontSize: 10))]),
              pw.SizedBox(height: 4),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Total de Vendas:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)), pw.Text('R\$ ${totalVendas.toStringAsFixed(2).replaceAll('.', ',')}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))]),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),

              pw.Center(child: pw.Text('MOVIMENTACOES (GAVETA)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
              pw.SizedBox(height: 4),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('(+) Suprimentos:', style: const pw.TextStyle(fontSize: 10)), pw.Text('R\$ ${totalSuprimento.toStringAsFixed(2).replaceAll('.', ',')}', style: const pw.TextStyle(fontSize: 10))]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('(-) Sangrias:', style: const pw.TextStyle(fontSize: 10)), pw.Text('R\$ ${totalSangria.toStringAsFixed(2).replaceAll('.', ',')}', style: const pw.TextStyle(fontSize: 10))]),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Saldo Inicial:', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('R\$ ${saldoInicial.toStringAsFixed(2).replaceAll('.', ',')}', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Saldo Final Esperado:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.Text('R\$ ${saldoEsperado.toStringAsFixed(2).replaceAll('.', ',')}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              if (!aberto) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Saldo Final Informado:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.Text('R\$ ${saldoFinal.toStringAsFixed(2).replaceAll('.', ',')}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
              pw.SizedBox(height: 15),
              pw.Center(child: pw.Text('Impresso via Sistema PDV', style: const pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic))),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Fechamento_Caixa_${caixa['id']}.pdf',
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.1) : color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: isMobile ? 20 : 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title, 
                  style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: isMobile ? 12 : 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 8 : 16),
          Text(
            value, 
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: isMobile ? 20 : 28, color: textColor),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _linhaResumoGaveta(String titulo, double valor, {bool isSubtracao = false, bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(titulo, style: TextStyle(color: isTotal ? textColor : textSecColor, fontWeight: isTotal ? FontWeight.w900 : FontWeight.bold, fontSize: isTotal ? 18 : 14)),
          Text(
            '${isSubtracao ? "- " : (isTotal ? "" : "+ ")}R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}', 
            style: TextStyle(
              color: isTotal ? accentColor : (isSubtracao ? Colors.redAccent : Colors.green), 
              fontWeight: FontWeight.w900, 
              fontSize: isTotal ? 26 : 16
            )
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    Widget btnSuprimento = ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () => _abrirModalSangriaSuprimento('Suprimento'),
      icon: const Icon(Icons.arrow_circle_up, size: 24),
      label: const Text('SUPRIMENTO', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
    );

    Widget btnSangria = ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () => _abrirModalSangriaSuprimento('Sangria'),
      icon: const Icon(Icons.arrow_circle_down, size: 24),
      label: const Text('SANGRIA', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
    );

    Widget btnAbrirFechar = ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: _isCaixaAberto ? Colors.black87 : accentColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: _abrirFecharCaixa,
      icon: Icon(_isCaixaAberto ? Icons.lock : Icons.lock_open, size: 24),
      label: Text(_isCaixaAberto ? 'FECHAR CAIXA' : 'ABRIR CAIXA', style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
    );

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
                    'GESTÃO DE CAIXA', 
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
                  color: _isCaixaAberto ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: _isCaixaAberto ? Colors.green.withOpacity(0.5) : Colors.red.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Icon(_isCaixaAberto ? Icons.lock_open : Icons.lock, color: _isCaixaAberto ? Colors.green : Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      _isCaixaAberto ? 'CAIXA ABERTO' : 'CAIXA FECHADO', 
                      style: TextStyle(color: _isCaixaAberto ? Colors.green : Colors.red, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)
                    ),
                  ],
                ),
              )
            ],
          ),
          body: _isLoading 
            ? Center(child: CircularProgressIndicator(color: accentColor))
            : Stack(
            children: [
              SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fluxo de Caixa', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textColor)),
                    const SizedBox(height: 4),
                    Text('Acompanhe as movimentações financeiras de hoje.', style: TextStyle(color: textSecColor, fontSize: 14)),
                    const SizedBox(height: 32),
                    
                    Showcase.withWidget(
                      key: _keyResumo,
                      container: _buildTooltipMascote(showcaseContext, _textosMascote[0], false),
                      child: isMobile 
                          ? Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: _buildSummaryCard('Vendas Totais', 'R\$ ${_totalVendas.toStringAsFixed(2).replaceAll('.', ',')}', Icons.point_of_sale, accentColor, true)),
                                    const SizedBox(width: 12),
                                    Expanded(child: _buildSummaryCard('Dinheiro', 'R\$ ${_totalDinheiro.toStringAsFixed(2).replaceAll('.', ',')}', Icons.payments, Colors.green, true)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(child: _buildSummaryCard('Cartão', 'R\$ ${_totalCartao.toStringAsFixed(2).replaceAll('.', ',')}', Icons.credit_card, Colors.orange, true)),
                                    const SizedBox(width: 12),
                                    Expanded(child: _buildSummaryCard('PIX', 'R\$ ${_totalPix.toStringAsFixed(2).replaceAll('.', ',')}', Icons.pix, Colors.teal, true)),
                                  ],
                                )
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(child: _buildSummaryCard('Vendas Totais', 'R\$ ${_totalVendas.toStringAsFixed(2).replaceAll('.', ',')}', Icons.point_of_sale, accentColor, false)),
                                const SizedBox(width: 16),
                                Expanded(child: _buildSummaryCard('Dinheiro', 'R\$ ${_totalDinheiro.toStringAsFixed(2).replaceAll('.', ',')}', Icons.payments, Colors.green, false)),
                                const SizedBox(width: 16),
                                Expanded(child: _buildSummaryCard('Cartão', 'R\$ ${_totalCartao.toStringAsFixed(2).replaceAll('.', ',')}', Icons.credit_card, Colors.orange, false)),
                                const SizedBox(width: 16),
                                Expanded(child: _buildSummaryCard('PIX', 'R\$ ${_totalPix.toStringAsFixed(2).replaceAll('.', ',')}', Icons.pix, Colors.teal, false)),
                              ],
                            ),
                    ),

                    const SizedBox(height: 32),
                    
                    Showcase.withWidget(
                      key: _keyAcoes,
                      container: _buildTooltipMascote(showcaseContext, _textosMascote[1], false),
                      child: isMobile 
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                btnSuprimento,
                                const SizedBox(height: 12),
                                btnSangria,
                                const SizedBox(height: 12),
                                btnAbrirFechar,
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(child: btnSuprimento),
                                const SizedBox(width: 16),
                                Expanded(child: btnSangria),
                                const SizedBox(width: 16),
                                Expanded(child: btnAbrirFechar),
                              ],
                            ),
                    ),

                    const SizedBox(height: 32),
                    Text('Resumo Físico da Gaveta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 16),
                    
                    Showcase.withWidget(
                      key: _keyGaveta,
                      container: _buildTooltipMascote(showcaseContext, _textosMascote[2], false),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _linhaResumoGaveta('Saldo Inicial (Abertura):', _saldoInicial),
                            
                            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Divider(color: isDark ? Colors.white10 : Colors.grey[200])),
                            
                            _linhaResumoGaveta('Vendas em Dinheiro:', _totalDinheiro),
                            
                            if (_totalSuprimento > 0)
                              _linhaResumoGaveta('Suprimentos (Entradas):', _totalSuprimento),
                            
                            if (_totalSangria > 0)
                              _linhaResumoGaveta('Sangrias (Retiradas):', _totalSangria, isSubtracao: true),
                            
                            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Divider(color: isDark ? Colors.white10 : Colors.grey[200])),
                            
                            _linhaResumoGaveta('Total Esperado na Gaveta:', _saldoEmCaixa, isTotal: true),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                    Text('Histórico de Aberturas e Fechamentos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 16),

                    Showcase.withWidget(
                      key: _keyHistorico,
                      container: _buildTooltipMascote(showcaseContext, _textosMascote[3], true),
                      child: Container(
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
                        ),
                        child: _historicoCaixas.isEmpty 
                        ? Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Center(child: Text('Nenhum registro de caixa encontrado.', style: TextStyle(color: textSecColor))),
                          )
                        : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _historicoCaixas.length,
                          separatorBuilder: (context, index) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
                          itemBuilder: (context, index) {
                            final item = _historicoCaixas[index];
                            final bool aberto = item['status'] == 'Aberto';
                            final double saldoInicial = double.tryParse(item['saldo_inicial']?.toString() ?? '0') ?? 0.0;
                            final double saldoFinal = double.tryParse(item['saldo_final']?.toString() ?? '0') ?? 0.0;
                            final String strAbertura = _formatarData(item['data_abertura']);
                            final String strFechamento = aberto ? 'Em andamento' : _formatarData(item['data_fechamento']);

                            return Padding(
                              padding: EdgeInsets.all(isMobile ? 16.0 : 20.0),
                              child: isMobile
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Caixa #${item['id']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                                            Row(
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.print, color: Colors.blueAccent),
                                                  onPressed: () => _gerarRelatorioCaixaPdf(item),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: aberto ? Colors.green.withOpacity(0.15) : Colors.grey.withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(20),
                                                    border: Border.all(color: aberto ? Colors.green : Colors.grey),
                                                  ),
                                                  child: Text(
                                                    item['status'].toString().toUpperCase(),
                                                    style: TextStyle(color: aberto ? Colors.green : textSecColor, fontSize: 11, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text('Abertura: $strAbertura', style: TextStyle(fontSize: 13, color: textSecColor)),
                                        Text('Fechamento: $strFechamento', style: TextStyle(fontSize: 13, color: textSecColor)),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Inicial: R\$ ${saldoInicial.toStringAsFixed(2).replaceAll('.', ',')}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
                                            Text('Final: R\$ ${saldoFinal.toStringAsFixed(2).replaceAll('.', ',')}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: aberto ? Colors.green : accentColor)),
                                          ],
                                        ),
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: aberto ? Colors.green.withOpacity(0.15) : Colors.grey.withOpacity(0.15),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            aberto ? Icons.lock_open : Icons.lock,
                                            color: aberto ? Colors.green : Colors.grey,
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          flex: 2,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Caixa #${item['id']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                                              const SizedBox(height: 2),
                                              Text(
                                                aberto ? 'Em andamento' : 'Encerrado',
                                                style: TextStyle(fontSize: 12, color: aberto ? Colors.green : textSecColor, fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Abertura: $strAbertura', style: TextStyle(fontSize: 13, color: textSecColor)),
                                              Text('Fechamento: $strFechamento', style: TextStyle(fontSize: 13, color: textSecColor)),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text('Inicial: R\$ ${saldoInicial.toStringAsFixed(2).replaceAll('.', ',')}', style: TextStyle(fontSize: 12, color: textSecColor)),
                                              Text('Final: R\$ ${saldoFinal.toStringAsFixed(2).replaceAll('.', ',')}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: accentColor)),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        IconButton(
                                          icon: const Icon(Icons.print, color: Colors.blueAccent),
                                          tooltip: 'Imprimir Relatório',
                                          onPressed: () => _gerarRelatorioCaixaPdf(item),
                                        ),
                                      ],
                                    ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 120), 
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