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

# Debug: Show feedback if provided
if [[ -n "${COMMENT_BODY:-}" ]]; then
    print_step "Feedback provided: ${#COMMENT_BODY} characters"
    echo "Content preview: ${COMMENT_BODY:0:100}..."
else
    print_warning "No COMMENT_BODY environment variable detected"
fi

# Collect diff context
print_step "Collecting diff context..."

# Generate diff from CI (BASE_SHA should be set; if not, the script is being run locally without proper context)
if [[ -z "${BASE_SHA:-}" ]]; then
    print_error "BASE_SHA env var not set — this script must be run via the CI action"
    exit 1
fi

# Generate the full PR diff between merge-base and HEAD
GIT_DIFF=$(git diff "${BASE_SHA}...HEAD" 2>/dev/null || true)

if [[ -z "$GIT_DIFF" ]]; then
    print_warning "No changes in this PR — skipping diagram generation"
    exit 0
fi

# Strip binary file annotations (non-text, would corrupt JSON payload)
CLEAN_DIFF=$(echo "$GIT_DIFF" | grep -v "^Binary files ")

if [[ -z "$CLEAN_DIFF" ]]; then
    print_error "GIT_DIFF contained only binary file changes — no text diff to analyze"
    exit 1
fi

DIFF_CONTEXT="# PR Git Diff"$'\n\n''```diff'$'\n'"$CLEAN_DIFF"$'\n''```'
FILE_COUNT=1

# Append existing architecture docs so model can update them in context
if [[ -d "docs/architecture" ]]; then
    print_step "Appending existing docs/architecture files..."
    set +o pipefail
    while IFS= read -r arch_file; do
        CONTENT=$(cat "$arch_file" 2>/dev/null || true)
        DIFF_CONTEXT+=$'\n\n'"# Existing Diagram: $arch_file"$'\n''```'$'\n'"$CONTENT"$'\n''```'
        ((FILE_COUNT++)) || true
    done < <(find "docs/architecture" -type f -name "*.md" 2>/dev/null || true)
    set -o pipefail
fi

CONTEXT_SIZE=${#DIFF_CONTEXT}
print_success "Diff mode: ${CONTEXT_SIZE} characters (diff + existing diagram file(s))"

print_step "Calling OpenAI API..."

if [[ -z "${OPENAI_API_KEY:-}" ]]; then
    print_error "OPENAI_API_KEY environment variable not set. Please export your OpenAI API key."
    exit 1
fi

# Set context header for the prompt
CONTEXT_HEADER="Analyze the following PR diff (all changes since the base commit). Existing architecture diagrams are appended after the diff — update them to reflect the changes:"

# Build the prompt
read -r -d '' PROMPT << 'PROMPT_END' || true
You are an expert software architect. Your ONLY task is to generate architecture diagrams in Mermaid.js format.

You MUST follow these rules EXACTLY from SKILL.md:
%SKILL%

%CONTEXT_HEADER%
%DIFF%

%FEEDBACK_SECTION%

Generate the diagrams and return ONLY this JSON structure with metadata about your filtering decisions:

{
  "metadata": {
    "classes_analyzed": 10,
    "classes_included": 5,
    "classes_excluded": 5,
    "excluded_patterns": [
      { "pattern": "DTO", "count": 2, "examples": ["OrderDTO", "PaymentDTO"] },
      { "pattern": "Service", "count": 2, "examples": ["OrderService", "PaymentService"] },
      { "pattern": "Mapper", "count": 1, "examples": ["OrderMapper"] }
    ],
    "methods_analyzed": 45,
    "methods_included": 20,
    "methods_excluded": 25
  },
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

# Replace placeholders - build prompt safely
PROMPT="${PROMPT//%SKILL%/$SKILL}"
PROMPT="${PROMPT//%DIFF%/$DIFF_CONTEXT}"
PROMPT="${PROMPT//%CONTEXT_HEADER%/$CONTEXT_HEADER}"

# Handle user feedback if provided
if [[ -n "${COMMENT_BODY:-}" ]]; then
    # Extract feedback from comment (remove /review command)
    FEEDBACK=$(echo "$COMMENT_BODY" | sed 's|^/review\s*||i' | xargs)
    
    if [[ -n "$FEEDBACK" ]]; then
        # Build feedback section as single-line to avoid sed issues with newlines
        FEEDBACK_SECTION="User Feedback / Requirements: $FEEDBACK. Please incorporate this feedback into your diagram generation."
        # Escape special chars for sed and perform substitution
        FEEDBACK_ESCAPED=$(printf '%s\n' "$FEEDBACK_SECTION" | sed -e 's/[\/&]/\\&/g')
        PROMPT=$(echo "$PROMPT" | sed "s|%FEEDBACK_SECTION%|$FEEDBACK_ESCAPED|")
    else
        PROMPT="${PROMPT//%FEEDBACK_SECTION%/}"
    fi
else
    PROMPT="${PROMPT//%FEEDBACK_SECTION%/}"
fi

# Remove extra blank lines
PROMPT=$(echo "$PROMPT" | sed '/^[[:space:]]*$/N;/^\n$/D')

# Set OpenAI model (default: gpt-4.1)
OPENAI_MODEL="${OPENAI_MODEL:-gpt-4.1-2025-04-14}"

# Create the request JSON
# Use --rawfile to read prompt from temp file to avoid "Argument list too long" with large diffs
PROMPT_FILE=$(mktemp)
echo "$PROMPT" > "$PROMPT_FILE"

REQUEST_JSON=$(jq -n \
    --arg model "$OPENAI_MODEL" \
    --argjson max_tokens 8000 \
    --rawfile content "$PROMPT_FILE" \
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
    rm -f "$PROMPT_FILE"
    exit 1
}

rm -f "$PROMPT_FILE"

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

# Display SKILL filtering summary
if echo "$JSON_CONTENT" | jq -e '.metadata' >/dev/null 2>&1; then
    echo ""
    print_success "✅ SKILL.md Successfully Applied"
    echo ""
    
    CLASSES_ANALYZED=$(echo "$JSON_CONTENT" | jq -r '.metadata.classes_analyzed // 0')
    CLASSES_INCLUDED=$(echo "$JSON_CONTENT" | jq -r '.metadata.classes_included // 0')
    CLASSES_EXCLUDED=$(echo "$JSON_CONTENT" | jq -r '.metadata.classes_excluded // 0')
    METHODS_ANALYZED=$(echo "$JSON_CONTENT" | jq -r '.metadata.methods_analyzed // 0')
    METHODS_INCLUDED=$(echo "$JSON_CONTENT" | jq -r '.metadata.methods_included // 0')
    METHODS_EXCLUDED=$(echo "$JSON_CONTENT" | jq -r '.metadata.methods_excluded // 0')
    
    echo "📊 Diagram Generation Summary:"
    echo "   Classes Analyzed: $CLASSES_ANALYZED"
    echo "   Classes Included: $CLASSES_INCLUDED"
    echo "   Classes Excluded: $CLASSES_EXCLUDED"
    echo ""
    echo "   Methods Analyzed: $METHODS_ANALYZED"
    echo "   Methods Included: $METHODS_INCLUDED"
    echo "   Methods Excluded: $METHODS_EXCLUDED (getters/setters filtered by SKILL)"
    echo ""
    
    # Display excluded patterns
    if echo "$JSON_CONTENT" | jq -e '.metadata.excluded_patterns | length > 0' >/dev/null 2>&1; then
        echo "🔍 Excluded Patterns (per SKILL rules):"
        echo "$JSON_CONTENT" | jq -r '.metadata.excluded_patterns[] | "   • \(.pattern): \(.count) class(es) (\(.examples | join(", ")))"' 2>/dev/null || true
        echo ""
    fi
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
