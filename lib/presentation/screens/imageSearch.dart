// imageSearch.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drug/presentation/screens/DrugDetailScreen.dart';
import 'package:flutter/material.dart';
import 'package:drug/presentation/widgets/common_bottom_nav.dart';
import 'package:drug/data/database/drug_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class ImageSearchScreen extends StatefulWidget {
  // isSeniorMode 파라미터 추가
  final bool isSeniorMode;

  const ImageSearchScreen({super.key, required this.isSeniorMode});

  @override
  State<ImageSearchScreen> createState() => _ImageSearchScreenState();
}

class _ImageSearchScreenState extends State<ImageSearchScreen> {
  File? _selectedImage;
  bool _isLoading = false;
  String? _errorMessage;
  final ImagePicker _picker = ImagePicker();
  final dbInstance = DrugDatabase.instance;

  Future<void> _pickImageFromCamera() async {
    // ... (기존 함수 내용 변경 없음)
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.camera);
      if (pickedFile != null) {
        setState(() => _selectedImage = File(pickedFile.path));
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "카메라 접근 중 오류 발생: $e");
    }
  }

  Future<void> _pickImageFromGallery() async {
    // ... (기존 함수 내용 변경 없음)
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() => _selectedImage = File(pickedFile.path));
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "갤러리 접근 중 오류 발생: $e");
    }
  }

  Future<void> _uploadAndIdentifyImage() async {
    if (_selectedImage == null) return;
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final String apiUrl = "http://52.78.59.115:8000/predict";
    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.files.add(await http.MultipartFile.fromPath("file", _selectedImage!.path));
      var streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        final result = jsonDecode(responseBody);
        if (result['predictions'] != null && (result['predictions'] as List).isNotEmpty) {
          final prediction = result['predictions'][0];
          final String? labelName = prediction['label_name']?.toString();
          final double? score = (prediction['score'] as num?)?.toDouble();

          if (labelName != null && score != null) {
            final drug = await dbInstance.getDrugByItemSeq(labelName);
            if (drug != null) {
              if (!mounted) return;
              // ==========================================================
              // 상세 화면으로 isSeniorMode 상태 전달
              // ==========================================================
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DrugDetailScreen(
                    drug: drug,
                    score: score,
                    isSeniorMode: widget.isSeniorMode,
                  ),
                ),
              );
              // ==========================================================
            } else {
              if (mounted) setState(() => _errorMessage = "식별된 약 정보(ID: $labelName)를 찾을 수 없습니다.");
            }
          } else {
            if (mounted) setState(() => _errorMessage = "서버 응답에서 유효한 약 정보를 얻지 못했습니다.");
          }
        } else {
          if (mounted) setState(() => _errorMessage = "이미지에서 약을 식별하지 못했습니다.");
        }
      } else {
        if (mounted) setState(() => _errorMessage = "이미지 식별 실패 (서버 오류 ${streamedResponse.statusCode})");
      }
    } catch (e) {
      if (mounted) {
        if (e is TimeoutException) {
          setState(() => _errorMessage = "서버 응답 시간 초과. 다시 시도해주세요.");
        } else {
          setState(() => _errorMessage = "오류 발생: $e");
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accentColor1 = Colors.cyan.shade600;
    final Color accentColor2 = Colors.orange.shade600;
    final isSeniorMode = widget.isSeniorMode; // <<< 시니어 모드 변수

    // =================================================================
    // 시니어 모드에 따른 UI 값 동적 설정
    // =================================================================
    final double headerTitleSize = isSeniorMode ? 26.0 : 22.0;
    final double headerIconSize = isSeniorMode ? 30.0 : 26.0;
    final double placeholderIconSize = isSeniorMode ? 90.0 : 70.0;
    final double placeholderTextSize = isSeniorMode ? 20.0 : 16.0;
    final double guideTextSize = isSeniorMode ? 20.0 : 16.0;
    final double choiceButtonFontSize = isSeniorMode ? 22.0 : 18.0;
    final double choiceButtonIconSize = isSeniorMode ? 28.0 : 24.0;
    final EdgeInsets choiceButtonPadding = isSeniorMode
        ? const EdgeInsets.symmetric(horizontal: 28, vertical: 20)
        : const EdgeInsets.symmetric(horizontal: 33, vertical: 16);
    final double identifyButtonHeight = isSeniorMode ? 65.0 : 55.0;
    final double identifyButtonFontSize = isSeniorMode ? 22.0 : 18.0;
    final double identifyButtonIconSize = isSeniorMode ? 32.0 : 28.0;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryColor.withOpacity(0.7), Colors.cyan.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10.0, left: 8.0, right: 16.0, bottom: 5.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: headerIconSize), // <<< 시니어 모드 적용
                      onPressed: () => Navigator.pop(context),
                      tooltip: '뒤로가기',
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '이미지로 약 검색',
                      style: TextStyle(
                        fontSize: headerTitleSize, // <<< 시니어 모드 적용
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
                  margin: const EdgeInsets.only(top: 15.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: Offset(0, -2))],
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 25, 20, 20),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: MediaQuery.of(context).size.width * 0.8,
                          height: MediaQuery.of(context).size.width * 0.8,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.grey.shade300, width: 1.5),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              _selectedImage != null
                                  ? ClipRRect(borderRadius: BorderRadius.circular(14.0), child: Image.file(_selectedImage!, fit: BoxFit.contain))
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.photo_camera_back_outlined, size: placeholderIconSize, color: Colors.grey[400]), // <<< 시니어 모드 적용
                                        const SizedBox(height: 12),
                                        Text(
                                          "카메라 또는 앨범에서\n이미지를 선택하세요.",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Colors.grey[600], fontSize: placeholderTextSize), // <<< 시니어 모드 적용
                                        ),
                                      ],
                                    ),
                              if (_isLoading)
                                Container(
                                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(12)),
                                  child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                                ),
                            ],
                          ),
                        ),
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w500, fontSize: 14.5), textAlign: TextAlign.center),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
                          child: Text(
                            '선명한 알약 사진은 더 정확한 결과를 제공합니다.\n(약을 하나씩만 촬영해 주세요.)',
                            style: TextStyle(fontSize: guideTextSize, color: Colors.grey[700], height: 1.8, fontWeight: FontWeight.w500), // <<< 시니어 모드 적용
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStyledChoiceButton(
                              icon: Icons.camera_alt_rounded,
                              label: '촬영하기',
                              color: accentColor1,
                              onPressed: _isLoading ? null : _pickImageFromCamera,
                              isSeniorMode: isSeniorMode, // <<< 시니어 모드 전달
                            ),
                            _buildStyledChoiceButton(
                              icon: Icons.photo_library_rounded,
                              label: '앨범 선택',
                              color: accentColor2,
                              onPressed: _isLoading ? null : _pickImageFromGallery,
                              isSeniorMode: isSeniorMode, // <<< 시니어 모드 전달
                            ),
                          ],
                        ),
                        const SizedBox(height: 25),
                        ElevatedButton.icon(
                          onPressed: (_selectedImage != null && !_isLoading) ? _uploadAndIdentifyImage : null,
                          icon: Icon(Icons.manage_search_rounded, color: Colors.white, size: identifyButtonIconSize), // <<< 시니어 모드 적용
                          label: Text('선택한 이미지로 약 식별', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            minimumSize: Size(double.infinity, identifyButtonHeight), // <<< 시니어 모드 적용
                            textStyle: TextStyle(fontSize: identifyButtonFontSize, fontWeight: FontWeight.bold), // <<< 시니어 모드 적용
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      bottomNavigationBar: CommonBottomNavBar(
        currentIndex: 0,
        onTap: (index) {
          if (index == 0) Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
          else if (index == 1) Navigator.pushNamed(context, '/management');
        },
      ),
    );
  }

  // 버튼 Helper 위젯 수정: isSeniorMode 파라미터 추가
  Widget _buildStyledChoiceButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
    required bool isSeniorMode, // <<< 시니어 모드 파라미터
  }) {
    // =================================================================
    // 버튼 내부 UI 동적 설정
    // =================================================================
    final double fontSize = isSeniorMode ? 22.0 : 18.0;
    final double iconSize = isSeniorMode ? 28.0 : 24.0;
    final EdgeInsets padding = isSeniorMode
        ? const EdgeInsets.symmetric(horizontal: 22, vertical: 20) // 시니어 모드일 때 좌우 패딩을 약간 줄여서 화면에 맞춤
        : const EdgeInsets.symmetric(horizontal: 28, vertical: 16);

    return Expanded( // <<< Expanded로 감싸서 버튼이 화면 너비에 맞게 조절되도록 함
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white, size: iconSize), // <<< 시니어 모드 적용
          label: Text(label, style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            padding: padding, // <<< 시니어 모드 적용
            textStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold), // <<< 시니어 모드 적용
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    );
  }
}