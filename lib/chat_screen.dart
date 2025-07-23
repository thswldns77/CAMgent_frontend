// lib/chat_screen.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'camera_settings.dart';

import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'apiservice.dart';

class ChatScreen extends StatefulWidget {
  final Function(CameraSettings) onSettingsReceived;

  const ChatScreen({Key? key, required this.onSettingsReceived}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    _messages.add(ChatMessage(
      text: "안녕하세요! 📸 스마트 카메라 어시스턴트입니다.\n\n어떤 사진을 찍고 싶으신가요? 예를 들어:\n• \"인물 사진을 찍고 싶어\"\n• \"야경 촬영 설정 알려줘\"\n• \"접사 사진 찍는 법\"\n• \"운동하는 모습 찍기\"\n• \"밝게 찍고 싶어\"\n• \"어둡게 찍고 싶어\"\n\n또는 사진을 첨부해서 이런 사진을 찍고 싶다고 알려주세요! 📷",
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  // 갤러리에서 이미지 선택
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        _sendImageMessage(image);
      }
    } catch (e) {
      _showErrorSnackBar('이미지를 선택하는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  // 카메라로 사진 촬영
  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        _sendImageMessage(image);
      }
    } catch (e) {
      _showErrorSnackBar('사진을 촬영하는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  // 이미지 메시지 전송
  void _sendImageMessage(XFile image) {
    setState(() {
      _messages.add(ChatMessage(
        text: "이런 스타일의 사진을 찍고 싶어요",
        isUser: true,
        timestamp: DateTime.now(),
        imagePath: image.path,
      ));
    });

    _scrollToBottom();

    // 이미지와 함께 전송된 경우 이미지 분석 함수 실행
    _processImageInput(image.path);
  }

  // 이미지 선택 다이얼로그 표시
  void _showImagePickerDialog() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('갤러리에서 선택'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('카메라로 촬영'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel),
                title: const Text('취소'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty) return;

    _textController.clear();

    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
    });

    _scrollToBottom();

    // 텍스트만 입력된 경우 일반 처리
    _processUserInput(text);
  }

  // 이미지 분석 및 처리 함수 (사진이 첨부된 경우)
  Future<void> _processImageInput(String imagePath) async {
    // 1) 타이핑 상태 시작
    setState(() => _isTyping = true);

    // 2) 이미지 분석 (실제로는 AI 모델이나 서버로 분석)
    final analysisResult = await ApiService.analyzeImage(imagePath);

    // 3) 분석 결과를 바탕으로 응답 및 설정 생성
    final response = _generateImageBasedResponse(analysisResult);
    final settings = _extractImageBasedCameraSettings(analysisResult);

    // 4) 지연 시간 추가
    await Future.delayed(const Duration(milliseconds: 1200));

    // 5) 채팅창에 봇 응답 추가 및 타이핑 상태 종료
    setState(() {
      _messages.add(ChatMessage(
        text: response,
        isUser: false,
        timestamp: DateTime.now(),
        cameraSettings: settings,
      ));
      _isTyping = false;
    });

    _scrollToBottom();
  }


  // 이미지 분석 결과 기반 응답 생성
  String _generateImageBasedResponse(String analysisResult) {
    switch (analysisResult) {
      case 'portrait':
        return "업로드해주신 사진을 분석한 결과, 인물 사진 스타일로 보입니다! 📸\n\n비슷한 느낌의 사진을 찍기 위한 설정을 준비했습니다:\n• 아웃포커싱 효과를 위한 낮은 F값\n• 자연스러운 피부톤 색감 조정\n• 얼굴 인식 AF 활성화\n• ISO 200으로 노이즈 최소화\n\n아래 버튼을 눌러 설정을 적용해보세요!";

      case 'night':
        return "업로드해주신 사진을 분석한 결과, 야간/저조도 사진 스타일로 보입니다! 🌃\n\n비슷한 분위기의 사진을 찍기 위한 설정을 준비했습니다:\n• 높은 ISO로 밝기 확보\n• 적절한 노출 시간 설정\n• 노이즈 감소 기능 활성화\n• 삼각대 사용 권장\n\n아래 버튼을 눌러 설정을 적용해보세요!";

      case 'landscape':
        return "업로드해주신 사진을 분석한 결과, 풍경 사진 스타일로 보입니다! 🏔️\n\n비슷한 느낌의 사진을 찍기 위한 설정을 준비했습니다:\n• 넓은 피사계 심도를 위한 높은 F값\n• 선명한 이미지를 위한 낮은 ISO\n• 풍경 모드 최적화\n• 화이트밸런스 자동 조정\n\n아래 버튼을 눌러 설정을 적용해보세요!";

      case 'macro':
        return "업로드해주신 사진을 분석한 결과, 접사/클로즈업 사진 스타일로 보입니다! 🔍\n\n비슷한 느낌의 사진을 찍기 위한 설정을 준비했습니다:\n• 매크로 모드 활성화\n• 높은 F값으로 피사계 심도 확보\n• 정확한 수동 포커스 모드\n• 충분한 조명 확보 설정\n\n아래 버튼을 눌러 설정을 적용해보세요!";

      default:
        return "업로드해주신 사진을 분석했습니다! 📷\n\n사진의 특성을 바탕으로 최적의 촬영 설정을 준비했습니다. 비슷한 느낌의 사진을 찍을 수 있도록 카메라 파라미터를 조정했습니다.\n\n아래 버튼을 눌러 설정을 적용해보세요!";
    }
  }

  // 이미지 분석 결과 기반 카메라 설정 생성
  CameraSettings _extractImageBasedCameraSettings(String analysisResult) {
    switch (analysisResult) {
      case 'portrait':
        return CameraSettings(
          sensorSensitivity: 200,
          sensorExposureTime: 0.008,
          controlAeExposureCompensation: 0.3,
          flashMode: 'AUTO',
          jpegQuality: 95,
          controlSceneMode: 'PORTRAIT',
        );

      case 'night':
        return CameraSettings(
          sensorSensitivity: 1600,
          sensorExposureTime: 0.1,
          controlAeExposureCompensation: 0.0,
          flashMode: 'OFF',
          jpegQuality: 90,
          controlSceneMode: 'NIGHT',
        );

      case 'landscape':
        return CameraSettings(
          sensorSensitivity: 100,
          sensorExposureTime: 0.006,
          controlAeExposureCompensation: 0.0,
          flashMode: 'OFF',
          jpegQuality: 95,
          controlSceneMode: 'LANDSCAPE',
        );

      case 'macro':
        return CameraSettings(
          sensorSensitivity: 200,
          sensorExposureTime: 0.016,
          controlAeExposureCompensation: 0.0,
          flashMode: 'AUTO',
          jpegQuality: 95,
          controlSceneMode: 'MACRO',
        );

      default:
        return CameraSettings(
          sensorSensitivity: 400,
          sensorExposureTime: 0.008,
          controlAeExposureCompensation: 0.0,
          flashMode: 'AUTO',
          jpegQuality: 90,
          controlSceneMode: 'AUTO',
        );
    }
  }


  bool _isAdviceQuery(String input) {
    final lower = input.toLowerCase();
    return lower.contains('팁') ||
        lower.contains('조언') ||
        lower.contains('방법') ||
        lower.contains('어떻게') ||
        lower.contains('추천');
  }

  Future<void> _processUserInput(String input) async {
    // 1) 타이핑 상태 시작
    setState(() => _isTyping = true);
    final bool isAdvice      = _isAdviceQuery(input);
    if(isAdvice) {
      String botText = "이런 숏츠 영상을 추천드려요!";
      String? youtubeUrl;
      try {
        youtubeUrl = await ApiService.getUrl(input);
      } catch (e) {
        botText = "죄송해요, 영상을 가져오는 데 실패했어요.";
        youtubeUrl = null;
      }
      // 4) 지연 시간 추가 (UI 응답성 향상)
      await Future.delayed(const Duration(milliseconds: 800));

      // 5) 채팅창에 봇 응답 추가 및 타이핑 상태 종료
      setState(() {
        _messages.add(ChatMessage(
          text: botText,
          isUser: false,
          timestamp: DateTime.now(),
          youtubeUrl: youtubeUrl,
        ));
        _isTyping = false;
      });
    } else {
      // 2) 메시지 답변 준비
      final response = _generateResponse(input);

      // 3) 카메라 설정 준비
      CameraSettings? settings;
      try {
        settings = await ApiService.getMockCameraSettings(input);
      } catch (e) {
        settings = _extractCameraSettings(input);
      }

      // 4) 지연 시간 추가 (UI 응답성 향상)
      await Future.delayed(const Duration(milliseconds: 800));

      // 5) 채팅창에 봇 응답 추가 및 타이핑 상태 종료
      setState(() {
        _messages.add(ChatMessage(
          text: response,
          isUser: false,
          timestamp: DateTime.now(),
          cameraSettings: settings,
        ));
        _isTyping = false;
      });

    }

    _scrollToBottom();
  }

  // 카메라 설정 적용 및 화면 이동 함수
  void _applyCameraSettings(CameraSettings settings) {
    try {
      // 카메라 설정 적용
      widget.onSettingsReceived(settings);

      // 설정 적용 완료 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('카메라 설정이 적용되었습니다'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

    } catch (e) {
      _showErrorSnackBar('설정 적용 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _generateResponse(String input) {
    final lowerInput = input.toLowerCase();

    if (lowerInput.contains('인물') || lowerInput.contains('사람') || lowerInput.contains('포트레이트')) {
      return "인물 사진 촬영에 최적화된 설정을 준비했습니다! 📷\n\n• 아웃포커싱 효과를 위한 낮은 F값\n• 자연스러운 색감 조정\n• 얼굴 인식 AF 활성화\n• ISO 200으로 노이즈 최소화\n\n아래 버튼을 눌러 설정을 적용하고 촬영을 시작하세요!";
    }

    if (lowerInput.contains('야경') || lowerInput.contains('밤') || lowerInput.contains('어두운')) {
      return "야경 촬영 설정을 준비했습니다! 🌃\n\n• 높은 ISO 1600으로 밝기 확보\n• 긴 노출 시간 설정\n• 노이즈 감소 기능 활성화\n• 삼각대 사용 권장\n\n아래 버튼을 눌러 설정을 적용하고 촬영을 시작하세요!";
    }

    if (lowerInput.contains('접사') || lowerInput.contains('클로즈업') || lowerInput.contains('가까이')) {
      return "접사 촬영 설정을 준비했습니다! 🔍\n\n• 매크로 모드 활성화\n• 높은 F값으로 피사계 심도 확보\n• 정확한 초점을 위한 수동 포커스\n• 충분한 조명 확보\n\n아래 버튼을 눌러 설정을 적용하고 촬영을 시작하세요!";
    }

    if (lowerInput.contains('운동') || lowerInput.contains('스포츠') || lowerInput.contains('빠른')) {
      return "액션/스포츠 촬영 설정을 준비했습니다! 🏃‍♂️\n\n• 빠른 셔터 스피드로 동작 정지\n• 연속 촬영 모드 활성화\n• 추적 AF로 움직이는 피사체 포착\n• 높은 ISO 800으로 충분한 노출\n\n아래 버튼을 눌러 설정을 적용하고 촬영을 시작하세요!";
    }

    if (lowerInput.contains('풍경') || lowerInput.contains('자연') || lowerInput.contains('산') || lowerInput.contains('바다')) {
      return "풍경 촬영 설정을 준비했습니다! 🏔️\n\n• 넓은 피사계 심도를 위한 높은 F값\n• 선명한 이미지를 위한 낮은 ISO 100\n• 황금 시간대 촬영 권장\n• 삼각대 사용으로 안정성 확보\n\n아래 버튼을 눌러 설정을 적용하고 촬영을 시작하세요!";
    }

    if (lowerInput.contains('밝게') || lowerInput.contains('밝은')) {
      return "밝은 사진 촬영 설정을 준비했습니다! ☀️\n\n• ISO 800으로 감도 증가\n• 노출 보정 +1.0 적용\n• 자동 플래시 모드\n• 높은 품질 JPEG 95%\n\n아래 버튼을 눌러 설정을 적용하고 촬영을 시작하세요!";
    }

    if (lowerInput.contains('어둡게') || lowerInput.contains('어두운')) {
      return "어두운 분위기의 사진 설정을 준비했습니다! 🌙\n\n• ISO 100으로 노이즈 최소화\n• 노출 보정 -1.0 적용\n• 플래시 꺼짐\n• 품질 85%로 적절한 용량\n\n아래 버튼을 눌러 설정을 적용하고 촬영을 시작하세요!";
    }

    return "말씀해주신 내용을 바탕으로 카메라 설정을 준비했습니다! 📸\n\n기본적인 촬영 설정으로 구성되어 있으니, 상황에 맞게 조정해서 사용해보세요.\n\n아래 버튼을 눌러 설정을 적용하고 촬영을 시작하세요!";
  }

  CameraSettings _extractCameraSettings(String input) {
    final lowerInput = input.toLowerCase();

    if (lowerInput.contains('인물') || lowerInput.contains('사람') || lowerInput.contains('포트레이트')) {
      return CameraSettings(
        sensorSensitivity: 200,
        sensorExposureTime: 0.008,
        controlAeExposureCompensation: 0.0,
        flashMode: 'AUTO',
        jpegQuality: 95,
        controlSceneMode: 'PORTRAIT',
      );
    }

    if (lowerInput.contains('야경') || lowerInput.contains('밤') || lowerInput.contains('어두운')) {
      return CameraSettings(
        sensorSensitivity: 1600,
        sensorExposureTime: 0.066,
        controlAeExposureCompensation: 0.0,
        flashMode: 'OFF',
        jpegQuality: 90,
        controlSceneMode: 'NIGHT',
      );
    }

    if (lowerInput.contains('접사') || lowerInput.contains('클로즈업') || lowerInput.contains('가까이')) {
      return CameraSettings(
        sensorSensitivity: 100,
        sensorExposureTime: 0.016,
        controlAeExposureCompensation: 0.0,
        flashMode: 'AUTO',
        jpegQuality: 95,
        controlSceneMode: 'MACRO',
      );
    }

    if (lowerInput.contains('운동') || lowerInput.contains('스포츠') || lowerInput.contains('빠른')) {
      return CameraSettings(
        sensorSensitivity: 800,
        sensorExposureTime: 0.002,
        controlAeExposureCompensation: 0.0,
        flashMode: 'OFF',
        jpegQuality: 90,
        controlSceneMode: 'SPORTS',
      );
    }

    if (lowerInput.contains('풍경') || lowerInput.contains('자연') || lowerInput.contains('산') || lowerInput.contains('바다')) {
      return CameraSettings(
        sensorSensitivity: 100,
        sensorExposureTime: 0.008,
        controlAeExposureCompensation: 0.0,
        flashMode: 'OFF',
        jpegQuality: 95,
        controlSceneMode: 'LANDSCAPE',
      );
    }

    if (lowerInput.contains('밝게') || lowerInput.contains('밝은')) {
      return CameraSettings(
        sensorSensitivity: 800,
        sensorExposureTime: 0.008,
        controlAeExposureCompensation: 1.0,
        flashMode: 'AUTO',
        jpegQuality: 95,
        controlSceneMode: 'AUTO',
      );
    }

    if (lowerInput.contains('어둡게') || lowerInput.contains('어두운')) {
      return CameraSettings(
        sensorSensitivity: 100,
        sensorExposureTime: 0.008,
        controlAeExposureCompensation: -1.0,
        flashMode: 'OFF',
        jpegQuality: 85,
        controlSceneMode: 'AUTO',
      );
    }

    // 기본 설정
    return CameraSettings(
      sensorSensitivity: 400,
      sensorExposureTime: 0.008,
      controlAeExposureCompensation: 0.0,
      flashMode: 'AUTO',
      jpegQuality: 90,
      controlSceneMode: 'AUTO',
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.smart_toy, color: Colors.grey[600], size: 20),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Colors.grey[400],
        shape: BoxShape.circle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📸 카메라 어시스턴트'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // 메시지 리스트
                ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    return _buildMessageBubble(_messages[index]);
                  },
                ),
                // 타이핑 인디케이터
                if (_isTyping)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.white,
                      child: _buildTypingIndicator(),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                // 이미지 첨부 버튼
                IconButton(
                  onPressed: _showImagePickerDialog,
                  icon: const Icon(Icons.photo),
                  tooltip: '사진 첨부',
                ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: '어떤 사진을 찍고 싶으신가요?',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: _handleSubmitted,
                    textInputAction: TextInputAction.send,
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: () => _handleSubmitted(_textController.text),
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildMessageBubble(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment:
        message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // 1) 아바타 + 메시지 버블
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!message.isUser) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child:
                  const Icon(Icons.smart_toy, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: message.isUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    // 말풍선
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: message.isUser
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 이미지가 있는 경우
                          if (message.imagePath != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(message.imagePath!),
                                width: 200,
                                height: 200,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          // 텍스트
                          Text(
                            message.text,
                            style: TextStyle(
                              color: message.isUser
                                  ? Colors.white
                                  : Colors.black87,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 카메라 설정 버튼 (필요할 때만)
                    if (message.cameraSettings != null) ...[
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () =>
                            _applyCameraSettings(message.cameraSettings!),
                        icon: const Icon(Icons.camera_alt, size: 18),
                        label: const Text('설정 적용하고 촬영하기'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (message.isUser) ...[
                const SizedBox(width: 8),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child:
                  const Icon(Icons.person, color: Colors.grey, size: 16),
                ),
              ],
            ],
          ),

          // 2) YouTube URL (필요할 때만)
          if (message.youtubeUrl != null) ...[
            const SizedBox(height: 8),
            YouTubePlayerItem(youtubeUrl: message.youtubeUrl!),
            // GestureDetector(
            //   onTap: () async {
            //     final uri = Uri.parse(message.youtubeUrl!);
            //     if (await canLaunchUrl(uri)) {
            //       await launchUrl(uri, mode: LaunchMode.externalApplication);
            //     }
            //   },
            //   child: Row(
            //     mainAxisSize: MainAxisSize.min,
            //     children: [
            //       const Icon(Icons.ondemand_video,
            //           size: 20, color: Colors.red),
            //       const SizedBox(width: 4),
            //       const Text(
            //         'YouTube 영상 보기',
            //         style: TextStyle(
            //           color: Colors.blue,
            //           decoration: TextDecoration.underline,
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final CameraSettings? cameraSettings;
  final String? imagePath; // 이미지 경로 추가
  final String? youtubeUrl;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.cameraSettings,
    this.imagePath,
    this.youtubeUrl,
  });
}

class YouTubePlayerItem extends StatefulWidget {
  final String youtubeUrl;
  const YouTubePlayerItem({ Key? key, required this.youtubeUrl }) : super(key: key);

  @override
  _YouTubePlayerItemState createState() => _YouTubePlayerItemState();
}

class _YouTubePlayerItemState extends State<YouTubePlayerItem> {
  late YoutubePlayerController _ytController;

  @override
  void initState() {
    super.initState();
    final videoId = YoutubePlayer.convertUrlToId(widget.youtubeUrl) ?? '';
    _ytController = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
      ),
    );
  }

  @override
  void dispose() {
    _ytController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayer(
      controller: _ytController,
      showVideoProgressIndicator: true,
      progressIndicatorColor: Theme.of(context).colorScheme.primary,
      onReady: () { /* 필요시 콜백 */ },
    );
  }
}




