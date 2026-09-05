#!/usr/bin/env bash
# daemon-smoke.sh --- fail-closed smoke check of the running runtime API.
#
# Verifies the semantic-correctness contract end to end against the live
# daemon: configured projects carry their prompt profile and source path,
# and unknown project ids fail clearly with 404 (no silent fallback to a
# default project). Exits non-zero on any mismatch.

set -euo pipefail

CORPUS="${AR_CORPUS_ROOT:-$HOME/starintel/auto-research-llm-cl}"
TOKEN="${AR_OPERATOR_TOKEN:-dev-operator-token}"
PORT="${AR_WEB_PORT:-8080}"
API="http://127.0.0.1:$PORT/api/v1"

projects="$(curl -sf -m 10 -H "Authorization: Bearer $TOKEN" "$API/projects")"
echo "$projects" | python3 -c '
import json, sys

data = json.load(sys.stdin)
projects = {p["id"]: p for p in data.get("projects", [])}
failures = []

for required in ("auto-research", "star-lang"):
    p = projects.get(required)
    if p is None:
        failures.append(f"missing project: {required}")
        continue
    if not p.get("prompt_profile"):
        failures.append(f"{required}: no prompt profile")
    if not p.get("source_path"):
        failures.append(f"{required}: no source repository path")
    if not p.get("source_repository"):
        failures.append(f"{required}: no source repository id")

if failures:
    print("\n".join(failures))
    sys.exit(1)
print("projects ok:", ", ".join(sorted(projects)))'

code="$(curl -s -m 10 -o /dev/null -w '%{http_code}' -X POST \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"question":"smoke"}' "$API/projects/definitely-not-a-project/research")"
if [ "$code" != "404" ]; then
  echo "unknown project did not fail with 404 (got $code)"
  exit 1
fi
echo "unknown project rejected with 404"
