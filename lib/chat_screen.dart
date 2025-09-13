
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'camera_settings.dart';

import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'apiservice.dart';
import 'dart:convert';

import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';



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
  String? _pendingImagePath;

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }

  // 메시지 제출 핸들러 모두 이 함수로 통합
  void _sendMessage({required String text, String? imagePath}) {
    if (text.trim().isEmpty && imagePath == null) return;

    // 1) 사용자 메시지 추가
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
        imagePath: imagePath,
      ));
    });
    _scrollToBottom();

    // 2) Agentica 호출
    _processUserInput(text: text, imagePath: imagePath);
  }

  Future<void> _processUserInput({
    required String text,
    String? imagePath,
  }) async {
    setState(() => _isTyping = true);
    try {
      await _sendToAgentica(text: text, imagePath: imagePath);
      // _addBotMessage(
      //   text: "테스트 중",
      // );
    } catch (e) {
      print('사용자 입력 처리 오류: $e');
      _addBotMessage(
        text: "처리 중 오류가 발생했습니다. 다시 시도해 주세요.",
      );
    } finally {
      if (mounted) {
        setState(() => _isTyping = false);
      }
    }
  }

  Future<void> _sendToAgentica({
    required String text,
    String? imagePath,
  }) async {
    try {
      // imagePath를 그대로 ApiService로 전달
      final res = await ApiService.sendToAgentica(text, imagePath);

      // 지연 시간 추가 (UX 개선)
      await Future.delayed(const Duration(milliseconds: 800));

      // 응답 처리
      if (res.cameraSettings != null) {
        // 카메라 설정 응답
        _addBotMessage(
          text: res.text,
          cameraSettings: res.cameraSettings,
        );
      } else if (res.url != null && res.url!.isNotEmpty) {
        // YouTube URL 응답
        _addBotMessage(
          text: "이런 숏츠 영상을 추천드려요!",
          youtubeUrl: res.url,
        );
      } else if (res.b64 != null && res.b64!.isNotEmpty) {
        // 보정된 이미지 응답
        try {
          final processedImageBytes = base64Decode(res.b64!);

          _addBotMessage(
            text: "보정 완료",
            image: processedImageBytes,
          );
        } catch (e) {
          print('이미지 디코딩 오류: $e');
          _addBotMessage(text: "이미지 처리 중 오류가 발생했습니다.");
        }
      } else {
        // 일반 텍스트 응답
        _addBotMessage(text: res.text.isNotEmpty ? res.text : "응답을 받지 못했습니다.");
      }
    } catch (e) {
      print('Agentica API 오류: $e');
      _addBotMessage(
        text: "죄송합니다. 서버와의 통신 중 오류가 발생했습니다. 다시 시도해 주세요.",
      );
    }
  }

  // 봇 메시지 추가를 위한 헬퍼 함수
  void _addBotMessage({
    required String text,
    CameraSettings? cameraSettings,
    String? youtubeUrl,
    Uint8List? image,
  }) {
    if (mounted) {
      setState(() {
        _messages.add(ChatMessage(
          text: text,
          isUser: false,
          timestamp: DateTime.now(),
          cameraSettings: cameraSettings,
          youtubeUrl: youtubeUrl,
          image: image,
        ));
      });
      _scrollToBottom();
    }
  }

  void _addWelcomeMessage() {
    _messages.add(ChatMessage(
      text: "안녕하세요!\n\n 카메라 어시스턴트, CAMgent입니다.",
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
      _pendingImagePath = image.path;
    });
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

  // 텍스트 메시지 제출 핸들러
  void _handleSubmitted(String text) {
    final trimmed = text.trim();
    final hasImage = _pendingImagePath != null;
    // ✅ 텍스트도 없고 이미지도 없을 때만 막기
    if (trimmed.isEmpty && !hasImage) return;

    // 텍스트와 이미지(있다면) 함께 전송
    _sendMessage(text: text.trim(), imagePath: _pendingImagePath);

    _textController.clear();
    // 이미지 초기화
    setState(() {
      _pendingImagePath = null;
    });
  }

  // build 메서드
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

                if (_isTyping)
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Container(
                      color: Colors.transparent, // 필요시 배경 제거/유지
                      child: _buildTypingIndicator(),
                    ),
                  ),
                // 타이핑 인디케이터
              ],
            ),
          ),

          _buildInputArea(),
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
                          // 사용자가 보낸 이미지 (imagePath)
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
                          // 봇이 보낸 처리된 이미지 (image bytes)
                          if (message.image != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                message.image!,
                                width: 200,
                                height: 200,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () async {
                                try {
                                  // 1) 임시 파일로 쓰기
                                  final tmpDir = await getTemporaryDirectory();
                                  final tmpPath = '${tmpDir.path}/ai_${DateTime.now().millisecondsSinceEpoch}.png';
                                  final tmpFile = File(tmpPath);
                                  await tmpFile.writeAsBytes(message.image!);

                                  // 3) Gal로 갤러리에 저장
                                  await Gal.putImage(tmpFile.path);

                                  // 예외 없이 여기까지 오면 성공
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('갤러리에 저장되었습니다')),
                                  );

                                }catch(e){
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('저장 중 오류 발생: $e')),
                                  );
                                }
                              },
                              icon: const Icon(Icons.download_rounded, size: 18),
                              label: const Text('갤러리에 저장'),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(150, 36),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                            ),
                            const SizedBox(height: 8,),
                          ],
                          // 텍스트 (텍스트가 있을 때만)
                          if (message.text.isNotEmpty) ...[
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
          ],
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_pendingImagePath != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(_pendingImagePath!),
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 0, right: 0,
                  child: GestureDetector(
                    onTap: () => setState(() => _pendingImagePath = null),
                    child: const Icon(Icons.close, size: 20, color: Colors.white),
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
              IconButton(
                icon: const Icon(Icons.photo),
                onPressed: _showImagePickerDialog,
                tooltip: '사진 첨부',
              ),
              Expanded(
                child: TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    hintText: '무엇을 도와드릴까요?',
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
                  textInputAction: TextInputAction.send,
                  onSubmitted: _handleSubmitted,
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
  final Uint8List? image;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.cameraSettings,
    this.imagePath,
    this.youtubeUrl,
    this.image,
  });
}

class YouTubePlayerItem extends StatefulWidget {
  final String youtubeUrl;
  const YouTubePlayerItem({ Key? key, required this.youtubeUrl }) : super(key: key);

  @override
  _YouTubePlayerItemState createState() => _YouTubePlayerItemState();
}

class _YouTubePlayerItemState extends State<YouTubePlayerItem> {
  late YoutubePlayerController? _ytController;
  late final String _videoId;

  @override
  void initState() {
    super.initState();
    _videoId = YoutubePlayer.convertUrlToId(widget.youtubeUrl) ?? '';
    if (_videoId.isNotEmpty) {
      _ytController = YoutubePlayerController(
        initialVideoId: _videoId,
        flags: const YoutubePlayerFlags(autoPlay: false, mute: false),
      );
    }
  }

  @override
  void dispose() {
    _ytController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_videoId.isEmpty || _ytController == null) {
      return const SizedBox.shrink(); // 또는 에러 메시지 UI
    }
    return YoutubePlayer(
      controller: _ytController!,
      showVideoProgressIndicator: true,
      progressIndicatorColor: Theme.of(context).colorScheme.primary,
    );
  }
}



