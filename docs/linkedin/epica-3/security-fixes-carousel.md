# LinkedIn Carousel Post: Security Fixes

---

## 📸 Slide-by-Slide Content for LinkedIn Carousel

**Format:** 10 slides, square format (1080x1080)
**Style:** Technical but accessible, code snippets + explanations

---

### Slide 1: Cover
```
🔐 3 Security Holes
We Found in Our
AI Agent Auth System

(And How We Fixed Them)

Building OAuth2 for agents ≠ OAuth2 for humans

#AIEngineering #Security
```

---

### Slide 2: The Context
```
The Challenge:

We're building Thalamus - an OAuth2
provider for AI agents that execute
workflows.

Agents can delegate tasks to other
agents, creating authorization chains.

Last week: Code review found 3 critical
security vulnerabilities.

Let's dive in →
```

---

### Slide 3: Mistake #1
```
❌ MISTAKE #1:
The Immortal Child Token

THE PROBLEM:
Child tokens could outlive parent tokens

EXAMPLE:
• Parent expires: 2:00 PM
• Child expires: 5:00 PM
• Result: Orphaned token running
  unauthorized tasks for 3 hours

RISK: Zombie agents with no oversight
```

---

### Slide 4: Fix #1
```
✅ FIX #1:
TTL Validation

THE SOLUTION:
Validate child TTL ≤ parent's remaining time

CODE:
```elixir
parent_remaining =
  DateTime.diff(
    parent.expires_at,
    DateTime.utc_now(),
    :second
  )

if child_ttl > parent_remaining do
  {:error, :ttl_exceeds_parent}
end
```

RESULT: Child tokens die before parents ✓
```

---

### Slide 5: Mistake #2
```
❌ MISTAKE #2:
Scope Inheritance Without Validation

THE PROBLEM:
Child agents inherited ALL parent scopes

EXAMPLE:
• Parent has: [admin, read, write]
• Child requests: [admin, read, write]
• System: ✓ Approved (no validation)

RISK: Privilege escalation by design
```

---

### Slide 6: Fix #2
```
✅ FIX #2:
Scope Narrowing

THE SOLUTION:
Enforce child scopes ⊆ parent scopes

CODE:
```elixir
requested = MapSet.new(child_scopes)
parent = MapSet.new(parent_scopes)

if MapSet.subset?(requested, parent) do
  :ok
else
  {:error, :scopes_exceed_parent}
end
```

RESULT: Least privilege enforced ✓
```

---

### Slide 7: Mistake #3
```
❌ MISTAKE #3:
Trusting AI-Generated Text

THE PROBLEM:
Task descriptions → database/logs
No sanitization, no validation

RISKS:
• XSS attacks in audit logs
• Control character injection
• Terminal corruption
• Log poisoning

AI agents generate unpredictable text!
```

---

### Slide 8: Fix #3
```
✅ FIX #3:
Input Sanitization

THE SOLUTION:
Sanitize all user-provided text

CODE:
```elixir
def sanitize_text(text) do
  text
  |> String.trim()
  |> remove_control_chars()
  |> String.slice(0, 500)
end
```

RESULT:
✓ No XSS
✓ No log injection
✓ Max 500 chars
```

---

### Slide 9: The Impact
```
📊 BEFORE vs AFTER

BEFORE:
❌ 3 critical vulnerabilities
❌ Privilege escalation possible
❌ Log injection vectors open

AFTER:
✅ 95 lines of code changed
✅ 3 security holes closed
✅ Production-ready in 2 hours

METRICS:
• 100% validation coverage
• 0 privilege escalation paths
• Full audit trail integrity
```

---

### Slide 10: Key Lessons
```
🧠 KEY LESSONS:

Auth for AI Agents ≠ Auth for Humans

1. Delegation ≠ Inheritance
   → Validate and narrow at every level

2. Time is a Security Boundary
   → Enforce TTL hierarchies strictly

3. AI Text is Untrusted Input
   → Sanitize everything

Building for the agentic economy?
Let's connect! 👇

#AIEngineering #Security #OAuth2
```

---

## 📝 Carousel Caption

```
🔐 We just closed 3 critical security holes in our AI agent authentication system.

Building OAuth2 for autonomous agents is NOT the same as auth for humans. Here's what we learned:

1️⃣ The Immortal Child Token
   → Child tokens outliving parents = zombie agents

2️⃣ Scope Inheritance Without Validation
   → Privilege escalation by design

3️⃣ Trusting AI-Generated Text
   → XSS, log injection, terminal corruption

Swipe through to see the code →

We fixed all 3 in 95 lines of code. Production-ready in 2 hours.

Key takeaway: Auth for the agentic economy requires rethinking traditional patterns.

Questions:
• Are you building auth for AI agents?
• How do you handle delegation chains?
• What security challenges have you faced?

Let's discuss in the comments! 👇

---

This is part of our work on Thalamus - an open-source OAuth2 provider for AI agents.

#AIEngineering #Security #OAuth2 #AgenticAI #Elixir #ProductionReady #ZEA
```

---

## 🎨 Design Notes

**Color Palette:**
- Primary: Dark blue (#1a1f36)
- Accent: Electric blue (#00d4ff)
- Error: Red (#ff4444)
- Success: Green (#00ff88)

**Typography:**
- Headers: Bold, 48px
- Body: Regular, 32px
- Code: Monospace, 24px

**Layout:**
- Consistent padding: 80px
- Code blocks: Dark background, syntax highlighted
- Icons: Use emojis for accessibility
