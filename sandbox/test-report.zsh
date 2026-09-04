#!/usr/bin/env zsh
# SBOX-43 (four sections, ordering, caps, empty window, sanitising),
# SBOX-40 (kernel dedupe across sessions), SBOX-45 (retention).
set -uo pipefail
here="${0:A:h}"
report="${here}/../scripts/.local/scripts/sandbox-report"
tmp=$(mktemp -d); trap 'rm -rf "${tmp}"' EXIT
export SANDBOX_STATE_ROOT="${tmp}/state"
root="${SANDBOX_STATE_ROOT}"
fail=0
check() { if eval "$2"; then print "ok   $1"; else print "FAIL $1"; fail=1; fi }
now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
old=$(date -u -v-40d +%Y-%m-%dT%H:%M:%SZ)
esc=$'\e'

out=$(zsh "${report}" 7); rc=$?
check "no state root: empty-window line, exit 0" '(( rc == 0 )) && [[ "$out" == "no denials recorded in the last 7 days" ]]'

mkdir -p "${root}/sessions/s1" "${root}/sessions/s2" "${root}/host/meta" "${root}/host/storm"
kernel() { print -r -- "{\"ts\":\"$1\",\"src\":\"kernel\",\"session\":\"$2\",\"ws\":\"w\",\"proc\":\"cat\",\"pid\":$3,\"op\":\"$4\",\"path\":\"$5\",\"msg\":\"\"}" }
{
    kernel "${now}" s1 11 file-read-data /a
    kernel "${now}" s1 11 file-read-data /a
    kernel "${now}" s1 12 file-read-data /b
    kernel "$(date -u -v-1M +%FT%TZ)" s1 12 file-read-data /b
    for i in {1..12}; do kernel "${now}" s1 $((100+i)) file-write-create "/p${i}"; done
    print -r -- '{"ts":"'"${now}"'","src":"hook","session":"s1","ws":"w","cmd":"tmux ls","snippet":"x"}'
    print -r -- '{"ts":"'"${now}"'","src":"hook","session":"s1","ws":"w","cmd":"tmux ls","snippet":"x"}'
    print -r -- '{"ts":"'"${now}"'","src":"hook","session":"s1","ws":"w","cmd":"cat \u001b[31mred\u001b[0m","snippet":"x"}'
    for i in {1..11}; do print -r -- '{"ts":"'"${now}"'","src":"hook","session":"s1","ws":"w","cmd":"cmd'"$(printf %02d $i)"'","snippet":"x"}'; done
    print -r -- '{"ts":"'"${now}"'","src":"note","session":"s1","ws":"w","want":"docker ps","why":"stack up?"}'
    print -r -- 'this line is not json'
    print -r -- '{"ts":"'"${old}"'","src":"note","session":"s1","ws":"w","want":"ancient","why":""}'
} > "${root}/sessions/s1/log.jsonl"
kernel "${now}" s2 11 file-read-data /a > "${root}/sessions/s2/log.jsonl"
print -r -- '{"ts":"'"${now}"'","src":"broker","session":"s1","ws":"w","cmd":"open https://x","decision":"auto","rc":0}' > "${root}/host/broker.jsonl"
print -r -- '{"ts":"'"${now}"'","event":"sidecar-died","session":"s1"}' > "${root}/host/events.jsonl"
print -r -- '{"ts":"'"${now}"'","event":"log-truncated","session":"s1"}' >> "${root}/host/events.jsonl"

out=$(zsh "${report}" 7); rc=$?
check "report exits 0" '(( rc == 0 ))'
check "four sections in order" '[[ "$out" == *"## Kernel"*"## Agent-visible"*"## Notes"*"## Broker"* ]]'
check "kernel duplicates counted once (same line, other session)" '[[ "$(print -r -- "$out" | grep -E "^ +1 +file-read-data +/a$" | wc -l | tr -d " ")" == 1 ]]'
check "kernel section capped at 10 rows" '(( $(print -r -- "$out" | sed -n "/## Kernel/,/## Agent/p" | grep -c "^ *[0-9]") == 10 ))'
check "count desc then path asc: /b (2) before /a (1), both before /p*" '[[ "$(print -r -- "$out" | grep -E "^ +[0-9]+ +file-read" | head -2 | awk "{print \$1 \$3}" | tr "\n" " ")" == "2/b 1/a " ]]'
check "hook commands grouped by count" '[[ "$(print -r -- "$out" | grep -E "^ +2 +tmux ls$" | wc -l | tr -d " ")" == 1 ]]'
hook_lines=("${(@f)$(print -r -- "$out" | sed -n "/## Agent-visible/,/## Notes/p" | grep "^ *[0-9]")}")
check "hook section capped at 10 rows, count desc then cmd asc" '(( ${#hook_lines} == 10 )) && [[ "${hook_lines[1]}" == *"tmux ls" && "${hook_lines[2]}" == *"cat "* && "${hook_lines[3]}" == *cmd01 && "${hook_lines[10]}" == *cmd08 ]]'
check "note and broker lines start with the record ts" '[[ "$(print -r -- "$out" | grep "want: docker ps")" == "  ${now}  "* && "$(print -r -- "$out" | grep "open https://x")" == "  ${now}  "* ]]'
check "ANSI escapes stripped" '[[ "$out" != *"${esc}"* && "$out" == *"cat [31mred[0m"* ]]'
check "note printed, old note outside window omitted" '[[ "$out" == *"want: docker ps  why: stack up?"* && "$out" != *ancient* ]]'
check "broker record printed with decision and rc" '[[ "$out" == *"auto"*"rc=0"*"open https://x"* ]]'
check "capture gaps counted in the kernel header" '[[ "$out" == *"sidecar-died 1"*"log-truncated 1"* ]]'
check "malformed line counted" '[[ "$out" == *"skipped 1 malformed line"* ]]'

mkdir -p "${tmp}/empty/sessions/s9"
print -r -- '{"ts":"'"${old}"'","src":"note","session":"s9","ws":"w","want":"ancient","why":""}' > "${tmp}/empty/sessions/s9/log.jsonl"
out=$(SANDBOX_STATE_ROOT="${tmp}/empty" zsh "${report}" 3); rc=$?
check "empty window: exact line, exit 0" '(( rc == 0 )) && [[ "$out" == "no denials recorded in the last 3 days" ]]'

mkdir -p "${root}/sessions/old1" "${root}/sessions/old2"
mkfile -n 26m "${root}/sessions/old1/log.jsonl"; mkfile -n 26m "${root}/sessions/old2/log.jsonl"
print '{}' > "${root}/host/meta/old1.json"; print 0 > "${root}/host/storm/old1"
touch -t 202501010000 "${root}/sessions/old1" "${root}/sessions/old2"
print -r -- '{"ts":"'"${old}"'","src":"broker","session":"s0","ws":"w","cmd":"x","decision":"denied","rc":126}' > "${root}/host/broker.jsonl"
out=$(zsh "${report}" 7); rc=$?
check "prune: old sessions over 50 MB deleted with meta and storm, report completes" '(( rc == 0 )) && [[ ! -e "${root}/sessions/old1" && ! -e "${root}/sessions/old2" && ! -e "${root}/host/meta/old1.json" && ! -e "${root}/host/storm/old1" && -e "${root}/sessions/s1" ]]'
check "broker log rotated when its first record is older than 30 days" '[[ -e "${root}/host/broker.jsonl.1" && ! -e "${root}/host/broker.jsonl" ]]'
exit $fail
