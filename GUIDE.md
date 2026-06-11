# 사용자 가이드 — bliss-statusline 로직

statusline 이 무엇을 어떻게 보여주는지, 그리고 입맛에 맞게 고치는 법을 설명합니다.
(참조 스타일: [AwesomeJun/CC-statusline](https://github.com/AwesomeJun/CC-statusline) 의 "What it shows")

---

## 전체 모습

```
LINE 1  📂 …/slack-offboarding-bot │ (main) ✗ │ Opus 4.8 │ high 💡
LINE 2  📝 █░░░░░░░░░ 16% 156K/1M │ 📊 5H █████░ 88% (2H 30M)
```

Claude Code 는 매 턴 statusline 스크립트에 **JSON 을 stdin 으로** 넘깁니다. 스크립트는 그 JSON 을 `jq` 로 뜯어 2줄로 그립니다. 값이 없는 세그먼트는 **조용히 생략**됩니다(자리만 비지 않음).

---

## LINE 1 — 환경

| 세그먼트 | 예시 | JSON 소스 | 의미 |
|---------|------|-----------|------|
| 📂 경로 | `…/slack-offboarding-bot` | `workspace.current_dir` | `$HOME`→`~` 치환. 깊이가 3단계 초과면 **마지막 폴더만** `…/` 로 축약 |
| git | `(main) ✗` | 현재 디렉토리의 git | 브랜치명(괄호) + dirty 표시. `+`(초록)=staged, `✗`(빨강)=unstaged. git 레포가 아니면 생략 |
| 모델 | `Opus 4.8` | `model.display_name` | `Claude ` 접두와 ` (… context)` 접미를 떼어낸 짧은 이름 |
| effort | `high 💡` | `effort.level` + `thinking.enabled` | reasoning effort(색상 구분) + thinking 켜짐이면 💡 추가 |

**effort 색상** — `max`(굵은 보라) · `xhigh`(보라) · `high`(노랑) · `medium`/`low`(흐림).

---

## LINE 2 — 사용량 (신호등)

| 세그먼트 | 예시 | JSON 소스 | 의미 |
|---------|------|-----------|------|
| 📝 컨텍스트 | `█░░… 16% 156K/1M` | `context_window.*` | 사용률 막대(너비 10) + % + `사용토큰/컨텍스트크기` |
| 📊 5시간 한도 | `5H █████░ 88% (2H 30M)` | `rate_limits.five_hour.*` | 5시간 사용률 막대(너비 6) + % + 리셋까지 남은 시간(`H`/`M`). Pro/Max 에서만 |

토큰 표기는 자동 단위 변환: `89000` → `89K`, `1000000` → `1M`.

### 📊 5H 캐시 폴백 (세션 시작 처리)

Claude Code 는 `rate_limits` 를 **첫 API 응답 이후에만** 넘겨줍니다([공식 문서](https://code.claude.com/docs/en/statusline.md)). 그래서 세션을 막 켠 시점엔 5H 데이터가 없습니다. 이를 메우려고:

- 실제 값이 올 때마다 스크립트 옆 `.statusline-5h-cache` 에 `퍼센트 리셋시각` 을 기록(원자적 쓰기).
- 데이터가 없을 때(시작 직후)는 캐시값을 `📊 5H ██ ~17% (이전)` 처럼 **`~` + `(이전)`** 으로 표시 → 지난 세션의 마지막 값.
- 단 **캐시된 리셋 시각이 지났으면**(5시간 윈도우가 새로 시작됐으면) 폴백을 쓰지 않고 생략 — 오래된 값으로 오인하지 않도록.
- 첫 메시지를 주고받아 실제 값이 들어오면 자동으로 `~`·`(이전)` 없는 정상 표시로 교체되고 캐시도 갱신됩니다.

캐시 파일은 `.gitignore` 처리돼 있고, 지우면 그냥 "첫 턴 전까진 5H 생략" 상태로 돌아갑니다.

---

## 신호등 색상 규칙 (핵심 로직)

막대와 % 색은 **사용률 하나로** 결정됩니다 (`pct_color()`):

| 사용률 | 색 | 코드 |
|--------|-----|------|
| `< 50%`   | 🟢 초록 | `\033[32m` |
| `50–79%`  | 🟡 노랑 | `\033[33m` |
| `≥ 80%`   | 🔴 빨강 | `\033[31m` |

컨텍스트든 5시간 한도든 같은 기준을 씁니다. "초록이면 여유, 빨강이면 곧 한도" 라고 읽으면 됩니다.

## 막대 그리는 법 (`make_bar`)

```
filled = 사용률(%) × 너비 ÷ 100   →  filled 칸은 █, 나머지는 ░
```

예) 컨텍스트 너비 10, 사용률 16% → `16×10÷100 = 1.6 → 1칸` → `█░░░░░░░░░`
예) 5시간 너비 6, 사용률 88% → `88×6÷100 = 5.28 → 5칸` → `█████░`

(소수점은 버림. 그래서 낮은 % 에서는 막대가 1칸 이하로 보일 수 있음.)

> 막대 너비(컨텍스트 10 / 5H 6)는 첫 줄과 전체 길이를 비슷하게 맞추려고 정한 값입니다. 더 길게/짧게 원하면 아래 표의 `make_bar` 숫자만 바꾸면 됩니다.

---

## 입맛대로 바꾸기

| 바꾸고 싶은 것 | 어디를 고치나 |
|----------------|---------------|
| 색 임계값 (50 / 80) | `pct_color()` 의 `-ge 80`, `-ge 50` |
| 막대 길이 | `make_bar "$used_int" 10`(컨텍스트), `make_bar "$fh_int" 6`(5H) 의 숫자 |
| 경로 축약 단계 | `short_cwd` awk 의 `n<=3` 조건 |
| 모델명 정리 규칙 | `model_short` 의 `sed` 패턴 |
| 리셋 시간 표기("시간/분") | 5H 블록의 `reset_str` 부분 |
| 7일 한도 막대 추가 | `sd_pct` 가 이미 파싱돼 있음 — `make_bar`+세그먼트를 LINE 2 에 추가하면 부활 |

> 참고: 스크립트는 `seven_day.used_percentage`(`sd_pct`)를 **파싱은 하지만 출력하지 않습니다**. 7일 한도 막대를 원하면 LINE 2 에 한 세그먼트만 추가하면 됩니다.

## 직접 테스트

설정을 바꾼 뒤 Claude Code 재시작 없이 바로 확인:

```bash
printf '{"workspace":{"current_dir":"/tmp/demo/proj/slack-offboarding-bot"},"model":{"display_name":"Claude Opus 4.8 (1M context)"},"context_window":{"used_percentage":9,"total_input_tokens":89000,"context_window_size":1000000},"effort":{"level":"high"},"thinking":{"enabled":true},"rate_limits":{"five_hour":{"used_percentage":75,"resets_at":9999999999}}}' \
  | bash ~/.claude/statusline-command.sh
```

`used_percentage` 값을 `9 → 60 → 90` 으로 바꿔가며 막대 색이 🟢→🟡→🔴 로 변하는지 확인해 보세요.
