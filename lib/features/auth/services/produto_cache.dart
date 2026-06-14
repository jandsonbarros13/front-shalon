import 'package:flutter/material.dart';
import 'package:acaiteria_front/features/auth/services/produto_service.dart';

class ProdutoCache extends ChangeNotifier {
  static final ProdutoCache _instance = ProdutoCache._internal();
  factory ProdutoCache() => _instance;
  ProdutoCache._internal();

  final _produtoService = ProdutoService();
  
  List<dynamic> _produtos = [];
  bool _carregado = false;
  bool _carregando = false;

  List<dynamic> get produtos => _produtos;
  bool get carregado => _carregado;
  bool get carregando => _carregando;

  Future<void> inicializarCache() async {
    if (_carregando) return;
    _carregando = true;
    notifyListeners();

    try {
      final resultado = await _produtoService.buscarProdutos(1, limit: 1000);
      final dados = resultado['produtos'] as List? ?? [];
      if (dados != null) {
        _produtos = List<dynamic>.from(dados);
        _carregado = true;
      }
    } catch (e) {
      debugPrint("Erro ao alimentar cache local: $e");
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  List<dynamic> obterPorCategoria(String categoria, {String filtroNome = ''}) {
    return _produtos.where((p) {
      final bateCategoria = p['category'] == categoria;
      final bateNome = p['name'].toString().toLowerCase().contains(filtroNome.toLowerCase());
      return bateCategoria && bateNome;
    }).toList();
  }

  List<dynamic> obterProdutosParaCombo({String filtroNome = ''}) {
    return _produtos.where((p) {
      final naoEAdicionalNemCombo = p['category'] != 'Adicionais' && p['category'] != 'Combos';
      final bateNome = p['name'].toString().toLowerCase().contains(filtroNome.toLowerCase());
      return naoEAdicionalNemCombo && bateNome;
    }).toList();
  }

  void invalidarEAtualizar(dynamic produtoEditadoOuNovo, {bool isDelecao = false, int? idDeletado}) {
    if (isDelecao && idDeletado != null) {
      _produtos.removeWhere((p) => p['id'] == idDeletado);
    } else if (produtoEditadoOuNovo != null) {
      final index = _produtos.indexWhere((p) => p['id'] == (produtoEditadoOuNovo['id'] ?? produtoEditadoOuNovo['ID']));
      if (index != -1) {
        _produtos[index] = produtoEditadoOuNovo;
      } else {
        _produtos.insert(0, produtoEditadoOuNovo);
      }
    }
    notifyListeners();
  }
}