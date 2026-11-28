# 품질 보류·미생성 응답이 앱까지 전달되지 않음

| 항목 | 내용 |
|---|---|
| 날짜 | 2026-11-12 |
| 카테고리 | network |
| 상태 | 통신·DTO 해결, iOS 화면 검증 미실행 |
| 환경 | Windows 11, WSL Ubuntu 26.04 Swift 6.1.3, Spring Boot, FastAPI |

## 증상과 원인

FastAPI는 `quality_rejected`로 추천을 보류할 수 있지만 Spring enum과 DB 제약은 3종만 받았다. Swift는 보류를 모두 불확실 분류로 표시했다. 실제 AI 출처·품질 필드가 저장되지 않아 `not_generated`도 사라졌다. 최신 추천 버전 문자열은 기존 DB 40자 한도를 넘었다.

## 해결

추가 상태와 `generation`을 저장·전달하고 앱은 생성하지 않은 답을 성공 카드로 표시하지 않는다. 품질 보류에서는 서버 안내를 보여주고 폴링을 종료한다. 피해야 할 성분도 설문에서 FastAPI까지 전달한다. 계약은 [패치](../../patch/20261112-ai-generation.md)에 정리했다.

`Package.swift`는 앱의 실제 Foundation 통신·DTO 소스를 사용한다. `swift test -c release`로 확인한다. Keychain 구현은 iOS 그대로 유지하며 Linux 시험은 명시적으로 메모리 저장소를 주입한다. 문장 분리 UI 보조 함수는 Darwin에서만 컴파일한다.

## 시험 환경 문제

실제 오류:

```text
'bySentences' is unavailable: Enumeration by sentences isn't supported in swift-corelibs-foundation
New-NetFirewallRule: 액세스가 거부되었습니다.
```

Docker Desktop은 기존 Inference manager 소켓 오류로 기동하지 못했다. WSL에 별도 시험 PostgreSQL을 구성했다. WSL이 종료되면 시험 도중 DB 연결이 끊겨, 시험 프로세스가 살아 있는 동안 WSL을 유지했다. Windows 방화벽을 변경하는 명령은 권한 거부되어 적용되지 않았다. 대신 양 끝을 localhost로 제한한 일회성 SSH 터널로 Swift → Spring HTTP를 연결했다. 시스템 SSH 설정이나 사용자 키는 변경하지 않았다.

SwiftUI·촬영 처리·Keychain과 iOS 화면은 Mac/Xcode에서 별도 확인해야 한다. Linux 통신 시험 통과를 iOS 전체 빌드 통과로 취급하지 않는다.
