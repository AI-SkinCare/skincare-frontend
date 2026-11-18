#!/bin/bash
# PostToolUseFailure: 도구 실패 시 trouble shooting 기록을 Claude에게 상기시킨다.
# 탐색용 명령(grep/ls/find 등)의 non-zero 종료는 문제가 아니므로 무시.

input=$(cat)
tool=$(printf '%s' "$input" | jq -r '.tool_name // empty')

if [ "$tool" = "Bash" ]; then
  cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
  first=$(printf '%s' "$cmd" | sed -E 's/^[[:space:]]*(cd [^;&]*(&&|;)[[:space:]]*)?//' | awk '{print $1}')
  case "$first" in
    grep|rg|ls|find|which|test|\[|cat|head|tail|diff|git) exit 0 ;;
  esac
fi

jq -n --arg tool "$tool" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUseFailure",
    additionalContext: ("[trouble shooting] " + $tool + " 실패. 단순 오타/경로 실수가 아니라 실제 문제(빌드·환경·설정·연동 오류 등)라면, 해결 후 docs/trouble_shooting/README.md 규칙에 따라 TEMPLATE.md로 문서를 작성하고 INDEX.md에 한 줄 추가할 것.")
  }
}'
