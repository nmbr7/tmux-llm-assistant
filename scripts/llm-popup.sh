#!/usr/bin/env bash

API_KEY="$1"
PANE_ID_FILE="$2"
MODEL="$3"
MAX_TOKENS="${4:-16384}"
DEFAULT_MODE="${5:-command}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TARGET_PANE_ID=$(cat "$PANE_ID_FILE")
RAW_OUT="/tmp/llm_raw_res.txt"
HISTORY_FILE="/tmp/llm_history_${TARGET_PANE_ID}.json"
STATE_FILE="/tmp/llm_state_${TARGET_PANE_ID}.state"
STREAM_PID_FILE="/tmp/llm_stream_${TARGET_PANE_ID}.pid"

# Initialize empty conversation history if it doesn't exist
[ ! -f "$HISTORY_FILE" ] && echo "[]" >"$HISTORY_FILE"

# Clean up any leftover state files
rm -f "$STATE_FILE" "$STREAM_PID_FILE"

hide_popup() {
  # Save state without killing background processes
  stty echo icanon 2>/dev/null
  printf '\e[?25h'
  rm -f "$PANE_ID_FILE"
  exit 0
}

cleanup() {
  stty echo icanon 2>/dev/null
  printf '\e[?25h'
  # Kill any background streaming process
  if [ -f "$STREAM_PID_FILE" ]; then
    kill $(cat "$STREAM_PID_FILE") 2>/dev/null
    rm -f "$STREAM_PID_FILE"
  fi
  rm -f "$PANE_ID_FILE" "$STATE_FILE"
  exit 0
}
trap cleanup INT TERM

clear
# Hide cursor
printf '\e[?25l'

while true; do
  # 1. INPUT STAGE
  clear

  # Set display text based on mode
  if [[ "$DEFAULT_MODE" == "ask" ]]; then
    mode_label="ASK MODE"
    mode_color=36
    placeholder="Ask a question..."
  else
    mode_label="COMMAND MODE"
    mode_color=212
    placeholder="What's the task?"
  fi

  if command -v gum &>/dev/null; then
    gum style --padding "1 2" --foreground "$mode_color" --bold "── $mode_label ──"
    gum style --padding "0 2" --faint "/r: Reset | /h: History"
    user_input=$(gum input --placeholder "$placeholder")
    [[ $? -ne 0 || -z "$user_input" ]] && cleanup
  else
    printf "\n  ── $mode_label ──\n  (/r: Reset | /h: History)\n  > "
    read -r user_input
    [[ -z "$user_input" ]] && cleanup
  fi

  # Check for special commands
  if [[ "$user_input" =~ ^/?r(eset)?$ ]]; then
    echo "[]" >"$HISTORY_FILE"
    if command -v gum &>/dev/null; then
      gum style --padding "1 2" --foreground 212 "✓ Conversation history cleared"
      sleep 1.5
    else
      printf "\n  ✓ Conversation history cleared\n"
      sleep 1.5
    fi
    continue
  elif [[ "$user_input" =~ ^/?h(istory)?$ ]]; then
    clear
    if command -v gum &>/dev/null; then
      gum style --padding "1 2" --foreground 212 --bold "── Conversation History ──"
    else
      printf "\n  ── Conversation History ──\n\n"
    fi

    # Display conversation history
    if [ -f "$HISTORY_FILE" ]; then
      history_display=$(jq -r '.[] | select(.role == "user") | .content' "$HISTORY_FILE" 2>/dev/null | nl -w2 -s". " || echo "No history found")
      if [ -n "$history_display" ]; then
        echo "$history_display" | sed 's/^/    /'
      else
        echo "    No history found"
      fi
    else
      echo "    No history found"
    fi

    printf "\n    Press any key to continue..."
    read -n 1 -s
    continue
  fi

  # Use the default mode for this session
  mode="$DEFAULT_MODE"
  p="$user_input"

  # Set color based on mode
  if [[ "$mode" == "ask" ]]; then
    color=36
  else
    color=212
  fi

  # 2. THINKING STAGE (with progressive streaming)
  clear
  if command -v gum &>/dev/null; then
    gum style --padding "1 2" --foreground "$color" "── Mode: ${mode^^} ──"
    gum style --padding "0 2" --faint "Streaming response..."
  else
    printf "\n  Processing ($mode)...\n"
  fi

  # Stream with real-time display
  printf "\n  "

  unbuffer bash "$SCRIPT_DIR/claude-api.sh" "$API_KEY" "$MODEL" "$mode" "$p" "$HISTORY_FILE" "$MAX_TOKENS" 2>&1
  api_exit_code=$?

  # Save the result to RAW_OUT from history
  if [ -f "$HISTORY_FILE" ]; then
    raw_res=$(jq -r '.[-1].content // empty' "$HISTORY_FILE" 2>/dev/null || echo "")
    echo "$raw_res" >"$RAW_OUT"
  else
    echo "" >"$RAW_OUT"
    api_exit_code=1
  fi

  # Check if API call succeeded
  if [ ! -f "$RAW_OUT" ] || [ ! -s "$RAW_OUT" ]; then
    echo "Error: API call failed" >&2
    sleep 2
    continue
  fi

  raw_res=$(cat "$RAW_OUT")

  # Clean command output in command mode (strip markdown, extra whitespace)
  if [ "$mode" = "command" ]; then
    # Remove markdown code fences and extract just the command
    raw_res=$(echo "$raw_res" | sed -e 's/^```.*$//' -e 's/^```$//' | sed '/^$/d' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  fi

  # Pause briefly before transitioning to review
  sleep 0.5

  # 3. RESPONSE / REVIEW STAGE
  while true; do
    clear

    # Command mode: simple display
    if [ "$mode" = "command" ]; then
      if command -v gum &>/dev/null; then
        gum style --padding "1 2" --foreground "$color" "── Command ──"
      else
        printf "\n  ── Command ──\n"
      fi
      # Show just the command, no formatting
      printf "\n  %s\n\n" "$raw_res"
    else
      # Ask/Pair mode: full formatted display
      if command -v gum &>/dev/null; then
        gum style --padding "0 2" --foreground "$color" "── Response ($mode) ──"
      fi

      # Rendering with markdown
      if command -v glow &>/dev/null; then
        echo "$raw_res" | glow -s dark - | sed 's/^/    /' | less -FXR
      else
        echo "$raw_res" | sed 's/^/    /' | less -FXR
      fi
    fi

    # Navigation Bar
    printf "\n    \033[1;32m[Enter]\033[0m Action    \033[1;33m[c]\033[0m Copy    \033[1;34m[q]\033[0m Edit    \033[1;35m[r]\033[0m Reset    \033[1;31m[Esc]\033[0m Exit\n"

    # Key Capture
    stty -echo -icanon
    char=$(dd bs=1 count=1 2>/dev/null)
    stty echo icanon
    case "$char" in
    "c" | "C")
      # Clipboard Detection and Execution
      if command -v pbcopy &>/dev/null; then
        echo "$raw_res" | pbcopy
        msg="Copied to macOS clipboard"
      elif command -v xclip &>/dev/null; then
        echo "$raw_res" | xclip -selection clipboard
        msg="Copied to clipboard (xclip)"
      elif command -v xsel &>/dev/null; then
        echo "$raw_res" | xsel --clipboard --input
        msg="Copied to clipboard (xsel)"
      elif [ -n "$TMUX" ]; then
        echo "$raw_res" | tmux load-buffer -
        msg="Copied to tmux buffer"
      else
        msg="Error: No clipboard utility found"
      fi

      # Visual Feedback
      if command -v gum &>/dev/null; then
        gum toast "$msg"
      else
        printf "\n    \033[1;33m$msg\033[0m"
        sleep 1
      fi
      ;;

    $'\x0a' | $'\x0d' | "")
      # Send to Target Pane
      if [ "$mode" = "command" ] && [[ ! "$raw_res" =~ ^Error ]] && [[ ! "$raw_res" =~ ^API\ Error ]]; then
        # raw_res is already cleaned, send it directly
        tmux send-keys -t "$TARGET_PANE_ID" -l "$raw_res"
        tmux send-keys -t "$TARGET_PANE_ID" Enter
      fi
      cleanup
      ;;

    "q" | "Q")
      # Go back to input stage (preserves conversation history)
      break
      ;;

    "r" | "R")
      # Reset conversation history
      echo "[]" >"$HISTORY_FILE"
      if command -v gum &>/dev/null; then
        gum toast "Conversation history cleared"
      else
        printf "\n    \033[1;35mConversation history cleared\033[0m"
        sleep 1
      fi
      # Go back to input stage
      break
      ;;

    $'\e')
      # Escape key to exit
      cleanup
      ;;
    esac
  done
done

