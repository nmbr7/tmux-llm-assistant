# Tmux LLM Assistant Plugin

A tmux plugin that provides floating popup-based access to Claude LLM with dedicated command and Q&A modes. Features real-time streaming responses, persistent conversation history, and seamless integration with your tmux workflow.

## Features

- 🚀 **Dual-Mode Operation**:
  - **Command mode** (`prefix + l`): Small bottom popup optimized for quick shell commands

      <img width="5120" height="2880" alt="image" src="https://github.com/user-attachments/assets/44bdf0aa-c786-4c98-9885-afe44942efd3" />

  - **Ask mode** (`prefix + L`): Larger centered popup for detailed Q&A

      <img width="5120" height="2880" alt="image" src="https://github.com/user-attachments/assets/66c617ef-4f95-49eb-afd2-bfa2d71f5f6f" />

- 🎯 **Separate Sessions**: Independent conversation contexts for command and ask modes
- 📡 **Real-Time Streaming**: See Claude's response as it's generated (no buffering)
- 💾 **Persistent History**: Per-pane conversation memory that survives popup toggles
- ⌨️ **Smart Command Injection**: Commands automatically sent to your active pane
- 📋 **Clipboard Integration**: Copy responses with a single key press
- 🎨 **Enhanced UI**: Optional `gum` and `glow` support for beautiful formatting
- 🔧 **Special Commands**:
  - `/r` or `/reset`: Clear conversation history
  - `/h` or `/history`: View previous queries
- ⚙️ **Configurable**: Custom key bindings and model selection
- 🔒 **Secure**: API key via environment variable or tmux option

> **Inspired by [tmux-floax](https://github.com/omerxx/tmux-floax)** - Popup toggle pattern adapted from floax's elegant session management approach.

## Prerequisites

- tmux 3.0 or higher (for `display-popup` support)
- `curl` command-line tool
- `jq` for JSON processing
- Claude API key from [Anthropic](https://console.anthropic.com/)
- **Optional but recommended**: `gum` for enhanced UI and `glow` for markdown rendering

## Installation

### Option 1: Manual Installation

1. Clone or download this repository:

```bash
cd ~/.tmux/plugins
git clone <your-repo-url> tmux-llm-assistant
# OR if you have it locally:
cp -r /path/to/tmux-llm-assistant ~/.tmux/plugins/
```

2. Make scripts executable:

```bash
chmod +x ~/.tmux/plugins/tmux-llm-assistant/llm-assistant.tmux
chmod +x ~/.tmux/plugins/tmux-llm-assistant/scripts/*.sh
```

3. Add to your `~/.tmux.conf`:

```bash
# Load the plugin
run-shell ~/.tmux/plugins/tmux-llm-assistant/llm-assistant.tmux
```

4. Reload tmux configuration:

```bash
tmux source-file ~/.tmux.conf
```

### Option 2: Using TPM (Tmux Plugin Manager)

If you use [TPM](https://github.com/tmux-plugins/tpm), add this to your `~/.tmux.conf`:

```bash
set -g @plugin 'your-username/tmux-llm-assistant'
```

Then press `prefix + I` to install.

## Configuration

### 1. Set Your Claude API Key

**Option A: Environment Variable (Recommended)**

```bash
export CLAUDE_API_KEY="your-api-key-here"
```

Add this to your `~/.bashrc`, `~/.zshrc`, or shell profile to make it persistent.

**Option B: Tmux Option**

```bash
tmux set-option -g @llm-assistant-api-key "your-api-key-here"
```

Add this to your `~/.tmux.conf` to make it persistent.

### 2. Customize Key Binding (Optional)

Default key binding is `prefix + l` (normal) and `prefix + L` (zoom). To change it:

```bash
tmux set-option -g @llm-assistant-key "a"  # Use prefix + a (normal) and prefix + A (zoom)
```

Add to `~/.tmux.conf` to make it persistent.

### 3. Change Claude Model (Optional)

Default model is `claude-opus-4-5-20251101`. To use a different model:

```bash
tmux set-option -g @llm-assistant-model "claude-opus-4-5-20251101"
```

## Usage

### Two Dedicated Modes

The plugin provides two independent interaction modes, each with its own session and conversation history:

#### Command Mode (`prefix + l`)
- Small popup at bottom (15% height)
- Optimized for quick shell commands
- Responses automatically sent to your active pane
- Session: `llm-cmd-<pane_id>`

**Example:**
```
> find all files modified in the last 7 days
```
Output: `find . -mtime -7` (automatically injected into your pane)

#### Ask Mode (`prefix + L`)
- Larger centered popup (70% height)
- Perfect for Q&A and explanations
- Markdown-formatted responses
- Session: `llm-ask-<pane_id>`

**Example:**
```
> what is the difference between git merge and git rebase?
```
Output: Detailed explanation with formatting

### Toggle Behavior (Floax-Style)

Press the same key to open/close the popup:
- First press: Opens popup with new or existing session
- Second press (inside popup): Closes popup (session persists)
- Third press: Reopens popup with conversation history intact

**Benefits:**
- ✅ **Real-time streaming** - See responses as they're generated
- ✅ **Persistent sessions** - Conversation context preserved across toggles
- ✅ **Per-pane isolation** - Each pane gets its own command and ask sessions
- ✅ **Full tmux features** - Scrollback, copy mode, search all work perfectly

### Special Commands

Available in both modes:

- **`/r` or `/reset`**: Clear conversation history for current mode
- **`/h` or `/history`**: View all previous queries in current session

Type these at the input prompt to use them.

### Response Viewer

After Claude responds, you'll see an interactive viewer using `less` pager:

**Navigation in the response viewer:**

- Use arrow keys, Page Up/Down, or vim keys (`j`/`k`, `Space`/`b`) to scroll through the response
- The response is displayed with markdown formatting (if `glow` is installed) or plain text

**Action keys (shown at bottom of viewer):**

- **[Enter]**: Execute/send the response to your pane (command mode only)
- **[c]**: Copy response to clipboard
- **[q]**: Go back to input stage to ask another question
- **[Esc]**: Exit the popup completely

### Conversation History & Persistence

**Independent History per Mode:**

- Each mode (command/ask) maintains its own conversation history
- Command mode: `/tmp/llm_history_<pane_id>.json`
- Ask mode: Separate history file per session
- History persists across popup toggles - context is preserved
- Use `/r` to reset history, `/h` to view past queries
- **[q]** key in response viewer goes back to input while preserving history

**Workflow:**
1. Open popup (`prefix + l` or `prefix + L`)
2. Ask questions, see streaming responses
3. Close popup anytime (press key again or `Ctrl+C`)
4. Do other work...
5. Reopen same popup - conversation history intact
6. Ask follow-up questions referencing previous context

### Action Keys in Response Viewer

After Claude responds:

- **[Enter]**: Execute/send response (command mode) or dismiss (ask mode)
- **[c]**: Copy response to clipboard
- **[q]**: Back to input (preserves history)
- **[r]**: Reset conversation history
- **[Esc]**: Exit popup completely

### Exiting

- Press the bound key again (inside popup) to close
- `Ctrl+C` or `Esc` to force exit
- Leave input empty and press Enter to exit

## Example Use Cases

### Command Mode Examples

```
> find all files modified in the last 7 days
> show disk usage sorted by size
> kill all processes using port 8080
> create a tar archive of the logs directory
```

### Ask Mode Examples

```
> explain what this bash script does: [paste your code]
> what is the difference between git merge and git rebase?
> how do I optimize Docker build times?
> explain the tmux copy mode workflow
```

## Troubleshooting

### "LLM Error: CLAUDE_API_KEY not found."

- Make sure you've set the API key using one of the methods above
- Verify the key is accessible: `echo $CLAUDE_API_KEY`
- Check tmux option: `tmux show-option -gqv "@llm-assistant-api-key"`

### "Network Error: ..."

- Check your internet connection
- Verify curl is working: `curl -I https://api.anthropic.com`
- Check firewall/proxy settings

### "API Error (HTTP_CODE): ..."

- HTTP 401: Invalid API key - verify your key is correct
- HTTP 429: Rate limit exceeded - wait and try again
- HTTP 400: Invalid request - check if model name is correct
- Check Claude API status: https://status.anthropic.com/
- Verify your API key has the correct permissions and credits

### Popup doesn't appear

- Ensure you're using tmux 3.0+
- Verify the plugin is loaded: `tmux list-keys | grep llm`
- Check that scripts are executable: `chmod +x scripts/*.sh`

### Response not appearing in pane

- Check if the target pane is still active
- Note: Only command mode responses are sent to the pane automatically

### Missing `jq` error

- Install `jq`: `brew install jq` (macOS) or `apt-get install jq` (Linux)

### Enhanced UI not working

- Install `gum` for better UI: `brew install gum` (macOS) or see [gum installation](https://github.com/charmbracelet/gum)
- Install `glow` for markdown rendering: `brew install glow` (macOS) or see [glow installation](https://github.com/charmbracelet/glow)
- The plugin works without these, but with a simpler interface

## File Structure

```
tmux-llm-assistant/
├── llm-assistant.tmux      # Main plugin file
├── scripts/
│   ├── llm-popup.sh        # Popup handler script
│   └── claude-api.sh       # Claude API integration
└── README.md
```

## Security Notes

### Best Practices

- **Never commit your API key** to version control
- Use environment variables for API keys (recommended)
- API keys passed via tmux session environment (not visible in `ps`)
- All temporary files have 600 permissions (owner read/write only)

### Security Features

✅ **API Key Protection**
- API key passed via tmux session environment (not command args)
- Not visible in process list (`ps` output)
- Simple and secure - uses tmux's `-e` flag

✅ **File Security**
- All temp files created with 600 permissions (owner only)
- History files protected from other users
- Marker files have restricted access
- Automatic cleanup on exit via trap handlers

⚠️ **Important Notes**
- Conversation history stored unencrypted in `/tmp/`
- History persists across sessions (by design for continuity)
- Use `/r` command to clear sensitive conversations
- Consider manual cleanup: `rm /tmp/llm_history_*` if needed

## Advanced Features

### Clipboard Integration

The plugin automatically detects and uses the best available clipboard method:
- `pbcopy` (macOS)
- `xclip` or `xsel` (Linux)
- tmux buffer (fallback)

### Command Output Cleaning

Command mode automatically strips markdown code blocks and extra formatting from Claude's responses, ensuring clean commands ready for execution.

### Session Isolation

Each pane maintains independent command and ask sessions:
- `llm-cmd-%0`, `llm-ask-%0` for pane `%0`
- `llm-cmd-%1`, `llm-ask-%1` for pane `%1`
- etc.

This allows different workflows in different panes without context mixing.

## Acknowledgments

- **[tmux-floax](https://github.com/omerxx/tmux-floax)** - Inspired the popup toggle pattern and session management approach
- **[Anthropic Claude](https://www.anthropic.com/claude)** - Powering the LLM interactions
- **[charm.sh](https://charm.sh/)** - `gum` and `glow` for beautiful terminal UI

## License

MIT License - feel free to modify and distribute.

## Contributing

Contributions welcome! Please feel free to submit a Pull Request.

---

**Note:** This project was fully vibe coded. 🎨
