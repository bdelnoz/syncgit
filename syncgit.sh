#!/usr/bin/env bash
# ==============================================================================
# PATH         : ~/scripts/syncgit.sh
# SCRIPT NAME  : syncgit.sh  (no version in filename – version is inside)
# AUTHOR       : Bruno DELNOZ
# EMAIL        : bruno.delnoz@protonmail.com
# TARGET USAGE : Recursively scans a root directory to find all Git
#                repositories (directories containing a .git folder),
#                then for each repo either:
#                  (a) runs the default Git sync sequence on a chosen branch:
#                        git branch syncgit-snapshot/YYYYMMDD-HHhMM
#                        git checkout <branch>
#                        git add .
#                        git commit -m "commit last version done by syncgit.sh user: <USER>   date : <YYYY-MM-DD> time <HH:MM:SS>"
#                        git push --set-upstream --force origin <branch>
#                  (b) runs a custom shell command via --cmd "<cmd>"
# VERSION      : v1.3.7
# DATE         : 2026-03-28
# ==============================================================================
# CHANGELOG (summary – full detail in ./infos/CHANGELOG.md):
#   v1.3.7 – 2026-03-28 – Bruno DELNOZ
#       Changed:
#       - ADDED: --cpagentsmd option to copy ${SCRIPT_DIR}/AGENTS.md
#                into every detected repository before any other repo operation
#                (forced overwrite when destination file already exists).
#   v1.3.6 – 2026-03-27 – Bruno DELNOZ
#       Changed:
#       - ADDED: --forcepush / -f option to override the remote-ahead guard.
#                When enabled, pushes proceed even if origin/<branch> is ahead.
#   v1.3.5 – 2026-03-27 – Bruno DELNOZ
#       Changed:
#       - UPDATED: final "Actions performed" display now numbers only
#                repository-level actions (SYNCED/FAILED/EXCLUDED).
#                Global run actions (directories/root scan) are shown unnumbered.
#   v1.3.4 – 2026-03-27 – Bruno DELNOZ
#       Changed:
#       - ADDED: pre-push guard for default sync:
#                if origin/<branch> is ahead of local <branch>, skip push steps
#                and report FAILED - remote ahead from local
#   v1.3.3 – 2026-03-27 – Bruno DELNOZ
#       Changed:
#       - UPDATED: default commit message now includes user/date/time
#   v1.3.2 – 2026-03-27 – Bruno DELNOZ
#       Feature:
#       - ADDED: create snapshot branch before default sync steps:
#                syncgit-snapshot/YYYYMMDD-HHhMM
#   v1.3.1 – 2026-03-05 – Bruno DELNOZ
#       Bugfix + Feature:
#       - FIXED: remote conversion direction was wrong (HTTPS→SSH); corrected to
#                SSH→HTTPS: git@github.com: / git@gitlab.com: → https://
#                Warning: SYNCED - WARNING SSH to HTTPS applied
#       - ADDED: --exclude "repo1;repo2;..." – skip named repos from processing;
#                shown as ⊘ EXCLUDED in output and counted as skipped
#       - ADDED: large file detection on push failure (blobs > 100MB in history)
#                reported as FAILED - BIG FILES DETECTED on screen and report;
#                full list written to logs/largefiles.<TIMESTAMP>.log
#       - ADDED: stderr capture – displayed on screen AND written to
#                logs/stderr.<TIMESTAMP>.log (via tee)
#       - ADDED: if branch 'main' missing and 'master' exists, auto-create main
#                from master; reported as SYNCED - WARNING main does not exists - created from master
#       - ADDED: if current branch has uncommitted changes blocking checkout to
#                main, auto-commit as "wip" then switch; reported as
#                SYNCED - WARNING current branch <name> behind main
#   v1.2.1 – 2026-03-03 – Bruno DELNOZ
#       Bugfix:
#       - FIXED: git add (and all git cmds) could block indefinitely on repos
#                containing embedded .git dirs (git awaiting stdin confirmation).
#                Fixed by redirecting stdin to /dev/null in run_cmd (bash -c/-ic).
#                (GIT_TERMINAL_PROMPT left untouched – preserves HTTPS credentials.)
#   v1.2.0 – 2026-03-03 – Bruno DELNOZ
#       Bugfixes:
#       - FIXED: cd without returning to original dir in repo loop (pushd/popd)
#       - FIXED: RESULT_FILE computed with empty RUN_TS during arg parsing
#       - FIXED: _check_one() nested inside check_prerequisites() → global scope
#       - FIXED: read without fallback in install_prerequisites (stdin pipe/cron)
#       - FIXED: generate_docs() was overwriting ./README.md and ./CHANGELOG.md
#                on every --exec run → now writes only to ./infos/
#       - FIXED: find picked up git submodule .git dirs → added prune logic
#       - ADDED: --branch name validation (rejects spaces and shell-unsafe chars)
#   v1.1.0 – 2026-02-28 – Bruno DELNOZ
#       Merged improvements from alternate version (v1.3.0 reference):
#       Added set -Eeuo pipefail + IFS safety, ts_now/ts_human/die/sep helpers,
#       --recurrent <seconds>, --root_dir (replaces
#       --base_dir), --results_dir alias for --dest_dir, --yes for --purge,
#       SCRIPT_DIR auto-detection, removed version from filename.
#   v1.0.1 – 2026-02-28 – Bruno DELNOZ
#       Fixed: gita is a shell alias not a git alias. Added bash -i -c
#       execution, --cmd option (renamed from --alias).
#   v1.0.0 – 2026-02-28 – Bruno DELNOZ
#       Initial release. Recursive git repo scanner, branch switcher, shell
#       command runner. Full argument support, progress display, logs, results,
#       prerequisite checker, simulate mode, README/CHANGELOG auto-generation.
# ==============================================================================

# ==============================================================================
# SECTION 0 – STRICT MODE & SAFETY
# set -E  : ERR trap inherited by functions and subshells
# set -e  : exit immediately on any non-zero exit code
# set -u  : treat unset variables as errors
# set -o pipefail : a pipeline fails if any command in it fails
# IFS     : restrict word splitting to newlines and tabs (safer for filenames)
# ==============================================================================
set -Eeuo pipefail
IFS=$'\n\t'

# ==============================================================================
# SECTION 1 – SCRIPT METADATA & GLOBAL CONSTANTS
# ==============================================================================

SCRIPT_NAME="syncgit.sh"
SCRIPT_VERSION="v1.3.7"
SCRIPT_DATE="2026-03-28"
AUTHOR="Bruno DELNOZ"
EMAIL="bruno.delnoz@protonmail.com"

# Resolve the absolute directory where this script lives, regardless of CWD.
# This ensures ./logs, ./results, ./infos are always relative to the script.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# ==============================================================================
# SECTION 2 – DEFAULT VALUES
# All runtime parameters are set here and can be overridden by CLI arguments.
# ==============================================================================

DEFAULT_ROOT_DIR="."                          # Root dir to scan (default: current dir)
DEFAULT_DEST_DIR="${SCRIPT_DIR}/results"      # Output folder for result files
DEFAULT_LOGS_DIR="${SCRIPT_DIR}/logs"         # Folder for log files
DEFAULT_INFOS_DIR="${SCRIPT_DIR}/infos"       # Folder for documentation .md files
DEFAULT_BRANCH="main"                         # Git branch to work on

# --- Runtime variables (overridden by parsed CLI arguments) ---
ROOT_DIR="${DEFAULT_ROOT_DIR}"
DEST_DIR="${DEFAULT_DEST_DIR}"
LOGS_DIR="${DEFAULT_LOGS_DIR}"
INFOS_DIR="${DEFAULT_INFOS_DIR}"
BRANCH="${DEFAULT_BRANCH}"

# --- Optional / flags ---
SIMULATE=0                  # 0=real execution, 1=dry-run (set by --simulate)
RECURRENT=0                 # 0=run once, 1=run in loop (set by --recurrent)
RECURRENT_SECONDS=""        # Interval in seconds between recurrent runs
CUSTOM_CMD=""               # If set via --cmd, replaces the default git sequence
EXCLUDE_LIST=""             # Semicolon-separated list of repo names to skip (--exclude)
ACTION_MODE=""              # Which primary action was requested
PURGE_YES=0                 # Safety flag: purge only proceeds if --yes is also passed
FORCE_PUSH=0                # 1 = bypass remote-ahead guard and force push anyway
CP_AGENTS_MD=0              # 1 = copy SCRIPT_DIR/AGENTS.md into each detected repo

# --- Runtime state (computed at startup via init_run_context) ---
RUN_TS=""                   # Timestamp string generated at run start
LOG_FILE=""                 # Full path to the log file for this run
RESULT_FILE=""              # Full path to the result summary file for this run
STDERR_LOG=""               # Full path to the stderr log for this run
LARGEFILE_LOG=""            # Full path to the large files log for this run

# --- Per-repo state (reset at the start of each repo) ---
REPO_SYNC_WARNING=""        # Warning message for current repo (SSH→HTTPS, wip, etc.)
LARGE_FILES_FOUND=0         # 1 if large files (>100MB) detected in git history
REPO_FAIL_REASON=""         # Explicit failure reason for current repo (if set)

# --- Execution counters ---
TOTAL_REPOS=0
REPOS_SYNCED=0
REPOS_SKIPPED=0
REPOS_FAILED=0
STEP_CURRENT=0
STEP_TOTAL=5

# --- Array to record every action performed ---
declare -a ACTIONS_DONE=()

# ==============================================================================
# SECTION 3 – UTILITY & LOGGING FUNCTIONS
# ==============================================================================

# ------------------------------------------------------------------------------
# Function : ts_now
# Purpose  : Return a compact timestamp string for filenames (no spaces/colons).
# Output   : e.g. 20260303-143022
# ------------------------------------------------------------------------------
ts_now() {
    date '+%Y%m%d-%H%M%S'
}

# ------------------------------------------------------------------------------
# Function : ts_human
# Purpose  : Return a human-readable timestamp for log lines.
# Output   : e.g. 2026-03-03 14:30:22
# ------------------------------------------------------------------------------
ts_human() {
    date '+%Y-%m-%d %H:%M:%S'
}

# ------------------------------------------------------------------------------
# Function : log
# Purpose  : Write a tagged, timestamped message to stdout AND the log file.
# Args     : $1 = level string (INFO / WARN / ERROR / SIM / OK / STEP / FATAL)
#            $@ = message content (all remaining args joined as one message)
# ------------------------------------------------------------------------------
log() {
    local level="$1"; shift
    local msg="$*"
    local line="[${SCRIPT_VERSION}] [$(ts_human)] [${level}] ${msg}"
    echo "${line}"
    # Write to log file only after LOG_FILE path has been initialized
    if [[ -n "${LOG_FILE:-}" && -d "${LOGS_DIR}" ]]; then
        echo "${line}" >> "${LOG_FILE}"
    fi
}

# ------------------------------------------------------------------------------
# Function : die
# Purpose  : Log a FATAL error and exit immediately with code 1.
# Args     : $@ = error message
# ------------------------------------------------------------------------------
die() {
    log "FATAL" "$*"
    exit 1
}

# ------------------------------------------------------------------------------
# Function : sep
# Purpose  : Print a visual separator line to stdout and the log file.
# ------------------------------------------------------------------------------
sep() {
    log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ------------------------------------------------------------------------------
# Function : log_action
# Purpose  : Append a completed action to ACTIONS_DONE array and log it.
# Args     : $1 = human-readable description of the action
# ------------------------------------------------------------------------------
log_action() {
    local action="$1"
    ACTIONS_DONE+=("${action}")
    log "OK" "ACTION: ${action}"
}

# ------------------------------------------------------------------------------
# Function : print_step
# Purpose  : Display step progress in format: ">>> LABEL (N/TOTAL)"
# Args     : $1 = current step, $2 = total steps, $3 = label
# ------------------------------------------------------------------------------
print_step() {
    local current="$1"
    local total="$2"
    local label="$3"
    log "STEP" ">>> ${label} (${current}/${total})"
}

# ==============================================================================
# SECTION 4 – COMMAND EXECUTION HELPER
# Centralises how commands are run, enforcing simulate mode uniformly.
# Commands are executed via bash -c in a non-interactive shell.
# ==============================================================================

# ------------------------------------------------------------------------------
# Function : run_cmd
# Purpose  : Execute a command string (real or simulated).
#            In SIMULATE mode: only logs what WOULD be executed.
#            In real mode: executes via bash -c.
# Args     : $1 = human-readable description
#            $2 = command string to execute
# Returns  : exit code of the command (0 in simulate mode)
# ------------------------------------------------------------------------------
run_cmd() {
    local desc="$1"
    local cmd_str="$2"

    if [[ "${SIMULATE}" -eq 1 ]]; then
        log "SIM" "[DRY-RUN] WOULD EXECUTE: ${desc}"
        log "SIM" "          Command: ${cmd_str}"
        return 0
    fi

    log "INFO" "EXECUTING: ${desc}"
    log "INFO" "  Command: ${cmd_str}"

    local exit_code=0
    # Non-interactive bash. Stdin from /dev/null prevents any subprocess from
    # blocking on a credential/confirmation prompt with no terminal attached.
    # Stderr is tee'd: displayed on screen AND captured in STDERR_LOG.
    bash -c "${cmd_str}" < /dev/null 2> >(tee -a "${STDERR_LOG:-/dev/null}" >&2) || exit_code=$?

    if [[ "${exit_code}" -ne 0 ]]; then
        log "ERROR" "Command failed (exit ${exit_code}): ${cmd_str}"
    fi
    return "${exit_code}"
}

# ==============================================================================
# SECTION 5 – DIRECTORY SETUP
# Ensures ./logs, ./results, ./infos exist before any operation.
# Creates them automatically if missing.
# ==============================================================================

setup_directories() {
    log "INFO" "Setting up required directories..."

    # Create logs directory if it does not exist
    if [[ ! -d "${LOGS_DIR}" ]]; then
        mkdir -p "${LOGS_DIR}"
        echo "[INFO] Created logs directory: ${LOGS_DIR}"
    fi

    # Create results/dest directory if it does not exist
    if [[ ! -d "${DEST_DIR}" ]]; then
        mkdir -p "${DEST_DIR}"
        log "INFO" "Created results directory: ${DEST_DIR}"
    fi

    # Create infos directory for documentation markdown files
    if [[ ! -d "${INFOS_DIR}" ]]; then
        mkdir -p "${INFOS_DIR}"
        log "INFO" "Created infos directory: ${INFOS_DIR}"
    fi

    log "INFO" "Directory setup complete."
}

# ==============================================================================
# SECTION 6 – INITIALIZE RUN CONTEXT
# Sets up the timestamp, log file path, and result file path for this run.
# Must be called after setup_directories() so that LOG_FILE can be written.
# ==============================================================================

init_run_context() {
    RUN_TS="$(ts_now)"
    LOG_FILE="${LOGS_DIR}/log.${SCRIPT_NAME}.${RUN_TS}.log"
    RESULT_FILE="${DEST_DIR}/summary.${SCRIPT_NAME}.${RUN_TS}.txt"
    STDERR_LOG="${LOGS_DIR}/stderr.${SCRIPT_NAME}.${RUN_TS}.log"
    LARGEFILE_LOG="${LOGS_DIR}/largefiles.${SCRIPT_NAME}.${RUN_TS}.log"
    log "INFO" "Run context initialized."
    log "INFO" "  Log file      : ${LOG_FILE}"
    log "INFO" "  Result file   : ${RESULT_FILE}"
    log "INFO" "  Stderr log    : ${STDERR_LOG}"
    log "INFO" "  Largefile log : ${LARGEFILE_LOG}"
}

# ==============================================================================
# SECTION 7 – HELP DISPLAY
# Shown automatically when no argument is given, or when --help / -h is passed.
# Lists all options with defaults and possible values.
# ==============================================================================

show_help() {
    cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ${SCRIPT_NAME}  –  ${SCRIPT_VERSION}  –  ${SCRIPT_DATE}
  Author : ${AUTHOR} <${EMAIL}>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DESCRIPTION:
  Recursively scans a root directory for Git repositories (.git dirs).
  For each repo found, either:
    (a) Default git sync sequence:
          git branch syncgit-snapshot/YYYYMMDD-HHhMM
          git checkout <branch>
          git add .
          git commit -m "commit last version done by syncgit.sh user: <USER>   date : <YYYY-MM-DD> time <HH:MM:SS>"  (skipped if nothing to commit)
          [guard] skip push if origin/<branch> is ahead of local (<branch>)
          git push --set-upstream --force origin <branch>
          git push --force origin --all
    (b) Custom command via --cmd "<command>"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
USAGE:
  ./${SCRIPT_NAME} [ACTION] [OPTIONS]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ACTIONS (one required):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  --exec,       -exe   Scan repos and execute the sync action.
  --simulate,   -s     Dry-run: scan and log all actions, no real changes.
  --prerequis,  -pr    Check prerequisites and display their status.
  --install,    -i     Install / configure missing prerequisites.
  --changelog,  -ch    Display the full embedded changelog.
  --purge,      -pu    Delete ./logs and ./results (requires --yes).
  --help,       -h     Display this help message.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OPTIONS (for use with --exec):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  --root_dir <path>        Root directory to scan recursively.
                           Default : ${DEFAULT_ROOT_DIR}
                           Possible: any absolute or relative path
                           Example : /mnt/data/projects

  --dest_dir <path>        Destination folder for result files.
                           Alias   : --results_dir
                           Default : ${DEFAULT_DEST_DIR}
                           Possible: any writable directory path

  --results_dir <path>     Alias of --dest_dir (same effect).

  --logs_dir <path>        Folder for log files.
                           Default : ${DEFAULT_LOGS_DIR}

  --branch <name>          Git branch to use in default sync sequence.
                           Default : ${DEFAULT_BRANCH}
                           Possible: main, master, develop, or any valid branch
                           Validated: only alphanumeric, /, _, -, . allowed

  --forcepush, -f          Bypass remote-ahead protection in default sync.
                           If origin/<branch> is ahead of local, pushes are
                           still executed when this flag is enabled.
                           Default : off (safe mode on)

  --cpagentsmd             Copy ${SCRIPT_DIR}/AGENTS.md into each detected
                           repository BEFORE any repo operation.
                           Destination: <repo>/AGENTS.md
                           Behavior : forced overwrite if file already exists.
                           Default  : off

  --simulate, -s           Dry-run mode: logs all actions, makes no changes.
                           Presence of this flag alone activates simulation.
                           Default : off

  --cmd "<command>"        Custom shell command to run in each repo instead
                           of the default sync sequence.
                           If omitted, the default sequence runs:
                             [a] git branch syncgit-snapshot/YYYYMMDD-HHhMM
                             [b] git checkout <branch>
                             [c] git add .
                             [d] git commit -m "commit last version done by syncgit.sh user: <USER>   date : <YYYY-MM-DD> time <HH:MM:SS>"
                             [guard] if origin/<branch> is ahead -> FAILED "remote ahead from local"
                             [e] git push --set-upstream --force origin <branch>
                             [f] git push --force origin --all
                           Example : "git pull --rebase"
                           Example : "rm -f .gigi"


  --recurrent <seconds>    Repeat the full run every N seconds until Ctrl+C.
                           Default : disabled (run once)
                           Example : --recurrent 300  (repeat every 5 minutes)

  --exclude "<list>"        Semicolon-separated list of repo names to skip.
                           Matched against the basename of each repo path.
                           Example : --exclude "LinkedIn-Learning-Downloader;toto;tata"

OPTIONS (for use with --purge):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  --yes                    Required confirmation flag for --purge.
                           Without it, purge will abort safely.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EXAMPLES:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  # Check prerequisites:
  ./${SCRIPT_NAME} --prerequis

  # Default sync on all repos under current directory:
  ./${SCRIPT_NAME} --exec

  # Default sync on a specific root directory:
  ./${SCRIPT_NAME} --exec --root_dir /mnt/data/Security

  # Simulate (dry-run) – no real changes:
  ./${SCRIPT_NAME} --exec --root_dir /mnt/data/Security --simulate

  # Run a custom shell command in each repo:
  ./${SCRIPT_NAME} --exec --cmd "git pull --rebase"

  # Run a direct shell command in each repo:
  ./${SCRIPT_NAME} --exec --cmd "rm -f .gigi" --root_dir /mnt/data/Security

  # Use master branch instead of main:
  ./${SCRIPT_NAME} --exec --branch master

  # Force push even if remote branch is ahead (bypass protection):
  ./${SCRIPT_NAME} --exec --root_dir /mnt/data/Security --forcepush

  # Copy master AGENTS.md into each repo before processing:
  ./${SCRIPT_NAME} --exec --root_dir /mnt/data/Security --cpagentsmd

  # Repeat every 10 minutes automatically:
  ./${SCRIPT_NAME} --exec --root_dir /mnt/data --recurrent 600

  # Purge all logs and results (requires --yes):
  ./${SCRIPT_NAME} --purge --yes

  # Show full changelog:
  ./${SCRIPT_NAME} --changelog

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FILES GENERATED:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Logs    : ./logs/log.${SCRIPT_NAME}.<TIMESTAMP>.log
  Results : ./results/summary.${SCRIPT_NAME}.<TIMESTAMP>.txt
  Docs    : ./infos/README.md  ./infos/CHANGELOG.md

EOF
    exit 0
}

# ==============================================================================
# SECTION 8 – CHANGELOG DISPLAY
# ==============================================================================

show_changelog() {
    cat <<'EOF'

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  CHANGELOG – syncgit.sh
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## v1.3.7 – 2026-03-28 – Bruno DELNOZ
  - ADDED: --cpagentsmd to copy ${SCRIPT_DIR}/AGENTS.md into each detected
           repository before any other repo operation.
           Destination AGENTS.md is always overwritten.

## v1.3.6 – 2026-03-27 – Bruno DELNOZ
  - ADDED: --forcepush / -f to bypass remote-ahead protection.
           With this option, push steps still run even if origin/<branch>
           is ahead of local.

## v1.3.5 – 2026-03-27 – Bruno DELNOZ
  - UPDATED: post-exec "Actions performed" display now numbers only
           repository actions (SYNCED/FAILED/EXCLUDED).
           Global run actions are shown as unnumbered bullet lines.

## v1.3.4 – 2026-03-27 – Bruno DELNOZ
  - ADDED: remote-ahead guard before push in default sequence.
           If origin/<branch> is ahead of local <branch>, push steps are skipped
           and repo is reported as: FAILED - remote ahead from local

## v1.3.3 – 2026-03-27 – Bruno DELNOZ
  - UPDATED: default commit message now includes user/date/time:
           commit last version done by syncgit.sh user: <USER>   date : <YYYY-MM-DD> time <HH:MM:SS>

## v1.3.2 – 2026-03-27 – Bruno DELNOZ
  - ADDED: create snapshot branch before default sync sequence:
           git branch syncgit-snapshot/YYYYMMDD-HHhMM

## v1.3.1 – 2026-03-05 – Bruno DELNOZ
  - FIXED: remote conversion was HTTPS→SSH (wrong direction); corrected to
           SSH→HTTPS: git@github.com: / git@gitlab.com: → https://github.com/ / https://gitlab.com/
           Output: SYNCED - WARNING SSH to HTTPS applied
  - ADDED: --exclude "repo1;repo2;..." – skip specific repos by basename;
           shown as ⊘ EXCLUDED in output, counted as skipped in summary

## v1.3.0 – 2026-03-04 – Bruno DELNOZ
  - ADDED: auto-conversion SSH→HTTPS for github.com/gitlab.com remotes
           (corrected direction in v1.3.1); output: SYNCED - WARNING SSH to HTTPS applied
  - ADDED: large file detection on push failure (blobs >100MB in git history);
           output on screen+report: FAILED - BIG FILES DETECTED;
           full list in logs/largefiles.<TIMESTAMP>.log
  - ADDED: stderr capture – displayed on screen as before AND written to
           logs/stderr.<TIMESTAMP>.log (via tee)
  - ADDED: if branch 'main' missing and 'master' exists → auto-create main from
           master and continue; output: SYNCED - WARNING main does not exists - created from master
           if neither main nor master → FAILED with explicit message
  - ADDED: if current branch has uncommitted changes blocking checkout to main
           → auto git add + commit "wip" then switch to main;
           output: SYNCED - WARNING current branch <name> behind main

## v1.2.1 – 2026-03-03 – Bruno DELNOZ
  - FIXED: git add (and any git cmd) could hang indefinitely on repos with
           embedded .git dirs (nested submodule-like repos not yet registered).
           Git was waiting for interactive stdin that never arrives.
           Fix: run_cmd now redirects stdin < /dev/null for both bash -c and
           bash -ic modes — no subprocess can block waiting for terminal input.
           (GIT_TERMINAL_PROMPT intentionally left untouched to preserve
           credential prompts for HTTPS push.)

## v1.2.0 – 2026-03-03 – Bruno DELNOZ
  - FIXED: cd without returning to original dir in repo loop (pushd/popd)
  - FIXED: RESULT_FILE computed with empty RUN_TS during arg parsing (removed
           stray assignment in --dest_dir case; init_run_context() owns this)
  - FIXED: _check_one() was nested inside check_prerequisites() → moved to
           global scope as prereq_check_one() for bash strict-mode safety
  - FIXED: read without fallback in install_prerequisites() – fails on
           non-interactive stdin (pipe/cron); added || answer="N" guard
  - FIXED: generate_docs() was overwriting ./README.md and ./CHANGELOG.md at
           every --exec run, erasing manual edits; now writes only to ./infos/
  - FIXED: find picked up .git dirs inside git submodule paths (.git/modules);
           added -not -path '*/.git/*' prune to skip nested hits
  - ADDED: --branch value now validated against safe charset [a-zA-Z0-9/_.-]

## v1.1.0 – 2026-02-28 – Bruno DELNOZ
  - MERGED: improvements from alternate reference version (v1.3.0 style)
  - ADDED: set -Eeuo pipefail + IFS=$'\n\t' for safer strict-mode bash
  - ADDED: ts_now() / ts_human() / die() / sep() utility functions
  - ADDED: --recurrent <seconds> repeat the full run every N seconds
  - ADDED: --root_dir as primary scan path option (replaces --base_dir)
  - ADDED: --results_dir as alias for --dest_dir
  - ADDED: --logs_dir to override the logs directory
  - ADDED: --yes required flag for --purge (no interactive prompt needed)
  - ADDED: SCRIPT_DIR auto-detection so ./logs ./results paths are always correct
  - ADDED: init_run_context() to initialize RUN_TS, LOG_FILE, RESULT_FILE cleanly
  - ADDED: no more version in filename (version stays inside script + .md files)
  - UPDATED: run_cmd() always uses bash -c (non-interactive)
  - UPDATED: default sync sequence now skips commit gracefully if nothing to commit

## v1.0.1 – 2026-02-28 – Bruno DELNOZ
  - FIXED: prerequisite checker tests custom cmd via bash -i -c "type <cmd>"

## v1.0.0 – 2026-02-28 – Bruno DELNOZ
  - Initial release
  - Recursive find for .git directories
  - Branch switch before command execution
  - --exec, --simulate, --prerequis, --install, --changelog, --purge, --help
  - Step progress display (N/TOTAL format)
  - ./logs, ./results, ./infos auto-created
  - README.md + CHANGELOG.md auto-generated in ./infos/
  - Post-execution numbered action list

EOF
    exit 0
}

# ==============================================================================
# SECTION 9 – PREREQUISITE CHECK
# Checks all required tools and configs. Displays PASS/FAIL per item.
#
# FIX v1.2.0: prereq_check_one() is now a global function (was nested inside
# check_prerequisites(), which is problematic in strict bash mode and prevents
# reuse). Prefixed with "prereq_" to avoid namespace collisions.
# ==============================================================================

# ------------------------------------------------------------------------------
# Function : prereq_check_one
# Purpose  : Print one prerequisite result line (PASS or FAIL).
# Args     : $1 = label, $2 = status (ok|fail), $3 = detail string
# Side-effect: sets __prereq_all_pass to "false" on any failure.
# ------------------------------------------------------------------------------
prereq_check_one() {
    local label="$1"
    local status="$2"
    local detail="$3"
    if [[ "${status}" == "ok" ]]; then
        printf "  [✔] %-42s PASS  – %s\n" "${label}:" "${detail}"
        log "INFO" "PREREQ OK  : ${label} – ${detail}"
    else
        printf "  [✘] %-42s FAIL  – %s\n" "${label}:" "${detail}"
        log "WARN" "PREREQ FAIL: ${label} – ${detail}"
        __prereq_all_pass="false"
    fi
}

check_prerequisites() {
    sep
    log "INFO" "Checking prerequisites for ${SCRIPT_NAME} ${SCRIPT_VERSION}..."
    sep

    # Shared state flag read by prereq_check_one()
    __prereq_all_pass="true"

    echo ""

    # 1. git binary
    if command -v git &>/dev/null; then
        prereq_check_one "git binary" "ok" "$(git --version)"
    else
        prereq_check_one "git binary" "fail" "Not found in PATH – install git"
    fi

    # 2. git user.name
    local git_user
    git_user="$(git config --global user.name 2>/dev/null || true)"
    if [[ -n "${git_user}" ]]; then
        prereq_check_one "git config user.name" "ok" "${git_user}"
    else
        prereq_check_one "git config user.name" "fail" \
            "Not set – run: git config --global user.name 'Your Name'"
    fi

    # 3. git user.email
    local git_email_cfg
    git_email_cfg="$(git config --global user.email 2>/dev/null || true)"
    if [[ -n "${git_email_cfg}" ]]; then
        prereq_check_one "git config user.email" "ok" "${git_email_cfg}"
    else
        prereq_check_one "git config user.email" "fail" \
            "Not set – run: git config --global user.email 'you@example.com'"
    fi

    # 4. If a custom --cmd is set, check the first word is an available command
    if [[ -n "${CUSTOM_CMD}" ]]; then
        local cmd_word
        cmd_word="${CUSTOM_CMD%% *}"
        if command -v "${cmd_word}" &>/dev/null; then
            prereq_check_one "custom cmd '${cmd_word}'" "ok" \
                "$(command -v "${cmd_word}")"
        else
            prereq_check_one "custom cmd '${cmd_word}'" "fail" \
                "'${cmd_word}' not found in PATH"
        fi
    fi

    # 5. Root directory exists and is readable
    if [[ -d "${ROOT_DIR}" && -r "${ROOT_DIR}" ]]; then
        prereq_check_one "root_dir '${ROOT_DIR}'" "ok" "Exists and is readable"
    else
        prereq_check_one "root_dir '${ROOT_DIR}'" "fail" \
            "'${ROOT_DIR}' does not exist or is not readable"
    fi

    # 6. find utility
    if command -v find &>/dev/null; then
        prereq_check_one "find utility" "ok" "$(command -v find)"
    else
        prereq_check_one "find utility" "fail" "Not found – install findutils"
    fi

    # 7. SSH agent OR credential helper
    local ssh_agent_pid="${SSH_AGENT_PID:-}"
    if [[ -n "${ssh_agent_pid}" ]]; then
        prereq_check_one "SSH agent" "ok" "Running (PID ${ssh_agent_pid})"
    else
        local cred_helper
        cred_helper="$(git config --global credential.helper 2>/dev/null || true)"
        if [[ -n "${cred_helper}" ]]; then
            prereq_check_one "git credential helper" "ok" "${cred_helper}"
        else
            prereq_check_one "SSH agent / credential helper" "fail" \
                "No SSH agent, no credential.helper – push may fail for HTTPS"
        fi
    fi

    echo ""
    sep

    if [[ "${__prereq_all_pass}" == "true" ]]; then
        log "OK" "All prerequisites passed. Ready to run --exec."
    else
        log "WARN" "Some prerequisites are missing."
        echo "  → Run: ./${SCRIPT_NAME} --install   to fix where possible."
    fi

    exit 0
}

# ==============================================================================
# SECTION 10 – PREREQUISITE INSTALLATION
# Best-effort installation of missing dependencies using available pkg managers.
# Uses sudo internally.
#
# FIX v1.2.0: read now has a fallback "|| answer='N'" so the script does not
# crash when stdin is not a terminal (cron, pipes, CI environments).
# ==============================================================================

install_prerequisites() {
    sep
    log "INFO" "Starting prerequisite installation – ${SCRIPT_NAME} ${SCRIPT_VERSION}"
    sep

    # Install git if missing
    if ! command -v git &>/dev/null; then
        log "INFO" "git not found. Attempting installation..."
        if command -v apt-get &>/dev/null; then
            sudo apt-get update -qq && sudo apt-get install -y git
            log_action "Installed git via apt-get"
        elif command -v yum &>/dev/null; then
            sudo yum install -y git
            log_action "Installed git via yum"
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y git
            log_action "Installed git via dnf"
        elif command -v brew &>/dev/null; then
            brew install git
            log_action "Installed git via brew"
        else
            die "No supported package manager found (apt/yum/dnf/brew). Install git manually."
        fi
    else
        log "INFO" "git already installed: $(git --version)"
    fi

    # git user.name
    if [[ -z "$(git config --global user.name 2>/dev/null || true)" ]]; then
        log "WARN" "git user.name not set. Please run:"
        echo "  git config --global user.name 'Bruno DELNOZ'"
    else
        log "INFO" "git user.name: $(git config --global user.name)"
    fi

    # git user.email
    if [[ -z "$(git config --global user.email 2>/dev/null || true)" ]]; then
        log "WARN" "git user.email not set. Please run:"
        echo "  git config --global user.email '${EMAIL}'"
    else
        log "INFO" "git user.email: $(git config --global user.email)"
    fi

    sep
    log "OK" "Installation phase complete. Run --prerequis to verify."
    exit 0
}

# ==============================================================================
# SECTION 11 – PURGE FUNCTION
# Deletes all files in LOGS_DIR and DEST_DIR.
# Requires --yes flag to be passed (no interactive prompt).
# ==============================================================================

purge_directories() {
    sep
    log "WARN" "PURGE requested for:"
    log "WARN" "  ${LOGS_DIR}"
    log "WARN" "  ${DEST_DIR}"
    sep

    # Safety gate: abort if --yes was not passed
    if [[ "${PURGE_YES}" -ne 1 ]]; then
        die "Purge requires --yes flag. Example: ./${SCRIPT_NAME} --purge --yes"
    fi

    # Purge logs directory
    if [[ -d "${LOGS_DIR}" ]]; then
        log "INFO" "Purging: ${LOGS_DIR}"
        rm -rf "${LOGS_DIR:?}"/*
        log "OK" "Purged: ${LOGS_DIR}"
    else
        log "INFO" "Not found, skipped: ${LOGS_DIR}"
    fi

    # Purge results/dest directory
    if [[ -d "${DEST_DIR}" ]]; then
        log "INFO" "Purging: ${DEST_DIR}"
        rm -rf "${DEST_DIR:?}"/*
        log "OK" "Purged: ${DEST_DIR}"
    else
        log "INFO" "Not found, skipped: ${DEST_DIR}"
    fi

    log_action "Purged: ${LOGS_DIR} and ${DEST_DIR}"
    echo ""
    log "OK" "Purge complete."
    exit 0
}


# ==============================================================================
# SECTION 11b – LARGE FILE DETECTION
# Scans the current repo's git object store for blobs exceeding 100MB.
# Called when a push fails to help diagnose the cause.
# Results are written to LARGEFILE_LOG; LARGE_FILES_FOUND is set to 1 if any
# oversized blob is found.
# ==============================================================================

# Threshold: 100 MB in bytes
_LARGEFILE_THRESHOLD=$(( 100 * 1024 * 1024 ))

check_large_files_in_history() {
    local repo_path="$1"
    LARGE_FILES_FOUND=0

    log "INFO" "  Scanning git history for blobs > 100MB in: ${repo_path}"

    local large_output
    large_output=$(
        git rev-list --objects --all 2>/dev/null \
        | git cat-file --batch-check='%(objecttype) %(objectsize) %(rest)' 2>/dev/null \
        | awk -v thresh="${_LARGEFILE_THRESHOLD}" \
              '$1=="blob" && $2+0 >= thresh { printf "%d MB  %s\n", int($2/1024/1024), $3 }' \
        | sort -rn \
        2>/dev/null || true
    )

    if [[ -n "${large_output}" ]]; then
        LARGE_FILES_FOUND=1
        {
            echo "================================================================"
            echo "  LARGE FILES DETECTED (>100MB) – ${repo_path}"
            echo "  Date: $(ts_human)"
            echo "================================================================"
            echo "${large_output}"
            echo ""
        } >> "${LARGEFILE_LOG}"
        log "WARN" "  Large files found in history – see: ${LARGEFILE_LOG}"
    else
        log "INFO" "  No large files (>100MB) found in history."
    fi
}

# ==============================================================================
# SECTION 11c – SSH TO HTTPS REMOTE CONVERSION
# If the origin remote uses an SSH URL for github.com or gitlab.com,
# converts it to HTTPS in-place before the push step.
# Sets REPO_SYNC_WARNING to signal the conversion to the caller.
#
# FIX v1.3.1: direction corrected – was HTTPS→SSH (wrong), now SSH→HTTPS.
# ==============================================================================

convert_remote_to_https() {
    local remote_url
    remote_url=$(git remote get-url origin 2>/dev/null || true)

    local new_url=""
    if [[ "${remote_url}" =~ ^git@github\.com: ]]; then
        new_url=$(echo "${remote_url}" | sed 's|git@github\.com:|https://github.com/|')
    elif [[ "${remote_url}" =~ ^git@gitlab\.com: ]]; then
        new_url=$(echo "${remote_url}" | sed 's|git@gitlab\.com:|https://gitlab.com/|')
    fi

    if [[ -n "${new_url}" ]]; then
        git remote set-url origin "${new_url}"
        log "INFO" "  SSH→HTTPS: ${remote_url} → ${new_url}"
        # Append to warning (may already contain another warning)
        if [[ -z "${REPO_SYNC_WARNING}" ]]; then
            REPO_SYNC_WARNING="WARNING SSH to HTTPS applied"
        else
            REPO_SYNC_WARNING="${REPO_SYNC_WARNING} / WARNING SSH to HTTPS applied"
        fi
    fi
}
# ==============================================================================

write_result_file() {
    {
        echo "================================================================"
        echo "  EXECUTION SUMMARY – ${SCRIPT_NAME} ${SCRIPT_VERSION}"
        echo "  Date       : $(ts_human)"
        echo "  Root dir   : ${ROOT_DIR}"
        echo "  Branch     : ${BRANCH}"
        echo "  Custom cmd : ${CUSTOM_CMD:-(default git sequence)}"
        echo "  Simulate   : ${SIMULATE}"
        echo "  Force push : ${FORCE_PUSH}"
        echo "  Exclude    : ${EXCLUDE_LIST:-(none)}"
        echo "  Recurrent  : ${RECURRENT_SECONDS:-(once)}"
        echo "================================================================"
        echo ""
        echo "  Total repos found        : ${TOTAL_REPOS}"
        echo "  Successfully synced      : ${REPOS_SYNCED}"
        echo "  Skipped (no branch)      : ${REPOS_SKIPPED}"
        echo "  Failed                   : ${REPOS_FAILED}"
        echo ""
        echo "================================================================"
        echo "  ACTIONS PERFORMED:"
        echo "================================================================"
        local action
        for action in "${ACTIONS_DONE[@]}"; do
            case "${action}" in
                SYNCED:*|FAILED*|EXCLUDED:*)
                    ;;
                *)
                    echo "  - ${action}"
                    ;;
            esac
        done
        local idx=1
        for action in "${ACTIONS_DONE[@]}"; do
            case "${action}" in
                SYNCED:*|FAILED*|EXCLUDED:*)
                    echo "  ${idx}. ${action}"
                    idx=$((idx + 1))
                    ;;
            esac
        done
        echo ""
        echo "  Log file        : ${LOG_FILE}"
        echo "  Stderr log      : ${STDERR_LOG}"
        echo "  Largefile log   : ${LARGEFILE_LOG}"
        echo "================================================================"
    } > "${RESULT_FILE}"
    log "OK" "Result summary written to: ${RESULT_FILE}"
}

# ==============================================================================
# SECTION 14 – DISPLAY POST-EXECUTION SUMMARY
# Prints a numbered list of all actions to the console.
# ==============================================================================

display_post_exec_summary() {
    sep
    log "INFO" "POST-EXECUTION SUMMARY"
    sep
    echo ""
    echo "  Total repos found        : ${TOTAL_REPOS}"
    echo "  Successfully synced      : ${REPOS_SYNCED}"
    echo "  Skipped (no branch)      : ${REPOS_SKIPPED}"
    echo "  Failed                   : ${REPOS_FAILED}"
    echo ""
    echo "  ── Actions performed ────────────────────────────────────────"
    local action
    for action in "${ACTIONS_DONE[@]}"; do
        case "${action}" in
            SYNCED:*|FAILED*|EXCLUDED:*)
                ;;
            *)
                echo "  - ${action}"
                ;;
        esac
    done
    local idx=1
    for action in "${ACTIONS_DONE[@]}"; do
        case "${action}" in
            SYNCED:*|FAILED*|EXCLUDED:*)
                echo "  ${idx}. ${action}"
                idx=$((idx + 1))
                ;;
        esac
    done
    echo ""
    echo "  Log file    : ${LOG_FILE}"
    echo "  Stderr log  : ${STDERR_LOG}"
    echo "  Largefile   : ${LARGEFILE_LOG}"
    echo "  Result file : ${RESULT_FILE}"
    sep
}

# ==============================================================================
# SECTION 15 – DEFAULT GIT SYNC SEQUENCE
# Runs the built-in sync when no --cmd is specified.
# Steps: create snapshot branch → checkout branch → add all
#        → commit (skip if clean) → push force → push all
#
# NOTE: This function is called AFTER pushd into the repo dir (see run_one_pass).
# The repo_path argument is used only for log messages, not for cd.
# ==============================================================================

run_default_git_sync() {
    local repo_path="$1"
    local _step_total=6

    log "INFO" "  Running default git sync sequence in: ${repo_path}"

    # ── Step a/6 : create snapshot branch ────────────────────────────────────
    local snapshot_branch="syncgit-snapshot/$(date '+%Y%m%d-%Hh%M')"
    echo "  ┌─ [a/${_step_total}] git branch ${snapshot_branch}"
    if [[ "${SIMULATE}" -eq 1 ]]; then
        run_cmd \
            "git branch ${snapshot_branch}" \
            "git branch ${snapshot_branch}"
        echo "  └─ ✔ done (simulated)"
    else
        local snap_exit=0
        run_cmd \
            "git branch ${snapshot_branch}" \
            "git branch ${snapshot_branch}" || snap_exit=$?
        if [[ "${snap_exit}" -ne 0 ]]; then
            echo "  └─ ✘ FAILED (exit ${snap_exit}) – snapshot branch creation"
            log "ERROR" "  snapshot branch creation failed (exit ${snap_exit})"
            return "${snap_exit}"
        fi
        echo "  └─ ✔ done"
    fi

    # ── Pre-checkout : auto-commit wip on current branch if needed ───────────
    # If the current branch is not the target branch AND has uncommitted changes,
    # those changes would block the checkout. We commit them as "wip" first.
    # In simulate mode: detect and warn but do NOT commit.
    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
    if [[ -n "${current_branch}" && "${current_branch}" != "${BRANCH}" ]]; then
        if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
            if [[ "${SIMULATE}" -eq 0 ]]; then
                log "INFO" "  Current branch '${current_branch}' has uncommitted changes – auto-committing wip."
                git add . < /dev/null 2> >(tee -a "${STDERR_LOG:-/dev/null}" >&2)
                git commit -m "wip" < /dev/null 2> >(tee -a "${STDERR_LOG:-/dev/null}" >&2) || true
                log "INFO" "  WIP committed on '${current_branch}' – now switching to '${BRANCH}'."
            else
                log "SIM" "  [DRY-RUN] Branch '${current_branch}' has uncommitted changes – WOULD auto-commit wip."
            fi
            if [[ -z "${REPO_SYNC_WARNING}" ]]; then
                REPO_SYNC_WARNING="WARNING current branch ${current_branch} behind main"
            else
                REPO_SYNC_WARNING="${REPO_SYNC_WARNING} / WARNING current branch ${current_branch} behind main"
            fi
        fi
    fi

    # ── Step b/6 : checkout ──────────────────────────────────────────────────
    echo "  ┌─ [b/${_step_total}] git checkout ${BRANCH}"
    local co_exit=0
    run_cmd "git checkout ${BRANCH}" "git checkout ${BRANCH}" || co_exit=$?
    if [[ "${co_exit}" -ne 0 && "${SIMULATE}" -eq 0 ]]; then
        echo "  └─ ✘ FAILED (exit ${co_exit}) – checkout '${BRANCH}'"
        log "ERROR" "  checkout '${BRANCH}' failed (exit ${co_exit}) – skipping repo."
        return "${co_exit}"
    fi
    echo "  └─ ✔ done"

    # ── Step c/6 : add ───────────────────────────────────────────────────────
    echo "  ┌─ [c/${_step_total}] git add ."
    run_cmd "git add ." "git add ."
    echo "  └─ ✔ done"

    # ── Step d/6 : commit ────────────────────────────────────────────────────
    echo "  ┌─ [d/${_step_total}] git commit"
    local commit_user
    local commit_date
    local commit_time
    local commit_msg
    local commit_msg_escaped
    commit_user="$(git config user.name 2>/dev/null || true)"
    if [[ -z "${commit_user}" ]]; then
        commit_user="$(whoami 2>/dev/null || echo "unknown")"
    fi
    commit_date="$(date '+%Y-%m-%d')"
    commit_time="$(date '+%H:%M:%S')"
    commit_msg="commit last version done by syncgit.sh user: ${commit_user}   date : ${commit_date} time ${commit_time}"
    printf -v commit_msg_escaped "%q" "${commit_msg}"
    if [[ "${SIMULATE}" -eq 1 ]]; then
        run_cmd \
            "git commit -m '${commit_msg}' (if anything staged)" \
            "git commit -m ${commit_msg_escaped}"
        echo "  └─ ✔ done (simulated)"
    else
        if ! git diff --cached --quiet 2>/dev/null; then
            local commit_exit=0
            run_cmd \
                "git commit -m '${commit_msg}'" \
                "git commit -m ${commit_msg_escaped}" || commit_exit=$?
            if [[ "${commit_exit}" -ne 0 ]]; then
                echo "  └─ ✘ FAILED (exit ${commit_exit}) – commit"
                log "ERROR" "  commit failed (exit ${commit_exit})"
                return "${commit_exit}"
            fi
            echo "  └─ ✔ done"
        else
            echo "  └─ ✔ nothing to commit – skipped"
            log "INFO" "  Nothing to commit – skipping commit step."
        fi
    fi

    # ── Pre-push : convert SSH remote to HTTPS if needed ─────────────────────
    # In simulate mode: detect and set warning but do NOT modify .git/config.
    if [[ "${SIMULATE}" -eq 0 ]]; then
        convert_remote_to_https
    else
        local _remote_url
        _remote_url=$(git remote get-url origin 2>/dev/null || true)
        if [[ "${_remote_url}" =~ ^git@github\.com: || "${_remote_url}" =~ ^git@gitlab\.com: ]]; then
            log "SIM" "  [DRY-RUN] Remote is SSH – WOULD convert to HTTPS: ${_remote_url}"
            if [[ -z "${REPO_SYNC_WARNING}" ]]; then
                REPO_SYNC_WARNING="WARNING SSH to HTTPS applied"
            else
                REPO_SYNC_WARNING="${REPO_SYNC_WARNING} / WARNING SSH to HTTPS applied"
            fi
        fi
    fi

    # ── Pre-push simulate : scan for big files (> 100MB) ─────────────────────
    # In simulate mode the push never runs, so we proactively scan history
    # and warn the user if oversized blobs would cause the push to fail.
    if [[ "${SIMULATE}" -eq 1 ]]; then
        check_large_files_in_history "${repo_path}"
        if [[ "${LARGE_FILES_FOUND}" -eq 1 ]]; then
            log "SIM" "  [DRY-RUN] Big files (>100MB) detected in history – push WOULD fail."
            if [[ -z "${REPO_SYNC_WARNING}" ]]; then
                REPO_SYNC_WARNING="WARNING BIG FILES DETECTED - push would fail"
            else
                REPO_SYNC_WARNING="${REPO_SYNC_WARNING} / WARNING BIG FILES DETECTED - push would fail"
            fi
        fi
    fi

    # ── Pre-push guard : skip if remote branch is ahead of local ─────────────
    # Default rule: if origin/<branch> has commits not present locally,
    # do not push (force or --all) and report FAILED in final summary.
    # Override: when --forcepush/-f is enabled, this protection is bypassed.
    if [[ "${SIMULATE}" -eq 0 ]]; then
        local fetch_exit=0
        run_cmd \
            "git fetch origin ${BRANCH} (remote-ahead guard)" \
            "git fetch origin ${BRANCH}" || fetch_exit=$?
        if [[ "${fetch_exit}" -ne 0 ]]; then
            log "ERROR" "  fetch origin ${BRANCH} failed (exit ${fetch_exit})"
            return "${fetch_exit}"
        fi

        if git show-ref --verify --quiet "refs/remotes/origin/${BRANCH}" 2>/dev/null; then
            local ahead_behind
            local local_ahead=0
            local remote_ahead=0
            ahead_behind=$(git rev-list --left-right --count "${BRANCH}...origin/${BRANCH}" 2>/dev/null || true)
            if [[ -n "${ahead_behind}" ]]; then
                read -r local_ahead remote_ahead <<< "${ahead_behind}"
            fi
            if [[ "${remote_ahead}" -gt 0 ]]; then
                if [[ "${FORCE_PUSH}" -eq 1 ]]; then
                    log "WARN" "  Remote ahead guard bypassed by --forcepush: origin/${BRANCH} is ahead of local ${BRANCH} (${remote_ahead} commit(s))."
                else
                    echo "  └─ ✘ FAILED – remote ahead from local (origin/${BRANCH})"
                    log "ERROR" "  Remote ahead guard triggered: origin/${BRANCH} is ahead of local ${BRANCH} (${remote_ahead} commit(s))."
                    REPO_FAIL_REASON="remote ahead from local"
                    return 40
                fi
            fi
        fi
    fi

    # ── Step e/6 : push branch ───────────────────────────────────────────────
    echo "  ┌─ [e/${_step_total}] git push --set-upstream --force origin ${BRANCH}"
    local push_exit=0
    run_cmd \
        "git push --set-upstream --force origin ${BRANCH}" \
        "git push --set-upstream --force origin ${BRANCH}" || push_exit=$?
    if [[ "${push_exit}" -ne 0 && "${SIMULATE}" -eq 0 ]]; then
        # Scan git history for blobs > 100MB to help diagnose the failure
        check_large_files_in_history "${repo_path}"
        if [[ "${LARGE_FILES_FOUND}" -eq 1 ]]; then
            echo "  └─ ✘ FAILED - BIG FILES DETECTED"
        else
            echo "  └─ ✘ FAILED (exit ${push_exit}) – push rejected (no remote? permissions?)"
        fi
        log "ERROR" "  push --set-upstream failed (exit ${push_exit}) – skipping push --all."
        return "${push_exit}"
    fi
    echo "  └─ ✔ done"

    # ── Step f/6 : push all branches ─────────────────────────────────────────
    echo "  ┌─ [f/${_step_total}] git push --force origin --all"
    local pushall_exit=0
    run_cmd \
        "git push --force origin --all" \
        "git push --force origin --all" || pushall_exit=$?
    if [[ "${pushall_exit}" -ne 0 && "${SIMULATE}" -eq 0 ]]; then
        check_large_files_in_history "${repo_path}"
        if [[ "${LARGE_FILES_FOUND}" -eq 1 ]]; then
            echo "  └─ ✘ FAILED - BIG FILES DETECTED"
        else
            echo "  └─ ✘ FAILED (exit ${pushall_exit}) – push --all rejected"
        fi
        log "ERROR" "  push --all failed (exit ${pushall_exit})"
        return "${pushall_exit}"
    fi
    echo "  └─ ✔ done"

    return 0
}

# ------------------------------------------------------------------------------
# Function : copy_master_agentsmd_to_repo
# Purpose  : Copy SCRIPT_DIR/AGENTS.md to <repo>/AGENTS.md before any other
#            repository operation when --cpagentsmd is enabled.
#            Destination is always overwritten (cp -f behavior).
# Args     : $1 = repo path
# Returns  : 0 on success, non-zero on failure
# ------------------------------------------------------------------------------
copy_master_agentsmd_to_repo() {
    local repo_path="$1"
    local source_agents="${SCRIPT_DIR}/AGENTS.md"
    local dest_agents="${repo_path}/AGENTS.md"

    if [[ ! -f "${source_agents}" ]]; then
        log "ERROR" "Master AGENTS.md not found at: ${source_agents}"
        return 50
    fi

    if [[ "${SIMULATE}" -eq 1 ]]; then
        log "SIM" "[DRY-RUN] WOULD copy '${source_agents}' -> '${dest_agents}' (overwrite enabled)."
        return 0
    fi

    if cp -f "${source_agents}" "${dest_agents}"; then
        log "OK" "AGENTS.md copied to repo: ${dest_agents} (overwrite forced)."
        return 0
    fi

    log "ERROR" "Failed to copy AGENTS.md to repo: ${dest_agents}"
    return 51
}

# ==============================================================================
# SECTION 16 – SINGLE SCAN & PROCESS PASS
# One complete scan + process cycle. Called once, or in a loop if --recurrent.
#
# FIX v1.2.0: each repo is now processed inside a pushd/popd block so the
# script always returns to the original working directory between repos.
# Without this, a failed cd or a repo that changes CWD would corrupt all
# subsequent relative path operations.
#
# FIX v1.2.0: find now uses -not -path '*/.git/*' to exclude .git entries
# found inside git submodule storage dirs (.git/modules/*/), which were
# previously being treated as top-level repositories.
# ==============================================================================

# ------------------------------------------------------------------------------
# Function : is_excluded
# Purpose  : Returns 0 (true) if the repo basename matches any entry in
#            EXCLUDE_LIST (semicolon-separated). Case-sensitive exact match.
# Args     : $1 = repo path
# ------------------------------------------------------------------------------
is_excluded() {
    local repo_path="$1"
    local repo_name
    repo_name="$(basename "${repo_path}")"

    if [[ -z "${EXCLUDE_LIST}" ]]; then
        return 1  # nothing excluded
    fi

    local IFS_BAK="${IFS}"
    IFS=';'
    local entry
    for entry in ${EXCLUDE_LIST}; do
        # strip leading/trailing spaces from each entry
        entry="${entry## }"
        entry="${entry%% }"
        if [[ "${repo_name}" == "${entry}" ]]; then
            IFS="${IFS_BAK}"
            return 0  # match → excluded
        fi
    done
    IFS="${IFS_BAK}"
    return 1  # no match
}

run_one_pass() {
    # Reset counters for this pass
    TOTAL_REPOS=0
    REPOS_SYNCED=0
    REPOS_SKIPPED=0
    REPOS_FAILED=0
    ACTIONS_DONE=()

    # Re-initialize timestamps and file paths for this pass
    init_run_context

    sep
    log "INFO" "Starting pass – ${SCRIPT_NAME} ${SCRIPT_VERSION}"
    log "INFO" "  Root dir   : ${ROOT_DIR}"
    log "INFO" "  Branch     : ${BRANCH}"
    log "INFO" "  Custom cmd : ${CUSTOM_CMD:-(default git sequence)}"
    log "INFO" "  Simulate   : ${SIMULATE}"
    log "INFO" "  Exclude    : ${EXCLUDE_LIST:-(none)}"
    log "INFO" "  cpagentsmd : ${CP_AGENTS_MD}"
    if [[ "${SIMULATE}" -eq 1 ]]; then
        log "SIM" "╔══════════════════════════════════════════════════╗"
        log "SIM" "║   SIMULATION MODE ACTIVE – no real changes      ║"
        log "SIM" "╚══════════════════════════════════════════════════╝"
    fi
    sep

    # -------------------------------------------------------------------------
    # STEP 1/5 – Setup directories
    # -------------------------------------------------------------------------
    STEP_CURRENT=1
    print_step "${STEP_CURRENT}" "${STEP_TOTAL}" "Setting up directories"
    setup_directories
    log_action "Directories ready: ${LOGS_DIR}, ${DEST_DIR}, ${INFOS_DIR}"

    # -------------------------------------------------------------------------
    # STEP 2/5 – Validate root directory
    # -------------------------------------------------------------------------
    STEP_CURRENT=2
    print_step "${STEP_CURRENT}" "${STEP_TOTAL}" "Validating root directory: ${ROOT_DIR}"

    [[ -d "${ROOT_DIR}" ]] || die "Root directory does not exist: '${ROOT_DIR}'"
    [[ -r "${ROOT_DIR}" ]] || die "Root directory not readable: '${ROOT_DIR}'"

    log "INFO" "Root directory is valid: ${ROOT_DIR}"
    log_action "Validated root directory: ${ROOT_DIR}"

    # -------------------------------------------------------------------------
    # STEP 3/5 – Discover git repositories
    # FIX: -not -path '*/.git/*' prevents matching .git dirs stored inside
    #      git submodule directories (.git/modules/<name>/.git).
    # -------------------------------------------------------------------------
    STEP_CURRENT=3
    print_step "${STEP_CURRENT}" "${STEP_TOTAL}" "Scanning for git repositories under ${ROOT_DIR}"
    log "INFO" "Running: find '${ROOT_DIR}' -type d -name '.git' (pruning submodule paths)"

    declare -a repo_paths=()
    local _scan_count=0
    while IFS= read -r gitdir; do
        repo_paths+=("${gitdir%/.git}")
        _scan_count=$(( _scan_count + 1 ))
        # Live counter on a single line, overwritten each time
        printf "\r  Scanning... repos found so far: %d" "${_scan_count}" >&2
        log "INFO" "  Found: ${gitdir%/.git}"
    done < <(find "${ROOT_DIR}" -type d -name ".git" -not -path "*/.git/*" 2>/dev/null)
    printf "\r  Scan complete.                          \n" >&2

    TOTAL_REPOS="${#repo_paths[@]}"
    log "INFO" "Scan complete. Found: ${TOTAL_REPOS} git repository(ies)."
    log_action "Scanned '${ROOT_DIR}' – found ${TOTAL_REPOS} repos"

    if [[ "${TOTAL_REPOS}" -eq 0 ]]; then
        log "WARN" "No git repositories found under: ${ROOT_DIR}"
        echo "  Nothing to sync. Try a different --root_dir."
        return 0
    fi

    # -------------------------------------------------------------------------
    # STEP 4/5 – Process each repository
    # FIX: pushd/popd ensures we always return to the original directory after
    #      processing each repo, regardless of success or failure.
    # -------------------------------------------------------------------------
    STEP_CURRENT=4
    print_step "${STEP_CURRENT}" "${STEP_TOTAL}" "Processing ${TOTAL_REPOS} repositories"

    local repo_idx=0
    for repo_path in "${repo_paths[@]}"; do
        repo_idx=$((repo_idx + 1))
        echo ""
        echo "╔══════════════════════════════════════════════════════════════════╗"
        printf "║  REPO [%d/%d]  %s\n" "${repo_idx}" "${TOTAL_REPOS}" "${repo_path}"
        printf "║  DIR  : %s\n" "${repo_path}"
        echo "╚══════════════════════════════════════════════════════════════════╝"
        log "INFO" "Repo ${repo_idx}/${TOTAL_REPOS}: ${repo_path}"

        # Check if this repo is in the exclude list
        if is_excluded "${repo_path}"; then
            echo "  ⊘ EXCLUDED : ${repo_path}"
            log "INFO" "  EXCLUDED (--exclude list): ${repo_path}"
            log_action "EXCLUDED: ${repo_path}"
            REPOS_SKIPPED=$((REPOS_SKIPPED + 1))
            continue
        fi

        # Enter the repo directory – pushd saves the current dir on a stack.
        # popd at the end of the block guarantees we return here unconditionally.
        if ! pushd "${repo_path}" > /dev/null 2>&1; then
            log "ERROR" "Cannot cd into: ${repo_path} – skipping."
            REPOS_FAILED=$((REPOS_FAILED + 1))
            log_action "FAILED (cannot access): ${repo_path}"
            continue
        fi
        log "INFO" "  Working dir: $(pwd)"

        # Optional pre-operation: copy master AGENTS.md into repo (forced overwrite)
        if [[ "${CP_AGENTS_MD}" -eq 1 ]]; then
            local cpagents_exit=0
            copy_master_agentsmd_to_repo "${repo_path}" || cpagents_exit=$?
            if [[ "${cpagents_exit}" -ne 0 ]]; then
                log "ERROR" "  --cpagentsmd failed (exit ${cpagents_exit}) – skipping repo."
                REPOS_FAILED=$((REPOS_FAILED + 1))
                log_action "FAILED (--cpagentsmd exit ${cpagents_exit}): ${repo_path}"
                popd > /dev/null 2>&1
                continue
            fi
        fi

        # Reset per-repo state flags
        REPO_SYNC_WARNING=""
        LARGE_FILES_FOUND=0
        REPO_FAIL_REASON=""

        # If using default sequence, verify the target branch exists.
        # FIX v1.3.0: if 'main' is missing but 'master' exists, auto-create main
        # from master and continue. If neither exists, mark repo as FAILED.
        if [[ -z "${CUSTOM_CMD}" ]]; then
            if ! git show-ref --verify --quiet "refs/heads/${BRANCH}" 2>/dev/null; then
                if [[ "${BRANCH}" == "main" ]] && \
                   git show-ref --verify --quiet "refs/heads/master" 2>/dev/null; then
                    if [[ "${SIMULATE}" -eq 0 ]]; then
                        log "INFO" "  Branch 'main' not found – creating from 'master'."
                        git checkout -b main master \
                            < /dev/null \
                            2> >(tee -a "${STDERR_LOG:-/dev/null}" >&2) || true
                        log "INFO" "  Branch 'main' created from 'master'."
                    else
                        log "SIM" "  [DRY-RUN] Branch 'main' not found – WOULD create from 'master'."
                    fi
                    if [[ -z "${REPO_SYNC_WARNING}" ]]; then
                        REPO_SYNC_WARNING="WARNING main does not exists - created from master"
                    else
                        REPO_SYNC_WARNING="${REPO_SYNC_WARNING} / WARNING main does not exists - created from master"
                    fi
                else
                    log "WARN" "  Branch '${BRANCH}' not found and no 'master' fallback – skipping."
                    echo "  ✘ FAILED : ${repo_path}  (no branch '${BRANCH}', no 'master')"
                    REPOS_FAILED=$((REPOS_FAILED + 1))
                    log_action "FAILED (no branch '${BRANCH}', no 'master'): ${repo_path}"
                    popd > /dev/null 2>&1
                    continue
                fi
            fi
        fi

        # Execute: custom command OR default git sync sequence
        local cmd_exit=0
        if [[ -n "${CUSTOM_CMD}" ]]; then
            run_cmd \
                "Running '${CUSTOM_CMD}' in ${repo_path}" \
                "${CUSTOM_CMD}" || cmd_exit=$?
        else
            run_default_git_sync "${repo_path}" || cmd_exit=$?
        fi

        # Always return to the previous directory before recording outcome
        popd > /dev/null 2>&1

        # Record outcome
        if [[ "${cmd_exit}" -eq 0 || "${SIMULATE}" -eq 1 ]]; then
            REPOS_SYNCED=$((REPOS_SYNCED + 1))
            if [[ -n "${REPO_SYNC_WARNING}" ]]; then
                echo "  ✔ SYNCED - ${REPO_SYNC_WARNING} : ${repo_path}"
                log "OK" "SYNCED - ${REPO_SYNC_WARNING}: ${repo_path}"
                log_action "SYNCED - ${REPO_SYNC_WARNING}: ${repo_path}"
            else
                echo "  ✔ SUCCESS : ${repo_path}"
                log "OK" "SUCCESS: ${repo_path}"
                log_action "SYNCED: ${repo_path}"
            fi
        else
            REPOS_FAILED=$((REPOS_FAILED + 1))
            if [[ "${LARGE_FILES_FOUND}" -eq 1 ]]; then
                echo "  ✘ FAILED - BIG FILES DETECTED : ${repo_path}"
                log "ERROR" "FAILED - BIG FILES DETECTED: ${repo_path}"
                log_action "FAILED - BIG FILES DETECTED: ${repo_path}"
            elif [[ "${REPO_FAIL_REASON}" == "remote ahead from local" ]]; then
                echo "  ✘ FAILED - remote ahead from local : ${repo_path}"
                log "ERROR" "FAILED - remote ahead from local: ${repo_path}"
                log_action "FAILED - remote ahead from local: ${repo_path}"
            else
                echo "  ✘ FAILED  : ${repo_path}  (exit ${cmd_exit})"
                log "ERROR" "FAILED (exit ${cmd_exit}): ${repo_path}"
                log_action "FAILED (exit ${cmd_exit}): ${repo_path}"
            fi
        fi

    done  # end repo loop

    # -------------------------------------------------------------------------
    # STEP 5/5 – Generate docs, write results, display summary
    # -------------------------------------------------------------------------
    STEP_CURRENT=5
    print_step "${STEP_CURRENT}" "${STEP_TOTAL}" "Writing results and summary"

    write_result_file
    display_post_exec_summary
}

# ==============================================================================
# SECTION 17 – MAIN EXEC DISPATCHER
# Handles single-run or recurrent loop depending on --recurrent flag.
# ==============================================================================

run_exec() {
    if [[ "${RECURRENT}" -eq 1 && -n "${RECURRENT_SECONDS}" ]]; then
        log "INFO" "Recurrent mode: running every ${RECURRENT_SECONDS} seconds. Press Ctrl+C to stop."
        while true; do
            run_one_pass
            log "INFO" "Sleeping ${RECURRENT_SECONDS}s before next run..."
            sleep "${RECURRENT_SECONDS}"
        done
    else
        run_one_pass
    fi
}

# ==============================================================================
# SECTION 18 – ARGUMENT PARSING
# ==============================================================================

# Auto-show help when called with no arguments
if [[ $# -eq 0 ]]; then
    show_help
fi

# Parse all arguments
while [[ $# -gt 0 ]]; do
    case "$1" in

        # ── Primary actions ─────────────────────────────────────────────────
        --exec|-exe)
            ACTION_MODE="exec"
            shift
            ;;
        --simulate|-s)
            ACTION_MODE="exec"
            SIMULATE=1
            shift
            ;;
        --prerequis|-pr)
            ACTION_MODE="prerequis"
            shift
            ;;
        --install|-i)
            ACTION_MODE="install"
            shift
            ;;
        --changelog|-ch)
            ACTION_MODE="changelog"
            shift
            ;;
        --purge|-pu)
            ACTION_MODE="purge"
            shift
            ;;
        --help|-h)
            show_help
            ;;

        # ── Modifiers ───────────────────────────────────────────────────────
        --yes)
            PURGE_YES=1
            shift
            ;;
        --forcepush|-f)
            FORCE_PUSH=1
            shift
            ;;
        --cpagentsmd)
            CP_AGENTS_MD=1
            shift
            ;;
        --root_dir)
            [[ -z "${2:-}" ]] && die "--root_dir requires a path argument."
            ROOT_DIR="$2"
            shift 2
            ;;
        --dest_dir|--results_dir)
            # FIX v1.2.0: removed stray RESULT_FILE assignment here.
            # RUN_TS is empty at parse time; init_run_context() sets RESULT_FILE
            # correctly once DEST_DIR and RUN_TS are both properly initialized.
            [[ -z "${2:-}" ]] && die "$1 requires a directory path."
            DEST_DIR="$2"
            shift 2
            ;;
        --logs_dir)
            [[ -z "${2:-}" ]] && die "--logs_dir requires a directory path."
            LOGS_DIR="$2"
            shift 2
            ;;
        --branch)
            [[ -z "${2:-}" ]] && die "--branch requires a branch name."
            # FIX v1.2.0: validate branch name – reject spaces and shell-unsafe chars
            if [[ ! "$2" =~ ^[a-zA-Z0-9/_.-]+$ ]]; then
                die "--branch value contains invalid characters: '$2'. Use only: a-z A-Z 0-9 / _ - ."
            fi
            BRANCH="$2"
            shift 2
            ;;
        --cmd)
            [[ -z "${2:-}" ]] && die "--cmd requires a command string."
            CUSTOM_CMD="$2"
            shift 2
            ;;
        --recurrent)
            [[ -z "${2:-}" ]] && die "--recurrent requires a number of seconds."
            if ! [[ "$2" =~ ^[0-9]+$ ]]; then
                die "--recurrent value must be a positive integer. Got: '$2'"
            fi
            RECURRENT=1
            RECURRENT_SECONDS="$2"
            shift 2
            ;;
        --exclude)
            [[ -z "${2:-}" ]] && die "--exclude requires a semicolon-separated list of repo names."
            EXCLUDE_LIST="$2"
            shift 2
            ;;

        # ── Unknown ─────────────────────────────────────────────────────────
        *)
            die "Unknown argument: '$1'. Run: ./${SCRIPT_NAME} --help"
            ;;
    esac
done

# ==============================================================================
# SECTION 19 – ACTION DISPATCH
# ==============================================================================

case "${ACTION_MODE}" in
    exec)
        setup_directories
        run_exec
        ;;
    prerequis)
        setup_directories
        check_prerequisites
        ;;
    install)
        setup_directories
        install_prerequisites
        ;;
    changelog)
        show_changelog
        ;;
    purge)
        purge_directories
        ;;
    "")
        die "No action specified. Use --exec, --prerequis, --install, --changelog, or --purge."
        ;;
    *)
        die "Unknown action mode: '${ACTION_MODE}'"
        ;;
esac
