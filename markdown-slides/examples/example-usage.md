# Example: Markdown Slides Usage

## Quick Presentation

Create `demo.md`:

```markdown
---
marp: true
theme: default
paginate: true
header: "Demo Corp"
footer: "Q1 2026 Review"
---

# Q1 2026 Review

**Team Performance & Roadmap**

---

## Revenue Growth

- Q1 Revenue: $2.4M (+18% QoQ)
- New customers: 142
- Churn rate: 2.1% (down from 3.4%)

![bg right:40%](https://via.placeholder.com/400x300)

---

## Product Milestones

| Feature | Status | Impact |
|---------|--------|--------|
| API v3 | ✅ Shipped | 40% faster |
| Mobile app | 🔄 Beta | 2k testers |
| AI search | 📋 Planned | Q2 launch |

---

## Q2 Priorities

1. **Launch mobile app** — Target: April 15
2. **AI search rollout** — Target: May 1
3. **Enterprise tier** — Target: June 1

---

<!-- _backgroundColor: #264653 -->
<!-- _color: white -->

# Questions?

📧 team@democorp.com
```

Convert:

```bash
# PDF for email
bash scripts/run.sh --input demo.md --format pdf

# PPTX for the meeting
bash scripts/run.sh --input demo.md --format pptx

# HTML with dark theme
bash scripts/run.sh --input demo.md --format html --theme scripts/custom-theme.css
```
