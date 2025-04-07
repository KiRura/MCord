import 'package:shared_preferences/shared_preferences.dart';

class SettingsStorage {
  // キー定数
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyNotifyChannelMessages = 'notify_channel_messages';
  static const String _keyNotifyDirectMessages = 'notify_direct_messages';
  static const String _keyConvertEmoticons = 'convert_emoticons';
  static const String _keyAnimateEmojis = 'animate_emojis';
  static const String _keyAnimateStickers = 'animate_stickers';
  static const String _keyDeveloperMode = 'developer_mode';

  // デフォルト値
  static const int defaultThemeMode = 0; // 0: システム, 1: ライト, 2: ダーク
  static const bool defaultNotifyChannelMessages = true;
  static const bool defaultNotifyDirectMessages = true;
  static const bool defaultConvertEmoticons = true;
  static const bool defaultAnimateEmojis = true;
  static const int defaultAnimateStickers = 0; // 0: 常に表示, 1: インタラクション時のみ, 2: 無効
  static const bool defaultDeveloperMode = false;

  // テーマ設定
  static Future<int> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyThemeMode) ?? defaultThemeMode;
  }

  static Future<void> setThemeMode(int mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyThemeMode, mode);
  }

  // 通知設定
  static Future<bool> getNotifyChannelMessages() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotifyChannelMessages) ??
        defaultNotifyChannelMessages;
  }

  static Future<void> setNotifyChannelMessages(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifyChannelMessages, value);
  }

  static Future<bool> getNotifyDirectMessages() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotifyDirectMessages) ??
        defaultNotifyDirectMessages;
  }

  static Future<void> setNotifyDirectMessages(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifyDirectMessages, value);
  }

  // 表示設定
  static Future<bool> getConvertEmoticons() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyConvertEmoticons) ?? defaultConvertEmoticons;
  }

  static Future<void> setConvertEmoticons(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyConvertEmoticons, value);
  }

  static Future<bool> getAnimateEmojis() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAnimateEmojis) ?? defaultAnimateEmojis;
  }

  static Future<void> setAnimateEmojis(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAnimateEmojis, value);
  }

  static Future<int> getAnimateStickers() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyAnimateStickers) ?? defaultAnimateStickers;
  }

  static Future<void> setAnimateStickers(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAnimateStickers, value);
  }

  // 開発者設定
  static Future<bool> getDeveloperMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDeveloperMode) ?? defaultDeveloperMode;
  }

  static Future<void> setDeveloperMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDeveloperMode, value);
  }

  // すべての設定を一度に取得
  static Future<Map<String, dynamic>> getAllSettings() async {
    return {
      'themeMode': await getThemeMode(),
      'notifyChannelMessages': await getNotifyChannelMessages(),
      'notifyDirectMessages': await getNotifyDirectMessages(),
      'convertEmoticons': await getConvertEmoticons(),
      'animateEmojis': await getAnimateEmojis(),
      'animateStickers': await getAnimateStickers(),
      'developerMode': await getDeveloperMode(),
    };
  }

  // 設定をリセット
  static Future<void> resetAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyThemeMode);
    await prefs.remove(_keyNotifyChannelMessages);
    await prefs.remove(_keyNotifyDirectMessages);
    await prefs.remove(_keyConvertEmoticons);
    await prefs.remove(_keyAnimateEmojis);
    await prefs.remove(_keyAnimateStickers);
    await prefs.remove(_keyDeveloperMode);
  }
}
