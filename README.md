# Tmux LLM Assistant Plugin

A tmux plugin that opens a floating popup to interact with Claude LLM. Supports two interaction modes (command generation and Q&A) with an interactive response viewer. Responses can be automatically sent to the tmux pane that triggered the popup.

## Features

- 🚀 Floating popup at the bottom of the screen (normal mode) or centered (zoom mode)
- 🤖 Integration with Claude API (Anthropic)
- 🎯 Two interaction modes:
  - **Command mode**: Generate executable shell commands (default)
  - **Ask mode**: Get explanations and answers (prefix with `?`)
- ⌨️ Automatic response injection into the active pane
- 📋 Copy responses to clipboard
- 📝 Interactive response viewer with markdown support
- ⚙️ Configurable key binding and model selection
- 🔒 Secure API key handling via environment variable or tmux option
- 🎨 Enhanced UI with `gum` and `glow` (optional, falls back gracefully)

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
tmux set-option -g @llm-assistant-model "claude-3-5-sonnet-20241022"
```

## Usage

### Opening the Popup

- **Normal mode**: Press `prefix + l` (or your custom key binding)
  - Small popup at the bottom of the screen (80% width, 15% height)
- **Zoom mode**: Press `prefix + L` (or `prefix + <uppercase-key>`)
  - Large centered popup (90% width, 85% height) for longer interactions

### Interaction Modes

The plugin supports two modes based on your input prefix:

1. **Command Mode** (default): Generate executable shell commands

   ```
   > find all files modified in the last 7 days
   ```

   Response will be sent directly to your pane and executed.

2. **Ask Mode**: Get explanations and answers (prefix with `?`)
   ```
   > ? what is the difference between git merge and git rebase?
   ```
   Response is displayed with markdown formatting.

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

### Canceling

- Press `Ctrl+C` or `Esc` to cancel at any time
- Leave input empty and press Enter to exit

## Example Use Cases

### Generate Shell Commands (Command Mode)

```
> find all files modified in the last 7 days
```

### Ask Questions (Ask Mode)

```
> ? explain what this bash script does: [paste your code]
> ? what is the difference between git merge and git rebase?
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

- **Never commit your API key** to version control
- Use environment variables for API keys when possible
- The API key is passed as a command-line argument (visible in process list)
- Temporary files are created in `/tmp/` and cleaned up automatically

## Advanced Features

### Zoom Mode

Use `prefix + L` to open a larger, centered popup ideal for longer interactions.

### Clipboard Integration

The plugin automatically detects and uses: `pbcopy` (macOS), `xclip`/`xsel` (Linux), or tmux buffer as fallback.

## License

MIT License - feel free to modify and distribute.

## Note

This project was fully vibe coded. 🎨

## Contributing

Contributions welcome! Please feel free to submit a Pull Request.
