#!/bin/bash
set -euo pipefail


# Architecture Bot - Generates/updates architecture diagrams via OpenAI
# Reads the SKILL.md architecture rules, collects codebase context,
# calls OpenAI API, and writes diagrams to docs/architecture/

# Requirements:
#   - Set OPENAI_API_KEY to your OpenAI API key (required)
#   - Optionally set OPENAI_MODEL (default: gpt-4.1)

SKILL_PATH=".agents/skills/architecture-bot/SKILL.md"
DIAGRAMS_DIR="docs/architecture"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}" >&2
}

print_error() {
    echo -e "${RED}❌ $1${NC}" >&2
}

# Read SKILL.md
print_step "Reading SKILL.md..."
if [[ ! -f "$SKILL_PATH" ]]; then
    print_error "SKILL.md not found at $SKILL_PATH"
    exit 1
fi
SKILL=$(cat "$SKILL_PATH")
print_success "SKILL.md loaded ($(wc -c < "$SKILL_PATH") bytes)"

# Collect codebase context
print_step "Collecting codebase context..."

# Get paths from command-line args or ANALYSIS_PATHS env var (required)
if [[ $# -gt 0 ]]; then
    IFS=' ' read -ra PATHS <<< "$@"
elif [[ -n "${ANALYSIS_PATHS:-}" ]]; then
    IFS=' ' read -ra PATHS <<< "$ANALYSIS_PATHS"
else
    print_error "No analysis paths provided"
    echo "Usage:" >&2
    echo "  bash scripts/run_architecture_bot.sh <path1> [path2] ..." >&2
    echo "OR" >&2
    echo "  ANALYSIS_PATHS='<path1> [path2] ...' bash scripts/run_architecture_bot.sh" >&2
    echo "" >&2
    echo "Examples:" >&2
    echo "  bash scripts/run_architecture_bot.sh src" >&2
    echo "  bash scripts/run_architecture_bot.sh src docs/architecture" >&2
    echo "  ANALYSIS_PATHS='src' bash scripts/run_architecture_bot.sh" >&2
    exit 1
fi

echo "   Analyzing paths: ${PATHS[*]}"

CODEBASE_CONTEXT=""
FILE_COUNT=0

for path_pattern in "${PATHS[@]}"; do
    if [[ -f "$path_pattern" ]]; then
        # Single file - include all files
        CONTENT=$(cat "$path_pattern" 2>/dev/null || true)
        CODEBASE_CONTEXT+=$'\n\n'"# File: $path_pattern"$'\n'"'"'```'"'"$'\n'"$CONTENT"$'\n'"'"'```'"'"
        ((FILE_COUNT++))
    elif [[ -d "$path_pattern" ]]; then
        # Directory - find all files
        while IFS= read -r source_file; do
            if [[ ! "$source_file" =~ __pycache__ ]] && [[ ! "$source_file" =~ \.git ]]; then
                CONTENT=$(cat "$source_file" 2>/dev/null || true)
                CODEBASE_CONTEXT+=$'\n\n'"# File: $source_file"$'\n'"'"'```'"'"$'\n'"$CONTENT"$'\n'"'"'```'"'"
                ((FILE_COUNT++))
            fi
        done < <(find "$path_pattern" -type f 2>/dev/null)
    fi
done

if [[ -z "$CODEBASE_CONTEXT" ]]; then
    print_error "No codebase context found"
    exit 1
fi

CONTEXT_SIZE=${#CODEBASE_CONTEXT}
print_success "Collected $FILE_COUNT files (${CONTEXT_SIZE} characters of code)"

# Call Claude via GitHub Models

print_step "Calling OpenAI API..."

if [[ -z "${OPENAI_API_KEY:-}" ]]; then
    print_error "OPENAI_API_KEY environment variable not set. Please export your OpenAI API key."
    exit 1
fi

# Build the prompt
read -r -d '' PROMPT << 'PROMPT_END' || true
You are an expert software architect. Generate/update architecture diagrams according to the codebase.
PROMPT_END

# Replace placeholders
PROMPT="${PROMPT//%SKILL%/$SKILL}"
PROMPT="${PROMPT//%CODEBASE%/$CODEBASE_CONTEXT}"


# Set OpenAI model (default: gpt-4.1)
OPENAI_MODEL="${OPENAI_MODEL:-gpt-4.1}"

# Create the request JSON
REQUEST_JSON=$(jq -n \
    --arg model "$OPENAI_MODEL" \
    --argjson max_tokens 8000 \
    --arg content "$PROMPT" \
    '{
        model: $model,
        max_tokens: $max_tokens,
        messages: [
            {
                role: "user",
                content: $content
            }
        ]
    }')

# Call OpenAI API
RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d "$REQUEST_JSON" \
    "https://api.openai.com/v1/chat/completions")


# Check for API errors
if echo "$RESPONSE" | jq -e '.error' >/dev/null 2>&1; then
    ERROR_MSG=$(echo "$RESPONSE" | jq -r '.error.message // .error')
    print_error "OpenAI API error: $ERROR_MSG"
    exit 1
fi

# Extract the response content
OPENAI_RESPONSE=$(echo "$RESPONSE" | jq -r '.choices[0].message.content')

# Parse and write diagrams
print_step "Writing diagrams to disk..."


# Extract JSON from the response
if echo "$OPENAI_RESPONSE" | grep -q '```json'; then
    JSON_CONTENT=$(echo "$OPENAI_RESPONSE" | sed -n '/```json/,/```/p' | sed '1d;$d')
elif echo "$OPENAI_RESPONSE" | grep -q '```'; then
    JSON_CONTENT=$(echo "$OPENAI_RESPONSE" | sed -n '/```/,/```/p' | sed '1d;$d')
else
    JSON_CONTENT="$OPENAI_RESPONSE"
fi

# Validate JSON
if ! echo "$JSON_CONTENT" | jq empty 2>/dev/null; then
    print_error "Could not parse Claude response as JSON"
    echo "Response was:"
    echo "$CLAUDE_RESPONSE"
    exit 1
fi

# Extract and write each diagram
DIAGRAMS=$(echo "$JSON_CONTENT" | jq -c '.diagrams[]')
DIAGRAM_COUNT=0

while IFS= read -r diagram; do
    FILENAME=$(echo "$diagram" | jq -r '.filename')
    CONTENT=$(echo "$diagram" | jq -r '.content')
    
    if [[ -z "$FILENAME" ]] || [[ -z "$CONTENT" ]] || [[ "$FILENAME" == "null" ]] || [[ "$CONTENT" == "null" ]]; then
        print_warning "Invalid diagram entry, skipping"
        continue
    fi
    
    # Create parent directory
    mkdir -p "$(dirname "$FILENAME")"
    
    # Write file
    echo "$CONTENT" > "$FILENAME"
    print_success "Generated: $FILENAME"
    ((DIAGRAM_COUNT++))
done <<< "$DIAGRAMS"

echo ""
print_success "Done! Generated $DIAGRAM_COUNT diagrams"