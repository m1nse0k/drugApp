// otc_chatbot_screen.dart
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

// =================================================================
// 1. isSeniorMode 파라미터를 받도록 StatefulWidget 수정
// =================================================================
class OtcChatbotScreen extends StatefulWidget {
  final bool isSeniorMode;

  const OtcChatbotScreen({super.key, required this.isSeniorMode});

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
        setState(() {
          _messages.insert(
            0,
            ChatMessage(text: _disclaimerMessage, isUserMessage: false),
          );
        });
      }
    });
  }

  Future<void> _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;

    _textController.clear();

    setState(() {
      _messages.insert(0, ChatMessage(text: text, isUserMessage: true));
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'query': text}),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
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
      } else {
        throw Exception("서버 오류 발생: ${response.statusCode}");
      }
    } catch (e) {
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
        _errorMessage = displayError;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // =================================================================
    // 2. 시니어 모드에 따른 UI 값들을 변수로 정의
    // =================================================================
    final isSeniorMode = widget.isSeniorMode;
    final double appBarTitleSize = isSeniorMode ? 24.0 : 20.0;
    final double appBarHeight = isSeniorMode ? 75.0 : 65.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'AI 약사',
          style: TextStyle(
            color: Colors.white,
            fontSize: appBarTitleSize, // <<< 시니어 모드 적용
          ),
        ),
        backgroundColor: const Color(0xFF7B8AC3),
        foregroundColor: Colors.white,
        elevation: 1,
        toolbarHeight: appBarHeight, // <<< 시니어 모드 적용
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(12.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                // _buildChatMessageBubble에 isSeniorMode 값 전달
                return _buildChatMessageBubble(message, isSeniorMode);
              },
            ),
          ),
          if (_isLoading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: LinearProgressIndicator(
                minHeight: isSeniorMode ? 5 : 3,
              ), // <<< 시니어 모드 적용
            ),
          // _buildTextComposer에 isSeniorMode 값 전달
          _buildTextComposer(isSeniorMode),
        ],
      ),
      // TODO: CommonBottomNavBar도 시니어 모드를 지원하도록 수정 필요
      bottomNavigationBar: CommonBottomNavBar(
        currentIndex: 0,
        onTap: (index) {
          if (index == 0)
            Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
          else if (index == 1)
            Navigator.pushNamed(context, '/management');
        },
      ),
    );
  }

  // =================================================================
  // 3. 채팅 말풍선 UI를 시니어 모드에 맞게 수정
  // =================================================================
  Widget _buildChatMessageBubble(ChatMessage message, bool isSeniorMode) {
    final bool isUser = message.isUserMessage;

    // 시니어 모드 UI 값 조정
    final double messageFontSize = isSeniorMode ? 20.0 : 15.5;
    final double avatarIconSize = isSeniorMode ? 26.0 : 20.0;
    final double avatarRadius = isSeniorMode ? 22.0 : 18.0;
    final EdgeInsets bubblePadding =
        isSeniorMode
            ? const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0)
            : const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0);
    final double verticalMargin = isSeniorMode ? 10.0 : 6.0;

    return Container(
      margin: EdgeInsets.symmetric(vertical: verticalMargin), // <<< 시니어 모드 적용
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(right: 8.0, top: 2.0),
              child: CircleAvatar(
                radius: avatarRadius, // <<< 시니어 모드 적용
                backgroundColor: Colors.teal[100],
                child: Icon(
                  Icons.medication_liquid_outlined,
                  size: avatarIconSize, // <<< 시니어 모드 적용
                  color: Colors.teal[700],
                ),
              ),
            ),
          Flexible(
            child: Container(
              padding: bubblePadding, // <<< 시니어 모드 적용
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
                  fontSize: messageFontSize, // <<< 시니어 모드 적용
                  color: isUser ? Colors.white : Colors.black87,
                ),
                softWrap: true,
              ),
            ),
          ),
          if (isUser)
            Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 2.0),
              child: CircleAvatar(
                radius: avatarRadius, // <<< 시니어 모드 적용
                backgroundColor: Colors.blue[50],
                child: Icon(
                  Icons.person_outline,
                  size: avatarIconSize, // <<< 시니어 모드 적용
                  color: Colors.blue[700],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // =================================================================
  // 4. 텍스트 입력창 UI를 시니어 모드에 맞게 수정
  // =================================================================
  Widget _buildTextComposer(bool isSeniorMode) {
    // 시니어 모드 UI 값 조정
    final double inputFontSize = isSeniorMode ? 20.0 : 16.0;
    final double sendIconSize = isSeniorMode ? 34.0 : 28.0;
    final double inputContainerBottomMargin = isSeniorMode ? 18.0 : 12.0;
    final double inputContainerBorderRadius = isSeniorMode ? 30.0 : 25.0;
    final EdgeInsets inputFieldPadding =
        isSeniorMode
            ? const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0)
            : const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0);

    return Container(
      margin: EdgeInsets.only(
        left: 12.0,
        right: 12.0,
        bottom: inputContainerBottomMargin, // <<< 시니어 모드 적용
        top: 8.0,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(
          inputContainerBorderRadius,
        ), // <<< 시니어 모드 적용
        border: Border.all(color: Colors.grey[300]!, width: 0.8),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 2),
            blurRadius: 5,
            color: Colors.black.withOpacity(0.08),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Flexible(
            child: Padding(
              padding: inputFieldPadding, // <<< 시니어 모드 적용
              child: TextField(
                controller: _textController,
                onSubmitted: _isLoading ? null : _handleSubmitted,
                decoration: InputDecoration.collapsed(
                  hintText: "증상을 입력하세요",
                  hintStyle: TextStyle(color: Colors.grey[500]),
                ),
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                style: TextStyle(fontSize: inputFontSize), // <<< 시니어 모드 적용
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.send_rounded,
              color: Colors.black,
              size: sendIconSize, // <<< 시니어 모드 적용
            ),
            onPressed:
                _isLoading
                    ? null
                    : () => _handleSubmitted(_textController.text),
            padding: const EdgeInsets.all(12.0), // 터치 영역 확보
            tooltip: '전송',
          ),
        ],
      ),
    );
  }
}
