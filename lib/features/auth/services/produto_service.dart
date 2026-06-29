import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:acaiteria_front/core/constants/api_constants.dart';

class ProdutoService {
  final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Future<Map<String, dynamic>> buscarProdutos(int pagina, {String nome = '', int limit = 8, bool semFoto = false}) async {
    final url = Uri.parse('${ApiConstants.produtos}?page=$pagina&limit=$limit&nome=$nome&sem_foto=$semFoto');
    try {
      final response = await http.get(url, headers: _headers);
      
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        
        if (decoded is Map) {
          return {
            'produtos': decoded['produtos'] is List ? decoded['produtos'] : [],
            'total': decoded['total'] ?? 0,
          };
        } else if (decoded is List) {
          return {
            'produtos': decoded,
            'total': decoded.length,
          };
        }
      } else {
        print("Erro na resposta do Servidor Go: Status ${response.statusCode}");
      }
    } catch (e, stacktrace) {
      print("🚨 ERRO CRÍTICO AO LER OS PRODUTOS: $e");
      print(stacktrace);
    }
    
    return {'produtos': [], 'total': 0};
  }

  Future<Map<String, dynamic>> cadastrarProduto(Map<String, dynamic> dados) async {
    final url = Uri.parse(ApiConstants.produtos);
    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(dados),
      );
      return jsonDecode(response.body);
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
      );
      if (response.body.isNotEmpty) {
        return jsonDecode(response.body);
      }
    } catch (_) {}
    return {'success': true};
  }

  Future<Map<String, dynamic>> deletarProduto(int id) async {
    final url = Uri.parse('${ApiConstants.produtos}/$id');
    try {
      final response = await http.delete(url, headers: _headers);
      if (response.body.isNotEmpty) {
        return jsonDecode(response.body);
      }
    } catch (_) {}
    return {'success': true};
  }
}