#!/usr/bin/env bash

API_KEY="$1"
PANE_ID_FILE="$2"
MODEL="$3"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TARGET_PANE_ID=$(cat "$PANE_ID_FILE")
RAW_OUT="/tmp/llm_raw_res.txt"
HISTORY_FILE="/tmp/llm_history_${TARGET_PANE_ID}.json"

# Initialize empty conversation history
echo "[]" > "$HISTORY_FILE"

cleanup() {
    stty echo icanon 2>/dev/null
    printf '\e[?25h'
    rm -f "$PANE_ID_FILE" "$RAW_OUT" "$HISTORY_FILE"
    exit 0
}
trap cleanup INT TERM

clear
# Hide cursor
printf '\e[?25l'

while true; do
    # 1. INPUT STAGE
    clear
    if command -v gum &> /dev/null; then
        gum style --padding "1 2" --foreground 212 --bold "── LLM Assistant ──"
        gum style --padding "0 2" --faint "Enter: Command | ?: Ask"
        user_input=$(gum input --placeholder "What's the task?")
        [[ $? -ne 0 || -z "$user_input" ]] && cleanup
    else
        printf "\n  ── LLM Assistant ──\n  > "
        read -r user_input
        [[ -z "$user_input" ]] && cleanup
    fi

    # Mode detection
    if [[ "$user_input" =~ ^\? ]]; then
        mode="ask"; color=36; p="${user_input#\?}"
    else
        mode="command"; color=212; p="$user_input"
    fi

    # 2. THINKING STAGE
    clear
    if command -v gum &> /dev/null; then
        gum style --padding "1 2" --foreground "$color" "── Mode: ${mode^^} ──"
        gum spin --spinner dot --title "  Claude is thinking..." -- \
            bash -c "bash '$SCRIPT_DIR/claude-api.sh' '$API_KEY' '$MODEL' '$mode' '$p' '$HISTORY_FILE' > '$RAW_OUT' 2>&1"
    else
        printf "\n  Processing ($mode)...\n"
        bash "$SCRIPT_DIR/claude-api.sh" "$API_KEY" "$MODEL" "$mode" "$p" "$HISTORY_FILE" > "$RAW_OUT" 2>&1
    fi

    raw_res=$(cat "$RAW_OUT")

    # 3. RESPONSE / REVIEW STAGE
    while true; do
        clear
        if command -v gum &>/dev/null; then
            gum style --padding "0 2" --foreground "$color" "── Response ($mode) ──"
        fi

        # Rendering
        if command -v glow &>/dev/null; then
            echo "$raw_res" | glow -s dark - | sed 's/^/    /' | less -FXR
        else
            echo "$raw_res" | sed 's/^/    /' | less -FXR
        fi

        # Navigation Bar
        printf "\n    \033[1;32m[Enter]\033[0m Action    \033[1;33m[c]\033[0m Copy    \033[1;34m[q]\033[0m Edit    \033[1;35m[r]\033[0m Reset    \033[1;31m[Esc]\033[0m Exit\n"

        # Key Capture
        stty -echo -icanon; char=$(dd bs=1 count=1 2>/dev/null); stty echo icanon
        case "$char" in
            "c"|"C")
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

            $'\x0a'|$'\x0d'|"")
                # Send to Target Pane
                if [ "$mode" = "command" ] && [[ ! "$raw_res" =~ ^Error ]] && [[ ! "$raw_res" =~ ^API\ Error ]]; then
                    # Trim leading/trailing whitespace but preserve quotes
                    clean_cmd=$(echo "$raw_res" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    tmux send-keys -t "$TARGET_PANE_ID" -l "$clean_cmd"
                    tmux send-keys -t "$TARGET_PANE_ID" Enter
                fi
                cleanup ;;
                
            "q"|"Q")
                # Go back to input stage (preserves conversation history)
                break ;;
                
            "r"|"R")
                # Reset conversation history
                echo "[]" > "$HISTORY_FILE"
                if command -v gum &>/dev/null; then
                    gum toast "Conversation history cleared"
                else
                    printf "\n    \033[1;35mConversation history cleared\033[0m"
                    sleep 1
                fi
                # Go back to input stage
                break ;;
                
            $'\e')
                # Escape key to exit
                cleanup ;;
        esac
    done
done