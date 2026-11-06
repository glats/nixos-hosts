set -euo pipefail

activation=$1
watchdog=$2
bash=$3
export HOME="$TMPDIR/home" GH_TEST_LOG="$TMPDIR/calls" GH_TEST_MODE=success
mkdir -p "$HOME/.config/gh"

run_activation() {
  "$watchdog" --kill-after=1s 10s "$bash" -e "$activation" >stdout 2>stderr
  test ! -s stdout
  ! grep -q 'private backend error' stderr
}

run_activation
test ! -e "$GH_TEST_LOG"
test ! -s stderr
printf 'github.com:\n    other:\n' > "$HOME/.config/gh/hosts.yml"
run_activation
test ! -e "$GH_TEST_LOG"
test ! -s stderr
printf 'github.com:\n    glats:\n' > "$HOME/.config/gh/hosts.yml"
printf '%s\n' auth switch --hostname github.com --user glats >expected

for GH_TEST_MODE in success hang failure; do
  rm -f "$HOME/selected-account"
  run_activation
  cmp expected "$GH_TEST_LOG"
  if [ "$GH_TEST_MODE" = success ]; then
    test "$(cat "$HOME/selected-account")" = glats
    test ! -s stderr
  else
    test ! -e "$HOME/selected-account"
    grep -q 'Warning:.*continuing activation' stderr
  fi
done
