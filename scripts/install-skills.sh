#!/usr/bin/env sh
# Installs the skill collection on macOS and Linux without PowerShell.
# The counterpart of install-skills.ps1: same destinations, receipt, collision rules and rollback.
# POSIX sh only (dash, bash 3.2 and later, busybox ash); needs awk, cp, mv, rm, mkdir, date, mktemp.
set -eu

collection="ai-engineering-skills"
receipt_name=".ai-engineering-skills.receipt.json"

usage() {
  cat <<'EOF'
Usage: install-skills.sh [options]

Copies the skills listed in skillset.json into the folders the selected tools read.

Options:
  --target NAME                 codex, claude, opencode, antigravity or universal (default: universal)
  --scope NAME                  user or project (default: user)
  --project-root PATH           existing project directory; required with --scope project
  --user-home PATH              home directory to install into (default: $HOME)
  --overwrite                   replace an installation identified by a collection receipt
  --force-overwrite-unmanaged   with --overwrite, also replace colliding paths that have no receipt
  --dry-run                     list what would change and change nothing
  -h, --help                    show this help

Every destination is committed as one transaction; an error restores the previous installation.
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

# True when $1 is a line of the newline-separated list $2.
in_list() {
  case "
$2
" in
  *"
$1
"*) return 0 ;;
  esac
  return 1
}

absolute_path() {
  case $1 in
  /* | [A-Za-z]:[\\/]*) abs=$1 ;;
  *) abs=$PWD/$1 ;;
  esac
  while [ "${abs%/}" != "$abs" ] && [ -n "${abs%/}" ]; do abs=${abs%/}; done
  printf '%s\n' "$abs"
}

# Deletes one path the installer placed or moved aside. Never called with a destination root.
remove_tree() {
  case $1 in
  "" | /) return 1 ;;
  esac
  rm -rf -- "$1"
}

target="universal"
scope="user"
project_root=""
user_home=""
overwrite=0
force_unmanaged=0
dry_run=0
# Deterministic fault injection used only by the repository's rollback test.
fail_after=0

while [ $# -gt 0 ]; do
  case $1 in
  --target | --scope | --project-root | --user-home | --test-fail-after-operation)
    [ $# -ge 2 ] || usage_error "Option $1 needs a value."
    option=$1
    value=$2
    shift 2
    ;;
  --target=* | --scope=* | --project-root=* | --user-home=* | --test-fail-after-operation=*)
    option=${1%%=*}
    value=${1#*=}
    shift
    ;;
  --overwrite)
    overwrite=1
    shift
    continue
    ;;
  --force-overwrite-unmanaged)
    force_unmanaged=1
    shift
    continue
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
  --test-fail-after-operation) fail_after=$value ;;
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
"" | *[!0-9]*) usage_error "--test-fail-after-operation needs a whole number." ;;
esac

if [ "$force_unmanaged" -eq 1 ] && [ "$overwrite" -eq 0 ]; then
  fail "--force-overwrite-unmanaged requires --overwrite."
fi

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
collection_root=${script_dir%/*}
manifest_path="$collection_root/skillset.json"
skills_source_root="$collection_root/skills"

# 1. Read the manifest and check the payload. The PowerShell installer runs validate-skills.ps1 here;
# this script checks only what it copies: safe unique names and a SKILL.md for each skill.
[ -f "$manifest_path" ] || fail "skillset.json not found: $manifest_path"

# skillset.json is small and has one shape: a top-level "version" and a "skills" array of objects,
# each with a "name". awk reads those two things, so no JSON tool is needed.
if ! manifest_data=$(
  LC_ALL=C awk '
    { text = text $0 "\n" }
    END {
      if (match(text, /"version"[ \t\r\n]*:[ \t\r\n]*"[^"]*"/)) {
        value = substr(text, RSTART, RLENGTH)
        sub(/"$/, "", value)
        sub(/^.*"/, "", value)
        print "version=" value
      }
      if (!match(text, /"skills"[ \t\r\n]*:[ \t\r\n]*\[/)) exit 10
      rest = substr(text, RSTART + RLENGTH)
      while (match(rest, /"name"[ \t\r\n]*:[ \t\r\n]*"[^"]*"/)) {
        value = substr(rest, RSTART, RLENGTH)
        rest = substr(rest, RSTART + RLENGTH)
        sub(/"$/, "", value)
        sub(/^.*"/, "", value)
        print "skill=" value
      }
    }
  ' "$manifest_path"
); then
  fail "skillset.json has no skills list: $manifest_path"
fi

manifest_version=""
skill_names=""
skill_count=0
# Word splitting is safe here: a value with a space or a glob character fails the checks below.
set -f
for entry in $manifest_data; do
  case $entry in
  version=*) manifest_version=${entry#version=} ;;
  skill=*)
    name=${entry#skill=}
    case $name in
    "" | *[!a-z0-9-]* | -* | *- | *--*) fail "skillset.json contains an unsafe skill name: '$name'" ;;
    esac
    if in_list "$name" "$skill_names"; then
      fail "skillset.json lists the skill '$name' twice."
    fi
    [ -f "$skills_source_root/$name/SKILL.md" ] || fail "Skill '$name' has no SKILL.md in $skills_source_root."
    if [ -n "$skill_names" ]; then
      skill_names="$skill_names
$name"
    else
      skill_names=$name
    fi
    skill_count=$((skill_count + 1))
    ;;
  *) fail "skillset.json has a version or a skill name that cannot be used: '$entry'" ;;
  esac
done
set +f

[ "$skill_count" -gt 0 ] || fail "skillset.json lists no skills: $manifest_path"
case $manifest_version in
"" | *[!0-9A-Za-z.+-]*) fail "skillset.json has no usable version: $manifest_path" ;;
esac

# 2. Resolve only the root required by the selected scope
if [ "$scope" = "User" ]; then
  if [ -z "$user_home" ]; then
    user_home=${HOME:-}
    [ -n "$user_home" ] || fail "Could not determine the user home directory. Specify --user-home."
  fi
  root=$(absolute_path "$user_home")
else
  [ -n "$project_root" ] || fail "--project-root is required when the scope is project."
  [ -d "$project_root" ] || fail "The project root directory does not exist: $project_root"
  root=$(CDPATH='' cd -- "$project_root" && pwd)
fi
case $root in
*"
"*) fail "The installation root must not contain a line break." ;;
esac

# 3. Plan destinations
# Every destination is flat: <dest>/<skill-name>/SKILL.md and a receipt in <dest>.
# The destinations become the positional parameters, so a path with spaces stays one item.
if [ "$scope" = "User" ]; then
  case $target in
  Codex) set -- "$root/.agents/skills" ;;
  Claude) set -- "$root/.claude/skills" ;;
  OpenCode) set -- "$root/.config/opencode/skills" ;;
  Antigravity) set -- "$root/.gemini/config/skills" ;;
  Universal)
    # Canonical .agents/skills (Codex, OpenCode, Antigravity project), Claude Code, Antigravity global
    set -- "$root/.agents/skills" "$root/.claude/skills" "$root/.gemini/config/skills"
    ;;
  esac
else
  case $target in
  Codex) set -- "$root/.agents/skills" ;;
  Claude) set -- "$root/.claude/skills" ;;
  OpenCode) set -- "$root/.opencode/skills" ;;
  Antigravity) set -- "$root/.agents/skills" ;;
  Universal) set -- "$root/.agents/skills" "$root/.claude/skills" ;;
  esac
fi

# 4. Preflight collision and ownership detection

# Reads a receipt written by either installer. Prints the skill names, one per line. Exit codes:
# 10 not a JSON object, 11 another collection, 12 no skills list, 13 an unsafe name (printed).
# Anything the pattern does not recognise counts as not managed.
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

# Sets receipt_state to missing, managed, unmanaged or unsafe, and receipt_skills to the names.
read_receipt() {
  receipt_skills=""
  if [ ! -f "$1" ]; then
    if exists "$1"; then receipt_state="unmanaged"; else receipt_state="missing"; fi
    return 0
  fi
  if receipt_skills=$(LC_ALL=C awk "$receipt_reader" "$1"); then
    receipt_state="managed"
  elif [ $? -eq 13 ]; then
    receipt_state="unsafe"
  else
    receipt_state="unmanaged"
    receipt_skills=""
  fi
}

legacy_antigravity_root=""
legacy_antigravity_skills=""
migrate_antigravity=0
if [ "$scope" = "User" ]; then
  case $target in
  Antigravity | Universal)
    legacy_antigravity_root="$root/.gemini/antigravity/skills"
    read_receipt "$legacy_antigravity_root/$receipt_name"
    case $receipt_state in
    unsafe) fail "Legacy receipt contains an unsafe skill name: '$receipt_skills'" ;;
    managed)
      [ "$overwrite" -eq 1 ] || fail "A managed Antigravity installation exists at the legacy path '$legacy_antigravity_root'. Re-run with --overwrite to migrate it to .gemini/config/skills."
      legacy_antigravity_skills=$receipt_skills
      migrate_antigravity=1
      ;;
    esac
    ;;
  esac
fi

# Up to 1.3.0 the installer put Claude Code skills in a nested plugin, .claude/skills/ai-engineering-skills,
# a layout Claude Code does not load. --overwrite replaces it with the flat layout.
legacy_claude_plugin=""
case $target in
Claude | Universal)
  legacy_candidate="$root/.claude/skills/$collection"
  read_receipt "$legacy_candidate/$receipt_name"
  case $receipt_state in
  managed | unsafe)
    [ "$overwrite" -eq 1 ] || fail "A managed Claude Code installation in the old nested layout exists at '$legacy_candidate', and Claude Code does not load skills from it. Re-run with --overwrite to remove it."
    legacy_claude_plugin=$legacy_candidate
    ;;
  esac
  ;;
esac

collisions=""
unmanaged_collisions=""
collision_count=0
unmanaged_count=0
add_collision() {
  collisions="$collisions
$1"
  collision_count=$((collision_count + 1))
}
add_unmanaged_collision() {
  unmanaged_collisions="$unmanaged_collisions
$1"
  unmanaged_count=$((unmanaged_count + 1))
}

for dest in "$@"; do
  receipt_path="$dest/$receipt_name"
  read_receipt "$receipt_path"
  case $receipt_state in
  unsafe) fail "Receipt '$receipt_path' contains an unsafe skill name: '$receipt_skills'" ;;
  unmanaged)
    add_collision "$receipt_path"
    add_unmanaged_collision "$receipt_path"
    ;;
  esac
  for name in $skill_names; do
    if exists "$dest/$name"; then
      add_collision "$dest/$name"
      in_list "$name" "$receipt_skills" || add_unmanaged_collision "$dest/$name"
    fi
  done
done

if [ "$collision_count" -gt 0 ] && [ "$overwrite" -eq 0 ]; then
  fail "Collision detected. The following destination path(s) already exist:$collisions
Use --overwrite to replace managed skill directories."
fi

if [ "$unmanaged_count" -gt 0 ] && [ "$force_unmanaged" -eq 0 ]; then
  fail "Refusing to overwrite destination path(s) that are not identified by an ai-engineering-skills receipt:$unmanaged_collisions
Use --force-overwrite-unmanaged together with --overwrite only after verifying these paths."
fi

# 5. Stage the complete payload before changing any destination
stage=""
operations=""
applied=""
transaction_open=0
transaction_error=""
transaction_id="$(date -u +%Y%m%d%H%M%S)-$$"

# Puts back whatever the transaction moved aside, newest first.
roll_back() {
  if [ -z "$applied" ] || [ ! -f "$applied" ]; then return 0; fi
  awk '{ line[NR] = $0 } END { for (i = NR - 1; i >= 1; i -= 2) { print line[i]; print line[i + 1] } }' "$applied" |
    while IFS= read -r done_target && IFS= read -r done_backup; do
      if exists "$done_target"; then remove_tree "$done_target" || true; fi
      if [ "$done_backup" != "-" ] && exists "$done_backup"; then
        mv -- "$done_backup" "$done_target" || true
      fi
    done
}

clean_up() {
  if [ "$transaction_open" -eq 1 ]; then
    transaction_open=0
    roll_back
  fi
  if [ -n "$stage" ] && [ -d "$stage" ]; then rm -rf -- "$stage"; fi
}
trap clean_up EXIT
trap 'exit 130' INT
trap 'exit 143' HUP TERM

# An operation is a target and what to put there: a path inside the stage folder, or "-" to only remove.
add_operation() {
  if [ "$dry_run" -eq 1 ]; then
    printf 'Dry run: %s: %s\n' "$3" "$1"
  else
    printf '%s\n%s\n' "$2" "$1" >>"$operations"
  fi
}

if [ "$dry_run" -eq 0 ]; then
  stage=$(mktemp -d "${TMPDIR:-/tmp}/ai-engineering-skills-stage-XXXXXX")
  operations="$stage/operations"
  applied="$stage/applied"
  : >"$operations"
  : >"$applied"

  # The payload is the same for every destination, so it is staged once.
  mkdir -p -- "$stage/skills"
  for name in $skill_names; do
    mkdir -- "$stage/skills/$name"
    cp -R -- "$skills_source_root/$name/." "$stage/skills/$name/"
    [ -f "$stage/skills/$name/SKILL.md" ] || fail "Staging verification failed for skill '$name'."
  done

  {
    printf '{\n'
    printf '  "schemaVersion": 1,\n'
    printf '  "collection": "%s",\n' "$collection"
    printf '  "version": "%s",\n' "$manifest_version"
    printf '  "target": "%s",\n' "$target"
    printf '  "scope": "%s",\n' "$scope"
    printf '  "installedAt": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '  "skills": [\n'
    separator=""
    for name in $skill_names; do
      printf '%s    "%s"' "$separator" "$name"
      separator=",
"
    done
    printf '\n  ]\n}\n'
  } >"$stage/receipt.json"
fi

for dest in "$@"; do
  read_receipt "$dest/$receipt_name"
  if [ "$receipt_state" = "managed" ] && [ -n "$receipt_skills" ]; then
    for name in $receipt_skills; do
      in_list "$name" "$skill_names" || add_operation "$dest/$name" "-" "Remove retired managed skill '$name'"
    done
  fi
  for name in $skill_names; do
    add_operation "$dest/$name" "skills/$name" "Install skill '$name'"
  done
  add_operation "$dest/$receipt_name" "receipt.json" "Write installation receipt"
done

if [ -n "$legacy_claude_plugin" ]; then
  add_operation "$legacy_claude_plugin" "-" "Remove the old nested Claude Code installation"
fi

if [ "$migrate_antigravity" -eq 1 ]; then
  if [ -n "$legacy_antigravity_skills" ]; then
    for name in $legacy_antigravity_skills; do
      add_operation "$legacy_antigravity_root/$name" "-" "Remove managed skill from legacy Antigravity location"
    done
  fi
  add_operation "$legacy_antigravity_root/$receipt_name" "-" "Remove legacy Antigravity receipt"
fi

if [ "$dry_run" -eq 1 ]; then
  printf 'Dry run: nothing was changed.\n'
  exit 0
fi

# 6. Commit. Backups live beside their targets so rename and restore stay on the same volume.
# set -e does not reach into a function called from a condition, so every step is checked here.
apply_transaction() {
  # Phase one: move every old target aside before installing any new payload.
  while IFS= read -r staged && IFS= read -r target_path; do
    parent=${target_path%/*}
    if [ ! -d "$parent" ]; then
      mkdir -p -- "$parent" || return 1
    fi
    backup="$target_path.ai-engineering-skills-backup-$transaction_id"
    if exists "$target_path"; then
      if exists "$backup"; then
        transaction_error="The backup path already exists: $backup"
        return 1
      fi
      mv -- "$target_path" "$backup" || return 1
      printf '%s\n%s\n' "$target_path" "$backup" >>"$applied" || return 1
    else
      printf '%s\n-\n' "$target_path" >>"$applied" || return 1
    fi
  done <"$operations"

  # Phase two: put the staged payloads in place. Remove-only operations have no source.
  operation_count=0
  while IFS= read -r staged && IFS= read -r target_path; do
    if [ "$staged" != "-" ]; then
      if exists "$target_path"; then
        transaction_error="The target appeared during the installation: $target_path"
        return 1
      fi
      cp -R -- "$stage/$staged" "$target_path" || return 1
    fi
    operation_count=$((operation_count + 1))
    if [ "$fail_after" -gt 0 ] && [ "$operation_count" -eq "$fail_after" ]; then
      transaction_error="Injected installer failure after operation $operation_count."
      return 1
    fi
  done <"$operations"
}

transaction_open=1
if ! apply_transaction; then
  transaction_open=0
  roll_back
  fail "Installation transaction failed and was rolled back: ${transaction_error:-a file operation failed; see the message above.}"
fi
transaction_open=0

while IFS= read -r done_target && IFS= read -r done_backup; do
  if [ "$done_backup" != "-" ] && exists "$done_backup"; then
    remove_tree "$done_backup" ||
      printf "Warning: Installed successfully, but could not remove backup '%s'.\n" "$done_backup" >&2
  fi
done <"$applied"

for dest in "$@"; do
  printf 'Installed %s canonical skills into %s\n' "$skill_count" "$dest"
done
if [ "$migrate_antigravity" -eq 1 ]; then
  printf 'Migrated managed Antigravity skills from %s\n' "$legacy_antigravity_root"
fi
if [ -n "$legacy_claude_plugin" ]; then
  printf 'Removed the old nested Claude Code installation at %s\n' "$legacy_claude_plugin"
fi
