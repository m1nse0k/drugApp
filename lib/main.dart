import 'package:drug/presentation/screens/otc_chatbot_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:drug/presentation/widgets/common_bottom_nav.dart';
import 'package:drug/presentation/screens/drugManagementScreen.dart';
import 'package:drug/presentation/screens/imageSearch.dart';
import 'package:drug/initialize_drug_data.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// 전역 FlutterLocalNotificationsPlugin 인스턴스
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print("Main: WidgetsFlutterBinding ensured."); // 로그 추가

  await initializeDrugDataIfNeeded();
  print("Main: Drug data initialized if needed.");

  try {
    print("Main: Initializing AndroidAlarmManager...");
    await AndroidAlarmManager.initialize();
    print("✅ Main: AndroidAlarmManager initialized successfully."); // 성공 로그
  } catch (e) {
    print("❌ Main: FAILED to initialize AndroidAlarmManager: $e"); // 실패 로그
  }

  // 3) flutter_local_notifications 초기 설정
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit, iOS: null);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/management': (context) => const DrugManagementScreen(),
        '/image_search': (context) => const ImageSearchScreen(),
        '/otc_chatbot': (context) => const OtcChatbotScreen(),
      },
      theme: ThemeData(
        fontFamily: "BMHANNA_11yrs_ttf",
        primarySwatch: Colors.teal, // <<<=== 앱의 주요 색상 테마 설정 (예시)
        scaffoldBackgroundColor: Colors.grey[50], // <<<=== 기본 Scaffold 배경색 설정
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
      ),
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
  const HomeScreen({super.key});

  // 각 기능 항목을 위한 헬퍼 위젯
  Widget _buildFeatureCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3.0, // 카드 그림자
      margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ), // 둥근 모서리
      color: backgroundColor,
      child: InkWell(
        // 탭 효과
        onTap: onTap,
        borderRadius: BorderRadius.circular(15.0),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(icon, size: 40.0, color: iconColor),
              const SizedBox(width: 20.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white, // 아이콘/배경색과 대비되는 색상
                      ),
                    ),
                    const SizedBox(height: 5.0),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14.0,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withOpacity(0.7),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar( // 필요 시 AppBar 추가
      //   title: Text('이 약 뭐약?', style: TextStyle(fontWeight: FontWeight.bold)),
      //   backgroundColor: Colors.transparent,
      //   elevation: 0,
      //   centerTitle: true,
      // ),
      body: Container(
        // 전체 배경 그라데이션
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.teal.shade100,
              Colors.cyan.shade100,
            ], // <<<=== 부드러운 그라데이션
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          // 상태바 영역 침범 방지
          child: ListView(
            // 스크롤 가능한 콘텐츠
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            children: [
              // 상단 로고 및 앱 이름
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 30.0,
                  horizontal: 20.0,
                ),
                child: Column(
                  children: [
                    Icon(
                      Symbols.pill, // Material Symbols 아이콘 사용
                      size: 80,
                      color: Colors.teal.shade700, // 아이콘 색상
                      // fill: 0, // 아이콘 채우기 정도 (0~1)
                      weight: 500, // 아이콘 선 굵기
                    ),
                    const SizedBox(height: 15),
                    Text(
                      '이 약 뭐약?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.bold,
                        color: const Color.fromARGB(255, 1, 105, 88), // 텍스트 색상
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '나에게 맞는 약을 찾아보세요!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.teal.shade700,
                      ),
                    ),
                  ],
                ),
              ),

              // 기능 카드 목록
              _buildFeatureCard(
                context: context,
                icon: Icons.image_search_outlined,
                title: '이미지 검색',
                subtitle: '사진으로 간편하게 약 정보 찾기',
                iconColor: Colors.white,
                backgroundColor: Colors.purple.shade400, // 카드 배경색
                onTap: () => Navigator.pushNamed(context, '/image_search'),
              ),
              SizedBox(height: 20),
              _buildFeatureCard(
                context: context,
                icon: Icons.chat_bubble_outline_rounded,
                title: 'AI 약사',
                subtitle: '증상에 맞는 일반의약품 추천받기',
                iconColor: Colors.white,
                backgroundColor: Colors.cyan.shade600, // 카드 배경색
                onTap: () => Navigator.pushNamed(context, '/otc_chatbot'),
              ),
              SizedBox(height: 20),
              _buildFeatureCard(
                context: context,
                icon: Icons.inventory_2_outlined,
                title: '복약 관리',
                subtitle: '나의 복용 일정 확인 및 관리',
                iconColor: Colors.white,
                backgroundColor: const Color.fromARGB(
                  255,
                  255,
                  177,
                  81,
                ), // 카드 배경색
                onTap: () => Navigator.pushNamed(context, '/management'),
              ),
              const SizedBox(height: 15), // 하단 여백
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
            // Navigator.pushNamed(context, '/settings'); // 설정 화면 라우트 정의 후 사용
            print("Settings tapped");
          }
        },
      ),
    );
  }
}
