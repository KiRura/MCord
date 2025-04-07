import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  final Map<String, dynamic>? userProfile;
  final bool isLoading;

  const ProfileScreen({super.key, this.userProfile, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (userProfile == null) {
      return const Center(
        child: Text('プロフィール情報を読み込み中...', style: TextStyle(fontSize: 18)),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),

            // アバター
            userProfile!['avatar'] != null
                ? CircleAvatar(
                  radius: 50,
                  backgroundImage: NetworkImage(
                    'https://cdn.discordapp.com/avatars/${userProfile!['id']}/${userProfile!['avatar']}.png',
                  ),
                )
                : CircleAvatar(
                  radius: 50,
                  child: Text(
                    userProfile!['username'][0].toUpperCase(),
                    style: const TextStyle(fontSize: 32),
                  ),
                ),

            const SizedBox(height: 16),

            // ユーザー名
            Text(
              userProfile!['username'],
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            // グローバル名（存在する場合）
            if (userProfile!['global_name'] != null) ...[
              const SizedBox(height: 4),
              Text(
                userProfile!['global_name'],
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ユーザーID
            _buildInfoRow('ID', userProfile!['id']),

            // botフラグ
            _buildInfoRow(
              'Botアカウント',
              userProfile!['bot'] == true ? 'はい' : 'いいえ',
            ),

            // アプリケーション情報（あれば）
            if (userProfile!['application'] != null)
              _buildInfoRow('アプリケーション', userProfile!['application']['name']),

            const SizedBox(height: 32),

            // 作成日時
            _buildInfoRow(
              '作成日時',
              _formatSnowflakeTimestamp(userProfile!['id']),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  // Discordのスノーフレークからタイムスタンプを計算
  String _formatSnowflakeTimestamp(String snowflake) {
    try {
      final snowflakeInt = BigInt.parse(snowflake);
      final timestamp =
          ((snowflakeInt >> 22) + BigInt.from(1420070400000)).toInt();
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return '${date.year}年${date.month}月${date.day}日';
    } catch (e) {
      return '不明';
    }
  }
}
