import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mcord/api/config.dart';

// トークンを使ってユーザー情報を取得する関数
Future<Map<String, dynamic>> loginWithToken({required String token}) async {
  final response = await http.get(
    Uri.parse('${config['baseUrl']}/users/@me'),
    headers: {'Content-Type': 'application/json', 'Authorization': token},
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('トークンでのログインに失敗しました: ${response.statusCode}');
  }
}
