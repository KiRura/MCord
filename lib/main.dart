import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mcord/api/login.dart';
import 'package:mcord/home.dart';
import 'package:mcord/storage/token_storage.dart';
import 'package:mcord/storage/settings_storage.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  // Flutter初期化を確実に行う
  WidgetsFlutterBinding.ensureInitialized();

  // Androidの場合、保存されたディスプレイモードを適用
  if (Platform.isAndroid) {
    await _applyDisplayMode();
  }

  runApp(const MainApp());
}

// 保存されたディスプレイモードを適用する関数
Future<void> _applyDisplayMode() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final savedModeIndex = prefs.getInt('preferred_display_mode');

    if (savedModeIndex != null) {
      final modes = await FlutterDisplayMode.supported;
      if (savedModeIndex < modes.length) {
        await FlutterDisplayMode.setPreferredMode(modes[savedModeIndex]);
      }
    }
  } catch (e) {
    // エラー処理：失敗しても起動は続行
    print('ディスプレイモードの適用に失敗: $e');
  }
}

// テーマ変更を通知するためのNotifier
class ThemeNotifier extends ChangeNotifier {
  static final ThemeNotifier _instance = ThemeNotifier._internal();
  factory ThemeNotifier() => _instance;
  ThemeNotifier._internal();

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  Future<void> loadThemeSettings() async {
    final themeModeSetting = await SettingsStorage.getThemeMode();
    _updateThemeMode(themeModeSetting);
    notifyListeners();
  }

  Future<void> updateThemeMode(int value) async {
    await SettingsStorage.setThemeMode(value);
    _updateThemeMode(value);
    notifyListeners();
  }

  void _updateThemeMode(int value) {
    switch (value) {
      case 0:
        _themeMode = ThemeMode.system;
        break;
      case 1:
        _themeMode = ThemeMode.light;
        break;
      case 2:
        _themeMode = ThemeMode.dark;
        break;
      default:
        _themeMode = ThemeMode.system;
    }
  }
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  ThemeMode _themeMode = ThemeMode.system;
  final _themeNotifier = ThemeNotifier();

  @override
  void initState() {
    super.initState();
    _loadThemeSettings();
    _themeNotifier.addListener(_handleThemeChange);
  }

  @override
  void dispose() {
    _themeNotifier.removeListener(_handleThemeChange);
    super.dispose();
  }

  void _handleThemeChange() {
    setState(() {
      _themeMode = _themeNotifier.themeMode;
    });
  }

  Future<void> _loadThemeSettings() async {
    await _themeNotifier.loadThemeSettings();
    setState(() {
      _themeMode = _themeNotifier.themeMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: LoginForm(),
      theme: ThemeData(colorSchemeSeed: Color(0xFF5468FF)),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Color(0xFF5468FF),
      ),
      themeMode: _themeMode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale("ja", "JP")],
    );
  }
}

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _tokenController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkSavedToken();
    _tokenController.addListener(_updateButtonState);
  }

  void _updateButtonState() {
    setState(() {});
  }

  Future<void> _checkSavedToken() async {
    final savedToken = await TokenStorage.getToken();
    if (savedToken != null) {
      _loginWithToken(savedToken);
    }
  }

  Future<void> _loginWithToken(String token) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userInfo = await loginWithToken(token: token);
      await TokenStorage.saveToken(token);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(userId: userInfo['id']),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tokenController.removeListener(_updateButtonState);
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('トークンログイン')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'トークンログイン',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32.0),
            TextField(
              controller: _tokenController,
              decoration: InputDecoration(
                labelText: 'トークン',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.vpn_key),
              ),
              obscureText: true,
            ),
            SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton(
                  onPressed: () async {
                    _tokenController.text = "";
                    await TokenStorage.deleteToken();
                  },
                  child: Icon(Icons.delete),
                ),
                ElevatedButton(
                  onPressed:
                      _isLoading || _tokenController.text.isEmpty
                          ? null
                          : () {
                            _loginWithToken(_tokenController.text);
                          },
                  child:
                      _isLoading
                          ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : Text('ログイン'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
