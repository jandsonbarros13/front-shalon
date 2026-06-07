import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../../../core/constants/api_constants.dart';

class ProdutoService {
  final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Future<List<dynamic>> buscarProdutos({String nome = ''}) async {
    final url = Uri.parse('${ApiConstants.produtos}?nome=$nome');
    try {
      final response = await http.get(url, headers: _headers).timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>> cadastrarProduto(Map<String, dynamic> dados) async {
    final url = Uri.parse(ApiConstants.produtos);
    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(dados),
      ).timeout(const Duration(seconds: 60));
      return jsonDecode(response.body);
    } on TimeoutException {
      return {'success': false, 'message': 'Tempo limite excedido. Imagem muito pesada?'};
    } catch (e) {
      return {'success': false, 'message': 'Erro ao conectar ao servidor Go.'};
    }
  }

  Future<Map<String, dynamic>> editarProduto(int id, Map<String, dynamic> dados) async {
    final url = Uri.parse('${ApiConstants.produtos}/$id');
    try {
      final response = await http.put(
        url,
        headers: _headers,
        body: jsonEncode(dados),
      ).timeout(const Duration(seconds: 60));
      if (response.body.isNotEmpty) {
        return jsonDecode(response.body);
      }
    } catch (_) {}
    return {'success': true};
  }

  Future<Map<String, dynamic>> deletarProduto(int id) async {
    final url = Uri.parse('${ApiConstants.produtos}/$id');
    try {
      final response = await http.delete(url, headers: _headers).timeout(const Duration(seconds: 60));
      if (response.body.isNotEmpty) {
        return jsonDecode(response.body);
      }
    } catch (_) {}
    return {'success': true};
  }
}