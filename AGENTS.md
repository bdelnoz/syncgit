<!--
Document : AGENTS.md
Auteur : Bruno DELNOZ
Email : bruno.delnoz@protonmail.com
Version : v3.0.0
Date : 2026-03-20 23:00
-->
# AGENTS.md

## 🔴 CRITICAL GIT WORKFLOW (HIGHEST PRIORITY)

- Every task MUST start from a clean and up-to-date `origin/main`.

- Before applying any change:
  - fetch origin
  - ensure working state is aligned with latest `origin/main`

- Before creating a PR:
  - fetch origin
  - rebase or reset onto latest `origin/main`
  - verify that HEAD strictly matches the latest `origin/main` base

- NEVER reuse a stale worktree, outdated branch, or obsolete branch state.
- NEVER continue working on a new change from the same branch after a PR has been merged.

- After a PR is merged:
  - the previous working branch/state MUST be considered obsolete
  - a NEW branch MUST be created from latest `origin/main`

- If the current environment is uncertain, stale, or diverged:
  - force refresh from `origin/main` before proceeding

- Avoid creating PRs from stale, diverged, reused, or outdated branches.

- Prefer:
  - one coherent task per branch
  - one fresh branch per merged PR

## Active instruction set

- This `AGENTS.md` file is the only active instruction source for this repository.
- Treat `AGENTS.md` as the only valid active rule set.
- Do not combine these repository rules with older external rule files or legacy rule sets.
- If this `AGENTS.md` file is updated later, the newest complete version becomes the only valid active instruction set for this repository.
- Do not summarize these repository rules.
- Do not reinterpret these repository rules.
- Apply these repository rules as written.
- Do not request, require, or depend on any external rule file when this `AGENTS.md` is present.

## General execution behavior

- Follow the user request directly.
- For script work, provide the **full complete script** immediately, even for a tiny modification.
- Do not provide partial patches instead of the full script when the request is about script generation or script correction.
- Do not simplify existing scripts.
- Do not remove existing features.
- Do not condense existing code.
- Do not reduce the number of lines compared with the previous version of a script.
- If the requested modification explicitly asks to simplify, remove, or condense existing content, ask for confirmation before producing that reduced version.
- When possible, provide generated content as downloadable files first; after that, ask whether the user also wants the content displayed in a Markdown box.

## Secrets and sensitive material

- Never place secrets, passwords, certificates, tokens, or similar sensitive values directly in versioned code.
- If a script needs secrets, use a local file at `./.secrets`.
- Ensure `./.secrets` is covered by `.gitignore`.
- Do not push secret material to git.

## Shell compatibility rules

- All `.sh` scripts must remain compatible with `sh`, `bash`, and `ksh` as far as possible.
- Use a retrocompatible shebang for shell scripts.
- Prefer portable shell syntax and avoid unnecessary shell-specific features.

## Script authoring rules

### Internal comments

- Comment each block and each section as much as possible to explain the internal logic.

### Mandatory header for executable scripts

Every executable script must start with a header containing at minimum:

- Full path and script name
- Author name
- Email
- Target usage / short purpose
- Version
- Date
- Changelog

### Author identity

Use the following values unless the user explicitly overrides them:

- Author: **Bruno DELNOZ**
- Email: **bruno.delnoz@protonmail.com**

### Versioning

- All generated scripts must be versioned and dated, even for a minor modification.
- The first version must start at **v1.0** or **v1.0.0**.
- Increment the version every time a script is produced again.
- The changelog must be updated every time.
- Do not add changelog entries that merely say new scripting rules were applied.

### Changelog rules

- Keep the complete version history in the script.
- No version entry may be omitted.
- `--changelog` must always exist.
- The changelog display should use Markdown formatting when possible.
- If a separate `CHANGELOG.md` file exists, it may hold the detailed history while the script keeps at least every version, its date, and a short explanation.

### Progress display

- When applicable, scripts must display execution progress.
- For multi-step execution, display the current step with its name and index, for example `Scan du disque (1/56)`.

## Mandatory CLI behavior for scripts

### Help

- A help block is mandatory.
- If no argument is provided, display help by default.
- `--help` must document every usage, every option, every argument, default values, all possible values, and several clear examples.

### Required options

Include these options whenever applicable and keep their behavior aligned with this `AGENTS.md`:

- `--help` / `-h`
- `--exec` / `-exe`
- `--stop` / `-st` when applicable
- `--prerequis` / `-pr`
- `--install` / `-i`
- `--simulate` / `-s`
- `--changelog` / `-ch`
- `--purge` / `-pu`

### Defaults

- Define default values when arguments are omitted.

### Simulate mode

- `--simulate` is inactive by default.
- The presence of `--simulate` alone activates dry-run mode.
- Do not require `true` or `false` values for `--simulate`.
- In simulate mode, reading, analysis, and logging remain active.
- Sensitive actions and system modifications must not execute for real while `--simulate` is present.

### Prerequisites

- Support prerequisite verification before execution.
- `--prerequis` must list prerequisites and report each one as satisfied or missing.
- If something is missing, handle it cleanly and propose `--install`.
- A skip path may exist when appropriate.

## Runtime output, logs, and artifacts

### Console explanations

- For each script execution, explain each step clearly in the console.
- Mirror the same logic in comments and in logs.

### Post-execution summary

- After execution, print a numbered list of all actions performed.

### Logs

- Create a `./logs` directory next to the script if it does not already exist.
- Write detailed logs there.
- Log filename pattern must follow the repository rule form defined in this `AGENTS.md`:
  - `./logs/log.<script_name>.<full_timestamp>.<script_version>.log`

### Results

- Create a `./results` directory next to the script if it does not already exist.
- Put generated content there.
- Generated filenames must be tied to the script name and version.
- Example: `./results/<other_name>.<script_name>.vX.X.txt`
- The destination folder for results must be overridable with `--dest_dir`.

## Sudo and ready-to-use behavior

- Prefer scripts that are ready to use immediately.
- Put `sudo` inside the script when possible.
- Avoid requiring the user to run `sudo ./script.sh` when internal elevation can be handled cleanly.
- Prefer zero external sudo when possible.

## Documentation generation rules

### Automatic files

For script projects, on first creation generate without asking:

- `./README.md`
- `./infos/README.md`
- `./CHANGELOG.md`
- `./infos/CHANGELOG.md`

Ask before generating:

- `./infos/USAGE.md`
- `./infos/INSTALL.md` (only if install instructions or dependencies are needed)
- `./infos/WHY.md`

### Major version updates

- On a major version bump (e.g. `3.2.0` → `4.0.0`), ask the user before updating `README.md` and `CHANGELOG.md`.

### Update behavior

- If one of the mandatory documentation files does not exist, create it automatically.
- Never delete or compress existing documentation files.
- If sections are missing, complete them automatically.
- Ensure generated `.md` files include:
  - full script name
  - precise date and time of last generation or modification
  - script version
  - authors and contacts

### CHANGELOG.md content

- `CHANGELOG.md` must exist both in `./` and `./infos/`.
- It must contain the version number, exact date and time, author name, and the full list of changes with a short description for each point.
- Keep the complete history of all versions.
- Never remove older versions.

## Metadata rules for documents and artifacts

### Executable non-shell scripts

- Executable scripts written in other languages (`.py`, `.js`, `.java`, `.ps1`, etc.) must carry the same header information as shell scripts.
- Only the comment syntax changes with the language.
- Place the header at the beginning of the file, after the shebang if applicable.
- Apply the same versioning and changelog rules as for shell scripts.

### Markdown documents

- A standalone `.md` document must start with a metadata block before the first title.
- The metadata must contain at minimum: document name or title, author, email, version, date and time.
- Use the following exact repository HTML comment format:

```md
<!--
Document : <Full document name>
Auteur : Bruno DELNOZ
Email : bruno.delnoz@protonmail.com
Version : vX.X.X
Date : YYYY-MM-DD HH:MM
-->
# <Document title>
```

- No changelog is required in a standalone `.md` document.
- If a `.md` file is generated as script documentation, it must also follow the documentation rules above.

### Text documents

- A standalone `.txt` document must start with a metadata block.
- The metadata must contain at minimum: document name or title, author, email, version, date and time.
- Use the following exact repository delimited metadata format:

```txt
----- SOLO DOCUMENT METADATA BEGIN -----
Document : <Full document name>
Auteur : Bruno DELNOZ
Email : bruno.delnoz@protonmail.com
Version : vX.X.X
Date : YYYY-MM-DD HH:MM
----- SOLO DOCUMENT METADATA END -----

<file content>
```

- No changelog is required in a standalone `.txt` document.

### DOCX documents

- A standalone `.docx` document must not contain a technical raw-text header block.
- Its first page or cover page must contain only:
  - document title or name
  - author
  - email
  - version
  - date and time
- No changelog is required in a standalone `.docx` document.

### PDF documents

- A standalone `.pdf` document follows the same logic as `.docx`.
- Its cover page must visibly contain:
  - document title or name
  - author
  - email
  - version
  - date and time
- Do not place a script-style technical header block inside the PDF content.
- No changelog is required in a standalone `.pdf` document.

## Repository expectations for Codex and Claude Code

- Treat this file as repository-wide instructions.
- Apply these rules before proposing code changes, reviews, or generated artifacts.
- When working inside this repository, prefer compliance with this file over generic habits.
- Keep outputs strict, direct, and operational.
