#!/bin/bash
set -euo pipefail

# Architecture Bot (MOCK) - Generates/updates architecture diagrams via mock data
# For testing file collection, JSON parsing, and diagram writing WITHOUT API calls
# Reads the SKILL.md architecture rules, collects codebase context,
# returns mock diagrams, and writes them to docs/architecture/

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

# Get paths from command-line args, env var, or default
if [[ $# -gt 0 ]]; then
    IFS=' ' read -ra PATHS <<< "$@"
else
    ANALYSIS_PATHS="${ANALYSIS_PATHS:-src_aipe}"
    IFS=' ' read -ra PATHS <<< "$ANALYSIS_PATHS"
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

# Mock response (for testing without API calls)
print_step "Using mock data (no API call)..."

# Create proper JSON with Mermaid diagrams using jq
CLAUDE_RESPONSE=$(jq -n '{
  diagrams: [
    {
      filename: "docs/architecture/mock_domain_model.md",
      content: "# Architecture Model: Domain (Mock)\n**Generated on:** 2026-04-24\n**Source Scope:** `src_aipe` (Test)\n\n## Mermaid Diagram\n\n```mermaid\nclassDiagram\n    class Job {\n        + url: string\n        + jobId: string\n        + title: string\n    }\n    class EnrichedJob {\n        + kldb5Name: string\n        + images: list\n        + videoUri: string\n    }\n    class MandateConfig {\n        + name: string\n        + feedUrl: string\n        + products: list\n    }\n    class Product {\n        + name: string\n        + budgetValue: float\n    }\n    \n    EnrichedJob \"1\" o-- \"1\" Job\n    MandateConfig \"1\" *-- \"0..*\" Product\n```\n\n## Entity Dictionary\n\n* **Job:** Core input entity representing a job posting from a feed.\n* **EnrichedJob:** Job with LLM-derived enrichment data and metadata.\n* **MandateConfig:** Configuration for a feed source and its processing rules.\n* **Product:** Budget-to-product-name matching rule."
    },
    {
      filename: "docs/architecture/mock_flow.md",
      content: "# Architecture Flow: Processing Pipeline (Mock)\n**Generated on:** 2026-04-24\n**Source Scope:** `src_aipe` (Test)\n\n## Mermaid Diagram\n\n```mermaid\nflowchart TD\n    A[Start] --> B[Fetch Job]\n    B --> C[Extract Data]\n    C --> D[Enrich Job]\n    D --> E{Success?}\n    E -->|Yes| F[Generate Images]\n    E -->|No| G[Log Error]\n    F --> H[Generate Video]\n    H --> I[Persist to DB]\n    G --> I\n    I --> J[End]\n```\n\n## Flow Description\n\nThis mock flow demonstrates the main processing steps:\n1. Fetch job from source feed\n2. Extract core data\n3. AI enrichment KLDB5, metadata\n4. Image generation multiple aspects\n5. Video generation\n6. Persistence to database"
    }
  ]
}')

# Since jq -n already creates valid JSON, we use it directly
JSON_CONTENT="$CLAUDE_RESPONSE"

# Validate JSON
if ! echo "$JSON_CONTENT" | jq empty 2>/dev/null; then
    print_error "Could not parse mock response as JSON"
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

    # Write file (using printf to properly handle escaped newlines)
    printf "%b" "$CONTENT" > "$FILENAME"
    print_success "Generated: $FILENAME"
    ((DIAGRAM_COUNT++))
done <<< "$DIAGRAMS"

echo ""
print_success "Done! Generated $DIAGRAM_COUNT mock diagrams with Mermaid syntax"
print_warning "Note: These are mock diagrams for testing. Use run_architecture_bot.sh for real diagrams via GitHub Models API."
