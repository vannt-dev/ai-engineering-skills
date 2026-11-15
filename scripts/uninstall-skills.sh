#!/usr/bin/env sh
# Removes an installation made by install-skills.sh or install-skills.ps1 on macOS and Linux.
# The counterpart of uninstall-skills.ps1: it removes only paths named by a valid collection receipt.
# POSIX sh only, tested with dash and with bash 3.2 and later; needs awk, mv, rm, date.
set -eu

collection="ai-engineering-skills"
receipt_name=".ai-engineering-skills.receipt.json"

usage() {
  cat <<'EOF'
Usage: uninstall-skills.sh [options]

Removes the skills and the receipt that the installer put in the selected tools' folders.
Other skills and files in those folders are left alone.

Options:
  --target NAME          codex, claude, opencode, antigravity or universal (default: universal)
  --scope NAME           user or project (default: user)
  --project-root PATH    existing project directory; required with --scope project
  --user-home PATH       home directory to uninstall from (default: $HOME)
  --dry-run              list what would be removed and remove nothing
  -h, --help             show this help
EOF
}

fail() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

usage_error() {
  printf 'Error: %s\n' "$1" >&2
  printf 'Run with --help for the list of options.\n' >&2
  exit 2
}

lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

exists() {
  [ -e "$1" ] || [ -L "$1" ]
}

absolute_path() {
  case $1 in
  /* | [A-Za-z]:[\\/]*) abs=$1 ;;
  *) abs=$PWD/$1 ;;
  esac
  while [ "${abs%/}" != "$abs" ] && [ -n "${abs%/}" ]; do abs=${abs%/}; done
  printf '%s\n' "$abs"
}

target="universal"
scope="user"
project_root=""
user_home=""
dry_run=0
# Deterministic fault injection used only by the repository's rollback test.
fail_after=0

while [ $# -gt 0 ]; do
  case $1 in
  --target | --scope | --project-root | --user-home | --test-fail-after-move)
    [ $# -ge 2 ] || usage_error "Option $1 needs a value."
    option=$1
    value=$2
    shift 2
    ;;
  --target=* | --scope=* | --project-root=* | --user-home=* | --test-fail-after-move=*)
    option=${1%%=*}
    value=${1#*=}
    shift
    ;;
  --dry-run)
    dry_run=1
    shift
    continue
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *) usage_error "Unknown option: $1" ;;
  esac
  case $option in
  --target) target=$value ;;
  --scope) scope=$value ;;
  --project-root) project_root=$value ;;
  --user-home) user_home=$value ;;
  --test-fail-after-move) fail_after=$value ;;
  esac
done

case $(lower "$target") in
codex) target="Codex" ;;
claude) target="Claude" ;;
opencode) target="OpenCode" ;;
antigravity) target="Antigravity" ;;
universal) target="Universal" ;;
*) usage_error "Unknown target '$target'. Use codex, claude, opencode, antigravity or universal." ;;
esac

case $(lower "$scope") in
user) scope="User" ;;
project) scope="Project" ;;
*) usage_error "Unknown scope '$scope'. Use user or project." ;;
esac

case $fail_after in
"" | *[!0-9]*) usage_error "--test-fail-after-move needs a whole number." ;;
esac

if [ "$scope" = "User" ]; then
  if [ -z "$user_home" ]; then
    user_home=${HOME:-}
    [ -n "$user_home" ] || fail "Could not determine the user home directory. Specify --user-home."
  fi
  root=$(absolute_path "$user_home")
else
  if [ -z "$project_root" ] || [ ! -d "$project_root" ]; then
    fail "--project-root must name an existing directory when the scope is project."
  fi
  root=$(CDPATH='' cd -- "$project_root" && pwd)
fi
case $root in
*"
"*) fail "The installation root must not contain a line break." ;;
esac

# Destinations are "flat <path>" or "nested <path>", one per line.
destinations=""
add_flat() {
  destinations="${destinations}flat $1
"
}
# Claude Code skills are flat in .claude/skills. Up to 1.3.0 the Claude and Universal targets put them in a
# nested plugin, .claude/skills/ai-engineering-skills; it is removed too when its receipt is there.
add_claude() {
  add_flat "$1"
  destinations="${destinations}nested $1/$collection
"
}

if [ "$scope" = "User" ]; then
  case $target in
  Codex) add_flat "$root/.agents/skills" ;;
  Claude) add_claude "$root/.claude/skills" ;;
  OpenCode) add_flat "$root/.config/opencode/skills" ;;
  Antigravity) add_flat "$root/.gemini/config/skills" ;;
  Universal)
    add_flat "$root/.agents/skills"
    add_claude "$root/.claude/skills"
    add_flat "$root/.gemini/config/skills"
    ;;
  esac
else
  case $target in
  Codex) add_flat "$root/.agents/skills" ;;
  Claude) add_claude "$root/.claude/skills" ;;
  OpenCode) add_flat "$root/.opencode/skills" ;;
  Antigravity) add_flat "$root/.agents/skills" ;;
  Universal)
    add_flat "$root/.agents/skills"
    add_claude "$root/.claude/skills"
    ;;
  esac
fi

# Reads a receipt written by either installer. Prints the skill names, one per line. Exit codes:
# 10 not a JSON object, 11 another collection, 12 no skills list, 13 an unsafe name (printed).
# shellcheck disable=SC2016
receipt_reader='
  { text = text $0 "\n" }
  END {
    gsub(/\r/, "", text)
    if (substr(text, 1, 3) == "\357\273\277") text = substr(text, 4)
    sub(/^[ \t\n]+/, "", text)
    sub(/[ \t\n]+$/, "", text)
    if (substr(text, 1, 1) != "{" || substr(text, length(text), 1) != "}") exit 10
    if (!match(text, /"collection"[ \t\n]*:[ \t\n]*"ai-engineering-skills"/)) exit 11
    if (!match(text, /"skills"[ \t\n]*:[ \t\n]*\[/)) exit 12
    body = substr(text, RSTART + RLENGTH)
    list_end = index(body, "]")
    if (list_end == 0) exit 12
    body = substr(body, 1, list_end - 1)
    sub(/^[ \t\n]+/, "", body)
    sub(/[ \t\n]+$/, "", body)
    if (body == "") exit 0
    # The awk of macOS splits at every line break as well as at the separator, so the line
    # breaks go first.
    gsub(/\n/, " ", body)
    count = split(body, items, ",")
    names = ""
    for (i = 1; i <= count; i++) {
      item = items[i]
      sub(/^[ \t\n]+/, "", item)
      sub(/[ \t\n]+$/, "", item)
      if (item !~ /^"[^"]*"$/) exit 12
      name = substr(item, 2, length(item) - 2)
      if (name !~ /^[a-z0-9]+(-[a-z0-9]+)*$/) {
        print name
        exit 13
      }
      names = names name "\n"
    }
    printf "%s", names
  }
'

# Sets receipt_found and receipt_skills, or stops: a receipt that cannot be trusted removes nothing.
read_receipt() {
  receipt_found=0
  receipt_skills=""
  [ -f "$1" ] || return 0
  if receipt_skills=$(LC_ALL=C awk "$receipt_reader" "$1"); then
    receipt_found=1
    return 0
  else
    reader_status=$?
  fi
  case $reader_status in
  10) fail "Refusing to uninstall because receipt is invalid JSON: '$1'" ;;
  11) fail "Refusing to uninstall because receipt does not identify ai-engineering-skills: '$1'" ;;
  13) fail "Receipt '$1' contains unsafe skill name '$receipt_skills'." ;;
  *) fail "Refusing to uninstall because receipt has no skills list: '$1'" ;;
  esac
}

# Preflight every receipt and build the complete removal plan before changing disk.
removals=""
removal_count=0
add_removal() {
  removals="${removals}$1
"
  removal_count=$((removal_count + 1))
}

# Lists are split into the positional parameters, one line each, so a path with spaces stays one
# item. A here-document is not used: some builds of dash drop one larger than a pipe buffer.
split_lines() {
  IFS='
'
  set -f
}
split_done() {
  set +f
  IFS=$saved_ifs
}
saved_ifs=$IFS

split_lines
# shellcheck disable=SC2086
set -- $destinations
split_done

for entry in "$@"; do
  kind=${entry%% *}
  dest=${entry#* }
  receipt_path="$dest/$receipt_name"
  read_receipt "$receipt_path"
  if [ "$receipt_found" -eq 0 ]; then
    if [ "$kind" = "flat" ]; then
      printf "Warning: No managed installation receipt found at '%s'; nothing will be removed there.\n" "$receipt_path" >&2
    fi
    continue
  fi
  if [ "$kind" = "nested" ]; then
    add_removal "$dest"
    continue
  fi
  # The reader accepts only lowercase letters, digits and single hyphens, so a name stays inside dest.
  for name in $receipt_skills; do
    if exists "$dest/$name"; then add_removal "$dest/$name"; fi
  done
  add_removal "$receipt_path"
done

if [ "$removal_count" -eq 0 ]; then
  printf 'No managed ai-engineering-skills installation found for the selected target and scope.\n'
  exit 0
fi

split_lines
# shellcheck disable=SC2086
set -- $removals
split_done

if [ "$dry_run" -eq 1 ]; then
  for path in "$@"; do
    printf 'Dry run: Uninstall receipt-managed content: %s\n' "$path"
  done
  printf 'Dry run: nothing was changed.\n'
  exit 0
fi

# Move everything into quarantine beside its place first; only when every move worked is it deleted.
transaction_id="$(date -u +%Y%m%d%H%M%S)-$$"
suffix=".ai-engineering-skills-uninstall-$transaction_id"
moved_count=0
transaction_open=0
transaction_error=""

# Puts every quarantined path back in its place.
roll_back() {
  for path in "$@"; do
    if exists "$path$suffix" && ! exists "$path"; then
      mv -- "$path$suffix" "$path" || true
    fi
  done
}

clean_up() {
  if [ "$transaction_open" -eq 1 ]; then
    transaction_open=0
    roll_back "$@"
  fi
}
trap 'clean_up "$@"' EXIT
trap 'exit 130' INT
trap 'exit 143' HUP TERM

# set -e does not reach into a function called from a condition, so every step is checked here.
quarantine_all() {
  for path in "$@"; do
    exists "$path" || continue
    if exists "$path$suffix"; then
      transaction_error="The quarantine path already exists: $path$suffix"
      return 1
    fi
    mv -- "$path" "$path$suffix" || return 1
    moved_count=$((moved_count + 1))
    if [ "$fail_after" -gt 0 ] && [ "$moved_count" -eq "$fail_after" ]; then
      transaction_error="Injected uninstaller failure after move $moved_count."
      return 1
    fi
  done
}

transaction_open=1
if ! quarantine_all "$@"; then
  transaction_open=0
  roll_back "$@"
  fail "Uninstall transaction failed and was rolled back: ${transaction_error:-a file operation failed; see the message above.}"
fi
transaction_open=0

for path in "$@"; do
  # Only the quarantine names made above are deleted, never a destination folder itself.
  if exists "$path$suffix"; then
    rm -rf -- "$path$suffix" ||
      printf "Warning: Content was uninstalled but quarantine cleanup failed for '%s'.\n" "$path$suffix" >&2
  fi
done

printf 'Removed %s receipt-managed path(s); unrelated content was preserved.\n' "$moved_count"
