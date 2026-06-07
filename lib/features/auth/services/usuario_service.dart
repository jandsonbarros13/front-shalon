import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:acaiteria_front/core/constants/api_constants.dart';

class UsuarioService {
  String get _baseUrl {
    String url = ApiConstants.baseUrl.trim();
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.endsWith('/api')) {
      url = url.substring(0, url.length - 4);
    }
    return url;
  }

  Future<List<dynamic>> listarUsuarios() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/usuarios'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print(e);
    }
    return [];
  }

  Future<bool> adicionarUsuario(Map<String, dynamic> usuario) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/usuarios'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(usuario),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<bool> editarUsuario(Map<String, dynamic> usuario) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/api/usuarios'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(usuario),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> excluirUsuario(int id) async {
    try {
      final response = await http.delete(Uri.parse('$_baseUrl/api/usuarios/$id'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}