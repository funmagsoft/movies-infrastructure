---
description: "Stage changes and create a Conventional Commits message, then run git commit automatically."
alwaysApply: true
---

# Git Commit Command

You are an autonomous commit assistant. Execute a safe, deterministic Git commit workflow in this repository.

## Goals

- Stage changes (all or a well-justified subset) and create a commit using **Conventional Commits**.
- Do **not** ask the user for approval. Proceed automatically.
- If anything is ambiguous or risky, choose the safest option and explain what you did.

## Conventional Commits requirements

- See rules file `.cursor/rules/conventional-commits.mdc` for complete specification.
- Format: `<type>(optional scope): <description>`
- Valid types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `build`, `ci`
- Use `scope` only when obvious (module name, top-level folder, bounded component).

### Commit Message Format

The commit message must follow this exact format:

```text
<type>(optional scope): <subject>

- <change description 1>
- <change description 2>
- <change description 3>
```

**Rules:**

- Subject line: concise description (max 72 characters recommended)
- Empty line after subject (required)
- **No indentation between subject and body** - body starts at column 0
- Body: unordered list starting with `-`
- No empty lines between list items
- Each list item describes one change made in the commit
- If only subject is needed (single simple change), omit the body

**Examples:**

```text
docs: add terraform.tfvars.example for all environments

- Add terraform.tfvars.example for dev, test, stage, and prod environments
- Include environment configuration variables
- Include gitops_repos and additional_tags examples
- Add note about service configuration in services.tf
```

```text
feat(github-oidc): add GitOps repositories support
```

```text
refactor(cursor): reorganize configuration and add gitcc command

- Add gitcc command for Conventional Commits workflow
- Rename git-commands.mdc to conventional-commits.mdc
- Update .gitignore to include commands/ directory
```

## Execution steps (must follow)

1. Check repo status:
   - Run: `git status --porcelain`
   - If no changes: respond with "No changes to commit." and stop.

2. Inspect the change set:
   - Run: `git diff --stat`
   - Run: `git diff`
   - If there are already staged changes, also run:
     - `git diff --cached --stat`
     - `git diff --cached`

3. Decide what to stage (no user prompt):
   - **Note:** Pre-commit hooks will automatically format Terraform files (`terraform_fmt`), fix file endings (`end-of-file-fixer`), and validate syntax. No manual formatting needed.
   - Default to staging **all changes**: `git add -A`
   - Exception: if you detect clearly unrelated groups of changes (e.g., formatting-only across many files + a feature fix), then stage only the most coherent group and leave the rest unstaged. You must:
     - Explain the grouping decision briefly
     - Stage the coherent set explicitly (e.g., `git add <files...>`)
   - After staging, run:
     - `git status --porcelain`
     - `git diff --cached --stat`
     - `git diff --cached`

4. Generate the commit message from the **staged diff**:
   - Determine `type` by primary intent (see types above).
   - Determine `scope` only when obvious (package name, top-level folder, bounded module).
   - Write a concise subject line (max 72 characters recommended).
   - If multiple changes were made, create an unordered list in the body:
     - Start with empty line after subject
     - **No indentation** - each list item starts with `-` at column 0
     - No empty lines between list items
     - Each item describes one change made in the commit
   - Example format:

     ```text
     <type>(scope): <subject>

     - <change 1>
     - <change 2>
     - <change 3>
     ```

5. Commit (no approval):
   - Create a temporary file with the commit message (to preserve exact formatting):

     ```bash
     cat > /tmp/commit_msg.txt << 'EOF'
     <type>(scope): <subject>

     - <change 1>
     - <change 2>
     EOF
     ```

   - Commit using the file:

     ```bash
     git commit -F /tmp/commit_msg.txt
     ```

   - **Note:** Pre-commit hooks will run automatically:
     - `terraform_fmt`: Formats Terraform files (may modify files)
     - `terraform_validate`: Validates Terraform syntax
     - `end-of-file-fixer`: Ensures files end with exactly one newline
     - `validate-commit-msg`: Validates commit message format (Conventional Commits)

   - If hooks modify files, you may need to re-stage and amend the commit.

6. Post-commit report:
   - Run: `git log -1 --oneline`
   - Run: `git status --porcelain`
   - Summarize what was staged and the final commit message.

## Safety constraints

- Never include secrets, tokens, or credentials in the commit message.
- Do not amend, rebase, or push.
- If `git commit` fails (hooks, conflicts, etc.), report the exact error output and what remains staged.
- If pre-commit hooks modify files (e.g., `terraform_fmt`, `end-of-file-fixer`), the commit may be blocked. In such cases:
  - Re-stage the modified files: `git add -A`
  - Re-run the commit with the same message.
- The `validate-commit-msg` hook will verify the commit message format. If it fails, the commit will be rejected. Fix the message format and try again.
