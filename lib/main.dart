import 'package:flutter/material.dart';
import 'dart:async';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:firebase_storage/firebase_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '프홈',
      debugShowCheckedModeBanner: false,
      // 로그인 상태를 실시간으로 감지해서 화면 전환
      home: const HomeScreen(),
    );
  }
}

class TodoItem {
  String id;
  String text;
  bool isDone;
  TodoItem({required this.id, required this.text, this.isDone = false});
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _seconds = 25 * 60;
  bool _isRunning = false;
  Timer? _timer;
  int _totalSeconds = 0;
  Timer? _totalTimer;
  DateTime _selectedDay = DateTime.now();
  List<TodoItem> _todos = [];
  File? _photoFile;
  String? _photoUrl;
  String _myCode = '';

  ui.Image? _catImage;
  int _catFrame = 0;
  Timer? _catTimer;

  final _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadCatImage();
    _loadPhoto();
    _loadMyCode().then((_) => _loadTodos());
  }

  Future<void> _loadCatImage() async {
    final data = await rootBundle.load('assets/images/cat 1.png');
    final bytes = data.buffer.asUint8List();
    final image = await decodeImageFromList(bytes);
    setState(() => _catImage = image);
    _catTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() => _catFrame = (_catFrame + 1) % 2);
    });
  }

  void _loadTodos() {
    // 유저 코드 기준으로 해당 유저의 투두만 불러옴
    _db
        .collection('users')
        .doc(_myCode)
        .collection('todos')
        .orderBy('createdAt')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _todos = snapshot.docs.map((doc) {
          return TodoItem(id: doc.id, text: doc['text'], isDone: doc['isDone']);
        }).toList();
      });
    });
  }

  Future<void> _loadMyCode() async {
    final prefs = await SharedPreferences.getInstance();
    String? code = prefs.getString('my_code');
    if (code == null) {
      // 최초 설치 시 코드 생성
      final words = [
        'BUNNY',
        'KITTY',
        'PUPPY',
        'PANDA',
        'CAPYBARA',
        'DUCKLING',
        'FOX',
        'PENGUIN',
        'TURTLE',
        'HONEY',
        'PLUSH',
        'FLUFFY',
        'SQUISHY',
        'CUDDLY',
        'BUBBLY',
        'CHERRY',
        'COOKIE',
        'CANDY',
        'JELLY',
        'MILKY',
        'DOODLE',
        'APRICOT',
        'PUFFERFISH',
      ];
      final word = words[Random().nextInt(words.length)];
      final number = Random().nextInt(9000) + 1000;
      code = '$word-$number';
      await prefs.setString('my_code', code);
    }
    setState(() => _myCode = code!);
  }

  Future<void> _saveTodo(String text, String? editId) async {
    if (text.trim().isEmpty) return;
    final todosRef = _db.collection('users').doc(_myCode).collection('todos');
    if (editId != null) {
      await todosRef.doc(editId).update({'text': text.trim()});
    } else {
      await todosRef.add({
        'text': text.trim(),
        'isDone': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _deleteTodo(String id) async {
    await _db
        .collection('users')
        .doc(_myCode)
        .collection('todos')
        .doc(id)
        .delete();
  }

  Future<void> _toggleTodo(String id, bool isDone) async {
    await _db
        .collection('users')
        .doc(_myCode)
        .collection('todos')
        .doc(id)
        .update({'isDone': !isDone});
  }

  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
      _totalTimer?.cancel();
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_seconds == 0) {
          timer.cancel();
          _totalTimer?.cancel();
          setState(() => _isRunning = false);
        } else {
          setState(() => _seconds--);
        }
      });
      _totalTimer = Timer.periodic(
        const Duration(seconds: 1),
        (timer) => setState(() => _totalSeconds++),
      );
    }
    setState(() => _isRunning = !_isRunning);
  }

  void _resetTimer() {
    _timer?.cancel();
    _totalTimer?.cancel();
    setState(() {
      _seconds = 25 * 60;
      _isRunning = false;
    });
  }

  String get _timeString {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _totalTimeString {
    final h = (_totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((_totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (_totalSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked == null) return;

    final file = File(picked.path);
    setState(() => _photoFile = file);

    // Firebase Storage에 업로드
    final ref = FirebaseStorage.instance.ref().child(
          'photos/$_myCode/today.jpg',
        );
    await ref.putFile(file);
    final url = await ref.getDownloadURL();

    // URL을 SharedPreferences에 저장
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('photo_url', url);
    setState(() => _photoUrl = url);
  }

  // 앱 시작할 때 저장된 사진 불러오기
  Future<void> _loadPhoto() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('photo_url');
    if (url != null) setState(() => _photoUrl = url);
  }

  void _showAddTodoDialog({String? editId, String? editText}) {
    final controller = TextEditingController(text: editText ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(editId != null ? '일정 수정' : '일정 추가'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '할 일을 입력하세요'),
          onSubmitted: (_) {
            _saveTodo(controller.text, editId);
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              _saveTodo(controller.text, editId);
              Navigator.pop(context);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _totalTimer?.cancel();
    _catTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F6F2),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.grey),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsScreen(myCode: _myCode),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              // ── 상단: 고양이 + 사진 + 타이머 ──
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Container(
                        margin: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.purple[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _catImage == null
                            ? const Center(child: CircularProgressIndicator())
                            : CustomPaint(
                                painter: CatSpritePainter(
                                  image: _catImage!,
                                  frame: _catFrame,
                                  row: 0,
                                  frameSize: 33,
                                  cols: 11,
                                  scale: 4,
                                ),
                              ),
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Container(
                              margin: const EdgeInsets.fromLTRB(0, 6, 6, 3),
                              decoration: BoxDecoration(
                                color: Colors.yellow[200],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: GestureDetector(
                                onTap: _pickImage,
                                child: _photoUrl != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          _photoUrl!,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                        ),
                                      )
                                    : _photoFile != null
                                        ? ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: Image.file(
                                              _photoFile!,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity,
                                            ),
                                          )
                                        : const Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.camera_alt,
                                                  size: 28,
                                                  color: Colors.grey,
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  '사진 추가',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Container(
                              margin: const EdgeInsets.fromLTRB(0, 3, 6, 6),
                              decoration: BoxDecoration(
                                color: Colors.green[200],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _timeString,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '총 $_totalTimeString',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.green[800],
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        onPressed: _toggleTimer,
                                        icon: Icon(
                                          _isRunning
                                              ? Icons.pause
                                              : Icons.play_arrow,
                                        ),
                                        iconSize: 20,
                                      ),
                                      IconButton(
                                        onPressed: _resetTimer,
                                        icon: const Icon(Icons.refresh),
                                        iconSize: 20,
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
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // ── 중단: 달력 + 투두리스트 ──
              Expanded(
                flex: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.teal[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      TableCalendar(
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: _selectedDay,
                        selectedDayPredicate: (day) =>
                            isSameDay(_selectedDay, day),
                        onDaySelected: (selectedDay, focusedDay) =>
                            setState(() => _selectedDay = selectedDay),
                        calendarFormat: CalendarFormat.week,
                        availableCalendarFormats: const {
                          CalendarFormat.week: 'Week',
                        },
                        onPageChanged: (focusedDay) =>
                            setState(() => _selectedDay = focusedDay),
                        headerVisible: false,
                        calendarStyle: CalendarStyle(
                          todayDecoration: const BoxDecoration(
                            color: Colors.teal,
                            shape: BoxShape.circle,
                          ),
                          selectedDecoration: BoxDecoration(
                            color: Colors.teal[300],
                            shape: BoxShape.circle,
                          ),
                          cellMargin: const EdgeInsets.all(4),
                          todayTextStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                          defaultTextStyle: const TextStyle(fontSize: 11),
                          weekendTextStyle: const TextStyle(fontSize: 11),
                          selectedTextStyle: const TextStyle(fontSize: 11),
                        ),
                        daysOfWeekStyle: const DaysOfWeekStyle(
                          weekdayStyle: TextStyle(fontSize: 10),
                          weekendStyle: TextStyle(fontSize: 10),
                        ),
                      ),
                      Divider(height: 1, color: Colors.teal[200]),
                      Expanded(
                        child: _todos.isEmpty
                            // 투두 없을 때: 화면 전체 터치 → 입력창
                            ? GestureDetector(
                                onTap: _showAddTodoDialog,
                                behavior: HitTestBehavior.opaque,
                                child: const Center(
                                  child: Text(
                                    '터치해서 일정을 추가하세요',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              )
                            // 투두 있을 때: 리스트 + 맨 아래 빈 공간
                            : CustomScrollView(
                                slivers: [
                                  // 투두 아이템 목록
                                  SliverList(
                                    delegate: SliverChildBuilderDelegate((
                                      context,
                                      index,
                                    ) {
                                      final todo = _todos[index];
                                      return Slidable(
                                        key: Key(todo.id),
                                        endActionPane: ActionPane(
                                          motion: const DrawerMotion(),
                                          extentRatio: 0.2,
                                          children: [
                                            CustomSlidableAction(
                                              onPressed: (_) =>
                                                  _deleteTodo(todo.id),
                                              backgroundColor: Colors.red,
                                              child: const Icon(
                                                Icons.close,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          child: Row(
                                            children: [
                                              // ① 체크박스: 터치 → 체크 토글
                                              GestureDetector(
                                                onTap: () => _toggleTodo(
                                                  todo.id,
                                                  todo.isDone,
                                                ),
                                                child: Container(
                                                  width: 22,
                                                  height: 22,
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: Colors.teal,
                                                      width: 2,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      4,
                                                    ),
                                                    color: todo.isDone
                                                        ? Colors.teal
                                                        : Colors.transparent,
                                                  ),
                                                  child: todo.isDone
                                                      ? const Icon(
                                                          Icons.check,
                                                          size: 14,
                                                          color: Colors.white,
                                                        )
                                                      : null,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              // ② 텍스트: 터치 → 새 투두 입력창
                                              Expanded(
                                                child: GestureDetector(
                                                  onTap: _showAddTodoDialog,
                                                  child: Text(
                                                    todo.text,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      decoration: todo.isDone
                                                          ? TextDecoration
                                                              .lineThrough
                                                          : null,
                                                      color: todo.isDone
                                                          ? Colors.grey
                                                          : Colors.black87,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              // ③ 수정 버튼: 터치 → 수정창
                                              IconButton(
                                                onPressed: () =>
                                                    _showAddTodoDialog(
                                                  editId: todo.id,
                                                  editText: todo.text,
                                                ),
                                                icon: const Icon(
                                                  Icons.edit,
                                                  size: 16,
                                                  color: Colors.grey,
                                                ),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }, childCount: _todos.length),
                                  ),
                                  // 리스트 아래 빈 공간: 터치 → 새 투두 입력창
                                  SliverFillRemaining(
                                    hasScrollBody: false,
                                    child: GestureDetector(
                                      onTap: _showAddTodoDialog,
                                      behavior: HitTestBehavior.opaque,
                                      child: const SizedBox.expand(),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // ── 하단: 친구 마을 ──
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.pink[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '친구 마을',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              Friend(
                                name: '지민',
                                color: Colors.red[200]!,
                              ),
                              Friend(
                                name: '수연',
                                color: Colors.blue[200]!,
                              ),
                              Friend(
                                name: '하은',
                                color: Colors.green[200]!,
                              ),
                              Friend(
                                name: '서아',
                                color: Colors.orange[200]!,
                              ),
                            ]
                                .map(
                                  (friend) => GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            FriendPage(friend: friend),
                                      ),
                                    ),
                                    child: Container(
                                      margin: const EdgeInsets.only(
                                        right: 12,
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          CustomPaint(
                                            size: const Size(40, 40),
                                            painter: HousePainter(
                                              color: friend.color,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            friend.name,
                                            style: const TextStyle(
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Friend {
  final String name;
  final Color color;
  Friend({required this.name, required this.color});
}

class FriendPage extends StatelessWidget {
  final Friend friend;
  const FriendPage({super.key, required this.friend});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F2),
      appBar: AppBar(
        backgroundColor: friend.color,
        title: Text('${friend.name}의 프홈'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Center(child: Text('친구 페이지 (나중에 채울 것)')),
    );
  }
}

class HousePainter extends CustomPainter {
  final Color color;
  HousePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.1,
        size.height * 0.45,
        size.width * 0.8,
        size.height * 0.55,
      ),
      paint,
    );
    final roofPath = Path()
      ..moveTo(0, size.height * 0.5)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height * 0.5)
      ..close();
    canvas.drawPath(roofPath, paint..color = color.withValues(alpha: 0.7));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CatSpritePainter extends CustomPainter {
  final ui.Image image;
  final int frame;
  final int row;
  final double frameSize;
  final int cols;
  final double scale;

  CatSpritePainter({
    required this.image,
    required this.frame,
    required this.row,
    required this.frameSize,
    required this.cols,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 스프라이트 시트에서 잘라낼 원본 영역 (frame번째 열, row번째 행)
    final srcRect = Rect.fromLTWH(
      frame * frameSize,
      row * frameSize,
      frameSize,
      frameSize,
    );
    // 화면 중앙에 scale배 크기로 그릴 영역
    final displaySize = frameSize * scale;
    final dstRect = Rect.fromLTWH(
      (size.width - displaySize) / 2,
      (size.height - displaySize) / 2,
      displaySize,
      displaySize,
    );
    final paint = Paint()..filterQuality = FilterQuality.none;
    canvas.drawImageRect(image, srcRect, dstRect, paint);
  }

  @override
  bool shouldRepaint(covariant CatSpritePainter oldDelegate) {
    return oldDelegate.frame != frame || oldDelegate.row != row;
  }
}

class SettingsScreen extends StatefulWidget {
  final String myCode;
  const SettingsScreen({super.key, required this.myCode});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  User? _user = FirebaseAuth.instance.currentUser;

  Future<void> _signInWithGoogle() async {
    final GoogleSignIn googleSignIn = GoogleSignIn();
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) return;
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await FirebaseAuth.instance.signInWithCredential(credential);
    setState(() => _user = result.user);
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
    setState(() => _user = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F6F2),
        elevation: 0,
        title: const Text('설정', style: TextStyle(color: Colors.black87)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '계정',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          // 로그인 상태에 따라 다르게 표시
          _user == null
              ? ListTile(
                  leading: const Icon(Icons.login, color: Colors.deepPurple),
                  title: const Text('Google로 로그인'),
                  onTap: _signInWithGoogle,
                )
              : ListTile(
                  leading: const CircleAvatar(
                    radius: 16,
                    child: Icon(Icons.person, size: 16),
                  ),
                  title: Text(_user!.displayName ?? '사용자'),
                  subtitle: Text(_user!.email ?? ''),
                  trailing: TextButton(
                    onPressed: _signOut,
                    child: const Text(
                      '로그아웃',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.tag, color: Colors.deepPurple, size: 20),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '내 코드',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      widget.myCode,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.deepPurple, width: 2),
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.deepPurple,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              '꾸미기',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.palette, color: Colors.deepPurple),
            title: const Text('테마 설정'),
            subtitle: const Text('포근뽀용 / 깔끔모던시크'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.check_circle, color: Colors.deepPurple),
            title: const Text('완료 아이콘 설정'),
            subtitle: const Text('체크 / 하트 / 별'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
