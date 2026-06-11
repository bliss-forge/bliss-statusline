# bliss-statusline

> Claude Code 용 **2줄 statusline** — 경로·git·모델·effort 한 줄, 컨텍스트/5시간 한도를 신호등 막대로 한 줄.
> 비용 표시 없음. 의존성은 `bash` + `jq` 뿐.

```
📂 …/slack-offboarding-bot │ (main) ✗ │ Opus 4.8 │ high 💡
📝 █░░░░░░░░░ 16% 156K/1M │ 📊 5H █████░ 88% (2H 30M)
```

- 🟢🟡🔴 **신호등 막대** — 사용량에 따라 초록(<50%) / 노랑(50–79%) / 빨강(≥80%)
- **모델 · effort** — `Claude `, `(… context)` 접두/접미 제거한 짧은 이름 + reasoning effort + thinking 💡
- 📝 **컨텍스트** — 사용 % + `사용토큰/컨텍스트크기` (예: `89K/1M`)
- 📊 **5시간 사용 한도** (Pro/Max) — % + 리셋까지 남은 시간

자세한 세그먼트 해설은 → **[GUIDE.md](./GUIDE.md)**

---

## 자연어로 설치 (Claude Code 에게 맡기기)

Claude Code 세션에서 이렇게 말하면 됩니다:

> **`github.com/bliss-forge/bliss-statusline` 의 README 를 보고 이 statusline 을 설치해줘`**

에이전트는 아래 **[설치 동작](#설치-동작-에이전트용)** 절차를 그대로 수행합니다. 수동으로 명령을 외울 필요가 없습니다.

### 설치 동작 (에이전트용)

에이전트는 다음을 순서대로 수행하면 된다:

1. **의존성 확인** — `jq`, `bash` 존재 확인. 없으면 안내(`brew install jq` / `apt install jq`).
2. **스크립트 설치** — `statusline-command.sh` 를 `~/.claude/statusline-command.sh` 로 복사(또는 원격 다운로드)하고 `chmod +x`.
3. **settings.json 연결** — `~/.claude/settings.json` 의 `statusLine` 키를 아래로 설정(기존 설정은 보존, 먼저 백업):
   ```json
   { "statusLine": { "type": "command", "command": "bash /ABS/PATH/.claude/statusline-command.sh" } }
   ```
4. **검증** — 샘플 입력을 파이프로 넣어 2줄이 정상 렌더링되는지 확인:
   ```bash
   printf '{"workspace":{"current_dir":"/tmp/demo/slack-offboarding-bot"},"model":{"display_name":"Claude Opus 4.8 (1M context)"},"context_window":{"used_percentage":9,"total_input_tokens":89000,"context_window_size":1000000},"effort":{"level":"high"},"thinking":{"enabled":true},"rate_limits":{"five_hour":{"used_percentage":75,"resets_at":9999999999}}}' | bash ~/.claude/statusline-command.sh
   ```
5. **안내** — Claude Code 재시작 후 적용된다고 알림.

위 1~4 단계는 `install.sh` 한 방으로 자동화돼 있습니다.

---

## 빠른 설치 (한 줄)

```bash
curl -fsSL https://raw.githubusercontent.com/bliss-forge/bliss-statusline/main/install.sh | bash
```

`install.sh` 가 하는 일: 스크립트 다운로드 → `~/.claude/` 설치 → `settings.json` 의 `statusLine` 연결(기존 설정 백업) → 샘플 렌더링 검증.

## 수동 설치

```bash
# 1) 레포 클론
git clone https://github.com/bliss-forge/bliss-statusline.git
cd bliss-statusline

# 2) 스크립트 설치
cp statusline-command.sh ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh

# 3) ~/.claude/settings.json 에 추가 (jq 사용 시)
jq '.statusLine = {type:"command", command:"bash \(env.HOME)/.claude/statusline-command.sh"}' \
   ~/.claude/settings.json > /tmp/s.json && mv /tmp/s.json ~/.claude/settings.json
```

Claude Code 를 재시작하면 적용됩니다.

---

## Requirements

| 항목 | 설명 |
|------|------|
| `bash` | 스크립트 실행 (macOS/Linux 기본 탑재) |
| `jq`   | Claude Code 가 넘기는 JSON 입력 파싱 — **필수**. `brew install jq` / `sudo apt install jq` |
| `git`  | git 세그먼트 표시용 (없으면 브랜치 부분만 생략) |

Nerd Font 불필요 — 일반 이모지만 사용합니다.

## 제거

```bash
# settings.json 에서 statusLine 키 제거
jq 'del(.statusLine)' ~/.claude/settings.json > /tmp/s.json && mv /tmp/s.json ~/.claude/settings.json
rm -f ~/.claude/statusline-command.sh
```

## FAQ

**Q. 5시간 막대(`📊 5H`)가 안 보여요.**
A. Claude Code 는 `rate_limits` 를 **첫 API 응답 이후에만** 넘겨줍니다(공식 동작, Pro/Max 한정). 그래서 *세션을 막 시작한 시점*엔 안 보이고, 첫 메시지를 주고받으면 나타납니다. 이 공백을 메우려 마지막 값을 캐시해 두고 시작 직후엔 `📊 5H ~17% (이전)` 처럼 **지난 세션 값**으로 보여줍니다(첫 턴 후 실시간 값으로 교체). API/Console 요금제는 `rate_limits` 자체가 없어 표시되지 않습니다.

**Q. git 브랜치가 안 보여요.**
A. 현재 작업 디렉토리가 git 레포일 때만 나옵니다. `✗`(빨강)는 unstaged 변경, `+`(초록)는 staged 변경을 뜻합니다.

**Q. 비용(💰)은 왜 없나요?**
A. 의도적으로 뺐습니다. 사용량(컨텍스트·5시간 한도)만 신호등으로 보여줍니다.

**Q. 색 기준을 바꾸고 싶어요.**
A. `statusline-command.sh` 의 `pct_color()` 임계값(50 / 80)과 `make_bar` 너비를 수정하면 됩니다. → [GUIDE.md](./GUIDE.md)

---

영감: [AwesomeJun/CC-statusline](https://github.com/AwesomeJun/CC-statusline) · License: MIT
