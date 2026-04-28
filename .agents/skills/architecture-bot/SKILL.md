---
name: 'architecture-bot'
description: 'CRITICAL: Use this tool IMMEDIATELY whenever the user asks for architecture, schematics, diagrams, or documentation. This skill operates in two modes: (1) FIRST-TIME GENERATION—two-phase: first enumerate flow diagram candidates from entry-point scripts and PAUSE for user confirmation, then generate only the confirmed set and record it in repo memory; (2) INCREMENTAL UPDATE—when diagrams already exist, detect code changes and update only affected diagrams. Always generates one UML domain model. Flow diagram count is decided by the user once and stored permanently. Transform repository source code into precise architectural schematics (Mermaid.js format) by strictly obeying the Architecture Legend rules in src/architecture_legend.md. Supports domain_model (classDiagram) and flow_diagram (flowchart TD) analysis. IMPORTANT: Do NOT write or suggest any new scripts; focus only on generating diagram files to docs/architecture/.'
---

# Architecture Diagram Generation Skill

## Your Role

You are the **Lead System Architect**. Your mission is to maintain the visual documentation of this repository by generating and updating Mermaid.js diagrams. You do not just "suggest" code; you stage file changes to keep the `docs/architecture/` directory synchronized with the codebase.

---

## Role & Responsibility

**What This Skill Does:**
- Transforms repository source code into precise architectural schematics
- Generates ONLY THESE two types of diagrams:
  1. **UML Domain Models** (`classDiagram`): Static structure showing domain entities, attributes, methods, and relationships
  2. **Behavioral Flowcharts** (`flowchart TD`): Execution flow showing process logic, decision points, and data I/O

**When to Invoke This Skill:**
- User requests architecture visualization of a codebase
- Documentation generation workflows need diagrams
- Architecture analysis or design review is required
- Need to understand domain model structure or process execution

**What It Depends On:**
- Codebase structure with identifiable classes and methods
- Mermaid.js for diagram syntax and rendering
- Proper source code context (not compiled binaries)

**Constraints & Limitations:**
- Works best with codebases <300 classes (warns if larger)
- Requires concrete implementation classes (ignores interfaces/abstractions)
- Output quality depends on code clarity and documentation
- May require `focus_scope` parameter for large repositories
- Does not generate database schemas or infrastructure diagrams

---

## Invocation Modes

This skill supports **two invocation methods** for maximum flexibility:

### Manual Invocation
- **Trigger:** User command in chat
- **Examples:**
  - "Generate UML domain model for this codebase"
  - "Create architecture diagram"
  - "Map flow for employee termination process"
  - "Analyze the domain structure"

### Automatic Invocation
- **Trigger:** Documentation workflows
- **Events:**
  - On codebase change (automatic architecture diagram generation)
  - On documentation generation request
  - On architecture analysis request

---

## Workflow Mode: First-Time Generation vs. Incremental Update

This skill operates in two distinct modes to optimize efficiency:

### Mode 1: First-Time Generation (No Diagrams Exist)
**Trigger:** `docs/architecture/` contains no diagrams OR is missing the main diagram files

Mode 1 is split into two mandatory phases. **Do NOT generate any files until Phase 1B is complete and the user has confirmed the candidate list.**

---

#### Phase 1A — Flow Diagram Candidate Enumeration (Execute Silently, Then Present)

The goal is to mechanically derive the flow diagram list from entry points.
```text
STEP 1: FIND ENTRY-POINT SCRIPTS
├─ Scan the repository for scripts that serve as execution entry points.
│  An entry point is any file that:
│    - Is directly runnable (contains an `if __name__ == "__main__"` block,
│      a CLI command definition, or is referenced as a startup command in
│      config files such as Dockerfile, docker-compose, pyproject.toml,
│      package.json scripts, Procfile, or similar)
│    - Is NOT a test file, utility helper, or infrastructure setup module
├─ Read each entry-point script
└─ RESULT: list of entry-point files

STEP 2: TRACE TOP-LEVEL SERVICE / USE-CASE CALLS
├─ FOR EACH entry-point file:
│  ├─ Identify every distinct class whose method is called at the outermost
│  │  level of the script's main execution path (not inside helpers or utilities)
│  ├─ Record: (entry_point_file, class_name, method_name, source_file)
│  └─ EXCLUDE calls whose sole purpose is infrastructure setup
│     (e.g. logging config, error-tracking init, credential loading)
└─ RESULT: list of (entry_point, class, method, source_file) tuples

STEP 3: GROUP INTO FLOW DIAGRAM CANDIDATES
├─ FOR EACH unique source_file in the result:
│  ├─ Collect all methods from that file that appear in the tuples
│  ├─ IF multiple methods from the same class form a sequential pipeline
│  │  (i.e., one method's output feeds into the next), GROUP them as one diagram
│  └─ OTHERWISE, one source_file = one flow diagram candidate
└─ RESULT: candidate list — each entry has:
     - source_file: path relative to repo root
     - entry_point: which script triggers it
     - methods_covered: list of method names included
     - one_line_rationale: why this qualifies as a top-level flow
```

#### Phase 1B — STOP AND PRESENT CANDIDATES TO USER

**MANDATORY GATE: Do NOT proceed to generation until the user explicitly confirms.**

Present the candidates in this exact format in the chat:

```
### Flow Diagram Candidates Found

I found [N] flow diagram candidate(s) by tracing the codebase entry points.
Please confirm this list before I generate any files.

| # | Source File | Entry Point | Methods Covered | Rationale |
|---|-------------|-------------|-----------------|-----------|
| 1 | {path}      | {script}    | method1, method2 | {rationale} |
...

Reply with:
- **"confirmed"** to generate all of the above
- **"drop #N"** to remove a candidate
- **"add [description]"** to add a candidate I may have missed
```

**Only the UML domain model (`uml_domain_model.md`) is generated immediately without waiting — it does not require user confirmation.**

---

#### Phase 1C — Generation (After User Confirms)

Once the user confirms (or adjusts) the candidate list:

1. **Write confirmed list to repo memory**
   - Store in `/memories/repo/` under the repository name
   - Record each confirmed flow file with its source file and methods covered
   - This list is now the **permanent canonical set** — all future Mode 2 runs update exactly these files and never re-derive the list

2. **Full Code-to-Diagram Validation**
   - Trace ALL domain entities, relationships, and execution flows from source code
   - Perform deep code inspection (read implementation details, not just function signatures)
   - Validate entity cardinality, relationships, and method inclusion/exclusion against Architecture Legend rules

3. **Generate Confirmed Diagrams**
   - Create `uml_domain_model.md` with all domain entities, attributes, methods, and relationships
   - Create exactly the confirmed flow diagrams — no more, no fewer
   - Include comprehensive descriptions and entity dictionaries
   - Validate Mermaid syntax and compliance with Architecture Legend

4. **Add Generation Metadata**
   - Include in each diagram: `**Generated on:** [CURRENT_DATE]`
   - Include in each diagram: `**Source Scope:** [FOLDER/PATH]`

---

### Mode 2: Incremental Update (Diagrams Already Exist)
**Trigger:** Diagrams exist in `docs/architecture/` AND user requests an update

**Workflow Procedure:**

1. **Detect Code Changes**
   - Use `get_changed_files` tool to identify files modified since last diagram generation
   - Filter to only changes in domain/application source code (ignore tests, config, non-logic files)
   - Map changed files to affected domain entities, methods, or workflows
   - Identify scope of impact: single entity, multiple entities, or entire flow

2. **Update Only Affected Diagrams**
   - If domain entities changed → update `uml_domain_model.md` only
   - If a specific workflow/process changed → update only that `{process_name}_flow.md`
   - If new entities were added → add them; if deleted → remove them
   - Preserve verified relationships, cardinality, and descriptions for unchanged code
   - Update method signatures, attributes only if code changed

3. **Preservation Strategy**
   - Keep existing entity descriptions unless they reference changed code
   - Retain relationship definitions that depend on unchanged code paths
   - Only re-analyze the changed portions; don't re-validate entire diagrams
   - Add new entities; remove deleted ones; update modified ones

4. **Update Metadata**
   - Change `**Generated on:**` to current date
   - Keep `**Source Scope:**` unless scope changed
   - Update session memory baseline reference

---

### Decision Logic: Which Mode to Use

```
IF docs/architecture/ is empty OR uml_domain_model.md does not exist:
  → Use Mode 1
  → Phase 1A: Enumerate flow candidates from entry-point scripts
  → Phase 1B: STOP — present candidates table to user and wait for confirmation
  → Phase 1C (after confirmation): Write confirmed list to repo memory, then generate all diagrams

ELSE IF diagrams exist AND user requests "update" or "refresh":
  → Read confirmed flow list from repo memory
  → Check for code changes using get_changed_files
  → IF changes detected:
    → Use Mode 2 (Incremental Update) — update only affected diagrams from the stored list
  → IF no changes detected:
    → Return: "No code changes detected. Diagrams are up-to-date."

ELSE IF user intent is unclear:
  → Ask user: "Should I do a full re-analysis or just update for code changes?"
```

---

### Practical Examples

**Scenario 1: First-Time Generation**
- User: "Generate architecture for this codebase."
- Response (Phase 1A+1B): Generate `uml_domain_model.md` immediately. Then present the flow candidate table and STOP. Wait for user to confirm before creating any flow files.
- Response (Phase 1C, after "confirmed"): Write confirmed list to repo memory. Generate exactly the confirmed flow diagrams.

**Scenario 2: Incremental Update After Small Change**
- User: "I updated the Job entity. Can you refresh the diagrams?"
- Response: Mode 2 — read confirmed flow list from repo memory, detect changes in Job class, update `uml_domain_model.md` only, preserve unaffected flow diagrams.

**Scenario 3: Update Request with Existing Diagrams**
- User: "Update the architecture schematic." (diagrams already exist)
- Response: Mode 2 — read confirmed flow list from repo memory, check all code changes, update only affected diagrams from the stored list.

**Scenario 4: User Adjusts Candidate List**
- User reviews Phase 1B table and says "drop #3, it's just a utility"
- Response: Remove candidate #3, write the adjusted list to repo memory, generate remaining diagrams.

---

## Dependencies & Requirements

**Required:**
- Mermaid.js v9.0+ (for diagram syntax support)
- Codebase context (file structure, class definitions)
- Valid Python/TypeScript codebase with identifiable classes

**Output Format:**
- Mermaid.js syntax (`classDiagram` or `flowchart TD`)
- JSON schemas for input/output validation

**Performance & Constraints:**
- **<100 classes:** Instant generation
- **100-300 classes:** May require 2-5 seconds; offers `focus_scope` option
- **>300 classes:** Warns user to use `focus_scope` for clarity
- **>1000 classes:** Hard error; demands `focus_scope` parameter

---

## 2. Execution Steps & Logic Algorithm

### Core Algorithm (Applies to Both Workflow Modes)

This algorithm is the **core engine** used by both Mode 1 (First-Time Generation) and Mode 2 (Incremental Update). The key difference in application:

- **Mode 1:** Apply the full algorithm below to the **entire codebase** (all classes, methods, workflows)
- **Mode 2:** Apply the algorithm **only to changed files and affected entities**; preserve and reference unchanged code without re-analysis

To ensure deterministic output, you MUST execute your task in this exact order. Use the `src/architecture_legend.md` file as your reference dictionary to fill in the exact rules for these pseudocode steps.

**PHASE A: The Logic Loop (Execute Silently)**
```text
INPUT: Repository context (files, classes, methods)
NOTE (Mode 2 Only): If running in incremental mode, limit INPUT to only changed files and their affected dependencies

STEP 1: FILTER BY CLASS NAME (Section 2: Pruning)
├─ FOR EACH class in repository [or changed classes in Mode 2]:
│  ├─ IF class name ends with [Controller, Handler, Repository, Factory, Mapper, DTO, ViewModel, Wrapper, Service, Util]
│  │  └─ EXCLUDE class (mark as pruned)
│  └─ IF class is interface or abstract
│     └─ EXCLUDE class (mark as pruned)
└─ RESULT: Set of concrete, non-excluded classes

STEP 2: EXTRACT ATTRIBUTES (Section 3: Entity & Naming)
├─ FOR EACH non-excluded class:
│  ├─ FOR EACH field/property **directly declared** in class (NOT inherited):
│  │  ├─ IF field is from excluded abstract base class or interface
│  │  │  └─ SKIP this field (do not include)
│  │  ├─ IF field name contains pattern `*_id` (foreign key):
│  │  │  └─ RECORD as relationship target (for Section 4)
│  │  └─ CONVERT field name to camelCase
│  │     └─ INFER type as language-agnostic (list, map, string, etc.)
└─ RESULT: Formatted attributes (directly declared only) with inferred types

STEP 3: FILTER METHODS (Section 2: Strict Method Inclusion)
├─ FOR EACH method **directly declared** in non-excluded class (NOT inherited):
│  ├─ IF method is from excluded abstract base class or interface
│  │  └─ SKIP this method (do not include)
│  ├─ IF method is NOT public
│  │  └─ EXCLUDE method
│  ├─ IF method name begins with [get, set, is, has, build, __init__, ngOnInit, etc.]
│  │  └─ EXCLUDE method
│  └─ IF method mutates state OR performs business logic
│     └─ INCLUDE method (convert to camelCase)
└─ RESULT: Filtered, formatted methods (directly declared only)

STEP 4: INFER RELATIONSHIPS (Section 4: Relation Mapping)
├─ FOR EACH recorded relationship from Step 2:
│  ├─ IF field is single object reference
│  │  └─ DETERMINE: Composition (*--) or Aggregation (o--)
│  │     ├─ IF Class A owns Class B lifecycle → Composition
│  │     └─ IF Class B independent → Aggregation
│  └─ IF Class A calls method on Class B (no persistent ref)
│     └─ DETERMINE: Directed Association (-->)
└─ RESULT: Relationship list with operators

STEP 5: INFER CARDINALITY (Section 5: Cardinality Definitions)
├─ FOR EACH inferred relationship:
│  ├─ Parent side: ALWAYS "1" (unless code shows otherwise)
│  └─ Child side:
│     ├─ IF field is single object → "1" or "0..1"
│     └─ IF field is array/collection → "0..*" or "1..*"
└─ RESULT: Relationships with cardinality

OUTPUT: Valid Mermaid code (classDiagram or flowchart TD)
```

---

### Mode 2 Preservation Strategy (Incremental Update Only)

When running in Mode 2 (Incremental Update), apply the above algorithm to **only changed/affected code**, then:

1. **Preserve Unchanged Entities**
   - Reference existing relationships, cardinality, and descriptions from the previous diagram
   - Do NOT re-trace relationships for unchanged entities
   - Only update method signatures, attributes if the code actually changed

2. **Merge Results**
   - Add any new entities extracted in PHASE A
   - Remove any deleted entities
   - Update modified entities with new attributes/methods
   - Keep relationship definitions that reference unchanged code

3. **Update Descriptions Only If Code Changed**
   - Keep existing entity descriptions unless they describe now-changed code
   - Add new descriptions only for new entities

---

**PHASE B: Flow Diagram Logic (For flow_diagram)**
```text
INPUT: execution_context (service, function, or workflow name)

STEP 1: IDENTIFY TARGET PROCESS
├─ EXTRACT target process from `execution_context`
└─ LOCATE entry point function/method in codebase

STEP 2: TRACE LOGIC & PRUNE
├─ WALKTHROUGH execution path step-by-step:
│  ├─ IF step is variable declaration, standard logging, or simple formatting
│  │  └─ EXCLUDE step
│  ├─ IF step is conditional branch, loop, database I/O, or cross-service call
│  │  └─ INCLUDE step
└─ RESULT: Pruned list of critical execution steps

STEP 3: MAP NODES
├─ FOR EACH included step:
│  ├─ IF entry point or exit/return/exception
│  │  └─ Map to Terminal Node: ([ ])
│  ├─ IF internal computation or task
│  │  └─ Map to Process Node: [ ]
│  ├─ IF control flow (if/switch/loop condition)
│  │  └─ Map to Decision Node: { } (Must be phrased as a question)
│  └─ IF database read/write
│     └─ Map to Database Node: [( )]
└─ RESULT: Mapped Mermaid elements

STEP 4: ROUTE EDGES
├─ CONNECT nodes sequentially using Directed Association (-->)
└─ IF exiting a Decision Node ({ }):
   └─ ADD branch condition label to edge (e.g., -->|Yes| or -->|No|)
```

---

### Mode 2 Preservation Strategy for Flow Diagrams (Incremental Update Only)

When running in Mode 2 for flow diagrams, apply the above algorithm **only to changed workflows/processes**, then:

1. **Preserve Unchanged Flows**
   - Keep existing flow diagrams for processes that haven't changed
   - Only re-trace flows for modified functions/services

2. **Merge Flow Results**
   - Update nodes/edges for changed execution paths
   - Keep nodes that reference unchanged operations
   - Remove nodes only if the corresponding code path no longer exists

3. **Update Process Dictionary**
   - Keep descriptions for unchanged steps
   - Update descriptions only for modified process steps
   - Add new step descriptions only for new nodes

---

**PHASE C: Output Generation**
1. **Drafting Table:** Output a markdown block in the chat titled `### Entities Found` (or `### Flow Steps Found`) listing exactly the classes, nodes, and relationships you extracted in Phase A or Phase B.
2. **File Generation:** Generate the actual markdown file containing the Mermaid diagram.
3. **Validation:** Ensure the generated Mermaid code adheres to the syntax and structure rules defined in `src/architecture_legend.md`.

---

**PHASE D: Verification Pass (Mode 1 Only — First-Time Generation)**
STEP 1: For each entity in generated diagram:
  ├─ Re-read the corresponding source file
  ├─ Check: are all attributes present? Are any missing?
  ├─ Check: are all methods correct? Any excluded that should be included?
  └─ Correct diagram if discrepancy found

STEP 2: For each relationship in generated diagram:
  ├─ Verify the reference exists as a direct field in code (not assumed)
  └─ Correct cardinality if discrepancy found

STEP 3: For each flow node in generated flow diagram:
  ├─ Verify the node maps to actual code logic (not hallucinated)
  ├─ Verify decision branches match actual if/else conditions in code
  └─ Correct or remove node if no matching code found

OUTPUT: Verified, corrected diagram — only now write to file

---

## 3. File Creation Guardrails & Template

You are strictly forbidden from inventing file names. You MUST use the following formula for all generated files:
* **Directory:** All generated files MUST be saved directly into `docs/architecture/`.
* **File Naming:** `uml_domain_model.md` or `{target_process}_flow.md` (Use `snake_case` only).

**Mandatory File Template:**
Every file you generate MUST exactly match this structure.

```
  # Architecture Model: [Folder or Process Name]
  **Generated on:** [Current Date]
  **Source Scope:** `/[Target Folder]`

  ## Mermaid Diagram
  [Insert Mermaid classDiagram or flowchart TD here]

  ## Entity/Process Dictionary
  * **[Entity/Node 1]:** Brief description of responsibility based on code.
```

---

## 4. Anti-Hallucination Directives
* **No Speculation:** You must ONLY draw relationships or flow paths that explicitly exist in the code via imports, inheritance, strict typing, or explicit method calls.
* **Strict Pruning:** If a class matches the exclusion list in `src/architecture_legend.md`, it must not appear in the diagram under any circumstances.
* **Consistency:** Ensure the direction of arrows (e.g. `-->`) always points from the dependent class/process to the dependency.

---

## 5. Input / Output Schemas

### Input Schema (JSON Schema)
```json
{
  "repository_path": "string (Path to the repository to analyze)",
  "analysis_type": "enum: [domain_model, flow_diagram, both]",
  "max_classes": "integer (Default: 50)",
  "focus_scope": "array of strings (Specific modules to focus on)",
  "execution_context": "object (Required for flow_diagrams)"
}
```

### Output Schema (JSON Schema)
```json
{
  "diagram_type": "enum: [classDiagram, flowchart]",
  "generated_file_path": "string (e.g., docs/architecture/users_domain_model.md)",
  "legend_rules_applied": "array of strings",
  "warnings": "array of strings (Edge cases or issues detected)",
  "metadata": {
    "node_or_class_count": "integer",
    "analysis_scope": "string"
  }
}
```

---

## 6. Error Handling & Edge Cases

### Error Case 1: Oversized Repository
**Condition:** Repository contains >300 classes (warning) or >1000 classes (error)
**Detection:**
```text
IF class_count > 1000:
  RETURN error: "Repository too large (>1000 classes). Use 'focus_scope' parameter."
ELIF class_count > 300:
  APPEND warning: "Repository large (>300 classes); consider narrowing focus_scope for clarity."
```

### Error Case 2: Circular Dependencies
**Condition:** Relationship graph contains cycles (e.g., A → B → A)
**Detection:** If cycles exist, append warning: "Circular dependency detected" and suggest refactoring.

### Error Case 3: Invalid Input Parameters
**Condition:** Input validation fails (e.g., missing path, invalid analysis type).
**Handling:** Return strict error detailing the validation failure before proceeding.

### Error Case 4: Missing Source Context
**Condition:** Insufficient codebase context provided.
**Handling:** If no classes are found in the `focus_scope`, return a warning and expand to the full repository if possible, or return a partial result with warnings.

### Error Case 5: Conflicting Input Parameters
**Condition:** `analysis_type == "flow_diagram"` but `execution_context` missing.
**Handling:** RETURN error: "execution_context required for flow_diagram analysis. Provide service_name, function_name, or workflow_name."

---

## Summary

This skill formalizes the Architecture Legend into a structured, reusable tool for code-to-diagram transformation. By embedding all 7 legend sections and providing clear invocation methods (manual + automatic), it enables consistent, high-quality architectural visualization across different codebases and use cases.

**Key takeaway:** The legend is applied systematically in order (Sections 1-5 for UML, Section 6 for flows), with explicit error handling for oversized repos, circular dependencies, and invalid inputs.
