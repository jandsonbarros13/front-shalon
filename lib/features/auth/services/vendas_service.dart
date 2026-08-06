import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:acaiteria_front/core/constants/api_constants.dart';

class VendasService {
  String get _urlBaseLimpa {
    String url = ApiConstants.baseUrl.trim();
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    if (url.endsWith('/api')) url = url.substring(0, url.length - 4);
    return url;
  }

  Future<Map<String, dynamic>> finalizarVendaBalcao(Map<String, dynamic> dadosVenda) async {
    final url = Uri.parse('$_urlBaseLimpa/api/vendas');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(dadosVenda),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'Erro ao processar venda no servidor'};
    } catch (_) {
      return {'success': false, 'message': 'Erro de conexão com o servidor Go'};
    }
  }

  Future<Map<String, dynamic>> listarVendas(int pagina, {int limit = 10}) async {
    final url = Uri.parse('$_urlBaseLimpa/api/vendas?page=$pagina&limit=$limit');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'vendas': [], 'total': 0};
    } catch (_) {
      return {'vendas': [], 'total': 0};
    }
  }

  Future<bool> atualizarStatus(int id, String novoStatus) async {
    final url = Uri.parse('$_urlBaseLimpa/api/vendas/$id');
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