import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const _apiBaseUrl = 'http://localhost:5001';

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
  bool _isLogin = true;
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
      final endpoint = _isLogin ? 'login' : 'register';
      final url = Uri.parse('$_apiBaseUrl/api/auth/$endpoint');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': id, 'password': pw}),
      );

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
          _error = '認証に失敗しました';
        });
      }
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
      appBar: AppBar(title: Text(_isLogin ? 'ログイン' : '新規登録')),
      body: Center(
        child: SizedBox(
          width: 420,
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
                          child: Text(_isLogin ? 'ログイン' : '新規登録'),
                        ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLogin = !_isLogin;
                        _error = null;
                      });
                    },
                    child: Text(_isLogin ? '新規登録はこちら' : 'ログインはこちら'),
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

class BbsHomePage extends StatefulWidget {
  const BbsHomePage({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<BbsHomePage> createState() => _BbsHomePageState();
}

class _BbsHomePageState extends State<BbsHomePage> {
  final _commentController = TextEditingController();
  late Map<String, dynamic> _currentUser;
  List<Map<String, dynamic>> _threads = [];
  int _selectedThread = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _currentUser = Map<String, dynamic>.from(widget.user);
    _loadThreads();
  }

  Future<void> _loadThreads() async {
    setState(() => _loading = true);
    try {
      final url = Uri.parse('$_apiBaseUrl/api/threads');
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        final mapped = list.map<Map<String, dynamic>>((t) {
          final comments = (t['comments'] as List<dynamic>? ?? []).map<Map<String, dynamic>>((c) {
            final userId = c['userId'];
            return {
              'id': c['id'],
              'userId': userId,
              'userName': 'ユーザー${userId ?? '匿名'}',
              'content': c['content'] ?? '',
              'createdAt': DateTime.tryParse('${c['createdAt']}') ?? DateTime.now(),
              'isMe': _currentUser['id'] != null && userId == _currentUser['id'],
            };
          }).toList();

          return {
            'id': t['id'],
            'title': '${t['title'] ?? '無題スレッド'}',
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
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
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
      'parentCommentId': null,
    });

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (res.statusCode == 200) {
      final payload = jsonDecode(res.body) as Map<String, dynamic>;
      final comment = {
        'id': payload['id'] ?? payload['Id'],
        'userId': payload['userId'] ?? payload['UserId'] ?? _currentUser['id'],
        'userName': _currentUser['displayName'] ?? _currentUser['username'] ?? '自分',
        'content': text,
        'createdAt': DateTime.tryParse('${payload['createdAt'] ?? payload['CreatedAt']}') ?? DateTime.now(),
        'isMe': true,
      };

      setState(() {
        final comments = (_threads[_selectedThread]['comments'] as List).cast<Map<String, dynamic>>();
        comments.add(comment);
        _commentController.clear();
      });
    }
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
                  width: 280,
                  child: ListView.builder(
                    itemCount: _threads.length,
                    itemBuilder: (context, index) {
                      final item = _threads[index];
                      return ListTile(
                        selected: _selectedThread == index,
                        title: Text('${item['title']}'),
                        subtitle: Text(_formatDateTime(item['createdAt'] as DateTime)),
                        onTap: () {
                          setState(() => _selectedThread = index);
                        },
                      );
                    },
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
                              const SizedBox(height: 12),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: comments.length,
                                  itemBuilder: (context, index) {
                                    final c = comments[index];
                                    final isMe = c['isMe'] == true;
                                    return Align(
                                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                      child: Card(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('${c['userName']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 4),
                                              Text('${c['content']}'),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
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
      );

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
