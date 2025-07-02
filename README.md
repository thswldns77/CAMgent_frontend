# camgent

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

아래는 분리된 네 개의 파일(`main.dart`, `camera_settings.dart`, `requirements_screen.dart`, `camera_screen.dart`)을 기준으로 각 코드의 역할과 흐름을 정리한 설명입니다.

---

## 1. `lib/main.dart`

앱의 진입점이자 전체 내비게이션 구조를 담당합니다.

1. **`main()`**

   * Flutter 바인딩 초기화
   * 권한 요청(`_requestPermissions`)
   * 사용 가능한 카메라 목록을 `availableCameras()`로 가져와 `MyApp`에 전달

2. **`MyApp`**

   * `MaterialApp`으로 테마·타이틀 설정
   * 홈 화면으로 `MainScreen` 지정

3. **`MainScreen`**

   * `IndexedStack` + `BottomNavigationBar` 조합으로

     * 탭 0: `RequirementsScreen` (요구사항 입력/목록)
     * 탭 1: `CameraScreen` (카메라 뷰)
   * `onSettingsReceived` 콜백을 통해 요구사항 처리 후 받은 `CameraSettings`를 상태에 저장, 자동으로 카메라 탭으로 전환

---

## 2. `lib/camera_settings.dart`

카메라 설정 데이터를 모델링하고, API 호출 로직을 분리해 둔 서비스 파일입니다.

1. **`CameraSettings` 모델**

   * JSON 키(`SENSOR_SENSITIVITY`, `FLASH_MODE` 등) → Dart 객체 필드 매핑
   * `fromJson()` 팩토리 생성자로 서버 응답을 파싱

2. **`ApiService`**

   * `getCameraSettings(requirement)`

     * 실제 API 엔드포인트에 POST 요청
     * 성공 시 `CameraSettings` 객체 반환
   * `getMockCameraSettings(requirement)`

     * 개발·테스트용으로 2초 지연 후 요구사항 키워드별 하드코딩 응답

---

## 3. `lib/requirements_screen.dart`

사용자가 “어떤 사진을 찍고 싶은지” 요구사항을 입력하고, 리스트에서 선택·전송하는 UI를 구현합니다.

1. **`Requirement` 모델**

   * `id`, `title`, `description`, `createdAt` 필드

2. **`RequirementsScreen` 위젯**

   * 상태(`_reqs`, `_busy`, 텍스트 컨트롤러) 관리
   * **목록**

     * `_reqs`가 비어 있으면 안내 메시지
     * 채워져 있으면 `ListTile`로 요구사항 표시
   * **추가 다이얼로그** (`_showDialog`)

     * 제목·상세 입력 후 `Requirement` 객체 생성
   * **요구사항 처리** (`_runReq`)

     * `ApiService.getMockCameraSettings` 호출
     * 콜백으로 `MainScreen`에 설정 전달
     * 완료 시 SnackBar 알림

---

## 4. `lib/camera_screen.dart`

실제 카메라 프리뷰, 사진 촬영, 갤러리·풀스크린 뷰어를 구현합니다.

1. **`CameraScreen` 위젯**

   * `CameraController` 초기화 (`_initCam`)

     * 카메라 없으면 오류 메시지
     * 성공 시 `CameraPreview` 보여주고 `_applySettings` 호출
   * **설정 적용** (`_applySettings`)

     * `CameraSettings`의 `controlAeExposureCompensation`, `flashMode` 등을
       Flutter `CameraController` API(`setExposureOffset`, `setFlashMode`)로 적용
     * 성공·실패 시 SnackBar 알림
   * **촬영** (`_takePic`)

     * `takePicture()` 호출 후 파일 경로를 리스트에 저장
     * 화면 상단 아이콘으로 촬영된 사진 개수 표시

2. **`GalleryScreen`**

   * 그리드 형태로 저장된 이미지 목록 표시
   * 클릭 시 \*\*`FullScreenImage`\*\*로 네비게이트

3. **`FullScreenImage`**

   * 전체 화면으로 이미지를 보여주는 단순 뷰어

---

### 흐름 요약

1. 앱 시작 → 권한 요청 → 카메라 리스트 준비
2. 요구사항 탭에서 “밝게 찍고 싶다” 등 입력 → Mock API 호출 → `CameraSettings` 객체 수신
3. 카메라 탭으로 이동 → 프리뷰 초기화 → 받아온 설정(`ISO`, `노출 보정`, `플래시 모드`) 적용
4. 사진 촬영 → 갤러리 뷰 → 풀스크린 보기

이 구조를 토대로, 추가 기능(예: 실제 API 연동, 더 많은 설정 매핑, 에러 핸들링 강화 등)을 손쉽게 확장하실 수 있습니다!
