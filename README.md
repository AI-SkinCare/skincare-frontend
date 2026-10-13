# skincare-frontend

피부 질환 및 타입 맞춤 AI 서비스의 프론트엔드(iOS 앱) 저장소입니다.

## 역할
사용자가 서비스를 이용하는 iOS 앱을 담당합니다. 피부 사진·영상 촬영 및 설문 입력, AI 진단 결과 및 맞춤 추천 결과를 사용자에게 보여주는 역할을 합니다.

## 주요 기능 (예정)
- 피부 사진·영상 촬영/업로드 및 설문 기반 정보 입력 화면
- 백엔드 API를 통한 진단 결과 조회 및 화면 표시
- 사용자별 피부 타입·질환 맞춤 추천 결과 제공

## 기술 스택
- Swift / SwiftUI (iOS 네이티브 앱)
- Xcode, Swift Package Manager

> 기획 문서(설계서·개발운영계획서)에는 프론트엔드가 React 기반으로 적혀 있으나, Swift 네이티브 앱으로 변경되었습니다. 앱에 맞게 바뀐 부분은 [iOS 패치 문서](docs/patch/01_swift-ios-patch.md)에 정리되어 있으며, 공통 문서보다 우선합니다.

## 실행

1. Xcode 26 이상에서 `SkinCare.xcodeproj` 열기
2. (실기기·TestFlight) `Config/Local.xcconfig.example`을 `Config/Local.xcconfig`로 복사하고 `DEVELOPMENT_TEAM` 입력
3. 백엔드를 로컬에서 `AI_MODE=fixture`로 실행 (`http://localhost:3000`)
4. `SkinCare` 스킴 + iPhone 시뮬레이터로 실행

- API 주소: Debug는 `http://localhost:3000/api/v1`, Release는 `Config/Release.xcconfig`의 `API_BASE_URL`
- 실기기에서 맥의 로컬 백엔드에 붙으려면 `Local.xcconfig`에 `API_BASE_URL = http:/$()/<맥 LAN IP>:3000/api/v1`
- 백엔드 없이 UI 확인 (Debug 전용): 스킴 Arguments에 `-MockAPI` 추가 → 목 응답으로 자동 로그인
  - `-StartScreen <이름>`으로 화면 바로 열기: `login` `signup` `home` `guide` `capture` `camera` `survey` `report-done` `report-queued` `report-recommending` `report-failed` `report-demo` `recommendation` `trend` `history` `mypage`
  - `-MockAIDown`(분석 서버 점검 중), `-MockEmpty`(이력 없음)
- 테스트: `xcodebuild test -project SkinCare.xcodeproj -scheme SkinCare -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`

## 구조

```
SkinCare/
├── App/            앱 진입점, 로그인 상태(SessionStore), 화면 이동(AppRouter), 설정·고정 문구
├── Core/           폴링 정책, 이미지 검증·변환, 날짜·문구 포맷
├── Networking/     APIClient(토큰 재발급 single-flight), 엔드포인트, Keychain
├── Models/         API 응답·요청 모델, 열거형
├── DesignSystem/   design.md 토큰(색·글꼴·간격·모서리)과 공통 컴포넌트
├── Features/       화면 (Auth, Home, Capture, Report, History, MyPage)
├── Debug/          Debug 전용 목 API·실행 옵션 (Release 빌드에서 제외)
└── Resources/      에셋, Pretendard 폰트(OFL)
SkinCareTests/      Swift Testing 단위 테스트
Config/             xcconfig, Info.plist
```

## 문서
- `docs/common/` — 공통 기획 문서 (각 docx / pdf)
  - `01_요구사항정의서_스킨케어` — 기능·비기능·모델 성능 요구사항
  - `02_설계서_스킨케어` — 시스템·API·데이터 설계
  - `03_화면설계서_스킨케어` — 화면 구성·흐름
  - `04_개발운영계획서_스킨케어` — 개발 일정, 환경, 배포·운영 계획
- `docs/patch/01_swift-ios-patch.md` — 공통 문서의 iOS 앱 수정 사항 (공통 문서보다 우선)
- `docs/design/design.md` — 디자인 시스템 (모든 UI의 기준)
- `docs/trouble_shooting/` — 문제 해결 기록 ([작성 가이드](docs/trouble_shooting/README.md))

## 관련 저장소
- [skincare-backend](https://github.com/AI-SkinCare/skincare-backend) — 백엔드
- [skincare-ai](https://github.com/AI-SkinCare/skincare-ai) — AI 모델 / 추론 서버

팀 소개 및 팀원 역할은 [AI-SkinCare 조직 프로필](https://github.com/AI-SkinCare)에서 확인해 주세요.
