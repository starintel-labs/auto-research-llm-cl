#!/usr/bin/env bash
# test-launcher.bash --- regression tests for the bin/research CLI contract.
#
# Covers the misrouting regression:
#   `research star-lang prompts/star-lang/bounder.md`
# must fail as ambiguous instead of submitting the literal words under
# the default project; `research -p star-lang <file>` must resolve the
# project explicitly and read the file.
#
# Usage: bash tests/test-launcher.bash   (exits non-zero on any failure)

set -u
cd "$(dirname "$0")/.."

pass=0
fail=0

check() { # description condition-result
  if [ "$2" = "0" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: $1"
  fi
}

# Load the launcher as a library; no API calls happen in resolve-invocation.
AR_RESEARCH_LIB_ONLY=1
# shellcheck disable=SC1091
source bin/research
# the launcher sets -e/-u for execution; the tests need failure as data
set +e +o pipefail

# ---- fixture ----------------------------------------------------------------
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
printf 'Investigate Star-Lang parser ownership with evidence from the repository.' \
  > "$TMP/bounder.md"

DEFAULT_PROJECT="auto-research"

# ---- 1. -p PROJECT <file> ----------------------------------------------------
resolve-invocation -p star-lang "$TMP/bounder.md" 2>/dev/null
check "-p star-lang <file> resolves" $?
check "project is star-lang" $([ "${PROJECT:-}" = "star-lang" ]; echo $?)
check "input-kind is file" $([ "${INPUT_KIND:-}" = "file" ]; echo $?)
check "input-path retained" $([ "${INPUT_PATH:-}" = "$TMP/bounder.md" ]; echo $?)
check "question is the file content" \
  $([ "${QUESTION:-}" = "Investigate Star-Lang parser ownership with evidence from the repository." ]; echo $?)

# ---- 2. the regression invocation: project id + file without -p --------------
resolve-invocation star-lang "$TMP/bounder.md" 2>/dev/null
check "ambiguous project+file invocation fails" $([ $? -ne 0 ]; echo $?)

# a file that does not exist keeps free-text semantics
resolve-invocation star-lang "$TMP/missing-file.md" 2>/dev/null
check "non-file args remain free text" $?
check "text input kind" $([ "${INPUT_KIND:-}" = "text" ]; echo $?)
check "text question joined" $([ "${QUESTION:-}" = "star-lang $TMP/missing-file.md" ]; echo $?)

# ---- 3. quoted question / multi-word topics ----------------------------------
resolve-invocation -p star-lang "long quoted question" 2>/dev/null
check "quoted question resolves" $?
check "quoted question project" $([ "${PROJECT:-}" = "star-lang" ]; echo $?)
check "quoted question kind is text" $([ "${INPUT_KIND:-}" = "text" ]; echo $?)
check "quoted question text" $([ "${QUESTION:-}" = "long quoted question" ]; echo $?)

resolve-invocation topic words here 2>/dev/null
check "multi-word topic joins" $([ "${QUESTION:-}" = "topic words here" ]; echo $?)
check "multi-word topic uses default project" \
  $([ "${PROJECT:-}" = "auto-research" ]; echo $?)

# ---- 4. malformed options -----------------------------------------------------
resolve-invocation -p 2>/dev/null
check "-p without value fails" $([ $? -ne 0 ]; echo $?)

resolve-invocation 2>/dev/null
check "no arguments fails" $([ $? -ne 0 ]; echo $?)

# ---- 5. unknown project fails clearly before submission -----------------------
PROJECT="star-lanng"
project-http-code() { echo 404; }
api-get() { echo '{"projects":[{"id":"auto-research"},{"id":"star-lang"}]}'; }
ensure-project 2>/dev/null
check "unknown project fails" $([ $? -ne 0 ]; echo $?)

PROJECT="star-lang"
project-http-code() { echo 200; }
ensure-project 2>/dev/null
check "known project resolves" $?

PROJECT="weird"
project-http-code() { echo 000; }
ensure-project 2>/dev/null
check "unreachable API fails closed" $([ $? -ne 0 ]; echo $?)

# ---- summary ------------------------------------------------------------------
echo "launcher tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
