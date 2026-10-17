# skincare-frontend

스마트폰 피부 이미지 분류와 맞춤 성분 추천 AI 서비스의 프론트엔드(iOS 앱) 저장소입니다.

## 역할
사용자가 서비스를 이용하는 iOS 앱을 담당합니다. 얼굴 사진 촬영과 설문을 받아 백엔드로 보내고, 이미지 분류 참고 결과와 맞춤 성분·관리법 추천, 분석 이력을 보여줍니다.

## 주요 기능
- 얼굴 타원 가이드가 있는 내장 카메라 촬영 / 앨범 선택 (HEIC → JPEG 변환, 메타데이터 제거)
- 설문 입력 (직전 분석 설문으로 기본값)
- 6종 이미지 분류 참고 결과 (건선·아토피·여드름·정상·주사·지루, 모델 분류 점수)
- 성분·관리 루틴·추천 이유 표시, 추천 보류(불확실·고민 없음)·실패·재요청 처리
- 분석 이력 (목록·삭제), 로그인·회원가입·탈퇴

## 기술 스택
- Swift / SwiftUI (iOS 네이티브 앱)
- Xcode, Swift Package Manager

> 기존 기획 문서(v1.0)에는 프론트엔드가 React 기반으로 적혀 있으나, Swift 네이티브 앱으로 변경되었고 개정 수행계획서(2026-10-15)에 반영되었습니다. 앱에 맞게 바뀐 부분은 [iOS 패치 문서](docs/patch/01_swift-ios-patch.md)에 정리되어 있으며, 공통 문서보다 우선합니다.

## 실행

1. Xcode 26 이상에서 `SkinCare.xcodeproj` 열기
2. (실기기·TestFlight) `Config/Local.xcconfig.example`을 `Config/Local.xcconfig`로 복사하고 `DEVELOPMENT_TEAM` 입력
3. 백엔드를 로컬에서 `AI_MODE=fixture`로 실행 (`http://localhost:3000`)
4. `SkinCare` 스킴 + iPhone 시뮬레이터로 실행

- API 주소: Debug는 `http://localhost:3000/api/v1`, Release는 `Config/Release.xcconfig`의 `API_BASE_URL`
- 실기기에서 맥의 로컬 백엔드에 붙으려면 `Local.xcconfig`에 `API_BASE_URL = http:/$()/<맥 LAN IP>:3000/api/v1`
- 백엔드 없이 UI 확인 (Debug 전용): 스킴 Arguments에 `-MockAPI` 추가 → 목 응답으로 자동 로그인
  - `-StartScreen <이름>`으로 화면 바로 열기: `login` `signup` `home` `guide` `capture` `camera` `survey` `report-completed` `report-queued` `report-generating` `report-uncertain` `report-no-concern` `report-failed` `recommendation` `history` `mypage`
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
- `docs/new_common/` — **최신 기획** (개정 수행계획서 2026-10-15, 백엔드 API 변경사항)
- `docs/common/` — 기존 공통 기획 문서 v1.0 (각 docx / pdf, 개정으로 일부 폐기)
  - `01_요구사항정의서_스킨케어` — 기능·비기능·모델 성능 요구사항
  - `02_설계서_스킨케어` — 시스템·API·데이터 설계
  - `03_화면설계서_스킨케어` — 화면 구성·흐름
  - `04_개발운영계획서_스킨케어` — 개발 일정, 환경, 배포·운영 계획
- `docs/patch/01_swift-ios-patch.md` — 공통 문서의 iOS 앱 수정 사항
- `docs/patch/02_pipeline-revision-checklist.md` — 개정 기획 변경점·앱 반영 체크리스트
- `docs/design/design.md` — 디자인 시스템 (모든 UI의 기준)
- `docs/trouble_shooting/` — 문제 해결 기록 ([작성 가이드](docs/trouble_shooting/README.md))

## 관련 저장소
- [skincare-backend](https://github.com/AI-SkinCare/skincare-backend) — 백엔드
- [skincare-ai](https://github.com/AI-SkinCare/skincare-ai) — AI 모델 / 추론 서버

팀 소개 및 팀원 역할은 [AI-SkinCare 조직 프로필](https://github.com/AI-SkinCare)에서 확인해 주세요.
