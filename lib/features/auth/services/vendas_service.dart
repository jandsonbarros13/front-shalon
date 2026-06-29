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
    final url = Uri.parse('$_urlBaseLimpa/api/pedidos');
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
}