import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/constants/api_constants.dart';

class AuthService {
  final http.Client _client = http.Client();

  Future<Map<String, dynamic>> login(String username, String password) async {
    final url = Uri.parse(ApiConstants.login);

    try {
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Sucesso',
          'token': responseData['token']
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Erro de autenticação'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Não foi possível conectar ao servidor Go. Verifique o terminal!'
      };
    }
  }
}