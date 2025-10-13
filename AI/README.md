# AI Context Management

## Quick Start for AI Agents

When starting work on this project, **READ THIS FIRST**:

```
Read /opt/openproject/AI/ai_context.yaml
```

This file contains:
- Complete project structure and philosophy
- Current implementation status across all components
- Control flow system usage patterns
- Common workflows and anti-patterns
- Immediate priorities and pending work

## For Human Developers

### When to Update ai_context.yaml

Update the context file at these milestones:
- ✅ **Major feature completion** (e.g., deploy-manager rollback flow)
- ✅ **Architecture changes** (new submodules, reorganization)
- ✅ **Critical bug fixes** that change understanding
- ✅ **Philosophy shifts** (new patterns, deprecated approaches)
- ✅ **After long conversations** that establish new context

### How to Prompt for Updates

```bash
# After significant work:
"Update ai_context.yaml - we just completed [feature/change]"

# Periodic refresh:
"Review ai_context.yaml and update any stale sections"

# Before ending session:
"Update the AI context with what we accomplished today"
```

### Update Checklist

When updating, ensure these sections are current:
- [ ] `last_updated` timestamp
- [ ] `implementation_status` for affected components
- [ ] `immediate_todos` (remove completed, add new)
- [ ] `current_blockers` (resolve fixed, add new)
- [ ] `recent_changes` log entry

## Conversation Summarization Performance

**Issue**: AI takes a long time to summarize conversations.

**Your options**:

1. **Start fresh conversations** at logical breakpoints
   - End conversation after major milestone
   - New conversation = no summarization needed
   
2. **Provide explicit context** instead of relying on history
   - "We're working on deploy-manager rollback flow"
   - "Last session we completed diagram generation"
   
3. **Use ai_context.yaml as handoff**
   - Update context at end of session
   - New AI reads context, skips conversation history
   
4. **Accept the delay** for continuity
   - Summarization ensures nothing is lost
   - Worth it for complex, multi-session work

**Recommended workflow**:
```
Long session → Update ai_context.yaml → End conversation
New session → AI reads ai_context.yaml → Fresh start
```

This keeps each conversation focused and avoids summarization overhead.
