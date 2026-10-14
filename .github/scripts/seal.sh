#!/usr/bin/env bash
# Seals this job's quiet log (see q.sh) for the maintainer. It packs $RUNNER_TEMP/ci.log and the
# saved fuzz cases (app/src-tauri/target/invade-fuzz, when a fuzz test failed) into a tar.gz, then
# encrypts it with seal.mjs for .github/ci-logs.pub.pem, whose private key never leaves the
# maintainer's Mac. The plaintext copies are deleted; upload only $RUNNER_TEMP/sealed-$NAME.enc.
#
#   NAME=<job name> bash "$GITHUB_WORKSPACE/.github/scripts/seal.sh"
#
# Windows runners check text files out with CRLF line endings: same guard as in q.sh.
case "$(cat "$0")" in *$'\r'*) tr -d '\r' < "$0" > "$RUNNER_TEMP/seal-lf.sh" || exit 1; exec bash "$RUNNER_TEMP/seal-lf.sh" "$@" ;; esac #
set -euo pipefail

: "${NAME:?NAME is not set}" "${RUNNER_TEMP:?}" "${GITHUB_WORKSPACE:?}"
case "$NAME" in
  *[!A-Za-z0-9._-]*) echo 'seal: NAME may only contain letters, digits, ".", "_" and "-"' >&2; exit 1 ;;
esac

# Relative paths from here on: GNU tar (Git for Windows) reads the colon of D:\ as a remote host.
cd "$RUNNER_TEMP"
dir="seal-$NAME"
rm -rf "$dir" "$dir.tgz"
mkdir "$dir"
if [ -f ci.log ]; then
  cp ci.log "$dir/ci.log"
else
  echo 'No quiet step ran in this job.' > "$dir/ci.log"
fi
fuzz="$GITHUB_WORKSPACE/app/src-tauri/target/invade-fuzz"
if [ -d "$fuzz" ]; then
  # Errors would name the fuzz cases: keep them out of the public log too.
  cp -R "$fuzz" "$dir/invade-fuzz" 2> /dev/null || echo 'seal: copying invade-fuzz failed' >> "$dir/ci.log"
fi
if ! tar -czf "$dir.tgz" -C "$dir" . 2> /dev/null; then
  rm -rf "$dir" "$dir.tgz"
  echo 'seal: packing the log failed' >&2
  exit 1
fi
rm -rf "$dir"
node "$GITHUB_WORKSPACE/.github/scripts/seal.mjs" "$dir.tgz" "sealed-$NAME.enc" "$GITHUB_WORKSPACE/.github/ci-logs.pub.pem" || status=$?
rm -f "$dir.tgz"
if [ -n "${status:-}" ]; then
  echo "seal: encryption failed (exit $status)" >&2
  exit "$status"
fi
echo "sealed: sealed-$NAME.enc ($(wc -c < "sealed-$NAME.enc" | tr -d ' ') bytes)"
