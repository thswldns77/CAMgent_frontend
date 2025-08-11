import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'camera_settings.dart';


// ApiResponse 클래스 개선
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
  static const String apiUrl = 'http://175.121.138.146:9877/agent-conversation';

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
      sensorExposureTime: 0.011,
      jpegQuality: 90,
      controlSceneMode: 'AUTO',
      flashMode: 'AUTO',
    );
  }
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
              // filename: 'image.jpg', // 필요시 파일명 지정
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

// /// API 호출 서비스
// class ApiService {
//   static const String apiUrl = 'http://10.0.2.2:3000/agent-conversation';
//   //
//   // static Future<CameraSettings?> getCameraSettings(String requirement) async {
//   //   final response = await http.post(
//   //     Uri.parse(apiUrl),
//   //     headers: {'Content-Type': 'application/json'},
//   //     body: jsonEncode({'message': requirement}),
//   //   );
//   //   if (response.statusCode == 200) {
//   //     return CameraSettings.fromJson(jsonDecode(response.body));
//   //   }
//   //   throw Exception('API 요청 실패: ${response.body}');
//   // }
//   //
//   // /// 테스트용 Mock
//   // static Future<CameraSettings?> getMockCameraSettings(String requirement) async {
//   //   await Future.delayed(const Duration(seconds: 2));
//   //
//   //   final lowerReq = requirement.toLowerCase();
//   //
//   //   if (lowerReq.contains('밝게') || lowerReq.contains('밝은')) {
//   //     return CameraSettings(
//   //       sensorSensitivity: 800,
//   //       sensorExposureTime: 0.033,
//   //       controlAeExposureCompensation: 1.0,
//   //       flashMode: 'AUTO',
//   //       jpegQuality: 95,
//   //       controlSceneMode: 'AUTO',
//   //     );
//   //   } else if (lowerReq.contains('어둡게') || lowerReq.contains('어두운')) {
//   //     return CameraSettings(
//   //       sensorSensitivity: 100,
//   //       sensorExposureTime: 0.008,
//   //       controlAeExposureCompensation: -1.0,
//   //       flashMode: 'OFF',
//   //       jpegQuality: 85,
//   //       controlSceneMode: 'AUTO',
//   //     );
//   //   } else if (lowerReq.contains('인물') || lowerReq.contains('사람')) {
//   //     return CameraSettings(
//   //       sensorSensitivity: 200,
//   //       sensorExposureTime: 0.008,
//   //       controlAeExposureCompensation: 0.0,
//   //       flashMode: 'AUTO',
//   //       jpegQuality: 95,
//   //       controlSceneMode: 'PORTRAIT',
//   //     );
//   //   } else if (lowerReq.contains('야경') || lowerReq.contains('밤')) {
//   //     return CameraSettings(
//   //       sensorSensitivity: 1600,
//   //       sensorExposureTime: 0.066,
//   //       controlAeExposureCompensation: 0.0,
//   //       flashMode: 'OFF',
//   //       jpegQuality: 90,
//   //       controlSceneMode: 'NIGHT',
//   //     );
//   //   }
//   //
//   //   return CameraSettings(
//   //     sensorSensitivity: 400,
//   //     sensorExposureTime: 0.008,
//   //     jpegQuality: 90,
//   //     controlSceneMode: 'AUTO',
//   //     flashMode: 'AUTO',
//   //   );
//   // }
//   //
//   // // url
//   // static Future<String?> getUrl(String requirement) async {
//   //   final response = await http.post(
//   //     Uri.parse(apiUrl),
//   //     headers: {'Content-Type': 'application/json'},
//   //     body: jsonEncode({'message': requirement}),
//   //   );
//   //   if (response.statusCode == 200) {
//   //     final Map<String, dynamic> body = jsonDecode(response.body);
//   //     final String botText      = body['text'] as String;
//   //     final String? youtubeUrl  = body['youtubeUrl'] as String?;  // ← URL 파싱
//   //     return youtubeUrl;
//   //   }
//   //   throw Exception('API 요청 실패: ${response.body}');
//   // }
//   //
//   //
//   // // 이미지 분석 함수 (모의 분석)
//   // static Future<String> analyzeImage(String imagePath) async {
//   //   // 실제로는 여기서 AI 모델이나 서버 API를 호출해서 이미지를 분석
//   //
//   //   String apiUrl = 'http://10.0.2.2:3000/agent-conversation';
//   //   final bytes = await File(imagePath).readAsBytes();
//   //   final base64Image = base64Encode(bytes);
//   //   final response = await http.post(
//   //     Uri.parse(apiUrl),
//   //     headers: {'Content-Type': 'application/json'},
//   //     body: jsonEncode({'message': base64Image}),
//   //   );
//   //   if (response.statusCode == 200) {
//   //     // 지금은 모의 분석 결과를 반환
//   //     await Future.delayed(const Duration(milliseconds: 500));
//   //
//   //     return response.body;
//   //
//   //   }
//   //   throw Exception('API 요청 실패: ${response.body}');
//   // }
//   //
//
//   static Future<ApiResponse> sendToAgentica(String text, String image) async {
//
//
//     // 1) MultipartRequest 생성
//     final uri = Uri.parse(apiUrl);
//     final request = http.MultipartRequest('POST', uri);
//
//     // 2) 텍스트 필드 추가
//     request.fields['text'] = text;
//
//     // 3) 이미지 파일 추가 (imagePath가 null이 아니면)
//     if (image != null) {
//       request.files.add(
//         await http.MultipartFile.fromPath(
//           'image',      // 서버에서 기대하는 파라미터 이름
//           image,
//           // contentType: MediaType('image', 'jpeg'), // 필요 시 MIME 지정
//         ),
//       );
//     }
//
//     // 4) 요청 전송 및 응답 수신
//     final streamed = await request.send();
//     final response = await http.Response.fromStream(streamed);
//     if (response.statusCode == 200) {
//       // 성공 처리
//
//         final data = jsonDecode(response.body) as Map<String, dynamic>;
//         return ApiResponse(
//           text: data['text'] as String,
//           url: data['youtubeUrl'] as String,
//           b64: data['image'] as String,
//           cameraSettings: CameraSettings.fromJson(
//               data['cameraSettings'] as Map<String, dynamic>
//           ),
//         );
//     }
//     throw Exception('API 요청 실패: ${response.body}');
//  }
//
//
//
//   //   final response = await http.post(
//   //     Uri.parse(apiUrl),
//   //     headers: { 'Content-Type': 'application/json' },
//   //     body: jsonEncode({'text' : text, 'image' : image}),
//   //   );
//   //   if(response.statusCode == 200){
//   //     final data = jsonDecode(response.body) as Map<String, dynamic>;
//   //     return ApiResponse(
//   //       text: data['text'] as String,
//   //       url: data['youtubeUrl'] as String,
//   //       b64: data['image'] as String,
//   //       cameraSettings: CameraSettings.fromJson(
//   //           data['cameraSettings'] as Map<String, dynamic>
//   //       ),
//   //     );
//   //   }
//   //   throw Exception('API 요청 실패: ${response.body}');
//   // }
// }
