# 스킨케어 Android

Android 9(API 28) 이상에서 얼굴 정면 사진 한 장과 설문을 Spring Boot에 보낸다. 전면 카메라는 셀프 촬영, 후면 카메라는 다른 사람이 촬영할 때 사용한다. 두 방법 모두 양쪽 볼이 보이는 정면 사진을 사용한다. 이번 앱에는 별도의 측면 분류 모드가 없다.

## 실행

Android Studio에서 이 디렉터리를 연다. Android SDK Platform 35, Android Build Tools 34.0.0, JDK 17 또는 21을 사용한다. Windows 빌드는 다음과 같다.

```powershell
.\gradlew.bat :app:assembleDebug
```

결과는 `app/build/outputs/apk/debug/app-debug.apk`에 생긴다. 에뮬레이터의 기본 Spring 주소는 `http://10.0.2.2:3000/api/v1`이다. 실제 휴대폰에서는 APK를 설치한 뒤 로그인 화면의 **서버 연결 설정**에 팀의 **Spring HTTPS 주소**를 입력한다. 주소는 `/api/v1`로 끝나야 한다. AI 서버와 내부 토큰은 Spring에서 설정한다. 운영용은 팀 인증서로 서명하고 배포 주소를 빌드에 지정한다.

```powershell
.\gradlew.bat :app:assembleRelease "-PspringBaseUrl=https://backend.example.org/api/v1"
```

백엔드는 `X-Client: android`를 허용하는 버전을 사용한다. 앱은 로그인과 갱신에서 토큰을 받고, 인증 정보를 세션 메모리에 둔다. 앱 프로세스가 종료되면 다시 로그인한다. 이력은 같은 계정으로 다시 조회할 수 있다.

## 멘토링 시연 순서

Android 15 에뮬레이터에서 가상 인물의 사진과 설문으로 실행한 화면이다. 이 사례는 모델 분류 점수가 낮아 추천이 보류됐다.

![정면 촬영, 선택 설문, 분류 결과와 추천 보류 화면](docs/analysis-flow.png)

1. 계정으로 로그인한다. 촬영 방법을 선택하거나 시스템 파일 선택기에서 사진 한 장을 고른다. 카메라는 앱 메모리에서 사진을 처리한다. 짧은 변 720px 미만, 거의 단색인 사진, 한 사람의 얼굴을 충분한 크기로 검출하지 못한 사진에는 재촬영 안내가 뜬다. 업로드용 JPEG에는 원본 위치 메타데이터를 복사하지 않는다.
2. 성별·연령대를 선택하고 피부 타입, 관리 고민(최대 3개), 회피 성분 등 필요한 설문을 입력한다. 최근 증상 여섯 항목은 이번 분석의 자가 응답으로만 저장한다. 현재 서비스에서 질환 분류기에 들어가는 입력은 사진이다.
3. 접수 뒤 분류 라벨·모델 점수를 먼저 보고 추천이 처리되는 동안 기다린다. Grad-CAM이 유효하면 참고 영역을 볼 수 있다. 추천이 생성되면 성분의 용도와 시간대별 루틴을 읽을 수 있다. 근거 카드·규칙 대체와 추천 보류는 서버 응답에 따라 표시한다.
4. **지난 분석 보기**에서 같은 결과를 다시 연다. 생성 실패 건은 **추천 다시 요청**을 사용할 수 있다.

## 연동 테스트

전·후면 가상 카메라가 모두 활성화된 API 35 에뮬레이터와 기본 주소의 **시험용** Spring DB를 사용한다. 테스트가 임시 계정을 만들고 정리한다. 시험은 시스템 선택기가 돌려주는 URI부터 사진 변환·한 사람 얼굴 확인·제출을 실행하며, 가상 카메라의 실제 JPEG 콜백도 전·후면 각각 확인한다.

```powershell
.\gradlew.bat :app:installDebug :app:installDebugAndroidTest
adb shell pm grant com.aiskincare.mobile.debug android.permission.CAMERA
adb shell am instrument -w com.aiskincare.mobile.debug.test/android.test.InstrumentationTestRunner
```

선택한 테스트 기기 한 대만 연결해서 실행한다. 가상 인물 사진 `app/src/androidTest/assets/fictional-frontal-face.jpg`는 ImageGen으로 생성한 연동 시험 전용 이미지다. 성별·연령·고민은 가상 설문이며 피부 질환 정답은 없다. 이 이미지는 테스트 APK에만 포함된다. 단색, 얼굴 없는 도형, 같은 얼굴 두 개를 나란히 놓은 입력은 거부 대상으로 검사한다. 실제 촬영 조건에서 얼굴 검출이 사용 가능한 사진까지 거부하는 비율은 별도 검증이 필요하다.
