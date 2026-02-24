import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const _apiBaseUrlFromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
const _requestTimeout = Duration(seconds: 12);

String get _apiBaseUrl {
  if (_apiBaseUrlFromEnv.isNotEmpty) {
    return _apiBaseUrlFromEnv;
  }
  return 'http://localhost:5001';
}

void main() {
  runApp(const BbsApp());
}

class BbsApp extends StatelessWidget {
  const BbsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '掲示板サービス',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idController = TextEditingController();
  final _pwController = TextEditingController();
  String? _error;
  bool _loading = false;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final id = _idController.text.trim();
    final pw = _pwController.text.trim();
    if (id.isEmpty || pw.isEmpty) {
      setState(() {
        _error = 'IDとパスワードを入力してください';
        _loading = false;
      });
      return;
    }

    try {
      final url = Uri.parse('$_apiBaseUrl/api/auth/login');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': id, 'password': pw}),
      ).timeout(_requestTimeout);

      if (res.statusCode == 200) {
        final user = jsonDecode(res.body) as Map<String, dynamic>;
        if (!mounted) {
          return;
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => BbsHomePage(user: user)),
        );
      } else {
        setState(() {
          _error = 'ログインに失敗しました';
        });
      }
    } on TimeoutException {
      setState(() {
        _error = 'API接続がタイムアウトしました。サーバーURLを確認してください。';
      });
    } catch (e) {
      setState(() {
        _error = '通信エラー: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ログイン')),
      body: Center(
        child: SizedBox(
          width: 440,
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _idController,
                    decoration: const InputDecoration(labelText: 'ユーザーID'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pwController,
                    decoration: const InputDecoration(labelText: 'パスワード'),
                    obscureText: true,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 20),
                  _loading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _submit,
                          child: const Text('ログイン'),
                        ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      );
                    },
                    child: const Text('新規登録はこちら'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _idController = TextEditingController();
  final _pwController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _avatarController = TextEditingController();

  bool _loading = false;
  bool? _idAvailable;
  String? _error;

  Future<void> _checkId() async {
    final username = _idController.text.trim();
    if (username.isEmpty) {
      setState(() {
        _idAvailable = null;
        _error = 'ユーザーIDを入力してください';
      });
      return;
    }

    final url = Uri.parse('$_apiBaseUrl/api/auth/check-username?username=${Uri.encodeQueryComponent(username)}');
    try {
      final res = await http.get(url).timeout(_requestTimeout);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _idAvailable = body['available'] == true;
          _error = null;
        });
      }
    } on TimeoutException {
      setState(() {
        _error = 'ID確認がタイムアウトしました';
      });
    }
  }

  Future<void> _register() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final username = _idController.text.trim();
    final password = _pwController.text.trim();
    final displayName = _displayNameController.text.trim();
    final avatarUrl = _avatarController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'ユーザーIDとパスワードは必須です';
        _loading = false;
      });
      return;
    }

    if (_idAvailable == false) {
      setState(() {
        _error = 'このユーザーIDは使用済みです';
        _loading = false;
      });
      return;
    }

    try {
      final url = Uri.parse('$_apiBaseUrl/api/auth/register');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'displayName': displayName,
          'avatarUrl': avatarUrl,
        }),
      ).timeout(_requestTimeout);

      if (res.statusCode == 200) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登録しました。ログインしてください。')),
        );
        Navigator.pop(context);
      } else {
        setState(() {
          _error = '登録に失敗しました';
        });
      }
    } on TimeoutException {
      setState(() {
        _error = '登録処理がタイムアウトしました';
      });
    } catch (e) {
      setState(() {
        _error = '通信エラー: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新規登録')),
      body: Center(
        child: SizedBox(
          width: 460,
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _idController,
                          decoration: const InputDecoration(labelText: 'ユーザーID'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(onPressed: _checkId, child: const Text('ID確認')),
                    ],
                  ),
                  if (_idAvailable != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _idAvailable! ? 'このIDは利用できます' : 'このIDは利用できません',
                        style: TextStyle(color: _idAvailable! ? Colors.green : Colors.red),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pwController,
                    decoration: const InputDecoration(labelText: 'パスワード'),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _displayNameController,
                    decoration: const InputDecoration(labelText: '表示名'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _avatarController,
                    decoration: const InputDecoration(labelText: 'プロフィール画像URL'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 20),
                  _loading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(onPressed: _register, child: const Text('登録する')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BbsHomePage extends StatefulWidget {
  const BbsHomePage({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<BbsHomePage> createState() => _BbsHomePageState();
}

class _BbsHomePageState extends State<BbsHomePage> {
  final _commentController = TextEditingController();
  final _searchTitleController = TextEditingController();
  late Map<String, dynamic> _currentUser;
  List<Map<String, dynamic>> _threads = [];
  int _selectedThread = 0;
  bool _loading = true;
  DateTime? _searchDate;
  Map<String, dynamic>? _replyTarget;

  @override
  void initState() {
    super.initState();
    _currentUser = Map<String, dynamic>.from(widget.user);
    _loadThreads();
  }

  Future<void> _loadThreads() async {
    setState(() => _loading = true);
    try {
      final titleQ = _searchTitleController.text.trim();
      final dateQ = _searchDate != null
          ? '&date=${_searchDate!.year}-${_searchDate!.month.toString().padLeft(2, '0')}-${_searchDate!.day.toString().padLeft(2, '0')}'
          : '';
      final query = titleQ.isNotEmpty ? '?title=$titleQ$dateQ' : (dateQ.isNotEmpty ? '?${dateQ.substring(1)}' : '');
      final url = Uri.parse('$_apiBaseUrl/api/threads$query');
      final res = await http.get(url).timeout(_requestTimeout);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        final mapped = list.map<Map<String, dynamic>>((t) {
          final comments = (t['comments'] as List<dynamic>? ?? []).map<Map<String, dynamic>>((c) {
            final reactionMap = <String, int>{};
            final src = c['reactions'] as Map<String, dynamic>? ?? {};
            for (final e in src.entries) {
              reactionMap[e.key] = (e.value as num).toInt();
            }

            return {
              'id': c['id'],
              'userId': c['userId'],
              'userName': c['userName'] ?? 'ユーザー${c['userId']}',
              'avatarUrl': c['avatarUrl']?.toString() ?? '',
              'content': c['content'] ?? '',
              'parentCommentId': c['parentCommentId'],
              'createdAt': DateTime.tryParse('${c['createdAt']}') ?? DateTime.now(),
              'reactions': reactionMap,
              'isMe': _currentUser['id'] != null && c['userId'] == _currentUser['id'],
            };
          }).toList();

          return {
            'id': t['id'],
            'title': '${t['title'] ?? '無題スレッド'}',
            'category': '${t['category'] ?? ''}',
            'createdAt': DateTime.tryParse('${t['createdAt']}') ?? DateTime.now(),
            'comments': comments,
          };
        }).toList();

        setState(() {
          _threads = mapped;
          if (_threads.isNotEmpty && _selectedThread >= _threads.length) {
            _selectedThread = 0;
          }
        });
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('スレッド読み込みがタイムアウトしました')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<List<String>> _fetchCategorySuggestions(String input) async {
    if (input.trim().isEmpty) {
      return [];
    }
    final url = Uri.parse('$_apiBaseUrl/api/threads/category-suggestions?query=$input');
    final res = await http.get(url).timeout(_requestTimeout);
    if (res.statusCode != 200) {
      return [];
    }
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => '$e').where((e) => e.trim().isNotEmpty).toList();
  }

  Future<void> _openCreateThreadDialog() async {
    final titleController = TextEditingController();
    final categoryController = TextEditingController();
    List<String> suggestions = [];

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('新規スレッド'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'スレッド名'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(labelText: 'カテゴリ'),
                      onChanged: (value) async {
                        final result = await _fetchCategorySuggestions(value);
                        setDialogState(() {
                          suggestions = result;
                        });
                      },
                    ),
                    if (suggestions.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: suggestions
                              .map((s) => ActionChip(
                                    label: Text(s),
                                    onPressed: () {
                                      categoryController.text = s;
                                    },
                                  ))
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
                ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final category = categoryController.text.trim();
                    if (title.isEmpty || category.isEmpty) {
                      return;
                    }
                    final url = Uri.parse('$_apiBaseUrl/api/threads');
                    await http.post(
                      url,
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode({
                        'title': title,
                        'category': category,
                        'createdBy': _currentUser['id'],
                      }),
                    ).timeout(_requestTimeout);
                    if (!mounted) {
                      return;
                    }
                    Navigator.of(this.context).pop();
                    await _loadThreads();
                  },
                  child: const Text('作成'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _postComment() async {
    if (_threads.isEmpty) {
      return;
    }
    final text = _commentController.text.trim();
    if (text.isEmpty) {
      return;
    }

    final thread = _threads[_selectedThread];
    final url = Uri.parse('$_apiBaseUrl/api/threads/comment');
    final body = jsonEncode({
      'threadId': thread['id'],
      'userId': _currentUser['id'],
      'content': text,
      'parentCommentId': _replyTarget?['id'],
    });

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    ).timeout(_requestTimeout);

    if (res.statusCode == 200) {
      _commentController.clear();
      setState(() {
        _replyTarget = null;
      });
      await _loadThreads();
    }
  }

  Future<void> _toggleReaction(Map<String, dynamic> comment, String reactionType) async {
    final url = Uri.parse('$_apiBaseUrl/api/threads/reaction');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'commentId': comment['id'],
        'userId': _currentUser['id'],
        'reactionType': reactionType,
      }),
    ).timeout(_requestTimeout);

    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List<dynamic>;
      final newMap = <String, int>{};
      for (final item in list) {
        final m = item as Map<String, dynamic>;
        newMap['${m['reactionType']}'] = (m['count'] as num).toInt();
      }

      setState(() {
        comment['reactions'] = newMap;
      });
    }
  }

  String _formatDateTime(DateTime dt) {
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$y/$m/$d $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final hasThreads = _threads.isNotEmpty;
    final thread = hasThreads ? _threads[_selectedThread] : null;
    final comments = hasThreads ? (thread!['comments'] as List).cast<Map<String, dynamic>>() : <Map<String, dynamic>>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('掲示板'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _openCreateThreadDialog,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final updated = await Navigator.push<Map<String, dynamic>>(
                context,
                MaterialPageRoute(builder: (_) => SettingsScreen(user: _currentUser)),
              );
              if (updated != null) {
                setState(() {
                  _currentUser.addAll(updated);
                });
              }
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                SizedBox(
                  width: 320,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            TextField(
                              controller: _searchTitleController,
                              decoration: const InputDecoration(
                                labelText: 'スレッド名検索',
                                prefixIcon: Icon(Icons.search),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _searchDate ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2100),
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _searchDate = picked;
                                        });
                                      }
                                    },
                                    icon: const Icon(Icons.calendar_today),
                                    label: Text(_searchDate == null
                                        ? '日付指定'
                                        : '${_searchDate!.year}/${_searchDate!.month}/${_searchDate!.day}'),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _searchDate = null;
                                    });
                                  },
                                  icon: const Icon(Icons.clear),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _loadThreads,
                                child: const Text('検索'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _threads.length,
                          itemBuilder: (context, index) {
                            final item = _threads[index];
                            return ListTile(
                              selected: _selectedThread == index,
                              title: Text('${item['title']}'),
                              subtitle: Text('${item['category']}  ${_formatDateTime(item['createdAt'] as DateTime)}'),
                              onTap: () {
                                setState(() => _selectedThread = index);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: hasThreads
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '${thread?['title'] ?? ''}',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Text('カテゴリ: ${thread?['category'] ?? ''}'),
                              const SizedBox(height: 12),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: comments.length,
                                  itemBuilder: (context, index) {
                                    final c = comments[index];
                                    final isMe = c['isMe'] == true;
                                    final reactions = (c['reactions'] as Map<String, int>? ?? {});
                                    final parentId = c['parentCommentId'];
                                    final quoted = parentId == null
                                        ? null
                                        : comments.cast<Map<String, dynamic>?>().firstWhere(
                                            (x) => x?['id'] == parentId,
                                            orElse: () => null,
                                          );

                                    return Align(
                                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                      child: Container(
                                        constraints: const BoxConstraints(maxWidth: 560),
                                        margin: const EdgeInsets.symmetric(vertical: 6),
                                        child: Row(
                                          mainAxisAlignment:
                                              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (!isMe)
                                              _AvatarWidget(
                                                displayName: c['userName']?.toString() ?? 'U',
                                                avatarUrl: c['avatarUrl']?.toString() ?? '',
                                              ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: isMe ? Colors.indigo.shade100 : Colors.grey.shade100,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Text(
                                                          '${c['userName']}',
                                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                                        ),
                                                        Text(
                                                          _formatDateTime(c['createdAt'] as DateTime),
                                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                                        ),
                                                      ],
                                                    ),
                                                    if (quoted != null) ...[
                                                      const SizedBox(height: 6),
                                                      Container(
                                                        width: double.infinity,
                                                        padding: const EdgeInsets.all(8),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white,
                                                          border: Border.all(color: Colors.grey.shade300),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: Text(
                                                          '引用: ${quoted['content']}',
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: TextStyle(color: Colors.grey.shade700),
                                                        ),
                                                      ),
                                                    ],
                                                    const SizedBox(height: 6),
                                                    Text('${c['content']}'),
                                                    const SizedBox(height: 8),
                                                    Wrap(
                                                      spacing: 8,
                                                      runSpacing: 4,
                                                      crossAxisAlignment: WrapCrossAlignment.center,
                                                      children: [
                                                        TextButton(
                                                          onPressed: () {
                                                            setState(() {
                                                              _replyTarget = c;
                                                            });
                                                          },
                                                          child: const Text('返信'),
                                                        ),
                                                        _ReactionChip(
                                                          label: '👍',
                                                          count: reactions['👍'] ?? 0,
                                                          onTap: () => _toggleReaction(c, '👍'),
                                                        ),
                                                        _ReactionChip(
                                                          label: '❤️',
                                                          count: reactions['❤️'] ?? 0,
                                                          onTap: () => _toggleReaction(c, '❤️'),
                                                        ),
                                                        _ReactionChip(
                                                          label: '😂',
                                                          count: reactions['😂'] ?? 0,
                                                          onTap: () => _toggleReaction(c, '😂'),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            if (isMe) ...[
                                              const SizedBox(width: 8),
                                              _AvatarWidget(
                                                displayName: c['userName']?.toString() ?? 'U',
                                                avatarUrl: c['avatarUrl']?.toString() ?? '',
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              if (_replyTarget != null)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.amber.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '返信先: ${_replyTarget!['content']}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () {
                                          setState(() {
                                            _replyTarget = null;
                                          });
                                        },
                                        icon: const Icon(Icons.close),
                                      ),
                                    ],
                                  ),
                                ),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _commentController,
                                      decoration: const InputDecoration(hintText: '書き込み内容を入力...'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _postComment,
                                    child: const Text('投稿'),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : const Center(child: Text('スレッドがありません')),
                  ),
                ),
              ],
            ),
    );
  }
}

class _AvatarWidget extends StatelessWidget {
  const _AvatarWidget({required this.displayName, required this.avatarUrl});

  final String displayName;
  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    final hasUrl = avatarUrl.trim().isNotEmpty;
    final initial = displayName.isNotEmpty ? displayName.characters.first : 'U';

    return CircleAvatar(
      radius: 16,
      backgroundImage: hasUrl ? NetworkImage(avatarUrl) : null,
      child: hasUrl ? null : Text(initial),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({required this.label, required this.count, required this.onTap});

  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text('$label $count'),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _avatarController;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user['displayName']?.toString() ?? '');
    _avatarController = TextEditingController(text: widget.user['avatarUrl']?.toString() ?? '');
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    final url = Uri.parse('$_apiBaseUrl/api/auth/update');
    final body = jsonEncode({
      'id': widget.user['id'],
      'displayName': _nameController.text.trim(),
      'avatarUrl': _avatarController.text.trim(),
    });

    try {
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(_requestTimeout);

      if (res.statusCode == 200) {
        final updated = jsonDecode(res.body) as Map<String, dynamic>;
        if (!mounted) {
          return;
        }
        Navigator.pop(context, updated);
      } else {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存に失敗しました')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ユーザー設定')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '表示名'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _avatarController,
              decoration: const InputDecoration(labelText: 'アバターURL'),
            ),
            const SizedBox(height: 24),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(onPressed: _save, child: const Text('保存')),
          ],
        ),
      ),
    );
  }
}
