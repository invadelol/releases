#!/usr/bin/env bash
# Quiet runner for the CI of the private invadelol/app, which runs on this public repo.
#
#   bash "$GITHUB_WORKSPACE/.github/scripts/q.sh" <command> [args...]
#
# The workflow logs here are public and the app's code is not: compiler errors and warnings, failed
# assertions and stack traces all quote it. So everything the command prints (stdout and stderr)
# goes only to $RUNNER_TEMP/ci.log, which seal.sh encrypts at the end of the job. The public log
# gets "ok", or the `test result:` count lines and the exit code.
#
# Windows runners check text files out with CRLF line endings, which bash cannot parse.
# .github/.gitattributes keeps this file LF; in case a checkout ignores it, every line up to the
# `case` line below is a comment or ends in one (so a trailing CR is harmless there), and if this
# copy has CRs, an LF copy of it runs instead.
case "$(cat "$0")" in *$'\r'*) tr -d '\r' < "$0" > "$RUNNER_TEMP/q-lf.sh" || exit 1; exec bash "$RUNNER_TEMP/q-lf.sh" "$@" ;; esac #
set -u

if [ "$#" -eq 0 ]; then
  echo 'usage: q.sh <command> [args...]' >&2
  exit 2
fi
log="${RUNNER_TEMP:?RUNNER_TEMP is not set}/ci.log"

# Files GitHub shows publicly (the job summary) or that feed later steps (their environment is
# listed in the public log): the command must not reach them.
unset GITHUB_STEP_SUMMARY GITHUB_ENV GITHUB_OUTPUT GITHUB_PATH GITHUB_STATE

printf '\n===== %s | %s | %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')" "$PWD" "$*" >> "$log" || exit 1
status=0
"$@" >> "$log" 2>&1 < /dev/null || status=$?
if [ "$status" -eq 0 ]; then
  echo ok
  exit 0
fi
grep -E '^test result:' "$log" | tail -n 3
echo "failed (exit $status): details in the sealed log"
exit "$status"
