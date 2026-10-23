#!/bin/bash
# Blocks Write of an HTML mock that does not build on the mock kit. See .claude/rules/mock-fidelity-rule.md.
input=$(cat)
path=$(jq -r '.tool_input.file_path // ""' <<<"$input")
case "$path" in
  */projects/*/mocks/kit/*) exit 0 ;;
  */projects/*/mocks/*.html) ;;
  *) exit 0 ;;
esac
content=$(jq -r '.tool_input.content // ""' <<<"$input")
if ! grep -q 'mocks/kit/kit.js\|src="kit/kit.js"' <<<"$content"; then
  echo "Mock blocked: $path must load projects/master/mocks/kit/kit.js and render the panel with MRW.panel()/MRW.row(). See .claude/rules/mock-fidelity-rule.md." >&2
  exit 2
fi
if perl -CS -ne 'exit 1 if /[\x{1F300}-\x{1FAFF}\x{2300}-\x{23FF}\x{21C0}-\x{21FF}\x{2600}-\x{27BF}\x{2B00}-\x{2BFF}]/' <<<"$content"; then exit 0; fi
echo "Mock blocked: $path contains emoji or unicode symbol stand-ins. Use MRW.symbol() with real SF Symbols from kit/symbols/." >&2
exit 2
