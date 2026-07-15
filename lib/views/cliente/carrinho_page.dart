import 'dart:convert';
import 'package:flutter/material.dart';
import 'finalizar_pedido_page.dart';

class CarrinhoPage extends StatefulWidget {
  final Map<String, dynamic> catalogo;
  final Map<int, double> carrinho;
  final Map<int, String> observacoes;
  final Map<int, List<int>> adicionaisEscolhidos;

  const CarrinhoPage({
    super.key,
    required this.catalogo,
    required this.carrinho,
    required this.observacoes,
    required this.adicionaisEscolhidos,
  });

  @override
  State<CarrinhoPage> createState() => _CarrinhoPageState();
}

class _CarrinhoPageState extends State<CarrinhoPage> {
  final double _pedidoMinimo = 10.0;

  Color _hexToColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF4A0E4E);
    }
  }

  double get _valorTotal {
    double total = 0.0;
    final produtos = widget.catalogo['produtos'] as List;
    for (var p in produtos) {
      int id = p['id'] ?? p['ID'];
      if (widget.carrinho.containsKey(id)) {
        double qtdOuPeso = widget.carrinho[id]!;
        double precoProduto = double.tryParse(p['price'].toString()) ?? 0.0;
        String un = (p['unidade_medida'] ?? '').toString().toLowerCase();
        bool isPeso = un == 'kg' || un == 'grama' || un == 'g';

        total += isPeso ? (precoProduto / 1000.0) * qtdOuPeso : precoProduto * qtdOuPeso;

        if (widget.adicionaisEscolhidos.containsKey(id) && p['adicionais'] != null && p['adicionais'] is List) {
          final escolhas = widget.adicionaisEscolhidos[id]!;
          for (var ad in p['adicionais']) {
            if (escolhas.contains(ad['id'] ?? ad['ID'])) {
              double precoAd = double.tryParse(ad['price'].toString()) ?? 0.0;
              total += precoAd * (isPeso ? 1 : qtdOuPeso);
            }
          }
        }
      }
    }
    return total;
  }

  void _atualizarQuantidade(int id, double novaQtd) {
    setState(() {
      if (novaQtd <= 0) {
        widget.carrinho.remove(id);
        widget.observacoes.remove(id);
        widget.adicionaisEscolhidos.remove(id);
        if (widget.carrinho.isEmpty) {
          Navigator.pop(context);
        }
      } else {
        widget.carrinho[id] = novaQtd;
      }
    });
  }

  void _irParaCheckout() async {
    if (_valorTotal < _pedidoMinimo) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'O pedido mínimo para entrega é de R\$ ${_pedidoMinimo.toStringAsFixed(2).replaceAll('.', ',')}!',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FinalizarPedidoPage(
          catalogo: widget.catalogo,
          carrinho: widget.carrinho,
          observacoes: widget.observacoes,
          adicionaisEscolhidos: widget.adicionaisEscolhidos,
          valorTotal: _valorTotal,
        ),
      ),
    );

    if (result == true) {
      if (!mounted) return;
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final corTema = _hexToColor(widget.catalogo['cor_theme'] ?? widget.catalogo['cor_tema'] ?? '#4A0E4E');
    final corLetras = _hexToColor(widget.catalogo['cor_letras'] ?? '#FFFFFF');
    final produtos = widget.catalogo['produtos'] as List;

    final itensNoCarrinho = produtos.where((p) => widget.carrinho.containsKey(p['id'] ?? p['ID'])).toList();
    final bool atingeMinimo = _valorTotal >= _pedidoMinimo;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: corTema,
        foregroundColor: corLetras,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: isMobile ? 36 : 40,
              height: isMobile ? 36 : 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
                image: const DecorationImage(image: AssetImage('assets/images/logo.jpg'), fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Text('MEU CARRINHO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: isMobile ? 16 : 20, letterSpacing: 1)),
          ],
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
          child: itensNoCarrinho.isEmpty
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.remove_shopping_cart_outlined, size: isMobile ? 60 : 80, color: Colors.grey[400]),
                    const SizedBox(height: 24),
                    Text('Seu carrinho está vazio', style: TextStyle(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: corTema, foregroundColor: corLetras),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('VOLTAR AO CARDÁPIO'),
                    )
                  ],
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        itemCount: itensNoCarrinho.length,
                        separatorBuilder: (_, __) => Divider(height: isMobile ? 24 : 32),
                        itemBuilder: (context, index) {
                          final p = itensNoCarrinho[index];
                          int id = p['id'] ?? p['ID'];
                          double qtdOuPeso = widget.carrinho[id]!;
                          String obs = widget.observacoes[id] ?? '';
                          double preco = double.tryParse(p['price'].toString()) ?? 0.0;
                          String un = (p['unidade_medida'] ?? '').toString().toLowerCase();
                          bool isPeso = un == 'kg' || un == 'grama' || un == 'g';

                          double subtotalItem = isPeso ? (preco / 1000.0) * qtdOuPeso : preco * qtdOuPeso;
                          
                          List<String> nomesAdicionais = [];
                          if (widget.adicionaisEscolhidos.containsKey(id) && p['adicionais'] != null && p['adicionais'] is List) {
                            final escolhas = widget.adicionaisEscolhidos[id]!;
                            for (var ad in p['adicionais']) {
                              if (escolhas.contains(ad['id'] ?? ad['ID'])) {
                                double precoAd = double.tryParse(ad['price'].toString()) ?? 0.0;
                                subtotalItem += precoAd * (isPeso ? 1 : qtdOuPeso);
                                nomesAdicionais.add(ad['name'] ?? '');
                              }
                            }
                          }

                          final String urlCompleta = p['image_url'] ?? '';
                          final List<String> fotos = urlCompleta.split('|||').where((s) => s.isNotEmpty).toList();

                          if (isMobile) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 70,
                                      height: 70,
                                      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!)),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: fotos.isEmpty
                                            ? Icon(Icons.fastfood, color: Colors.grey[400])
                                            : fotos.first.startsWith('data:image')
                                                ? Image.memory(base64Decode(fotos.first.split(',')[1]), fit: BoxFit.cover)
                                                : Image.network(fotos.first, fit: BoxFit.cover),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(p['name'], style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: corTema), maxLines: 2, overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 4),
                                          Text(isPeso ? '${qtdOuPeso.toInt()}g' : '${qtdOuPeso.toInt()} unidade(s)', style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.bold)),
                                          if (nomesAdicionais.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2.0),
                                              child: Text('+ ${nomesAdicionais.join(", ")}', style: TextStyle(color: Colors.orange[800], fontSize: 12, fontWeight: FontWeight.bold)),
                                            ),
                                          const SizedBox(height: 4),
                                          Text('R\$ ${subtotalItem.toStringAsFixed(2).replaceAll('.', ',')}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (obs.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text('📝 Obs: $obs', style: TextStyle(color: Colors.purple[700], fontSize: 13, fontStyle: FontStyle.italic)),
                                  ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    if (!isPeso)
                                      Container(
                                        height: 36,
                                        decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(6)),
                                        child: Row(
                                          children: [
                                            IconButton(padding: EdgeInsets.zero, icon: const Icon(Icons.remove, size: 18), onPressed: () => _atualizarQuantidade(id, qtdOuPeso - 1)),
                                            Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0), child: Text('${qtdOuPeso.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold))),
                                            IconButton(padding: EdgeInsets.zero, icon: const Icon(Icons.add, size: 18), onPressed: () => _atualizarQuantidade(id, qtdOuPeso + 1)),
                                          ],
                                        ),
                                      )
                                    else
                                      const SizedBox.shrink(),
                                    TextButton.icon(
                                      onPressed: () => _atualizarQuantidade(id, 0),
                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                      label: const Text('Remover', style: TextStyle(color: Colors.red)),
                                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                    )
                                  ],
                                ),
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!)),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: fotos.isEmpty
                                      ? Icon(Icons.fastfood, color: Colors.grey[400])
                                      : fotos.first.startsWith('data:image')
                                          ? Image.memory(base64Decode(fotos.first.split(',')[1]), fit: BoxFit.cover)
                                          : Image.network(fotos.first, fit: BoxFit.cover),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p['name'], style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: corTema)),
                                    const SizedBox(height: 4),
                                    Text(isPeso ? '${qtdOuPeso.toInt()}g' : '${qtdOuPeso.toInt()} unidade(s)', style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.bold)),
                                    if (nomesAdicionais.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Text('+ ${nomesAdicionais.join(", ")}', style: TextStyle(color: Colors.orange[800], fontSize: 13, fontWeight: FontWeight.bold)),
                                      ),
                                    if (obs.isNotEmpty)
                                      Padding(padding: const EdgeInsets.only(top: 8.0), child: Text('📝 Obs: $obs', style: TextStyle(color: Colors.purple[700], fontSize: 13, fontStyle: FontStyle.italic))),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('R\$ ${subtotalItem.toStringAsFixed(2).replaceAll('.', ',')}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                                  const SizedBox(height: 8),
                                  if (!isPeso)
                                    Container(
                                      height: 36,
                                      decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(6)),
                                      child: Row(
                                        children: [
                                          IconButton(padding: EdgeInsets.zero, icon: const Icon(Icons.remove, size: 16), onPressed: () => _atualizarQuantidade(id, qtdOuPeso - 1)),
                                          Padding(padding: const EdgeInsets.symmetric(horizontal: 4.0), child: Text('${qtdOuPeso.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold))),
                                          IconButton(padding: EdgeInsets.zero, icon: const Icon(Icons.add, size: 16), onPressed: () => _atualizarQuantidade(id, qtdOuPeso + 1)),
                                        ],
                                      ),
                                    ),
                                  TextButton.icon(
                                    onPressed: () => _atualizarQuantidade(id, 0),
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                    label: const Text('Remover', style: TextStyle(color: Colors.red)),
                                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                  )
                                ],
                              )
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(isMobile ? 16 : 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: corTema.withOpacity(0.2)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: isMobile ? 16 : 20)),
                              Text('R\$ ${_valorTotal.toStringAsFixed(2).replaceAll('.', ',')}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: isMobile ? 22 : 28, color: corTema)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: isMobile ? 50 : 60,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: atingeMinimo ? const Color(0xFF25D366) : Colors.grey,
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              ),
                              onPressed: _irParaCheckout,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    atingeMinimo 
                                        ? 'CONTINUAR PARA PAGAMENTO' 
                                        : 'FALTA R\$ ${(_pedidoMinimo - _valorTotal).toStringAsFixed(2).replaceAll('.', ',')} P/ PEDIDO MÍNIMO', 
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: isMobile ? 12 : 16, letterSpacing: isMobile ? 0 : 1),
                                  ),
                                  const SizedBox(width: 8),
                                  if (atingeMinimo) Icon(Icons.arrow_forward_ios, size: isMobile ? 16 : 20),
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                    )
                  ],
                ),
        ),
      ),
    );
  }
}