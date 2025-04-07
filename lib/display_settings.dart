import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DisplaySettingsScreen extends StatefulWidget {
  const DisplaySettingsScreen({super.key});

  @override
  State<DisplaySettingsScreen> createState() => _DisplaySettingsScreenState();
}

class _DisplaySettingsScreenState extends State<DisplaySettingsScreen> {
  List<DisplayMode> _modes = <DisplayMode>[];
  DisplayMode? _preferredMode;
  DisplayMode? _activeMode;
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadDisplayModes();
  }

  Future<void> _loadDisplayModes() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // 利用可能なディスプレイモードを取得
      final modes = await FlutterDisplayMode.supported;
      // 現在アクティブなモードを取得
      final active = await FlutterDisplayMode.active;

      // 保存済みの設定を読み込む
      final prefs = await SharedPreferences.getInstance();
      final savedModeIndex = prefs.getInt('preferred_display_mode');

      DisplayMode? preferredMode;
      if (savedModeIndex != null && savedModeIndex < modes.length) {
        preferredMode = modes[savedModeIndex];
      } else {
        // 保存されていない場合はアクティブなモードを選択状態にする
        preferredMode = active;
      }

      if (mounted) {
        setState(() {
          _modes = modes;
          _activeMode = active;
          _preferredMode = preferredMode;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _setDisplayMode(DisplayMode mode) async {
    try {
      await FlutterDisplayMode.setPreferredMode(mode);

      // 設定を保存
      final prefs = await SharedPreferences.getInstance();
      final index = _modes.indexOf(mode);
      await prefs.setInt('preferred_display_mode', index);

      // 更新後の状態を取得
      final active = await FlutterDisplayMode.active;

      if (mounted) {
        setState(() {
          _activeMode = active;
          _preferredMode = mode;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'ディスプレイモードを変更しました: ${mode.refreshRate.toStringAsFixed(2)}Hz',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('エラー: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ディスプレイ設定')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error.isNotEmpty
              ? Center(child: Text('エラー: $_error'))
              : ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'リフレッシュレート',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  for (final mode in _modes)
                    RadioListTile<DisplayMode>(
                      title: Text('${mode.refreshRate.toStringAsFixed(2)}Hz'),
                      subtitle: _buildModeSubtitle(mode),
                      value: mode,
                      groupValue: _preferredMode,
                      onChanged: (mode) {
                        if (mode != null) {
                          _setDisplayMode(mode);
                        }
                      },
                    ),
                ],
              ),
    );
  }

  Widget _buildModeSubtitle(DisplayMode mode) {
    final List<Widget> badges = [];

    // 現在アクティブなモードを表示
    if (_activeMode != null &&
        _activeMode!.width == mode.width &&
        _activeMode!.height == mode.height &&
        _activeMode!.refreshRate == mode.refreshRate) {
      badges.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '現在適用中',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('解像度: ${mode.width}x${mode.height}'),
        if (badges.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(children: badges),
          ),
      ],
    );
  }
}
