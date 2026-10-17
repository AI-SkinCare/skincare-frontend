# Claude Code 셸에서 gh·swiftlint를 찾지 못함

| 항목 | 내용 |
|------|------|
| 날짜 | 2026-10-18 |
| 카테고리 | env |
| 상태 | 우회 |
| 작성자 | 정도희 (Claude Code) |
| 환경 | macOS, Apple Silicon, Homebrew `/opt/homebrew` |

## 증상

`gh auth login`을 끝냈는데 Claude Code가 실행하는 셸에서는 명령을 찾지 못함.

```
(eval):1: command not found: gh
brew not found
```

## 원인

Homebrew가 `/opt/homebrew/bin`에 설치돼 있지만, Claude Code가 띄우는 비로그인 셸의 PATH에 이 경로가 없음. 사용자 터미널(로그인 셸, `~/.zprofile`의 `brew shellenv`)에서는 정상 동작.

## 해결

전체 경로로 실행한다.

```bash
/opt/homebrew/bin/gh pr create ...
/opt/homebrew/bin/swiftlint lint
```

로그인 셸 PATH 확인: `zsh -lc 'which gh'` → `/opt/homebrew/bin/gh`

## 시도했지만 실패한 방법

- `which gh`, `brew --version` — 비로그인 셸이라 둘 다 못 찾음

## 참고

- 근본 해결이 필요하면 `~/.zshenv`에 `eval "$(/opt/homebrew/bin/brew shellenv)"` 추가 (모든 셸에 적용)
