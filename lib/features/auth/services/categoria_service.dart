import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:acaiteria_front/core/constants/api_constants.dart';

class CategoriaService {
  final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Future<List<dynamic>> listarCategorias() async {
    try {
      final response = await http.get(Uri.parse(ApiConstants.categorias), headers: _headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}
    return [];
  }

  // AGORA RECEBE O PARÂMETRO 'permiteAdicionais'
  Future<bool> cadastrarCategoria(String nome, bool permiteAdicionais) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.categorias),
        headers: _headers,
        body: jsonEncode({'nome': nome.trim(), 'permite_adicionais': permiteAdicionais}),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {}
    return false;
  }

  // AGORA RECEBE O PARÂMETRO 'permiteAdicionais'
  Future<bool> editarCategoria(int id, String nome, bool permiteAdicionais) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConstants.categorias}/$id'),
        headers: _headers,
        body: jsonEncode({'nome': nome.trim(), 'permite_adicionais': permiteAdicionais}),
      );
      return response.statusCode == 200;
    } catch (_) {}
    return false;
  }

  Future<bool> deletarCategoria(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConstants.categorias}/$id'),
        headers: _headers,
      );
      return response.statusCode == 200;
    } catch (_) {}
    return false;
  }

  Future<bool> atualizarOrdem(List<int> ids) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConstants.categorias}/ordem'),
        headers: _headers,
        body: jsonEncode({'ids': ids}),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {}
    return false;
  }
}