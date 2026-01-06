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

- API key passed as command argument (visible in `ps`)
- History stored in `/tmp/` (user-readable only)
- No encryption of conversation history
- Marker files use predictable names
- API key never written to disk by plugin

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

- Always test changes before committing
- Preserve backward compatibility where possible
- Document breaking changes clearly
- Keep commit messages descriptive
- Include token usage in commit stats
- This is a user-facing tool - prioritize UX
