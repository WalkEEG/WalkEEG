# Commit Convention

All commit messages in this repository are **English only**. No Chinese, no mixed-language subjects.

## Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Subject line

- **Imperative mood** — `add`, not `added` or `adds` (it completes "If applied, this commit will …").
- **Lowercase** after the type/scope prefix.
- **No trailing period.**
- **≤ 72 characters.**
- Scope is optional but preferred: `docs`, `app`, `firmware`, `backend`, `algorithms`, `wiki`, `relay`, `hardware`.

### Types

| Type | Use for |
|---|---|
| `feat` | New capability |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `refactor` | Restructure without behaviour change |
| `perf` | Performance improvement |
| `test` | Tests only |
| `build` | Build system, dependencies |
| `ci` | CI configuration |
| `chore` | Maintenance, no source or test change |
| `revert` | Reverts a previous commit |

### Examples

```
feat(algorithms): extract platform-neutral statistics module
fix(app): restore cloud config compile chain
docs(wiki): link CMRR and 10-20 system terms
chore: remove dangling 05-APP submodule reference
```

Avoid these:

```
<non-English subject>      ← not English
fix: Fixed the bug.      ← past tense, trailing period
update                    ← no type, no scope, says nothing
WIP                       ← never commit work in progress to a shared branch
```

## Body

Use the body to explain **why**, not what — the diff already shows what changed.

- Wrap at 72 characters.
- Separate from the subject with one blank line.
- Bullet points are fine.
- If the change is not obvious from the diff, the body is not optional.

## Footer

- `Closes #123` — links to an issue.
- `BREAKING CHANGE: …` — required when callers must update their code.

## Policy

1. **English only.** This keeps history readable for anyone, and avoids mojibake in every non-CJK terminal.
2. **One logical change per commit.** Do not mix a rename with a refactor with a dependency bump.
3. **Never commit build output.** `obj/`, `bin/`, `build/`, `.dart_tool/`, `node_modules/` are git-ignored; see [`.gitignore`](../.gitignore).
4. **Never commit secrets.** Deployment values live in git-ignored local files (`app_config.dart`, `config.js`).
5. **Code, comments and identifiers are English too.** This document covers commits, but the same rule applies repo-wide — see [language policy](#language-policy).

## Language policy

| Content | Language |
|---|---|
| Code, comments, identifiers, commit messages | **English** |
| Documentation under `docs/`, `algorithms/`, component READMEs | **English** |
| `LICENSE` | Bilingual by design — English is authoritative, the Chinese section is a reference translation |
| User-facing UI strings | May be localized separately; keep source strings English and translate at the presentation layer |

Rationale: a single language for code and docs removes an entire class of review overhead, makes diffs searchable, and lets contributors who do not read Chinese work on the firmware and app without a translation step.

## Enforcing locally (optional)

Add a pre-commit hook if you want a fast guard:

```bash
# .git/hooks/commit-msg
if head -1 "$1" | grep -q '[^[:print:]]' && head -1 "$1" | perl -CS -ne 'exit 1 if /[\x{4e00}-\x{9fff}]/'; then
  echo "Commit subject must be English only." >&2
  exit 1
fi
```

Hooks are local and not committed; treat this as a convenience, and rely on review for the actual guarantee.
