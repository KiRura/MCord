import 'package:flutter/material.dart';
import 'package:mcord/storage/token_storage.dart';
import 'package:mcord/main.dart';
import 'package:mcord/api/guild.dart';
import 'package:mcord/profile.dart';
import 'package:mcord/api/user.dart';
import 'package:mcord/settings.dart';
import 'package:mcord/channel_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userId;

  const HomeScreen({super.key, required this.userId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _guilds = [];
  List<dynamic> _channels = [];
  Map<String, dynamic>? _userProfile;
  bool _isLoadingGuilds = true;
  bool _isLoadingChannels = false;
  bool _isLoadingProfile = false;
  String? _errorMessage;
  dynamic _selectedGuild;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchGuilds();
    _fetchUserProfile();
  }

  Future<void> _fetchGuilds() async {
    setState(() {
      _isLoadingGuilds = true;
      _errorMessage = null;
    });

    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        throw Exception('トークンが見つかりません');
      }

      final guilds = await fetchUserGuilds(token: token);

      setState(() {
        _guilds = guilds;
        _isLoadingGuilds = false;

        // 最初のサーバーを自動選択（存在する場合）
        if (guilds.isNotEmpty) {
          _selectGuild(guilds[0]);
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoadingGuilds = false;
      });
    }
  }

  // 初回のプロフィール取得（起動時に実行）
  Future<void> _fetchUserProfile() async {
    setState(() {
      _isLoadingProfile = true;
    });

    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        throw Exception('トークンが見つかりません');
      }

      final profile = await fetchUserProfile(token: token);

      if (mounted) {
        setState(() {
          _userProfile = profile;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
        // エラーはSnackBarで表示
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('プロフィール取得エラー: ${e.toString()}')));
      }
    }
  }

  // バックグラウンドでプロフィールを更新（タブ切り替え時に実行）
  Future<void> _updateUserProfileInBackground() async {
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        return;
      }

      final profile = await fetchUserProfile(token: token);

      if (mounted) {
        setState(() {
          _userProfile = profile;
        });
      }
    } catch (e) {
      // バックグラウンド更新のエラーは表示しない
    }
  }

  Future<void> _selectGuild(dynamic guild) async {
    setState(() {
      _selectedGuild = guild;
      _isLoadingChannels = true;
      _channels = [];
    });

    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        throw Exception('トークンが見つかりません');
      }

      final channels = await fetchGuildChannels(
        token: token,
        guildId: guild['id'],
      );

      // positionプロパティに基づいて並び替える
      channels.sort((a, b) {
        // positionプロパティがない場合は最後尾に配置
        final positionA = a['position'] ?? 9999;
        final positionB = b['position'] ?? 9999;
        return positionA.compareTo(positionB);
      });

      setState(() {
        _channels = channels;
        _isLoadingChannels = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoadingChannels = false;
      });
    }
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // プロフィールタブに切り替えたとき
    if (index == 1) {
      if (_userProfile == null) {
        // プロフィールがまだない場合は同期的に取得
        _fetchUserProfile();
      } else {
        // プロフィールがすでにある場合はバックグラウンドで更新
        _updateUserProfileInBackground();
      }
    }
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedIndex == 0
              ? (_selectedGuild != null ? _selectedGuild['name'] : 'Discord')
              : 'プロフィール',
        ),
        actions: [
          if (_selectedIndex == 0)
            IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchGuilds)
          else
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _navigateToSettings,
              tooltip: '設定',
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await TokenStorage.deleteToken();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginForm()),
                );
              }
            },
          ),
        ],
      ),
      body:
          _selectedIndex == 0
              ? _buildServerView()
              : ProfileScreen(
                userProfile: _userProfile,
                isLoading: _isLoadingProfile,
              ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.forum), label: 'サーバー'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'プロフィール'),
        ],
      ),
    );
  }

  Widget _buildServerView() {
    if (_isLoadingGuilds) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'エラーが発生しました',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchGuilds, child: const Text('再試行')),
          ],
        ),
      );
    }

    if (_guilds.isEmpty) {
      return const Center(child: Text('ボットが参加しているサーバーはありません'));
    }

    return Row(
      children: [
        // 左側: サーバーリスト（アイコンのみ）
        Container(
          width: 72,
          color: Theme.of(context).colorScheme.surfaceVariant,
          child: ListView.builder(
            itemCount: _guilds.length,
            itemBuilder: (context, index) {
              final guild = _guilds[index];
              final isSelected =
                  _selectedGuild != null && _selectedGuild['id'] == guild['id'];

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: InkWell(
                  onTap: () => _selectGuild(guild),
                  borderRadius: BorderRadius.circular(25),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border:
                          isSelected
                              ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              )
                              : null,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child:
                          guild['icon'] != null
                              ? CircleAvatar(
                                backgroundImage: NetworkImage(
                                  'https://cdn.discordapp.com/icons/${guild['id']}/${guild['icon']}.png',
                                ),
                              )
                              : CircleAvatar(
                                child: Text(guild['name'][0]),
                                backgroundColor:
                                    Theme.of(
                                      context,
                                    ).colorScheme.secondaryContainer,
                              ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // 右側: チャンネル一覧
        Expanded(child: _buildChannelList()),
      ],
    );
  }

  Widget _buildChannelList() {
    if (_channels == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_channels!.isEmpty) {
      return const Center(child: Text('チャンネルが見つかりません'));
    }

    // チャンネルをカテゴリー/タイプでグループ化
    final List<dynamic> categories =
        _channels!
            .where((channel) => channel['type'] == 4) // カテゴリーのみ
            .toList();

    // カテゴリーごとのチャンネルをグループ化するマップを作成
    final Map<String, List<dynamic>> categorizedChannels = {};

    // カテゴリー別にチャンネルをグループ化
    for (final category in categories) {
      final String categoryId = category['id'];
      // このカテゴリーに属するチャンネルを取得
      final List<dynamic> channelsInCategory =
          _channels!
              .where(
                (channel) =>
                    channel['parent_id'] == categoryId && channel['type'] != 4,
              ) // カテゴリー自体を除外
              .toList();

      // テキストチャンネルとボイスチャンネルを分離
      final textChannels =
          channelsInCategory
              .where(
                (channel) =>
                    channel['type'] == 0 ||
                    channel['type'] == 5 ||
                    channel['type'] == 15,
              )
              .toList();

      final voiceChannels =
          channelsInCategory
              .where((channel) => channel['type'] == 2 || channel['type'] == 13)
              .toList();

      // テキストチャンネルとボイスチャンネルをそれぞれpositionでソート
      textChannels.sort(
        (a, b) => (a['position'] ?? 0).compareTo(b['position'] ?? 0),
      );
      voiceChannels.sort(
        (a, b) => (a['position'] ?? 0).compareTo(b['position'] ?? 0),
      );

      // ソートされたテキストチャンネルとボイスチャンネルを結合
      channelsInCategory.clear();
      channelsInCategory.addAll(textChannels);
      channelsInCategory.addAll(voiceChannels);

      // 空でなければ追加
      if (channelsInCategory.isNotEmpty) {
        categorizedChannels[categoryId] = channelsInCategory;
      }
    }

    // カテゴリーに分類されていないチャンネル
    final uncategorizedChannels =
        _channels!
            .where(
              (channel) => channel['parent_id'] == null && channel['type'] != 4,
            ) // カテゴリー自体を除外
            .toList();

    // テキストチャンネルとボイスチャンネルを分離してソート
    final uncategorizedTextChannels =
        uncategorizedChannels
            .where(
              (channel) =>
                  channel['type'] == 0 ||
                  channel['type'] == 5 ||
                  channel['type'] == 15,
            )
            .toList()
          ..sort((a, b) => (a['position'] ?? 0).compareTo(b['position'] ?? 0));

    final uncategorizedVoiceChannels =
        uncategorizedChannels
            .where((channel) => channel['type'] == 2 || channel['type'] == 13)
            .toList()
          ..sort((a, b) => (a['position'] ?? 0).compareTo(b['position'] ?? 0));

    // すべてのウィジェットを格納するリスト
    final List<Widget> channelWidgets = [];

    // カテゴリー外のチャンネルがあれば表示
    if (uncategorizedTextChannels.isNotEmpty ||
        uncategorizedVoiceChannels.isNotEmpty) {
      // テキストチャンネルを追加
      if (uncategorizedTextChannels.isNotEmpty) {
        for (final channel in uncategorizedTextChannels) {
          channelWidgets.add(_buildChannelItem(channel));
        }
      }

      // ボイスチャンネルを追加
      if (uncategorizedVoiceChannels.isNotEmpty) {
        for (final channel in uncategorizedVoiceChannels) {
          channelWidgets.add(_buildChannelItem(channel));
        }
      }

      // カテゴリーとの区切り線を追加
      if (categories.isNotEmpty && categorizedChannels.isNotEmpty) {
        channelWidgets.add(const Divider());
      }
    }

    // カテゴリー別にチャンネルを表示
    for (final category in categories) {
      final String categoryId = category['id'];
      final channelsInCategory = categorizedChannels[categoryId];

      // このカテゴリーにチャンネルがなければスキップ
      if (channelsInCategory == null || channelsInCategory.isEmpty) {
        continue;
      }

      // カテゴリーヘッダー
      channelWidgets.add(
        Padding(
          padding: const EdgeInsets.only(left: 12, top: 16, bottom: 4),
          child: Row(
            children: [
              Icon(
                Icons.keyboard_arrow_down,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                category['name'].toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );

      // テキストチャンネルとボイスチャンネルを分離
      final textChannels =
          channelsInCategory
              .where(
                (channel) =>
                    channel['type'] == 0 ||
                    channel['type'] == 5 ||
                    channel['type'] == 15,
              )
              .toList();

      final voiceChannels =
          channelsInCategory
              .where((channel) => channel['type'] == 2 || channel['type'] == 13)
              .toList();

      // テキストチャンネルを表示
      for (final channel in textChannels) {
        channelWidgets.add(_buildChannelItem(channel, isCategorized: true));
      }

      // ボイスチャンネルを表示
      if (voiceChannels.isNotEmpty) {
        for (final channel in voiceChannels) {
          channelWidgets.add(_buildChannelItem(channel, isCategorized: true));
        }
      }
    }

    return ListView(children: channelWidgets);
  }

  Widget _buildChannelItem(dynamic channel, {bool isCategorized = false}) {
    final channelType = channel['type'];
    IconData icon;
    bool isVoice = false;

    switch (channelType) {
      case 0: // テキストチャンネル
        icon = Icons.tag;
        break;
      case 2: // ボイスチャンネル
        icon = Icons.headset;
        isVoice = true;
        break;
      case 5: // アナウンスチャンネル（News）
        icon = Icons.campaign;
        break;
      case 13: // ステージチャンネル
        icon = Icons.mic;
        isVoice = true;
        break;
      case 15: // フォーラムチャンネル
        icon = Icons.forum;
        break;
      default:
        icon = Icons.circle;
    }

    return ListTile(
      leading: Icon(
        icon,
        color:
            isVoice
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : Theme.of(context).colorScheme.onSurface,
        size: 20,
      ),
      contentPadding: EdgeInsets.only(
        left: isCategorized ? 32.0 : 16.0,
        right: 16.0,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              channel['name'],
              style: TextStyle(
                color:
                    isVoice
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.normal,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // NSFWタグを表示
          if (channel['nsfw'] == true)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 4.0,
                vertical: 2.0,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4.0),
                border: Border.all(
                  color: Theme.of(context).colorScheme.error.withOpacity(0.3),
                ),
              ),
              child: Text(
                'NSFW',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 10.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      dense: true,
      visualDensity: VisualDensity.compact,
      onTap: () {
        // チャンネルをタップしたときの処理
        _navigateToChannel(channel, _selectedGuild);
      },
    );
  }

  void _navigateToChannel(dynamic channel, dynamic guild) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ChannelScreen(
              channel: channel,
              guild: guild,
              userId: widget.userId,
            ),
      ),
    );
  }
}
