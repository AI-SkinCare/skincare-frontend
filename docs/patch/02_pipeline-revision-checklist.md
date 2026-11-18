# 개정 기획(2026-10-15) 앱 반영 브리핑 · 체크리스트

| 항목 | 내용 |
|------|------|
| 근거 | `docs/new_common/스킨케어_수행계획서_파이프라인개정_20261015` (이하 "개정안") |
| 대상 | iOS 앱 (`SkinCare/`) |
| 작성일 | 2026-10-17 (같은 날 백엔드 확정안 반영·앱 적용 완료) |
| 원칙 | 그대로 쓸 수 있는 것은 그대로 둔다. 질환명(분류 라벨)은 그대로 화면에 띄운다 (출시하지 않음, 팀 결정) |

---

## 1. 브리핑 — 무엇이 바뀌었나

### 1.1 서비스 정의

| | 기존 (v1.0, 10/01) | 개정안 (10/15) |
|---|---|---|
| 과제명 | 스마트폰 촬영 영상 기반 피부 상태 정량화 및 맞춤 성분 추천 | **스마트폰 피부 이미지 분류**와 맞춤 성분 추천 |
| 핵심 결과 | 수분·탄력·색소침착·모공 4개 지표(0–100), 종합 점수, 등급, 부위별(ROI 9개) | **6종 이미지 분류**: 건선·아토피·여드름·정상·주사·지루 + 성분·관리법 추천 |
| 제외 | 질환 진단, 네이티브 앱 | 4개 지표 회귀, ROI 분할, 촬영 환경 보정 (네이티브 앱 제외는 삭제 — Swift 앱이 공식 구성) |
| 표현 원칙 | 질환명 금지, "측정 결과" | 분류는 **참고 결과**, 확정 진단·처방으로 표현하지 않음. 안내문 "이미지 분류 참고 결과이며 의학적 진단이 아닙니다." |

### 1.2 시스템 구성

| | 기존 | 개정안 |
|---|---|---|
| 앱 | React 웹 → (패치로) Swift | **Swift iOS** (URLSession·Codable) — 계획서에 공식 반영 |
| 백엔드 | NestJS + TypeORM | **Spring Boot** REST + 서버 작업 큐 (DB는 PostgreSQL "사용안", 세부 미확정) |
| AI | FastAPI: 회귀 측정 + sLLM 추천 | FastAPI: **DenseNet121 분류(CPU)** + **Qwen2.5-7B + rec_sllm_v2 LoRA(GPU 4-bit)** |
| 흐름 | 측정은 요청 안에서, 추천은 큐 | **분류는 요청 안에서(목표 p95 3초), 추천은 큐**(생성 p95 120초 목표, 실측 중앙값 43초) — 2단계 구조는 동일 |
| 앱이 아는 서버 | 백엔드만 | 동일. AI 내부 토큰은 앱에 넣지 않음 |

### 1.3 API 계약 (개정안 부록 B — **백엔드와 합의 전 제안안**)

| | 기존 | 개정안 |
|---|---|---|
| 분석 접수 | `POST /api/v1/analyses` (image, survey, deviceType) → 202 `{analysisId, status, queuePosition, estimatedWaitSec}` | `POST /api/v1/analyses` (image, survey JSON 문자열) → 202 + **초기 결과 전체** `{analysisId, status, disease, recommendationStatus, recommendation, guidance, error}`. 즉시 보류 확정 시 200 + `WITHHELD` 가능 |
| 결과 조회 | `GET /api/v1/analyses/{id}` | 동일 경로, **접수 응답과 같은 형태** |
| 작업 상태 `status` | 소문자 `queued` · `recommending` · `done` · `failed` | **대문자** `QUEUED` · `GENERATING` · `COMPLETED` · **`WITHHELD`** · `FAILED` |
| 추천 상태 | `recommendation.status`: `pending`/`done`/`failed` | 최상위 **`recommendationStatus`**: `generated` · `uncertain` · `no_concern` (진행 중엔 `null`) |
| 측정 결과 | `measurement` {isDemo, overallScore, summary[4], byRoi[]} | **삭제** → `disease` {`label`(한글), `labelEn`, `confidence`(0–1), `uncertain`, `probabilities`(6종 한글 키)} |
| 추천 객체 | skinType·concerns가 `{code, label}` | AI 원본은 **한글 문자열** (`"건성"`, `["민감성(트러블/자극감)"]`). 백엔드가 코드로 바꿀지 **미정** |
| 추천 이유 | reasoning 정확히 3개 | 예시는 1개 — **개수 고정 아님**으로 취급 |
| 안내문 | 없음 (disclaimer만) | 최상위 **`guidance`** 배열 추가 |
| 대기 순번·예상 시간 | queuePosition, estimatedWaitSec | 개정안 예시에 **없음** (미정) |
| 이력 목록·삭제·추이 | `GET /analyses`, `DELETE`, `GET …/trend` | 개정안에 **없음** ("이력 관리"는 F6 기능으로만 언급) — 추이는 지표가 없어져 의미 없음 |
| 추천 재요청 | `POST …/recommendation/retry` | "허용된 재시도"만 언급, **경로 미정** |
| 서버 상태 | `GET /system/status` (aiAvailable) | 개정안에 **없음** (미정) |
| 인증 | `/auth/*` (쿠키 리프레시) + 패치 A2 제안 | 개정안에 **없음** ("사용자 인증"만 언급) — 기존 + A2 유지 |
| deviceType | 필수 | 개정안에 **없음** |

### 1.4 추천 생성 규칙 (앱은 결과만 표시, 규칙은 복제하지 않음)

- 분류 점수 **0.6 미만** 또는 `uncertain=true` → 추천 생성 안 함 → `WITHHELD` + `uncertain` → **재촬영·상담 안내**
- **정상** + 지원 고민 없음 → `WITHHELD` + `no_concern` → **설문에서 고민 선택 안내**
- 분류 → 고민 매핑(건선·아토피·지루 → 민감성 등)은 AI가 한다. 앱·백엔드에 복제 금지.
- 보류는 **오류가 아니다**. 빈 추천으로 대체하지 않는다.

### 1.5 설문

| 필드 | 기존 | 개정안 |
|---|---|---|
| gender | 필수 | 필수 (female/male) |
| 나이 | ageBand 필수 | **`age`(10–100 정수) 또는 `ageBand`** (권장) |
| skinType | 선택, 코드 | 권장, `dry/normal/oily/combination` |
| 고민 | `concerns` 코드 최대 3 | AI 기준 `selfReportedConcerns` (한글 라벨). 앱→백엔드 필드명·값은 **미정** |
| note | 300자 | 동일 |
| 수면·수분·자외선·스트레스·사용 제품 | 선택 | 개정안 표에 언급 없음 (기존 AI는 받았음) — **미정, 일단 유지** |

### 1.6 폴링 · 시간

| | 기존 | 개정안 |
|---|---|---|
| 간격 | 3분까지 3초, 이후 10초 | 동일 |
| 지연 안내 | 없음 | **150초 이후 지연 안내** |
| 중단 | 15분 | **최대 30분** |
| 종료 조건 | done·failed | **COMPLETED · WITHHELD · FAILED** |
| 앱 이탈 | — | 앱 종료·화면 이탈 ≠ 서버 작업 취소. 재진입 시 같은 ID로 재조회 (현재 구현과 일치) |

### 1.7 오류 코드

| 코드 | 기존 의미 | 개정안 |
|---|---|---|
| E2001 | 얼굴 미검출 | **아직 구현 안 됨** (처리 코드는 남겨둠) |
| E2002 | 품질 미달 | **디코딩 실패** 또는 요청 검증 실패(E4002와 함께) → 재촬영·입력 확인 |
| E2003 / E2004 | 10MB 초과 / 형식 | 동일 (10MiB, JPEG/PNG) |
| E3001 / E3003 | AI 없음 / 대기열 | 분류 비활성 / 대기열 초과 → 서버 준비·혼잡 안내 |
| E3002 | 타임아웃 | 동일. 중복 생성 방지 |
| 그 외 | — | 백엔드는 detail·토큰을 앱에 노출하지 않음 |

### 1.8 표시 규칙 (개정안 A.3)

- 분류 라벨은 **질환명 그대로** 표시 (팀 결정) + "참고 결과·진단 아님" 안내 상시 표시
- 점수 표시 시 0–1 → **백분율**, 반드시 **"모델 분류 점수"**로 표기 (질환 확률처럼 보이지 않게)
- ingredients 개수 가변, `purpose` null이면 성분명만
- routine.time: morning/evening/daily/weekly/anytime (기존과 동일)
- reasoning은 "생성된 설명" — 검증된 근거처럼 표시하지 않음
- filtered·usedFallback은 화면 비표시 (기존과 동일)

### 1.9 그대로 쓰는 것

로그인·가입·토큰(Keychain, single-flight 재발급), 촬영 가이드·내장 카메라·앨범, HEIC→JPEG 변환·메타데이터 제거, 설문 화면(구성 유지), 폴링 생명주기(화면·백그라운드), 추천 상세(성분·루틴·이유·가정), 디자인 시스템, 탭 구조, 마이페이지, 목 API 구조

### 1.10 일정 (개정안 4.2)

| 기간 | 내용 |
|---|---|
| 10/16–10/20 | **Swift·Spring DTO·상태 합의**, 중간 발표(10/20) |
| 10/21–11/9 | 작업 큐·**앱 화면**·입력 거부·관리 제약 보완 → 통합 시제품 |
| 11/10–11/24 | 실제 사진·반례·부하·재시도 검증 |
| 11/25–12/1 | 오류 수정·배포 점검 |

---

## 2. 백엔드(이현승)와 합의할 것

- [x] B1. 접수·조회 응답 DTO 최종 필드 (개정안 부록 B 그대로 갈지) → **확정**: `AnalysisView` 하나로 통일 (접수·재요청·조회 동일)
- [x] B2. `recommendation.skinType`·`concerns`를 한글 문자열로 줄지, 코드로 바꿔 줄지 → **확정**: `{code, label}` 객체 (기존과 같음)
- [x] B3. 설문 필드: `age` vs `ageBand`, 고민 필드명(`concerns` 코드 vs `selfReportedConcerns` 한글), 생활 습관 필드 유지 여부 → **확정**: 설문 기존 그대로 (`ageBand` 필수, `concerns` 코드 최대 3, 생활 습관 유지). `concerns`는 정상 분류일 때 추천 대상
- [x] B4. 이력 목록(`GET /analyses`)·삭제(`DELETE`) API 유지 여부와 목록 항목 필드 (label·status·createdAt 등) → **확정**: 목록·삭제 유지. 항목 `{analysisId, createdAt, status, recommendationStatus, disease, concerns}`
- [x] B5. 추천 재시도 API 경로 (`POST …/recommendation/retry` 유지?) → **확정**: `POST …/recommendation/retry` 유지, FAILED만, 응답 `AnalysisView`
- [x] B6. 대기 순번·예상 대기 시간 제공 여부 → **확정**: `queuePosition`·`estimatedWaitSec` QUEUED일 때만
- [x] B7. 서버 상태 API(`/system/status`) 유지 여부 → **확정**: `/system/status` 유지 (`checkedAt` nullable)
- [x] B8. 인증 API 경로와 패치 A2(리프레시 토큰 본문 전달) — 기존 제안 회신 → **확정**: 인증 그대로, **A2 반영됨** (iOS면 `refreshToken` 본문)
- [x] B9. `deviceType` 필드 폐지 확인 → **확정**: 삭제 (보내도 무시)

> 2026-10-16 백엔드가 `docs/new_common/api변경사항.md`로 전부 확정했다 (develop `bdce8da`). 이후 계약은 그 문서가 기준이다.

---

## 3. 앱 반영 체크리스트 (작업 순서)

### 3.1 모델 · 네트워킹

- [x] M1. `Disease` 모델 추가: `label`, `labelEn`, `confidence`, `uncertain`, `probabilities`([String: Double], 한글 키 6종), 표시 순서 고정(건선·아토피·여드름·정상·주사·지루)
- [x] M2. `AnalysisStatus`를 대문자 5종으로 교체 (`QUEUED`·`GENERATING`·`COMPLETED`·`WITHHELD`·`FAILED`), `isInProgress`·`isFinal` 갱신
- [x] M3. `RecommendationStatus`를 `generated`·`uncertain`·`no_concern`(nullable)로 교체, 최상위 필드로 이동
- [x] M4. `AnalysisDetail` 재구성: `disease`, `recommendationStatus`, `recommendation`(nullable), `guidance`, `error`, `createdAt`, `survey`(선택). `measurement` 제거
- [x] M5. `Recommendation`: `skinType`·`concerns`를 **코드 객체 또는 한글 문자열 둘 다** 받도록 디코딩 (B2 미정 대응)
- [x] M6. 접수 응답(`AnalysisSubmission`)을 상세와 같은 형태로 (202·200 모두 처리)
- [x] M7. `Measurement`·`MetricSummary`·`RoiMetrics`·`Metric`·`ROI`·`Grade`(점수 기반)·`TrendPoint`·`TrendDelta`·`Trend` 제거
- [x] M8. `AnalysisListItem`을 분류 기준으로 (`label`·`status`·`createdAt`, 나머지 선택) — B4 미정, 필드 없으면 숨김
- [x] M9. 업로드에서 `deviceType` 제거 (B9), 설문 인코딩은 기존 유지 (B3 확정 시 변경)
- [x] M10. `AnalysisAPI.trend` 제거, `retryRecommendation`·`list`·`delete`·`SystemAPI`는 유지 (B4·B5·B7 결과 반영)

### 3.2 폴링

- [x] P1. `PollingPolicy.timeout` 15분 → **30분**
- [x] P2. **150초 지연 안내** 기준 추가 (`delayNoticeAfter`)
- [x] P3. 종료 조건: `COMPLETED`·`WITHHELD`·`FAILED`

### 3.3 화면

- [x] S1. **결과 리포트(SCR-08) 재구성**
  - 상단: 분류 라벨(질환명, 크게) + "모델 분류 점수 NN%" + 상시 안내문(`guidance`, 없으면 기본 문구)
  - `uncertain=true`면 라벨 옆 "판단 보류" 표시
  - 6종 점수 막대(높은 순 또는 고정 순) — 라벨은 "모델 분류 점수"
  - 기존 점수 링·지표 타일·부위별 섹션 삭제
- [x] S2. **추천 영역 상태별 화면**
  - `QUEUED`·`GENERATING`: 진행 표시 (대기 순번은 값 있을 때만), 150초 지나면 지연 안내
  - `COMPLETED`+`generated`: 기존 요약 카드 재사용
  - `WITHHELD`+`uncertain`: 판단 보류 사유 + **다시 촬영** 버튼 + 상담 안내
  - `WITHHELD`+`no_concern`: 자동 추천할 고민 없음 + **설문에서 고민 선택 후 다시 분석** 버튼
  - `FAILED`: 오류 안내 + 재시도(B5 결과에 따라)
  - 30분 초과: "이력에서 나중에 확인" 안내
- [x] S3. 추천 상세(SCR-09): 피부 프로필 칩이 한글 문자열도 표시, reasoning **개수 가변**(3개일 때만 단계 제목, 아니면 번호만)
- [x] S4. **추이 비교(SCR-11) 삭제**: `TrendView`, 라우트, 리포트의 "이전 측정과 비교" 버튼
- [x] S5. 홈: 최근 결과 카드를 분류 라벨 + 상태로 (점수 링 제거), "이렇게 측정해요"(4지표) → **분석 흐름 안내**(촬영 → 분류 → 성분 추천) 또는 6종 안내로 교체, 시작 카드 문구 수정
- [x] S6. 이력: 행을 분류 라벨 + 상태(보류·실패 포함)로 (점수 링 제거), 빈 상태 문구에서 "변화를 비교" 제거
- [x] S7. 측정 중 오버레이: "피부 상태를 측정하고 있어요" → "사진을 분석하고 있어요"
- [x] S8. 로그인 부제: 4지표 문구 → 분류·추천 문구
- [x] S9. 가입 부제 "변화를 볼 수 있어요" → 기록 확인 문구
- [x] S10. 데모 값 배지·안내 제거 (`isDemo` 없어짐)

### 3.4 문구 · 상수

- [x] C1. `AppCopy`: `demoNotice`·`demoReportNotice` 삭제, 분류 안내문 추가 ("이미지 분류 참고 결과이며 의학적 진단이 아닙니다.")
- [x] C2. 질환명 그대로 표시 결정을 CLAUDE.md·패치 문서 문구 규칙에 반영
- [x] C3. (선택) "측정" → "분석" 용어 통일 — 그대로 둬도 무방, 시간 남으면

### 3.5 목 API · 테스트

- [x] T1. 목 서버를 개정 계약으로: 상태 5종, `disease`, `recommendationStatus` 3종, `guidance`. `-StartScreen`에 `report-withheld-uncertain`·`report-withheld-noconcern` 추가, 트렌드 제거
- [x] T2. 디코딩 테스트 fixture를 개정안 예시 JSON으로 교체 (부록 A.3·B.1), 한글 문자열 skinType/concerns 케이스 추가
- [x] T3. 폴링 테스트: 30분 중단, 150초 지연 안내
- [x] T4. 전체 화면 시뮬레이터 스크린샷 확인 (완료·대기·생성 중·보류 2종·실패, 홈·이력)

### 3.6 문서

- [x] D1. 패치 문서(`01_swift-ios-patch.md`): API·지표·화면 목록·폴링·테스트 케이스를 개정안 기준으로 갱신
- [x] D2. `design.md` App Additions: 분류 결과 헤더·점수 막대 컴포넌트 추가, 점수 링·등급 색 용도 정리
- [x] D3. README 기능·구조, CLAUDE.md 갱신
