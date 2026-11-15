#!/usr/bin/env sh
# Tests install-skills.sh and uninstall-skills.sh in throwaway folders; nothing outside them is touched.
# Every case runs under each of sh, bash and dash that is installed (or the shells named in TEST_SHELLS).
# When pwsh or powershell is installed, the result is also compared with the PowerShell installer.
set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=${script_dir%/*}
install="$script_dir/install-skills.sh"
uninstall="$script_dir/uninstall-skills.sh"
receipt_name=".ai-engineering-skills.receipt.json"

# The folder name has spaces on purpose.
work=$(mktemp -d "${TMPDIR:-/tmp}/ai skills test XXXXXX")
trap 'rm -rf -- "$work"' EXIT
out="$work/output.txt"
checks=0
shell=""
case_name=""

flunk() {
  printf 'FAILED [%s] %s: %s\n' "$shell" "$case_name" "$1" >&2
  exit 1
}

begin() {
  case_name=$1
}

passed() {
  checks=$((checks + 1))
  printf 'ok - [%s] %s\n' "$shell" "$case_name"
}

# run <expected exit code> <command...>; the output goes to $out.
run() {
  expected=$1
  shift
  set +e
  "$@" >"$out" 2>&1
  actual=$?
  set -e
  if [ "$actual" -ne "$expected" ]; then
    cat "$out" >&2
    flunk "expected exit code $expected, got $actual"
  fi
}

output_has() {
  if ! grep -F -q -- "$1" "$out"; then
    cat "$out" >&2
    flunk "the output lacks: $1"
  fi
}

# Every path under a folder, sorted; a missing folder lists as nothing.
listing() {
  if [ -d "$1" ]; then
    (cd "$1" && find . | LC_ALL=C sort)
  fi
}

files_in() {
  if [ -d "$1" ]; then
    (cd "$1" && find . -type f | sed 's|^\./||' | LC_ALL=C sort)
  fi
}

same_text() {
  printf '%s\n' "$1" >"$work/expected.txt"
  printf '%s\n' "$2" >"$work/actual.txt"
  if ! diff -u "$work/expected.txt" "$work/actual.txt" >&2; then
    flunk "$3"
  fi
}

must_exist() {
  [ -e "$1" ] || flunk "missing: $1"
}

must_not_exist() {
  if [ -e "$1" ] || [ -L "$1" ]; then flunk "still there: $1"; fi
}

# The expected payload comes from skillset.json and the skills folder, not from the installer.
skills=$(sed -n 's/^ *"name": "\([a-z0-9-]*\)".*$/\1/p' "$repo_root/skillset.json")
skill_count=$(printf '%s\n' "$skills" | grep -c .)
[ "$skill_count" -gt 0 ] || {
  printf 'No skill names were read from skillset.json.\n' >&2
  exit 1
}
expected_destination=$(
  cd "$repo_root/skills"
  {
    for name in $skills; do find "$name" -type f; done
    printf '%s\n' "$receipt_name"
  } | LC_ALL=C sort
)

# check_destination <folder>: exactly the payload and a receipt, with the same file contents.
check_destination() {
  same_text "$expected_destination" "$(files_in "$1")" "unexpected files in $1"
  for name in $skills; do
    diff -r "$repo_root/skills/$name" "$1/$name" >&2 || flunk "content differs in $1/$name"
  done
}

# receipts <root>: the destinations that hold a receipt, relative to the root.
receipts() {
  if [ -d "$1" ]; then
    (cd "$1" && find . -name "$receipt_name" | sed -e 's|^\./||' -e "s|/$receipt_name\$||" | LC_ALL=C sort)
  fi
}

# A receipt as Windows PowerShell 5.1 writes it: CRLF, deep indent, two spaces after each colon.
write_powershell_receipt() {
  {
    printf '{\r\n    "schemaVersion":  1,\r\n    "collection":  "ai-engineering-skills",\r\n'
    printf '    "version":  "0.9.0",\r\n    "target":  "Universal",\r\n    "scope":  "User",\r\n'
    printf '    "installedAt":  "2026-01-01T00:00:00Z",\r\n    "skills":  [\r\n'
    printf '                   "%s"\r\n               ]\r\n}\r\n' "$2"
  } >"$1"
}

run_suite() {
  shell=$1
  base="$work/$shell"
  mkdir -p "$base"

  begin "help and option errors"
  run 0 "$shell" "$install" --help
  output_has "--dry-run"
  output_has "--force-overwrite-unmanaged"
  run 0 "$shell" "$uninstall" --help
  output_has "--dry-run"
  run 2 "$shell" "$install" --no-such-option
  output_has "Unknown option"
  run 2 "$shell" "$install" --target vim --user-home "$base/none"
  output_has "Unknown target"
  run 2 "$shell" "$uninstall" --scope
  output_has "needs a value"
  run 1 "$shell" "$install" --user-home "$base/none" --force-overwrite-unmanaged
  output_has "requires --overwrite"
  must_not_exist "$base/none"
  passed

  begin "dry run changes nothing"
  home="$base/home"
  run 0 "$shell" "$install" --target universal --scope user --user-home "$home" --dry-run
  output_has "Dry run: Install skill 'review-code': $home/.claude/skills/review-code"
  output_has "Dry run: nothing was changed."
  must_not_exist "$home"
  passed

  begin "universal user install"
  run 0 "$shell" "$install" --user-home "$home"
  output_has "Installed $skill_count canonical skills into $home/.agents/skills"
  output_has "Installed $skill_count canonical skills into $home/.claude/skills"
  output_has "Installed $skill_count canonical skills into $home/.gemini/config/skills"
  check_destination "$home/.agents/skills"
  check_destination "$home/.claude/skills"
  check_destination "$home/.gemini/config/skills"
  same_text ".agents/skills
.claude/skills
.gemini/config/skills" "$(receipts "$home")" "unexpected destinations"
  grep -F -q '"target": "Universal"' "$home/.agents/skills/$receipt_name" || flunk "the receipt lacks the target"
  grep -F -q '"scope": "User"' "$home/.agents/skills/$receipt_name" || flunk "the receipt lacks the scope"
  passed

  begin "second install without --overwrite is refused"
  before=$(listing "$home")
  run 1 "$shell" "$install" --user-home "$home"
  output_has "Collision detected."
  output_has "$home/.claude/skills/review-code"
  same_text "$before" "$(listing "$home")" "a refused install changed the folder"
  passed

  begin "--overwrite is idempotent, removes stale files and keeps unrelated content"
  printf 'stale\n' >"$home/.agents/skills/review-code/stale.md"
  mkdir -p "$home/.agents/skills/my-own-skill"
  printf 'mine\n' >"$home/.agents/skills/my-own-skill/SKILL.md"
  printf 'notes\n' >"$home/.claude/skills/notes.txt"
  run 0 "$shell" "$install" --user-home "$home" --overwrite
  must_not_exist "$home/.agents/skills/review-code/stale.md"
  must_exist "$home/.agents/skills/my-own-skill/SKILL.md"
  must_exist "$home/.claude/skills/notes.txt"
  rm -r "$home/.agents/skills/my-own-skill" "$home/.claude/skills/notes.txt"
  same_text "$before" "$(listing "$home")" "an overwrite left something behind"
  check_destination "$home/.gemini/config/skills"
  passed

  begin "uninstall removes only what the receipt names"
  mkdir -p "$home/.agents/skills/my-own-skill"
  printf 'mine\n' >"$home/.agents/skills/my-own-skill/SKILL.md"
  printf 'notes\n' >"$home/.claude/skills/notes.txt"
  printf 'other\n' >"$home/unrelated.txt"
  before=$(listing "$home")
  run 0 "$shell" "$uninstall" --user-home "$home" --dry-run
  output_has "Dry run: Uninstall receipt-managed content: $home/.agents/skills/review-code"
  same_text "$before" "$(listing "$home")" "an uninstall dry run changed the folder"
  run 0 "$shell" "$uninstall" --user-home "$home"
  output_has "receipt-managed path(s); unrelated content was preserved."
  same_text ".agents/skills/my-own-skill/SKILL.md
.claude/skills/notes.txt
unrelated.txt" "$(files_in "$home")" "the uninstall left or removed the wrong files"
  must_exist "$home/.gemini/config/skills"
  run 0 "$shell" "$uninstall" --user-home "$home"
  output_has "No managed ai-engineering-skills installation found"
  passed

  begin "each target installs to its own folder"
  for row in \
    "codex user .agents/skills" \
    "claude user .claude/skills" \
    "opencode user .config/opencode/skills" \
    "antigravity user .gemini/config/skills" \
    "Codex Project .agents/skills" \
    "Claude Project .claude/skills" \
    "OpenCode Project .opencode/skills" \
    "Antigravity Project .agents/skills"; do
    # shellcheck disable=SC2086
    set -- $row
    root="$base/target-$1-$2"
    mkdir -p "$root"
    if [ "$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')" = "user" ]; then
      run 0 "$shell" "$install" --target "$1" --scope "$2" --user-home "$root"
    else
      run 0 "$shell" "$install" --target="$1" --scope="$2" --project-root="$root"
    fi
    same_text "$3" "$(receipts "$root")" "wrong destination for $1 $2"
    check_destination "$root/$3"
  done
  passed

  begin "project scope needs no HOME"
  project="$base/project"
  mkdir -p "$project"
  (
    unset HOME
    run 0 "$shell" "$install" --scope project --project-root "$project"
  )
  same_text ".agents/skills
.claude/skills" "$(receipts "$project")" "wrong destinations for a universal project install"
  run 1 "$shell" "$install" --scope project
  output_has "--project-root is required"
  run 1 "$shell" "$install" --scope project --project-root "$base/no-such-project"
  output_has "does not exist"
  run 1 "$shell" "$uninstall" --scope project --project-root "$base/no-such-project"
  output_has "must name an existing directory"
  (
    cd "$project"
    run 0 "$shell" "$uninstall" --scope project --project-root .
  )
  same_text "" "$(files_in "$project")" "a project uninstall left files"
  passed

  begin "a colliding path without a receipt is not replaced"
  root="$base/unmanaged"
  mkdir -p "$root/.agents/skills/review-code"
  printf 'mine\n' >"$root/.agents/skills/review-code/mine.txt"
  run 1 "$shell" "$install" --target codex --user-home "$root"
  output_has "Collision detected."
  run 1 "$shell" "$install" --target codex --user-home "$root" --overwrite
  output_has "Refusing to overwrite destination path(s) that are not identified"
  same_text ".agents/skills/review-code/mine.txt" "$(files_in "$root")" "an unmanaged path was touched"
  run 0 "$shell" "$install" --target codex --user-home "$root" --overwrite --force-overwrite-unmanaged
  check_destination "$root/.agents/skills"
  passed

  begin "a skill the receipt does not list counts as unmanaged"
  rm -r "$root/.agents/skills/review-code"
  sed '/"review-code"/d' "$root/.agents/skills/$receipt_name" >"$work/receipt.tmp"
  cp "$work/receipt.tmp" "$root/.agents/skills/$receipt_name"
  mkdir "$root/.agents/skills/review-code"
  printf 'mine\n' >"$root/.agents/skills/review-code/mine.txt"
  run 1 "$shell" "$install" --target codex --user-home "$root" --overwrite
  output_has "Refusing to overwrite"
  output_has "$root/.agents/skills/review-code"
  must_exist "$root/.agents/skills/review-code/mine.txt"
  passed

  begin "a malformed receipt is refused by both scripts"
  root="$base/malformed"
  mkdir -p "$root/.agents/skills"
  printf '{ "collection": "ai-engineering-skills", "skills": [\n' >"$root/.agents/skills/$receipt_name"
  run 1 "$shell" "$install" --target codex --user-home "$root" --overwrite
  output_has "Refusing to overwrite"
  output_has "$root/.agents/skills/$receipt_name"
  run 1 "$shell" "$uninstall" --target codex --user-home "$root"
  output_has "invalid JSON"
  printf '{ "collection": "something-else", "skills": ["review-code"] }\n' >"$root/.agents/skills/$receipt_name"
  mkdir "$root/.agents/skills/review-code"
  run 1 "$shell" "$uninstall" --target codex --user-home "$root"
  output_has "does not identify ai-engineering-skills"
  printf '{ "collection": "ai-engineering-skills", "skills": "review-code" }\n' >"$root/.agents/skills/$receipt_name"
  run 1 "$shell" "$uninstall" --target codex --user-home "$root"
  output_has "has no skills list"
  must_exist "$root/.agents/skills/review-code"
  passed

  begin "a receipt cannot name a path outside its folder"
  root="$base/unsafe"
  mkdir -p "$root/.agents/skills" "$root/.agents/precious"
  printf 'keep\n' >"$root/.agents/precious/keep.txt"
  printf '{ "collection": "ai-engineering-skills", "skills": ["../precious"] }\n' >"$root/.agents/skills/$receipt_name"
  run 1 "$shell" "$uninstall" --target codex --user-home "$root"
  output_has "unsafe skill name '../precious'"
  run 1 "$shell" "$install" --target codex --user-home "$root" --overwrite
  output_has "unsafe skill name: '../precious'"
  must_exist "$root/.agents/precious/keep.txt"
  passed

  begin "a failed install is rolled back"
  root="$base/rollback"
  run 1 "$shell" "$install" --target codex --user-home "$root" --test-fail-after-operation 3
  output_has "Installation transaction failed and was rolled back: Injected installer failure after operation 3."
  same_text "" "$(files_in "$root")" "a failed first install left files"
  run 0 "$shell" "$install" --target codex --user-home "$root"
  printf 'old\n' >"$root/.agents/skills/review-code/old.md"
  before=$(listing "$root")
  run 1 "$shell" "$install" --target codex --user-home "$root" --overwrite --test-fail-after-operation 5
  output_has "rolled back"
  same_text "$before" "$(listing "$root")" "the rollback did not restore the old installation"
  passed

  begin "a failed uninstall is rolled back"
  run 1 "$shell" "$uninstall" --target codex --user-home "$root" --test-fail-after-move 4
  output_has "Uninstall transaction failed and was rolled back: Injected uninstaller failure after move 4."
  same_text "$before" "$(listing "$root")" "the rollback did not restore the installation"
  passed

  begin "a skill retired from the collection is removed"
  rm "$root/.agents/skills/review-code/old.md"
  mkdir "$root/.agents/skills/retired-skill" "$root/.agents/skills/kept-skill"
  printf 'old\n' >"$root/.agents/skills/retired-skill/SKILL.md"
  printf 'mine\n' >"$root/.agents/skills/kept-skill/SKILL.md"
  sed 's/"review-code"/"review-code", "retired-skill"/' "$root/.agents/skills/$receipt_name" >"$work/receipt.tmp"
  cp "$work/receipt.tmp" "$root/.agents/skills/$receipt_name"
  run 0 "$shell" "$install" --target codex --user-home "$root" --overwrite
  must_not_exist "$root/.agents/skills/retired-skill"
  must_exist "$root/.agents/skills/kept-skill/SKILL.md"
  if grep -F -q "retired-skill" "$root/.agents/skills/$receipt_name"; then flunk "the new receipt lists a retired skill"; fi
  passed

  begin "the legacy Antigravity folder is migrated"
  root="$base/legacy-antigravity"
  legacy="$root/.gemini/antigravity/skills"
  mkdir -p "$legacy/review-code" "$legacy/someone-else"
  printf 'old\n' >"$legacy/review-code/SKILL.md"
  printf 'keep\n' >"$legacy/someone-else/SKILL.md"
  write_powershell_receipt "$legacy/$receipt_name" "review-code"
  run 1 "$shell" "$install" --target antigravity --user-home "$root"
  output_has "legacy path"
  must_exist "$legacy/review-code/SKILL.md"
  run 0 "$shell" "$install" --target antigravity --user-home "$root" --overwrite
  output_has "Migrated managed Antigravity skills from $legacy"
  must_not_exist "$legacy/review-code"
  must_not_exist "$legacy/$receipt_name"
  must_exist "$legacy/someone-else/SKILL.md"
  check_destination "$root/.gemini/config/skills"
  passed

  begin "the old nested Claude Code folder is replaced and uninstalled"
  root="$base/legacy-claude"
  nested="$root/.claude/skills/ai-engineering-skills"
  mkdir -p "$nested/skills/review-code"
  printf 'old\n' >"$nested/skills/review-code/SKILL.md"
  write_powershell_receipt "$nested/$receipt_name" "review-code"
  run 1 "$shell" "$install" --target claude --user-home "$root"
  output_has "old nested layout"
  must_exist "$nested/skills/review-code/SKILL.md"
  run 0 "$shell" "$install" --target claude --user-home "$root" --overwrite
  output_has "Removed the old nested Claude Code installation at $nested"
  must_not_exist "$nested"
  check_destination "$root/.claude/skills"
  mkdir -p "$nested/skills/review-code"
  write_powershell_receipt "$nested/$receipt_name" "review-code"
  run 0 "$shell" "$uninstall" --target claude --user-home "$root"
  same_text "" "$(files_in "$root")" "the uninstall left the nested folder or the skills"
  passed

  rm -rf -- "$base"
}

# Compares with the PowerShell scripts: same files for the same inputs, and each side reads the
# other's receipt. Every call names its folder, because PowerShell prefers USERPROFILE over HOME.
powershell_path() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s\n' "$1"; fi
}

run_powershell_comparison() {
  base="$work/powershell"
  mkdir -p "$base/project-ps" "$base/project-sh"
  ps_install=$(powershell_path "$script_dir/install-skills.ps1")
  ps_uninstall=$(powershell_path "$script_dir/uninstall-skills.ps1")

  begin "same files as the PowerShell installer, user scope"
  run 0 "$powershell" -NoProfile -File "$ps_install" -Target Universal -Scope User -UserHome "$(powershell_path "$base/home-ps")"
  run 0 "$shell" "$install" --target universal --scope user --user-home "$base/home-sh"
  same_text "$(files_in "$base/home-ps")" "$(files_in "$base/home-sh")" "the file lists differ"
  diff -r -x "$receipt_name" "$base/home-ps" "$base/home-sh" >&2 || flunk "the file contents differ"
  passed

  begin "same files as the PowerShell installer, project scope"
  run 0 "$powershell" -NoProfile -File "$ps_install" -Target Universal -Scope Project -ProjectRoot "$(powershell_path "$base/project-ps")"
  run 0 "$shell" "$install" --target universal --scope project --project-root "$base/project-sh"
  same_text "$(files_in "$base/project-ps")" "$(files_in "$base/project-sh")" "the file lists differ"
  passed

  begin "PowerShell updates and removes an installation made by sh"
  run 0 "$powershell" -NoProfile -File "$ps_install" -Target Universal -Scope User -UserHome "$(powershell_path "$base/home-sh")" -Overwrite
  check_destination "$base/home-sh/.claude/skills"
  run 0 "$shell" "$install" --user-home "$base/home-sh" --overwrite
  run 0 "$powershell" -NoProfile -File "$ps_uninstall" -Target Universal -Scope User -UserHome "$(powershell_path "$base/home-sh")"
  same_text "" "$(files_in "$base/home-sh")" "PowerShell left files of an sh installation"
  passed

  begin "sh updates and removes an installation made by PowerShell"
  run 0 "$shell" "$install" --user-home "$base/home-ps" --overwrite
  check_destination "$base/home-ps/.agents/skills"
  run 0 "$powershell" -NoProfile -File "$ps_install" -Target Universal -Scope User -UserHome "$(powershell_path "$base/home-ps")" -Overwrite
  run 0 "$shell" "$uninstall" --user-home "$base/home-ps"
  same_text "" "$(files_in "$base/home-ps")" "sh left files of a PowerShell installation"
  run 0 "$shell" "$uninstall" --scope project --project-root "$base/project-ps"
  same_text "" "$(files_in "$base/project-ps")" "sh left files of a PowerShell project installation"
  passed

  rm -rf -- "$base"
}

shells=""
for candidate in ${TEST_SHELLS:-sh bash dash}; do
  if command -v "$candidate" >/dev/null 2>&1; then shells="$shells $candidate"; fi
done
[ -n "$shells" ] || {
  printf 'None of the shells to test is installed.\n' >&2
  exit 1
}

for candidate in $shells; do
  run_suite "$candidate"
done

powershell=""
for candidate in pwsh powershell; do
  if command -v "$candidate" >/dev/null 2>&1; then
    powershell=$candidate
    break
  fi
done
if [ -n "$powershell" ]; then
  shell=${shells# }
  shell=${shell%% *}
  run_powershell_comparison
  comparison="compared with $powershell"
else
  comparison="PowerShell comparison skipped: neither pwsh nor powershell is installed"
fi

printf 'POSIX installer checks passed: %s checks, shells:%s, %s.\n' "$checks" "$shells" "$comparison"
