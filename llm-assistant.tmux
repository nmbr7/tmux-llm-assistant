#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

get_key() {
    local key=$(tmux show-option -gqv "@llm-assistant-key")
    [ -z "$key" ] && key="l"
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

get_max_tokens() {
    local max_tokens=$(tmux show-option -gqv "@llm-assistant-max-tokens")
    [ -z "$max_tokens" ] && max_tokens="16384"
    echo "$max_tokens"
}

toggle_llm_popup() {
    local mode="${1:-normal}"
    local current_session=$(tmux display-message -p "#{session_name}")

    # Check if we're currently IN any LLM session (inside the popup)
    case "$current_session" in
        llm-cmd-*|llm-ask-*)
            # Extract origin pane from session name and clean up marker
            local origin_pane="${current_session#llm-*-}"
            rm -f "/tmp/llm_popup_active_cmd_${origin_pane}"
            rm -f "/tmp/llm_popup_active_ask_${origin_pane}"
            # We're inside the popup - detach to close it
            tmux detach-client
            return 0
            ;;
    esac

    # Get the origin pane from outside the popup
    local origin_pane=$(tmux display-message -p "#{pane_id}")

    # Use different session names for command vs ask mode
    if [[ "$mode" == "zoom" ]]; then
        local llm_session="llm-ask-${origin_pane}"
        local popup_marker="/tmp/llm_popup_active_ask_${origin_pane}"
    else
        local llm_session="llm-cmd-${origin_pane}"
        local popup_marker="/tmp/llm_popup_active_cmd_${origin_pane}"
    fi

    # Check if popup is already showing for this pane
    if [ -f "$popup_marker" ]; then
        # Popup already active, do nothing
        return 0
    fi

    # Check if LLM session exists for this pane
    if ! tmux has-session -t "$llm_session" 2>/dev/null; then
        # Session doesn't exist - create it
        local api_key=$(get_api_key)

        if [ -z "$api_key" ]; then
            tmux display-message -d 4000 "LLM Error: CLAUDE_API_KEY not found."
            return 1
        fi

        local model=$(get_model)
        local max_tokens=$(get_max_tokens)
        local tmp_file=$(mktemp /tmp/tmux-llm.XXXXXX)
        chmod 600 "$tmp_file"
        echo "$origin_pane" > "$tmp_file"

        # Determine session mode
        if [[ "$mode" == "zoom" ]]; then
            local session_mode="ask"
        else
            local session_mode="command"
        fi

        # Create new detached session with mode parameter
        # API key read from environment in the session (secure - not in ps output)
        tmux new-session -d -s "$llm_session" \
            -e CLAUDE_API_KEY="$api_key" \
            "bash $CURRENT_DIR/scripts/llm-popup.sh '$tmp_file' '$model' '$max_tokens' '$session_mode'"

        # Configure the window appearance
        tmux set-option -t "$llm_session" status off
    fi

    # Set popup position and size based on mode
    if [[ "$mode" == "zoom" ]]; then
        # Ask mode - larger popup for Q&A
        local width="85%"
        local height="70%"
        local x_pos="C"
        local y_pos="C"
    else
        # Command mode - small popup at bottom
        local width="80%"
        local height="15%"
        local x_pos="C"
        local y_pos="100%"
    fi

    # Mark popup as active with secure permissions
    touch "$popup_marker"
    chmod 600 "$popup_marker"

    # Show popup with session attached (floax-style)
    tmux set-option -t "$llm_session" detach-on-destroy on
    tmux popup \
        -s fg=white \
        -T " LLM Assistant " \
        -w "$width" \
        -h "$height" \
        -x "$x_pos" \
        -y "$y_pos" \
        -b rounded \
        -E \
        "tmux attach-session -t \"$llm_session\"; rm -f $popup_marker"
}

case "${1:-}" in
    toggle_llm_popup) toggle_llm_popup "$2" ;;
    *)
        KEY=$(get_key)
        # Standard binding - Toggle popup (floax-style)
        tmux bind-key "$KEY" run-shell "bash $CURRENT_DIR/llm-assistant.tmux toggle_llm_popup normal"

        # Zoom binding (Large window)
        ZOOM_KEY=$(echo "$KEY" | tr '[:lower:]' '[:upper:]')
        tmux bind-key "$ZOOM_KEY" run-shell "bash $CURRENT_DIR/llm-assistant.tmux toggle_llm_popup zoom"
        ;;
esac