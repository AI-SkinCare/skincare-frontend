# API 변경사항

백엔드 API(`/api/v1`)를 한곳에서 확인하는 문서입니다. **1절은 현재 API 전체**, **2절은 이전과 달라진 점**, **3절은 앱에서 할 일**입니다.

- 현재 기준: 2026-10-16, `develop` `bdce8da` (개정 수행계획서 2026-10-15 반영)
- 실제 동작 기준: Swagger `/api/docs` (JSON `/api/docs-json`)
- 상세 규칙: [TRD](TRD.md) §7·§9–§14, 앱 연동 규칙: [ios-integration.md](ios-integration.md)
- 팀 공식 명세 SC-03(`skincare-ai/docs/project/03-api-spec.md`)은 아직 이번 변경 전 내용입니다
- 다음에 API가 바뀌면 1절을 고치고, 2절 맨 위에 날짜별로 변경 내용을 추가합니다

---

## 1. 현재 API 전체 목록

### 1.1 목록

경로 앞에는 모두 `/api/v1`이 붙습니다. 맨 오른쪽 열은 이전(2026-10-13 버전)과 비교한 결과입니다.

| # | 메서드 | 경로 | 인증 | 성공 | 설명 | 이전 대비 |
|---|---|---|---|---|---|---|
| 1 | POST | `/auth/signup` | 없음 | 201 | 회원가입 (동의 4종 필수) | 같음 |
| 2 | POST | `/auth/login` | 없음 | 200 | 로그인 | 같음 |
| 3 | POST | `/auth/refresh` | 없음 | 200 | 토큰 재발급 (리프레시 토큰 교체) | 같음 |
| 4 | POST | `/auth/logout` | 필요 | 204 | 로그아웃 (리프레시 토큰 폐기) | 같음 |
| 5 | GET | `/users/me` | 필요 | 200 | 내 정보 | 같음 |
| 6 | DELETE | `/users/me` | 필요 | 204 | 탈퇴 (모든 데이터 즉시 삭제) | 같음 |
| 7 | POST | `/analyses` | 필요 | 202 | 사진 + 설문 제출 → 이미지 분류 → 추천 대기열 등록 | **변경** |
| 8 | GET | `/analyses` | 필요 | 200 | 이력 목록 (최신순) | **변경** |
| 9 | GET | `/analyses/{id}` | 필요 | 200 | 결과·진행 상태 (분류 + 추천 또는 보류) | **변경** |
| 10 | POST | `/analyses/{id}/recommendation/retry` | 필요 | 202 | 실패한 추천 재요청 | **변경** |
| 11 | DELETE | `/analyses/{id}` | 필요 | 204 | 이력 삭제 | 같음 |
| 12 | GET | `/system/status` | 없음 | 200 | AI 가용 여부·대기열 상태 | 같음 |
| — | GET | ~~`/analyses/{id}/trend`~~ | — | — | 직전 분석 대비 변화 | **삭제** |

### 1.2 공통 규칙

| 항목 | 내용 |
|---|---|
| 헤더 | `Authorization: Bearer <accessToken>`(인증 필요 API), `X-Client: ios`(모든 요청), `X-Request-Id`(권장) |
| 성공 응답 | `{ "success": true, "data": … }`. 204는 본문 없음 |
| 실패 응답 | `{ "success": false, "error": { "code", "message", "detail" } }`. `message`는 화면에 그대로 표시 |
| 인증 오류 | 인증 필요 API는 공통으로 401 E1001(토큰 없음·만료·위조) → refresh 후 1회 재시도 |
| 시간 | UTC ISO 8601, 밀리초 없음 (`2026-10-16T09:12:33Z`) |
| 열거형 | 소문자 snake_case. **분석 `status`만 대문자** |

### 1.3 API별 요청·응답

#### 1) `POST /auth/signup`
- 요청: `{ email, password, nickname, agreements: { terms, privacy, imageProcessing, over14 } }` — 동의 4개 모두 `true`
- 응답 201: `{ userId }`
- 오류: 422 E4002(검증 실패·동의 누락), 409 E1004(이미 가입된 이메일)

#### 2) `POST /auth/login`
- 요청: `{ email, password }`
- 응답 200: `{ accessToken, expiresIn: 3600, refreshToken, user: { id, email, nickname } }`. `refreshToken`은 `X-Client: ios`일 때만 있고, 쿠키 `refresh_token`도 함께 내려갑니다
- 오류: 401 E1003(이메일·비밀번호 불일치), 429 E4004(IP당 분당 10회 초과), 422 E4002

#### 3) `POST /auth/refresh`
- 요청: 쿠키 `refresh_token`, 없으면 본문 `{ refreshToken }`
- 응답 200: 로그인과 같은 형태(새 토큰). 이전 리프레시 토큰은 폐기됩니다
- 오류: 401 E1001(없음·만료·폐기·재사용 — 재사용이면 그 사용자 토큰 전부 폐기)

#### 4) `POST /auth/logout`
- 요청: 쿠키 또는 본문 `{ refreshToken }`
- 응답 204

#### 5) `GET /users/me`
- 응답 200: `{ id, email, nickname, createdAt, analysisCount }`

#### 6) `DELETE /users/me`
- 응답 204. 분석·설문·추천·토큰까지 즉시 삭제

#### 7) `POST /analyses` — multipart/form-data
- 요청
  - `image`: 파일, JPEG/PNG, 10MB 이하, 짧은 변 720px 이상
  - `survey`: JSON **문자열**, 구조는 아래
- `survey`
  ```json
  { "gender": "female", "ageBand": "20s", "skinType": "combination", "sleepHours": 6,
    "waterIntakeLevel": "low", "sunExposureLevel": "high", "stressLevel": "medium",
    "concerns": ["pore"], "currentProducts": ["토너"], "note": "…" }
  ```
  - 필수는 `gender`·`ageBand`
  - `concerns`는 최대 3개이고, 분류가 정상일 때 추천 대상이 됨
- 응답 202: `AnalysisView` (§1.4)
- 오류
  - 429 E4004: 진행 중 분석 있음 / 일일 20건 초과
  - 503 E3003: 대기열 가득 / 503 E3001: AI 점검 중
  - 413 E2003: 10MB 초과 / 415 E2004: JPEG·PNG 아님
  - 422 E2002: 해상도 부족·사진 디코딩 실패 / 422 E2001: 얼굴 미검출(AI 미구현)
  - 422 E4002: 입력 오류
  - 500 E4001

#### 8) `GET /analyses?page=1&size=20`
- 응답 200: `{ items: [ListItem], page: { page, size, totalItems, totalPages } }`
- `ListItem`: `{ analysisId, createdAt, status, recommendationStatus, disease, concerns }`
  - `concerns`: COMPLETED면 추천 고민 코드, 아니면 `[]`
- 오류: 422 E4002(page < 1, size가 1–50 밖)

#### 9) `GET /analyses/{id}`
- 응답 200: `AnalysisView` (§1.4)
- 오류: 404 E4003(없음·남의 것·ULID 형식 아님)

#### 10) `POST /analyses/{id}/recommendation/retry`
- FAILED 분석만 됩니다. 저장된 분류로 추천만 다시 만들고, 사진을 다시 올리지 않습니다
- 응답 202: `AnalysisView`
- 오류: 409 E4005(FAILED가 아님 — WITHHELD·COMPLETED 포함), 404 E4003, 429 E4004, 503 E3003

#### 11) `DELETE /analyses/{id}`
- 응답 204 (진행 중이어도 삭제됨)
- 오류: 404 E4003

#### 12) `GET /system/status`
- 응답 200: `{ aiAvailable, queueLength, estimatedWaitSec, checkedAt }`
  - `checkedAt`은 첫 헬스체크 전이면 `null`

### 1.4 분석 응답 `AnalysisView`

`POST /analyses`, 재요청, `GET /analyses/{id}`가 모두 이 형태를 돌려줍니다.

```json
{
  "analysisId": "01J9Z3K5V8Q2M4N6P8R0S2T4V6",
  "status": "COMPLETED",
  "disease": {
    "label": "아토피", "labelEn": "atopic", "confidence": 0.9, "uncertain": false,
    "probabilities": { "건선": 0.02, "아토피": 0.9, "여드름": 0.02, "정상": 0.02, "주사": 0.02, "지루": 0.02 },
    "modelVersion": "densenet121_s2_3ea9506", "inferenceMs": 45
  },
  "recommendationStatus": "generated",
  "recommendation": {
    "skinType": { "code": "dry", "label": "건성" },
    "concerns": [{ "code": "sensitivity", "label": "민감성(트러블/자극감)" }],
    "ingredients": [{ "name": "쑥잎 추출물", "purpose": "…", "priority": 1 }, { "name": "대나무추출물", "purpose": null, "priority": 2 }],
    "routine": [{ "step": 1, "time": "anytime", "action": "…" }],
    "reasoning": ["…", "…", "…"],
    "answer": "…", "inputNotes": ["…"], "disclaimer": "…",
    "filtered": true, "usedFallback": false, "modelVersion": "rec_sllm_v2", "inferenceMs": 47038
  },
  "guidance": [
    "이미지 모델의 6종 분류 참고 결과이며 의학적 진단이 아닙니다. 분류 점수만으로 다른 질환을 배제할 수 없습니다.",
    "성분 추천은 화장품 수준의 보조 관리 정보입니다. 질환 확인과 치료는 피부과 전문의와 상담하세요."
  ],
  "error": null,
  "queuePosition": null,
  "estimatedWaitSec": null,
  "createdAt": "2026-10-16T09:12:33Z",
  "completedAt": "2026-10-16T09:13:21Z",
  "survey": { … }
}
```

| 필드 | 타입 | 값이 있는 경우 |
|---|---|---|
| `analysisId` | string | 항상 (ULID) |
| `status` | string | 항상 — 아래 상태표 |
| `disease` | object | 항상 (접수 때 저장한 분류) |
| `recommendationStatus` | string \| null | COMPLETED·WITHHELD |
| `recommendation` | object \| null | COMPLETED |
| `guidance` | string[] | COMPLETED·WITHHELD (그 밖에는 `[]`) |
| `error` | `{ code, message }` \| null | FAILED (E3001·E3002·E3003·E4001) |
| `queuePosition` / `estimatedWaitSec` | number \| null | QUEUED |
| `createdAt` | string | 항상 |
| `completedAt` | string \| null | COMPLETED·WITHHELD·FAILED |
| `survey` | object | 항상 (다음 분석의 기본값) |

**상태 (`status`)**

| 값 | 의미 | 폴링 | 앱 처리 |
|---|---|---|---|
| `QUEUED` | 추천 생성 대기 | 계속 | 분류 참고 결과 + 대기 순번·예상 시간 |
| `GENERATING` | 추천 생성 중 (약 45초) | 계속 | 진행 표시, 재제출 막기 |
| `COMPLETED` | 추천 완료 | 끝 | 추천 + `guidance` |
| `WITHHELD` | 추천 보류 (**오류 아님**) | 끝 | 추천 없이 사유와 다음 행동 + `guidance` |
| `FAILED` | 통신·생성 실패 | 끝 | `error.message` + 재요청 버튼 |

폴링 간격은 처음 3분은 3초, 이후 10초입니다. 150초가 지나면 지연 안내를 보여 주고, 최대 30분까지 조회합니다.

**분류 결과 (`disease`)**

| 필드 | 설명 |
|---|---|
| `label` | 분류 라벨(한글): 건선·아토피·여드름·정상·주사·지루 |
| `labelEn` | `psoriasis` · `atopic` · `acne` · `normal` · `rosacea` · `seborrheic` |
| `confidence` | 모델 분류 점수 0–1. 화면엔 백분율 + **"모델 분류 점수"**라고 표기 (질환 확률 아님) |
| `uncertain` | 점수가 AI 임계값(0.6) 미만이면 true |
| `probabilities` | 6종 라벨(한글) → 0–1, 위 순서 |
| `modelVersion`, `inferenceMs` | 운영 기록용 |

진단이 아닌 **참고 결과**입니다.

**추천 상태 (`recommendationStatus`)**

| 값 | 상태 | 뜻 | 앱 안내 |
|---|---|---|---|
| `generated` | COMPLETED | 추천 생성 | 성분·관리 단계·요약 |
| `uncertain` | WITHHELD | 분류가 불확실해 보류 | 재촬영 또는 피부과 상담 |
| `no_concern` | WITHHELD | 정상 분류이고 고른 고민 없음 | 설문에서 고민을 골라 다시 분석 |

**추천 객체 (`recommendation`)**: `skinType`·`concerns`(code + label), `ingredients`, `routine`, `reasoning`, `answer`, `inputNotes`, `disclaimer`, `filtered`, `usedFallback`, `modelVersion`, `inferenceMs`

- `ingredients`는 개수가 가변입니다. `purpose`가 `null`이면 성분명만 표시합니다.
- `routine.time`은 `morning` · `evening` · `daily` · `weekly` · `anytime` 중 하나입니다.
- `reasoning`은 생성된 설명이지 검증된 근거가 아닙니다. `filtered`·`usedFallback`은 화면에 표시하지 않습니다.

### 1.5 개발용 fixture (`X-Fixture-Scenario`, production에선 무시)

| 값 | 결과 |
|---|---|
| `ok` (기본) | 아토피 0.9 → 약 1초 뒤 COMPLETED |
| `uncertain` | 아토피 0.55 → WITHHELD / `uncertain` |
| `no-concern` | 정상 0.9 → WITHHELD / `no_concern` |
| `rec-timeout` | FAILED E3002 → 헤더 없이 재요청하면 COMPLETED |
| `rec-slow` | 60초 뒤 COMPLETED |
| `no-face` | 제출 422 E2001 |
| `ai-down` | 제출 503 E3001 |

---

## 2. 이전과 달라진 점

### 2026-10-16 — 분석 API를 이미지 분류 + 추천으로 전환 (호환 깨짐)

- 커밋: `develop` `bdce8da` (이전 버전 `64b2143`)
- 근거: 개정 수행계획서(2026-10-15) 부록 B
- 내용: 회귀 지표 측정(수분·탄력·색소침착·모공)을 빼고 **DenseNet121 6종 이미지 분류 → Qwen2.5 성분 추천**으로 바꿨습니다
- 바뀐 범위: **분석 API 4개(7–10번)가 바뀌고 추이 API가 삭제**됐습니다. 인증·사용자·시스템 API와 응답 봉투·에러 코드 목록은 그대로입니다

#### 2.1 한눈에 보기

| 항목 | 이전 | 지금 |
|---|---|---|
| `GET /analyses/{id}/trend` | 있음 | **삭제** (404) |
| `POST /analyses` 요청 | `image` + `survey` + `deviceType` | `image` + `survey` (`deviceType`은 보내도 무시) |
| `POST /analyses` 응답 | `{ analysisId, status, queuePosition, estimatedWaitSec }` | `AnalysisView` 전체 |
| 재요청 응답 | 위와 같은 짧은 형태 | `AnalysisView` 전체 |
| `GET /analyses/{id}` 응답 | `AnalysisDetail` (`measurement` 포함) | `AnalysisView` (`disease` 포함) |
| `status` | `queued` `recommending` `done` `failed` | `QUEUED` `GENERATING` `COMPLETED` `WITHHELD` `FAILED` |
| 측정 결과 | `measurement` (점수·등급·ROI) | **삭제** |
| 분류 결과 | — | **`disease` 신규** |
| 추천 상태 | `recommendation.status` (`pending` `done` `failed`) | **`recommendationStatus` 신규** (`generated` `uncertain` `no_concern`) |
| 추천 객체 | 항상 있음 | COMPLETED일 때만, 아니면 `null` |
| 안내 문장 | — | **`guidance` 신규** |
| 이력 항목 | `overallScore`, `isDemo` | `recommendationStatus`, `disease` |
| 재요청 대상 | `failed` | `FAILED`만 (새 상태 `WITHHELD`는 대상 아님) |

#### 2.2 `POST /analyses` 요청

| 필드 | 이전 | 지금 |
|---|---|---|
| `image` | JPEG/PNG, 10MB, 짧은 변 720px | 같음 |
| `survey` | JSON 문자열 | 같음 (`concerns`가 정상 분류일 때 추천 대상이 됨) |
| `deviceType` | **필수** (`smartphone`·`tablet`·`camera`) | **삭제** (보내도 무시, 누락해도 오류 없음) |

#### 2.3 분석 응답 필드

| 필드 | 이전 | 지금 |
|---|---|---|
| `analysisId`, `createdAt`, `completedAt`, `queuePosition`, `estimatedWaitSec`, `survey`, `error` | 있음 | 같음 |
| `status` | 소문자 4종 | 대문자 5종 (§2.4) |
| `deviceType` | 있음 | **삭제** |
| `measurement` | `{ isDemo, confidence, calibrationApplied, overallScore, summary[], byRoi[], modelVersion }` | **삭제** |
| `disease` | — | **추가** |
| `recommendationStatus` | — | **추가** |
| `recommendation` | `{ status, …추천 필드 }`, 진행 중이면 `{ "status": "pending" }` | `null` 또는 추천 필드 (`status` 삭제, `inferenceMs` 추가) |
| `guidance` | — | **추가** |

이전 `GET /analyses/{id}` 완료 응답:

```json
{
  "analysisId": "01J9Z3K5V8Q2M4N6P8R0S2T4V6",
  "status": "done",
  "createdAt": "2026-10-15T09:12:33Z",
  "completedAt": "2026-10-15T09:13:31Z",
  "deviceType": "smartphone",
  "queuePosition": null,
  "estimatedWaitSec": null,
  "measurement": {
    "isDemo": false, "confidence": 0.87, "calibrationApplied": true, "overallScore": 63,
    "summary": [{ "metric": "moisture", "value": 61, "score": 61, "grade": "normal" }],
    "byRoi": [{ "roi": "forehead", "moisture": 58, "elasticity": 71, "pigmentation": 35, "pore": 52, "overallScore": 61, "grade": "normal" }],
    "modelVersion": "skin_reg_v1"
  },
  "recommendation": {
    "status": "done",
    "skinType": { "code": "combination", "label": "복합성" },
    "concerns": [{ "code": "pore", "label": "모공" }],
    "ingredients": [{ "name": "나이아신아마이드", "purpose": "…", "priority": 1 }],
    "routine": [{ "step": 1, "time": "morning", "action": "…" }],
    "reasoning": ["…", "…", "…"],
    "answer": "…", "inputNotes": [], "disclaimer": "…",
    "filtered": false, "usedFallback": false, "modelVersion": "rec_sllm_v2"
  },
  "survey": { … },
  "error": null
}
```

지금은 §1.4 예시와 같습니다.

#### 2.4 상태값

| 이전 `status` | 지금 `status` | 비고 |
|---|---|---|
| `queued` | `QUEUED` | |
| `recommending` | `GENERATING` | 이름 변경 |
| `done` | `COMPLETED` | 이름 변경 |
| — | `WITHHELD` | **신규** — 추천 보류(오류 아님), 재요청 불가 |
| `failed` | `FAILED` | |

#### 2.5 추천 상태

| 이전 분석 상태 | 이전 `recommendation` | 지금 분석 상태 | 지금 `recommendationStatus` / `recommendation` |
|---|---|---|---|
| `queued`·`recommending` | `{ "status": "pending" }` | `QUEUED`·`GENERATING` | `null` / `null` |
| `done` | `{ "status": "done", …추천 필드 }` | `COMPLETED` | `"generated"` / 추천 객체 |
| — | — | `WITHHELD` | `"uncertain"` 또는 `"no_concern"` / `null` |
| `failed` | `{ "status": "failed" }` | `FAILED` | `null` / `null` (사유는 `error`) |

#### 2.6 재요청 `POST /analyses/{id}/recommendation/retry`

| 항목 | 이전 | 지금 |
|---|---|---|
| 응답 | `{ analysisId, status: "queued", queuePosition, estimatedWaitSec }` | `AnalysisView` 전체 |
| 다시 쓰는 값 | 저장된 측정값 | 저장된 분류 결과 (사진·분류 재실행 없음) |
| 409 E4005 조건 | `failed`가 아님 | `FAILED`가 아님 (WITHHELD·COMPLETED 포함) |

#### 2.7 이력 `GET /analyses` 항목

| 이전 | 지금 |
|---|---|
| `{ analysisId, createdAt, status, overallScore, isDemo, concerns }` | `{ analysisId, createdAt, status, recommendationStatus, disease, concerns }` |

#### 2.8 에러 코드

코드와 HTTP 상태는 그대로이고 의미만 보강했습니다.

| 코드 | 이전 | 지금 |
|---|---|---|
| E2001 | 얼굴 미검출 | 같은 의미지만 AI에 아직 없음 (개발 서버 `no-face`로만 재현) |
| E2002 | 흐림·저조도·해상도 부족 | + AI가 사진을 읽지 못함(디코딩 실패) |
| E3001 | AI 응답 없음·설정 오류·60분 대기 초과 | + AI 분류기가 꺼짐 |
| E4005 | 상태상 불가능한 요청 | + WITHHELD 분석 재요청 |

#### 2.9 동작 차이

| 항목 | 이전 | 지금 |
|---|---|---|
| POST 응답의 `status` | 항상 `queued` | 저장 직후 실제 상태 (워커가 바로 집어 가면 `GENERATING`, 드물게 `WITHHELD`) |
| 폴링 기준 | 3분까지 3초, 이후 10초, **15분 뒤 중단** | 3분까지 3초, 이후 10초, **150초 후 지연 안내, 최대 30분** |
| `estimatedWaitSec` 평균 | 완료(done) 건 평균 | 완료(COMPLETED) 건 평균 — 보류는 GPU 생성이 없어 뺌 |
| 분석 1건 소요 | 측정 약 3초 + 추천 약 55초 | 분류 약 0.1초 + 추천 약 45초 (보류는 거의 즉시) |

#### 2.10 삭제된 API·열거형·스키마 (앱 타입 생성 기준)

**삭제된 추이 API** `GET /analyses/{id}/trend` — 이전 응답:

```json
{
  "current":  { "analysisId": "01J9…", "date": "2026-10-15", "overallScore": 63, "summary": { "moisture": 61, "elasticity": 74, "pigmentation": 38, "pore": 45 } },
  "previous": { "analysisId": "01J8…", "date": "2026-09-28", "overallScore": 60, "summary": { … } },
  "delta":    { "overallScore": 3, "moisture": 7, "elasticity": 2, "pigmentation": -2, "pore": -2 }
}
```

**열거형**

| 구분 | 이전 값 | 지금 |
|---|---|---|
| 분석 `status` | `queued` `recommending` `done` `failed` | `QUEUED` `GENERATING` `COMPLETED` `WITHHELD` `FAILED` |
| `recommendation.status` | `pending` `done` `failed` | 삭제 → `recommendationStatus`: `generated` `uncertain` `no_concern` |
| `labelEn` | — | 신규: `psoriasis` `atopic` `acne` `normal` `rosacea` `seborrheic` |
| `deviceType` | `smartphone` `tablet` `camera` | 삭제 |
| `metric` | `moisture` `elasticity` `pigmentation` `pore` | 삭제 |
| `roi` | `full_face` `forehead` `glabella` `eye_left` `eye_right` `cheek_left` `cheek_right` `lip` `chin` | 삭제 |
| `grade` | `good` `normal` `care` | 삭제 |
| 그대로 | `skinType`, `concerns`(고민 8종), `routine.time`, `gender`, `ageBand`, 수준(`low`·`medium`·`high`) | 변경 없음 |

**OpenAPI 스키마 (`/api/docs-json`)** — swift-openapi-generator 등으로 타입을 다시 만들면 이렇게 바뀝니다.

| 이전 | 지금 |
|---|---|
| `AnalysisCreated` (POST·재요청 응답) | `AnalysisView` |
| `AnalysisDetail` (GET 응답) | `AnalysisView` |
| `ApiEnvelopeAnalysisCreated`, `ApiEnvelopeAnalysisDetail` (봉투) | `ApiEnvelopeAnalysisView` |
| `Measurement`, `SummaryItem`, `RoiScore` | 삭제 |
| `AnalysisTrend`, `TrendPoint`, `TrendSummary`, `TrendDelta`, `ApiEnvelopeAnalysisTrend` | 삭제 |
| — | `Disease` (신규) |
| `Recommendation` | 이름 같음. `status` 삭제, `inferenceMs` 추가, 필드 자체가 nullable |
| `ListItem` | 이름 같음. `overallScore`·`isDemo` → `recommendationStatus`·`disease` |
| `AnalysisSubmission` (multipart 본문) | 이름 같음. `deviceType` 삭제, 필수는 `image`·`survey` |

#### 2.11 개발용 fixture

| 이전 | 지금 |
|---|---|
| `ok` `no-face` `rec-timeout` `rec-slow` `ai-down` | + **`uncertain`**, **`no-concern`** (보류 화면 재현용). `ok` 응답은 새 형태(아토피 0.9 → COMPLETED) |

#### 2.12 백엔드·배포 (앱 영향 없음)

| 항목 | 이전 | 지금 |
|---|---|---|
| DB 마이그레이션 | V1 | V2 추가. 처음 적용될 때 **기존 분석 기록을 모두 삭제**(계정·토큰은 유지), `skin_metrics` 테이블·회귀 컬럼 삭제, 분류 컬럼·`recommendation_status`·`guidance` 추가, `measure_ms` → `classify_ms` |
| DB `analyses.status` 값 | 소문자 4종 | 대문자 5종 (API 값과 같음) |
| 환경변수 | `AI_SKIN_TIMEOUT_MS` | `AI_CLASSIFY_TIMEOUT_MS` (기본값 20000 같음) |
| 백엔드 → AI 호출 | `/infer/skin-metrics`(동기) → `/infer/recommend`(워커) | `/infer/disease`(동기) → `/infer/disease-recommend`(워커) |
| AI로 보내는 추천 요청 | `metrics`(측정값, 데모면 null) + 설문 | 저장한 분류 JSON 전체 + 설문, `metrics` 없음 |
| 설문 변환 | `skinType` 한글 라벨, 고민 없으면 키 생략 | `skinType` 코드 그대로, `selfReportedConcerns`는 없어도 `[]` |
| AI 가용 판단 | `/health` `status: ok` | `status: ok` + `disease_loaded: true` |
| 성능 집계 SQL | `measure_ms`, `status='done'` | `classify_ms`, `status='COMPLETED'`, 목표: 분류 p95 ≤ 3초, 추천 p95 ≤ 120초 |

---

## 3. 앱(Swift)에서 할 일

- [ ] 제출 multipart에서 `deviceType` 빼기
- [ ] `AnalysisSubmission`·`AnalysisDetail`을 하나의 `AnalysisView` DTO로 통일
- [ ] `AnalysisStatus`를 대문자 5종으로 바꾸고 `WITHHELD` 추가
- [ ] `Measurement`·`MetricSummary`·`RoiMetrics`와 점수 링·등급·부위별 화면 제거
- [ ] `Disease` DTO와 분류 참고 결과 화면 추가 ("모델 분류 점수" 표기)
- [ ] `recommendationStatus`·`guidance` 추가, `recommendation`을 Optional로, `status` 필드 제거, `inferenceMs` 추가
- [ ] 보류 화면: `uncertain` → 재촬영·상담, `no_concern` → 설문 고민 선택
- [ ] 이력 항목 DTO 변경 (`overallScore`·`isDemo` 제거)
- [ ] 추이 화면·`AnalysisAPI.trend` 제거
- [ ] 폴링: 15분 중단 → 최대 30분, 150초 이후 지연 안내
- [ ] 목 서버(`Debug/MockServer.swift`) 응답 갱신
