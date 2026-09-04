#!/usr/bin/env zsh
# smoke.zsh: the pass/fail matrix from spec SBOX-52, run on the host.
#
# Every row launches sandbox-run with a stub agent that executes the row's
# command inside a policy freshly rendered for the row's CWD, so each row
# sees exactly the environment an agent gets. Expect `ok` = exit 0,
# `fail` = non-zero exit.
#
# Fixture (see sandbox/README.md): primary clone ~/dev/$SMOKE_REPO with
# worktrees in workspaces $SMOKE_WS and $SMOKE_OTHER.
#
# Usage: smoke.zsh [--only <AC-ID>] [--row 'AC|cwd|expect|command']...
set -uo pipefail

REPO="${SMOKE_REPO:-sbx-fixture}"
WS="${SMOKE_WS:-sbx-a}"
OTHER="${SMOKE_OTHER:-sbx-b}"
LINK="${REPO}-link"
launcher="${0:A:h}/../scripts/.local/scripts/sandbox-run"
dotfiles="${HOME}/dotfiles"
plist="${HOME}/Library/LaunchAgents/local.hostrun.plist"
hostrun="${HOME}/.local/scripts/hostrun"
denial_pattern='Operation not permitted|EPERM|Sandbox: .* deny\(|Mounts denied'

only=""
extra_rows=()
while (( $# )); do
    case "$1" in
        --only) only="$2"; shift 2 ;;
        --row) extra_rows+=("$2"); shift 2 ;;
        *) print -u2 "smoke: unknown argument $1"; exit 2 ;;
    esac
done

# --- preconditions ------------------------------------------------------------
need() { "$@" >/dev/null 2>&1 }
precondition() { local name="$1"; shift; "$@" >/dev/null 2>&1 || { print -u2 "smoke: missing precondition: ${name}"; exit 1 } }
precondition "primary clone ~/dev/${REPO}" git -C "${HOME}/dev/${REPO}" rev-parse --git-dir
precondition "worktree ~/dev/.worktrees/${WS}/${REPO}" git -C "${HOME}/dev/.worktrees/${WS}/${REPO}" rev-parse --git-dir
precondition "second worktree ~/dev/.worktrees/${OTHER}/${REPO}" git -C "${HOME}/dev/.worktrees/${OTHER}/${REPO}" rev-parse --git-dir
precondition "~/.ssh/id_ed25519" test -f "${HOME}/.ssh/id_ed25519"
precondition "Google Chrome" test -x "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
precondition "gh auth status" gh auth status
precondition "ssh-agent with a loaded key" ssh-add -l
precondition "safehouse" command -v safehouse
precondition "jq" command -v jq
[[ -e "${HOME}/dev/${LINK}" ]] || ln -s "${REPO}" "${HOME}/dev/${LINK}"

tmp=$(mktemp -d)
stub="${tmp}/agent"
printf '#!/bin/zsh\nexec /bin/zsh -c "$*"\n' > "${stub}"; chmod +x "${stub}"
cleanup() {
    rm -rf "${tmp}"
    rm -f "${dotfiles}"/{sandbox,nvim/.config/nvim,scripts,zsh,claude,opencode,ai}/.probe \
        "${HOME}/dev/${REPO}/.git/.probe" "${HOME}/dev/.worktrees/${WS}/${REPO}/.probe" \
        "${HOME}/dev/${LINK}"
    rmdir "${HOME}/dev/.worktrees/${WS}/${REPO}/.claude" 2>/dev/null
}
trap cleanup EXIT

cwd_path() {
    case "$1" in
        default) print "${HOME}/dev/.worktrees/${WS}/${REPO}" ;;
        dotfiles) print "${dotfiles}" ;;
        dev) print "${HOME}/dev" ;;
        repo) print "${HOME}/dev/${REPO}" ;;
        *) print -u2 "smoke: unknown cwd key $1"; exit 2 ;;
    esac
}

# --- rows: AC | cwd | expect | command (run by zsh inside) --------------------
rows=(
    "SBOX-02|dotfiles|ok|touch ~/dotfiles/sandbox/.probe"
    "SBOX-02|dotfiles|ok|touch ~/dotfiles/nvim/.config/nvim/.probe"
    "SBOX-02|dotfiles|ok|touch ~/dotfiles/scripts/.probe"
    "SBOX-02|dotfiles|ok|touch ~/dotfiles/zsh/.probe"
    "SBOX-02|dotfiles|ok|touch ~/dotfiles/claude/.probe"
    "SBOX-02|dotfiles|ok|touch ~/dotfiles/opencode/.probe"
    "SBOX-02|dotfiles|ok|touch ~/dotfiles/ai/.probe"
    "SBOX-02|dotfiles|fail|touch ~/dotfiles/scripts/.local/bin/claude"
    "SBOX-02|default|fail|touch ~/dotfiles/sandbox/.probe"
    "SBOX-02|default|fail|touch ~/dotfiles/scripts/.probe"
    "SBOX-02|default|fail|touch ~/.claude/settings.json"
    "SBOX-02|default|fail|touch ~/.claude/CLAUDE.md"
    "SBOX-02|default|fail|mkdir -p ~/.claude/hooks && touch ~/.claude/hooks/.probe"
    "SBOX-02|default|fail|mkdir -p ~/.claude/agents && touch ~/.claude/agents/.probe"
    "SBOX-02|default|fail|mkdir -p ~/.claude/skills && touch ~/.claude/skills/.probe"
    "SBOX-02|default|fail|mkdir -p ~/.claude/plugins && touch ~/.claude/plugins/.probe"
    "SBOX-02|default|fail|mkdir -p ~/.claude/commands && touch ~/.claude/commands/.probe"
    "SBOX-02|default|fail|touch ~/.mcp.json"
    "SBOX-02|default|fail|touch ~/.config/opencode/opencode.json"
    "SBOX-02|default|fail|touch ~/.config/opencode/plugins/.probe"
    "SBOX-02|default|fail|touch ~/.config/opencode/AGENTS.md"
    "SBOX-02|default|fail|mkdir -p .claude && touch .claude/settings.json"
    "SBOX-02|default|fail|mkdir -p .claude && touch .claude/settings.local.json"
    "SBOX-02|default|fail|ln -sf /tmp/x ~/.zshrc"
    "SBOX-02|default|fail|touch ~/.zshrc"
    "SBOX-02|default|fail|touch ~/.zshenv"
    "SBOX-02|default|fail|touch ~/.zprofile"
    "SBOX-02|default|fail|touch ~/.zlogin"
    "SBOX-02|default|fail|touch ~/.aliases.zsh"
    "SBOX-02|default|fail|touch ~/.gitconfig"
    "SBOX-02|default|fail|touch ~/.config/git/.probe"
    "SBOX-02|default|fail|touch ~/.ssh/config"
    "SBOX-02|default|fail|touch ~/Library/LaunchAgents/.probe"
    "SBOX-03|default|fail|cat ~/dev/.worktrees/${OTHER}/${REPO}/README.md"
    "SBOX-03|default|ok|touch ~/dev/${REPO}/.git/.probe"
    "SBOX-03|default|fail|touch ~/dev/${REPO}/README.md"
    "SBOX-03|dev|fail|cat ~/dev/.worktrees/${OTHER}/${REPO}/README.md"
    "SBOX-03|dev|ok|touch ~/dev/${REPO}/.git/.probe"
    "SBOX-03|dev|fail|touch ~/dev/${REPO}/README.md"
    "SBOX-03|dev|ok|touch ~/dev/.worktrees/${WS}/${REPO}/.probe"
    "SBOX-04|dev|fail|touch ~/dev/${LINK}/README.md"
    "SBOX-04|dev|ok|touch ~/dev/${LINK}/.git/.probe"
    "SBOX-05|default|fail|head -c1 ~/.ssh/id_ed25519"
    "SBOX-05|default|fail|head -c1 '${HOME}/Library/Application Support/Google/Chrome/Default/Cookies'"
    "SBOX-06|default|fail|tmux ls"
    "SBOX-06|default|fail|tmux new-window true"
    "SBOX-06|default|ok|[[ \$(ws workspace) == ${WS} ]]"
    "SBOX-07|default|fail|touch ~/dev/${REPO}/.git/hooks/.probe"
    "SBOX-07|default|fail|touch ~/dev/${REPO}/.git/config"
    "SBOX-07|repo|fail|touch \$PWD/.git/hooks/.probe"
    "SBOX-07|repo|fail|touch \$PWD/.git/config"
    "SBOX-08|default|ok|ssh-add -l"
    "SBOX-10|default|ok|pgrep -l zsh"
    "SBOX-10|default|ok|ps -o pid,comm -p \$\$"
    "SBOX-10|default|ok|kill -0 \$(pgrep -n -x tmux)"
    "SBOX-11|default|ok|out=\$(brew --prefix 2>&1) && ! print -r -- \"\$out\" | grep -Eq '${denial_pattern}'"
    "SBOX-11|default|ok|out=\$(brew list --formula 2>&1) && ! print -r -- \"\$out\" | grep -Eq '${denial_pattern}'"
    "SBOX-11|default|ok|out=\$(brew info jq 2>&1) && ! print -r -- \"\$out\" | grep -Eq '${denial_pattern}'"
    "SBOX-11|default|fail|touch \"\$(brew --prefix)/.probe\""
    "SBOX-12|default|ok|err=\$(zsh -ic true 2>&1 >/dev/null) && ! print -r -- \"\$err\" | grep -Eq '${denial_pattern}'"
    "SBOX-13|default|ok|out=\$('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' --headless --disable-gpu --no-sandbox --dump-dom about:blank 2>/dev/null) && [[ \$out == *'<html'* ]]"
    "SBOX-15|default|ok|gh api user"
    "SBOX-15|default|ok|git ls-remote git@github.com:emiliosheinz/dotfiles.git HEAD"
    "SBOX-15|default|fail|touch ~/.config/gh/hosts.yml"
    "SBOX-16|default|fail|touch ~/.local/bin/claude"
    "SBOX-17|default|ok|[[ \$PATH == ~/dev/.worktrees/${WS}/.tools/bin:* ]]"
    "SBOX-17|default|ok|[[ -z \${NPM_CONFIG_PREFIX:-} ]]"
    "SBOX-44|default|ok|echo '{\"src\":\"probe\"}' >> \"\$SANDBOX_SESSION_LOG\""
    "SBOX-44|default|fail|touch ~/.local/scripts/sandbox-denial-hook"
    "SBOX-51|default|ok|head -c1 \"\$(brew --prefix)/bin/gh\""
    "SBOX-51|default|ok|head -c1 ~/.config/ccstatusline/settings.json"
    "SBOX-51|default|ok|head -c1 ~/.nvm/nvm.sh"
    "SBOX-51|default|ok|[[ ! -e ~/.volta/bin/node ]] || head -c1 ~/.volta/bin/node"
    "SBOX-51|default|ok|pbpaste >/dev/null"
    # Rendered-policy assertions (SBOX-05 second AC, SBOX-50)
    "SBOX-05|default|ok|for p in 'home-prefix \"/.ssh/id_\"' 'home-subpath \"/.gnupg\"' 'home-subpath \"/.aws\"' 'home-subpath \"/.config/gcloud\"' 'Support/Google/Chrome\"' 'Support/Firefox\"' 'Support/Safari\"'; do grep -qF -- \"\$p\" \$SMOKE_POLICY || exit 1; done"
    "SBOX-50|default|ok|grep -q ';; Source: 00-base.sb' \$SMOKE_POLICY && grep -q ';; ws-scope.sb' \$SMOKE_POLICY"
    "SBOX-50|default|ok|[[ ! -e ~/dotfiles/sandbox/agents.sb ]]"
    "SBOX-53|dotfiles|ok|! git grep -q '/User[s]/' -- sandbox scripts"
)
# Broker rows: skipped until phase 3 installs hostrun and the launchd job.
broker_rows=(
    "SBOX-19|default|ok|hostrun open https://example.com"
    "SBOX-32|default|fail|touch ~/.local/state/agent-sandbox/host/auto-approve"
    "SBOX-34|default|ok|HOSTRUN_PLIST=/nonexistent hostrun true; [[ \$? == 127 ]]"
    "SBOX-35|default|fail|ls ~/.local/state/agent-sandbox/sessions/"
)
rows+=("${extra_rows[@]}")

# --- runner -------------------------------------------------------------------
failed=0; ran=0
run_row() {
    local ac="$1" cwdkey="$2" expect="$3" cmd="$4" dir rc actual out
    [[ -n "${only}" && "${ac}" != "${only}" ]] && return 0
    dir=$(cwd_path "${cwdkey}")
    (( ran++ ))
    if [[ "${cmd}" == *SMOKE_POLICY* ]]; then
        (cd "${dir}" && WS_WORKSPACE="${WS}" SANDBOX_RUN_PRINT_POLICY=1 "${launcher}" claude > "${tmp}/policy.sb")
        out=$(cd "${dir}" && SMOKE_POLICY="${tmp}/policy.sb" zsh -c "${cmd}" 2>&1); rc=$?
    else
        out=$(cd "${dir}" && WS_WORKSPACE="${WS}" SANDBOX_RUN_AGENT_BIN="${stub}" "${launcher}" claude "${cmd}" 2>&1 </dev/null); rc=$?
    fi
    if (( rc == 0 )); then actual=ok; else actual=fail; fi
    if [[ "${actual}" == "${expect}" ]]; then
        print -r -- "ok   ${ac}  [${cwdkey}] ${cmd}"
    else
        print -r -- "FAIL ${ac}  [${cwdkey}] ${cmd}"
        print "     expected: ${expect}   actual: ${actual} (rc=${rc})"
        [[ -n "${out}" ]] && print -r -- "     output: ${out[1,300]}"
        (( failed++ ))
    fi
}

# "AC|cwd|expect|command": the command keeps every `|` after the third field.
split_row() {
    row_ac="${1%%|*}"; local rest="${1#*|}"
    row_cwd="${rest%%|*}"; rest="${rest#*|}"
    row_expect="${rest%%|*}"; row_cmd="${rest#*|}"
}

for row in "${rows[@]}"; do
    split_row "${row}"
    run_row "${row_ac}" "${row_cwd}" "${row_expect}" "${row_cmd}"
done
if [[ -r "${plist}" && -x "${hostrun}" ]]; then
    for row in "${broker_rows[@]}"; do
        split_row "${row}"
        run_row "${row_ac}" "${row_cwd}" "${row_expect}" "${row_cmd}"
    done
else
    for row in "${broker_rows[@]}"; do
        split_row "${row}"
        [[ -n "${only}" && "${row_ac}" != "${only}" ]] && continue
        print "SKIP ${row_ac}  broker not installed: ${row_cmd}"
    done
fi

print "smoke: ${ran} rows, ${failed} failed"
(( failed == 0 ))
