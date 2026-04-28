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
        # Temporarily disable pipefail to handle find command gracefully
        set +o pipefail
        while IFS= read -r source_file; do
            if [[ ! "$source_file" =~ __pycache__ ]] && [[ ! "$source_file" =~ \.git ]]; then
                CONTENT=$(cat "$source_file" 2>/dev/null || true)
                CODEBASE_CONTEXT+=$'\n\n'"# File: $source_file"$'\n'"'"'```'"'"$'\n'"$CONTENT"$'\n'"'"'```'"'"
                ((FILE_COUNT++)) || true
            fi
        done < <(find "$path_pattern" -type f 2>/dev/null || true)
        set -o pipefail
    fi
done

if [[ -z "$CODEBASE_CONTEXT" ]]; then
    print_error "No codebase context found"
    exit 1
fi

CONTEXT_SIZE=${#CODEBASE_CONTEXT}
print_success "Collected $FILE_COUNT files (${CONTEXT_SIZE} characters of code)"

print_step "Calling OpenAI API..."

if [[ -z "${OPENAI_API_KEY:-}" ]]; then
    print_error "OPENAI_API_KEY environment variable not set. Please export your OpenAI API key."
    exit 1
fi

# Build the prompt
read -r -d '' PROMPT << 'PROMPT_END' || true
You are an expert software architect. Your ONLY task is to generate architecture diagrams in Mermaid.js format.

You MUST follow these rules EXACTLY from SKILL.md:
%SKILL%

Analyze this codebase:
%CODEBASE%

Generate the diagrams and return ONLY this JSON structure. DO NOT return analysis, warnings, or metadata. ONLY return the diagrams in this exact format:

{
  "diagrams": [
    {
      "filename": "docs/architecture/uml_domain_model.md",
      "content": "# Architecture Model: Domain\n\n**Generated on:** April 28, 2026\n\n**Source Scope:** `src`\n\n## Mermaid Diagram\n\n```mermaid\nclassDiagram\n[FULL MERMAID DIAGRAM WITH ALL ENTITIES, ATTRIBUTES, METHODS, AND RELATIONSHIPS]\n```\n\n## Entity Dictionary\n\n* **Entity1:** Description\n* **Entity2:** Description"
    },
    {
      "filename": "docs/architecture/flow_name.md",
      "content": "# Architecture Flow: [Process Name]\n\n**Generated on:** April 28, 2026\n\n**Source Scope:** `src`\n\n## Mermaid Diagram\n\n```mermaid\nflowchart TD\n[FULL MERMAID FLOW DIAGRAM]\n```\n\n## Flow Description\n\n[Detailed description of the flow]"
    }
  ]
}

CRITICAL REQUIREMENTS:
- Return ONLY valid JSON with no additional text
- No markdown code block wrappers (no ```json tags)
- No explanations, analysis, or warnings
- Each diagram MUST have filename and content fields
- Content must include complete Mermaid diagrams, not placeholders
PROMPT_END

# Replace placeholders
PROMPT="${PROMPT//%SKILL%/$SKILL}"
PROMPT="${PROMPT//%CODEBASE%/$CODEBASE_CONTEXT}"

# Set OpenAI model (default: gpt-4.1)
OPENAI_MODEL="${OPENAI_MODEL:-gpt-4.1-2025-04-14}"

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
    }' 2>&1) || {
    print_error "Failed to build request JSON with jq"
    echo "Error: $REQUEST_JSON" >&2
    exit 1
}

# Call OpenAI API
RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d "$REQUEST_JSON" \
    "https://api.openai.com/v1/chat/completions" 2>&1)


# Check for API errors
if echo "$RESPONSE" | jq -e '.error' >/dev/null 2>&1; then
    ERROR_MSG=$(echo "$RESPONSE" | jq -r '.error.message // .error')
    print_error "OpenAI API error: $ERROR_MSG"
    echo "Full response:" >&2
    echo "$RESPONSE" >&2
    exit 1
fi

# Extract the response content
OPENAI_RESPONSE=$(echo "$RESPONSE" | jq -r '.choices[0].message.content' 2>&1) || {
    print_error "Failed to extract response from OpenAI"
    echo "Response: $RESPONSE" >&2
    exit 1
}

if [[ -z "$OPENAI_RESPONSE" ]] || [[ "$OPENAI_RESPONSE" == "null" ]]; then
    print_error "OpenAI returned empty or null response"
    echo "Response: $RESPONSE" >&2
    exit 1
fi

# Parse and write diagrams
print_step "Writing diagrams to disk..."


# Extract JSON from the response (assume raw JSON, no code blocks)
JSON_CONTENT="$OPENAI_RESPONSE"

# Validate JSON is parseable
if ! echo "$JSON_CONTENT" | jq -e '.diagrams' >/dev/null 2>&1; then
    print_error "Could not parse OpenAI response or no diagrams field found"
    echo "Response preview:" >&2
    echo "$OPENAI_RESPONSE" | head -c 1000 >&2
    exit 1
fi

# Extract and write each diagram
DIAGRAM_COUNT=0

# Get each diagram object one at a time
DIAGRAM_COUNT=$(echo "$JSON_CONTENT" | jq '.diagrams | length')
print_success "Found $DIAGRAM_COUNT diagram(s)"

for ((i=0; i<DIAGRAM_COUNT; i++)); do
    FILENAME=$(echo "$JSON_CONTENT" | jq -r ".diagrams[$i].filename")
    CONTENT=$(echo "$JSON_CONTENT" | jq -r ".diagrams[$i].content")

    if [[ -z "$FILENAME" ]] || [[ -z "$CONTENT" ]] || [[ "$FILENAME" == "null" ]] || [[ "$CONTENT" == "null" ]]; then
        print_warning "Invalid diagram entry at index $i, skipping"
        continue
    fi

    # Create parent directory
    mkdir -p "$(dirname "$FILENAME")"

    # Write file
    echo "$CONTENT" > "$FILENAME"
    print_success "Generated: $FILENAME"
done

echo ""
print_success "Done! Generated $DIAGRAM_COUNT diagrams"
