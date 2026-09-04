#!/usr/bin/env zsh
# smoke.zsh: the allow/deny matrix for the rendered policy, run on the host.
#
# Every row launches sandbox-run with a stub agent that executes the row's
# command inside a policy freshly rendered for the row's CWD, so each row
# sees exactly the environment an agent gets. Expect `ok` = exit 0,
# `fail` = non-zero exit.
#
# Fixture (see sandbox/README.md): primary clone ~/dev/$SMOKE_REPO with
# worktrees in workspaces $SMOKE_WS and $SMOKE_OTHER.
#
# Usage: smoke.zsh [--only <label>] [--row 'label|cwd|expect|command']...
set -uo pipefail

REPO="${SMOKE_REPO:-sbx-fixture}"
WS="${SMOKE_WS:-sbx-a}"
OTHER="${SMOKE_OTHER:-sbx-b}"
LINK="${REPO}-link"
NEW_WS="${WS}-smoke-new"
DUMMY_SID="0-smoke"
dummy_session="${HOME}/.local/state/agent-sandbox/sessions/${DUMMY_SID}"
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
precondition "tmux server socket" test -S "/private/tmp/tmux-$(id -u)/default"
precondition "safehouse" command -v safehouse
precondition "jq" command -v jq
[[ -e "${HOME}/dev/${LINK}" ]] || ln -s "${REPO}" "${HOME}/dev/${LINK}"

tmp=$(mktemp -d)
stub="${tmp}/agent"
# a foreign session other rows must not reach
mkdir -p "${dummy_session}/requests" "${dummy_session}/results"
print '{"src":"probe"}' > "${dummy_session}/log.jsonl"; print '{}' > "${dummy_session}/requests/probe.json"
printf '#!/bin/zsh\nexec /bin/zsh -c "$*"\n' > "${stub}"; chmod +x "${stub}"
cleanup() {
    rm -rf "${tmp}" "${dummy_session}"
    rm -f "${dotfiles}"/{sandbox,nvim/.config/nvim,scripts,zsh,claude,opencode,ai}/.probe \
        "${HOME}/dev/${REPO}/.git/.probe" "${HOME}/dev/.worktrees/${WS}/${REPO}/.probe" \
        "${HOME}/dev/${LINK}"
    rmdir "${HOME}/dev/.worktrees/${WS}/${REPO}/.claude" 2>/dev/null
    if [[ -d "${HOME}/dev/.worktrees/${NEW_WS}/${REPO}" ]]; then
        git -C "${HOME}/dev/${REPO}" worktree remove --force "${HOME}/dev/.worktrees/${NEW_WS}/${REPO}" >/dev/null 2>&1
        git -C "${HOME}/dev/${REPO}" branch -D "${NEW_WS}" >/dev/null 2>&1
        rmdir "${HOME}/dev/.worktrees/${NEW_WS}" 2>/dev/null
    fi
}
trap cleanup EXIT

cwd_path() {
    case "$1" in
        default) print "${HOME}/dev/.worktrees/${WS}/${REPO}" ;;
        dotfiles) print "${dotfiles}" ;;
        dev|dev-new) print "${HOME}/dev" ;;
        repo) print "${HOME}/dev/${REPO}" ;;
        *) print -u2 "smoke: unknown cwd key $1"; exit 2 ;;
    esac
}

# --- rows: AC | cwd | expect | command (run by zsh inside) --------------------
rows=(
    "dotfiles-workdir|dotfiles|ok|touch ~/dotfiles/sandbox/.probe"
    "dotfiles-workdir|dotfiles|ok|touch ~/dotfiles/nvim/.config/nvim/.probe"
    "dotfiles-workdir|dotfiles|ok|touch ~/dotfiles/scripts/.probe"
    "dotfiles-workdir|dotfiles|ok|touch ~/dotfiles/zsh/.probe"
    "dotfiles-workdir|dotfiles|ok|touch ~/dotfiles/claude/.probe"
    "dotfiles-workdir|dotfiles|ok|touch ~/dotfiles/opencode/.probe"
    "dotfiles-workdir|dotfiles|ok|touch ~/dotfiles/ai/.probe"
    "dotfiles-workdir|dotfiles|fail|touch ~/dotfiles/scripts/.local/bin/claude"
    "self-governance|default|fail|touch ~/dotfiles/sandbox/.probe"
    "self-governance|default|fail|touch ~/dotfiles/scripts/.probe"
    "self-governance|default|fail|touch ~/.claude/settings.json"
    "self-governance|default|fail|touch ~/.claude/CLAUDE.md"
    "self-governance|default|fail|mkdir -p ~/.claude/hooks && touch ~/.claude/hooks/.probe"
    "self-governance|default|fail|mkdir -p ~/.claude/agents && touch ~/.claude/agents/.probe"
    "self-governance|default|fail|mkdir -p ~/.claude/skills && touch ~/.claude/skills/.probe"
    "self-governance|default|fail|mkdir -p ~/.claude/plugins && touch ~/.claude/plugins/.probe"
    "self-governance|default|fail|mkdir -p ~/.claude/commands && touch ~/.claude/commands/.probe"
    "self-governance|default|fail|touch ~/.mcp.json"
    "self-governance|default|fail|touch ~/.config/opencode/opencode.json"
    "self-governance|default|fail|touch ~/.config/opencode/plugins/.probe"
    "self-governance|default|fail|touch ~/.config/opencode/AGENTS.md"
    "self-governance|default|fail|mkdir -p .claude && touch .claude/settings.json"
    "self-governance|default|fail|mkdir -p .claude && touch .claude/settings.local.json"
    "self-governance|default|fail|ln -sf /tmp/x ~/.zshrc"
    "self-governance|default|fail|touch ~/.zshrc"
    "self-governance|default|fail|touch ~/.zshenv"
    "self-governance|default|fail|touch ~/.zprofile"
    "self-governance|default|fail|touch ~/.zlogin"
    "self-governance|default|fail|touch ~/.aliases.zsh"
    "self-governance|default|fail|touch ~/.gitconfig"
    "self-governance|default|fail|touch ~/.config/git/.probe"
    "self-governance|default|fail|touch ~/.ssh/config"
    "self-governance|default|fail|touch ~/Library/LaunchAgents/.probe"
    "workspace-isolation|default|fail|cat ~/dev/.worktrees/${OTHER}/${REPO}/README.md"
    "workspace-isolation|default|ok|touch ~/dev/${REPO}/.git/.probe"
    "workspace-isolation|default|fail|touch ~/dev/${REPO}/README.md"
    "workspace-isolation|dev|fail|cat ~/dev/.worktrees/${OTHER}/${REPO}/README.md"
    "workspace-isolation|dev|ok|touch ~/dev/${REPO}/.git/.probe"
    "workspace-isolation|dev|fail|touch ~/dev/${REPO}/README.md"
    "workspace-isolation|dev|ok|touch ~/dev/.worktrees/${WS}/${REPO}/.probe"
    "symlinked-repo|dev|fail|touch ~/dev/${LINK}/README.md"
    "symlinked-repo|dev|ok|touch ~/dev/${LINK}/.git/.probe"
    "secrets|default|fail|head -c1 ~/.ssh/id_ed25519"
    "secrets|default|fail|head -c1 '${HOME}/Library/Application Support/Google/Chrome/Default/Cookies'"
    "tmux|default|fail|tmux ls"
    "tmux|default|fail|tmux new-window true"
    "tmux|default|fail|ls /private/tmp/tmux-\$(id -u)/"
    "tmux|default|ok|[[ \$(ws workspace) == ${WS} ]]"
    "git-guards|default|fail|touch ~/dev/${REPO}/.git/hooks/.probe"
    "git-guards|default|fail|touch ~/dev/${REPO}/.git/config"
    "git-guards|repo|fail|touch \$PWD/.git/hooks/.probe"
    "git-guards|repo|fail|touch \$PWD/.git/config"
    "ssh-agent|default|ok|ssh-add -l"
    "process-control|default|ok|pgrep -l zsh"
    "process-control|default|ok|ps -o pid,comm -p \$\$"
    "process-control|default|ok|kill -0 \$(pgrep -n -x tmux)"
    "brew|default|ok|out=\$(brew --prefix 2>&1) && ! print -r -- \"\$out\" | grep -Eq '${denial_pattern}'"
    "brew|default|ok|out=\$(brew list --formula 2>&1) && ! print -r -- \"\$out\" | grep -Eq '${denial_pattern}'"
    "brew|default|ok|out=\$(brew info jq 2>&1) && ! print -r -- \"\$out\" | grep -Eq '${denial_pattern}'"
    "brew|default|fail|touch \"\$(brew --prefix)/.probe\""
    "zsh-startup|default|ok|err=\$(zsh -ic true 2>&1 >/dev/null) && ! print -r -- \"\$err\" | grep -Eq '${denial_pattern}'"
    "playwright|default|ok|touch ~/Library/Caches/ms-playwright-mcp/.probe && rm ~/Library/Caches/ms-playwright-mcp/.probe"
    "playwright|default|ok|d=\$(getconf DARWIN_USER_TEMP_DIR)pw-smoke; mkdir -p \$d && python3 -c 'import socket,sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])' \$d/b.sock; rc=\$?; rm -rf \$d; exit \$rc"
    "chrome|default|ok|out=\$('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' --headless --disable-gpu --no-sandbox --dump-dom about:blank 2>/dev/null) && [[ \$out == *'<html'* ]]"
    "gh|default|ok|gh api user"
    "gh|default|ok|git ls-remote git@github.com:emiliosheinz/dotfiles.git HEAD"
    "gh|default|fail|touch ~/.config/gh/hosts.yml"
    "claude-launcher|default|fail|touch ~/.local/bin/claude"
    "environment|default|ok|[[ \$PATH == ~/dev/.worktrees/${WS}/.tools/bin:* ]]"
    "environment|default|ok|[[ -z \${NPM_CONFIG_PREFIX:-} ]]"
    "session-log|default|ok|echo '{\"src\":\"probe\"}' >> \"\$SANDBOX_SESSION_LOG\""
    "kernel-denials|default|ok|head -c1 ~/.ssh/id_ed25519 2>/dev/null; for i in {1..20}; do grep -q '\"src\":\"kernel\".*\"path\":\"'\$HOME'/.ssh/id_ed25519\"' \"\$SANDBOX_SESSION_LOG\" && exit 0; sleep 0.5; done; exit 1"
    "sandbox-note|default|ok|sandbox-note 'docker ps' 'is the stack up' && grep -q '\"src\":\"note\".*\"want\":\"docker ps\"' \"\$SANDBOX_SESSION_LOG\""
    "scripts-readonly|default|fail|touch ~/.local/scripts/sandbox-denial-hook"
    "scripts-readonly|default|fail|touch ~/.local/scripts/sandbox-note"
    "scripts-readonly|default|fail|touch ~/.local/scripts/sandbox-report"
    "scripts-readonly|default|fail|touch ~/.local/scripts/sandbox-run"
    "session-isolation|default|fail|cat ~/.local/state/agent-sandbox/sessions/${DUMMY_SID}/log.jsonl"
    "session-isolation|default|fail|echo x >> ~/.local/state/agent-sandbox/sessions/${DUMMY_SID}/log.jsonl"
    "session-isolation|default|fail|cat ~/.local/state/agent-sandbox/sessions/${DUMMY_SID}/requests/probe.json"
    "session-isolation|default|fail|touch ~/.local/state/agent-sandbox/sessions/${DUMMY_SID}/results/probe.json"
    "scripts-readonly|default|fail|touch ~/.local/scripts/hostrun-broker"
    "scripts-readonly|default|fail|touch ~/.local/scripts/hostrun"
    "tool-reads|default|ok|head -c1 \"\$(brew --prefix)/bin/gh\""
    "tool-reads|default|ok|head -c1 ~/.config/ccstatusline/settings.json"
    "tool-reads|default|ok|head -c1 ~/.nvm/nvm.sh"
    "tool-reads|default|ok|[[ ! -e ~/.volta/bin/node ]] || head -c1 ~/.volta/bin/node"
    "tool-reads|default|ok|pbpaste >/dev/null"
    # Rendered-policy assertions
    "secrets|default|ok|for p in 'home-prefix \"/.ssh/id_\"' 'home-subpath \"/.gnupg\"' 'home-subpath \"/.aws\"' 'home-subpath \"/.config/gcloud\"' 'Support/Google/Chrome\"' 'Support/Firefox\"' 'Support/Safari\"'; do grep -qF -- \"\$p\" \$SMOKE_POLICY || exit 1; done"
    "policy-layout|default|ok|grep -q ';; Source: 00-base.sb' \$SMOKE_POLICY && grep -q ';; ws-scope.sb' \$SMOKE_POLICY"
    "policy-layout|default|ok|[[ ! -e ~/dotfiles/sandbox/agents.sb ]]"
    "portable-paths|dotfiles|ok|! git grep -q '/User[s]/' -- sandbox scripts"
)
# Broker rows: skipped until hostrun and the launchd job are installed.
broker_rows=(
    "hostrun-open|default|ok|start=\$SECONDS; hostrun open https://example.com && (( SECONDS - start <= 5 ))"
    "auto-approve|default|fail|touch ~/.local/state/agent-sandbox/host/auto-approve"
    "hostrun-no-broker|default|ok|HOSTRUN_PLIST=/nonexistent hostrun true; [[ \$? == 127 ]]"
    "broker-log|default|fail|cat ~/.local/state/agent-sandbox/host/broker.jsonl"
    "ws-wt-add|dev-new|ok|ws wt add ${REPO} -b main && [[ -d ~/dev/.worktrees/${NEW_WS}/${REPO} ]]"
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
        local ws="${WS}"; [[ "${cwdkey}" == dev-new ]] && ws="${NEW_WS}"
        out=$(cd "${dir}" && WS_WORKSPACE="${ws}" SANDBOX_RUN_AGENT_BIN="${stub}" "${launcher}" claude "${cmd}" 2>&1 </dev/null); rc=$?
    fi
    if (( rc == 0 )); then actual=ok; else actual=fail; fi
    if [[ "${actual}" == "${expect}" ]]; then
        printf 'ok   %-20s [%s] %s\n' "${ac}" "${cwdkey}" "${cmd}"
    else
        printf 'FAIL %-20s [%s] %s\n' "${ac}" "${cwdkey}" "${cmd}"
        print "     expected: ${expect}   actual: ${actual} (rc=${rc})"
        [[ -n "${out}" ]] && print -r -- "     output: ${out[1,300]}"
        (( failed++ ))
    fi
}

# "label|cwd|expect|command": the command keeps every `|` after the third field.
split_row() {
    row_ac="${1%%|*}"; local rest="${1#*|}"
    row_cwd="${rest%%|*}"; rest="${rest#*|}"
    row_expect="${rest%%|*}"; row_cmd="${rest#*|}"
}

for row in "${rows[@]}"; do
    split_row "${row}"
    run_row "${row_ac}" "${row_cwd}" "${row_expect}" "${row_cmd}"
done
broker_log="${HOME}/.local/state/agent-sandbox/host/broker.jsonl"
if [[ -r "${plist}" && -x "${hostrun}" ]]; then
    for row in "${broker_rows[@]}"; do
        split_row "${row}"
        run_row "${row_ac}" "${row_cwd}" "${row_expect}" "${row_cmd}"
        # host-side assertion: auto-approved requests are logged as such
        if [[ "${row_cmd}" == "start="* || "${row_cmd}" == "ws wt add"* ]] && [[ -z "${only}" || "${only}" == "${row_ac}" ]]; then
            if [[ "$(tail -n 1 "${broker_log}" 2>/dev/null | jq -r .decision)" == auto ]]; then
                printf 'ok   %-20s [host] broker log decision auto\n' "${row_ac}"
            else
                printf 'FAIL %-20s [host] broker log decision auto\n' "${row_ac}"; (( failed++ ))
            fi
        fi
    done
else
    for row in "${broker_rows[@]}"; do
        split_row "${row}"
        [[ -n "${only}" && "${row_ac}" != "${only}" ]] && continue
        printf 'SKIP %-20s broker not installed: %s\n' "${row_ac}" "${row_cmd}"
    done
fi

print "smoke: ${ran} rows, ${failed} failed"
(( failed == 0 ))
