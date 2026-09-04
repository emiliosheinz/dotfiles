#!/usr/bin/env zsh
# hostrun + hostrun-broker unit tests (SBOX-19/30–36): the broker runs
# directly (no launchd) against a temp state root with the dialog seam
# scripted through HOSTRUN_DIALOG.
set -uo pipefail
here="${0:A:h}"
hostrun="${here}/../scripts/.local/scripts/hostrun"
broker="${here}/../scripts/.local/scripts/hostrun-broker"
tmp=$(mktemp -d); trap 'rm -rf "${tmp}"' EXIT
export SANDBOX_STATE_ROOT="${tmp}/state" HOSTRUN_PLIST="${tmp}/local.hostrun.plist" HOSTRUN_DEADLINE=4
root="${SANDBOX_STATE_ROOT}"
: > "${HOSTRUN_PLIST}"
mkdir -p "${root}/host/meta" "${root}/inbox" "${tmp}/work"
export DIALOG_ANSWER="${tmp}/answer" DIALOG_CALLS="${tmp}/calls" DIALOG_SLEEP="${tmp}/dialog-sleep"
cat > "${tmp}/dialog" <<'STUB'
#!/bin/zsh
print -r -- "$1|$2|$3" >> "${DIALOG_CALLS}"
[[ -f "${DIALOG_SLEEP}" ]] && sleep "$(cat "${DIALOG_SLEEP}")"
[[ -f "${DIALOG_PRE}" ]] && zsh "${DIALOG_PRE}"
cat "${DIALOG_ANSWER}" 2>/dev/null || print timeout
STUB
chmod +x "${tmp}/dialog"; export HOSTRUN_DIALOG="${tmp}/dialog" DIALOG_PRE="${tmp}/dialog-pre"
fail=0
check() { if eval "$2"; then print "ok   $1"; else print "FAIL $1"; fail=1; fi }
answer() { print -r -- "$1" > "${DIALOG_ANSWER}" }
calls() { [[ -f "${DIALOG_CALLS}" ]] && wc -l < "${DIALOG_CALLS}" | tr -d ' ' || print 0 }
broker_log() { cat "${root}/host/broker.jsonl" 2>/dev/null }
mk_session() {
    local sid="$1" ws="$2"
    mkdir -p "${root}/sessions/${sid}/requests" "${root}/sessions/${sid}/results"
    jq -n --arg sid "${sid}" --arg ws "${ws}" --arg wd "${tmp}/work" '{sid:$sid, ws:$ws, workdir:$wd, started:"", agent_pid:0}' > "${root}/host/meta/${sid}.json"
}
# submit <sid> <outfile> <argv...>: runs hostrun in the background, then the broker.
submit() {
    local sid="$1" outf="$2"; shift 2
    (SANDBOX_SESSION_ID="${sid}" zsh "${hostrun}" "$@" > "${outf}.out" 2> "${outf}.err"; print $? > "${outf}.rc") &
    local hp=$!
    for _ in {1..50}; do [[ -n "$(ls "${root}/inbox" 2>/dev/null)" ]] && break; sleep 0.1; done
    zsh "${broker}"
    wait "${hp}"
}
S1="1000-11"; S2="1000-22"
mk_session "${S1}" wsA; mk_session "${S2}" wsB
rm -f "${DIALOG_CALLS}"

# --- SBOX-30: approve → direct exec, passthrough; deny → 126, not run ------
answer approve
argv_r1=(/bin/sh -c 'printf out; printf err >&2; printf "%s" "$HOME"; exit 3')
submit "${S1}" "${tmp}/r1" "${argv_r1[@]}"
check "approve: rc passthrough" '[[ "$(cat "${tmp}/r1.rc")" == 3 ]]'
check "approve: stdout and stderr passthrough" '[[ "$(cat "${tmp}/r1.out")" == "out${HOME}" && "$(cat "${tmp}/r1.err")" == err ]]'
rec=$(broker_log | tail -1); expected_line="${(j: :)${(@q-)${(@)argv_r1}}}"
check "broker record fields: ts ISO, src, session, ws, cmd, decision, rc" '[[ "$(print -r -- "$rec" | jq -r .src)" == broker && "$(print -r -- "$rec" | jq -r .session)" == "${S1}" && "$(print -r -- "$rec" | jq -r .ws)" == wsA && "$(print -r -- "$rec" | jq -r .cmd)" == "${expected_line}" && "$(print -r -- "$rec" | jq -r .decision)" == approved && "$(print -r -- "$rec" | jq -r .rc)" == 3 && "$(print -r -- "$rec" | jq -r .ts)" == <->-<->-<->T<->:<->:<->Z ]]'
submit "${S1}" "${tmp}/r2" printf '%s' '$HOME'
check "argv executed directly: no shell expansion of \$HOME" '[[ "$(cat "${tmp}/r2.out")" == "\$HOME" ]]'
check "command runs in the session workdir with WS_WORKSPACE from meta" 'submit "${S1}" "${tmp}/r3" /bin/sh -c "pwd; printf %s \"\$WS_WORKSPACE\"" && [[ "$(cat "${tmp}/r3.out")" == "${tmp:A}/work"*wsA ]]'
check "dialog received ws from meta and the exact quoted command line" 'grep -qF "wsA|${expected_line}|" "${DIALOG_CALLS}"'
check "approved resets the storm counter" '[[ ! -e "${root}/host/storm/${S1}" ]]'
ctl=$'\x01'
submit "${S1}" "${tmp}/r3b" printf '%s' "ctl${ctl}char"
check "control characters stripped from the dialog body" '! tail -1 "${DIALOG_CALLS}" | grep -q "${ctl}" && tail -1 "${DIALOG_CALLS}" | grep -q "ctlchar"'

answer deny
submit "${S1}" "${tmp}/r4" touch "${tmp}/ran-denied"
check "deny: 126, message, command not run" '[[ "$(cat "${tmp}/r4.rc")" == 126 && "$(cat "${tmp}/r4.err")" == "hostrun: denied" && ! -e "${tmp}/ran-denied" ]]'
check "deny logged with decision denied and rc 126" '[[ "$(broker_log | tail -1 | jq -r .decision)" == denied && "$(broker_log | tail -1 | jq -r .rc)" == 126 ]]'
answer timeout
submit "${S1}" "${tmp}/r5" touch "${tmp}/ran-timeout"
check "dialog timeout: 124, message, command not run" '[[ "$(cat "${tmp}/r5.rc")" == 124 && "$(cat "${tmp}/r5.err")" == "hostrun: timed out" && ! -e "${tmp}/ran-timeout" ]]'
check "timeout logged with decision timeout and rc 124" '[[ "$(broker_log | tail -1 | jq -r .decision)" == timeout && "$(broker_log | tail -1 | jq -r .rc)" == 124 ]]'
check "default deadline is 30 s in hostrun and the broker" 'grep -q "HOSTRUN_DEADLINE:-30" "${hostrun}" && grep -q "HOSTRUN_DEADLINE:-30" "${broker}"'

# --- SBOX-34: approval after the mtime-derived deadline does not run --------
answer approve; print 5 > "${DIALOG_SLEEP}"
submit "${S2}" "${tmp}/r6" touch "${tmp}/ran-late"
rm -f "${DIALOG_SLEEP}"
check "approve after deadline: timeout, not run" '[[ "$(cat "${tmp}/r6.rc")" == 124 && ! -e "${tmp}/ran-late" ]]'
check "dialog give-up bounded by the deadline (>= 5)" 'tail -1 "${DIALOG_CALLS}" | awk -F"|" "{exit !(\$3 >= 5)}"'

# --- SBOX-32: auto-approve list -----------------------------------------------
expected_default=$'^open https://[^ ]+$\n^ws wt add [A-Za-z0-9][A-Za-z0-9._-]*( -b [A-Za-z0-9][A-Za-z0-9._/-]*)?$'
check "shipped default list: exactly the two spec patterns" '[[ "$(grep -v "^#" "${here}/auto-approve.default")" == "${expected_default}" ]]'
printf '# comment\n^open https://[^ ]+$\n^/usr/bin/true$\n' > "${root}/host/auto-approve"
n=$(calls)
submit "${S2}" "${tmp}/r7" /usr/bin/true
check "auto match: no dialog, rc 0, decision auto" '[[ "$(cat "${tmp}/r7.rc")" == 0 && "$(calls)" == "$n" ]] && [[ "$(broker_log | tail -1 | jq -r .decision)" == auto ]]'
submit "${S2}" "${tmp}/r7b" /usr/bin/true extra
check "anchored: /usr/bin/true extra does not auto-match (dialog called)" '[[ "$(calls)" == $((n+1)) ]]'
printf '^open https://[^ ]+$\n^/usr/bin/tru(e$\n' > "${root}/host/auto-approve"
n=$(calls); answer approve
submit "${S2}" "${tmp}/r8" /usr/bin/true
check "bad regex line: fail closed, dialog called" '[[ "$(calls)" == $((n+1)) ]]'
printf '^/usr/bin/true$\n' > "${root}/host/auto-approve"

# --- SBOX-36: storm guard ----------------------------------------------------
S3="1000-33"; mk_session "${S3}" wsC; rm -f "${DIALOG_CALLS}"
answer deny
submit "${S3}" "${tmp}/s1" /bin/echo one
submit "${S3}" "${tmp}/s2" /bin/echo two
submit "${S3}" "${tmp}/auto" /usr/bin/true
submit "${S3}" "${tmp}/s3" /bin/echo three
n=$(calls)
submit "${S3}" "${tmp}/s4" /bin/echo four
check "three denials (auto in between does not reset): fourth is storm, no dialog" '[[ "$(cat "${tmp}/s4.rc")" == 126 && "$(cat "${tmp}/s4.err")" == "hostrun: storm guard active" && "$(calls)" == "$n" ]] && [[ "$(broker_log | tail -1 | jq -r .decision)" == storm ]]'
print -r -- "3 $(( $(date +%s) - 700 ))" > "${root}/host/storm/${S3}"
n=$(calls); answer approve
submit "${S3}" "${tmp}/s5" /bin/echo five
check "storm window expired (last non-approval > 10 min ago): prompts again" '[[ "$(calls)" == $((n+1)) && "$(cat "${tmp}/s5.out")" == five ]]'

# --- SBOX-35: isolation and immutability -------------------------------------
answer approve
S4="1000-44"; mk_session "${S4}" wsD
(SANDBOX_SESSION_ID="${S1}" zsh "${hostrun}" /bin/echo from-one > "${tmp}/c1.out" 2>/dev/null; print $? > "${tmp}/c1.rc") &
p1=$!
(SANDBOX_SESSION_ID="${S4}" zsh "${hostrun}" /bin/echo from-four > "${tmp}/c4.out" 2>/dev/null; print $? > "${tmp}/c4.rc") &
p4=$!
sleep 0.5; zsh "${broker}"; wait "${p1}" "${p4}"
check "two sessions concurrent: each receives only its own result" '[[ "$(cat "${tmp}/c1.out")" == from-one && "$(cat "${tmp}/c4.out")" == from-four ]]'
leftovers=("${root}"/sessions/{${S1},${S4}}/{requests,results}/*(N))
check "request and result files removed after completion" '(( ${#leftovers} == 0 ))'

# marker naming another session; request whose sid field lies; symlinked request; oversize
jq -n --arg sid "${S2}" '{sid:$sid, rid:"1-2-3", argv:["/bin/echo","x"]}' > "${root}/sessions/${S1}/requests/1-2-3.json"
: > "${root}/inbox/${S1}.1-2-3"
zsh "${broker}"
check "request whose sid does not match the marker: invalid, nothing run" '[[ "$(jq -r .decision "${root}/sessions/${S1}/results/1-2-3.json")" == invalid ]] && [[ "$(broker_log | tail -1 | jq -r .decision)" == invalid ]]'
rm -f "${root}/sessions/${S1}/results/1-2-3.json"
: > "${root}/inbox/${S1}.9-9-9"
zsh "${broker}"
check "marker without a request: invalid logged" '[[ "$(broker_log | tail -1 | jq -r .decision)" == invalid ]]'
rm -f "${root}/sessions/${S1}/results/9-9-9.json"
jq -n --arg sid "${S1}" '{sid:$sid, rid:"2-2-2", argv:["/usr/bin/touch","'"${tmp}"'/ran-symlink"]}' > "${tmp}/planted.json"
ln -s "${tmp}/planted.json" "${root}/sessions/${S1}/requests/2-2-2.json"
: > "${root}/inbox/${S1}.2-2-2"
zsh "${broker}"
check "symlinked request: invalid, not run" '[[ "$(jq -r .decision "${root}/sessions/${S1}/results/2-2-2.json")" == invalid && ! -e "${tmp}/ran-symlink" ]]'
rm -f "${root}/sessions/${S1}/results/2-2-2.json" "${root}/sessions/${S1}/requests/2-2-2.json"
head -c 70000 /dev/zero | tr '\0' 'a' > "${root}/sessions/${S1}/requests/3-3-3.json"
: > "${root}/inbox/${S1}.3-3-3"
zsh "${broker}"
check "oversize request: invalid, request file removed" '[[ "$(jq -r .decision "${root}/sessions/${S1}/results/3-3-3.json")" == invalid && ! -e "${root}/sessions/${S1}/requests/3-3-3.json" ]]'
rm -f "${root}/sessions/${S1}/results/3-3-3.json"
# result path pre-planted as a symlink: replaced by rename, target untouched
print planted > "${tmp}/target.txt"
jq -n --arg sid "${S1}" '{sid:$sid, rid:"4-4-4", argv:["/usr/bin/true"]}' > "${root}/sessions/${S1}/requests/4-4-4.json"
ln -s "${tmp}/target.txt" "${root}/sessions/${S1}/results/4-4-4.json"
: > "${root}/inbox/${S1}.4-4-4"
zsh "${broker}"
check "planted result symlink replaced by rename; target untouched" '[[ ! -L "${root}/sessions/${S1}/results/4-4-4.json" && "$(jq -r .decision "${root}/sessions/${S1}/results/4-4-4.json")" == auto && "$(cat "${tmp}/target.txt")" == planted ]]'
rm -f "${root}/sessions/${S1}/results/4-4-4.json"
# request mutated after submission: the snapshot is what runs
jq -n --arg sid "${S1}" '{sid:$sid, rid:"5-5-5", argv:["/usr/bin/true"]}' > "${root}/sessions/${S1}/requests/5-5-5.json"
: > "${root}/inbox/${S1}.5-5-5"
printf '{"sid":"%s","rid":"5-5-5","argv":["/usr/bin/touch","%s/ran-mutated"]}' "${S1}" "${tmp}" > "${tmp}/mutated.json"
cat > "${DIALOG_PRE}" <<PRE
cp "${tmp}/mutated.json" "${root}/sessions/${S1}/requests/5-5-5.json"
PRE
printf '^never$\n' > "${root}/host/auto-approve"
zsh "${broker}"; rm -f "${DIALOG_PRE}"
check "request mutated while the dialog is open: original argv ran" '[[ "$(broker_log | tail -1 | jq -r .cmd)" == /usr/bin/true && ! -e "${tmp}/ran-mutated" ]]'

# --- execution cap, output cap, queue removed mid-flight, one record per path -
before=$(broker_log | wc -l | tr -d ' ')
HOSTRUN_EXEC_TIMEOUT=1 submit "${S2}" "${tmp}/t1" /bin/sleep 5
check "execution cap: rc 124, decision approved" '[[ "$(cat "${tmp}/t1.rc")" == 124 && "$(broker_log | tail -1 | jq -r .decision)" == approved ]]'
submit "${S2}" "${tmp}/t2" /bin/sh -c 'head -c 2000000 /dev/zero | tr "\0" a'
check "output capped at 1 MB with a note on stderr" '(( $(stat -f %z "${tmp}/t2.out") == 1048576 )) && grep -q truncated "${tmp}/t2.err"'
check "exactly one broker record per request" '(( $(broker_log | wc -l | tr -d " ") == before + 2 ))'
cat > "${DIALOG_PRE}" <<PRE
rm -rf "${root}/sessions/${S2}/results"
PRE
submit "${S2}" "${tmp}/t3" /usr/bin/true; rm -f "${DIALOG_PRE}"
check "queue removed mid-flight: interrupted logged, hostrun times out" '[[ "$(broker_log | tail -1 | jq -r .decision)" == interrupted && "$(cat "${tmp}/t3.rc")" == 124 ]]'
mkdir -p "${root}/sessions/${S2}/results"

# --- broker under a launchd-style PATH: jq must not come from the caller -----
answer approve
(SANDBOX_SESSION_ID="${S1}" zsh "${hostrun}" /bin/echo launchd-path > "${tmp}/lp.out" 2> "${tmp}/lp.err"; print $? > "${tmp}/lp.rc") &
hp=$!
for _ in {1..50}; do [[ -n "$(ls "${root}/inbox" 2>/dev/null)" ]] && break; sleep 0.1; done
env -i PATH=/bin:/usr/sbin:/sbin HOME="${HOME}" SANDBOX_STATE_ROOT="${root}" HOSTRUN_DIALOG="${HOSTRUN_DIALOG}" \
    DIALOG_ANSWER="${DIALOG_ANSWER}" DIALOG_CALLS="${DIALOG_CALLS}" DIALOG_SLEEP="${DIALOG_SLEEP}" DIALOG_PRE="${DIALOG_PRE}" zsh "${broker}"
wait "${hp}"
check "broker finds jq without /usr/bin or brew on the inherited PATH" '[[ "$(cat "${tmp}/lp.rc")" == 0 && "$(cat "${tmp}/lp.out")" == launchd-path ]]'

# --- SBOX-34 second AC / no broker ---------------------------------------------
start=$SECONDS
SANDBOX_SESSION_ID="${S1}" HOSTRUN_PLIST=/nonexistent zsh "${hostrun}" /usr/bin/true 2> "${tmp}/n.err"; rc=$?
check "job definition absent: 127 within 5 s with message" '(( rc == 127 && SECONDS - start <= 5 )) && [[ "$(cat "${tmp}/n.err")" == "hostrun: host broker not installed" ]]'
start=$SECONDS
SANDBOX_SESSION_ID="${S1}" HOSTRUN_DEADLINE=1 zsh "${hostrun}" /usr/bin/true 2> "${tmp}/n2.err"; rc=$?
check "broker installed but not waking: 124 at deadline+15 s" '(( rc == 124 && SECONDS - start >= 16 && SECONDS - start <= 20 )) && [[ "$(cat "${tmp}/n2.err")" == "hostrun: timed out" ]] && [[ -z "$(ls "${root}/inbox")" ]]'
exit $fail
