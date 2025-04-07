import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

Future<Map<String, dynamic>> fetchUserProfile({required String token}) async {
  final url = Uri.parse('${config['baseUrl']}/users/@me');

  final response = await http.get(
    url,
    headers: {'Authorization': token, 'Content-Type': 'application/json'},
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    final errorBody = jsonDecode(response.body);
    final errorMessage = errorBody['message'] ?? 'ユーザー情報の取得に失敗しました';
    throw Exception(errorMessage);
  }
}
