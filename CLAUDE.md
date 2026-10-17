# CLAUDE.md

## 프로젝트

스마트폰 피부 이미지 분류와 맞춤 성분 추천 AI 서비스의 **프론트엔드** (2026-10-15 개정. 기존 과제명: 스마트폰 촬영 영상 기반 피부 상태 정량화 및 맞춤 성분 추천).

**이 저장소는 Swift iOS 앱 프로젝트다.** (Swift / SwiftUI)

- `docs/` 안의 문서를 토대로 제작한다.

### ⚠️ 기획 변경 (2026-10-15 개정 수행계획서)

`docs/new_common/스킨케어_수행계획서_파이프라인개정_20261015`가 **최신 기획**이다. 기존 `docs/common/`(v1.0, 10/01)과 다르면 개정 계획서가 우선한다.

- **파이프라인**: Swift iOS 앱 → **Spring Boot**(기존 NestJS 아님) → FastAPI **DenseNet121 이미지 분류**(6종: 건선·아토피·여드름·정상·주사·지루) → **Qwen2.5 성분 추천**. 프론트가 Swift 앱인 것은 계획서에 공식 반영됨.
- **제외된 기능**: 수분·탄력·색소침착·모공 4개 지표 회귀, 9개 ROI 분할, 촬영 환경 보정, 종합 점수·등급. → 기존 결과 리포트·추이 비교·이력 카드의 점수 표시는 새 기획에 맞게 다시 만들어야 한다.
- **API 계약 (백엔드 확정, `docs/new_common/api변경사항.md`가 기준)**: `POST /api/v1/analyses`(image + survey JSON) → `GET /api/v1/analyses/{id}` 조회. 응답은 모두 `AnalysisView`. 이력·삭제·재요청·시스템 상태 API 유지, 추이 API 삭제, `deviceType` 삭제. 리프레시 토큰 본문 전달(패치 A2) 반영됨.
  - 작업 상태 `status`: `QUEUED` · `GENERATING` · `COMPLETED` · `WITHHELD`(추천 보류) · `FAILED`
  - AI 결과 `recommendationStatus`: `generated` · `uncertain`(분류 점수 0.6 미만 등 → 재촬영·상담 안내) · `no_concern`(정상 + 고민 없음 → 설문 선택 안내)
  - `disease`: `label`, `labelEn`, `confidence`, `uncertain`, `probabilities`(6종). 점수를 보여줄 때는 반드시 **"모델 분류 점수"**로 표기하고 질환 확률처럼 보이게 하지 않는다.
  - 추천 객체 구조(skinType·concerns `{code,label}`, ingredients·routine·reasoning·answer·disclaimer)는 기존과 같음. `guidance` 안내 문장 상시 표시. 보류는 오류가 아니며 빈 추천으로 대체하지 않는다.
- **폴링**: 처음 3분 3초, 이후 10초, **150초 이후 지연 안내, 최대 30분**(기존 15분).
- **설문**: 기존 그대로 (`gender`·`ageBand` 필수, `concerns` 코드 최대 3 — 정상으로 분류되면 추천 대상).
- **문구**: 분류 라벨(질환명)은 **그대로 화면에 띄운다** (팀 결정, 출시하지 않음). 대신 "이미지 분류 참고 결과이며 의학적 진단이 아닙니다." 안내를 상시 표시하고, 점수는 "모델 분류 점수"로만 표기한다.
- 앱 반영 완료 (2026-10-17, 체크리스트 `docs/patch/02_pipeline-revision-checklist.md`). `docs/patch/01_swift-ios-patch.md`의 iOS 전용 규칙은 유효하고, 지표·추이·데모 관련 부분은 폐기.

### 문서 우선순위

`docs/new_common/`(개정 기획 + 백엔드 API 변경사항) > `docs/patch/`(iOS 적용) > `docs/design/design.md`(디자인) > `docs/common/`(v1.0, 일부 폐기).

- 기존 공통 기획 문서(`docs/common/`)는 프론트엔드를 React 웹 기준으로 작성했다. iOS용 수정 사항은 `docs/patch/01_swift-ios-patch.md`에 정리돼 있다.
- 패치 §0의 "팀 합의 필요" 항목(A1~A4)은 합의 전 임시 방식으로 개발한다. 합의 결과가 나오면 패치 문서를 갱신한다.
- 공통 문서에서 앱에 맞지 않는 내용(브라우저 저장소, 쿠키, URL 경로 등)을 새로 발견하면 패치 문서에 항목을 추가한 뒤 구현한다.

## 디자인

- **모든 UI는 `docs/design/design.md`를 기준으로 일관성 있게 만든다.** 색상·타이포·간격·radius·컴포넌트 규칙을 임의로 바꾸지 않는다.
- 핵심: 모노크롬(ink `#141414` on white), accent 블루 `#0066ff`는 결정/강조 신호에만, 인터랙티브 요소는 pill(full radius), 그림자 대신 neutral tint + 1px hairline.
- design.md의 토큰(`{colors.*}`, `{typography.*}`, `{rounded.*}`)은 Swift에서 디자인 토큰(Color/Font/CGFloat 상수)으로 한 곳에 정의해 재사용한다. 화면 코드에 hex·숫자 하드코딩 금지.
- 웹 기준 수치(px, breakpoint)는 iOS(pt, Dynamic Type, safe area)에 맞게 옮긴다.

## 코드

- Xcode 프로젝트 `SkinCare.xcodeproj` (폴더 동기화 방식 — `SkinCare/`, `SkinCareTests/` 안에 파일을 추가하면 자동 포함, pbxproj 수정 불필요). iOS 17+, Swift 6, SwiftUI.
- 구조는 README "구조" 참고. 디자인 토큰: `SkinCare/DesignSystem/`, API: `SkinCare/Networking/Endpoints.swift`, 고정 문구: `SkinCare/App/AppCopy.swift`.
- 빌드 설정: `Config/*.xcconfig` (API 주소 등). 개인 값은 `Config/Local.xcconfig`(커밋 안 됨).
- 백엔드 없이 화면 확인: Debug 실행 인자 `-MockAPI -StartScreen <이름>` (README "실행" 참고). UI를 바꾸면 시뮬레이터 스크린샷으로 확인한다.
- 빌드·테스트: `xcodebuild test -project SkinCare.xcodeproj -scheme SkinCare -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'`
- 화면 모델은 `@MainActor @Observable`, API 모델은 `Sendable`. 서버 열거형은 `UnknownCaseDecodable`로 모르는 값을 `unknown`으로 받는다.
- 화면 문구는 화면 설계서 §4 문구 규칙(진단·치료 표현 금지)을 지킨다. 분류 라벨(질환명)은 그대로 표시하되 "참고 결과·진단 아님" 안내와 함께 쓴다. 고민 표기는 `Concern.displayLabel`만 쓰고 서버 label은 화면에 쓰지 않는다.
- 브랜치: `develop`에서 `feat/`·`fix/`·`chore/` 분기 (협업 규칙 §2). 커밋 메시지는 `<타입>: <한국어 요약>`.

## 문서 위치

| 경로 | 내용 |
|------|------|
| `docs/new_common/api변경사항.md` | **백엔드 API 계약 기준** (백엔드 제공, develop `bdce8da`) — 전체 API·변경점·앱 할 일 |
| `docs/new_common/스킨케어_수행계획서_파이프라인개정_20261015.docx` / `.pdf` | **최신 기획** — 이미지 분류(DenseNet121) + 성분 추천(Qwen2.5) 파이프라인 개정안, Spring Boot·Swift 연동 계약안(부록 A·B) |
| `docs/common/01_요구사항정의서_스킨케어.docx` / `.pdf` | (v1.0, 개정으로 일부 폐기) 기능·비기능·모델 성능 요구사항, 추적표 |
| `docs/common/02_설계서_스킨케어.docx` / `.pdf` | 시스템·API·데이터 설계 (FE 부분은 패치 문서 §3 참고) |
| `docs/common/03_화면설계서_스킨케어.docx` / `.pdf` | 화면 구성·흐름 |
| `docs/common/04_개발운영계획서_스킨케어.docx` / `.pdf` | 개발 일정, 환경, 배포·운영 계획 (FE 부분은 패치 문서 §4 참고) |
| `docs/patch/02_pipeline-revision-checklist.md` | 개정 기획 변경점 브리핑, 백엔드 합의 항목(B1–B9), 앱 반영 체크리스트 — 작업 시 체크 갱신 |
| `docs/patch/01_swift-ios-patch.md` | 공통 문서 iOS(Swift) 패치 — 공통 문서보다 우선. 팀 합의 필요 항목(§0) 포함 |
| `docs/design/design.md` | 디자인 시스템 (색상, 타이포, 레이아웃, 컴포넌트, Do/Don't) |
| `docs/design/skincare_icon_transparent.png`, `.ico` | 앱 아이콘 원본. iOS용(불투명·정사각 1024)은 `SkinCare/Resources/Assets.xcassets/AppIcon.appiconset/` — 원본을 바꾸면 다시 변환 필요 |
| `docs/trouble_shooting/` | 문제 해결 기록. 규칙: `README.md`, 양식: `TEMPLATE.md`, 목록: `INDEX.md` |
| `private/` | 개인 자료. `.gitignore` 처리됨 — 커밋 금지 |

공통 문서 원본은 `skincare-ai/docs/project/` (Markdown). docx 내용 읽기: `textutil -convert txt -stdout <파일>.docx`

**문서 위치·폴더 구조가 바뀌거나 새 문서가 추가되면 반드시 이 CLAUDE.md(위 표)를 즉시 갱신한다.**

## Trouble Shooting

- 개발 중 실제 문제(빌드 실패, 환경/설정, API 연동, 크래시 등)가 생기면 해결 후 **항상** `docs/trouble_shooting/`에 기록한다. 작성 규칙은 `docs/trouble_shooting/README.md`.
- 단순 오타·경로 실수는 기록하지 않는다.
- 도구 실패 시 `.claude/settings.json`의 `PostToolUseFailure` 훅(`.claude/hooks/troubleshoot-reminder.sh`)이 기록을 상기시킨다.

## 관련 저장소

- [skincare-backend](https://github.com/AI-SkinCare/skincare-backend) — 백엔드 (API 서버, `/api/v1`)
- [skincare-ai](https://github.com/AI-SkinCare/skincare-ai) — AI 모델 / 추론 서버
