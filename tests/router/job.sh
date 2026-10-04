# Install the uploaded kit, then run the scenarios, detached from the ssh session (tests/run.ps1, tests/run.sh).
# A dropped connection does not stop it: the wrappers poll /tmp/flint-test.log, which ends with ALL PASSED or SOME FAILED.
# Usage: sh job.sh <kit dir> [scenario ...]
DIR="$(cd "$(dirname "$0")" && pwd)"
KIT="${1:?kit dir}"; shift
echo $$ > /tmp/flint-test.pid
if sh "$KIT/install.sh"; then
	sh "$DIR/all.sh" "$KIT" "$@"
else
	echo "SOME FAILED (install.sh)"
fi
rm -rf "$KIT" "${DIR%/router}" /tmp/flint-test.pid
