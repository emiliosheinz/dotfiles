#!/usr/bin/env zsh
# The smoke harness names a missing precondition and reports a
# mismatching row with its label, command, expected and actual outcome.
set -uo pipefail
smoke="${0:A:h}/../smoke.zsh"
fail=0
check() { if eval "$2"; then print "ok   $1"; else print "FAIL $1"; fail=1; fi }

out=$(SMOKE_REPO=no-such-repo-$$ zsh "${smoke}" 2>&1); rc=$?
check "missing precondition exits non-zero and names it" '(( rc != 0 )) && [[ "$out" == *"missing precondition"* && "$out" == *no-such-repo-$$* ]]'

out=$(zsh "${smoke}" --only probe --row 'probe|default|ok|false' 2>&1); rc=$?
check "bad row exits non-zero" '(( rc != 0 ))'
check "bad row prints label, command, expected and actual" '[[ "$out" == *probe* && "$out" == *false* && "$out" == *"expected: ok"* && "$out" == *"actual: fail"* ]]'

out=$(zsh "${smoke}" --only probe --row 'probe|default|ok|true' 2>&1); rc=$?
check "matching row exits zero" '(( rc == 0 )) && [[ "$out" == *"ok   probe"* ]]'
exit $fail
