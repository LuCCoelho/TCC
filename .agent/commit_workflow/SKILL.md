---
name: commit-workflow
description: Build well-structured git commits by analyzing changed files and splitting work into logical chunks. Use when the user asks to commit, create commits, stage changes, review diffs for committing, or organize uncommitted work into commits.
---

# Commit Workflow

How to analyze uncommitted changes, split them into logical chunks, and create clean git commits. Commit subjects should follow **Conventional Commits**: **`type: SUMMARY`**, with an optional **Linear issue id** after the type when the change maps to a ticket (e.g. `feat: HUB-1222 add session endpoint` or `feat: add session endpoint`).

## Step 1: Assess the working tree

Run these in parallel:

```bash
git status
git diff                 # unstaged changes
git diff --cached        # staged changes
git log --oneline -5     # recent style reference
```

Read the output carefully. Identify every changed, added, and deleted file.

## Step 2: Categorize changes into logical chunks

Group files by **purpose**, not by file type or directory. Each commit should represent one cohesive unit of work. Common grouping strategies:

| Signal | Example chunk (subject line) |
|--------|-----------------------------|
| Schema change + migration + seed update | `feat: HUB-123 add CreditProduct model` |
| New API route + its tests | `feat: HUB-456 implement GET /api/credits/balance` |
| Component + hook + translations it needs | `feat: HUB-789 add credit purchase modal` |
| Multiple files all fixing the same bug | `fix: HUB-101 prevent double-charge on PIX webhook retry` |
| Docs-only changes (AGENTS.md, READMEs, /docs) | `docs: HUB-202 document credit purchase flow` |
| Config/CI/tooling (tsconfig, eslint, workflows) | `build: HUB-303 add typecheck step to CI` |
| Pure refactor with no behavior change | `refactor: HUB-404 extract auth helpers from middleware` |
| Test-only additions or fixes | `test: HUB-1222 Modified test file for better coverage` |

**Splitting rules:**

- If a file serves two purposes (e.g., a util used by both a new feature and a bug fix), attribute it to the primary chunk; mention the secondary benefit in the commit body.
- Prefer smaller, focused commits over large ones. A commit touching 15+ files across unrelated concerns should almost always be split.
- Migrations and schema changes go in their own commit, before the code that uses them.
- Translation file changes (`messages/*.json`) go with the feature that introduced the new keys.
- Test files go with the code they test, unless the commit is test-only.

## Step 3: Stage and commit each chunk

For each chunk, stage only the relevant files:

```bash
git add path/to/file1 path/to/file2
```

Then commit. Always use a HEREDOC for the message to preserve formatting. Subject line: `type: SUMMARY` or `type: TICKET_NUMBER SUMMARY` when linking to Linear:

```bash
git commit -m "$(cat <<'EOF'
feat: HUB-1222 Modified test file for better coverage

Optional body explaining WHY, not what. Include context that isn't
obvious from the diff: trade-offs, constraints, related issues.
EOF
)"
```

After each commit, run `git status` to confirm the remaining working tree is as expected before proceeding to the next chunk.

## Commit message format

Subject line should follow:

```
type: SUMMARY
```

or, when tying work to Linear:

```
type: TICKET_NUMBER SUMMARY
```

Examples: `feat: add session endpoint`, `feat: HUB-1222 Modified test file for better coverage`

### Structure

```
type: [TICKET_NUMBER ]Short summary in imperative mood

[optional body]
```

- **type** — Required. Use the type that best fits the change (see table below). Do **not** use scope in parentheses (e.g. use `feat:`, never `feat(api):`).
- **TICKET_NUMBER** — Optional but recommended when a Linear issue exists (e.g. `HUB-1222`, `HUB-456`).
- **SUMMARY** — Required. Short description; imperative mood ("add", "fix", "remove"); no trailing period; keep subject line under ~72 characters.

### Type (required)

| Type | When to use |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `perf` | Performance improvement |
| `test` | Adding or fixing tests |
| `docs` | Documentation only |
| `build` | Build system, CI, dependencies |
| `chore` | Maintenance (cleanup, formatting, tooling config) |
| `style` | Code style/formatting (no logic change) |
| `revert` | Reverts a previous commit (reference the reverted SHA in body/footer) |
| `hotfix` | Urgent production fix (same spirit as `fix`; use whichever your team prefers) |

### Body (optional)

Include a body when the change is non-trivial, the "why" isn’t obvious, or you need to document trade-offs or constraints. Start one blank line after the subject. Wrap at 72 characters. Explain **why**, not what.

### Examples

**Minimal (subject only):**
```
fix: HUB-100 correct date format in reading session list
```

**With ticket and summary:**
```
feat: HUB-456 implement GET /api/sessions/:id endpoint
```

**With body:**
```
perf: HUB-789 add Cache-Control headers to API routes

- reading-types, products: public, s-maxage=3600, stale-while-revalidate=86400
- credits/balance, sessions/pending-count: private, max-age=10, stale-while-revalidate=30
```

**Revert:**
```
revert: HUB-101 revert session payload change

Refs: 676104e, a215868
```

## Forbidden patterns

**Never include AI-attribution trailers or metadata:**

- `Made-with: Cursor`
- `Made with Cursor`
- `Generated by Claude`
- `Co-authored-by: Cursor` / `Co-authored-by: Claude` / any AI co-author
- `Made-with: <any AI tool>`
- Any similar "made with", "generated by", "assisted by" attribution to an AI tool

These add no value to the git history and leak tooling details into the permanent record.

**Other anti-patterns to avoid:**

- **Scope in parentheses** — Never put a Linear ticket in `(scope)`. Use `feat: HUB-1222 Add feature`, not `feat(HUB-1222): Add feature`. Optional non-ticket scopes like `feat(api):` are allowed if your team uses them; the ticket still goes after the colon when present (`feat: HUB-1222 …`).
- **Missing summary** — Do not leave the subject empty after the colon (e.g. avoid `feat:` with no description).
- Vague summaries: "fix: HUB-1 stuff", "chore: HUB-2 updates"
- Kitchen-sink commits: "feat: HUB-3 too many changes to keep track"
- WIP commits: "wip: HUB-4 working on it" (if work is incomplete, describe what was done in the summary)
- Profanity or jokes in commit messages
- Repeating the file list in the body (the diff already shows this)
- Adding `Signed-off-by` unless the project requires DCO

## Workflow summary

```
1. git status + git diff          → see all changes
2. Group files by purpose         → plan N commits
3. For each chunk:
   a. git add <files>             → stage the chunk
   b. git commit (HEREDOC)        → write a good message
   c. git status                  → verify remaining state
4. Done when working tree is clean (or only unrelated files remain)
```
