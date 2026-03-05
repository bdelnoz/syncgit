#!/usr/bin/env bash
# ==============================================================================
# Script Name      : syncgit.sh
# Script Version   : v1.4.2
# Date             : 2026-02-28
#
# Classic BASH script (NOT POSIX sh).
#
# Purpose:
#   Recursively scan for Git repositories (directories containing ".git") and:
#     - run a custom command provided via --cmd "<command>"
#       OR
#     - run the default Git sync sequence on a chosen branch (default: main):
#         git checkout <branch>
#         git add .
#         git commit -m "commit last version"   (ignored if nothing to commit)
#         git push --set-upstream --force origin <branch>
#
# Instrumentation rules:
#   - NO version in script filename
#   - YES version inside script (header + SCRIPT_VERSION)
#   - YES version in README.md and CHANGELOG.md
#   - Logs/results filenames are timestamped (no version in filenames)
# ==============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_VERSION="v1.4.2"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DEFAULT_ROOT_DIR="."
DEFAULT_DEST_DIR="${SCRIPT_DIR}/results"
DEFAULT_LOGS_DIR="${SCRIPT_DIR}/logs"
DEFAULT_INFOS_DIR="${SCRIPT_DIR}/infos"
DEFAULT_BRANCH="main"
DEFAULT_CMD_MODE="direct"   # direct | bash-i

ROOT_DIR="${DEFAULT_ROOT_DIR}"
DEST_DIR="${DEFAULT_DEST_DIR}"
LOGS_DIR="${DEFAULT_LOGS_DIR}"
INFOS_DIR="${DEFAULT_INFOS_DIR}"
BRANCH="${DEFAULT_BRANCH}"
CMD_MODE="${DEFAULT_CMD_MODE}"

SIMULATE=0
RECURRENT=0
RECURRENT_SECONDS=""
CUSTOM_CMD=""
ACTION_MODE=""
PURGE_YES=0

RUN_TS=""
LOG_FILE=""
RESULT_FILE=""

ts_now()   { date '+%Y%m%d-%H%M%S'; }
ts_human() { date '+%Y-%m-%d %H:%M:%S'; }

log() {
  local level="$1"; shift
  local msg="$*"
  local line="[${SCRIPT_VERSION}] [$(ts_human)] [${level}] ${msg}"
  echo "${line}"
  [[ -n "${LOG_FILE:-}" ]] && echo "${line}" >> "${LOG_FILE}"
}

die() { log "FATAL" "$*"; exit 1; }
sep() { log "INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; }

help() {
  cat <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  syncgit.sh - ${SCRIPT_VERSION} - 2026-02-28
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

USAGE
  ./syncgit.sh [ACTION] [OPTIONS]

ACTIONS (one required)
  --exec,       -exe   Scan + execute action in each repo
  --prerequis,  -pr    Check prerequisites
  --install,    -i     Best-effort install prerequisites (apt only)
  --purge,      -pu    Purge logs/results (requires --yes)
  --changelog,  -ch    Print embedded changelog summary
  --help,       -h     Show help

OPTIONS (for --exec)
  --root_dir <path>        Root directory to scan (default: ${DEFAULT_ROOT_DIR})
  --dest_dir <path>        Results directory (default: ${DEFAULT_DEST_DIR})
  --results_dir <path>     Alias of --dest_dir
  --logs_dir <path>        Logs directory (default: ${DEFAULT_LOGS_DIR})
  --branch <name>          Branch for default git sequence (default: ${DEFAULT_BRANCH})
  --simulate, -s           Dry-run (no changes)
  --cmd "<command>"        Custom command executed inside each repo
  --cmd_mode direct|bash-i direct: bash -c ; bash-i: bash -ic (aliases ok)
  --recurrent <seconds>    Repeat full run every N seconds until Ctrl+C

OPTIONS (for --purge)
  --yes                    Required confirmation for purge

EXAMPLES
  ./syncgit.sh --exec --root_dir /mnt/data2_78g/Security --simulate
  ./syncgit.sh --exec --root_dir /mnt/data2_78g/Security --cmd "rm -f .gigi"
  ./syncgit.sh --exec --root_dir /mnt/data2_78g/Security --cmd "gita" --cmd_mode bash-i
EOF
}

show_changelog() {
  cat <<EOF
CHANGELOG (summary)
- v1.4.2 (2026-02-28)
  - Fix: previous file was truncated (here-doc / braces). This one is complete.
  - Classic bash implementation (no POSIX sh).
  - Robust repo discovery: find -print0 + read -d '' (bash).
EOF
}

prerequis() {
  sep; log "INFO" "Prerequisites"; sep
  command -v bash >/dev/null && log "OK" "bash: $(command -v bash)" || log "WARN" "bash missing?"
  command -v git  >/dev/null && log "OK" "git : $(git --version)"    || log "WARN" "git missing"
  command -v find >/dev/null && log "OK" "find: $(command -v find)"   || log "WARN" "find missing"

  local un ue
  un="$(git config --global user.name 2>/dev/null || true)"
  ue="$(git config --global user.email 2>/dev/null || true)"
  [[ -n "$un" ]] && log "OK" "git user.name : $un" || log "WARN" "git user.name not set"
  [[ -n "$ue" ]] && log "OK" "git user.email: $ue" || log "WARN" "git user.email not set"
}

install_tools() {
  command -v apt-get >/dev/null 2>&1 || die "apt-get not found; install manually"
  sudo -n true >/dev/null 2>&1 || log "WARN" "sudo may prompt"
  sudo apt-get update -y
  sudo apt-get install -y git
  log "OK" "Install done"
}

purge() {
  [[ "${PURGE_YES}" -eq 1 ]] || die "--purge requires --yes"
  mkdir -p "${LOGS_DIR}" "${DEST_DIR}" >/dev/null 2>&1 || true
  rm -rf "${LOGS_DIR:?}/"* "${DEST_DIR:?}/"*
  log "OK" "Purged ${LOGS_DIR} and ${DEST_DIR}"
}

run_cmd() {
  local cmd="$1"
  if [[ "${CMD_MODE}" == "bash-i" ]]; then
    bash -ic "${cmd}"
  else
    bash -c "${cmd}"
  fi
}

default_git() {
  git checkout "${BRANCH}"
  git add .
  git commit -m "commit last version" || true
  git push --set-upstream --force origin "${BRANCH}"
}

discover_repos() {
  find "${ROOT_DIR}" -type d -name .git -print0 2>/dev/null |
    while IFS= read -r -d '' gd; do
      printf '%s\0' "${gd%/.git}"
    done
}

exec_once() {
  RUN_TS="$(ts_now)"
  mkdir -p "${LOGS_DIR}" "${DEST_DIR}" "${INFOS_DIR}" >/dev/null 2>&1 || die "Cannot create logs/results/infos"

  LOG_FILE="${LOGS_DIR}/log.syncgit.${RUN_TS}.log"
  RESULT_FILE="${DEST_DIR}/results.syncgit.${RUN_TS}.txt"
  : > "${LOG_FILE}"

  sep
  log "INFO" "Run start: root_dir=${ROOT_DIR} branch=${BRANCH} simulate=${SIMULATE} cmd_mode=${CMD_MODE}"
  log "INFO" "cmd: ${CUSTOM_CMD:-'(default git sequence)'}"
  sep

  local total=0 ok=0 skip=0 fail=0
  local -a OK_LIST=() SK_LIST=() FA_LIST=()

  while IFS= read -r -d '' repo; do
    total=$((total+1))
    log "INFO" "[${total}] Repo: $repo"

    if [[ ! -d "$repo/.git" ]]; then
      log "WARN" "SKIP: missing .git"
      skip=$((skip+1)); SK_LIST+=("$repo")
      continue
    fi

    if [[ "${SIMULATE}" -eq 1 ]]; then
      WARNINGS=()

      remote_url="$(git -C "$repo" remote get-url origin 2>/dev/null || true)"
      if [[ "$remote_url" =~ ^https:// ]]; then
          WARNINGS+=("HTTPS to SSH applied")
      fi

      if ! git -C "$repo" show-ref --verify --quiet refs/heads/main; then
          WARNINGS+=("main branch missing")
      fi

      current_branch="$(git -C "$repo" branch --show-current 2>/dev/null || true)"
      if git -C "$repo" show-ref --verify --quiet refs/heads/main; then
          ahead=$(git -C "$repo" rev-list --left-right --count main...${current_branch} 2>/dev/null | awk '{print $2}')
          if [[ "$ahead" -gt 0 ]]; then
              WARNINGS+=("current branch ahead of main")
          fi
      fi

      big_files=$(git -C "$repo" rev-list --objects --all 2>/dev/null |
        git -C "$repo" cat-file --batch-check='%(objecttype) %(objectsize) %(rest)' 2>/dev/null |
        awk '$1=="blob" && $2 > 50000000 {print $3}' | head -n 1)

      if [[ -n "$big_files" ]]; then
          WARNINGS+=("large files detected")
      fi

      if [[ ${#WARNINGS[@]} -eq 0 ]]; then
          log "SIM" "SYNCED"
      else
          log "SIM" "SYNCED - WARNING $(IFS=' / '; echo "${WARNINGS[*]}")"
      fi

      ok=$((ok+1)); OK_LIST+=("$repo")
      continue
    fi

    (
      cd "$repo" || exit 11
      git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 12
      if [[ -n "${CUSTOM_CMD}" ]]; then
        run_cmd "${CUSTOM_CMD}"
      else
        default_git
      fi
    )
    local rc=$?

    case "$rc" in
      0)  log "OK" "OK"; ok=$((ok+1)); OK_LIST+=("$repo") ;;
      11|12) log "WARN" "SKIP rc=$rc"; skip=$((skip+1)); SK_LIST+=("$repo") ;;
      *)  log "ERROR" "FAIL rc=$rc"; fail=$((fail+1)); FA_LIST+=("$repo") ;;
    esac
  done < <(discover_repos)

  {
    echo "Results summary - syncgit.sh"
    echo "Version   : ${SCRIPT_VERSION}"
    echo "Timestamp : ${RUN_TS}"
    echo "Root dir  : ${ROOT_DIR}"
    echo "Dest dir  : ${DEST_DIR}"
    echo "Logs dir  : ${LOGS_DIR}"
    echo "Branch    : ${BRANCH}"
    echo "Simulate  : ${SIMULATE}"
    echo "Cmd mode  : ${CMD_MODE}"
    echo "Cmd       : ${CUSTOM_CMD:-'(default git sequence)'}"
    echo
    echo "Repos found : $total"
    echo "OK         : $ok"
    echo "SKIPPED    : $skip"
    echo "FAILED     : $fail"
    echo
    echo "== OK =="; printf '%s\n' "${OK_LIST[@]}"
    echo
    echo "== SKIPPED =="; printf '%s\n' "${SK_LIST[@]}"
    echo
    echo "== FAILED =="; printf '%s\n' "${FA_LIST[@]}"
  } > "${RESULT_FILE}"

  sep
  log "INFO" "Run complete"
  log "INFO" "Summary: ${RESULT_FILE}"
  log "INFO" "Log    : ${LOG_FILE}"
  sep
}

do_exec() {
  [[ -d "${ROOT_DIR}" ]] || die "Root directory not found: ${ROOT_DIR}"
  if [[ "${RECURRENT}" -eq 1 ]]; then
    [[ "${RECURRENT_SECONDS}" =~ ^[0-9]+$ ]] || die "--recurrent expects integer seconds"
    log "INFO" "Recurrent mode enabled: every ${RECURRENT_SECONDS}s (Ctrl+C to stop)"
    while true; do
      exec_once
      sleep "${RECURRENT_SECONDS}"
    done
  else
    exec_once
  fi
}

if [[ $# -eq 0 ]]; then
  help
  exit 0
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) help; exit 0 ;;
    --exec|-exe) ACTION_MODE="exec"; shift ;;
    --prerequis|-pr) ACTION_MODE="prerequis"; shift ;;
    --install|-i) ACTION_MODE="install"; shift ;;
    --purge|-pu) ACTION_MODE="purge"; shift ;;
    --changelog|-ch) ACTION_MODE="changelog"; shift ;;
    --root_dir) shift; [[ $# -gt 0 ]] || die "Missing value for --root_dir"; ROOT_DIR="$1"; shift ;;
    --dest_dir|--results_dir) shift; [[ $# -gt 0 ]] || die "Missing value for --dest_dir/--results_dir"; DEST_DIR="$1"; shift ;;
    --logs_dir) shift; [[ $# -gt 0 ]] || die "Missing value for --logs_dir"; LOGS_DIR="$1"; shift ;;
    --branch) shift; [[ $# -gt 0 ]] || die "Missing value for --branch"; BRANCH="$1"; shift ;;
    --simulate|-s) SIMULATE=1; shift ;;
    --cmd) shift; [[ $# -gt 0 ]] || die "Missing value for --cmd"; CUSTOM_CMD="$1"; shift ;;
    --cmd_mode) shift; [[ $# -gt 0 ]] || die "Missing value for --cmd_mode"; CMD_MODE="$1";
              [[ "$CMD_MODE" == "direct" || "$CMD_MODE" == "bash-i" ]] || die "--cmd_mode must be direct|bash-i"; shift ;;
    --recurrent) shift; [[ $# -gt 0 ]] || die "Missing value for --recurrent"; RECURRENT=1; RECURRENT_SECONDS="$1"; shift ;;
    --yes) PURGE_YES=1; shift ;;
    *) die "Unknown argument: $1 (use --help)" ;;
  esac
done

case "$ACTION_MODE" in
  exec) do_exec ;;
  prerequis) prerequis ;;
  install) install_tools ;;
  purge) purge ;;
  changelog) show_changelog ;;
  "") die "No action specified. Use --exec / --prerequis / --install / --purge / --changelog" ;;
  *) die "Unknown action mode: $ACTION_MODE" ;;
esac
