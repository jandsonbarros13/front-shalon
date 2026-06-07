import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';

class CatalogoService {
  final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Future<List<dynamic>> listarCatalogos() async {
    final url = Uri.parse('${ApiConstants.baseUrl}/catalogo');
    try {
      final response = await http.get(url, headers: _headers).timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) {
        final dadosDecodificados = jsonDecode(response.body);
        if (dadosDecodificados is List) {
          return dadosDecodificados;
        } else if (dadosDecodificados is Map && dadosDecodificados['dados'] != null) {
          return [dadosDecodificados['dados']];
        }
      }
    } on TimeoutException {
      return [];
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>> buscarPorId(int id) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/catalogo/$id');
    try {
      final response = await http.get(url, headers: _headers).timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}
    return {};
  }

  Future<Map<String, dynamic>> salvarCatalogo(Map<String, dynamic> dados) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/catalogo');
    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(dados),
      ).timeout(const Duration(seconds: 60));
      
      return jsonDecode(response.body);
    } on TimeoutException {
      return {'success': false, 'message': 'Tempo limite excedido. Imagem muito pesada?'};
    } catch (_) {
      return {'success': false, 'message': 'Erro de conexão com o servidor.'};
    }
  }

  Future<Map<String, dynamic>> deletarCatalogo(int id) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/catalogo/$id');
    try {
      final response = await http.delete(url, headers: _headers).timeout(const Duration(seconds: 60));
      
      if (response.statusCode == 200 || response.statusCode == 204) {
         return {'success': true, 'message': 'Catálogo excluído com sucesso.'};
      }
      return {'success': false, 'message': 'Falha ao excluir. Status: ${response.statusCode}'};
    } on TimeoutException {
      return {'success': false, 'message': 'Tempo limite excedido ao tentar excluir.'};
    } catch (_) {
      return {'success': false, 'message': 'Erro de CORS ou servidor offline.'};
    }
  }
}