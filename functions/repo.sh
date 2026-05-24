#!/usr/bin/env bash
# =============================================================================
# repo — clone / sync a Git repository (or extract a single file / folder)
#
# Usage:
#   repo LINK PATH [OPTIONS]
#
# Arguments:
#   LINK   Repo address WITHOUT "https://" and WITHOUT ".git"
#          e.g.  github.com/user/my-project
#   PATH   Local destination directory (FOLDER WHERE GIT FILES WILL BE)
#
# Options:
#   --file  <remote-path>   Extract only one file from the repo to PATH
#   --dir   <remote-path>   Extract only one directory from the repo to PATH
#   --force                 Re-clone the repo when it is outdated
#                           (default: leave it as-is when outdated)
#   -h, --help              Show this help text
#
# Behaviour
# ---------
#   • If PATH/.git exists and the local HEAD already matches the remote HEAD
#     the repo is NEVER touched (--force has no effect on an up-to-date repo).
#   • If PATH/.git exists but the repo is outdated:
#       - without --force → leave the repo untouched and exit 0
#       -    with --force → remove PATH and re-clone
#   • --file / --dir clone into a temporary directory, copy the requested
#     path to PATH, then remove the temporary clone — the full repo is never
#     stored at PATH in these modes.
# =============================================================================

repo() {
    # ------------------------------------------------------------------ #
    #  Colour helpers                                                      #
    # ------------------------------------------------------------------ #
    _info()    { echo -e "${BLUE}[repo]${RESET} $*"; }
    _ok()      { echo -e "${GREEN}[repo]${RESET} $*"; }
    _warn()    { echo -e "${YELLOW}[repo]${RESET} $*"; }
    _err()     { echo -e "${RED}[repo]${RESET} $*" >&2; }
    _section() { echo -e "${WHITE}── $* ──${RESET}"; }

    # ------------------------------------------------------------------ #
    #  Help                                                               #
    # ------------------------------------------------------------------ #
    _usage() {
        echo -e "
${_BLD}Usage:${_RST}
  repo LINK PATH [--file <path>] [--dir <path>] [--force]

${_BLD}Arguments:${_RST}
  LINK    Repo URL without ${_YLW}https://${_RST} and without ${_YLW}.git${_RST}
          e.g. ${_CYN}github.com/user/project${_RST}
  PATH    Local destination directory

${_BLD}Options:${_RST}
  --file  <remote-path>   Download only a single file from the repo
  --dir   <remote-path>   Download and extract a single directory from the repo
  --force                 Re-clone when the local repo is outdated
  -h, --help              Show this message
"
    }

    # ------------------------------------------------------------------ #
    #  Argument parsing                                                   #
    # ------------------------------------------------------------------ #
    local LINK="" DEST="" REMOTE_FILE="" REMOTE_DIR="" FORCE=false

    if [[ $# -eq 0 ]]; then _usage; return 0; fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)   _usage; return 0 ;;
            --force)     FORCE=true;         shift ;;
            --file)
                [[ -z "${2:-}" ]] && { _err "--file requires an argument"; return 1; }
                REMOTE_FILE="$2";            shift 2 ;;
            --dir)
                [[ -z "${2:-}" ]] && { _err "--dir requires an argument"; return 1; }
                REMOTE_DIR="$2";             shift 2 ;;
            -*)
                _err "Unknown option: $1"; _usage; return 1 ;;
            *)
                if   [[ -z "$LINK" ]]; then LINK="$1"
                elif [[ -z "$DEST" ]]; then DEST="$1"
                else _err "Unexpected argument: $1"; _usage; return 1
                fi
                shift ;;
        esac
    done

    # ------------------------------------------------------------------ #
    #  Validate                                                           #
    # ------------------------------------------------------------------ #
    [[ -z "$LINK" ]] && { _err "LINK is required."; _usage; return 1; }
    [[ -z "$DEST" ]] && { _err "PATH is required."; _usage; return 1; }

    if [[ -n "$REMOTE_FILE" && -n "$REMOTE_DIR" ]]; then
        _err "--file and --dir are mutually exclusive."
        return 1
    fi

    # Ensure git is available
    if ! command -v git &>/dev/null; then
        _err "git is not installed or not in PATH."
        return 1
    fi

    # ------------------------------------------------------------------ #
    #  Build clone URL                                                    #
    # ------------------------------------------------------------------ #
    # Strip any accidental https:// or .git the caller may have included
    local CLEAN_LINK="${LINK#https://}"
    CLEAN_LINK="${CLEAN_LINK%.git}"

    local CLONE_URL="https://${CLEAN_LINK}.git"

    _section "repo"
    _info "Source : ${_BLD}${CLONE_URL}${_RST}"
    _info "Dest   : ${_BLD}${DEST}${_RST}"
    [[ -n "$REMOTE_FILE" ]] && _info "File   : ${_BLD}${REMOTE_FILE}${_RST}"
    [[ -n "$REMOTE_DIR"  ]] && _info "Dir    : ${_BLD}${REMOTE_DIR}${_RST}"
    [[ "$FORCE" == true   ]] && _info "Force  : ${_YLW}enabled${_RST}"

    # ------------------------------------------------------------------ #
    #  Helper — fetch remote HEAD commit SHA                              #
    # ------------------------------------------------------------------ #
    _remote_head() {
        git ls-remote "$1" HEAD 2>/dev/null | awk '$2 == "HEAD" {print $1; exit}'
    }

    # ------------------------------------------------------------------ #
    #  Mode A — full clone (no --file / --dir)                           #
    # ------------------------------------------------------------------ #
    if [[ -z "$REMOTE_FILE" && -z "$REMOTE_DIR" ]]; then

        if [[ -d "$DEST" ]]; then
            _info "Existing repo detected at '${DEST}'."

            local LOCAL_SHA REMOTE_SHA
            LOCAL_SHA="$(git -C "$DEST" rev-parse HEAD 2>/dev/null)"
            REMOTE_SHA="$(_remote_head "$CLONE_URL")"

            if [[ -z "$REMOTE_SHA" ]]; then
                _warn "Could not reach remote — leaving repo untouched."
                return 0
            fi

            if [[ "$LOCAL_SHA" == "$REMOTE_SHA" ]]; then
                _ok "Already up to date (${LOCAL_SHA:0:8}). Nothing to do."
                return 0
            fi

            _warn "Outdated  local=${LOCAL_SHA:0:8}  remote=${REMOTE_SHA:0:8}"

            if [[ "$FORCE" != true ]]; then
                _warn "Use ${_BLD}--force${_RST} to re-clone. Leaving repo as-is."
                return 0
            fi

            _info "Removing outdated repo…"
            rm -rf "$DEST"
        fi

        _info "Cloning…"
        if git clone --depth 1 "$CLONE_URL" "$DEST"; then
            # Remove the .git directory to keep things clean (as per spec)
            rm -rf "$DEST/.git"
            _ok "Done → '${DEST}' (no .git)"
        else
            _err "git clone failed."
            return 1
        fi

        return 0
    fi

    # ------------------------------------------------------------------ #
    #  Mode B — sparse / file extraction (--file or --dir)               #
    # ------------------------------------------------------------------ #

    # Use a temp directory for the clone
    local TMP_DIR
    TMP_DIR="$(mktemp -d "/tmp/repo_XXXXXXXX")"

    _cleanup() { rm -rf "$TMP_DIR"; }
    trap _cleanup RETURN INT TERM

    # Determine which remote path we're after
    local REMOTE_PATH
    if [[ -n "$REMOTE_FILE" ]]; then
        REMOTE_PATH="$REMOTE_FILE"
    else
        REMOTE_PATH="$REMOTE_DIR"
    fi

    # Check if DEST already contains the item and is current
    if [[ -e "$DEST" ]]; then
        _info "Target path '${DEST}' already exists. Checking remote commit…"

        local REMOTE_SHA
        REMOTE_SHA="$(_remote_head "$CLONE_URL")"

        # We store the last-synced SHA in a dotfile next to the destination
        local SHA_STORE
        if [[ -d "$DEST" ]]; then
            SHA_STORE="${DEST%/}/.repo_commit"
        else
            SHA_STORE="${DEST}.repo_commit"
        fi

        local STORED_SHA=""
        [[ -f "$SHA_STORE" ]] && STORED_SHA="$(cat "$SHA_STORE")"

        if [[ -n "$REMOTE_SHA" && "$STORED_SHA" == "$REMOTE_SHA" ]]; then
            _ok "Already up to date (${REMOTE_SHA:0:8}). Nothing to do."
            return 0
        fi

        if [[ -n "$REMOTE_SHA" && -n "$STORED_SHA" ]]; then
            _warn "Outdated  local=${STORED_SHA:0:8}  remote=${REMOTE_SHA:0:8}"
            if [[ "$FORCE" != true ]]; then
                _warn "Use ${_BLD}--force${_RST} to re-download. Leaving as-is."
                return 0
            fi
            _info "Re-downloading…"
        fi
    fi

    # ------ Sparse clone (bandwidth-efficient) -------------------------
    _info "Initialising sparse clone in temp dir…"

    git clone \
        --filter=blob:none \
        --no-checkout \
        --depth=1 \
        "$CLONE_URL" "$TMP_DIR" 2>&1 | sed "s/^/  /"

    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        _err "Sparse clone failed."
        return 1
    fi

    # Configure sparse-checkout to pull only the target path
    git -C "$TMP_DIR" sparse-checkout init --cone 2>/dev/null \
        || git -C "$TMP_DIR" sparse-checkout init

    git -C "$TMP_DIR" sparse-checkout set "$REMOTE_PATH"
    git -C "$TMP_DIR" checkout 2>&1 | sed "s/^/  /"

    # Verify the requested path exists in the clone
    local SRC_PATH="${TMP_DIR}/${REMOTE_PATH}"
    if [[ ! -e "$SRC_PATH" ]]; then
        _err "Path '${REMOTE_PATH}' was not found in the repository."
        return 1
    fi

    # ------ Copy to destination ----------------------------------------
    mkdir -p "$(dirname "$DEST")"

    if [[ -n "$REMOTE_FILE" ]]; then
        # Single file
        cp "$SRC_PATH" "$DEST"
        _ok "File saved → '${DEST}'"
    else
        # Directory — copy contents into DEST
        mkdir -p "$DEST"
        cp -r "${SRC_PATH}/." "$DEST/"
        _ok "Directory extracted → '${DEST}'"
    fi

    # Save the remote commit SHA so future calls can detect staleness
    local FINAL_SHA
    FINAL_SHA="$(git -C "$TMP_DIR" rev-parse HEAD 2>/dev/null)"

    local SHA_STORE
    if [[ -d "$DEST" ]]; then
        SHA_STORE="${DEST%/}/.repo_commit"
    else
        SHA_STORE="${DEST}.repo_commit"
    fi

    echo "$FINAL_SHA" > "$SHA_STORE"
    _info "Commit cached (${FINAL_SHA:0:8}) → '${SHA_STORE}'"

    return 0
}

# =============================================================================
# Stand-alone invocation  (source the file to use as a library, or run it
# directly to call repo with the supplied arguments)
# =============================================================================
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    repo "$@"
fi