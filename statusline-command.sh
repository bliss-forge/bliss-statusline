#!/usr/bin/env bash
# Claude Code statusLine — 2-line layout
# 신호등 바(초록<50 / 노랑50-79 / 빨강≥80), 토큰 사용량 표시, 비용 없음
#
#   LINE 1  📂 …/slack-offboarding-bot │ 🌿(main) ✗ │ 🧠 Opus 4.8 │ high 💡
#   LINE 2  📝 █░░░░░░░░░░░░░░ 9% 89K/1M │ 🚀 5H ███████░░░ 75% (3시간 14분)

input=$(cat)

cwd=$(echo "$input"          | jq -r '.workspace.current_dir // .cwd // empty')
model_full=$(echo "$input"   | jq -r '.model.display_name // empty')
used=$(echo "$input"         | jq -r '.context_window.used_percentage // empty')
total_input=$(echo "$input"  | jq -r '.context_window.total_input_tokens // empty')
ctx_size=$(echo "$input"     | jq -r '.context_window.context_window_size // empty')
effort=$(echo "$input"       | jq -r '.effort.level // empty')
thinking=$(echo "$input"     | jq -r '.thinking.enabled // empty')
fh_pct=$(echo "$input"       | jq -r '.rate_limits.five_hour.used_percentage // empty')
fh_reset=$(echo "$input"     | jq -r '.rate_limits.five_hour.resets_at // empty')
sd_pct=$(echo "$input"       | jq -r '.rate_limits.seven_day.used_percentage // empty')

# ── 신호등 색상: 사용량(%) → ANSI 색 ─────────────────────────────────────────
pct_color() {
  if   [ "$1" -ge 80 ]; then echo "\033[31m"   # 빨강
  elif [ "$1" -ge 50 ]; then echo "\033[33m"   # 노랑
  else                       echo "\033[32m"   # 초록
  fi
}

# ── 신호등 진행 바: $1=percent(int) $2=width → BAR / BARC 전역 설정 ───────────
make_bar() {
  local pct=$1 width=$2 filled empty i
  [ "$pct" -lt 0 ] && pct=0; [ "$pct" -gt 100 ] && pct=100
  filled=$(( pct * width / 100 )); empty=$(( width - filled ))
  BAR=""
  for ((i=0; i<filled; i++)); do BAR="${BAR}█"; done
  for ((i=0; i<empty;  i++)); do BAR="${BAR}░"; done
  BARC=$(pct_color "$pct")
}

# ── 경로: $HOME → ~, 마지막 단계만 ───────────────────────────────────────────
short_cwd="${cwd/#$HOME/~}"
short_cwd=$(echo "$short_cwd" | awk -F'/' '{ n=NF; if (n<=3) print $0; else print "…/" $n }')

# ── Git: 브랜치 + dirty ──────────────────────────────────────────────────────
git_branch=""; git_dirty=""
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
               || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  git -C "$cwd" diff --cached --quiet 2>/dev/null || git_dirty="\033[32m+\033[0m"
  git -C "$cwd" diff --quiet        2>/dev/null || git_dirty="${git_dirty}\033[31m✗\033[0m"
fi

# ── 모델명 정리 ("Claude " / " (… context)" 제거) ───────────────────────────
model_short=""
[ -n "$model_full" ] && model_short=$(echo "$model_full" | sed 's/^Claude //; s/ *([^)]*)//')

# ── effort 색상 ──────────────────────────────────────────────────────────────
effort_str=""
case "$effort" in
  max)    effort_str="\033[1;35mmax\033[0m"    ;;
  xhigh)  effort_str="\033[35mxhigh\033[0m"    ;;
  high)   effort_str="\033[33mhigh\033[0m"     ;;
  medium) effort_str="\033[2mmedium\033[0m"    ;;
  low)    effort_str="\033[2mlow\033[0m"       ;;
esac
[ "$thinking" = "true" ] && effort_str="${effort_str:+$effort_str }\033[2m💡\033[0m"

SEP="\033[2m │ \033[0m"

# ════════════════════════════════════════════════════════════════════════════
# LINE 1 — 경로 │ 브랜치 │ 모델 │ effort
# ════════════════════════════════════════════════════════════════════════════
segs=()
segs+=("$(printf '\033[1;34m📂 %s\033[0m' "$short_cwd")")
if [ -n "$git_branch" ]; then
  g=$(printf '\033[36m🌿(%s)\033[0m' "$git_branch")
  [ -n "$git_dirty" ] && g="${g} ${git_dirty}"
  segs+=("$g")
fi
[ -n "$model_short" ] && segs+=("$(printf '\033[1;36m🧠 %s\033[0m' "$model_short")")
[ -n "$effort_str" ]  && segs+=("$effort_str")

line1=""
for s in "${segs[@]}"; do
  if [ -z "$line1" ]; then line1="$s"; else line1="${line1}${SEP}${s}"; fi
done
printf "%b\n" "$line1"

# ════════════════════════════════════════════════════════════════════════════
# LINE 2 — Context (바+%+토큰)  │  5H 사용량 한도
# ════════════════════════════════════════════════════════════════════════════
line2=""

if [ -n "$used" ] && [ "$used" != "null" ]; then
  used_int=$(printf "%.0f" "$used"); make_bar "$used_int" 15
  tok=""
  if [ -n "$total_input" ] && [ "$total_input" != "null" ] \
     && [ -n "$ctx_size" ] && [ "$ctx_size" != "null" ]; then
    tok=$(echo "$total_input $ctx_size" | awk '{
      uk = sprintf("%dK", int($1/1000 + 0.5))
      if ($2 >= 1000000) tt = sprintf("%gM", $2/1000000); else tt = sprintf("%dK", int($2/1000 + 0.5))
      printf "%s/%s", uk, tt
    }')
  fi
  line2=$(printf '\033[2m📝\033[0m %b%s\033[0m \033[1m%d%%\033[0m \033[2m%s\033[0m' "$BARC" "$BAR" "$used_int" "$tok")
fi

# 5H 사용량 한도 (Pro/Max 전용)
if [ -n "$fh_pct" ] && [ "$fh_pct" != "null" ]; then
  fh_int=$(printf "%.0f" "$fh_pct"); make_bar "$fh_int" 10
  reset_str=""
  if [ -n "$fh_reset" ] && [ "$fh_reset" != "null" ]; then
    diff=$(( fh_reset - $(date +%s) ))
    if [ "$diff" -gt 0 ]; then
      h=$(( diff / 3600 )); m=$(( (diff % 3600) / 60 ))
      if [ "$h" -gt 0 ]; then reset_str=" \033[2m(${h}시간 ${m}분)\033[0m"; else reset_str=" \033[2m(${m}분)\033[0m"; fi
    fi
  fi
  fh_seg=$(printf '\033[2m🚀 5H\033[0m %b%s\033[0m %d%%' "$BARC" "$BAR" "$fh_int")
  fh_seg="${fh_seg}${reset_str}"
  if [ -z "$line2" ]; then line2="$fh_seg"; else line2="${line2}${SEP}${fh_seg}"; fi
fi

[ -n "$line2" ] && printf "%b\n" "$line2"
