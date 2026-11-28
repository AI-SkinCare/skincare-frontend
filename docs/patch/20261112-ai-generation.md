# 추천 보류와 생성 출처 (2026-11-12)

백엔드 `docs/ai-generation-contract.md`와 함께 적용한다.

`quality_rejected`는 WITHHELD 종료 상태이며 실패/재시도 상태가 아니다. `guidance`를 표시하고 촬영 불확실과 구별한다.
`generation.origin=not_generated`는 추천을 생성하지 않았다는 뜻이며 추천 카드·성공 문구를 표시하지 않는다.
`generation`은 `origin`, `qualityStatus`, `evidenceStatus`, `qualityIssues`를 포함한다. 구버전은 필드를 생략할 수 있다.
`source_cards`는 근거 자료를 바탕으로 구성한 대체 안내, `rule_fallback`은 규칙 기반 대체 안내로 표시한다. 임상 검증으로 표현하지 않는다.
선택 설문 `avoidIngredients`는 최대 30개, 각 1–100자이며 Spring을 거쳐 FastAPI로 전달된다.
성분의 `purposeSource`, `purposeStatus`는 선택 필드다.

Windows에서는 실제 Swift Foundation 네트워크/DTO 코드를 시험하고, iOS SwiftUI 빌드·화면 검증은 별도 Mac/Xcode 확인 대상으로 명시한다.

## 검증 결과

Swift 통신·DTO·토큰·폴링 시험 23개, Spring 단위 150개 및 HTTP/DB 통합 88개, AI 회귀 600개가 통과했다(AI 4개 건너뜀).
실제 사진 3장으로 요청 4개를 보냈다: 회피 조건 품질 보류·정상 무고민 보류는 약 1초에 종료했고, 추천 2개는 약 78초·39초 후 근거 카드 대체 안내로 완료됐다. 두 대체 답변을 모델 원문 성공으로 계산하지 않았다.
회원가입·로그인·이력·토큰 갱신·삭제·보류 재요청 409까지 실제 HTTP로 확인했다. 실제 생성 후 폴링 중 분류 값과 회피 조건이 유지됐다.

`swift test -c release`는 앱의 실제 Foundation 코드를 사용한다. `Tools/LiveFlow.swift`는 같은 소스와 함께 컴파일하는 실제 HTTP 시험 진입점이다. 사진은 표준 입력의 메모리 데이터로만 받으며 저장하지 않는다. iOS 전체 빌드·SwiftUI 화면·촬영·Keychain·SwiftLint는 별도 Mac 검증이 남아 있다.
