import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../../../core/constants/api_constants.dart';

class FreteService {
  final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  String get _urlBaseLimpa {
    final base = ApiConstants.produtos.replaceAll('produtos', 'fretes');
    return base.endsWith('/') ? base : '$base/';
  }

  Future<List<dynamic>> listarFretesDoBanco() async {
    try {
      final response = await http.get(Uri.parse(_urlBaseLimpa), headers: _headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}
    return [];
  }

  Future<bool> atualizarStatusETaxaDoBairro(int id, double taxa, bool ativo) async {
    try {
      final response = await http.put(
        Uri.parse('$_urlBaseLimpa$id'),
        headers: _headers,
        body: jsonEncode({
          'taxa': taxa,
          'ativo': ativo,
        }),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}