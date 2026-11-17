#!/usr/bin/env bash
# Smoke-test ZIP composition and zupdate with a fake GitHub release.
set -euo pipefail

RepoRoot=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
Temp=$(mktemp -d)
trap 'rm -rf -- "$Temp"' EXIT
Tag=v9.8.7

bash "$RepoRoot/scripts/build-zsh-release.sh" "$Tag" "$Temp/assets"
(cd "$Temp/assets" && sha256sum -c zshfiles.zip.sha256)

(
   cd "$RepoRoot/files/zsh"
   shopt -s nullglob
   printf '%s\n' .zshenv .zshrc .zshrc.d/[0-9]*.zsh .zshrc.d/examples/*.zsh > "$Temp/expected"
)
unzip -Z -1 "$Temp/assets/zshfiles.zip" > "$Temp/actual"
diff -u "$Temp/expected" "$Temp/actual"
! grep -Eq '(^README[.]md$|[/]a[0-9a-f]-)' "$Temp/actual"

command -v zsh >/dev/null || { echo 'zsh required for updater smoke test' >&2; exit 1; }
zsh -n "$RepoRoot/files/zsh/.zshrc"
zsh -n "$RepoRoot/files/zsh/.zshrc.d/95-update.zsh"
zsh -n "$RepoRoot/files/zsh/.zshrc.d/00-help-update.zsh"

# Test real startup-module loading with valid two-hex-prefix files, invalid
# names, and an empty module directory; no extra *.zsh files may run.
LoaderHome="$Temp/loader-home"
mkdir -p "$LoaderHome/.zshrc.d"
for Name in 00-managed a0-user ff-user; do
   printf 'print -r -- "loaded-%s"\n' "$Name" > "$LoaderHome/.zshrc.d/$Name.zsh"
done
for Name in 0-invalid 9g-invalid A0-upper gg-invalid a0invalid; do
   printf 'print -r -- "loaded-invalid-%s"\n' "$Name" > "$LoaderHome/.zshrc.d/$Name.zsh"
done
LoaderOutput=$(HOME="$LoaderHome" zsh -f -ic 'source "$1"' zsh-loader-check \
   "$RepoRoot/files/zsh/.zshrc")
grep -Fxq 'loaded-00-managed' <<< "$LoaderOutput"
grep -Fxq 'loaded-a0-user' <<< "$LoaderOutput"
grep -Fxq 'loaded-ff-user' <<< "$LoaderOutput"
! grep -Fq 'loaded-invalid' <<< "$LoaderOutput"
mkdir -p "$Temp/empty-loader-home/.zshrc.d"
HOME="$Temp/empty-loader-home" zsh -f -ic 'source "$1"' zsh-loader-check \
   "$RepoRoot/files/zsh/.zshrc" >/dev/null

# Discover the updater using its actual command name, not the legacy filename.
HelpModule="$RepoRoot/files/zsh/.zshrc.d/00-help.zsh"
UpdateHelpModule="$RepoRoot/files/zsh/.zshrc.d/00-help-update.zsh"
HelpTopics=$(zsh -f -c 'source "$1"; function :help:update { :; }; source "$2"; help -l' \
   zsh-help-check "$HelpModule" "$UpdateHelpModule")
grep -Eq '^[[:space:]]+zupdate$' <<< "$HelpTopics"
! grep -Eq '^[[:space:]]+update$' <<< "$HelpTopics"
HelpText=$(zsh -f -c 'source "$1"; source "$2"; help zupdate' \
   zsh-help-check "$HelpModule" "$UpdateHelpModule")
grep -Fq 'Zsh Configuration Updates' <<< "$HelpText"
grep -Fq 'zupdate -y' <<< "$HelpText"
if zsh -f -c 'source "$1"; source "$2"; help update' \
   zsh-help-check "$HelpModule" "$UpdateHelpModule" >/dev/null 2>&1; then
   echo 'Unexpected legacy help update alias' >&2
   exit 1
fi
bash "$RepoRoot/tests/smoke-ztag.sh"

export HOME="$Temp/home"
export MOCK_ASSET_DIR="$Temp/assets"
export MOCK_ASSET_LOG="$Temp/asset-downloads.log"
mkdir -p "$HOME/.zshrc.d" "$Temp/bin"
cp "$RepoRoot/files/zsh/.zshrc.d/95-update.zsh" "$HOME/.zshrc.d/95-update.zsh"
cp "$RepoRoot/files/zsh/.zshrc.d/00-version.zsh" "$HOME/.zshrc.d/00-version.zsh"
printf 'prior shell file\n' > "$HOME/.zshrc"
printf 'prior managed module\n' > "$HOME/.zshrc.d/10-obsolete.zsh"
printf 'retired high-prefix module\n' > "$HOME/.zshrc.d/9f-retired.zsh"
printf 'remove single-digit filename\n' > "$HOME/.zshrc.d/1-not-managed.zsh"
printf 'remove non-hex filename\n' > "$HOME/.zshrc.d/9g-not-managed.zsh"
printf 'remove non-zsh file\n' > "$HOME/.zshrc.d/7-stale.txt"
printf 'preserve a0 settings\n' > "$HOME/.zshrc.d/a0-personal.zsh"
printf 'preserve personal settings\n' > "$HOME/.zshrc.d/e0-personal.zsh"
printf 'preserve ff settings\n' > "$HOME/.zshrc.d/ff-personal.zsh"
mkdir -p "$HOME/.zshrc.d/examples/obsolete-subdir"
printf 'remove obsolete example\n' > "$HOME/.zshrc.d/examples/retired-example.zsh"
printf 'remove obsolete nested example\n' > "$HOME/.zshrc.d/examples/obsolete-subdir/old.txt"

# The same Zsh glob with (N) must produce an empty array on no matches,
# even with NULL_GLOB disabled.
mkdir -p "$Temp/empty-modules"
EmptyCount=$(zsh -f -c 'unsetopt null_glob; typeset -a Candidates; Candidates=( "$1"/[0-9]*.zsh(N) ); print -r -- ${#Candidates}' zsh-glob-test "$Temp/empty-modules")
[[ $EmptyCount == 0 ]]

# Bare help should show the installed release and point to zupdate without
# requiring a network lookup. The source checkout is explicitly unversioned.
HelpUsage=$(zsh -f -c 'source "$1"; source "$2"; help' \
   zsh-help-check "$HelpModule" "$HOME/.zshrc.d/95-update.zsh")
grep -Fq 'Installed configuration: source checkout (unversioned)' <<< "$HelpUsage"
grep -Fq 'zupdate          Check for the latest release (no changes)' <<< "$HelpUsage"
grep -Fq 'zupdate -y       Install an available release' <<< "$HelpUsage"
grep -Fq 'help zupdate     Explain release updates and safeguards' <<< "$HelpUsage"

# The reported release must come from the installed marker, not the network.
printf 'typeset -g _ZshFilesVersion=v2.3.4\n' > "$HOME/.zshrc.d/00-version.zsh"
HelpUsage=$(zsh -f -c 'source "$1"; source "$2"; help' \
   zsh-help-check "$HelpModule" "$HOME/.zshrc.d/95-update.zsh")
grep -Fq 'Installed configuration: v2.3.4' <<< "$HelpUsage"
cp "$RepoRoot/files/zsh/.zshrc.d/00-version.zsh" "$HOME/.zshrc.d/00-version.zsh"

cat > "$Temp/bin/curl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
Output=''
URL=''
while (( $# )); do
   case "$1" in
      -o) Output=$2; shift 2 ;;
      *) URL=$1; shift ;;
   esac
done
case "$URL" in
   */releases/latest) printf '{"tag_name": "v9.8.7"}\n' ;;
   */releases/download/v9.8.7/zshfiles.zip|*/releases/download/v9.8.7/zshfiles.zip.sha256)
      printf '%s\n' "$URL" >> "$MOCK_ASSET_LOG"
      cp -- "$MOCK_ASSET_DIR/${URL##*/}" "$Output" ;;
   *) printf 'Unexpected mock URL: %s\n' "$URL" >&2; exit 1 ;;
esac
MOCK
chmod +x "$Temp/bin/curl"

# Force a late example-install failure to verify that the complete original
# numeric namespace and examples tree are restored on rollback.
cat > "$Temp/bin/install" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
if [[ ${MOCK_FAIL_INSTALL:-} == 1 && ${4:-} == */unpacked/.zshrc.d/examples/ff-user.zsh ]]; then
   echo 'Deliberately failing example installation' >&2
   exit 1
fi
exec /usr/bin/install "$@"
MOCK
chmod +x "$Temp/bin/install"
export PATH="$Temp/bin:$PATH"

# The default and --check must never download release assets or alter managed files.
CheckOutput=$(zsh -f -c 'source "$HOME/.zshrc.d/95-update.zsh"; zupdate --version; zupdate; zupdate --check')
grep -Fq 'An update is available.' <<< "$CheckOutput"
grep -Fq 'Run zupdate -y to download and apply the update.' <<< "$CheckOutput"
[[ ! -e "$MOCK_ASSET_LOG" ]]
[[ ! -d "$HOME/.zshrc.d/.zupdate.lock" ]]
[[ ! -d "$HOME/.config-backups/ubuntu-host-bootstrap" ]]
grep -Fxq 'prior shell file' "$HOME/.zshrc"
grep -Fxq 'prior managed module' "$HOME/.zshrc.d/10-obsolete.zsh"
grep -Fxq 'retired high-prefix module' "$HOME/.zshrc.d/9f-retired.zsh"
grep -Fxq 'remove single-digit filename' "$HOME/.zshrc.d/1-not-managed.zsh"
grep -Fxq 'remove non-hex filename' "$HOME/.zshrc.d/9g-not-managed.zsh"
grep -Fxq 'remove non-zsh file' "$HOME/.zshrc.d/7-stale.txt"
grep -Fxq 'preserve a0 settings' "$HOME/.zshrc.d/a0-personal.zsh"
grep -Fxq 'preserve personal settings' "$HOME/.zshrc.d/e0-personal.zsh"
grep -Fxq 'preserve ff settings' "$HOME/.zshrc.d/ff-personal.zsh"
grep -Fxq 'remove obsolete example' "$HOME/.zshrc.d/examples/retired-example.zsh"
grep -Fxq 'remove obsolete nested example' "$HOME/.zshrc.d/examples/obsolete-subdir/old.txt"
! grep -Fxq "typeset -g _ZshFilesVersion=$Tag" "$HOME/.zshrc.d/00-version.zsh"

# A failure after clearing the namespace must restore all original files.
if MOCK_FAIL_INSTALL=1 zsh -f -c 'source "$HOME/.zshrc.d/95-update.zsh"; :zupdate:apply "$1" "$2"' \
   zsh-rollback-test "$Tag" "$Temp/assets" > "$Temp/rollback.log" 2>&1; then
   echo 'zupdate unexpectedly succeeded despite failed example installation' >&2
   exit 1
fi
grep -Fq 'rolling back' "$Temp/rollback.log"
grep -Fxq 'prior shell file' "$HOME/.zshrc"
grep -Fxq 'prior managed module' "$HOME/.zshrc.d/10-obsolete.zsh"
grep -Fxq 'remove non-zsh file' "$HOME/.zshrc.d/7-stale.txt"
grep -Fxq 'remove obsolete example' "$HOME/.zshrc.d/examples/retired-example.zsh"
grep -Fxq 'remove obsolete nested example' "$HOME/.zshrc.d/examples/obsolete-subdir/old.txt"
grep -Fxq 'preserve a0 settings' "$HOME/.zshrc.d/a0-personal.zsh"
grep -Fxq 'preserve personal settings' "$HOME/.zshrc.d/e0-personal.zsh"
grep -Fxq 'preserve ff settings' "$HOME/.zshrc.d/ff-personal.zsh"
grep -Fxq 'typeset -g _ZshFilesVersion=source' "$HOME/.zshrc.d/00-version.zsh"

# Only -y may apply the release; backup and retirement safeguards remain.
zsh -f -c 'source "$HOME/.zshrc.d/95-update.zsh"; zupdate -y'
[[ $(wc -l < "$MOCK_ASSET_LOG") == 2 ]]
grep -Fxq "typeset -g _ZshFilesVersion=$Tag" "$HOME/.zshrc.d/00-version.zsh"
[[ ! -e "$HOME/.zshrc.d/10-obsolete.zsh" ]]
[[ ! -e "$HOME/.zshrc.d/9f-retired.zsh" ]]
[[ ! -e "$HOME/.zshrc.d/1-not-managed.zsh" ]]
[[ ! -e "$HOME/.zshrc.d/9g-not-managed.zsh" ]]
[[ ! -e "$HOME/.zshrc.d/7-stale.txt" ]]
[[ ! -e "$HOME/.zshrc.d/examples/retired-example.zsh" ]]
[[ ! -e "$HOME/.zshrc.d/examples/obsolete-subdir" ]]
[[ -f "$HOME/.zshrc.d/examples/ff-user.zsh" ]]
grep -Fxq 'preserve a0 settings' "$HOME/.zshrc.d/a0-personal.zsh"
grep -Fxq 'preserve personal settings' "$HOME/.zshrc.d/e0-personal.zsh"
grep -Fxq 'preserve ff settings' "$HOME/.zshrc.d/ff-personal.zsh"
find "$HOME/.config-backups/ubuntu-host-bootstrap" -type f -name 10-obsolete.zsh | grep -q .
find "$HOME/.config-backups/ubuntu-host-bootstrap" -type f -name 9f-retired.zsh | grep -q .
find "$HOME/.config-backups/ubuntu-host-bootstrap" -type f -name 7-stale.txt | grep -q .
find "$HOME/.config-backups/ubuntu-host-bootstrap" -type f -name retired-example.zsh | grep -q .
find "$HOME/.config-backups/ubuntu-host-bootstrap" -type f -name old.txt | grep -q .
find "$HOME/.config-backups/ubuntu-host-bootstrap" -type f -name .zshrc | grep -q .

# The numeric namespace must contain exactly the current packaged modules.
unzip -Z -1 "$Temp/assets/zshfiles.zip" |
   grep -E '^\.zshrc.d/[0-9][0-9a-f]-[^/]+\.zsh$' | sort > "$Temp/expected-managed"
find "$HOME/.zshrc.d" -mindepth 1 -maxdepth 1 -printf '%f\n' |
   grep -E '^[0-9]' | sed 's|^|.zshrc.d/|' | sort > "$Temp/installed-managed"
diff -u "$Temp/expected-managed" "$Temp/installed-managed"
zsh -f -c 'source "$HOME/.zshrc.d/95-update.zsh"; zupdate --version; zupdate; zupdate --check; zupdate -y'
[[ $(wc -l < "$MOCK_ASSET_LOG") == 2 ]]

# Reject ambiguous or unsupported update requests before any mutation.
for Args in '--check -y' '-y --check' '--yes' '--version -y'; do
   read -r -a Arguments <<< "$Args"
   if zsh -f -c 'source "$HOME/.zshrc.d/95-update.zsh"; zupdate "$@"' zupdate-test "${Arguments[@]}" >/dev/null 2>&1; then
      echo "zupdate unexpectedly accepted: $Args" >&2
      exit 1
   fi
done

echo 'Zsh release and updater smoke test: PASS'
