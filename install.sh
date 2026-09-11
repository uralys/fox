#!/bin/sh
# -----------------------------------------------------------------------------
# Fox installer: one curl, and Fox is on your machine, both halves of it.
# -----------------------------------------------------------------------------
#   cd your-game
#   curl -fsSL https://raw.githubusercontent.com/uralys/fox/main/install.sh | sh
#
# Fox ships as two halves, and this script installs BOTH from the same git tag,
# so the executable and the tree a game mounts can never come from two different
# Fox:
#
#   - the runtime, mounted at `addons/fox` of the Godot project it is run from;
#   - the `fox` executable, installed globally with npm.
#
# The runtime is the half that matters: it is a plain Godot addon and needs
# nothing but Godot. The CLI needs NodeJS, and a machine without it is NOT a
# failed install: the addon is mounted all the same, and the CLI is skipped with
# a warning.
#
# Run outside a Godot project, the script installs the CLI alone and says so:
# `fox upgrade` mounts the runtime later, from inside the game.
#
#   curl -fsSL .../install.sh | sh -s -- 2.2.0        # a version, not the latest
#   curl -fsSL .../install.sh | sh -s -- your-game    # a project other than `.`
#   FOX_VERSION=2.2.0 sh install.sh
#
# POSIX sh on purpose: this runs on whatever shell a user pipes it into, macOS
# `sh`, Debian `dash` and Git Bash included.
# -----------------------------------------------------------------------------

set -eu

REPOSITORY='uralys/fox'
LATEST_RELEASE="https://api.github.com/repos/${REPOSITORY}/releases/latest"
DOCUMENTATION="https://github.com/${REPOSITORY}/blob/main/docs/install.md"
MINIMUM_NODE_MAJOR=26

ADDON_MOUNT='addons/fox'
GODOT_PROJECT='project.godot'
CONFIG_FILE='fox.config.json'
IGNORE_FILE='.gitignore'

# -----------------------------------------------------------------------------
# The tree the CLI itself prints, so the install reads like the commands that
# follow it. Colours are dropped when the output is not a terminal: a log file
# or a CI transcript keeps escape sequences forever.

if [ -t 1 ]; then
  BLUE=$(printf '\033[34m')
  GREEN=$(printf '\033[32m')
  YELLOW=$(printf '\033[33m')
  RED=$(printf '\033[31m')
  BOLD=$(printf '\033[1m')
  RESET=$(printf '\033[0m')
else
  BLUE='' GREEN='' YELLOW='' RED='' BOLD='' RESET=''
fi

title() { printf '%s\n' "${BLUE}${BOLD}● $1${RESET}"; }
step() { printf '%s\n' "├─ $1"; }
success() { printf '%s\n' "${GREEN}├─ ✔  $1${RESET}"; }
warn() { printf '%s\n' "${YELLOW}├─ ⚠  $1${RESET}"; }
done_() { printf '%s\n' "${GREEN}└─ $1${RESET}"; }

fail() {
  printf '%s\n' "${RED}└─ ✖  $1${RESET}" >&2
  exit 1
}

has() { command -v "$1" >/dev/null 2>&1; }

# -----------------------------------------------------------------------------
# One argument, two meanings, because a newcomer piping a script into `sh` is
# not going to read a flag table: anything starting with a digit (or a `v`) is a
# version, anything else is the project to mount the addon in.

VERSION_ARGUMENT=${FOX_VERSION:-}
PROJECT_ROOT=${FOX_PROJECT:-.}

for argument in "$@"; do
  case "${argument}" in
    v[0-9]* | [0-9]*) VERSION_ARGUMENT=${argument} ;;
    *) PROJECT_ROOT=${argument} ;;
  esac
done

# -----------------------------------------------------------------------------

fetch() {
  if has curl; then
    curl -fsSL "$1"
  elif has wget; then
    wget -qO- "$1"
  else
    fail 'curl or wget is required, and neither was found'
  fi
}

# -----------------------------------------------------------------------------
# core.fox: the version a game declares, in the config it already commits.
#
# `addons/fox` is a dependency and belongs in a `.gitignore`, which costs a game
# the only record of the version it runs, since that record is `plugin.cfg`
# INSIDE the mount. This pin is that record, and it is read and written here in
# sed and awk for the same reason the rest of this script is: it runs before Fox
# owns anything on the machine.

read_pin() {
  config="${PROJECT_ROOT}/${CONFIG_FILE}"

  [ -f "${config}" ] || return 0

  sed -n 's/.*"fox"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${config}" | head -n 1
}

write_pin() {
  version=$1
  config="${PROJECT_ROOT}/${CONFIG_FILE}"

  if [ ! -f "${config}" ]; then
    warn "no ${CONFIG_FILE} yet: add \"fox\": \"${version}\" to its \"core\" block once you write one"
    return 0
  fi

  current=$(read_pin)

  # An `&&` list would be the failing command `set -e` exits on when the two
  # versions differ, which is precisely the case this function exists for.
  if [ "${current}" = "${version}" ]; then
    return 0
  fi

  pinned="${config}.fox-pin"

  # Two passes rather than one: replacing a pin and inserting a missing one are
  # different edits, and deciding between them upfront keeps each awk readable.
  # Both stop at the first match, so a `"fox"` key living elsewhere in the
  # config is never the one rewritten.
  if [ -n "${current}" ]; then
    awk -v v="${version}" '
      !seen && /"fox"[[:space:]]*:[[:space:]]*"[^"]*"/ {
        sub(/"fox"[[:space:]]*:[[:space:]]*"[^"]*"/, "\"fox\": \"" v "\"")
        seen = 1
      }
      { print }
    ' "${config}" >"${pinned}"
  else
    awk -v v="${version}" '
      { print }
      !seen && /"core"[[:space:]]*:[[:space:]]*\{/ {
        print "    \"fox\": \"" v "\","
        seen = 1
      }
    ' "${config}" >"${pinned}"
  fi

  # An empty result means awk found nothing to work with: the config is left
  # exactly as it was, and the line to add by hand is printed instead.
  if [ ! -s "${pinned}" ] || ! grep -q '"fox"' "${pinned}"; then
    rm -f "${pinned}"
    warn "could not pin ${version} in ${CONFIG_FILE}: add \"fox\": \"${version}\" to its \"core\" block"
    return 0
  fi

  mv "${pinned}" "${config}"
  step "Pinned ${version} in ${CONFIG_FILE}"
}

# -----------------------------------------------------------------------------
# The mount is a dependency, and a game tracking it sees every upgrade as a wall
# of changes it never wrote, and every `fox link` as the whole runtime deleted.
# So the ignore is written here, where a newcomer meets the problem, rather than
# in a paragraph they read afterwards.
#
# Dropping the files already in the index is NOT done: staging hundreds of
# deletions in somebody else's working tree is not a side effect an install may
# have, so the command is named and left to them.

is_ignored() {
  git -C "${PROJECT_ROOT}" check-ignore -q --no-index "${ADDON_MOUNT}" 2>/dev/null && return 0
  git -C "${PROJECT_ROOT}" check-ignore -q --no-index "${ADDON_MOUNT}/" 2>/dev/null && return 0

  return 1
}

ignore_mount() {
  has git || return 0
  git -C "${PROJECT_ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0

  tracked=$(git -C "${PROJECT_ROOT}" ls-files "${ADDON_MOUNT}" | wc -l | tr -d ' ')

  # git is asked rather than the file parsed: the ignore may already come from a
  # parent `.gitignore`, from `.git/info/exclude` or from the global one.
  #
  # Both spellings are asked, because neither alone answers every case:
  # `--no-index` throughout, since `check-ignore` calls a TRACKED path not
  # ignored whatever the rules say; the plain path misses a `addons/fox/`
  # pattern when the mount is ABSENT; and the trailing slash is `fatal: beyond a
  # symbolic link` once the mount is LINKED. The plain path answers first and
  # covers a symlink, so the slash form only runs with no symlink in the way.
  #
  # The pattern WRITTEN carries no slash either, since a directory pattern would
  # not catch the symlink `fox link` leaves behind.
  if ! is_ignored; then
    # The blank line separates the block from what was there, and there is
    # nothing to separate it from in a file that did not exist a second ago.
    if [ -s "${PROJECT_ROOT}/${IGNORE_FILE}" ]; then
      printf '\n' >>"${PROJECT_ROOT}/${IGNORE_FILE}"
    fi

    {
      printf '%s\n' '# The Fox runtime is a dependency, mounted by `fox upgrade` and `fox link`.'
      printf '%s\n' '# The version this game runs is pinned in fox.config.json, as core.fox.'
      printf '%s\n' "${ADDON_MOUNT}"
    } >>"${PROJECT_ROOT}/${IGNORE_FILE}"

    step "Ignoring ${ADDON_MOUNT} in ${IGNORE_FILE}"
  fi

  if [ "${tracked}" -gt 0 ]; then
    [ "${tracked}" -eq 1 ] && noun='file' || noun='files'
    warn "${tracked} ${noun} of ${ADDON_MOUNT} still tracked: git ignores nothing it already follows"
    step "Drop them from the index once: git rm -r --cached ${ADDON_MOUNT}"
  fi
}

# -----------------------------------------------------------------------------
# The tag of the latest release, read from the GitHub API. No jq: a machine
# about to download an addon is not asked for a second tool, and the field is
# picked out with sed.

resolve_tag() {
  if [ -n "${VERSION_ARGUMENT}" ]; then
    case "${VERSION_ARGUMENT}" in
      v*) printf '%s' "${VERSION_ARGUMENT}" ;;
      *) printf 'v%s' "${VERSION_ARGUMENT}" ;;
    esac
    return
  fi

  payload=$(fetch "${LATEST_RELEASE}" 2>/dev/null || true)
  tag=$(printf '%s' "${payload}" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)

  [ -n "${tag}" ] || fail "Could not read the latest release of ${REPOSITORY}: pass a version, \`sh -s -- 2.2.0\`"

  printf '%s' "${tag}"
}

# -----------------------------------------------------------------------------
# The runtime half: `addons/fox`, taken from the tarball of the tag.
#
# The tarball rather than the release zip: `tar -xz` reads it on macOS, Linux
# and Windows alike, where unzipping needs a tool that is not everywhere. It is
# what `fox upgrade` downloads too.
#
# The mount is REPLACED, never written over: a file dropped between two versions
# would otherwise survive in the game forever. That deletion is the whole reason
# `fox upgrade` exists rather than a copy by hand, and an installer that skipped
# it would hand a newcomer the very mess the CLI was written to avoid.

mount_addon() {
  tag=$1
  mount="${PROJECT_ROOT}/${ADDON_MOUNT}"

  # A symlinked mount is a contributor following their checkout, on purpose:
  # replacing it with a pinned copy is never what an install was asked to do.
  if [ -L "${mount}" ]; then
    warn "${mount} is a symlink on a checkout, and was left alone"

    # The pin is not touched, since a checkout is not a release, but the ignore
    # still is: a linked mount is exactly the one git reports as every file
    # under it deleted at once.
    ignore_mount
    return
  fi

  work=$(mktemp -d "${TMPDIR:-/tmp}/fox-install-XXXXXX")
  trap 'rm -rf "${work}"' EXIT INT TERM

  step "Downloading ${tag}"
  fetch "https://github.com/${REPOSITORY}/archive/refs/tags/${tag}.tar.gz" | tar -xz -C "${work}" ||
    fail "Could not download ${REPOSITORY} ${tag}"

  extracted=$(find "${work}" -mindepth 1 -maxdepth 1 -type d | head -n 1)

  [ -d "${extracted}/${ADDON_MOUNT}" ] || fail "${tag} holds no ${ADDON_MOUNT}: it predates the addon layout"

  rm -rf "${mount}"
  mkdir -p "$(dirname "${mount}")"
  cp -R "${extracted}/${ADDON_MOUNT}" "${mount}"

  rm -rf "${work}"
  trap - EXIT INT TERM

  success "${ADDON_MOUNT} is now ${tag#v}"

  write_pin "${tag#v}"
  ignore_mount
}

# -----------------------------------------------------------------------------
# Whether this machine can run the CLI at all. A missing NodeJS is not a failed
# install: the runtime above is already mounted, and it is the half a game
# actually runs on.

can_run_cli() {
  if ! has node || ! has npm; then
    return 1
  fi

  major=$(node --version | sed 's/^v//' | cut -d. -f1)

  [ "${major}" -ge "${MINIMUM_NODE_MAJOR}" ]
}

# -----------------------------------------------------------------------------
# A `fox` sitting earlier in the PATH than the one npm just wrote shadows it,
# and every command afterwards runs a Fox nobody chose. Contributors linking a
# checkout hit exactly that, so the file is named rather than diagnosed.

check_shadowing() {
  npm_bin="$(npm prefix -g 2>/dev/null)/bin"
  installed=$(command -v fox 2>/dev/null || true)

  if [ -z "${installed}" ]; then
    warn "\`fox\` is not in your PATH: add ${npm_bin} to it"
    return
  fi

  case "${installed}" in
    "${npm_bin}"/*) ;;
    *)
      warn "${installed} comes first in your PATH and shadows the one npm installed"
      step "Remove it to run the released CLI: rm ${installed}"
      ;;
  esac
}

# -----------------------------------------------------------------------------

install_cli() {
  tag=$1

  if ! can_run_cli; then
    if ! has node; then
      warn "the \`fox\` CLI needs NodeJS >= ${MINIMUM_NODE_MAJOR}, which is not installed: https://nodejs.org"
    elif ! has npm; then
      warn 'the `fox` CLI needs npm, which is not installed: it ships with NodeJS'
    else
      warn "the \`fox\` CLI needs NodeJS >= ${MINIMUM_NODE_MAJOR}, and this is $(node --version)"
    fi

    step 'Skipping it: the addon is what your game runs on, and it needs nothing but Godot'
    return 1
  fi

  step "NodeJS $(node --version)"
  step "Installing the ${tag} CLI"

  # npm is quiet while it works and loud when it fails: a successful install has
  # nothing to say that the tree does not, and a failed one is unreadable
  # without the reason npm gave.
  log=$(mktemp "${TMPDIR:-/tmp}/fox-npm-XXXXXX")

  if ! npm install -g "github:${REPOSITORY}#${tag}" >"${log}" 2>&1; then
    cat "${log}" >&2
    rm -f "${log}"
    fail "npm could not install ${REPOSITORY}#${tag}"
  fi

  rm -f "${log}"

  check_shadowing
  success "\`fox\` is now ${tag}"
}

# -----------------------------------------------------------------------------

title 'installing fox'

# A project holding no mount is being RESTORED, not upgraded: the version it is
# owed is the one it declares, not whatever came out last week. A game that
# already has a mount, or that named a version, is installing on purpose and
# gets what it asked for.
if [ -z "${VERSION_ARGUMENT}" ] && [ ! -e "${PROJECT_ROOT}/${ADDON_MOUNT}" ]; then
  PIN=$(read_pin)

  if [ -n "${PIN}" ]; then
    step "Restoring the ${PIN} pinned in ${CONFIG_FILE}"
    VERSION_ARGUMENT=${PIN}
  fi
fi

TAG=$(resolve_tag)
MOUNTED=false

if [ -f "${PROJECT_ROOT}/${GODOT_PROJECT}" ]; then
  step "Mounting the runtime in ${PROJECT_ROOT}"
  mount_addon "${TAG}"
  MOUNTED=true
else
  step "No ${GODOT_PROJECT} in ${PROJECT_ROOT}: installing the CLI alone"
fi

CLI=true
install_cli "${TAG}" || CLI=false

done_ "Fox ${TAG#v} is installed"

# -----------------------------------------------------------------------------
# What is left to do, and only what is left: the three cases are genuinely
# different, and a newcomer reading a step already done is a newcomer wondering
# whether it failed.

printf '\n'

if [ "${MOUNTED}" = true ]; then
  printf '%s\n' 'Enable the plugin once, from Project > Project Settings > Plugins > Fox,'
  printf '%s\n' 'then open your project: Godot imports the addon as it opens.'
else
  printf '%s\n' 'Mount the runtime in your Godot project:'
  printf '\n'
  printf '%s\n' "  ${BOLD}cd your-game${RESET}"

  if [ "${CLI}" = true ]; then
    printf '%s\n' "  ${BOLD}fox upgrade${RESET}"
  else
    printf '%s\n' "  ${BOLD}curl -fsSL https://raw.githubusercontent.com/${REPOSITORY}/main/install.sh | sh${RESET}"
  fi

  printf '\n'
  printf '%s\n' 'Then enable the plugin once, from Project > Project Settings > Plugins > Fox.'
fi

printf '%s\n' "${DOCUMENTATION}"
