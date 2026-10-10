# CLAUDE.md

## 프로젝트

스마트폰 촬영 영상 기반 피부 상태 정량화 및 맞춤 성분 추천 AI 서비스의 **프론트엔드**.

**이 저장소는 Swift iOS 앱 프로젝트다.** (Swift / SwiftUI)

- `docs/` 안의 문서를 토대로 제작한다.
- 공통 기획 문서(`docs/common/`)는 프론트엔드를 React 웹 기준으로 작성했다. **iOS용 수정 사항은 `docs/patch/01_swift-ios-patch.md`에 정리돼 있고, 공통 문서와 다르면 패치 문서가 우선한다.**
- 우선순위: `docs/patch/` > `docs/design/design.md`(디자인) > `docs/common/`.
- 패치 §0의 "팀 합의 필요" 항목(A1~A4)은 합의 전 임시 방식으로 개발한다. 합의 결과가 나오면 패치 문서를 갱신한다.
- 공통 문서에서 앱에 맞지 않는 내용(브라우저 저장소, 쿠키, URL 경로 등)을 새로 발견하면 패치 문서에 항목을 추가한 뒤 구현한다.

## 디자인

- **모든 UI는 `docs/design/design.md`를 기준으로 일관성 있게 만든다.** 색상·타이포·간격·radius·컴포넌트 규칙을 임의로 바꾸지 않는다.
- 핵심: 모노크롬(ink `#141414` on white), accent 블루 `#0066ff`는 결정/강조 신호에만, 인터랙티브 요소는 pill(full radius), 그림자 대신 neutral tint + 1px hairline.
- design.md의 토큰(`{colors.*}`, `{typography.*}`, `{rounded.*}`)은 Swift에서 디자인 토큰(Color/Font/CGFloat 상수)으로 한 곳에 정의해 재사용한다. 화면 코드에 hex·숫자 하드코딩 금지.
- 웹 기준 수치(px, breakpoint)는 iOS(pt, Dynamic Type, safe area)에 맞게 옮긴다.

## 문서 위치

| 경로 | 내용 |
|------|------|
| `docs/common/01_요구사항정의서_스킨케어.docx` / `.pdf` | 기능·비기능·모델 성능 요구사항, 추적표 |
| `docs/common/02_설계서_스킨케어.docx` / `.pdf` | 시스템·API·데이터 설계 (FE 부분은 패치 문서 §3 참고) |
| `docs/common/03_화면설계서_스킨케어.docx` / `.pdf` | 화면 구성·흐름 |
| `docs/common/04_개발운영계획서_스킨케어.docx` / `.pdf` | 개발 일정, 환경, 배포·운영 계획 (FE 부분은 패치 문서 §4 참고) |
| `docs/patch/01_swift-ios-patch.md` | 공통 문서 iOS(Swift) 패치 — 공통 문서보다 우선. 팀 합의 필요 항목(§0) 포함 |
| `docs/design/design.md` | 디자인 시스템 (색상, 타이포, 레이아웃, 컴포넌트, Do/Don't) |
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
