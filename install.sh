#!/usr/bin/env bash
# bliss-statusline installer
# 하는 일: statusline-command.sh 를 ~/.claude/ 로 설치하고 settings.json 의 statusLine 을 연결.
# 사용법:
#   원격:  curl -fsSL https://raw.githubusercontent.com/bliss-forge/bliss-statusline/main/install.sh | bash
#   로컬:  ./install.sh            (레포를 clone 한 경우)
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/bliss-forge/bliss-statusline/main"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
DEST="$CLAUDE_DIR/statusline-command.sh"
SETTINGS="$CLAUDE_DIR/settings.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"

say() { printf '\033[1;36m▶\033[0m %s\n' "$1"; }
die() { printf '\033[1;31m✗ %s\033[0m\n' "$1" >&2; exit 1; }

# 1) 의존성 확인
command -v jq  >/dev/null 2>&1 || die "jq 가 필요합니다.  macOS: brew install jq  /  Debian: sudo apt install jq"
command -v bash >/dev/null 2>&1 || die "bash 가 필요합니다."

mkdir -p "$CLAUDE_DIR"

# 2) statusline-command.sh 확보 (로컬 우선, 없으면 원격에서 다운로드)
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/statusline-command.sh" ]; then
  say "로컬 statusline-command.sh 복사 → $DEST"
  cp "$SCRIPT_DIR/statusline-command.sh" "$DEST"
else
  say "원격에서 statusline-command.sh 다운로드 → $DEST"
  curl -fsSL "$REPO_RAW/statusline-command.sh" -o "$DEST"
fi
chmod +x "$DEST"

# 3) settings.json 의 statusLine 연결 (기존 설정 보존, 백업 후 병합)
CMD="bash $DEST"
if [ -f "$SETTINGS" ]; then
  cp "$SETTINGS" "$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
  say "기존 settings.json 백업 후 statusLine 갱신"
  tmp="$(mktemp)"
  jq --arg cmd "$CMD" '.statusLine = {type:"command", command:$cmd}' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
else
  say "settings.json 생성"
  jq -n --arg cmd "$CMD" '{statusLine:{type:"command", command:$cmd}}' > "$SETTINGS"
fi

# 4) 검증 (샘플 입력으로 실제 렌더링)
say "검증 실행:"
NOW=$(date +%s); RESET=$((NOW + 11640))
printf '{"workspace":{"current_dir":"%s"},"model":{"display_name":"Claude Opus 4.8 (1M context)"},"context_window":{"used_percentage":9,"total_input_tokens":89000,"context_window_size":1000000},"effort":{"level":"high"},"thinking":{"enabled":true},"rate_limits":{"five_hour":{"used_percentage":75,"resets_at":%s}}}' \
  "$HOME/work/proj/slack-offboarding-bot" "$RESET" | bash "$DEST" || true

printf '\n\033[1;32m✓ 설치 완료.\033[0m Claude Code 를 재시작하면 statusline 이 적용됩니다.\n'
