#!/usr/bin/env bash

API_KEY="$1"
MODEL="${2:-claude-opus-4-5-20251101}"
MODE="${3:-command}"
PROMPT="$4"

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

# Build JSON
json_payload=$(jq -n \
    --arg model "$MODEL" \
    --arg system "$SYSTEM_PROMPT" \
    --arg user "$PROMPT" \
    '{model: $model, max_tokens: 4096, system: $system, messages: [{role: "user", content: $user}]}')

# API call - capturing stderr to a variable to catch network/curl errors
exec 3>&1
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
    exit 1
fi

if [ "$http_code" != "200" ]; then
    # This will catch "invalid model" errors
    err=$(echo "$response_body" | jq -r '.error.message' 2>/dev/null || echo "$response_body")
    echo "API Error ($http_code): $err"
    exit 1
fi

echo "$response_body" | jq -r '.content[0].text'
rm -f "$error_log"