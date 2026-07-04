#!/usr/bin/env bash
# Install this repo's cost-routing subagents into a Claude Code agents directory.
#
# Usage:
#   ./install.sh                          install ALL agents for the current user   (~/.claude/agents/)
#   ./install.sh <name>                   install one agent (e.g. ./install.sh scout)
#   ./install.sh --target project --repo PATH   install into PATH/.claude/agents/   (project-local)
#   ./install.sh --list                   list available agents
#   ./install.sh --uninstall [name|all]   remove installed agent(s) this repo owns
#   ./install.sh --help                   this help
#
# Agents live in this repo under `agents/<name>.md`. The installer prefers a
# symlink (so a `git pull` here propagates with no re-install); where symlinks
# are unavailable (common on Windows/MSYS), it falls back to a copy and says so.
#
# Idempotent. Only ever touches files whose basename matches an agent in this
# repo, so it will not disturb other subagents in the target directory.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_ROOT="${SCRIPT_DIR}/agents"

list_agents() {
    [[ -d "${AGENTS_ROOT}" ]] || { echo "no agents directory at ${AGENTS_ROOT}" >&2; exit 1; }
    for f in "${AGENTS_ROOT}"/*.md; do
        [[ -e "$f" ]] || continue
        printf '  %s\n' "$(basename "${f}" .md)"
    done
}

print_help() { sed -n 's/^# \{0,1\}//p' "$0" | head -n 18; }

TARGET="user"
REPO=""
ACTION="install"
ONE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target) TARGET="$2"; shift 2 ;;
        --repo) REPO="$2"; shift 2 ;;
        --list) list_agents; exit 0 ;;
        --uninstall) ACTION="uninstall"; shift; [[ $# -gt 0 && "$1" != --* ]] && { ONE="$1"; shift; } ;;
        -h|--help) print_help; exit 0 ;;
        --*) echo "error: unknown flag '$1'" >&2; exit 2 ;;
        *) [[ -n "${ONE}" ]] && { echo "error: too many names ('${ONE}' and '$1')" >&2; exit 2; }; ONE="$1"; shift ;;
    esac
done

# Resolve the destination agents directory.
case "${TARGET}" in
    user)    DEST_DIR="${HOME}/.claude/agents" ;;
    project) [[ -n "${REPO}" ]] || { echo "error: --target project needs --repo PATH" >&2; exit 2; }
             DEST_DIR="${REPO%/}/.claude/agents" ;;
    *) echo "error: --target must be 'user' or 'project'" >&2; exit 2 ;;
esac

# Which agents are we acting on?
select_srcs() {
    if [[ -n "${ONE}" && "${ONE}" != "all" ]]; then
        local src="${AGENTS_ROOT}/${ONE}.md"
        [[ -f "${src}" ]] || { echo "error: no agent '${ONE}' (see --list)" >&2; exit 2; }
        printf '%s\n' "${src}"
    else
        for f in "${AGENTS_ROOT}"/*.md; do [[ -e "$f" ]] && printf '%s\n' "$f"; done
    fi
}

if [[ "${ACTION}" == "uninstall" ]]; then
    while IFS= read -r src; do
        dest="${DEST_DIR}/$(basename "${src}")"
        if [[ -e "${dest}" || -L "${dest}" ]]; then rm -f "${dest}"; echo "removed  ${dest}"; fi
    done < <(select_srcs)
    exit 0
fi

mkdir -p "${DEST_DIR}"
while IFS= read -r src; do
    dest="${DEST_DIR}/$(basename "${src}")"
    rm -f "${dest}"
    if ln -s "${src}" "${dest}" 2>/dev/null && [[ -L "${dest}" ]]; then
        echo "linked   ${dest}"
    else
        cp -f "${src}" "${dest}"
        echo "copied   ${dest}   (no symlink support — re-run after 'git pull')"
    fi
done < <(select_srcs)

echo
echo "done -> ${DEST_DIR}"
