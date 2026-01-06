# Instructions for Claude Code

This file provides context and guidelines for AI assistants (like Claude Code) working on this project.

## Project Overview

**tmux-llm-assistant** is a tmux plugin that provides floating popup-based access to Claude LLM with two distinct modes:
- **Command mode** (`prefix + l`): Quick shell command generation
- **Ask mode** (`prefix + L`): Detailed Q&A and explanations

The plugin uses bash scripting, tmux session management, and real-time SSE streaming from Claude's API.

## Architecture

### Core Files

1. **llm-assistant.tmux** - Main plugin entry point
   - Handles key bindings and initialization
   - Creates popup sessions with floax-style toggle pattern
   - Manages session naming: `llm-cmd-<pane_id>` and `llm-ask-<pane_id>`

2. **scripts/llm-popup.sh** - UI and interaction loop
   - Input prompts with mode-specific headers
   - Special commands: `/r` (reset), `/h` (history)
   - Response viewer with action keys
   - Conversation history management

3. **scripts/claude-api.sh** - Claude API integration
   - SSE streaming implementation
   - Real-time response parsing
   - Conversation history tracking in JSON format

## Key Design Patterns

### Floax-Style Popup Toggle
Inspired by [tmux-floax](https://github.com/omerxx/tmux-floax):
```bash
tmux popup -E "tmux attach-session -t llm-cmd-%0"
```
- Persistent sessions that survive popup toggles
- Marker files prevent duplicate popups
- Detaching from inside closes popup via `-E` flag

### Real-Time Streaming
Uses `unbuffer` (from expect package) to prevent output buffering:
```bash
unbuffer bash claude-api.sh | # character-by-character output
```
Without unbuffer, shell pipes buffer ~4KB before flushing.

### Per-Pane Isolation
Each tmux pane gets independent sessions:
- Pane `%0`: `llm-cmd-%0`, `llm-ask-%0`
- Pane `%1`: `llm-cmd-%1`, `llm-ask-%1`

## Development Guidelines

### When Making Changes

1. **Test streaming**: Ensure `unbuffer` is always used for API calls
2. **Maintain toggle pattern**: Preserve floax-style session management
3. **Keep modes separate**: Command and ask modes should not share sessions
4. **Clean command output**: Strip markdown from command mode responses
5. **Preserve history**: Don't break conversation persistence

### Code Style

- Use `local` for function variables
- Quote all shell variables: `"$variable"`
- Use `$(command)` instead of backticks
- Prefer `[[ ]]` over `[ ]` for conditionals
- Add comments for non-obvious logic

### Testing Changes

After modifications, test:
1. Streaming works in real-time (no buffering)
2. Toggle behavior (open/close/reopen)
3. Both command and ask modes
4. Special commands (`/r`, `/h`)
5. Conversation history persistence
6. Per-pane session isolation

### Critical Paths

**DO NOT break these:**
- `unbuffer bash claude-api.sh` - Required for streaming
- Session naming: `llm-cmd-<pane_id>` and `llm-ask-<pane_id>`
- Marker files: `/tmp/llm_popup_active_*`
- History files: `/tmp/llm_history_<pane_id>.json`
- Popup command: `tmux popup -E "tmux attach-session ..."`

## Common Tasks

### Adding a New Special Command

Edit `scripts/llm-popup.sh`:
```bash
elif [[ "$user_input" =~ ^/?newcmd$ ]]; then
    # Handle command
    continue
fi
```

### Changing Popup Size

Edit `llm-assistant.tmux` in `toggle_llm_popup()`:
```bash
local width="80%"
local height="15%"
```

### Modifying Streaming Behavior

Edit `scripts/claude-api.sh` in the SSE parsing section:
```bash
"content_block_delta")
    text_delta=$(echo "$json_data" | jq -r '.delta.text // empty')
    printf "%s" "$text_delta"  # Must use printf, not echo
    ;;
```

### Adding New Key Bindings

Edit `llm-assistant.tmux` at bottom:
```bash
tmux bind-key "$KEY" run-shell "bash $CURRENT_DIR/llm-assistant.tmux toggle_llm_popup normal"
```

## Debugging

### Check Session Status
```bash
tmux list-sessions | grep llm
```

### View History
```bash
jq . /tmp/llm_history_%0.json
```

### Check Marker Files
```bash
ls -la /tmp/llm_popup_active_*
```

### Test Streaming Directly
```bash
bash scripts/claude-api.sh "$CLAUDE_API_KEY" "claude-opus-4-5-20251101" "command" "test" "/tmp/test.json" "16384"
```

## Dependencies

### Required
- tmux 3.0+ (for `display-popup`)
- bash 4.0+
- curl
- jq
- expect (provides `unbuffer`)

### Optional
- gum (enhanced UI)
- glow (markdown rendering)

## API Considerations

- Rate limits handled by API key tier
- No token counting implemented
- Streaming enabled by default
- Max tokens: 16384 (configurable)

## Security Notes

### Security Improvements Implemented

✅ **API Key Protection**
- API key passed via tmux session environment (`-e` flag)
- Not visible in `ps` output (environment variables are process-private)
- No temporary key files needed
- Simple and secure approach

✅ **File Permissions**
- All temp files created with 600 permissions (owner only)
- History files: 600 permissions on creation
- Marker files: 600 permissions
- Pane ID files: 600 permissions

✅ **Secure Cleanup**
- EXIT trap ensures temp files are removed
- INT and TERM signals also trigger cleanup
- Automatic cleanup on all exit paths

### Remaining Considerations

⚠️ **Conversation History**
- Stored unencrypted in `/tmp/llm_history_<pane_id>.json`
- Protected by 600 permissions (owner read/write only)
- Persists across sessions (by design for continuity)
- Use `/r` command to clear sensitive conversations

⚠️ **Temporary Directory**
- Uses `/tmp/` which may be on disk or tmpfs depending on system
- On most modern systems, `/tmp` is tmpfs (RAM-based)
- Consider manual cleanup of sensitive history if needed

## When to Update README

Update README.md when:
- Adding new features or modes
- Changing key bindings or commands
- Modifying popup behavior
- Adding new special commands
- Changing dependencies

## Acknowledgments

This plugin draws inspiration from:
- [tmux-floax](https://github.com/omerxx/tmux-floax) - Popup pattern
- [charm.sh](https://charm.sh/) - UI components (gum, glow)

## Notes for Claude Code

### Before Committing Changes

**CRITICAL: Security Audit**

Before committing ANY changes, run a security audit to ensure no sensitive data is being committed:

```bash
# Check for API keys, tokens, secrets
git diff HEAD | grep -iE "(sk-ant|api[_-]?key.*=.*['\"]|password.*=|token.*=.*['\"]|secret.*=)" | grep -v "CLAUDE_API_KEY" | grep -v "# "

# Check for personal paths
git diff HEAD | grep -E "(/Users/[^/]+|/home/[^/]+)"

# Check for hardcoded credentials
git diff HEAD | grep -iE "(bearer|authorization:|x-api-key:)"
```

**Never commit:**
- ❌ Actual API keys or tokens
- ❌ Personal paths with usernames
- ❌ Hardcoded credentials
- ❌ Internal URLs or endpoints
- ❌ Test data with real user information

**CRITICAL: Developer Understanding Check**

Before committing any code changes, you MUST verify the developer understands what was changed and why. Ask questions like:

1. **Understanding Check:**
   - "Can you explain in your own words what these changes do?"
   - "What problem does this solve?"
   - "How would you debug this if it breaks?"

2. **Maintenance Check:**
   - "If I (Claude) wasn't available, could you maintain this code?"
   - "Do you understand each function/script modification?"
   - "Can you trace the data flow through the changes?"

3. **Testing Verification:**
   - "Have you tested these changes?"
   - "What scenarios did you test?"
   - "Do you know how to test this without AI assistance?"

**Only commit if:**
- ✅ Developer demonstrates clear understanding of the changes
- ✅ Developer can explain the logic without AI help
- ✅ Developer knows how to debug/maintain the code
- ✅ Developer has tested or knows how to test the changes

**Do NOT commit if:**
- ❌ Developer just says "looks good" without explanation
- ❌ Developer can't explain what the code does
- ❌ Changes are too complex for developer to understand
- ❌ Developer hasn't reviewed the changes carefully

**Why this matters:**
- Code must be maintainable without AI assistance
- Developer needs to fix bugs independently
- Long-term maintenance requires human understanding
- Blind trust in AI-generated code creates technical debt

### General Guidelines

- Always test changes before committing
- Preserve backward compatibility where possible
- Document breaking changes clearly
- Keep commit messages descriptive
- Include token usage in commit stats
- This is a user-facing tool - prioritize UX
