// main.dart
import 'package:drug/presentation/screens/otc_chatbot_screen.dart';
import 'package:flutter/material.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:drug/presentation/widgets/common_bottom_nav.dart';
import 'package:drug/presentation/screens/drugManagementScreen.dart';
import 'package:drug/presentation/screens/imageSearch.dart';
import 'package:drug/initialize_drug_data.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:convert'; // jsonDecode를 위해 추가
import 'package:drug/presentation/screens/alarm_screen.dart';

/// 전역 FlutterLocalNotificationsPlugin 인스턴스
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print("Main: WidgetsFlutterBinding ensured.");

  await initializeDrugDataIfNeeded();
  print("Main: Drug data initialized if needed.");

  try {
    print("Main: Initializing AndroidAlarmManager...");
    await AndroidAlarmManager.initialize();
    print("✅ Main: AndroidAlarmManager initialized successfully.");
  } catch (e) {
    print("❌ Main: FAILED to initialize AndroidAlarmManager: $e");
  }

  // 3) flutter_local_notifications 초기 설정
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit, iOS: null);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  runApp(const MyApp());
}

// =================================================================
// 1. MyApp을 StatefulWidget으로 변경하여 UI 모드 상태 관리
// =================================================================
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // 시니어 모드 여부를 저장하는 상태 변수
  bool _isSeniorMode = false;

  // UI 모드를 변경하는 함수
  void _toggleUIMode() {
    setState(() {
      _isSeniorMode = !_isSeniorMode;
    });
  }

  // 일반 모드 테마 정의
  ThemeData _buildNormalTheme() {
    return ThemeData(
      fontFamily: "BMHANNA_11yrs_ttf",
      primarySwatch: Colors.teal,
      scaffoldBackgroundColor: Colors.grey[50],
      textTheme: TextTheme(
        headlineSmall: TextStyle(
          fontSize: 24.0,
          fontWeight: FontWeight.bold,
          color: Colors.grey[800],
        ),
        titleLarge: TextStyle(
          fontSize: 20.0,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
        ),
        bodyMedium: TextStyle(fontSize: 16.0, color: Colors.grey[600]),
      ),
    );
  }

  // 시니어 모드 테마 정의 (더 큰 폰트)
  ThemeData _buildSeniorTheme() {
    return ThemeData(
      fontFamily: "BMHANNA_11yrs_ttf",
      primarySwatch: Colors.teal,
      scaffoldBackgroundColor: Colors.grey[50],
      textTheme: TextTheme(
        headlineSmall: TextStyle(
          fontSize: 30.0, // 크기 증가
          fontWeight: FontWeight.bold,
          color: Colors.grey[900], // 대비 증가
        ),
        titleLarge: TextStyle(
          fontSize: 26.0, // 크기 증가
          fontWeight: FontWeight.w600,
          color: Colors.grey[800], // 대비 증가
        ),
        bodyMedium: TextStyle(fontSize: 22.0, color: Colors.grey[700]), // 크기 증가
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      // _isSeniorMode 값에 따라 동적으로 테마 적용
      theme: _isSeniorMode ? _buildSeniorTheme() : _buildNormalTheme(),
      initialRoute: '/',
      routes: {
        // 각 화면으로 상태와 토글 함수를 전달
        '/':
            (context) => HomeScreen(
              isSeniorMode: _isSeniorMode,
              onToggleMode: _toggleUIMode,
            ),
        // TODO: 다른 화면들도 시니어 모드를 지원하려면 아래와 같이 수정 필요
        '/management':
            (context) => DrugManagementScreen(isSeniorMode: _isSeniorMode),
        '/image_search':
            (context) => ImageSearchScreen(isSeniorMode: _isSeniorMode),
        '/otc_chatbot':
            (context) => OtcChatbotScreen(isSeniorMode: _isSeniorMode),
      },
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
    );
  }
}

class HomeScreen extends StatelessWidget {
  final bool isSeniorMode;
  final VoidCallback onToggleMode;

  const HomeScreen({
    super.key,
    required this.isSeniorMode,
    required this.onToggleMode,
  });

  // 각 기능 항목을 위한 헬퍼 위젯 (이 부분은 이전과 동일합니다)
  Widget _buildFeatureCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    // 시니어 모드에 따른 UI 값 조정
    final double cardPadding = isSeniorMode ? 28.0 : 20.0;
    final double iconSize = isSeniorMode ? 50.0 : 40.0;
    final double titleFontSize = isSeniorMode ? 26.0 : 20.0;
    final double subtitleFontSize = isSeniorMode ? 18.0 : 14.0;
    final double cardVerticalMargin = isSeniorMode ? 15.0 : 10.0;

    return Card(
      elevation: 3.0,
      margin: EdgeInsets.symmetric(
        vertical: cardVerticalMargin,
        horizontal: 16.0,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
      color: backgroundColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15.0),
        child: Padding(
          padding: EdgeInsets.all(cardPadding),
          child: Row(
            children: [
              Icon(icon, size: iconSize, color: iconColor),
              const SizedBox(width: 20.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 5.0),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: subtitleFontSize,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withOpacity(0.7),
                size: isSeniorMode ? 22 : 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 시니어 모드에 따른 UI 값 조정
    final double titleFontSize = isSeniorMode ? 52 : 44;
    final double subtitleFontSize = isSeniorMode ? 22 : 18;
    final double titleIconSize = isSeniorMode ? 90 : 80;

    return Scaffold(
      // =================================================================
      // AppBar 수정: IconButton을 직관적인 Switch 위젯으로 교체
      // =================================================================
      appBar: AppBar(
        // 1. title을 앱 이름으로 고정
        title: Text(
          '',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: isSeniorMode ? 24 : 20,
          ),
        ),
        backgroundColor: Colors.teal.shade400,
        elevation: 2,
        actions: [
          // 2. '시니어 모드' 텍스트와 스위치를 함께 배치
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Row(
              children: [
                Text(
                  '시니어 모드 ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSeniorMode ? 18 : 14, // 모드에 따라 폰트 크기 조절
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                // 3. Switch 위젯 사용
                Transform.scale(
                  // 스위치 크기를 약간 키워 터치가 쉽도록 함
                  scale: isSeniorMode ? 1.2 : 1.0,
                  child: Switch(
                    value: isSeniorMode, // 스위치의 On/Off 상태를 isSeniorMode와 연결
                    onChanged: (value) {
                      onToggleMode(); // 스위치를 누르면 모드 전환 함수 호출
                    },
                    // 스위치 색상 커스텀
                    activeColor: Colors.white, // On 상태일 때 원의 색상
                    activeTrackColor:
                        Colors.deepPurple.shade200, // On 상태일 때 배경 트랙 색상
                    inactiveThumbColor: Colors.grey.shade300, // Off 상태일 때 원의 색상
                    inactiveTrackColor:
                        Colors.grey.shade500, // Off 상태일 때 배경 트랙 색상
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Container(
        // 이 아래 Body 부분은 이전과 동일합니다
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade100, Colors.cyan.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 30.0,
                  horizontal: 20.0,
                ),
                child: Column(
                  children: [
                    Icon(
                      Symbols.pill,
                      size: titleIconSize,
                      color: Colors.teal.shade700,
                      weight: 500,
                    ),
                    const SizedBox(height: 15),
                    Text(
                      '이 약 뭐약?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                        color: const Color.fromARGB(255, 1, 105, 88),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '나에게 맞는 약을 찾아보세요!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: subtitleFontSize,
                        color: Colors.teal.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              _buildFeatureCard(
                context: context,
                icon: Icons.image_search_outlined,
                title: '이미지 검색',
                subtitle: '사진으로 간편하게 약 정보 찾기',
                iconColor: Colors.white,
                backgroundColor: Colors.purple.shade400,
                onTap: () => Navigator.pushNamed(context, '/image_search'),
              ),
              const SizedBox(height: 20),
              _buildFeatureCard(
                context: context,
                icon: Icons.chat_bubble_outline_rounded,
                title: 'AI 약사',
                subtitle: '증상에 맞는 일반의약품 추천받기',
                iconColor: Colors.white,
                backgroundColor: Colors.cyan.shade600,
                onTap: () => Navigator.pushNamed(context, '/otc_chatbot'),
              ),
              const SizedBox(height: 20),
              _buildFeatureCard(
                context: context,
                icon: Icons.inventory_2_outlined,
                title: '복약 관리',
                subtitle: '나의 복용 일정 확인 및 관리',
                iconColor: Colors.white,
                backgroundColor: const Color.fromARGB(255, 255, 177, 81),
                onTap: () => Navigator.pushNamed(context, '/management'),
              ),
              const SizedBox(height: 15),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CommonBottomNavBar(
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) {
            Navigator.pushNamed(context, '/management');
          } else if (index == 2) {
            print("Settings tapped");
          }
        },
      ),
    );
  }
}
