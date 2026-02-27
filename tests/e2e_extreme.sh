#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -x "$ROOT_DIR/zig-out/bin/zigbox" ]]; then
  zig build
fi

ZIGBOX="$ROOT_DIR/zig-out/bin/zigbox"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

assert_file() {
  [[ -f "$1" ]] || fail "expected file: $1"
}

assert_dir() {
  [[ -d "$1" ]] || fail "expected directory: $1"
}

assert_not_exists() {
  [[ ! -e "$1" ]] || fail "expected path to not exist: $1"
}

assert_contains() {
  local needle="$1"
  local file="$2"
  grep -Fq "$needle" "$file" || fail "expected '$needle' in $file"
}

assert_eq() {
  local got="$1"
  local want="$2"
  [[ "$got" == "$want" ]] || fail "expected '$want', got '$got'"
}

# Isolated workspace with nested structure and spaces in names.
mkdir -p "$TMP_DIR/real/root/inner dir" "$TMP_DIR/out" "$TMP_DIR/multi-dst"
printf 'alpha\nTODO one\n' > "$TMP_DIR/real/root/file one.txt"
printf 'beta\nTODO two\n' > "$TMP_DIR/real/root/inner dir/file-two.txt"
ln -s "$TMP_DIR/real/root" "$TMP_DIR/link-root"

# pwd: logical vs physical from symlinked cwd.
pushd "$TMP_DIR/link-root" >/dev/null
pwd_logical="$($ZIGBOX pwd -L)"
pwd_physical="$($ZIGBOX pwd -P)"
popd >/dev/null
assert_eq "$pwd_logical" "$TMP_DIR/link-root"
assert_eq "$pwd_physical" "$TMP_DIR/real/root"

# echo -n should not append newline.
echo_out="$($ZIGBOX echo -n hello extreme)"
assert_eq "$echo_out" "hello extreme"

# touch -c must not create missing files.
$ZIGBOX touch -c "$TMP_DIR/should-not-exist.txt"
assert_not_exists "$TMP_DIR/should-not-exist.txt"

# mkdir -p and touch should handle nested paths with spaces.
$ZIGBOX mkdir -p "$TMP_DIR/out/deep path/n1"
$ZIGBOX touch "$TMP_DIR/out/deep path/n1/touched.txt"
assert_file "$TMP_DIR/out/deep path/n1/touched.txt"

# cp recursive directory copy with nested content.
$ZIGBOX cp -r "$TMP_DIR/real/root" "$TMP_DIR/out/copied-root"
assert_dir "$TMP_DIR/out/copied-root"
assert_file "$TMP_DIR/out/copied-root/file one.txt"
assert_file "$TMP_DIR/out/copied-root/inner dir/file-two.txt"

# cp multiple sources into existing directory.
$ZIGBOX cp "$TMP_DIR/real/root/file one.txt" "$TMP_DIR/real/root/inner dir/file-two.txt" "$TMP_DIR/multi-dst"
assert_file "$TMP_DIR/multi-dst/file one.txt"
assert_file "$TMP_DIR/multi-dst/file-two.txt"

# cp multiple sources into non-directory must fail.
if $ZIGBOX cp "$TMP_DIR/real/root/file one.txt" "$TMP_DIR/real/root/inner dir/file-two.txt" "$TMP_DIR/not-a-dir.txt" >/dev/null 2>&1; then
  fail "cp should fail when multiple sources target a non-directory"
fi

# mv multiple sources into existing directory.
mkdir -p "$TMP_DIR/move-dst"
$ZIGBOX mv "$TMP_DIR/multi-dst/file one.txt" "$TMP_DIR/multi-dst/file-two.txt" "$TMP_DIR/move-dst"
assert_file "$TMP_DIR/move-dst/file one.txt"
assert_file "$TMP_DIR/move-dst/file-two.txt"
assert_not_exists "$TMP_DIR/multi-dst/file one.txt"
assert_not_exists "$TMP_DIR/multi-dst/file-two.txt"

# find with wildcard and type filtering.
$ZIGBOX find "$TMP_DIR/out/copied-root" -name "*.txt" -type f > "$TMP_DIR/find.out"
assert_contains "file one.txt" "$TMP_DIR/find.out"
assert_contains "file-two.txt" "$TMP_DIR/find.out"

# grep recursive across nested directory.
$ZIGBOX grep -r "TODO" "$TMP_DIR/out/copied-root" > "$TMP_DIR/grep.out"
assert_contains "TODO one" "$TMP_DIR/grep.out"
assert_contains "TODO two" "$TMP_DIR/grep.out"

# ls long format on nested directory should include known file.
$ZIGBOX ls -lah "$TMP_DIR/out/copied-root" > "$TMP_DIR/ls.out"
assert_contains "file one.txt" "$TMP_DIR/ls.out"

# cat should preserve contents.
$ZIGBOX cat "$TMP_DIR/out/copied-root/file one.txt" > "$TMP_DIR/cat.out"
assert_contains "alpha" "$TMP_DIR/cat.out"
assert_contains "TODO one" "$TMP_DIR/cat.out"

# rm without -r on directory must fail.
if $ZIGBOX rm "$TMP_DIR/out/copied-root" >/dev/null 2>&1; then
  fail "rm should fail on directory without -r"
fi

# rm -r must remove nested tree fully.
$ZIGBOX rm -r "$TMP_DIR/out/copied-root"
assert_not_exists "$TMP_DIR/out/copied-root"

echo "E2E extreme tests passed"
