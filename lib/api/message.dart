import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

/// チャンネルのメッセージを取得する
Future<List<dynamic>> fetchMessages({
  required String token,
  required String channelId,
  int limit = 50,
  String? before,
  String? after,
  String? around,
}) async {
  final queryParams = <String, String>{'limit': limit.toString()};

  if (before != null) queryParams['before'] = before;
  if (after != null) queryParams['after'] = after;
  if (around != null) queryParams['around'] = around;

  final uri = Uri.parse(
    '${config['baseUrl']}/channels/$channelId/messages',
  ).replace(queryParameters: queryParams);

  final response = await http.get(
    uri,
    headers: {'Authorization': token, 'Content-Type': 'application/json'},
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    final errorBody = jsonDecode(response.body);
    throw Exception(errorBody['message'] ?? 'メッセージの取得に失敗しました');
  }
}

/// メッセージを送信する
Future<Map<String, dynamic>> sendMessage({
  required String token,
  required String channelId,
  required String content,
  List<String>? attachmentUrls,
}) async {
  final Map<String, dynamic> body = {'content': content};

  if (attachmentUrls != null && attachmentUrls.isNotEmpty) {
    // 添付ファイルの処理（今回は実装しません）
  }

  final response = await http.post(
    Uri.parse('${config['baseUrl']}/channels/$channelId/messages'),
    headers: {'Authorization': token, 'Content-Type': 'application/json'},
    body: jsonEncode(body),
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    final errorBody = jsonDecode(response.body);
    throw Exception(errorBody['message'] ?? 'メッセージの送信に失敗しました');
  }
}

/// メッセージを編集する
Future<Map<String, dynamic>> editMessage({
  required String token,
  required String channelId,
  required String messageId,
  required String content,
}) async {
  final response = await http.patch(
    Uri.parse('${config['baseUrl']}/channels/$channelId/messages/$messageId'),
    headers: {'Authorization': token, 'Content-Type': 'application/json'},
    body: jsonEncode({'content': content}),
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    final errorBody = jsonDecode(response.body);
    throw Exception(errorBody['message'] ?? 'メッセージの編集に失敗しました');
  }
}

/// メッセージを削除する
Future<void> deleteMessage({
  required String token,
  required String channelId,
  required String messageId,
}) async {
  final response = await http.delete(
    Uri.parse('${config['baseUrl']}/channels/$channelId/messages/$messageId'),
    headers: {'Authorization': token},
  );

  if (response.statusCode != 204) {
    try {
      final errorBody = jsonDecode(response.body);
      throw Exception(errorBody['message'] ?? 'メッセージの削除に失敗しました');
    } catch (e) {
      throw Exception('メッセージの削除に失敗しました');
    }
  }
}
