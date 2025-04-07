import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:mcord/storage/token_storage.dart';
import 'package:mcord/main.dart';
import 'package:mcord/storage/settings_storage.dart';
import 'package:mcord/display_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;
  int _themeMode = 0; // 0: システム, 1: ライト, 2: ダーク
  bool _notifyChannelMessages = true;
  bool _notifyDirectMessages = true;
  bool _convertEmoticons = true;
  bool _animateEmojis = true;
  int _animateStickers = 0;
  bool _developerMode = false;
  String _appVersion = "1.0.0";

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _themeMode = await SettingsStorage.getThemeMode();
      _notifyChannelMessages = await SettingsStorage.getNotifyChannelMessages();
      _notifyDirectMessages = await SettingsStorage.getNotifyDirectMessages();
      _convertEmoticons = await SettingsStorage.getConvertEmoticons();
      _animateEmojis = await SettingsStorage.getAnimateEmojis();
      _animateStickers = await SettingsStorage.getAnimateStickers();
      _developerMode = await SettingsStorage.getDeveloperMode();
    } catch (e) {
      // エラー処理
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('設定の読み込みに失敗しました: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resetSettings() async {
    final bool confirm =
        await showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('設定のリセット'),
                content: const Text('すべての設定をデフォルトに戻しますか？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('キャンセル'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('リセット'),
                  ),
                ],
              ),
        ) ??
        false;

    if (confirm) {
      await SettingsStorage.resetAllSettings();
      // テーマの反映
      final themeNotifier = ThemeNotifier();
      await themeNotifier.loadThemeSettings();
      // 他の設定も再読み込み
      await _loadSettings();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('設定をリセットしました')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('設定')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            onPressed: _resetSettings,
            tooltip: '設定をリセット',
          ),
        ],
      ),
      body: ListView(
        children: [
          _buildSectionHeader('テーマ'),
          ListTile(
            title: const Text('アプリテーマ'),
            subtitle: Text(_getThemeModeText()),
            leading: const Icon(Icons.brightness_6),
            onTap: _showThemeModeDialog,
          ),

          // Androidの場合のみディスプレイ設定を表示
          if (Platform.isAndroid) ...[
            _buildSectionHeader('プラットフォーム依存の設定項目 - Android'),
            ListTile(
              title: const Text('リフレッシュレート'),
              subtitle: const Text('画面のリフレッシュレートを設定'),
              leading: const Icon(Icons.refresh),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DisplaySettingsScreen(),
                  ),
                );
              },
            ),
          ],

          _buildSectionHeader('通知設定'),
          SwitchListTile(
            title: const Text('チャンネルメッセージ'),
            subtitle: const Text('サーバーチャンネルのメッセージを通知する'),
            value: _notifyChannelMessages,
            onChanged: (value) async {
              await SettingsStorage.setNotifyChannelMessages(value);
              setState(() {
                _notifyChannelMessages = value;
              });
            },
          ),
          SwitchListTile(
            title: const Text('ダイレクトメッセージ'),
            subtitle: const Text('DMのメッセージを通知する'),
            value: _notifyDirectMessages,
            onChanged: (value) async {
              await SettingsStorage.setNotifyDirectMessages(value);
              setState(() {
                _notifyDirectMessages = value;
              });
            },
          ),

          _buildSectionHeader('表示設定'),
          SwitchListTile(
            title: const Text('絵文字変換'),
            subtitle: const Text('テキスト絵文字を自動的に絵文字に変換する'),
            value: _convertEmoticons,
            onChanged: (value) async {
              await SettingsStorage.setConvertEmoticons(value);
              setState(() {
                _convertEmoticons = value;
              });
            },
          ),
          SwitchListTile(
            title: const Text('アニメーション絵文字'),
            subtitle: const Text('アニメーション付き絵文字を表示する'),
            value: _animateEmojis,
            onChanged: (value) async {
              await SettingsStorage.setAnimateEmojis(value);
              setState(() {
                _animateEmojis = value;
              });
            },
          ),
          ListTile(
            title: const Text('ステッカーアニメーション'),
            subtitle: Text(_getAnimateStickersText()),
            leading: const Icon(Icons.sticky_note_2),
            onTap: _showAnimateStickersDialog,
          ),

          _buildSectionHeader('開発者設定'),
          SwitchListTile(
            title: const Text('開発者モード'),
            subtitle: const Text('開発者向けの追加機能を有効にする'),
            value: _developerMode,
            onChanged: (value) async {
              await SettingsStorage.setDeveloperMode(value);
              setState(() {
                _developerMode = value;
              });
            },
          ),

          _buildSectionHeader('アカウント'),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('ログアウト'),
            subtitle: const Text('アカウントからログアウトします'),
            onTap: _confirmLogout,
          ),

          _buildSectionHeader('情報'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('アプリ情報'),
            subtitle: Text('バージョン $_appVersion'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'MCord',
                applicationVersion: _appVersion,
                applicationIcon: const Icon(Icons.discord),
                children: [
                  const Text('Discord APIを利用したクライアントアプリです。'),
                  const SizedBox(height: 8),
                  const Text('このアプリはDiscordの公式アプリではありません。'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _getThemeModeText() {
    switch (_themeMode) {
      case 0:
        return 'システム設定に従う';
      case 1:
        return 'ライトモード';
      case 2:
        return 'ダークモード';
      default:
        return 'システム設定に従う';
    }
  }

  String _getAnimateStickersText() {
    switch (_animateStickers) {
      case 0:
        return '常にアニメーション';
      case 1:
        return 'インタラクション時のみ';
      case 2:
        return 'アニメーションなし';
      default:
        return '常にアニメーション';
    }
  }

  Future<void> _showThemeModeDialog() async {
    final result = await showDialog<int>(
      context: context,
      builder:
          (context) => SimpleDialog(
            title: const Text('アプリテーマ'),
            children: [
              RadioListTile<int>(
                title: const Text('システム設定に従う'),
                value: 0,
                groupValue: _themeMode,
                onChanged: (value) => Navigator.pop(context, value),
              ),
              RadioListTile<int>(
                title: const Text('ライトモード'),
                value: 1,
                groupValue: _themeMode,
                onChanged: (value) => Navigator.pop(context, value),
              ),
              RadioListTile<int>(
                title: const Text('ダークモード'),
                value: 2,
                groupValue: _themeMode,
                onChanged: (value) => Navigator.pop(context, value),
              ),
            ],
          ),
    );

    if (result != null) {
      // テーマの変更と通知
      final themeNotifier = ThemeNotifier();
      await themeNotifier.updateThemeMode(result);
      setState(() {
        _themeMode = result;
      });
    }
  }

  Future<void> _showAnimateStickersDialog() async {
    final result = await showDialog<int>(
      context: context,
      builder:
          (context) => SimpleDialog(
            title: const Text('ステッカーアニメーション'),
            children: [
              RadioListTile<int>(
                title: const Text('常にアニメーション'),
                value: 0,
                groupValue: _animateStickers,
                onChanged: (value) => Navigator.pop(context, value),
              ),
              RadioListTile<int>(
                title: const Text('インタラクション時のみ'),
                value: 1,
                groupValue: _animateStickers,
                onChanged: (value) => Navigator.pop(context, value),
              ),
              RadioListTile<int>(
                title: const Text('アニメーションなし'),
                value: 2,
                groupValue: _animateStickers,
                onChanged: (value) => Navigator.pop(context, value),
              ),
            ],
          ),
    );

    if (result != null) {
      await SettingsStorage.setAnimateStickers(result);
      setState(() {
        _animateStickers = result;
      });
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('ログアウト'),
            content: const Text('ログアウトしてもよろしいですか？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () async {
                  await TokenStorage.deleteToken();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginForm(),
                      ),
                      (route) => false,
                    );
                  }
                },
                child: const Text('ログアウト'),
              ),
            ],
          ),
    );
  }
}
