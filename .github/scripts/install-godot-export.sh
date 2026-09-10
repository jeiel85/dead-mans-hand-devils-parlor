#!/usr/bin/env bash
# Writes $RUNNER_TEMP/godot-export.sh, the wrapper every workflow uses to export
# a Godot preset. Kept here rather than inline in each workflow so the three
# call sites cannot drift apart.
set -euo pipefail

mkdir -p "$RUNNER_TEMP/exportlogs"

cat > "$RUNNER_TEMP/godot-export.sh" <<'WRAPPER'
#!/usr/bin/env bash
# Usage: godot-export.sh "<preset name>" <output path>
#
# Godot's headless editor finishes the export and can then hang on shutdown, so
# it runs under `timeout` and exit code 124 is treated as "finished, then hung".
# Success is judged by the two things that actually matter: no failure marker in
# the log, and (checked by the caller) a non-empty artifact. Shutdown noise —
# leaked RIDs, unreferenced StringNames, thread cleanup — is expected and ignored.
set -uo pipefail

preset="$1"
out="$2"

# Markers that mean the export itself went wrong, as opposed to shutdown noise.
# Deliberately specific: generic engine lines like "Could not open ..." or
# "Condition ... is true" also show up in healthy runs and would fail the build
# for nothing.
FAILURE_MARKERS='Project export for preset|Failed to export|No export template found|Template file not found|Cannot create file|SCRIPT ERROR|Parse Error'

slug=$(printf '%s' "$preset" | tr ' ' '_')
log="$RUNNER_TEMP/exportlogs/$slug.log"

timeout 900 "$HOME/godot/godot" --headless --path godot --export-release "$preset" "$out" >"$log" 2>&1
status=$?

echo "--- export '$preset' finished (godot exit $status)"
tail -n 15 "$log"

if grep -qE "$FAILURE_MARKERS" "$log"; then
  echo "::error::Godot reported a failure while exporting '$preset'"
  grep -nE "$FAILURE_MARKERS" "$log" | head -20
  exit 1
fi

# 124 is our own timeout killing a finished-but-hung editor; anything else is real.
if [ "$status" -ne 0 ] && [ "$status" -ne 124 ]; then
  echo "::error::Godot exited $status while exporting '$preset'"
  exit 1
fi

echo "export '$preset' OK"
WRAPPER

chmod +x "$RUNNER_TEMP/godot-export.sh"
echo "wrote $RUNNER_TEMP/godot-export.sh"
