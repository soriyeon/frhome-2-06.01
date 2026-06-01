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
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  kakao.KakaoSdk.init(nativeAppKey: '3f4be132af4916508509cf8ece47ba37');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '프홈',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.notoSansTextTheme(),
      ),
      home: const HomeScreen(),
    );
  }
}

//테마 컬러 클래스
class AppTheme {
  final Color background;
  final Color catCard;
  final Color photoCard;
  final Color timerCard;
  final Color todoCard;
  final Color friendCard;
  final Color textPrimary;
  final Color textSecondary;

  const AppTheme({
    required this.background,
    required this.catCard,
    required this.photoCard,
    required this.timerCard,
    required this.todoCard,
    required this.friendCard,
    required this.textPrimary,
    required this.textSecondary,
  });

  // 기본 테마
  static const AppTheme defaultTheme = AppTheme(
    background: Color(0xFFF5F5F5),
    catCard: Color(0xFFE8D0E5),
    photoCard: Color(0xFFF5F5F5),
    timerCard: Color(0xFFE8E8E8),
    todoCard: Color(0xFF8E7C78),
    friendCard: Color(0xFF413B35),
    textPrimary: Color(0xFF000000),
    textSecondary: Color(0xFF666666),
  );
}

class TodoItem {
  String id;
  String text;
  bool isDone;
  bool iconSeed; //True = music_note, false = queue_music / filter_drama면 cloud
  TodoItem({
    required this.id,
    required this.text,
    this.isDone = false,
    this.iconSeed = false,
  });
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
  String _pomodoroMode = '30min';
  List<String> _friendCodes = [];
  double _totalXp = 0;
  double _todayXp = 0;
  int _todayTodoCount = 0;
  int _friendRequestCount = 0;
  String _completionIcon = 'check';

  String _petStage = 'egg';
  String _petType = '';
  String _petVariant = '';

  ui.Image? _eggImage;

  int _catFrame = 0;
  Timer? _catTimer;

  final AppTheme _currentTheme = AppTheme.defaultTheme;

  final _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadEggImage();
    _loadPhoto();
    _loadMyCode().then((_) {
      _loadTodos();
      _loadPomodoroMode();
      _loadXpData();
      _loadFriends();
      _loadFriendRequests();
      _loadCompletionIcon();
    });

    _catTimer = Timer.periodic(const Duration(milliseconds: 500), (Timer) {
      setState(() => _catFrame = (_catFrame + 1) % 2);
    });
  }

  Future<void> _loadEggImage() async {
    final data = await rootBundle.load('assets/images/egg.png');
    final bytes = data.buffer.asUint8List();
    final image = await decodeImageFromList(bytes);
    setState(() => _eggImage = image);
  }

  void _loadTodos() {
    _db
        .collection('users')
        .doc(_myCode)
        .collection('todos')
        .orderBy('createdAt')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _todos = snapshot.docs.map((doc) {
          return TodoItem(
            id: doc.id,
            text: doc['text'],
            isDone: doc['isDone'],
            iconSeed: doc['iconSeed'] ?? Random().nextBool(),
          );
        }).toList();
      });
    });
  }

  Future<void> _loadMyCode() async {
    final prefs = await SharedPreferences.getInstance();
    String? code = prefs.getString('my_code');
    if (code == null) {
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
    await _db.collection('users').doc(code).set({
      'code': code,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _loadPomodoroMode() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('pomodoro_mode') ?? '30min';
    setState(() {
      _pomodoroMode = mode;
      if (mode == '60min') {
        _seconds = 55 * 60;
      } else {
        _seconds = 25 * 60;
      }
    });
  }

  Future<void> _loadCompletionIcon() async {
    final prefs = await SharedPreferences.getInstance();
    final icon = prefs.getString('completion_icon') ?? 'check';
    setState(() => _completionIcon = icon);
  }

  IconData _getCompletionIcon({bool iconSeed = false}) {
    switch (_completionIcon) {
      case 'kid_star':
        return Icons.star;
      case 'heart_check':
        return Icons.favorite;
      case 'close_small':
        return Icons.close;
      case 'pets':
        return Icons.pets;
      case 'mood':
        return Icons.mood;
      case 'cruelty_free':
        return Icons.cruelty_free;
      case 'cookie':
        return Icons.cookie;
      case 'circle':
        return Icons.circle;
      case 'filter_drama':
        return iconSeed ? Icons.filter_drama : Icons.cloud;
      case 'healing':
        return Icons.healing;
      case 'music_note':
        return Random().nextBool() ? Icons.music_note : Icons.queue_music;
      case 'lunch_dining':
        return Icons.lunch_dining;
      case 'casino':
        return Icons.casino;
      default:
        return Icons.check;
    }
  }

  Future<void> _loadXpData() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final doc = await _db.collection('users').doc(_myCode).get();

    final data = doc.data() ?? {};
    final lastDate = data['last_opened_date'] ?? '';
    final totalXp = (data['total_xp'] ?? 0).toDouble();
    final todayXp = (data['today_xp'] ?? 0).toDouble();
    final todayTodoCount = (data['today_todo_count'] ?? 0) as int;

    if (lastDate != today) {
      final newTotalXp = totalXp + todayXp;
      await _db.collection('users').doc(_myCode).update({
        'total_xp': newTotalXp,
        'today_xp': 0,
        'today_todo_count': 0,
        'last_opened_date': today,
      });
      setState(() {
        _totalXp = newTotalXp;
        _todayXp = 0;
        _todayTodoCount = 0;
      });
    } else {
      setState(() {
        _totalXp = totalXp;
        _todayXp = todayXp;
        _todayTodoCount = todayTodoCount;
      });
    }
    final pestStage = data['petStage'] ?? 'egg';
    final petType = data['tetType'] ?? '';
    final petVariant = data['petVariant'] ?? '';
    setState(() {
      _petStage = pestStage;
      _petType = petType;
      _petVariant = petVariant;
    });

    //레벨업 체크
    if (_totalXp >= 200 && _petStage == 'egg') {
      await _assignRandomPet();
    } else if (_totalXp >= 600 && _petStage == 'baby') {
      await _evolvePet();
    }
  }

  void _loadFriends() {
    _db
        .collection('users')
        .doc(_myCode)
        .collection('friends')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _friendCodes = snapshot.docs.map((doc) => doc.id).toList();
      });
    });
  }

  void _loadFriendRequests() {
    _db
        .collection('users')
        .doc(_myCode)
        .collection('friendRequests')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _friendRequestCount = snapshot.docs.length;
      });
    });
  }

  Future<void> _savePomodoroMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pomodoro_mode', mode);
    setState(() {
      _pomodoroMode = mode;
      _isRunning = false;
      _timer?.cancel();
      _totalTimer?.cancel();
      if (mode == '60min') {
        _seconds = 55 * 60;
      } else if (mode == '30min') {
        _seconds = 25 * 60;
      }
    });
  }

  Future<void> _saveTodo(String text, String? editId) async {
    if (text.trim().isEmpty) return;
    print('저장 시도: $text, myCode: $_myCode');
    final todosRef = _db.collection('users').doc(_myCode).collection('todos');
    if (editId != null) {
      await todosRef.doc(editId).update({'text': text.trim()});
    } else {
      await todosRef.add({
        'text': text.trim(),
        'isDone': false,
        'iconSeed': Random().nextBool(),
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

    if (!isDone) {
      final prefs = await SharedPreferences.getInstance();
      final maxCount = _pomodoroMode == 'off' ? 5 : 3;
      final xpPerTodo = _pomodoroMode == 'off' ? 8.0 : 4.0;
      if (_todayTodoCount < maxCount) {
        setState(() {
          _todayTodoCount++;
          _todayXp += xpPerTodo;
        });
        if (_todayTodoCount < maxCount) {
          setState(() {
            _todayTodoCount++;
            _todayXp += xpPerTodo;
          });
          await _db.collection('users').doc(_myCode).update({
            'today_todo_count': _todayTodoCount,
            'today_xp': _todayXp,
          });
        }
      }
    }
  }

  Future<void> _addPomodoroXp() async {
    final xp = _pomodoroMode == '60min' ? 10.5 : 7.0;
    setState(() => _todayXp += xp);
    await _db.collection('users').doc(_myCode).update({
      'today_xp': _todayXp,
    });
  }

  Future<void> _assignRandomPet() async {
    final animals = [
      {'type': 'cat', 'variant': 'white'},
      {'type': 'cat', 'variant': 'black'},
      {'type': 'cat', 'variant': 'orange'},
      {'type': 'cat', 'variant': 'gray'},
      {'type': 'cat', 'variant': 'tuxedo'},
      {'type': 'cat', 'variant': 'calico'},
      {'type': 'cat', 'variant': 'brown'},
      {'type': 'cat', 'variant': 'cream'},
    ];

    final random = Random();
    final picked = animals[random.nextInt(animals.length)];

    await _db.collection('users').doc(_myCode).update({
      'petStage': 'baby',
      'petType': picked['type'],
      'petVariant': picked['variant'],
    });

    setState(() {
      _petStage = 'baby';
      _petType = picked['type']!;
      _petVariant = picked['variant']!;
    });
  }

  Future<void> _evolvePet() async {
    await _db.collection('users').doc(_myCode).update({
      'petStage': 'adult',
    });
    setState(() => _petStage = 'adult');
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
          _addPomodoroXp();
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
      _seconds = _pomodoroMode == '60min' ? 55 * 60 : 25 * 60;
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

  String get _catLevel {
    if (_totalXp < 200) return '🥚 알';
    if (_totalXp < 600) return '🐱 새끼';
    return '😺 성체';
  }

  double get _xpProgress {
    if (_totalXp < 200) return _totalXp / 200;
    if (_totalXp < 600) return (_totalXp - 200) / 400;
    return 1.0;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked == null) return;
    final file = File(picked.path);
    setState(() => _photoFile = file);
    final ref =
        FirebaseStorage.instance.ref().child('photos/$_myCode/today.jpg');
    await ref.putFile(file);
    final url = await ref.getDownloadURL();
    final prefs = await SharedPreferences.getInstance();
    await _db.collection('users').doc(_myCode).update({'photoUrl': url});
    await prefs.setString('photo_url', url);
    setState(() => _photoUrl = url);
  }

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
              onPressed: () => Navigator.pop(context), child: const Text('취소')),
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
      backgroundColor: _currentTheme.background,
      appBar: AppBar(
        backgroundColor: _currentTheme.background,
        elevation: 0,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.people, color: Colors.grey),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FriendManageScreen(myCode: _myCode),
                  ),
                ),
              ),
              if (_friendRequestCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.grey),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsScreen(
                  myCode: _myCode,
                  pomodoroMode: _pomodoroMode,
                  onModeChanged: (mode) => _savePomodoroMode(mode),
                  onIconChanged: (icon) =>
                      setState(() => _completionIcon = icon),
                  onCodeChanged: (newCode) {
                    setState(() => _myCode = newCode);
                    _loadTodos();
                  },
                ),
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
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Container(
                        margin: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _currentTheme.catCard,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_catLevel,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.white70)),
                            Expanded(
                              child: SizedBox.expand(
                                // petStage에 따라 다른 이미지 보여주기
                                child: _petStage == 'egg'
                                    ? (_eggImage == null
                                        ? const SizedBox()
                                        : CustomPaint(
                                            painter: CatSpritePainter(
                                              image: _eggImage!,
                                              frame: _catFrame,
                                              row: 0,
                                              frameSize: 32,
                                              cols: 2,
                                              scale: 1.0,
                                            ),
                                          ))
                                    : const Center(
                                        child: Text('🐱',
                                            style: TextStyle(fontSize: 48)),
                                        // 나중에 실제 이미지로 교체
                                      ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                              child: Column(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: _xpProgress,
                                      backgroundColor: Colors.white30,
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                              Colors.white),
                                      minHeight: 6,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_todayXp.toStringAsFixed(1)}xp 오늘',
                                    style: const TextStyle(
                                        fontSize: 9, color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          Expanded(
                            flex: _pomodoroMode == 'off' ? 5 : 3,
                            child: Container(
                              margin: const EdgeInsets.fromLTRB(0, 6, 6, 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: GestureDetector(
                                onTap: _pickImage,
                                child: _photoUrl != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(_photoUrl!,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity),
                                      )
                                    : _photoFile != null
                                        ? ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: Image.file(_photoFile!,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                height: double.infinity),
                                          )
                                        : const Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.camera_alt,
                                                    size: 28,
                                                    color: Colors.grey),
                                                SizedBox(height: 4),
                                                Text('사진 추가',
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey)),
                                              ],
                                            ),
                                          ),
                              ),
                            ),
                          ),
                          if (_pomodoroMode != 'off')
                            Expanded(
                              flex: 2,
                              child: Container(
                                margin: const EdgeInsets.fromLTRB(0, 3, 6, 6),
                                decoration: BoxDecoration(
                                  color: _currentTheme.timerCard,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(_timeString,
                                        style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold)),
                                    Text('총 $_totalTimeString',
                                        style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.green[800])),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          onPressed: _toggleTimer,
                                          icon: Icon(_isRunning
                                              ? Icons.pause
                                              : Icons.play_arrow),
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
              Expanded(
                flex: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: _currentTheme.todoCard,
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
                          CalendarFormat.week: 'Week'
                        },
                        onPageChanged: (focusedDay) =>
                            setState(() => _selectedDay = focusedDay),
                        headerVisible: false,
                        calendarStyle: CalendarStyle(
                          todayDecoration: const BoxDecoration(
                              color: Colors.teal, shape: BoxShape.circle),
                          selectedDecoration: BoxDecoration(
                              color: Colors.teal[300], shape: BoxShape.circle),
                          cellMargin: const EdgeInsets.all(4),
                          todayTextStyle: const TextStyle(
                              color: Colors.white, fontSize: 11),
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
                            ? GestureDetector(
                                onTap: _showAddTodoDialog,
                                behavior: HitTestBehavior.opaque,
                                child: const Center(
                                  child: Text('터치해서 일정을 추가하세요',
                                      style: TextStyle(
                                          color: Colors.grey, fontSize: 13)),
                                ),
                              )
                            : CustomScrollView(
                                slivers: [
                                  SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                        (context, index) {
                                      //마지막 인덱스는 "+" 추가 행
                                      if (index == _todos.length) {
                                        return GestureDetector(
                                            onTap: _showAddTodoDialog,
                                            behavior: HitTestBehavior
                                                .opaque, //빈 공간도 터치 인식
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6),
                                              child: SizedBox(
                                                width:
                                                    double.infinity, //가로 꽉 채우기
                                                child: Center(
                                                  child: Text(
                                                    '+',
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      color: _currentTheme
                                                          .textSecondary,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ));
                                      }

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
                                              child: const Icon(Icons.close,
                                                  color: Colors.white),
                                            ),
                                          ],
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          child: Row(
                                            children: [
                                              GestureDetector(
                                                onTap: () => _toggleTodo(
                                                    todo.id, todo.isDone),
                                                child: Container(
                                                  width: 22,
                                                  height: 22,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                    color: Colors
                                                        .transparent, //항상 투명
                                                  ),
                                                  child: todo.isDone
                                                      ? Icon(
                                                          _getCompletionIcon(
                                                              iconSeed: todo
                                                                  .iconSeed),
                                                          size: 14,
                                                          color: Colors.white)
                                                      : null,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: GestureDetector(
                                                  onTap: () => _toggleTodo(
                                                      todo.id, todo.isDone),
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
                                                          : _currentTheme
                                                              .textPrimary,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                onPressed: () =>
                                                    _showAddTodoDialog(
                                                        editId: todo.id,
                                                        editText: todo.text),
                                                icon: const Icon(Icons.edit,
                                                    size: 16,
                                                    color: Colors.grey),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }, childCount: _todos.length + 1),
                                  ),
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
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: _currentTheme.friendCard,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('친구 마을',
                            style: TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 6),
                        Expanded(
                          child: _friendCodes.isEmpty
                              ? const Center(
                                  child: Text('친구를 추가해보세요!',
                                      style: TextStyle(
                                          color: Colors.grey, fontSize: 12)),
                                )
                              : ListView(
                                  scrollDirection: Axis.horizontal,
                                  children:
                                      _friendCodes.asMap().entries.map((entry) {
                                    final colors = [
                                      Colors.red[200]!,
                                      Colors.blue[200]!,
                                      Colors.green[200]!,
                                      Colors.orange[200]!,
                                      Colors.purple[200]!,
                                      Colors.pink[200]!,
                                    ];
                                    final color =
                                        colors[entry.key % colors.length];
                                    final code = entry.value;
                                    return GestureDetector(
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => FriendPage(
                                            friend: Friend(
                                                name: code, color: color),
                                          ),
                                        ),
                                      ),
                                      child: Container(
                                        margin:
                                            const EdgeInsets.only(right: 12),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            CustomPaint(
                                              size: const Size(40, 40),
                                              painter:
                                                  HousePainter(color: color),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(code,
                                                style: const TextStyle(
                                                    fontSize: 10)),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
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

class FriendPage extends StatefulWidget {
  final Friend friend;
  const FriendPage({super.key, required this.friend});

  @override
  State<FriendPage> createState() => _FriendPageState();
}

class _FriendPageState extends State<FriendPage> {
  final _db = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _todos = [];
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _loadFriendData();
  }

  void _loadFriendData() {
    _db
        .collection('users')
        .doc(widget.friend.name)
        .collection('todos')
        .orderBy('createdAt')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _todos = snapshot.docs
            .map((doc) => {
                  'text': doc['text'],
                  'isDone': doc['isDone'],
                })
            .toList();
      });
    });

    _db.collection('users').doc(widget.friend.name).get().then((doc) {
      if (doc.exists && doc.data()!.containsKey('photoUrl')) {
        setState(() => _photoUrl = doc['photoUrl']);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F2),
      appBar: AppBar(
        backgroundColor: widget.friend.color,
        title: Text('${widget.friend.name}의 프홈'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Container(
                        margin: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: widget.friend.color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text('🐱', style: TextStyle(fontSize: 48)),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(0, 6, 6, 6),
                        decoration: BoxDecoration(
                          color: Colors.yellow[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _photoUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(_photoUrl!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity),
                              )
                            : const Center(
                                child: Text('사진 없음',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 12)),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                flex: 5,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.teal[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Text('오늘의 할 일',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                      Divider(height: 1, color: Colors.teal[200]),
                      Expanded(
                        child: _todos.isEmpty
                            ? const Center(
                                child: Text('아직 할 일이 없어요',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 13)),
                              )
                            : ListView.builder(
                                itemCount: _todos.length,
                                itemBuilder: (context, index) {
                                  final todo = _todos[index];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                                color: Colors.teal, width: 2),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            color: todo['isDone']
                                                ? Colors.teal
                                                : Colors.transparent,
                                          ),
                                          child: todo['isDone']
                                              ? const Icon(Icons.check,
                                                  size: 14, color: Colors.white)
                                              : null,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            todo['text'],
                                            style: TextStyle(
                                              fontSize: 13,
                                              decoration: todo['isDone']
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                              color: todo['isDone']
                                                  ? Colors.grey
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
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

class HousePainter extends CustomPainter {
  final Color color;
  HousePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.1, size.height * 0.45, size.width * 0.8,
          size.height * 0.55),
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
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
    final frameX = frame == 0 ? 0.0 : 32.0;

    final srcRect = Rect.fromLTWH(frameX, 0, 32, 32);

    final padding = 20.0;
    final displaySize =
        (size.width < size.height ? size.width : size.height) - padding * 2;
    final offsetX = (size.width - displaySize) / 2;
    final offsetY = (size.height - displaySize) / 2;

    final dstRect = Rect.fromLTWH(offsetX, offsetY, displaySize, displaySize);

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
  final String pomodoroMode;
  final Function(String) onModeChanged;
  final Function(String) onIconChanged;
  final Function(String) onCodeChanged;

  const SettingsScreen({
    super.key,
    required this.myCode,
    required this.pomodoroMode,
    required this.onModeChanged,
    required this.onIconChanged,
    required this.onCodeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  User? _user = FirebaseAuth.instance.currentUser;
  bool _kakaoLoggedIn = false;
  late String _pomodoroMode;

  @override
  void initState() {
    super.initState();
    _pomodoroMode = widget.pomodoroMode;
  }

  Future<void> _saveCompletionIcon(String icon) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('completion_icon', icon);
    widget.onIconChanged(icon);
    if (context.mounted) Navigator.pop(context);
  }

  void _showIconPickerDialog() {
    final icons = [
      {'key': 'check', 'icon': Icons.check, 'label': '체크'},
      {'key': 'kid_star', 'icon': Icons.star, 'label': 'Kid Star'},
      {'key': 'heart_check', 'icon': Icons.favorite, 'label': 'Heart Check'},
      {'key': 'close_small', 'icon': Icons.close, 'label': 'Close Small'},
      {'key': 'pets', 'icon': Icons.pets, 'label': 'Pets'},
      {'key': 'mood', 'icon': Icons.mood, 'label': 'Mood'},
      {
        'key': 'cruelty_free',
        'icon': Icons.cruelty_free,
        'label': 'Cruelty Free'
      },
      {'key': 'cookie', 'icon': Icons.cookie, 'label': 'Cookie'},
      {'key': 'circle', 'icon': Icons.circle, 'label': 'Circle'},
      {'key': 'filter_drama', 'icon': Icons.filter_drama, 'label': 'Cloud(랜덤)'},
      {'key': 'cloud', 'icon': Icons.cloud, 'label': 'Cloud'},
      {'key': 'healing', 'icon': Icons.healing, 'label': 'Healing'},
      {'key': 'music_note', 'icon': Icons.music_note, 'label': 'Music Note'},
      {
        'key': 'lunch_dining',
        'icon': Icons.lunch_dining,
        'label': 'Lunch Dining'
      },
      {'key': 'casino', 'icon': Icons.casino, 'label': 'Casino'},
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('완료 아이콘 선택'),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 1,
            ),
            itemCount: icons.length,
            itemBuilder: (context, index) {
              final item = icons[index];
              return GestureDetector(
                onTap: () => _saveCompletionIcon(item['key'] as String),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item['icon'] as IconData,
                        color: Colors.deepPurple, size: 28),
                    const SizedBox(height: 4),
                    Text(item['label'] as String,
                        style: const TextStyle(fontSize: 8),
                        textAlign: TextAlign.center),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  void _showAddFriendDialog() {
    final controller = TextEditingController();
    String? errorMessage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('친구 추가하기'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(hintText: '친구 코드를 입력하세요'),
              ),
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                final code = controller.text.trim().toUpperCase();
                if (code.isEmpty) return;

                if (code == widget.myCode) {
                  setDialogState(() => errorMessage = '자기 자신은 추가할 수 없어요!');
                  return;
                }

                final db = FirebaseFirestore.instance;

                final friendDoc = await db
                    .collection('users')
                    .doc(widget.myCode)
                    .collection('friends')
                    .doc(code)
                    .get();
                if (friendDoc.exists) {
                  setDialogState(() => errorMessage = '이미 친구예요!');
                  return;
                }

                final userDoc = await db.collection('users').doc(code).get();
                if (!userDoc.exists) {
                  setDialogState(() => errorMessage = '존재하지 않는 코드예요');
                  return;
                }

                await db
                    .collection('users')
                    .doc(code)
                    .collection('friendRequests')
                    .doc(widget.myCode)
                    .set({'sentAt': FieldValue.serverTimestamp()});

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('친구 요청을 보냈어요!')),
                  );
                }
              },
              child: const Text('확인'),
            ),
          ],
        ),
      ),
    );
  }

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

    final uid = result.user!.uid;
    final db = FirebaseFirestore.instance;
    final prefs = await SharedPreferences.getInstance();

    // 이 계정에 연결된 코드가 이미 있는지 확인
    final accountDoc = await db.collection('accounts').doc(uid).get();

    if (accountDoc.exists) {
      // 이미 연결된 코드가 있음 → 현재 기기의 임시 코드 삭제
      final linkedCode = accountDoc['myCode'];
      final currentCode = widget.myCode;

      if (currentCode != linkedCode) {
        widget.onCodeChanged(linkedCode);
        // 임시 코드 Firestore 데이터 삭제
        await db.collection('users').doc(currentCode).delete();
        // 기기 코드를 계정 연결 코드로 교체
        await prefs.setString('my_code', linkedCode);
      }
    } else {
      // 처음 로그인 → 현재 코드를 계정에 연결
      await db.collection('accounts').doc(uid).set({
        'myCode': widget.myCode,
        'linkedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _signInWithKakao() async {
    try {
      print('카카오 로그인 시작');
      if (await kakao.isKakaoTalkInstalled()) {
        await kakao.UserApi.instance.loginWithKakaoTalk();
      } else {
        await kakao.UserApi.instance.loginWithKakaoAccount();
      }
      print('카카오 인증 완료');

      final user = await kakao.UserApi.instance.me();
      final kakaoId = user.id.toString();
      print('카카오 유저 ID: $kakaoId');

      final db = FirebaseFirestore.instance;
      final prefs = await SharedPreferences.getInstance();

      final accountDoc =
          await db.collection('accounts').doc('kakao_$kakaoId').get();
      print('accountDoc exists: ${accountDoc.exists}');

      if (accountDoc.exists) {
        final linkedCode = accountDoc['myCode'];
        final currentCode = widget.myCode;
        if (currentCode != linkedCode) {
          widget.onCodeChanged(linkedCode);
          await db.collection('users').doc(currentCode).delete();
          await prefs.setString('my_code', linkedCode);
        }
      } else {
        await db.collection('accounts').doc('kakao_$kakaoId').set({
          'myCode': widget.myCode,
          'linkedAt': FieldValue.serverTimestamp(),
        });
        print('카카오 계정 저장 완료');
      }

      setState(() => _kakaoLoggedIn = true);
      print('카카오 로그인 완료');
    } catch (e) {
      print('카카오 로그인 실패: $e');
    }
  }

  Future<void> _savePomodoroMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pomodoro_mode', mode);
    setState(() => _pomodoroMode = mode);
    widget.onModeChanged(mode);
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
    try {
      await kakao.UserApi.instance.logout();
    } catch (e) {
      //카카오 로그아웃 실패해도 무시
    }
    setState(() {
      _user = null;
      _kakaoLoggedIn = false;
    });
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
            child:
                Text('계정', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          (_user == null && !_kakaoLoggedIn)
              ? Column(
                  children: [
                    ListTile(
                      leading:
                          const Icon(Icons.login, color: Colors.deepPurple),
                      title: const Text('Google로 로그인'),
                      onTap: _signInWithGoogle,
                    ),
                    ListTile(
                      leading: Image.asset('assets/images/kakao_logo.png',
                          width: 24),
                      title: const Text('카카오로 로그인'),
                      onTap: _signInWithKakao,
                    ),
                  ],
                )
              : ListTile(
                  leading: const CircleAvatar(
                      radius: 16, child: Icon(Icons.person, size: 16)),
                  title: Text(_user!.displayName ?? '카카오 사용자'),
                  subtitle: Text(_user!.email ?? ''),
                  trailing: TextButton(
                    onPressed: _signOut,
                    child:
                        const Text('로그아웃', style: TextStyle(color: Colors.red)),
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
                    Text('내 코드',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(widget.myCode,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _showAddFriendDialog(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.deepPurple, width: 2),
                    ),
                    child: const Icon(Icons.add,
                        color: Colors.deepPurple, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child:
                Text('타이머', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('포모도로 설정', style: TextStyle(fontSize: 15)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Radio<String>(
                      value: 'off',
                      groupValue: _pomodoroMode,
                      onChanged: (v) => _savePomodoroMode(v!),
                      activeColor: Colors.deepPurple,
                    ),
                    const Text('OFF'),
                  ],
                ),
                Row(
                  children: [
                    Radio<String>(
                      value: '30min',
                      groupValue: _pomodoroMode,
                      onChanged: (v) => _savePomodoroMode(v!),
                      activeColor: Colors.deepPurple,
                    ),
                    const Text('30Min: Study 25Min + Rest 5Min'),
                  ],
                ),
                Row(
                  children: [
                    Radio<String>(
                      value: '60min',
                      groupValue: _pomodoroMode,
                      onChanged: (v) => _savePomodoroMode(v!),
                      activeColor: Colors.deepPurple,
                    ),
                    const Text('1Hour: Study 55Min + Rest 5Min'),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child:
                Text('꾸미기', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
            subtitle: const Text('체크 / 하트 / 별 외 다양한 아이콘'),
            onTap: () => _showIconPickerDialog(),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip, color: Colors.deepPurple),
            title: const Text('개인정보처리방침'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class FriendManageScreen extends StatefulWidget {
  final String myCode;
  const FriendManageScreen({super.key, required this.myCode});

  @override
  State<FriendManageScreen> createState() => _FriendManageScreenState();
}

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse('https://soriyeon.github.io/privacy-policy'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F6F2),
        elevation: 0,
        title: const Text('개인정보처리방침', style: TextStyle(color: Colors.black87)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}

class _FriendManageScreenState extends State<FriendManageScreen> {
  final _db = FirebaseFirestore.instance;
  List<String> _friends = [];
  List<String> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _loadRequests();
  }

  void _loadFriends() {
    _db
        .collection('users')
        .doc(widget.myCode)
        .collection('friends')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _friends = snapshot.docs.map((doc) => doc.id).toList();
      });
    });
  }

  void _loadRequests() {
    _db
        .collection('users')
        .doc(widget.myCode)
        .collection('friendRequests')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _requests = snapshot.docs.map((doc) => doc.id).toList();
      });
    });
  }

  Future<void> _acceptRequest(String code) async {
    await _db
        .collection('users')
        .doc(widget.myCode)
        .collection('friends')
        .doc(code)
        .set({'addedAt': FieldValue.serverTimestamp()});
    await _db
        .collection('users')
        .doc(code)
        .collection('friends')
        .doc(widget.myCode)
        .set({'addedAt': FieldValue.serverTimestamp()});
    await _db
        .collection('users')
        .doc(widget.myCode)
        .collection('friendRequests')
        .doc(code)
        .delete();
  }

  Future<void> _rejectRequest(String code) async {
    await _db
        .collection('users')
        .doc(widget.myCode)
        .collection('friendRequests')
        .doc(code)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F6F2),
        elevation: 0,
        title: const Text('친구', style: TextStyle(color: Colors.black87)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        children: [
          if (_requests.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('받은 친구 요청',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ),
            ..._requests.map((code) => ListTile(
                  leading:
                      const Icon(Icons.person_add, color: Colors.deepPurple),
                  title: Text(code),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => _acceptRequest(code),
                        child: const Text('수락',
                            style: TextStyle(color: Colors.deepPurple)),
                      ),
                      TextButton(
                        onPressed: () => _rejectRequest(code),
                        child: const Text('거절',
                            style: TextStyle(color: Colors.grey)),
                      ),
                    ],
                  ),
                )),
            const Divider(),
          ],
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('친구 목록',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          if (_friends.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('아직 친구가 없어요',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
            )
          else
            ..._friends.map((code) {
              final colors = [
                Colors.red[200]!,
                Colors.blue[200]!,
                Colors.green[200]!,
                Colors.orange[200]!,
                Colors.purple[200]!,
                Colors.pink[200]!,
              ];
              final color = colors[_friends.indexOf(code) % colors.length];
              return ListTile(
                leading: const Icon(Icons.person, color: Colors.deepPurple),
                title: Text(code),
                trailing: IconButton(
                  icon: const Icon(Icons.home, color: Colors.deepPurple),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FriendPage(
                        friend: Friend(name: code, color: color),
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
