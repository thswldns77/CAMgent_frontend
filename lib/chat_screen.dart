// lib/chat_screen.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'camera_settings.dart';

import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'apiservice.dart';
import 'dart:convert';


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

    // 2) Agentica에 페이로드 전송
    _sendToAgentica(text: text, imagePath: imagePath);
  }

  // Future<void> _sendToAgentica({  required String text,    String? imagePath,  }) async {
  //   setState(() => _isTyping = true);
  //
  //   // base64 인코딩(이미지 있으면)
  //   String? b64 = null;
  //   if (imagePath != null) {
  //     final bytes = await File(imagePath).readAsBytes();
  //     b64 = base64Encode(bytes);
  //   }
  //
  //   // Agentica 호출
  //   final res = await ApiService.sendToAgentica(text, b64!);
  //
  //   // 지연
  //   await Future.delayed(const Duration(milliseconds: 800));
  //
  //   // 봇 응답 추가
  //
  //   if(res.cameraSettings != null){
  //     setState(() {
  //       _messages.add(ChatMessage(
  //         text: res.text,
  //         isUser: false,
  //         timestamp: DateTime.now(),
  //         cameraSettings: res.cameraSettings,
  //       ));
  //       _isTyping = false;
  //     });
  //     _scrollToBottom();
  //   }else if(res.url != null){
  //
  //     setState(() {
  //       _messages.add(ChatMessage(
  //         text: "이런 숏츠 영상을 추천드려요!",
  //         isUser: false,
  //         timestamp: DateTime.now(),
  //         youtubeUrl: res.url,
  //       ));
  //       _isTyping = false;
  //     });
  //   }else if(res.b64 != null){
  //     Uint8List bytes = base64Decode(b64);
  //
  //     setState(() {
  //       _messages.add(ChatMessage(
  //         text: "보정 완료",
  //         isUser: false,
  //         timestamp: DateTime.now(),
  //         imagePath: res.b64,
  //       ));
  //       _isTyping = false;
  //     });
  //   }else{
  //     setState(() {
  //       _messages.add(ChatMessage(
  //         text: res.text,
  //         isUser: false,
  //         timestamp: DateTime.now(),
  //       ));
  //       _isTyping = false;
  //     });
  //     _scrollToBottom();
  //   }
  //
  //
  // }


  // Future<void> _sendToAgentica({  required String text,    String? imagePath,  }) async {
  //   setState(() => _isTyping = true);
  //
  //
  //   // Agentica 호출
  //   final res = await ApiService.sendToAgentica(text, imagePath!);
  //
  //   // 지연
  //   await Future.delayed(const Duration(milliseconds: 800));
  //
  //   // 봇 응답 추가
  //
  //   if(res.cameraSettings != null){
  //     setState(() {
  //       _messages.add(ChatMessage(
  //         text: res.text,
  //         isUser: false,
  //         timestamp: DateTime.now(),
  //         cameraSettings: res.cameraSettings,
  //       ));
  //       _isTyping = false;
  //     });
  //     _scrollToBottom();
  //   }else if(res.url != null){
  //
  //     setState(() {
  //       _messages.add(ChatMessage(
  //         text: "이런 숏츠 영상을 추천드려요!",
  //         isUser: false,
  //         timestamp: DateTime.now(),
  //         youtubeUrl: res.url,
  //       ));
  //       _isTyping = false;
  //     });
  //   }else if(res.b64 != null){
  //     Uint8List bytes = base64Decode(res.b64);
  //
  //     setState(() {
  //       _messages.add(ChatMessage(
  //         text: "보정 완료",
  //         isUser: false,
  //         timestamp: DateTime.now(),
  //         image: bytes,
  //       ));
  //       _isTyping = false;
  //     });
  //   }else{
  //     setState(() {
  //       _messages.add(ChatMessage(
  //         text: res.text,
  //         isUser: false,
  //         timestamp: DateTime.now(),
  //       ));
  //       _isTyping = false;
  //     });
  //     _scrollToBottom();
  //   }
  //
  //
  // }
// _sendToAgentica 함수 개선
  Future<void> _sendToAgentica({
    required String text,
    String? imagePath,
  }) async {
    setState(() => _isTyping = true);

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
    } finally {
      // 항상 타이핑 상태 해제
      if (mounted) {
        setState(() => _isTyping = false);
      }
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
      _pendingImagePath = image.path;
    });
  }


  // 선택
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
    if (text.trim().isEmpty) return;

    // 텍스트와 이미지(있다면) 함께 전송
    _sendMessage(text: text.trim(), imagePath: _pendingImagePath);

    //_sendMessage(text: text.trim(), imagePath: null);
    _textController.clear();

    // 이미지 초기화
    setState(() {
      _pendingImagePath = null;
    });
  }
// build 메서드와 _buildMessageBubble 메서드
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
          // Container(
          //   padding: const EdgeInsets.all(16),
          //   decoration: BoxDecoration(
          //     color: Theme.of(context).colorScheme.surface,
          //     boxShadow: [
          //       BoxShadow(
          //         color: Colors.black.withOpacity(0.05),
          //         blurRadius: 10,
          //         offset: const Offset(0, -5),
          //       ),
          //     ],
          //   ),
          //   child: Row(
          //     children: [
          //       // 이미지 첨부 버튼
          //       IconButton(
          //         onPressed: _showImagePickerDialog,
          //         icon: const Icon(Icons.photo),
          //         tooltip: '사진 첨부',
          //       ),
          //       Expanded(
          //         child: TextField(
          //           controller: _textController,
          //           decoration: InputDecoration(
          //             hintText: '어떤 사진을 찍고 싶으신가요?',
          //             border: OutlineInputBorder(
          //               borderRadius: BorderRadius.circular(24),
          //               borderSide: BorderSide.none,
          //             ),
          //             filled: true,
          //             fillColor: Colors.grey[100],
          //             contentPadding: const EdgeInsets.symmetric(
          //               horizontal: 16,
          //               vertical: 12,
          //             ),
          //           ),
          //           onSubmitted: _handleSubmitted,
          //           textInputAction: TextInputAction.send,
          //         ),
          //       ),
          //       const SizedBox(width: 8),
          //       FloatingActionButton(
          //         mini: true,
          //         onPressed: () => _handleSubmitted(_textController.text),
          //         child: const Icon(Icons.send),
          //       ),
          //     ],
          //   ),
          // ),
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
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.photo),
              onPressed: _showImagePickerDialog,
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                decoration: const InputDecoration(hintText: '메시지 입력'),
                textInputAction: TextInputAction.send,
                onSubmitted: _handleSubmitted,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: () => _handleSubmitted(_textController.text),
            ),
          ],
        ),
      ],
    );
  }


// 위에거 잘 안되면 밑에 꺼 ㄱㄱ

  //
  // // build 메서드와 _buildMessageBubble 메서드
  // @override
  // Widget build(BuildContext context) {
  //   return Scaffold(
  //     appBar: AppBar(
  //       title: const Text('📸 카메라 어시스턴트'),
  //       centerTitle: true,
  //       backgroundColor: Theme.of(context).colorScheme.surface,
  //       elevation: 0,
  //     ),
  //     body: Column(
  //       children: [
  //         Expanded(
  //           child: Stack(
  //             children: [
  //               // 메시지 리스트
  //               ListView.builder(
  //                 controller: _scrollController,
  //                 padding: const EdgeInsets.all(16),
  //                 itemCount: _messages.length,
  //                 itemBuilder: (context, index) {
  //                   return _buildMessageBubble(_messages[index]);
  //                 },
  //               ),
  //               // 타이핑 인디케이터
  //               if (_isTyping)
  //                 Positioned(
  //                   bottom: 0,
  //                   left: 0,
  //                   right: 0,
  //                   child: Container(
  //                     color: Colors.white,
  //                     child: _buildTypingIndicator(),
  //                   ),
  //                 ),
  //             ],
  //           ),
  //         ),
  //         Container(
  //           padding: const EdgeInsets.all(16),
  //           decoration: BoxDecoration(
  //             color: Theme.of(context).colorScheme.surface,
  //             boxShadow: [
  //               BoxShadow(
  //                 color: Colors.black.withOpacity(0.05),
  //                 blurRadius: 10,
  //                 offset: const Offset(0, -5),
  //               ),
  //             ],
  //           ),
  //           child: Row(
  //             children: [
  //               // 이미지 첨부 버튼
  //               IconButton(
  //                 onPressed: _showImagePickerDialog,
  //                 icon: const Icon(Icons.photo),
  //                 tooltip: '사진 첨부',
  //               ),
  //               Expanded(
  //                 child: TextField(
  //                   controller: _textController,
  //                   decoration: InputDecoration(
  //                     hintText: '어떤 사진을 찍고 싶으신가요?',
  //                     border: OutlineInputBorder(
  //                       borderRadius: BorderRadius.circular(24),
  //                       borderSide: BorderSide.none,
  //                     ),
  //                     filled: true,
  //                     fillColor: Colors.grey[100],
  //                     contentPadding: const EdgeInsets.symmetric(
  //                       horizontal: 16,
  //                       vertical: 12,
  //                     ),
  //                   ),
  //                   onSubmitted: _handleSubmitted,
  //                   textInputAction: TextInputAction.send,
  //                 ),
  //               ),
  //               const SizedBox(width: 8),
  //               FloatingActionButton(
  //                 mini: true,
  //                 onPressed: () => _handleSubmitted(_textController.text),
  //                 child: const Icon(Icons.send),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }
  //
  // Widget _buildMessageBubble(ChatMessage message) {
  //   return Container(
  //     margin: const EdgeInsets.symmetric(vertical: 4),
  //     child: Column(
  //       crossAxisAlignment:
  //       message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
  //       children: [
  //         // 1) 아바타 + 메시지 버블
  //         Row(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           mainAxisAlignment:
  //           message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
  //           children: [
  //             if (!message.isUser) ...[
  //               Container(
  //                 width: 32,
  //                 height: 32,
  //                 decoration: BoxDecoration(
  //                   color: Theme.of(context).colorScheme.primary,
  //                   shape: BoxShape.circle,
  //                 ),
  //                 child:
  //                 const Icon(Icons.smart_toy, color: Colors.white, size: 16),
  //               ),
  //               const SizedBox(width: 8),
  //             ],
  //             Flexible(
  //               child: Column(
  //                 crossAxisAlignment: message.isUser
  //                     ? CrossAxisAlignment.end
  //                     : CrossAxisAlignment.start,
  //                 children: [
  //                   // 말풍선
  //                   Container(
  //                     padding: const EdgeInsets.all(12),
  //                     decoration: BoxDecoration(
  //                       color: message.isUser
  //                           ? Theme.of(context).colorScheme.primary
  //                           : Colors.grey[100],
  //                       borderRadius: BorderRadius.circular(16),
  //                     ),
  //                     child: Column(
  //                       crossAxisAlignment: CrossAxisAlignment.start,
  //                       children: [
  //                         // 사용자가 보낸 이미지 (imagePath)
  //                         if (message.imagePath != null) ...[
  //                           ClipRRect(
  //                             borderRadius: BorderRadius.circular(8),
  //                             child: Image.file(
  //                               File(message.imagePath!),
  //                               width: 200,
  //                               height: 200,
  //                               fit: BoxFit.cover,
  //                             ),
  //                           ),
  //                           const SizedBox(height: 8),
  //                         ],
  //                         // 봇이 보낸 처리된 이미지 (image bytes)
  //                         if (message.image != null) ...[
  //                           ClipRRect(
  //                             borderRadius: BorderRadius.circular(8),
  //                             child: Image.memory(
  //                               message.image!,
  //                               width: 200,
  //                               height: 200,
  //                               fit: BoxFit.cover,
  //                             ),
  //                           ),
  //                           const SizedBox(height: 8),
  //                         ],
  //                         // 텍스트 (텍스트가 있을 때만)
  //                         if (message.text.isNotEmpty) ...[
  //                           Text(
  //                             message.text,
  //                             style: TextStyle(
  //                               color: message.isUser
  //                                   ? Colors.white
  //                                   : Colors.black87,
  //                               fontSize: 16,
  //                             ),
  //                           ),
  //                         ],
  //                       ],
  //                     ),
  //                   ),
  //                   // 카메라 설정 버튼 (필요할 때만)
  //                   if (message.cameraSettings != null) ...[
  //                     const SizedBox(height: 8),
  //                     ElevatedButton.icon(
  //                       onPressed: () =>
  //                           _applyCameraSettings(message.cameraSettings!),
  //                       icon: const Icon(Icons.camera_alt, size: 18),
  //                       label: const Text('설정 적용하고 촬영하기'),
  //                       style: ElevatedButton.styleFrom(
  //                         backgroundColor:
  //                         Theme.of(context).colorScheme.primary,
  //                         foregroundColor: Colors.white,
  //                         padding: const EdgeInsets.symmetric(
  //                             horizontal: 16, vertical: 8),
  //                         shape: RoundedRectangleBorder(
  //                           borderRadius: BorderRadius.circular(20),
  //                         ),
  //                       ),
  //                     ),
  //                   ],
  //                 ],
  //               ),
  //             ),
  //             if (message.isUser) ...[
  //               const SizedBox(width: 8),
  //               Container(
  //                 width: 32,
  //                 height: 32,
  //                 decoration: BoxDecoration(
  //                   color: Colors.grey[300],
  //                   shape: BoxShape.circle,
  //                 ),
  //                 child:
  //                 const Icon(Icons.person, color: Colors.grey, size: 16),
  //               ),
  //             ],
  //           ],
  //         ),
  //
  //         // 2) YouTube URL (필요할 때만)
  //         if (message.youtubeUrl != null) ...[
  //           const SizedBox(height: 8),
  //           YouTubePlayerItem(youtubeUrl: message.youtubeUrl!),
  //         ],
  //       ],
  //     ),
  //   );
  // }
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




