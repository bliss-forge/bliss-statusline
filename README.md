# bliss-statusline 📊 — 토큰이 바닥나기 전에 미리 본다

> Claude Code 작업 정보와 컨텍스트·5시간 사용량을, 터미널 두 줄에.

![macOS](https://img.shields.io/badge/macOS-supported-000000?style=flat-square&logo=apple&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-supported-FCC624?style=flat-square&logo=linux&logoColor=black)
![Bash](https://img.shields.io/badge/shell-bash-4EAA25?style=flat-square&logo=gnubash&logoColor=white)
![deps](https://img.shields.io/badge/deps-jq-1E90FF?style=flat-square)
![Claude Code](https://img.shields.io/badge/Claude%20Code-statusLine-DA7756?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-3DA639?style=flat-square)

```
📂 …/my-project │ (main) ✗ │ Opus 4.8 │ high 💡
📝 █░░░░░░░░░ 16% 156K/1M │ 📊 5H ████████░░ 88% (2H 30M)
```

작업 위치·브랜치·모델을 한 줄, 컨텍스트와 5시간 사용량을 신호등 막대로 한 줄. 비용 표시 없음. 의존성은 `bash` + `jq` 뿐.

## ✨ 무엇을 보여주나

**1번째 줄 — 환경**
- 📂 **경로** — 홈은 `~`, 깊으면 `…/마지막폴더` 로 축약
- **(브랜치)** — git 브랜치 + 변경 표시 (`+` 초록 = staged, `✗` 빨강 = unstaged)
- **모델** — `Opus 4.8` 처럼 짧은 이름 + reasoning effort + thinking 켜지면 💡

**2번째 줄 — 사용량 (신호등 막대)**
- 📝 **컨텍스트** — 사용률 막대 + % + `사용토큰/전체` (예: `156K/1M`)
- 📊 **5시간 한도** — 사용률 막대 + % + 리셋까지 남은 시간 (Pro/Max 전용)
- 막대 색: 🟢 `<50%` · 🟡 `50–79%` · 🔴 `≥80%`

> 세그먼트별 상세 로직은 → **[GUIDE.md](./GUIDE.md)**

## 🚀 설치

**자연어로 (Claude Code 에게)** — 세션에서 그대로 말하면 됩니다:

> `github.com/bliss-forge/bliss-statusline` 의 statusline 을 설치해줘

**한 줄로:**
```bash
curl -fsSL https://raw.githubusercontent.com/bliss-forge/bliss-statusline/main/install.sh | bash
```
스크립트를 `~/.claude/` 에 설치하고 `settings.json` 의 `statusLine` 을 연결합니다(기존 설정은 백업).

**수동으로:**
```bash
git clone https://github.com/bliss-forge/bliss-statusline.git
cp bliss-statusline/statusline-command.sh ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
jq '.statusLine = {type:"command", command:"bash \(env.HOME)/.claude/statusline-command.sh"}' \
   ~/.claude/settings.json > /tmp/s.json && mv /tmp/s.json ~/.claude/settings.json
```

설치 후 Claude Code 를 재시작하면 적용됩니다.

## 🧩 요구사항
- `bash`, `jq` (필수 — `brew install jq` / `sudo apt install jq`)
- `git` (있으면 브랜치 표시, 없으면 그 부분만 생략)

## 🧹 제거
```bash
jq 'del(.statusLine)' ~/.claude/settings.json > /tmp/s.json && mv /tmp/s.json ~/.claude/settings.json
rm -f ~/.claude/statusline-command.sh
```

---
상세 로직 → [GUIDE.md](./GUIDE.md) · License: MIT
