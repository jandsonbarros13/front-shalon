import 'package:flutter/material.dart';
import 'package:acaiteria_front/features/auth/services/frete_service.dart';

class CadastroFretePage extends StatefulWidget {
  const CadastroFretePage({super.key});

  @override
  State<CadastroFretePage> createState() => _CadastroFretePageState();
}

class _CadastroFretePageState extends State<CadastroFretePage> {
  final _freteService = FreteService();
  bool _carregando = true;
  List<dynamic> _bairros = [];

  @override
  void initState() {
    super.initState();
    _buscarDadosDoBanco();
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

  @override
  Widget build(BuildContext context) {
    const corTema = Color(0xFF4A0E4E);

    return Scaffold(
      body: Padding(
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
                      : ListView.separated(
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
          ],
        ),
      ),
    );
  }
}