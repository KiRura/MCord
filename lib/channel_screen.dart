import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mcord/storage/token_storage.dart';
import 'package:mcord/api/message.dart';
import 'package:mcord/api/websocket.dart';

class ChannelScreen extends StatefulWidget {
  final dynamic channel;
  final dynamic guild;
  final String userId;

  const ChannelScreen({
    super.key,
    required this.channel,
    required this.guild,
    required this.userId,
  });

  @override
  State<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends State<ChannelScreen> {
  List<dynamic> _messages = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;
  bool _hasMoreMessages = true;
  String? _lastMessageId;
  final ScrollController _scrollController = ScrollController();
  bool _isMessageEmpty = true;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _messageUpdateSubscription;
  StreamSubscription? _messageDeleteSubscription;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _setupWebSocket();

    // スクロールリスナーを追加（分離したメソッドを参照）
    _scrollController.addListener(_onScroll);

    // メッセージ入力の監視を追加
    _messageController.addListener(_updateMessageState);
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _messageUpdateSubscription?.cancel();
    _messageDeleteSubscription?.cancel();
    _messageController.removeListener(_updateMessageState);
    _messageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _setupWebSocket() {
    final websocket = DiscordWebSocket();

    // 既存のリスナーをキャンセル
    _messageSubscription?.cancel();
    _messageUpdateSubscription?.cancel();
    _messageDeleteSubscription?.cancel();

    // 新しいメッセージの受信
    _messageSubscription = websocket.messageStream.listen((message) {
      if (message['channel_id'] == widget.channel['id']) {
        setState(() {
          // 既存のメッセージをチェック
          final existingIndex = _messages.indexWhere(
            (m) => m['id'] == message['id'],
          );
          if (existingIndex == -1) {
            // メッセージが存在しない場合のみ追加
            _messages.insert(0, message);
          }
        });
      }
    });

    // メッセージの更新
    _messageUpdateSubscription = websocket.messageUpdateStream.listen((
      message,
    ) {
      if (message['channel_id'] == widget.channel['id']) {
        setState(() {
          final index = _messages.indexWhere((m) => m['id'] == message['id']);
          if (index != -1) {
            _messages[index] = message;
          }
        });
      }
    });

    // メッセージの削除
    _messageDeleteSubscription = websocket.messageDeleteStream.listen((
      message,
    ) {
      if (message['channel_id'] == widget.channel['id']) {
        setState(() {
          _messages.removeWhere((m) => m['id'] == message['id']);
        });
      }
    });

    // 接続が確立されていない場合のみ接続
    websocket.connect();
  }

  // メッセージの状態を更新
  void _updateMessageState() {
    final newIsEmpty = _messageController.text.trim().isEmpty;
    if (_isMessageEmpty != newIsEmpty) {
      setState(() {
        _isMessageEmpty = newIsEmpty;
      });
    }
  }

  // スクロールリスナーメソッドを分離
  void _onScroll() {
    // ListView.reverseを使用しているため、minScrollExtentが下部、maxScrollExtentが上部になる
    // 上部に近づいたら（maxScrollExtentに近づいたら）追加のメッセージを読み込む
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMoreMessages) {
      print('スクロール位置: ${_scrollController.position.pixels}');
      print('最大スクロール位置: ${_scrollController.position.maxScrollExtent}');
      print('追加メッセージを読み込みます...');
      _fetchMoreMessages();
    }
  }

  Future<void> _fetchMessages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    print('初期メッセージを読み込み中...');
    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        throw Exception('トークンが見つかりません');
      }

      final messages = await fetchMessages(
        token: token,
        channelId: widget.channel['id'],
        limit: 50,
      );

      print('初期メッセージ取得: ${messages.length}件');
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
          // 次回取得用に最後のメッセージIDを保存
          if (messages.isNotEmpty) {
            _lastMessageId = messages.last['id'];
            print('初期_lastMessageId: $_lastMessageId');
          } else {
            _hasMoreMessages = false;
            print('取得したメッセージはありません');
          }
        });
      }
    } catch (e) {
      print('初期読み込みエラー: ${e.toString()}');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchMoreMessages() async {
    if (_lastMessageId == null || _isLoading || !_hasMoreMessages) {
      print(
        '読み込みスキップ: _lastMessageId=$_lastMessageId, _isLoading=$_isLoading, _hasMoreMessages=$_hasMoreMessages',
      );
      return;
    }

    print('読み込み開始: _lastMessageId=$_lastMessageId');
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        throw Exception('トークンが見つかりません');
      }

      final newMessages = await fetchMessages(
        token: token,
        channelId: widget.channel['id'],
        limit: 50,
        before: _lastMessageId,
      );

      print('取得したメッセージ数: ${newMessages.length}');
      if (mounted) {
        setState(() {
          if (newMessages.isEmpty) {
            _hasMoreMessages = false;
            // 全てのメッセージを読み込み終わったことをユーザーに伝える
            if (_messages.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('全てのメッセージを読み込みました'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          } else {
            _messages.addAll(newMessages);
            _lastMessageId = newMessages.last['id'];
            print('新しい_lastMessageId: $_lastMessageId');
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('エラー発生: ${e.toString()}');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    final messenger = _scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: _isChannelTextBased() ? 80 : 16,
          left: 16,
          right: 16,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // チャンネルの種類を表すテキスト
    final String channelTypeText = _getChannelTypeText();

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: '戻る',
          ),
          title: Row(
            children: [
              Icon(_getChannelIcon(), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.channel['name'],
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16),
                    ),
                    Row(
                      children: [
                        Text(
                          channelTypeText,
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        // NSFWバッジ（小さめ）
                        if (widget.channel['nsfw'] == true)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(2),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.error.withOpacity(0.3),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              'NSFW',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            // スクロールによるメッセージ読み込み中に表示するインジケーター
            if (_isLoading && !(_isLoading && _messages.isEmpty))
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchMessages,
              tooltip: '更新',
            ),
          ],
        ),
        body: Column(
          children: [
            // メッセージリスト
            Expanded(
              child:
                  _isLoading && _messages.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : _errorMessage != null
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'エラーが発生しました',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(_errorMessage!),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetchMessages,
                              child: const Text('再試行'),
                            ),
                          ],
                        ),
                      )
                      : _messages.isEmpty
                      ? const Center(child: Text('メッセージがありません'))
                      : Column(
                        children: [
                          // メッセージが全て読み込まれたことを示すインジケーター（オプション）
                          if (!_hasMoreMessages && _messages.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceVariant.withOpacity(0.3),
                              child: Text(
                                '全てのメッセージを読み込みました',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                          // メッセージリスト本体
                          Expanded(
                            child: ListView.builder(
                              controller: _scrollController,
                              reverse: true, // 新しいメッセージを下に表示
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                // メッセージを表示
                                final message = _messages[index];
                                return _buildMessageItem(message);
                              },
                            ),
                          ),
                        ],
                      ),
            ),

            // メッセージ入力欄
            if (_isChannelTextBased())
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: '${widget.channel['name']}へメッセージを送信',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          minLines: 1,
                          maxLines: 5,
                          textInputAction: TextInputAction.send,
                          onSubmitted:
                              (_) => _isMessageEmpty ? null : _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon:
                            _isSending
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.send),
                        onPressed:
                            (_isSending || _isMessageEmpty)
                                ? null
                                : _sendMessage,
                        color:
                            _isMessageEmpty
                                ? Theme.of(context).disabledColor
                                : Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              )
            else
              SafeArea(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  child: Text(
                    'このチャンネルタイプではメッセージを送信できません',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _isChannelTextBased() {
    // テキストベースのチャンネルか判定
    final channelType = widget.channel['type'];
    return channelType == 0 || channelType == 5; // TEXT, NEWS
  }

  IconData _getChannelIcon() {
    switch (widget.channel['type']) {
      case 0: // テキストチャンネル
        return Icons.tag;
      case 2: // ボイスチャンネル
        return Icons.headset;
      case 5: // アナウンスチャンネル (News)
        return Icons.campaign;
      case 13: // ステージチャンネル
        return Icons.mic;
      case 15: // フォーラムチャンネル
        return Icons.forum;
      default:
        return Icons.circle;
    }
  }

  Widget _buildMessageItem(dynamic message) {
    try {
      // メッセージの送信日時をフォーマット
      final timestamp = DateTime.parse(message['timestamp']);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final messageDate = DateTime(
        timestamp.year,
        timestamp.month,
        timestamp.day,
      );

      // 時刻部分のフォーマット
      final timeString =
          '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';

      // 日付部分のフォーマット（今日、昨日、それ以前で表示を変える）
      String dateString;
      if (messageDate == today) {
        dateString = '今日 $timeString';
      } else if (messageDate == yesterday) {
        dateString = '昨日 $timeString';
      } else {
        dateString =
            '${timestamp.year}/${timestamp.month.toString().padLeft(2, '0')}/${timestamp.day.toString().padLeft(2, '0')} $timeString';
      }

      // メッセージ送信者
      final author = message['author'];
      final authorId = author['id'];
      final authorName =
          author['global_name'] ?? author['username'] ?? '不明なユーザー';
      final authorAvatar =
          author['avatar'] != null
              ? 'https://cdn.discordapp.com/avatars/${author['id']}/${author['avatar']}.png'
              : null;

      // このメッセージのインデックスを取得
      final int messageIndex = _messages.indexOf(message);
      // メッセージのグループ化：同じ送信者からの連続メッセージかどうかを判定
      bool shouldShowHeader = true;

      // このメッセージの前のメッセージがあるかどうか確認
      if (messageIndex < _messages.length - 1) {
        // 前のメッセージの送信者と比較
        final prevMessage =
            _messages[messageIndex + 1]; // reverseしているので+1が前のメッセージ
        final prevAuthor = prevMessage['author'];

        // 送信者が同じなら、送信時間の差を計算
        if (prevAuthor['id'] == authorId) {
          // 時間の差を計算（3分以内なら省略）
          final prevTimestamp = DateTime.parse(prevMessage['timestamp']);
          final timeDiff = timestamp.difference(prevTimestamp).inMinutes.abs();

          if (timeDiff < 3) {
            // 3分以内の同じ送信者からのメッセージはヘッダーを表示しない
            shouldShowHeader = false;
          }
        }
      }

      return GestureDetector(
        onLongPress: () {
          // メッセージの送信者と現在のユーザーが同じ場合のみメニューを表示
          if (message['author']['id'] == widget.userId) {
            showModalBottomSheet(
              context: context,
              builder:
                  (context) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.edit),
                          title: const Text('メッセージを編集'),
                          onTap: () {
                            Navigator.pop(context);
                            _showEditMessageDialog(message);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.delete, color: Colors.red),
                          title: const Text(
                            'メッセージを削除',
                            style: TextStyle(color: Colors.red),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _showDeleteMessageDialog(message);
                          },
                        ),
                      ],
                    ),
                  ),
            );
          }
        },
        child: Padding(
          padding: EdgeInsets.only(
            left: 8,
            right: 8,
            top: shouldShowHeader ? 8 : 0,
            bottom: 0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // アバター（同じ送信者の連続メッセージでは透明のプレースホルダー）
              if (shouldShowHeader)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundImage:
                        authorAvatar != null
                            ? NetworkImage(authorAvatar)
                            : null,
                    child: authorAvatar == null ? Text(authorName[0]) : null,
                  ),
                )
              else
                const SizedBox(width: 32), // アバターの幅分の透明なスペース

              const SizedBox(width: 8),

              // メッセージコンテンツ
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ヘッダー（同じ送信者の連続メッセージでは表示しない）
                    if (shouldShowHeader)
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              authorName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            dateString,
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    // 連続メッセージの場合は時間表示を省略

                    // メッセージ本文
                    if (message['content'] != null &&
                        message['content'].toString().isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(
                          top: shouldShowHeader ? 2 : 1, // ヘッダーがない場合はさらに間隔を狭く
                          right: 8,
                          bottom: 1, // 下部の余白も追加
                        ),
                        child: Text(
                          message['content'],
                          style: const TextStyle(fontSize: 14),
                          softWrap: true,
                          overflow: TextOverflow.visible,
                        ),
                      ),

                    // 添付ファイル
                    if (message['attachments'] != null &&
                        message['attachments'].isNotEmpty)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: _buildAttachments(message['attachments']),
                        ),
                      ),

                    // 埋め込み
                    if (message['embeds'] != null &&
                        message['embeds'].isNotEmpty)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: _buildEmbeds(message['embeds']),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      // エラー時のフォールバック表示
      return ListTile(
        title: const Text('メッセージの表示に失敗しました'),
        subtitle: Text(e.toString()),
      );
    }
  }

  void _showEditMessageDialog(dynamic message) {
    final TextEditingController editController = TextEditingController(
      text: message['content'],
    );
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('メッセージを編集'),
            content: TextField(
              controller: editController,
              decoration: const InputDecoration(
                hintText: 'メッセージを入力',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () async {
                  final newContent = editController.text.trim();
                  if (newContent.isNotEmpty) {
                    try {
                      final token = await TokenStorage.getToken();
                      if (token == null) throw Exception('トークンが見つかりません');

                      await editMessage(
                        token: token,
                        channelId: widget.channel['id'],
                        messageId: message['id'],
                        content: newContent,
                      );

                      if (mounted) {
                        Navigator.pop(context);
                        _showSnackBar('メッセージを編集しました');
                      }
                    } catch (e) {
                      if (mounted) {
                        _showSnackBar('エラー: ${e.toString()}');
                      }
                    }
                  }
                },
                child: const Text('保存'),
              ),
            ],
          ),
    );
  }

  void _showDeleteMessageDialog(dynamic message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('メッセージを削除'),
            content: const Text('このメッセージを削除してもよろしいですか？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    final token = await TokenStorage.getToken();
                    if (token == null) throw Exception('トークンが見つかりません');

                    await deleteMessage(
                      token: token,
                      channelId: widget.channel['id'],
                      messageId: message['id'],
                    );

                    if (mounted) {
                      Navigator.pop(context);
                      _showSnackBar('メッセージを削除しました');
                    }
                  } catch (e) {
                    if (mounted) {
                      _showSnackBar('エラー: ${e.toString()}');
                    }
                  }
                },
                child: const Text('削除', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  List<Widget> _buildAttachments(List<dynamic> attachments) {
    return attachments.map<Widget>((attachment) {
      try {
        if (attachment['content_type'] != null &&
            attachment['content_type'].toString().startsWith('image/')) {
          // 画像の場合 - サイズを制限
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 300,
                  maxHeight: 300,
                ),
                child: Image.network(
                  attachment['url'],
                  fit: BoxFit.contain, // 画像のアスペクト比を維持
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: 200,
                      height: 150,
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                ),
              ),
            ),
          );
        } else {
          // その他のファイル
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min, // 必要最小限のサイズに
              children: [
                const Icon(Icons.attachment),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    attachment['filename'] ?? '添付ファイル',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '添付ファイルの表示に失敗: ${e.toString()}',
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        );
      }
    }).toList();
  }

  List<Widget> _buildEmbeds(List<dynamic> embeds) {
    return embeds.map<Widget>((embed) {
      try {
        // 埋め込みの色
        Color embedColor = Theme.of(context).colorScheme.primary;
        if (embed['color'] != null) {
          final colorInt = embed['color'];
          embedColor = Color(colorInt).withAlpha(255);
        }

        return Container(
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: embedColor, width: 4)),
            color: Theme.of(context).colorScheme.surface,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // タイトル
                if (embed['title'] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      embed['title'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),

                // 説明
                if (embed['description'] != null)
                  Text(
                    embed['description'],
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 8, // 長い説明は制限
                  ),

                // フィールド
                if (embed['fields'] != null)
                  ...embed['fields'].map<Widget>((field) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            field['name'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            field['value'] ?? '',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 3,
                          ),
                        ],
                      ),
                    );
                  }).toList(),

                // 画像
                if (embed['image'] != null && embed['image']['url'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 300,
                          maxHeight: 300,
                        ),
                        child: Image.network(
                          embed['image']['url'],
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),

                // サムネイル
                if (embed['thumbnail'] != null &&
                    embed['thumbnail']['url'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        embed['thumbnail']['url'],
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                // フッター
                if (embed['footer'] != null && embed['footer']['text'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      embed['footer']['text'],
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        );
      } catch (e) {
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '埋め込みの表示に失敗: ${e.toString()}',
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        );
      }
    }).toList();
  }

  // チャンネルタイプのテキストを取得
  String _getChannelTypeText() {
    switch (widget.channel['type']) {
      case 0:
        return 'テキストチャンネル';
      case 2:
        return 'ボイスチャンネル';
      case 5:
        return 'アナウンスチャンネル';
      case 10:
        return 'ニューススレッド';
      case 11:
        return 'パブリックスレッド';
      case 12:
        return 'プライベートスレッド';
      case 13:
        return 'ステージチャンネル';
      case 15:
        return 'フォーラムチャンネル';
      default:
        return 'チャンネル';
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      final token = await TokenStorage.getToken();
      if (token == null) {
        throw Exception('トークンが見つかりません');
      }

      await sendMessage(
        token: token,
        channelId: widget.channel['id'],
        content: message,
      );

      if (mounted) {
        _messageController.clear();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('エラー: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }
}
