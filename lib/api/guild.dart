import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

Future<List<dynamic>> fetchUserGuilds({required String token}) async {
  final url = Uri.parse('${config['baseUrl']}/users/@me/guilds');

  final response = await http.get(
    url,
    headers: {'Authorization': token, 'Content-Type': 'application/json'},
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    final errorBody = jsonDecode(response.body);
    final errorMessage = errorBody['message'] ?? 'ギルド一覧の取得に失敗しました';
    throw Exception(errorMessage);
  }
}

Future<Map<String, dynamic>> fetchGuildDetails({
  required String token,
  required String guildId,
}) async {
  final url = Uri.parse('${config['baseUrl']}/guilds/$guildId');

  final response = await http.get(
    url,
    headers: {'Authorization': token, 'Content-Type': 'application/json'},
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    final errorBody = jsonDecode(response.body);
    final errorMessage = errorBody['message'] ?? 'ギルド情報の取得に失敗しました';
    throw Exception(errorMessage);
  }
}

Future<List<dynamic>> fetchGuildChannels({
  required String token,
  required String guildId,
}) async {
  final url = Uri.parse('${config['baseUrl']}/guilds/$guildId/channels');

  final response = await http.get(
    url,
    headers: {'Authorization': token, 'Content-Type': 'application/json'},
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    final errorBody = jsonDecode(response.body);
    final errorMessage = errorBody['message'] ?? 'チャンネル一覧の取得に失敗しました';
    throw Exception(errorMessage);
  }
}
