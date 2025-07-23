import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'camera_settings.dart';





/// API 호출 서비스
class ApiService {
  static const String apiUrl = 'http://10.0.2.2:3000/agent-conversation';

  static Future<CameraSettings?> getCameraSettings(String requirement) async {
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'message': requirement}),
    );
    if (response.statusCode == 200) {
      return CameraSettings.fromJson(jsonDecode(response.body));
    }
    throw Exception('API 요청 실패: ${response.body}');
  }

  /// 테스트용 Mock
  static Future<CameraSettings?> getMockCameraSettings(String requirement) async {
    await Future.delayed(const Duration(seconds: 2));

    final lowerReq = requirement.toLowerCase();

    if (lowerReq.contains('밝게') || lowerReq.contains('밝은')) {
      return CameraSettings(
        sensorSensitivity: 800,
        sensorExposureTime: 0.033,
        controlAeExposureCompensation: 1.0,
        flashMode: 'AUTO',
        jpegQuality: 95,
        controlSceneMode: 'AUTO',
      );
    } else if (lowerReq.contains('어둡게') || lowerReq.contains('어두운')) {
      return CameraSettings(
        sensorSensitivity: 100,
        sensorExposureTime: 0.008,
        controlAeExposureCompensation: -1.0,
        flashMode: 'OFF',
        jpegQuality: 85,
        controlSceneMode: 'AUTO',
      );
    } else if (lowerReq.contains('인물') || lowerReq.contains('사람')) {
      return CameraSettings(
        sensorSensitivity: 200,
        sensorExposureTime: 0.008,
        controlAeExposureCompensation: 0.0,
        flashMode: 'AUTO',
        jpegQuality: 95,
        controlSceneMode: 'PORTRAIT',
      );
    } else if (lowerReq.contains('야경') || lowerReq.contains('밤')) {
      return CameraSettings(
        sensorSensitivity: 1600,
        sensorExposureTime: 0.066,
        controlAeExposureCompensation: 0.0,
        flashMode: 'OFF',
        jpegQuality: 90,
        controlSceneMode: 'NIGHT',
      );
    }

    return CameraSettings(
      sensorSensitivity: 400,
      sensorExposureTime: 0.008,
      jpegQuality: 90,
      controlSceneMode: 'AUTO',
      flashMode: 'AUTO',
    );
  }

  // url
  static Future<String?> getUrl(String requirement) async {
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'message': requirement}),
    );
    if (response.statusCode == 200) {
      final Map<String, dynamic> body = jsonDecode(response.body);
      final String botText      = body['text'] as String;
      final String? youtubeUrl  = body['youtubeUrl'] as String?;  // ← URL 파싱
      return youtubeUrl;
    }
    throw Exception('API 요청 실패: ${response.body}');
  }


  // 이미지 분석 함수 (모의 분석)
  static Future<String> analyzeImage(String imagePath) async {
    // 실제로는 여기서 AI 모델이나 서버 API를 호출해서 이미지를 분석

    String apiUrl = 'http://10.0.2.2:3000/agent-conversation';
    final bytes = await File(imagePath).readAsBytes();
    final base64Image = base64Encode(bytes);
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'message': base64Image}),
    );
    if (response.statusCode == 200) {
      // 지금은 모의 분석 결과를 반환
      await Future.delayed(const Duration(milliseconds: 500));

      return response.body;

    }
    throw Exception('API 요청 실패: ${response.body}');
  }


}
