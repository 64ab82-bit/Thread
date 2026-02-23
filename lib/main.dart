
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;


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
        scaffoldBackgroundColor: const Color(0xFFF6F8FB),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 1,
        ),
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
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _pwController = TextEditingController();
  String? _error;
  bool _isLogin = true;
  bool _loading = false;

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    final id = _idController.text.trim();
    final pw = _pwController.text.trim();
    if (id.isEmpty || pw.isEmpty) {
      setState(() { _error = 'IDとパスワードを入力してください'; _loading = false; });
      return;
    }
    try {
      final url = Uri.parse('http://localhost:5000/api/auth/${_isLogin ? 'login' : 'register'}');
      final res = await http.post(url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': id,
          'password': pw,
        }),
      );
      if (res.statusCode == 200) {
        final user = jsonDecode(res.body);
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => BbsHomePage(user: user),
        ));
      } else {
        setState(() { _error = '認証に失敗しました'; });
      }
    } catch (e) {
      setState(() { _error = '通信エラー: $e'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'ログイン' : '新規登録')),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _idController,
                    decoration: const InputDecoration(labelText: 'ユーザーID'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _pwController,
                    decoration: const InputDecoration(labelText: 'パスワード'),
                    obscureText: true,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 24),
                  _loading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _submit,
                          child: Text(_isLogin ? 'ログイン' : '新規登録'),
                        ),
                  TextButton(
                    onPressed: () {
                      setState(() { _isLogin = !_isLogin; _error = null; });
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
        final Map<String, dynamic> user;
        const BbsHomePage({super.key, required this.user});
        @override
        State<BbsHomePage> createState() => _BbsHomePageState();
      }

        int selectedThread = 0;
        late List<Map<String, dynamic>> threads;
        final TextEditingController _controller = TextEditingController();

        @override
        void initState() {
          super.initState();
            threads = [];
            _loadThreads();
        }

          Future<void> _loadThreads() async {
            try {
              final url = Uri.parse('http://localhost:5000/api/threads');
              final res = await http.get(url);
              if (res.statusCode == 200) {
                final list = jsonDecode(res.body) as List<dynamic>;
                setState(() {
                  threads = list.map<Map<String, dynamic>>((t) {
                    final comments = (t['comments'] as List<dynamic>?) ?? [];
                    return {
                      'id': t['id'],
                      'title': t['title'],
                      'createdAt': DateTime.parse(t['createdAt']),
                      'comments': comments.map<Map<String, dynamic>>((c) {
                        final userId = c['userId'];
                        return {
                          'id': c['id'],
                          'userId': userId,
                          'userName': 'ユーザー${userId ?? '匿名'}',
                          'userImage': 'https://api.dicebear.com/7.x/personas/svg?seed=${userId ?? 'anon'}',
                          'content': c['content'],
                          'createdAt': DateTime.parse(c['createdAt']),
                          'isMe': widget.user['id'] != null && userId == widget.user['id'],
                        };
                      }).toList(),
                    };
                  }).toList();
                  if (threads.isNotEmpty) selectedThread = 0;
                });
              } else {
                // leave empty or show error
              }
            } catch (e) {
              // ignore for now
            }
          }

        String _formatDateTime(DateTime dt) {
          return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        }

        String _formatTime(DateTime dt) {
          return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        }

        @override
        Widget build(BuildContext context) {
          final thread = threads[selectedThread];
          final comments = thread['comments'] as List;
          return Scaffold(
          appBar: AppBar(
            title: const Text('掲示板モックアップ', style: TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () async {
                  final updated = await Navigator.push(context, MaterialPageRoute(
                    builder: (_) => SettingsScreen(user: widget.user),
                  ));
                  if (updated != null && updated is Map<String, dynamic>) {
                    setState(() {
                      widget.user.addAll(updated);
                    });
                  }
                },
              ),
            ],
          ),
            body: Row(
              children: [
                // 左側: スレッド一覧
                Container(
                  width: 280,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(2, 0),
                      ),
                    ],
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: const [
                            Icon(Icons.forum, color: Colors.indigo),
                            SizedBox(width: 8),
                            Text('スレッド一覧', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.builder(
                          itemCount: threads.length,
                          itemBuilder: (context, index) {
                            final t = threads[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              elevation: selectedThread == index ? 4 : 1,
                              color: selectedThread == index ? Colors.indigo[50] : Colors.white,
                              child: ListTile(
                                title: Text(t['title'], style: const TextStyle(fontWeight: FontWeight.w500)),
                                subtitle: Text('作成: ' + _formatDateTime(t['createdAt'])),
                                selected: selectedThread == index,
                                selectedTileColor: Colors.indigo[50],
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                onTap: () {
                                  setState(() {
                                    selectedThread = index;
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // 右側: スレッド内容と書き込みフォーム
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text('${thread['title']}の内容', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                          ),
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
                                child: Container(
                                  margin: EdgeInsets.only(
                                    top: 8,
                                    bottom: 8,
                                    left: isMe ? 60 : 0,
                                    right: isMe ? 0 : 60,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (!isMe) ...[
                                        CircleAvatar(
                                          backgroundImage: NetworkImage(c['userImage']),
                                          radius: 18,
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Flexible(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                          decoration: BoxDecoration(
                                            color: isMe ? Colors.indigo[100] : Colors.white,
                                            borderRadius: BorderRadius.only(
                                              topLeft: const Radius.circular(16),
                                              topRight: const Radius.circular(16),
                                              bottomLeft: Radius.circular(isMe ? 16 : 4),
                                              bottomRight: Radius.circular(isMe ? 4 : 16),
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.04),
                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    c['userName'],
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: isMe ? Colors.indigo : Colors.black87,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    _formatTime(c['createdAt']),
                                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                c['content'],
                                                style: const TextStyle(fontSize: 15),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (isMe) ...[
                                        const SizedBox(width: 8),
                                        CircleAvatar(
                                          backgroundImage: NetworkImage(c['userImage']),
                                          radius: 18,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _controller,
                                    decoration: const InputDecoration(
                                      hintText: '書き込み内容を入力...',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  ),
                                  onPressed: () async {
                                      final text = _controller.text.trim();
                                      if (text.isEmpty) return;
                                      final threadId = thread['id'];
                                      final url = Uri.parse('http://localhost:5000/api/threads/comment');
                                      final body = jsonEncode({
                                        'threadId': threadId,
                                        'userId': widget.user['id'],
                                        'content': text,
                                        'parentCommentId': null,
                                      });
                                      try {
                                        final res = await http.post(url, headers: {'Content-Type':'application/json'}, body: body);
                                        if (res.statusCode == 200) {
                                          final r = jsonDecode(res.body);
                                          final cid = r['id'] ?? r['Id'];
                                          final cUserId = r['userId'] ?? r['UserId'];
                                          final createdAtStr = r['createdAt'] ?? r['CreatedAt'];
                                          final createdAt = createdAtStr != null ? DateTime.parse(createdAtStr) : DateTime.now();
                                          setState(() {
                                            comments.add({
                                              'id': cid,
                                              'userId': cUserId,
                                              'userName': widget.user['displayName'] ?? '自分',
                                              'userImage': widget.user['avatarUrl'] ?? 'https://api.dicebear.com/7.x/personas/svg?seed=me',
                                              'content': text,
                                              'createdAt': createdAt,
                                              'isMe': true,
                                            });
                                            _controller.clear();
                                          });
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('投稿に失敗しました')));
                                        }
                                      } catch (e) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('通信エラー: $e')));
                                      }
                                    },
                                  child: const Text('投稿', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      }

      class SettingsScreen extends StatefulWidget {
        final Map<String, dynamic> user;
        const SettingsScreen({super.key, required this.user});
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
          _nameController = TextEditingController(text: widget.user['displayName'] ?? '');
          _avatarController = TextEditingController(text: widget.user['avatarUrl'] ?? '');
        }

        Future<void> _save() async {
          setState(() => _loading = true);
          final url = Uri.parse('http://localhost:5000/api/auth/update');
          final body = jsonEncode({
            'id': widget.user['id'],
            'displayName': _nameController.text.trim(),
            'avatarUrl': _avatarController.text.trim(),
          });
          try {
            final res = await http.post(url, headers: {'Content-Type': 'application/json'}, body: body);
            if (res.statusCode == 200) {
              final updated = jsonDecode(res.body);
              Navigator.pop(context, updated);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存に失敗しました')));
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('通信エラー: $e')));
          } finally {
            setState(() => _loading = false);
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
                  TextField(controller: _nameController, decoration: const InputDecoration(labelText: '表示名')),
                  const SizedBox(height: 12),
                  TextField(controller: _avatarController, decoration: const InputDecoration(labelText: 'アバターURL')),
                  const SizedBox(height: 24),
                  _loading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _save, child: const Text('保存')),
                ],
              ),
            ),
          );
        }
      }
