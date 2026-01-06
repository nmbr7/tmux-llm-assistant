#!/usr/bin/env bash

# Disable output buffering for real-time streaming
exec 2>&1
stty -icanon min 1 time 0 2>/dev/null || true

API_KEY="$1"
MODEL="${2:-claude-opus-4-5-20251101}"
MODE="${3:-command}"
PROMPT="$4"
HISTORY_FILE="${5:-}"
MAX_TOKENS="${6:-16384}"

if [ -z "$API_KEY" ] || [ -z "$PROMPT" ]; then
    echo "Error: API key and prompt are required"
    exit 1
fi

# Set system prompt
if [ "$MODE" = "pair" ]; then
    SYSTEM_PROMPT="You are an elite Pair Programmer. Identify bugs and suggest idiomatic code. Use Markdown."
elif [ "$MODE" = "ask" ]; then
    SYSTEM_PROMPT="You are a technical educator. Provide clear explanations in Markdown."
else
    SYSTEM_PROMPT="You are a terminal command generator. Respond with the EXECUTABLE COMMAND ONLY. No markdown."
fi

# Load conversation history if it exists
if [ -n "$HISTORY_FILE" ] && [ -f "$HISTORY_FILE" ]; then
    # Read existing messages from history file
    existing_messages=$(cat "$HISTORY_FILE" 2>/dev/null || echo "[]")
else
    existing_messages="[]"
fi

# Build messages array: existing messages + new user message
messages=$(echo "$existing_messages" | jq --arg user "$PROMPT" '. + [{role: "user", content: $user}]')

# Non-streaming API call (fallback)
non_streaming_api_call() {
    # Build JSON payload without streaming
    json_payload=$(jq -n \
        --arg model "$MODEL" \
        --arg system "$SYSTEM_PROMPT" \
        --argjson messages "$messages" \
        --argjson max_tokens "$MAX_TOKENS" \
        '{model: $model, max_tokens: $max_tokens, system: $system, messages: $messages}')

    # API call - capturing stderr to a variable to catch network/curl errors
    error_log=$(mktemp)
    response=$(curl -s -w "\n%{http_code}" -X POST https://api.anthropic.com/v1/messages \
      -H "x-api-key: $API_KEY" \
      -H "anthropic-version: 2023-06-01" \
      -H "Content-Type: application/json" \
      -d "$json_payload" 2>"$error_log")
    curl_exit_code=$?

    http_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | sed '$d')

    if [ $curl_exit_code -ne 0 ]; then
        echo "Network Error: $(cat "$error_log")"
        rm -f "$error_log"
        return 1
    fi

    if [ "$http_code" != "200" ]; then
        # This will catch "invalid model" errors
        err=$(echo "$response_body" | jq -r '.error.message' 2>/dev/null || echo "$response_body")
        echo "API Error ($http_code): $err"
        rm -f "$error_log"
        return 1
    fi

    # Extract assistant response
    assistant_response=$(echo "$response_body" | jq -r '.content[0].text')
    rm -f "$error_log"

    echo "$assistant_response"
    return 0
}

# Streaming API call with SSE parsing
streaming_api_call() {
    # Build JSON payload with streaming enabled
    json_payload=$(jq -n \
        --arg model "$MODEL" \
        --arg system "$SYSTEM_PROMPT" \
        --argjson messages "$messages" \
        --argjson max_tokens "$MAX_TOKENS" \
        '{model: $model, max_tokens: $max_tokens, stream: true, system: $system, messages: $messages}')

    # Temporary files for headers and errors
    headers_file=$(mktemp)
    error_log=$(mktemp)
    accumulated_file=$(mktemp)

    # SSE parser function
    parse_sse_stream() {
        local accumulated_response=""
        local has_error=false
        local error_message=""
        local stream_started=false
        local content_blocks_stopped=0

        while IFS= read -r -t 120 line || break; do
            # Skip empty lines and comments
            [[ -z "$line" || "$line" =~ ^: ]] && continue

            # Extract JSON data from "data: {...}" lines
            if [[ "$line" =~ ^data:\ (.*)$ ]]; then
                json_data="${BASH_REMATCH[1]}"

                # Check for stream end marker
                if [[ "$json_data" == "[DONE]" ]]; then
                    break
                fi

                # Parse event type
                event_type=$(echo "$json_data" | jq -r '.type // empty' 2>/dev/null)

                case "$event_type" in
                    "message_start")
                        stream_started=true
                        ;;

                    "content_block_start")
                        stream_started=true
                        ;;

                    "content_block_delta")
                        # Extract text delta and output immediately for streaming
                        text_delta=$(echo "$json_data" | jq -r '.delta.text // empty' 2>/dev/null)
                        if [ -n "$text_delta" ]; then
                            printf "%s" "$text_delta"
                            accumulated_response+="$text_delta"
                        fi
                        ;;

                    "content_block_stop")
                        ((content_blocks_stopped++))
                        # Don't break - wait for message_stop
                        ;;

                    "message_delta")
                        # Message metadata update, continue
                        :
                        ;;

                    "message_stop")
                        # Stream complete - this is the proper end signal
                        break
                        ;;

                    "error")
                        # API error during streaming
                        has_error=true
                        error_message=$(echo "$json_data" | jq -r '.error.message // "Unknown error"' 2>/dev/null)
                        break
                        ;;
                esac
            fi
        done

        # Store accumulated response for history
        echo "$accumulated_response" > "$accumulated_file"

        if [ "$has_error" = true ]; then
            echo "Stream Error: $error_message" >&2
            return 1
        fi

        # Check if we got any content
        if [ -z "$accumulated_response" ] && [ "$stream_started" = true ]; then
            echo "Warning: Stream started but no content received" >&2
        fi

        return 0
    }

    # Execute streaming curl with SSE parser
    curl -s -N -D "$headers_file" \
      -X POST https://api.anthropic.com/v1/messages \
      -H "x-api-key: $API_KEY" \
      -H "anthropic-version: 2023-06-01" \
      -H "Content-Type: application/json" \
      -d "$json_payload" 2>"$error_log" | parse_sse_stream

    curl_exit_code=$?

    # Extract HTTP status code from headers
    http_code=$(grep "^HTTP/" "$headers_file" 2>/dev/null | tail -n1 | awk '{print $2}')

    if [ $curl_exit_code -ne 0 ]; then
        echo "Network Error: $(cat "$error_log")" >&2
        rm -f "$error_log" "$headers_file" "$accumulated_file"
        return 1
    fi

    if [ "$http_code" != "200" ]; then
        echo "API Error ($http_code): Unable to connect" >&2
        rm -f "$error_log" "$headers_file" "$accumulated_file"
        return 1
    fi

    # Read accumulated response
    assistant_response=$(cat "$accumulated_file" 2>/dev/null || echo "")
    rm -f "$error_log" "$headers_file" "$accumulated_file"

    if [ -z "$assistant_response" ]; then
        return 1
    fi

    return 0
}

# Main execution: Try streaming first, fallback to non-streaming on error
used_streaming=true
if streaming_api_call; then
    # Streaming succeeded, output already happened during stream
    # Just add newline at end
    echo
else
    # Streaming failed, try non-streaming
    used_streaming=false
    echo "[Retrying with non-streaming mode...]" >&2
    sleep 0.5
    assistant_response=$(non_streaming_api_call)
    if [ $? -ne 0 ]; then
        exit 1
    fi
    # Output the response (since streaming didn't output it)
    echo "$assistant_response"
fi

# Update conversation history if history file is provided
if [ -n "$HISTORY_FILE" ]; then
    # Add assistant response to history
    updated_messages=$(echo "$messages" | jq --arg assistant "$assistant_response" '. + [{role: "assistant", content: $assistant}]')
    echo "$updated_messages" > "$HISTORY_FILE"
fi
