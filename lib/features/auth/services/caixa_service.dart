import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:acaiteria_front/core/constants/api_constants.dart';

class CaixaService {
  final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Buscar status atual do caixa
  Future<Map<String, dynamic>> obterStatusCaixa() async {
    try {
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/caixa/status'), headers: _headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'isAberto': false, 'mensagem': 'Erro ao carregar.'};
    } catch (e) {
      print('Erro ao obter status do caixa: $e');
      return {'isAberto': false, 'mensagem': 'Erro de conexão.'};
    }
  }

  // Listar histórico de aberturas e fechamentos
  Future<List<dynamic>> listarHistorico() async {
    try {
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/caixa/historico'), headers: _headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Erro ao listar histórico do caixa: $e');
    }
    return [];
  }

  // Abrir o caixa
  Future<bool> abrirCaixa(double saldoInicial) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/caixa/abrir'),
        headers: _headers,
        body: jsonEncode({'saldo_inicial': saldoInicial}),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Erro ao abrir o caixa: $e');
    }
    return false;
  }

  // Fechar o caixa
  Future<bool> fecharCaixa() async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/caixa/fechar'),
        headers: _headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Erro ao fechar o caixa: $e');
    }
    return false;
  }

  // Registrar Sangria ou Suprimento
  Future<bool> lancarMovimentacao(String tipo, double valor, String motivo) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/caixa/movimentacao'),
        headers: _headers,
        body: jsonEncode({
          'tipo': tipo,
          'valor': valor,
          'motivo': motivo.trim()
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Erro ao lançar movimentação: $e');
    }
    return false;
  }
}