// imageSearch.dart
import 'dart:async';
import 'dart:convert'; // for jsonDecode
import 'dart:io'; // for File
import 'package:drug/presentation/screens/DrugDetailScreen.dart';
import 'package:flutter/material.dart';
import 'package:drug/presentation/widgets/common_bottom_nav.dart'; // 위젯 경로 확인
import 'package:drug/data/database/drug_database.dart'; // <<<=== DB 클래스 임포트
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
// import 'package:http_parser/http_parser.dart'; // 필요 시 MediaType 지정 위해

class ImageSearchScreen extends StatefulWidget {
  const ImageSearchScreen({super.key});

  @override
  State<ImageSearchScreen> createState() => _ImageSearchScreenState();
}

class _ImageSearchScreenState extends State<ImageSearchScreen> {
  File? _selectedImage; // 선택/촬영된 이미지
  bool _isLoading = false; // API 요청 중 로딩 상태
  String? _errorMessage; // 오류 메시지
  // API 결과는 이제 상세 화면으로 전달하므로 여기서 저장할 필요 없음
  // dynamic _identificationResult;

  final ImagePicker _picker = ImagePicker();
  final dbInstance = DrugDatabase.instance; // DB 인스턴스

  // 카메라에서 이미지 가져오기 (기존 코드 유지)
  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        // imageQuality: 100, // 품질을 70%로 낮춤 (0-100)
        // maxWidth: 1080, // 최대 너비를 1080px로 제한
        // maxHeight: 1080, // 최대 높이를 1080px로 제한
      );
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _errorMessage = null; // 이전 오류/결과 초기화
        });
        print("Image picked from camera: ${pickedFile.path}");
      } else {
        print("Image picking cancelled (camera).");
      }
    } catch (e) {
      print("Error picking image from camera: $e");
      if (mounted) setState(() => _errorMessage = "카메라 접근 중 오류 발생: $e");
    }
  }

  // 갤러리에서 이미지 가져오기 (기존 코드 유지)
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        // imageQuality: 100, // 품질을 70%로 낮춤
        // maxWidth: 1080, // 최대 너비 제한
        // maxHeight: 1080, // 최대 높이 제한
      );
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _errorMessage = null; // 이전 오류/결과 초기화
        });
        print("Image picked from gallery: ${pickedFile.path}");
      } else {
        print("Image picking cancelled (gallery).");
      }
    } catch (e) {
      print("Error picking image from gallery: $e");
      if (mounted) setState(() => _errorMessage = "갤러리 접근 중 오류 발생: $e");
    }
  }

  // 이미지 업로드 및 식별 요청 (수정됨)
  Future<void> _uploadAndIdentifyImage() async {
    if (_selectedImage == null) {
      if (mounted) setState(() => _errorMessage = "먼저 이미지를 선택하거나 촬영해주세요.");
      return;
    }
    if (_isLoading) return; // 중복 요청 방지

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final String apiUrl = "http://52.78.59.115:8000/predict";
    final String imageFieldName = "file";

    try {
      final fileSize = await _selectedImage!.length(); // 파일 크기 (bytes)
      print("Selected image size: ${fileSize / 1024 / 1024} MB"); // MB 단위로 출력

      print("Preparing to upload image: ${_selectedImage!.path}");
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.files.add(
        await http.MultipartFile.fromPath(
          imageFieldName,
          _selectedImage!.path,
          // contentType: MediaType('image', 'jpeg'), // 필요 시 명시
        ),
      );

      print("Sending request to $apiUrl...");
      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
      ); // 타임아웃 설정 (예: 30초)
      print("Response status code: ${streamedResponse.statusCode}");

      final responseBody = await streamedResponse.stream.bytesToString();
      print("API Response body: $responseBody");

      if (streamedResponse.statusCode == 200) {
        final result = jsonDecode(responseBody);

        // --- 결과 처리 ---
        if (result['predictions'] != null &&
            result['predictions'] is List &&
            (result['predictions'] as List).isNotEmpty) {
          // 첫 번째 예측 결과 사용 (가장 확률 높은 결과로 가정)
          final prediction = result['predictions'][0];
          final String? labelName =
              prediction['label_name']?.toString(); // itemSeq
          final double? score =
              (prediction['score'] as num?)?.toDouble(); // score (숫자 타입으로 변환)

          print("Prediction - label_name (itemSeq): $labelName, score: $score");

          if (labelName != null && score != null) {
            // DB에서 약 정보 조회
            print("Looking up drug in DB with itemSeq: $labelName");
            final drug = await dbInstance.getDrugByItemSeq(labelName);

            if (drug != null) {
              // 약 정보 찾음 -> 상세 화면으로 이동
              print("Drug found: ${drug.itemName}. Navigating to details...");
              if (!mounted) return; // 네비게이션 전 마운트 상태 확인
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DrugDetailScreen(drug: drug, score: score),
                ),
              );
              // 성공 시 선택된 이미지 초기화 (선택 사항)
              // setState(() => _selectedImage = null);
            } else {
              // DB에 해당 약 정보 없음
              print("Drug with itemSeq $labelName not found in local DB.");
              if (mounted) {
                setState(
                  () => _errorMessage = "식별된 약 정보(ID: $labelName)를 찾을 수 없습니다.",
                );
              }
            }
          } else {
            print("Invalid prediction format (label_name or score missing).");
            if (mounted)
              setState(() => _errorMessage = "서버 응답에서 유효한 약 정보를 얻지 못했습니다.");
          }
        } else {
          // 예측 결과 없음
          print("No predictions found in API response.");
          if (mounted) setState(() => _errorMessage = "이미지에서 약을 식별하지 못했습니다.");
        }
        // --- 결과 처리 끝 ---
      } else {
        // API 오류
        print(
          "API Error response: ${streamedResponse.statusCode} - $responseBody",
        );
        if (mounted) {
          setState(
            () =>
                _errorMessage =
                    "이미지 식별 실패 (서버 오류 ${streamedResponse.statusCode})",
          );
        }
      }
    } catch (e) {
      // 네트워크 오류, 타임아웃, JSON 파싱 오류 등
      print("Error during image identification process: $e");
      if (mounted) {
        if (e is TimeoutException) {
          setState(() => _errorMessage = "서버 응답 시간 초과. 다시 시도해주세요.");
        } else {
          setState(() => _errorMessage = "오류 발생: $e");
        }
      }
    } finally {
      // 로딩 종료
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 앱 테마 색상 가져오기
    final Color primaryColor =
        Theme.of(context).primaryColor; // main.dart에서 설정한 teal
    final Color accentColor1 = Colors.cyan.shade600; // HomeScreen 카드 색상 참고
    final Color accentColor2 = Colors.orange.shade600; // HomeScreen 카드 색상 참고

    return Scaffold(
      // --- AppBar 대신 상단 영역 직접 구성 ---
      // backgroundColor: Colors.grey[50], // 앱 전체 배경색과 통일 (main.dart에서 설정)
      body: Container(
        // <<<=== HomeScreen과 유사한 그라데이션 배경 적용
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              primaryColor.withOpacity(0.7),
              Colors.cyan.shade100,
            ], // Teal 계열 그라데이션
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // --- 상단 뒤로가기 및 제목 영역 ---
              Padding(
                padding: const EdgeInsets.only(
                  top: 10.0,
                  left: 8.0,
                  right: 16.0,
                  bottom: 5.0,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 26,
                      ),
                      onPressed: () => Navigator.pop(context),
                      tooltip: '뒤로가기',
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '이미지로 약 검색',
                      style: TextStyle(
                        fontSize: 22, // 폰트 크기 조절
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 15.0), // <<<=== 상단 여백 추가
                  decoration: BoxDecoration(
                    color:
                        Theme.of(
                          context,
                        ).scaffoldBackgroundColor, // <<<=== main.dart의 scaffoldBackgroundColor 사용
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(30),
                    ), // <<<=== HomeScreen 카드와 유사한 둥글기
                    boxShadow: [
                      // <<<=== 부드러운 그림자 추가
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    25,
                    20,
                    20,
                  ), // 내부 패딩 조절
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start, // 위에서부터 시작
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // --- 이미지 미리보기 영역 ---
                        Container(
                          width:
                              MediaQuery.of(context).size.width *
                              0.8, // 너비 살짝 줄임
                          height:
                              MediaQuery.of(context).size.width *
                              0.8, // 높이 비율 유지
                          decoration: BoxDecoration(
                            color: Colors.white, // 내부 배경 흰색
                            borderRadius: BorderRadius.circular(15), // 둥근 모서리
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1.5,
                            ), // 테두리
                            boxShadow: [
                              // 내부 그림자 효과 (선택 사항)
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                spreadRadius: 1,
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              _selectedImage != null
                                  ? ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      14.0,
                                    ), // 내부 이미지도 둥글게
                                    child: Image.file(
                                      _selectedImage!,
                                      fit: BoxFit.contain,
                                    ),
                                  )
                                  : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.photo_camera_back_outlined,
                                        size: 70,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        "카메라 또는 앨범에서 이미지를 선택하세요.",
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                              if (_isLoading)
                                Container(
                                  // 로딩 오버레이
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 오류 메시지 표시
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w500,
                                fontSize: 14.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        // 안내 문구
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12.0,
                            horizontal: 10.0,
                          ),
                          child: Text(
                            '선명한 알약 사진은 더 정확한 결과를 제공합니다.\n(특히 각인된 글자가 잘 보이도록 촬영해주세요.)',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[700],
                              height: 2,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // --- 버튼 영역 스타일 통일 ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStyledChoiceButton(
                              icon: Icons.camera_alt_rounded,
                              label: '촬영하기',
                              color: accentColor1, // HomeScreen 카드 색상
                              onPressed:
                                  _isLoading ? null : _pickImageFromCamera,
                            ),
                            _buildStyledChoiceButton(
                              icon: Icons.photo_library_rounded,
                              label: '앨범 선택',
                              color: accentColor2, // HomeScreen 카드 색상
                              onPressed:
                                  _isLoading ? null : _pickImageFromGallery,
                            ),
                          ],
                        ),
                        const SizedBox(height: 25),

                        // 식별하기 버튼
                        ElevatedButton.icon(
                          onPressed:
                              (_selectedImage != null && !_isLoading)
                                  ? _uploadAndIdentifyImage
                                  : null,
                          icon: const Icon(
                            Icons.manage_search_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          label: const Text(
                            '선택한 이미지로 약 식별',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor, // 앱의 주요 색상 사용
                            minimumSize: const Size(double.infinity, 55),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 3,
                            disabledBackgroundColor: Colors.grey[300],
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

      // 버튼 UI를 위한 Helper 위젯
      bottomNavigationBar: CommonBottomNavBar(
        currentIndex: 0, // 네비게이션 로직에 따라 현재 인덱스 설정
        onTap: (index) {
          if (index == 0)
            Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
          else if (index == 1)
            Navigator.pushNamed(context, '/management');
          // else if (index == 2) Navigator.pushNamed(context, '/settings');
        },
      ),
    );
  }

  // 스타일 적용된 버튼 UI를 위한 Helper 위젯
  Widget _buildStyledChoiceButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 4.0,
        vertical: 10,
      ), // 각 버튼 좌우에 약간의 패딩
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 24),
        label: Text(label, style: TextStyle(color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          // minimumSize는 이제 Padding을 고려하여 조절해야 할 수 있음
          padding: const EdgeInsets.symmetric(
            horizontal: 33,
            vertical: 16,
          ), // 내부 패딩 유지 또는 조절
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 2,
          disabledBackgroundColor: Colors.grey.shade300,
        ),
      ),
    );
  }
}
