#!/usr/bin/env bash
# ==============================================================================
# Full path    : /workspace/syncgit/findgit.sh
# Script name  : findgit.sh
# Author       : Bruno DELNOZ
# Email        : bruno.delnoz@protonmail.com
# Target usage : Recursively scan a directory to find Git repositories and
#                display repository paths with optional submodule listing.
# Version      : v1.1.0
# Date         : 2026-03-31
# ------------------------------------------------------------------------------
# Changelog:
# - v1.1.0 (2026-03-31): Added CLI framework, help, simulate mode, prerequisites,
#                        install routine, logging/results directories, purge,
#                        changelog display, progress output and safer scanning.
# - v1.0.0 (2026-03-31): Initial minimal repository and submodule finder.
# ==============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_NAME="findgit.sh"
SCRIPT_VERSION="v1.1.0"
SCRIPT_DATE="2026-03-31"
AUTHOR="Bruno DELNOZ"
EMAIL="bruno.delnoz@protonmail.com"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DEFAULT_ROOT_DIR="."
DEFAULT_DEST_DIR="${SCRIPT_DIR}/results"
DEFAULT_LOGS_DIR="${SCRIPT_DIR}/logs"

ROOT_DIR="${DEFAULT_ROOT_DIR}"
DEST_DIR="${DEFAULT_DEST_DIR}"
LOGS_DIR="${DEFAULT_LOGS_DIR}"
SIMULATE=0
ACTION_MODE=""
RUN_TS=""
LOG_FILE=""
RESULT_FILE=""

show_help() {
    cat <<'HELP'
Usage:
  findgit.sh --help|-h
  findgit.sh --exec|-exe [--root_dir <dir>] [--dest_dir <dir>] [--logs_dir <dir>] [--simulate|-s]
  findgit.sh --simulate|-s [--root_dir <dir>] [--dest_dir <dir>] [--logs_dir <dir>]
  findgit.sh --prerequis|-pr
  findgit.sh --install|-i
  findgit.sh --changelog|-ch
  findgit.sh --purge|-pu

Description:
  Scan recursively from --root_dir (default: .) and list Git repositories
  (directories containing a .git folder). For each repository, display whether
  submodules are detected and list them when available.

Options:
  --help, -h           Show this help and exit.
  --exec, -exe         Execute repository discovery.
  --stop, -st          Accepted for CLI compatibility, currently no-op.
  --prerequis, -pr     Check required commands.
  --install, -i        Try to install missing prerequisites.
  --simulate, -s       Dry-run mode (scan and report only, no modifications).
  --changelog, -ch     Print embedded changelog.
  --purge, -pu         Remove generated logs and results directories.
  --root_dir <dir>     Root directory to scan (default: .).
  --dest_dir <dir>     Results directory (default: ./results next to script).
  --logs_dir <dir>     Logs directory (default: ./logs next to script).

Examples:
  ./findgit.sh --prerequis
  ./findgit.sh --exec --root_dir /workspace
  ./findgit.sh --simulate --root_dir .
  ./findgit.sh --exec --root_dir . --dest_dir ./results --logs_dir ./logs
HELP
}

show_changelog() {
    cat <<CHANGELOG
${SCRIPT_NAME} changelog
- v1.1.0 (2026-03-31): Added CLI framework, safety, logs/results, help and options.
- v1.0.0 (2026-03-31): Initial minimal repository and submodule finder.
CHANGELOG
}

ts_now() { date '+%Y%m%d-%H%M%S'; }
ts_human() { date '+%Y-%m-%d %H:%M:%S'; }

log() {
    local level="$1"; shift
    local msg="$*"
    local line="[${SCRIPT_VERSION}] [$(ts_human)] [${level}] ${msg}"
    echo "${line}"
    if [[ -n "${LOG_FILE}" ]]; then
        echo "${line}" >> "${LOG_FILE}"
    fi
}

check_prerequisites() {
    local missing=0
    local commands=(find xargs dirname git awk date)
    for cmd in "${commands[@]}"; do
        if command -v "${cmd}" >/dev/null 2>&1; then
            echo "[OK] ${cmd}"
        else
            echo "[MISSING] ${cmd}"
            missing=1
        fi
    done
    return "${missing}"
}

install_prerequisites() {
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update && sudo apt-get install -y git findutils gawk
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y git findutils gawk
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y git findutils gawk
    elif command -v brew >/dev/null 2>&1; then
        brew install git findutils gawk
    else
        echo "No supported package manager found. Install prerequisites manually."
        return 1
    fi
}

prepare_runtime() {
    RUN_TS="$(ts_now)"
    mkdir -p "${LOGS_DIR}" "${DEST_DIR}"
    LOG_FILE="${LOGS_DIR}/log.${SCRIPT_NAME}.${RUN_TS}.${SCRIPT_VERSION}.log"
    RESULT_FILE="${DEST_DIR}/results.${SCRIPT_NAME}.${RUN_TS}.${SCRIPT_VERSION}.txt"
    : > "${LOG_FILE}"
    : > "${RESULT_FILE}"
}

find_git_repos() {
    local dir="$1"
    local index=0
    mapfile -d '' repos < <(find "${dir}" -type d -name ".git" -print0 | xargs -0 -r dirname -z)
    local total="${#repos[@]}"

    if [[ "${total}" -eq 0 ]]; then
        log "WARN" "No Git repository found under ${dir}"
        echo "No Git repository found under ${dir}" >> "${RESULT_FILE}"
        return 0
    fi

    for repo in "${repos[@]}"; do
        repo="${repo%$'\0'}"
        ((index+=1))
        log "STEP" "Scan du dépôt (${index}/${total}): ${repo}"
        echo "Dépôt Git trouvé : ${repo}" | tee -a "${RESULT_FILE}"

        if [[ -f "${repo}/.gitmodules" ]]; then
            echo "  Submodules dans ce dépôt :" | tee -a "${RESULT_FILE}"
            if [[ "${SIMULATE}" -eq 1 ]]; then
                echo "    - [SIMULATE] git submodule status non exécuté" | tee -a "${RESULT_FILE}"
            else
                git -C "${repo}" submodule status | awk '{print "    - " $2}' | tee -a "${RESULT_FILE}"
            fi
        else
            echo "  Aucun submodule trouvé." | tee -a "${RESULT_FILE}"
        fi
    done
}

purge_artifacts() {
    rm -rf "${LOGS_DIR}" "${DEST_DIR}"
    echo "Purged: ${LOGS_DIR} and ${DEST_DIR}"
}

parse_args() {
    if [[ "$#" -eq 0 ]]; then
        show_help
        exit 0
    fi

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --help|-h) ACTION_MODE="help"; shift ;;
            --exec|-exe) ACTION_MODE="exec"; shift ;;
            --stop|-st) shift ;;
            --prerequis|-pr) ACTION_MODE="prerequis"; shift ;;
            --install|-i) ACTION_MODE="install"; shift ;;
            --simulate|-s) ACTION_MODE="exec"; SIMULATE=1; shift ;;
            --changelog|-ch) ACTION_MODE="changelog"; shift ;;
            --purge|-pu) ACTION_MODE="purge"; shift ;;
            --root_dir)
                ROOT_DIR="$2"; shift 2 ;;
            --dest_dir)
                DEST_DIR="$2"; shift 2 ;;
            --logs_dir)
                LOGS_DIR="$2"; shift 2 ;;
            *)
                echo "Unknown argument: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

main() {
    parse_args "$@"

    case "${ACTION_MODE}" in
        help)
            show_help
            ;;
        prerequis)
            check_prerequisites
            ;;
        install)
            install_prerequisites
            ;;
        changelog)
            show_changelog
            ;;
        purge)
            purge_artifacts
            ;;
        exec)
            prepare_runtime
            log "INFO" "Starting ${SCRIPT_NAME} version ${SCRIPT_VERSION}"
            log "INFO" "Mode simulate: ${SIMULATE}"
            find_git_repos "${ROOT_DIR}"
            log "INFO" "Completed. Results: ${RESULT_FILE}"
            echo "1) Scan completed" | tee -a "${RESULT_FILE}"
            echo "2) Results written to ${RESULT_FILE}" | tee -a "${RESULT_FILE}"
            echo "3) Logs written to ${LOG_FILE}" | tee -a "${RESULT_FILE}"
            ;;
        *)
            show_help
            ;;
    esac
}

main "$@"
