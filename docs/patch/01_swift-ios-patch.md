# 공통 문서 iOS(Swift) 패치

| 항목 | 내용 |
|------|------|
| 대상 | `docs/common/` 01~04 (v1.0, 2026-10-01) |
| 작성 | 정도희 (프론트엔드) |
| 작성일 | 2026-10-10 |
| 상태 | 초안 — 팀 공유·합의 필요 항목은 §0에 별도 표시 |

> **2026-10-17 개정 반영**: 기획이 "피부 이미지 6종 분류 + 성분 추천"으로 바뀌었다 (`docs/new_common/`).
> 백엔드 계약은 `docs/new_common/api변경사항.md`가 기준이고, 변경점·체크리스트는 `02_pipeline-revision-checklist.md`에 있다.
> 이 문서의 4개 지표·종합 점수·부위별·추이·데모 값 관련 내용은 **폐기**됐다. iOS 적용 규칙(Keychain, HEIC, 카메라, 폴링 생명주기, 디자인, 배포)은 그대로 유효하다.

## 읽는 법

- 공통 문서는 프론트엔드를 **React 웹 SPA** 기준으로 작성했다. 프론트엔드는 **Swift(SwiftUI) iOS 네이티브 앱**으로 만든다.
- 이 문서는 공통 문서에서 **바꿔야 하는 부분만** 모은 패치다. 여기에 없는 내용(기능, API 계약, 에러 코드, 문구 규칙 등)은 개정 기획(`docs/new_common/`)과 공통 문서를 따른다.
- **공통 문서와 이 문서가 다르면 이 문서가 우선한다.**
- 형식: `원문` → `수정` / 이유.
- 문서 번호: 01 요구사항(SC-01) · 02 설계서(SC-02 시스템, SC-03 API, SC-04 DB) · 03 화면(SC-05) · 04 개발운영(SC-06 협업, SC-07 WBS, SC-08 테스트).

---

## 0. 팀 합의가 필요한 항목

혼자 결정할 수 없는 항목. 합의 전까지는 괄호 안 방식으로 개발한다.

| # | 항목 | 관련 | 상대 | 합의 전 임시 방식 |
|---|------|------|------|-------------------|
| A1 | ~~범위에서 "네이티브 앱 제외" 삭제, Android 미지원~~ **결정됨 (2026-10-10): iOS(Swift)로 개발. Android(Kotlin)는 iOS 완성 후 여유 있으면 검토** | 01 §1.3, NFR-CMP-01 | 전원 공유 | — |
| A2 | ~~모바일용 리프레시 토큰 전달 방식 (§3.1)~~ **반영됨 (2026-10-16): 백엔드가 `X-Client: ios`일 때 `refreshToken`을 본문으로 주고, refresh·logout 본문도 받음** | API §3.2·3.3, 설계 §8 | 백엔드 이현승 | — |
| A3 | design.md를 화면 디자인 기준으로 채택 (화면설계서 §5 대체) | 03 §5 | 김우주, 손승우 | design.md 기준 |
| A4 | (선택) 추천 완료 푸시 알림 | 신규 | 이현승 | 하지 않음 — 폴링만 |

---

## 1. 요구사항 정의서 (SC-01)

### §1.3 범위

- `제외: … 소셜 기능, 네이티브 앱`
- → `제외: … 소셜 기능, 웹 클라이언트, Android 앱(iOS 완성 후 여유 시 Kotlin으로 검토 — API는 그대로 재사용 가능, 백엔드는 A2만 공유)`
- 이유: 클라이언트를 iOS 네이티브 앱으로 변경. **[A1]**

### §1.4 사용자

- `일반 사용자: … 모바일 브라우저로 접속`
- → `일반 사용자: … iPhone에 앱을 설치해 사용 (배포: TestFlight)`

### FR-CAP-01 촬영 가이드

- `이후 "다시 보지 않기" 가능` — 저장 위치는 화면설계서에서 "브라우저 저장소"
- → `"다시 보지 않기"는 기기 로컬(UserDefaults)에 저장. 앱 삭제 시 초기화`

### FR-CAP-02 이미지 선택

- `카메라 촬영 또는 앨범 선택으로 이미지를 고른다. JPEG/PNG, 10MB 이하, 짧은 변 720px 이상만 허용한다`
- → `전면 카메라 촬영 또는 앨범 선택(PhotosPicker). 앨범의 HEIC 등 모든 형식은 앱에서 JPEG로 변환해 전송한다. 사전 검증은 "짧은 변 720px 이상"(원본 기준)과 "전송 파일 10MB 이하"(변환 후 기준)로 한다`
- 이유: iPhone 카메라·앨범 기본 형식은 **HEIC**라 "JPEG/PNG만 허용"을 그대로 적용하면 대부분의 앨범 사진이 거부된다. 서버 계약(JPEG/PNG, 10MB)은 바뀌지 않는다 — 앱이 변환해서 맞춘다.

### FR-AUTH-02 로그인 유지

- `리프레시 토큰(14일, httpOnly 쿠키)`
- → `리프레시 토큰(14일). 앱은 Keychain에 저장한다` **[A2]**
- 이유: §3.1 참고. httpOnly 쿠키는 브라우저 JS에서 토큰을 숨기기 위한 장치로, 네이티브 앱에서는 Keychain이 같은 역할을 한다.

### NFR-CMP-01 호환성

- `iOS Safari 16+, Android Chrome 최신 2개 버전, 데스크톱 Chrome. 화면 폭 360–430px 기준`
- → `iOS 17 이상 iPhone. 세로 모드 고정. 화면 폭 375–440pt (iPhone SE ~ Pro Max). iPad·Android·웹 미지원` **[A1]**
- 이유: iOS 17부터 Observation(`@Observable`)을 쓸 수 있어 상태 관리가 단순해진다. 2026년 기준 iOS 17 미만 점유율은 무시할 수준.

### NFR-SEC-01 HTTPS

- 그대로. 단, **Debug 빌드에서만** 로컬 백엔드(`http://localhost:8080`, `http://<맥 LAN IP>:8080`)용 ATS 예외를 둔다. Release 빌드에는 ATS 예외를 넣지 않는다.

### NFR-PRI-01 원본 이미지 미저장 — 앱 측 규칙 추가

- 원문은 백엔드·AI 서버만 다룸. 앱에도 같은 원칙을 적용한다:
  - 촬영 이미지는 **메모리에서만** 다루고, 앱 샌드박스(Documents, Caches, tmp)에 파일로 쓰지 않는다.
  - 촬영한 사진을 사진 앱(카메라 롤)에 저장하지 않는다.
  - 업로드 전 **EXIF 메타데이터(GPS 위치 포함)를 제거**한다 — JPEG로 다시 인코딩할 때 메타데이터를 넣지 않는다.
  - 업로드 완료(또는 실패) 후 이미지 참조를 해제한다.

### NFR-MNT-01 CI

- `CI(린트·테스트·빌드)` → 그대로. 도구만 §4.4로 변경.

### §6 요구사항 추적표

- 화면 ID(SCR-xx)는 그대로 쓴다. "경로" 대신 SwiftUI 화면(View) 이름으로 추적한다 (§3.4 표).

---

## 2. 화면 설계서 (SC-05)

### §1 화면 흐름 · 하단 탭

- `하단 탭(로그인 후 항상 표시): 홈 · 이력 · 마이. 촬영 흐름(SCR-04~07) 동안에는 탭을 숨기고 상단 "닫기"로 홈에 돌아갑니다.`
- → 그대로 유지. 구현: `TabView` 3개 탭 + 촬영 흐름은 `fullScreenCover`로 띄워서 탭을 자연스럽게 가린다. "닫기"는 cover dismiss.

### §2 화면 목록 · "경로" 열

- 웹 URL(`/login`, `/analyses/:id` …)은 쓰지 않는다. 화면 전환은 `NavigationStack` + 화면 enum으로 한다. 딥링크는 범위 밖.

| ID | 웹 경로 (삭제) | iOS 화면 | 표시 방식 |
|----|----------------|----------|-----------|
| SCR-01 | /login | `LoginView` | 비로그인 루트 |
| SCR-02 | /signup | `SignupView` | 로그인에서 push |
| SCR-03 | / | `HomeView` | 탭 1 |
| SCR-04 | /capture/guide | `CaptureGuideView` | 촬영 흐름 cover 첫 화면 |
| SCR-05 | /capture | `CaptureView` | 촬영 흐름 push |
| SCR-06 | /capture/survey | `SurveyView` | 촬영 흐름 push |
| SCR-07 | (오버레이) | `MeasuringOverlay` | SurveyView 위 전체 화면 오버레이 |
| SCR-08 | /analyses/:id | `ReportView` — 분류 참고 결과 + 6종 점수 + 추천(상태별) | cover 닫고 홈 탭에서 push |
| SCR-09 | /analyses/:id/recommendation | `RecommendationView` | ReportView에서 push |
| SCR-10 | /history | `HistoryView` | 탭 2 |
| ~~SCR-11~~ | ~~/analyses/:id/trend~~ | **삭제** (개정 기획: 지표 없음, 추이 API 삭제) | — |
| SCR-12 | /me | `MyPageView` | 탭 3 |

### SCR-04 촬영 가이드

- `"다음부터 보지 않기"는 브라우저 저장소에 기록합니다`
- → `UserDefaults(@AppStorage)에 기록`

### SCR-05 촬영·업로드

| 원문 | 수정 |
|------|------|
| `<input type="file" accept="image/jpeg,image/png" capture="user">` (전면 카메라) | **AVFoundation 커스텀 카메라** (전면 카메라, 얼굴 위치 가이드 오버레이). 화면 꺼짐 방지, 셔터 후 미리보기 |
| 앨범: 같은 input에서 capture 없이 | **PhotosPicker** (사진 1장, 이미지만). PhotosPicker는 사진 접근 권한 요청이 필요 없음 |
| 사전 검증: 형식(JPEG/PNG), 크기 10MB, 짧은 변 720px | 형식 검증 삭제(모두 JPEG로 변환). 짧은 변 720px(원본), 전송 크기 10MB(변환 후). 위반 시 미리보기 아래 문구 + 다음 버튼 비활성 — 동작은 동일 |
| 리사이즈: 긴 변 1600px, JPEG 0.9 | 그대로. 추가: **EXIF 방향(orientation) 반영 후** 리사이즈, 메타데이터 제거 |

- 권한: `NSCameraUsageDescription` 필요. 문구는 문구 규칙에 맞춘다 (현재: "피부 이미지 분석을 위해 얼굴 사진을 촬영해요. 사진은 분석에만 쓰고 저장하지 않아요.").
- 카메라 권한 거부 시: 설정 앱으로 이동 버튼 + 앨범 선택은 계속 가능.
- 시뮬레이터에는 카메라가 없으므로 개발 중에는 앨범 선택으로 테스트한다.

### SCR-07 분석 중

- 그대로. 업로드 중 앱이 백그라운드로 가도 요청이 끊기지 않게 짧은 백그라운드 작업(`beginBackgroundTask`)으로 감싼다.

### SCR-08 결과 리포트 · 폴링

- `폴링: status가 queued·recommending일 때 처음 3분은 3초, 이후 10초 간격. 15분이 지나면 폴링을 멈추고…` → **개정: QUEUED·GENERATING일 때 3분까지 3초, 이후 10초, 150초 후 지연 안내, 최대 30분** (API 변경사항 §1.4)
- → 간격·타임아웃 규칙은 그대로. 앱 규칙 추가:
  - 화면이 사라지면(`.task` 취소) 폴링 중단, 다시 나타나면 즉시 1회 조회 후 재개.
  - 앱이 백그라운드로 가면 폴링 중단, 포그라운드로 돌아오면 즉시 1회 조회 후 재개 (`scenePhase`).
  - 30분 타이머·150초 지연 안내는 **분석 제출 시각(createdAt) 기준**으로 계산한다 (화면 재진입마다 리셋되지 않게).
- 폴링 중 추천 완료 알림은 하지 않는다 (푸시는 **[A4]**).

### SCR-09 추천 상세

- `긴 문단은 3줄까지 보이고 "더 보기"` → 그대로 (`lineLimit(3)` + 토글).
- `면책 문구: 화면 맨 아래 고정 영역` → `safeAreaInset(edge: .bottom)`으로 고정. 접기·닫기 없음은 그대로.

### SCR-10 이력

- `20건 단위 무한 스크롤` → 그대로 (`List` 마지막 셀 등장 시 다음 페이지 로드).
- `카드의 ⋯ 메뉴 → 삭제 확인 다이얼로그` → `⋯` 메뉴 + **스와이프 삭제**도 지원. 둘 다 확인 다이얼로그를 거친다.

### SCR-12 마이페이지

- `개인정보 처리방침` → 앱 안에서 `SFSafariViewController`로 연다.
- 회원 탈퇴 후: Keychain 토큰 삭제, UserDefaults 초기화, 로그인 화면으로 이동.

### §4 문구 규칙

- 그대로. 추가: **권한 요청 문구(Info.plist), App Store/TestFlight 설명문**도 문구 규칙 적용 대상.

### §5 디자인 기준 — 전면 대체

**`docs/design/design.md`가 디자인 기준이다.** 화면설계서 §5는 아래와 같이 바뀐다. **[A3]**

| 항목 | 원문 | 수정 |
|------|------|------|
| 기준 폭 | 390px (360–430px), 데스크톱 가운데 480px 컬럼 | iPhone 375–440pt, safe area 준수. 데스크톱 컬럼 삭제 |
| 글꼴 | Pretendard (본문 15px, 보조 13px, 제목 20–24px) | **Pretendard 유지** (앱에 번들). design.md가 지정한 Saans는 상용·한글 미지원이고, design.md가 권장하는 대체 폰트 Inter와 Pretendard는 같은 계열(Pretendard 라틴 글리프 = Inter 기반)이라 둘 다 만족한다. 크기·굵기·행간은 design.md typography 표를 pt로 옮기고, 웹 히어로용 큰 크기(80/56/44px)는 쓰지 않는다. Dynamic Type 대응 |
| 간격 | 8px 배수 | design.md spacing 토큰 (4pt 반단계 포함) |
| 터치 영역 | 최소 44×44px | 44×44pt (동일) |
| 주 색상 | 청록 계열 1색 (버튼·링크·게이지) | **삭제.** 버튼·게이지는 ink `#141414`, accent 블루 `#0066ff`는 design.md 규칙대로 "결정이 필요한 강조"에만 사용 |
| ~~등급 색~~ | 양호·보통·관리 필요 | **폐기** — 개정 기획으로 등급 없음. 오류·삭제 표시용 `{colors.negative}`만 남김 |
| 대비 | 본문 명암비 4.5:1 | 그대로 |
| 대체 텍스트 | alt/aria-label | `accessibilityLabel` / `accessibilityValue` (얼굴 도식·게이지·막대 그래프) |
| 로딩 | 0.3초 이상 → 스켈레톤 또는 진행 표시 | 그대로. 스켈레톤은 `.redacted(reason: .placeholder)` |
| 다크 모드 | (없음) | 1차는 **라이트 모드 고정**. 토큰은 다크 대응 가능하게 Asset Catalog 색으로 정의 |

---

## 3. 설계서 (SC-02 시스템 · SC-03 API)

### 3.1 인증 토큰 — 모바일 방식 **[A2]**

원문 (시스템 설계 §5, §8 / API §3.2·3.3):

- `액세스 토큰은 메모리에만, 리프레시 토큰은 httpOnly 쿠키` / `Set-Cookie: refresh_token=…; HttpOnly; Secure; SameSite=Strict; Path=/api/v1/auth`

문제:

1. `httpOnly`·`SameSite`는 브라우저 보안 장치라 네이티브 앱에는 의미가 없다.
2. URLSession도 쿠키를 저장하긴 하지만 `Secure` 쿠키는 HTTP로 보내지지 않아 **로컬 개발(`http://localhost:8080`)에서 재발급이 항상 실패**한다.
3. 쿠키 저장소는 앱이 직접 제어하기 어렵고, 로그아웃·탈퇴 시 확실히 지웠는지 확인하기 어렵다.

수정 제안 (백엔드 변경 최소화):

| 항목 | 제안 |
|------|------|
| 식별 | 앱은 모든 요청에 `X-Client: ios` 헤더를 보낸다 |
| 로그인·재발급 응답 | `X-Client: ios`이면 응답 `data`에 `refreshToken` 필드를 추가로 내려준다 (쿠키는 보내도 무방) |
| 재발급 요청 | `POST /auth/refresh` 본문 `{ "refreshToken": "…" }` 허용 (쿠키 없을 때) |
| 로그아웃 요청 | `POST /auth/logout` 본문 `{ "refreshToken": "…" }` 허용 |
| 앱 저장 | 리프레시 토큰은 **Keychain** (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`), 액세스 토큰은 메모리(actor) |
| 교체·재사용 감지 | 백엔드 규칙 그대로 (재발급마다 새 토큰으로 교체) |

합의 전 임시: 쿠키 방식 그대로 구현하고, 로컬은 Cloudflare 임시 터널(HTTPS)로 백엔드에 붙는다.

### 3.2 시스템 설계 §2 전체 구성 · 프론트엔드

- `React 18, TypeScript, Vite, React Router, TanStack Query`
- → `Swift 6, SwiftUI, iOS 17+, URLSession(async/await), Swift Package Manager`
- `웹 서버 nginx: 빌드 결과 서빙, /api → 백엔드 프록시, 업로드 크기 제한(12MB)`
- → `nginx: /api → 백엔드 프록시, 업로드 크기 제한(12MB)` — 프론트 빌드 서빙 역할만 삭제. 앱은 `https://app.<도메인>/api/v1`을 직접 호출한다.

### 3.3 시스템 설계 §5 프론트엔드 설계 — 전면 대체

| 항목 | 원문 (React) | 수정 (iOS) |
|------|--------------|------------|
| 라우팅 | React Router | `TabView` + `NavigationStack` + 화면 enum, 촬영 흐름은 `fullScreenCover` (§2 표) |
| 서버 상태 | TanStack Query refetch | `@Observable` 화면 모델 + `async/await`. 폴링은 `Task` + `Task.sleep`, 규칙은 §2 SCR-08 |
| HTTP | axios 1개, withCredentials, 401 시 refresh single-flight | `APIClient` 1개 (URLSession). 401(E1001)이면 refresh 후 원 요청 1회 재시도. **single-flight는 actor로 구현** — 동시에 여러 401이 와도 refresh 요청은 하나만, 나머지는 그 결과를 기다림 (원문 이유 그대로 유효: 교체 방식이라 두 번 보내면 로그아웃됨) |
| 토큰 | 메모리 + httpOnly 쿠키, 앱 시작 시 /auth/refresh | 메모리 + Keychain (§3.1). 앱 시작 시 스플래시에서 Keychain 토큰으로 /auth/refresh → 성공 시 메인, 실패 시 로그인 |
| 로컬 개발 | Vite proxy /api → localhost:3000 | 프록시 없음. 시뮬레이터: `http://localhost:8080/api/v1`, 실기기: `http://<맥 LAN IP>:8080/api/v1` 또는 터널. xcconfig로 전환 (§4.2) |
| 타입 | openapi-typescript | 백엔드 Swagger 기준으로 `Codable` 모델 직접 작성 (화면 수가 적어 생성기 도입 비용이 더 큼). 필요 시 swift-openapi-generator 검토 |
| 이미지 | 캔버스 리사이즈 1600px, JPEG 0.9 | `UIGraphicsImageRenderer`(또는 ImageIO)로 리사이즈 1600px, JPEG 0.9, 메타데이터 제거 (§2 SCR-05) |
| 날짜 | (프론트가 KST 변환) | `ISO8601DateFormatter`로 파싱, 표시는 `TimeZone(identifier: "Asia/Seoul")` 고정 |

### 3.4 API 명세 (SC-03) — 앱 측 규칙

계약 자체는 바꾸지 않는다. 앱 구현 시 지킬 것:

| 항목 | 규칙 |
|------|------|
| Base URL | 빌드 설정(xcconfig)의 `API_BASE_URL` |
| X-Request-Id | 앱이 요청마다 UUID를 생성해 헤더로 보낸다. 공통 오류 문구의 "요청 ID 앞 8자리"는 응답 헤더 값을 쓴다 |
| ~~deviceType~~ | 개정으로 **삭제** — 보내지 않는다 |
| survey | multipart의 `survey` 필드는 JSON 문자열 (`JSONEncoder` → String) |
| Retry-After | 429(E4004) 응답의 `Retry-After`는 다이얼로그 문구에만 반영, 자동 재시도 안 함 |
| 빈 목록 | ingredients 0개, routine 0개, byRoi 빈 배열을 모두 처리 (원문 규칙 그대로) |
| 열거형 | 모르는 enum 값이 와도 디코딩이 실패하지 않게 `unknown` 케이스로 받는다 |
| CORS | 네이티브 앱은 Origin이 없으므로 무관. 백엔드 `CORS_ORIGIN`은 앱과 상관없음 |

### 3.5 시스템 설계 §8 보안 · 개인정보

| 원문 | 수정 |
|------|------|
| 토큰 탈취: 리프레시 httpOnly·Secure·SameSite=Strict 쿠키 | 앱: Keychain(이 기기 전용) 저장. 백엔드 측 해시 저장·교체 규칙은 그대로 |
| 로그 유출: 이미지·설문 원문·토큰 비기록 | 앱도 동일. `print`/`Logger`에 토큰·설문·이미지 데이터 출력 금지. Release 빌드에서 네트워크 디버그 로그 비활성 |
| (없음) | 앱 이미지 처리 규칙 — §1 NFR-PRI-01 추가분 |

---

## 4. 개발 운영 계획서 (SC-06 협업 · SC-07 WBS · SC-08 테스트)

### 4.1 협업 §1 저장소

- `skincare-frontend | 정도희 | 이현승 | React SPA`
- → `skincare-frontend | 정도희 | 이현승 | SwiftUI iOS 앱 (Xcode 프로젝트)`

### 4.2 협업 §7.2 프론트엔드 .env → xcconfig

- `.env` / `VITE_*` 삭제. Xcode 빌드 설정(xcconfig)으로 대체한다.

| 원문 변수 | 수정 |
|-----------|------|
| `VITE_API_BASE_URL=/api/v1` | `API_BASE_URL` — `Debug.xcconfig`: `http://localhost:8080/api/v1`, `Release.xcconfig`: `https://app.<도메인>/api/v1` |
| `VITE_POLL_INTERVAL_MS` 등 폴링 값 | 환경변수 아님 — 코드 상수 (`PollingPolicy`: 3초 / 3분 후 10초 / 150초 지연 안내 / 30분 중단) |

- 실기기 테스트용 개인 값(맥 LAN IP 등)은 `Local.xcconfig`에 두고 `.gitignore` 처리 (`*.local.xcconfig`).
- 비밀값은 앱에 넣지 않는다 (앱 바이너리는 누구나 열어볼 수 있음). AI 서버 토큰 등은 원래대로 백엔드에만.

### 4.3 협업 §6 코드 스타일

| 원문 | 수정 |
|------|------|
| frontend: ESLint + Prettier, printWidth 100, singleQuote | **SwiftLint + swift-format**, 줄 길이 120 |
| TS 파일: kebab-case (`analysis-detail.page.tsx`) | Swift 파일: 타입 이름과 동일한 UpperCamelCase (`ReportView.swift`, `APIClient.swift`) |
| JSON 필드 camelCase | 그대로. Swift 프로퍼티도 camelCase라 `CodingKeys` 변환 불필요 |

### 4.4 협업 §8 CI

- `frontend: npm ci → npm run lint → npm run test -- --run → npm run build`
- → `frontend (macos runner): swiftlint → xcodebuild build → xcodebuild test (iPhone 시뮬레이터)`
- GitHub Actions macOS runner는 Public 레포에서 무료.

### 4.5 협업 §9 로컬 실행

- 원문 `npm ci && npm run dev` 삭제 →
  1. Xcode(최신 안정판)에서 `.xcodeproj` 열기
  2. 백엔드를 개발 모드로 로컬 실행 (fixture 응답, API 변경사항 §1.5)
  3. Debug 스킴 + iPhone 시뮬레이터로 실행 → `localhost:8080`에 직접 연결
  4. 실기기: `Local.xcconfig`에 맥 LAN IP 지정, 맥과 같은 Wi-Fi
- 도구 표: `Node.js 20 LTS (프론트)` → `Xcode 최신 안정판, macOS`. (백엔드 개발용 Node는 그대로)

### 4.6 협업 §11 버전 · 릴리스

- 태그 규칙은 그대로. 추가: **각 태그 시점에 TestFlight 빌드를 올린다.** (Apple Developer 계정 보유 — 정도희)
  - 버전: 태그 `v0.1.0` → 앱 `CFBundleShortVersionString` 0.1.0, 빌드 번호는 업로드마다 증가.
  - 팀원·시연 기기는 TestFlight 내부 테스터로 등록.
- 시연 기기: TestFlight 빌드 사용. 내부 테스트 빌드는 90일 후 만료되므로 최종발표(12/9) 전에 새로 올린다.

### 4.7 WBS §2 · 프론트엔드 (5.x) · 인프라 (6.x)

| ID | 원문 | 수정 |
|----|------|------|
| 5.1 | Vite·라우팅·Query·ESLint·CI 셋업 | Xcode 프로젝트·탭/내비게이션 골격·APIClient·디자인 토큰·SwiftLint·CI 셋업 |
| 5.3 | 촬영 가이드·촬영·설문·분석 중 | 동일 + 커스텀 카메라·HEIC 변환·이미지 리사이즈 |
| 5.7 | E2E 테스트 (Playwright) | UI 테스트 (XCUITest) |
| 5.8 (신규) | — | TestFlight 배포 (v0.1.0 10/18, v0.2.0 11/24, v1.0.0 12/8) |
| 6.1 | 자택 서버 Docker Compose + Cloudflare Tunnel 배포 | 동일. 단 web(nginx) 컨테이너는 프론트 서빙 없이 `/api` 프록시 역할만 |

- 일정 메모: 5.1은 원래 10/5까지였으나 스택 변경으로 지연. M2(10/12, fixture 모드로 가입→결과 화면)는 목표 유지하되 결과 화면은 정적 표시까지를 1차 목표로 한다.

### 4.8 테스트 계획 (SC-08)

| 원문 | 수정 |
|------|------|
| 단위: Vitest(FE) | **Swift Testing** (XCTest 병행 가능) — 화면 모델, APIClient(URLProtocol 목), 폴링 정책, 이미지 검증·리사이즈 |
| E2E: Playwright (모바일 뷰포트 390×844) | **XCUITest**, iPhone 16 시뮬레이터 + 실기기 1회 (발표 전) |
| E2E 실행 환경 | 백엔드 개발 모드, 시나리오 헤더 `X-Fixture-Scenario`는 앱 Debug 실행 인자 `-FixtureScenario <값>`으로 주입 (구현됨) |
| TC-E2E-01~03 | 시나리오 그대로. 사진 선택은 시뮬레이터 사진 보관함에 테스트 이미지를 미리 넣어 PhotosPicker로 선택 |

추가 테스트 케이스 (앱 전용):

| ID | 요구사항 | 절차 | 기대 결과 |
|----|----------|------|-----------|
| TC-IOS-01 | FR-CAP-02 | 앨범에서 HEIC 사진 선택 | JPEG로 변환되어 업로드 성공 |
| TC-IOS-02 | NFR-PRI-01 | 촬영·분석 후 앱 컨테이너(Documents/Caches/tmp)와 사진 앱 확인 | 이미지 파일 0건 |
| TC-IOS-03 | NFR-PRI-01 | 업로드 요청 본문 JPEG의 EXIF 확인 | GPS·기기 메타데이터 없음 |
| TC-IOS-04 | FR-ANA-03 | 추천 대기 중 앱을 백그라운드 → 1분 후 복귀 | 즉시 최신 상태 반영, 폴링 재개 |
| TC-IOS-05 | FR-AUTH-02 | 동시에 API 3개 호출 중 액세스 토큰 만료 | refresh 요청 1회, 3개 모두 성공 |
| TC-IOS-06 | FR-AUTH-02 | 앱 완전 종료 후 재실행 | 재로그인 없이 홈 진입 |
| TC-IOS-07 | — | 카메라 권한 거부 상태에서 촬영 화면 진입 | 설정 이동 안내 + 앨범 선택 가능 |
