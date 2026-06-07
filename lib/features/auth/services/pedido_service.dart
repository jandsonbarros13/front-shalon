import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:acaiteria_front/core/constants/api_constants.dart';

class PedidoService {
  String get _urlBaseLimpa {
    String url = ApiConstants.baseUrl.trim();
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    if (url.endsWith('/api')) url = url.substring(0, url.length - 4);
    return url;
  }

  Future<Map<String, dynamic>> salvarPedido(Map<String, dynamic> dados) async {
    final url = Uri.parse('$_urlBaseLimpa/api/pedidos');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(dados),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'Erro no servidor'};
    } catch (_) {
      return {'success': false, 'message': 'Erro de conexão'};
    }
  }

  Future<List<dynamic>> listarPedidos() async {
    final url = Uri.parse('$_urlBaseLimpa/api/pedidos');
    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}
    return [];
  }

  Future<bool> atualizarStatus(int id, String novoStatus) async {
    final url = Uri.parse('$_urlBaseLimpa/api/pedidos/$id');
    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': novoStatus}),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}