import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:drug/presentation/widgets/common_bottom_nav.dart';

class ChatMessage {
  final String text;
  final bool isUserMessage; // 사용자가 보낸 메시지인지 여부

  ChatMessage({required this.text, required this.isUserMessage});
}

class OtcChatbotScreen extends StatefulWidget {
  const OtcChatbotScreen({super.key});

  @override
  State<OtcChatbotScreen> createState() => _OtcChatbotScreenState();
}

class _OtcChatbotScreenState extends State<OtcChatbotScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = []; // 채팅 메시지 목록
  bool _isLoading = false; // API 요청 중 로딩 상태
  String? _errorMessage; // 오류 메시지

  final String _apiUrl = "https://notable-manatee-actual.ngrok-free.app/query";

  final String _disclaimerMessage =
      "안녕하세요! AI 약사입니다. 일반 의약품 추천은 참고용으로만 활용해 주시고, "
      "정확한 진단과 처방은 반드시 의사 또는 약사와 상담하시기 바랍니다. "
      "제공되는 정보는 의학적 조언을 대체할 수 없습니다.";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _messages.isEmpty) {
        // 이미 메시지가 있는 경우는 제외 (핫 리로드 등)
        setState(() {
          _messages.insert(
            0, // reverse: true이므로 0번 인덱스에 추가하면 맨 아래(가장 먼저 보임)
            ChatMessage(text: _disclaimerMessage, isUserMessage: false),
          );
        });
      }
    });
  }

  // 메시지 전송 및 API 호출 함수
  Future<void> _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return; // 빈 메시지 방지

    _textController.clear(); // 입력 필드 초기화

    // 사용자 메시지 추가
    setState(() {
      _messages.insert(
        0,
        ChatMessage(text: text, isUserMessage: true),
      ); // 새 메시지를 맨 위에 추가
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print("Sending query to OTC chatbot API: $text");
      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {
              'Content-Type': 'application/json',
            }, // 서버가 JSON 입력을 받는다고 가정
            body: jsonEncode({'query': text}), // 'query' 필드명으로 전송
          )
          .timeout(const Duration(seconds: 60)); // 타임아웃 설정

      print("OTC Chatbot API Response Status: ${response.statusCode}");
      // print("OTC Chatbot API Response Body: ${response.body}");

      String decodedBodyForLog;
      try {
        decodedBodyForLog = utf8.decode(response.bodyBytes);
      } catch (e) {
        decodedBodyForLog =
            "Error decoding body for log: $e. Raw body: ${response.body}";
      }
      print(
        "OTC Chatbot API Response Body (Decoded for log): $decodedBodyForLog",
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(
          utf8.decode(response.bodyBytes),
        ); // UTF-8 디코딩 추가

        if (responseData['answer'] != null &&
            responseData['answer'] is String) {
          final String botAnswer = responseData['answer'];
          setState(() {
            _messages.insert(
              0,
              ChatMessage(text: botAnswer, isUserMessage: false),
            );
          });
        } else {
          throw Exception("API 응답에서 'answer' 필드를 찾을 수 없거나 형식이 다릅니다.");
        }
        // TODO: 'hits' 필드 활용은 추후 구현
      } else {
        throw Exception("서버 오류 발생: ${response.statusCode}");
      }
    } catch (e) {
      print("Error calling OTC Chatbot API: $e");
      String displayError = "죄송합니다, 답변을 가져오는 중 오류가 발생했습니다.";
      if (e is TimeoutException) {
        displayError = "서버 응답 시간이 초과되었습니다. 다시 시도해주세요.";
      } else if (e.toString().contains("Connection refused")) {
        displayError = "서버에 연결할 수 없습니다. 네트워크를 확인해주세요.";
      }
      setState(() {
        _messages.insert(
          0,
          ChatMessage(text: displayError, isUserMessage: false),
        );
        _errorMessage = displayError; // 별도 오류 메시지 UI에 표시 가능
      });
    } finally {
      if (mounted) {
        // mounted 체크 추가
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('AI 약사', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF7B8AC3),
        foregroundColor: Colors.white,
        elevation: 1,
        toolbarHeight: 65,
      ),
      body: Column(
        children: <Widget>[
          // 채팅 메시지 목록
          Expanded(
            child: ListView.builder(
              reverse: true, // 새 메시지가 아래에 추가되고 위로 스크롤되도록
              padding: const EdgeInsets.all(12.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildChatMessageBubble(message);
              },
            ),
          ),
          // 로딩 인디케이터
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: LinearProgressIndicator(minHeight: 3), // 얇은 로딩 바
            ),
          // 입력 필드 및 전송 버튼 영역
          _buildTextComposer(),
        ],
      ),
      // 하단 네비게이션 바 (인덱스는 상황에 맞게 조절)
      bottomNavigationBar: CommonBottomNavBar(
        currentIndex: 0,
        onTap: (index) {
          if (index == 0)
            Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
          else if (index == 1)
            Navigator.pushNamed(context, '/management');
          // 설정 화면 등
        },
      ),
    );
  }

  // 채팅 메시지 UI 구성
  Widget _buildChatMessageBubble(ChatMessage message) {
    final bool isUser = message.isUserMessage;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 챗봇 아이콘 (사용자 메시지 아닐 때만)
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(right: 8.0, top: 2.0),
              child: CircleAvatar(
                backgroundColor: Colors.teal[100],
                child: Icon(
                  Icons.medication_liquid_outlined,
                  size: 20,
                  color: Colors.teal[700],
                ),
              ),
            ),
          // 메시지 내용
          Flexible(
            // Flexible로 감싸서 긴 텍스트 자동 줄바꿈
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14.0,
                vertical: 10.0,
              ),
              decoration: BoxDecoration(
                color: isUser ? Colors.blue[500] : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18.0),
                  topRight: Radius.circular(18.0),
                  bottomLeft:
                      isUser ? Radius.circular(18.0) : Radius.circular(4.0),
                  bottomRight:
                      isUser ? Radius.circular(4.0) : Radius.circular(18.0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 3,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: 15.5,
                  color: isUser ? Colors.white : Colors.black87,
                ),
                softWrap: true,
              ),
            ),
          ),
          // 사용자 아이콘 (사용자 메시지일 때만)
          if (isUser)
            Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 2.0),
              child: CircleAvatar(
                backgroundColor: Colors.blue[50],
                child: Icon(
                  Icons.person_outline,
                  size: 20,
                  color: Colors.blue[700],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 텍스트 입력 필드 및 전송 버튼
  Widget _buildTextComposer() {
    return Container(
      margin: const EdgeInsets.only(
        left: 12.0,
        right: 12.0,
        bottom: 12.0,
        top: 8.0,
      ), // 하단 여백 증가
      padding: const EdgeInsets.symmetric(horizontal: 8.0), // 내부 좌우 패딩은 버튼용으로
      decoration: BoxDecoration(
        color: Colors.grey[100], // <<<=== 입력창 배경색 변경 (예: 연한 회색)
        borderRadius: BorderRadius.circular(25.0), // <<<=== 모서리 둥글기 조절
        border: Border.all(
          color: Colors.grey[300]!,
          width: 0.8,
        ), // <<<=== 얇은 테두리 추가
        boxShadow: [
          // <<<=== 그림자 효과 강화 (선택 사항)
          BoxShadow(
            offset: const Offset(0, 2),
            blurRadius: 5,
            color: Colors.black.withOpacity(0.08),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // 수직 중앙 정렬
        children: <Widget>[
          Flexible(
            child: Padding(
              // <<<=== TextField 주위에 패딩 추가
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 4.0,
              ), // 내부 패딩
              child: TextField(
                controller: _textController,
                onSubmitted: _isLoading ? null : _handleSubmitted,
                decoration: InputDecoration.collapsed(
                  hintText: "예: 기침 증상이 있는데 약 추천해줘",
                  hintStyle: TextStyle(
                    color: Colors.grey[500],
                  ), // <<<=== 힌트 텍스트 색상 변경
                ),
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                // textAlign: TextAlign.left, // 기본값
                style: const TextStyle(fontSize: 16.0), // <<<=== 입력 텍스트 크기 조절
              ),
            ),
          ),
          // 전송 버튼
          Container(
            // margin: const EdgeInsets.symmetric(horizontal: 4.0), // IconButton 패딩으로 대체 가능
            child: IconButton(
              icon: Icon(
                Icons.send_rounded, // <<<=== 아이콘 변경 (둥근 모양)
                color: Colors.black,
                size: 28, // <<<=== 아이콘 크기 조절
              ),
              onPressed:
                  _isLoading
                      ? null
                      : () => _handleSubmitted(_textController.text),
              padding: const EdgeInsets.all(10.0), // <<<=== 아이콘 버튼 터치 영역 확보
              tooltip: '전송', // <<<=== 툴팁 추가
            ),
          ),
        ],
      ),
    );
  }
}
