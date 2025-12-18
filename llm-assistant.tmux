#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

get_key() {
    local key=$(tmux show-option -gqv "@llm-assistant-key")
    [ -z "$key" ] && key="L"
    echo "$key"
}

get_api_key() {
    echo "${CLAUDE_API_KEY:-$(tmux show-option -gqv "@llm-assistant-api-key")}"
}

get_model() {
    local model=$(tmux show-option -gqv "@llm-assistant-model")
    [ -z "$model" ] && model="claude-opus-4-5-20251101"
    echo "$model"
}

open_llm_popup() {
    local mode="${1:-normal}" # Default to normal
    local api_key=$(get_api_key)
    
    if [ -z "$api_key" ]; then
        tmux display-message -d 4000 "LLM Error: CLAUDE_API_KEY not found."
        return 1
    fi
    
    local pane_id=$(tmux display-message -p "#{pane_id}")
    local model=$(get_model)
    local tmp_file=$(mktemp /tmp/tmux-llm.XXXXXX)
    echo "$pane_id" > "$tmp_file"
    
    # Set dimensions based on mode
    local width="80%"
    local height="15%"
    local pos="S" # Bottom
    
    if [ "$mode" = "zoom" ]; then
        width="90%"
        height="85%"
        pos="C" # Center for zoomed view
    fi
    
    tmux display-popup -w "$width" -h "$height" -y "$pos" -b rounded -e "PATH=$PATH" -E \
        "bash $CURRENT_DIR/scripts/llm-popup.sh '$api_key' '$tmp_file' '$model'"
}

case "${1:-}" in
    open_llm_popup) open_llm_popup "$2" ;;
    *) 
        KEY=$(get_key)
        # Standard binding (Small bar)
        tmux bind-key "$KEY" run-shell "bash $CURRENT_DIR/llm-assistant.tmux open_llm_popup normal"
        
        # Zoom binding (Large window) - e.g., if KEY is 'L', this binds 'Shift-L'
        # Check if the key is a letter to capitalize it, otherwise just use a separate bind logic
        ZOOM_KEY=$(echo "$KEY" | tr '[:lower:]' '[:upper:]')
        tmux bind-key "$ZOOM_KEY" run-shell "bash $CURRENT_DIR/llm-assistant.tmux open_llm_popup zoom"
        ;;
esac