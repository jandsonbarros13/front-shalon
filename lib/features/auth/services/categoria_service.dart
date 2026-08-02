import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:acaiteria_front/core/constants/api_constants.dart';

class CategoriaService {
  final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Buscar todas as categorias
  Future<List<dynamic>> listarCategorias() async {
    try {
      final response = await http.get(Uri.parse(ApiConstants.categorias), headers: _headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Erro ao listar categorias: $e');
    }
    return [];
  }

  // Cadastrar nova categoria
  Future<bool> cadastrarCategoria(String nome) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.categorias),
        headers: _headers,
        body: jsonEncode({'nome': nome.trim()}),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {}
    return false;
  }

  // Editar categoria existente
  Future<bool> editarCategoria(int id, String nome) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConstants.categorias}/$id'),
        headers: _headers,
        body: jsonEncode({'nome': nome.trim()}),
      );
      return response.statusCode == 200;
    } catch (_) {}
    return false;
  }

  // Deletar categoria
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
}