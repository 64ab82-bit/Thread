import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _apiBaseUrlFromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
const _requestTimeout = Duration(seconds: 12);

String get _apiBaseUrl {
  if (_apiBaseUrlFromEnv.isNotEmpty) {
    return _apiBaseUrlFromEnv;
  }
  return 'https://localhost:5001';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final userStr = prefs.getString('user');
  if (userStr != null) {
    final user = jsonDecode(userStr) as Map<String, dynamic>;
    runApp(BbsAppWithUser(user: user));
  } else {
    runApp(const BbsApp());
  }
}

class BbsAppWithUser extends StatelessWidget {
  final Map<String, dynamic> user;
  const BbsAppWithUser({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '掲示板',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: BbsHomePage(user: user),
    );
  }
}

class BbsApp extends StatefulWidget {
  const BbsApp({super.key});

  @override
  State<BbsApp> createState() => _BbsAppState();

  static _BbsAppState? of(BuildContext context) {
    return context.findAncestorStateOfType<_BbsAppState>();
  }
}

class _BbsAppState extends State<BbsApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('darkMode') ?? false;
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  Future<void> toggleThemeMode() async {
    final isDark = _themeMode == ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', !isDark);
    setState(() {
      _themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '掲示板サービス',
      theme: ThemeData(
        colorScheme: ColorScheme.light(
          primary: Colors.black,
          secondary: Colors.grey.shade700,
          surface: Colors.white,
          background: Colors.grey.shade50,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
        ),
        dividerTheme: DividerThemeData(color: Colors.grey.shade200, thickness: 1),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: Colors.white,
          secondary: Colors.grey.shade400,
          surface: Colors.grey.shade900,
          background: Colors.black,
        ),
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.grey.shade900,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(color: Colors.grey.shade800, width: 1),
          ),
        ),
        dividerTheme: DividerThemeData(color: Colors.grey.shade800, thickness: 1),
        useMaterial3: true,
      ),
      themeMode: _themeMode,
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
  bool _obscurePassword = true;

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
        // ユーザー情報を永続化
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(user));
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
              padding: const EdgeInsets.all(20),
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
                    decoration: InputDecoration(
                      labelText: 'パスワード',
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    onSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 20),
                  _loading
                      ? const CircularProgressIndicator()
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                            child: const Text('ログイン', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          ),
                        ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey.shade400
                          : Colors.grey.shade700,
                    ),
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
          'avatarUrl': '',
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
              padding: const EdgeInsets.all(20),
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
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 20),
                  _loading
                      ? const CircularProgressIndicator()
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                            child: const Text('登録する', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          ),
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
  final _searchTitleController = TextEditingController();
  final _searchBodyController = TextEditingController();
  late Map<String, dynamic> _currentUser;
  List<Map<String, dynamic>> _threads = [];
  int _selectedThread = 0;
  bool _loading = true;
  DateTime? _searchDate;
  Map<String, dynamic>? _replyTarget;
  Map<int, DateTime> _lastSeenMap = {};
  Set<int> _favoriteIds = {};

  @override
  void initState() {
    super.initState();
    _currentUser = Map<String, dynamic>.from(widget.user);
    _loadLastSeen();
    _loadFavorites();
    _loadThreads();
    _saveUserToPrefs();
  }

  Future<void> _saveUserToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(_currentUser));
  }

  Future<void> _loadLastSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final map = <int, DateTime>{};
    for (final key in keys) {
      if (key.startsWith('lastSeen_')) {
        final threadId = int.tryParse(key.substring(9));
        final timestamp = prefs.getInt(key);
        if (threadId != null && timestamp != null) {
          map[threadId] = DateTime.fromMillisecondsSinceEpoch(timestamp);
        }
      }
    }
    setState(() {
      _lastSeenMap = map;
    });
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('favorites') ?? [];
    setState(() {
      _favoriteIds = list.map((e) => int.tryParse(e)).whereType<int>().toSet();
    });
  }

  Future<void> _toggleFavorite(int threadId) async {
    final prefs = await SharedPreferences.getInstance();
    final newSet = Set<int>.from(_favoriteIds);
    if (newSet.contains(threadId)) {
      newSet.remove(threadId);
    } else {
      newSet.add(threadId);
    }
    await prefs.setStringList('favorites', newSet.map((e) => '$e').toList());
    setState(() {
      _favoriteIds = newSet;
    });
  }

  Future<void> _markThreadAsSeen(int threadId) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setInt('lastSeen_$threadId', now.millisecondsSinceEpoch);
    setState(() {
      _lastSeenMap[threadId] = now;
    });
  }

  int _getUnreadCount(Map<String, dynamic> thread) {
    final threadId = thread['id'] as int;
    final lastSeen = _lastSeenMap[threadId];
    if (lastSeen == null) {
      return (thread['comments'] as List).length;
    }
    final comments = (thread['comments'] as List).cast<Map<String, dynamic>>();
    return comments.where((c) {
      final createdAt = c['createdAt'] as DateTime;
      return createdAt.isAfter(lastSeen);
    }).length;
  }

  Future<void> _loadThreads() async {
    setState(() => _loading = true);
    try {
      final titleQ = _searchTitleController.text.trim();
      final bodyQ = _searchBodyController.text.trim();
      final dateQ = _searchDate != null
          ? '&date=${_searchDate!.year}-${_searchDate!.month.toString().padLeft(2, '0')}-${_searchDate!.day.toString().padLeft(2, '0')}'
          : '';
      
      final params = <String>[];
      if (titleQ.isNotEmpty) params.add('title=$titleQ');
      if (bodyQ.isNotEmpty) params.add('body=$bodyQ');
      if (dateQ.isNotEmpty) params.add(dateQ.substring(1));
      
      final query = params.isNotEmpty ? '?${params.join('&')}' : '';
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

        // お気に入りを先頭に並べる
        mapped.sort((a, b) {
          final aFav = _favoriteIds.contains(a['id']);
          final bFav = _favoriteIds.contains(b['id']);
          if (aFav && !bFav) return -1;
          if (!aFav && bFav) return 1;
          return 0;
        });

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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('タイトルとカテゴリは必須です')),
                      );
                      return;
                    }
                    try {
                      final url = Uri.parse('$_apiBaseUrl/api/threads');
                      final res = await http.post(
                        url,
                        headers: {'Content-Type': 'application/json'},
                        body: jsonEncode({
                          'title': title,
                          'category': category,
                          'createdBy': _currentUser['id'],
                        }),
                      ).timeout(_requestTimeout);
                      if (!mounted) return;
                      if (res.statusCode == 200) {
                        Navigator.of(this.context).pop();
                        await _loadThreads();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('投稿失敗: ${res.body.isNotEmpty ? res.body : 'サーバーエラー'}')),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('投稿エラー: $e')),
                      );
                    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('スレッドがありません')),
      );
      return;
    }
    final text = _commentController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('コメント内容は必須です')),
      );
      return;
    }
    try {
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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('コメント投稿失敗: ${res.body.isNotEmpty ? res.body : 'サーバーエラー'}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('コメント投稿エラー: $e')),
      );
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

  Future<void> _editComment(Map<String, dynamic> comment) async {
    final controller = TextEditingController(text: comment['content']?.toString() ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('コメントを編集'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'コメント内容'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade400
                    : Colors.grey.shade700,
              ),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  Navigator.pop(context, text);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                elevation: 0,
              ),
              child: const Text('保存', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (result != null) {
      final url = Uri.parse('$_apiBaseUrl/api/threads/comment/${comment['id']}');
      final res = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': _currentUser['id'],
          'content': result,
        }),
      ).timeout(_requestTimeout);

      if (res.statusCode == 200) {
        await _loadThreads();
      }
    }
  }

  Future<void> _deleteComment(Map<String, dynamic> comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('コメントを削除'),
          content: const Text('このコメントを削除しますか？\n内容は「[削除されました]」に置き換えられます。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade400
                    : Colors.grey.shade700,
              ),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                elevation: 0,
              ),
              child: const Text('削除', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final url = Uri.parse('$_apiBaseUrl/api/threads/comment/${comment['id']}?userId=${_currentUser['id']}');
      final res = await http.delete(url).timeout(_requestTimeout);

      if (res.statusCode == 200) {
        await _loadThreads();
      }
    }
  }

  Widget _buildCommentText(String content) {
    final regex = RegExp(r'@(\w+)');
    final matches = regex.allMatches(content);
    
    if (matches.isEmpty) {
      return Text(content);
    }

    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: content.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(
          color: Colors.blue,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.underline,
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < content.length) {
      spans.add(TextSpan(text: content.substring(lastEnd)));
    }

    return RichText(text: TextSpan(style: DefaultTextStyle.of(context).style, children: spans));
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
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 20,
            ),
            onPressed: () {
              BbsApp.of(context)?.toggleThemeMode();
            },
            tooltip: 'ダークモード切替',
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 22),
            onPressed: _openCreateThreadDialog,
            tooltip: '新規スレッド',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
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
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: [
                            TextField(
                              controller: _searchTitleController,
                              decoration: InputDecoration(
                                hintText: 'スレッド名で検索',
                                prefixIcon: const Icon(Icons.search, size: 20),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                filled: true,
                                fillColor: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey.shade900
                                    : Colors.grey.shade50,
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _searchBodyController,
                              decoration: InputDecoration(
                                hintText: '本文で検索',
                                prefixIcon: const Icon(Icons.text_fields, size: 20),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                filled: true,
                                fillColor: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey.shade900
                                    : Colors.grey.shade50,
                              ),
                              style: const TextStyle(fontSize: 13),
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
                                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                                    label: Text(
                                      _searchDate == null
                                          ? '日付指定'
                                          : '${_searchDate!.year}/${_searchDate!.month}/${_searchDate!.day}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      side: BorderSide(
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.grey.shade700
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _searchDate = null;
                                    });
                                  },
                                  icon: const Icon(Icons.close, size: 18),
                                  tooltip: 'クリア',
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
                            final threadId = item['id'] as int;
                            final commentCount = (item['comments'] as List?)?.length ?? 0;
                            final unreadCount = _getUnreadCount(item);
                            final isFavorite = _favoriteIds.contains(threadId);
                            return ListTile(
                              selected: _selectedThread == index,
                              title: Row(
                                children: [
                                  Expanded(child: Text('${item['title']}')),
                                  if (unreadCount > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.blue.shade700
                                            : Colors.blue.shade500,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '$unreadCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Text('[${item['category']}] $commentCount件  ${_formatDateTime(item['createdAt'] as DateTime)}'),
                              trailing: IconButton(
                                icon: Icon(
                                  isFavorite ? Icons.star : Icons.star_outline,
                                  color: isFavorite
                                      ? (Theme.of(context).brightness == Brightness.dark
                                          ? Colors.yellow.shade600
                                          : Colors.amber.shade700)
                                      : (Theme.of(context).brightness == Brightness.dark
                                          ? Colors.grey.shade600
                                          : Colors.grey.shade400),
                                  size: 20,
                                ),
                                onPressed: () => _toggleFavorite(threadId),
                              ),
                              onTap: () {
                                setState(() => _selectedThread = index);
                                _markThreadAsSeen(threadId);
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
                    padding: const EdgeInsets.all(12),
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
                                            Flexible(
                                              child: Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                    color: Theme.of(context).brightness == Brightness.dark
                                                        ? Colors.grey.shade800
                                                        : Colors.grey.shade200,
                                                  ),
                                                  borderRadius: BorderRadius.circular(6),
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
                                                      const SizedBox(height: 8),
                                                      Container(
                                                        width: double.infinity,
                                                        padding: const EdgeInsets.all(10),
                                                        decoration: BoxDecoration(
                                                          color: Theme.of(context).brightness == Brightness.dark
                                                              ? Colors.grey.shade900
                                                              : Colors.grey.shade50,
                                                          border: Border.all(
                                                            color: Theme.of(context).brightness == Brightness.dark
                                                                ? Colors.grey.shade700
                                                                : Colors.grey.shade300,
                                                          ),
                                                          borderRadius: BorderRadius.circular(5),
                                                        ),
                                                        child: Text(
                                                          '${quoted['content']}',
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: TextStyle(
                                                            color: Theme.of(context).brightness == Brightness.dark
                                                                ? Colors.grey.shade500
                                                                : Colors.grey.shade600,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                    const SizedBox(height: 6),
                                                    _buildCommentText('${c['content']}'),
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
                                                          style: TextButton.styleFrom(
                                                            foregroundColor: Theme.of(context).brightness == Brightness.dark
                                                                ? Colors.grey.shade400
                                                                : Colors.grey.shade700,
                                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                                            textStyle: const TextStyle(fontSize: 12),
                                                          ),
                                                          child: const Text('返信'),
                                                        ),
                                                        if (isMe) ...[
                                                          IconButton(
                                                            icon: const Icon(Icons.edit_outlined, size: 16),
                                                            onPressed: () => _editComment(c),
                                                            tooltip: '編集',
                                                            padding: const EdgeInsets.all(4),
                                                            constraints: const BoxConstraints(),
                                                            color: Theme.of(context).brightness == Brightness.dark
                                                                ? Colors.grey.shade500
                                                                : Colors.grey.shade600,
                                                          ),
                                                          IconButton(
                                                            icon: const Icon(Icons.delete_outline, size: 16),
                                                            onPressed: () => _deleteComment(c),
                                                            tooltip: '削除',
                                                            padding: const EdgeInsets.all(4),
                                                            constraints: const BoxConstraints(),
                                                            color: Theme.of(context).brightness == Brightness.dark
                                                                ? Colors.grey.shade500
                                                                : Colors.grey.shade600,
                                                          ),
                                                        ],
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
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.grey.shade900
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.grey.shade800
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '返信先: ${_replyTarget!['content']}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context).brightness == Brightness.dark
                                                ? Colors.grey.shade400
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () {
                                          setState(() {
                                            _replyTarget = null;
                                          });
                                        },
                                        icon: const Icon(Icons.close, size: 16),
                                        padding: const EdgeInsets.all(4),
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                ),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _commentController,
                                      decoration: InputDecoration(
                                        hintText: 'コメントを入力...',
                                        hintStyle: TextStyle(
                                          fontSize: 13,
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? Colors.grey.shade600
                                              : Colors.grey.shade400,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: Theme.of(context).brightness == Brightness.dark
                                                ? Colors.grey.shade700
                                                : Colors.grey.shade300,
                                          ),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        filled: true,
                                        fillColor: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.grey.shade900
                                            : Colors.grey.shade50,
                                      ),
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton(
                                    onPressed: _postComment,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.white
                                          : Colors.black,
                                      foregroundColor: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.black
                                          : Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                      elevation: 0,
                                    ),
                                    child: const Text('投稿', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({required this.label, required this.count, required this.onTap});

  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: count > 0
              ? (isDark ? Colors.grey.shade800 : Colors.grey.shade100)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
        ),
        child: Text(
          '$label ${count > 0 ? count : ""}',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
          ),
        ),
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
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _loading = false;
  bool _showPasswordSection = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user['displayName']?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    final url = Uri.parse('$_apiBaseUrl/api/auth/update');
    final body = jsonEncode({
      'id': widget.user['id'],
      'displayName': _nameController.text.trim(),
      'avatarUrl': '',
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

  Future<void> _changePassword() async {
    final currentPw = _currentPasswordController.text.trim();
    final newPw = _newPasswordController.text.trim();

    if (currentPw.isEmpty || newPw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('現在のパスワードと新しいパスワードを入力してください')),
      );
      return;
    }

    setState(() => _loading = true);
    final url = Uri.parse('$_apiBaseUrl/api/auth/change-password');
    final body = jsonEncode({
      'id': widget.user['id'],
      'currentPassword': currentPw,
      'newPassword': newPw,
    });

    try {
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(_requestTimeout);

      if (!mounted) {
        return;
      }

      if (res.statusCode == 200) {
        _currentPasswordController.clear();
        _newPasswordController.clear();
        setState(() {
          _showPasswordSection = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('パスワードを変更しました')),
        );
      } else {
        final errorMsg = res.body.isNotEmpty ? res.body : 'パスワード変更に失敗しました';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    } on TimeoutException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('タイムアウトしました')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $e')),
      );
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '表示名'),
            ),
            const SizedBox(height: 24),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(onPressed: _save, child: const Text('保存')),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _showPasswordSection = !_showPasswordSection;
                });
              },
              icon: Icon(_showPasswordSection ? Icons.expand_less : Icons.expand_more),
              label: const Text('パスワードを変更'),
            ),
            if (_showPasswordSection) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _currentPasswordController,
                decoration: const InputDecoration(labelText: '現在のパスワード'),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newPasswordController,
                decoration: const InputDecoration(labelText: '新しいパスワード'),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loading ? null : _changePassword,
                child: const Text('パスワードを変更'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
