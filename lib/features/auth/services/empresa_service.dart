import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';

class EmpresaService {
  final String _baseUrl = ApiConstants.baseUrl;

  // Buscar configurações da empresa
  Future<Map<String, dynamic>?> obterEmpresa() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/empresa'));

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      } else {
        print('Erro ao buscar dados da empresa: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Erro de conexão ao buscar empresa: $e');
      return null;
    }
  }

  // Salvar/Atualizar configurações da empresa
  Future<bool> salvarEmpresa(Map<String, dynamic> dadosEmpresa) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/empresa'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(dadosEmpresa),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Erro ao salvar configurações da empresa: $e');
      return false;
    }
  }
}