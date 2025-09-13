import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'camera_settings.dart';

class ApiResponse {
  final String text;
  final String? url;           // nullable로 변경
  final String? b64;           // nullable로 변경
  final CameraSettings? cameraSettings; // nullable로 변경

  ApiResponse({
    required this.text,
    this.url,
    this.b64,
    this.cameraSettings,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      text: json['text'] as String? ?? '',
      url: json['youtubeUrl'] as String?,
      b64: json['image'] as String?,
      cameraSettings: json['cameraSettings'] != null
          ? CameraSettings.fromJson(json['cameraSettings'] as Map<String, dynamic>)
          : null,
    );
  }
}

// ApiService 클래스 개선
class ApiService {
  static const String apiUrl = 'http://192.168.0.6:9877/agent-conversation';

  static Future<ApiResponse> sendToAgentica(String text, String? imagePath) async {
    try {
      final uri = Uri.parse(apiUrl);
      final request = http.MultipartRequest('POST', uri);

      // 텍스트 필드 추가
      request.fields['text'] = text;

      // 이미지 파일이 있는 경우 직접 파일에서 읽어서 전송
      if (imagePath != null && imagePath.isNotEmpty) {
        final file = File(imagePath);
        if (await file.exists()) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'image',      // 서버에서 기대하는 파라미터 이름
              imagePath,
            ),
          );
        } else {
          print('이미지 파일이 존재하지 않습니다: $imagePath');
        }
      }
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      print('🟢 StatusCode: ${response.statusCode}');
      print('🟢 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResponse.fromJson(data);
      } else {
        throw Exception('API 요청 실패: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('sendToAgentica 오류: $e');
      rethrow;
    }
  }
}
