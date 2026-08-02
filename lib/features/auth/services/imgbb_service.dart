import 'dart:convert';
import 'package:http/http.dart' as http;

class ImgbbService {
  // Sua chave da API já configurada
  static const String _apiKey = '3d6eac9b5993c4dc6d79e5993d5365af'; 

  static Future<String?> uploadImage(String base64Image) async {
    final url = Uri.parse('https://api.imgbb.com/1/upload?key=$_apiKey');
    
    try {
      final response = await http.post(url, body: {
        'image': base64Image, 
      });

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        // Retorna a URL limpa da imagem (ex: https://i.ibb.co/abcd/foto.jpg)
        return jsonResponse['data']['url']; 
      } else {
        print("Erro ImgBB: ${response.body}");
      }
    } catch (e) {
      print("Erro de conexão no upload para ImgBB: $e");
    }
    return null; 
  }
}