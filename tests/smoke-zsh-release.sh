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
zsh -n "$RepoRoot/files/zsh/.zshrc.d/95-update.zsh"
zsh -n "$RepoRoot/files/zsh/.zshrc.d/00-help-update.zsh"

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
printf 'preserve personal settings\n' > "$HOME/.zshrc.d/e0-personal.zsh"

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
grep -Fxq 'preserve personal settings' "$HOME/.zshrc.d/e0-personal.zsh"
! grep -Fxq "typeset -g _ZshFilesVersion=$Tag" "$HOME/.zshrc.d/00-version.zsh"

# Only -y may apply the release; the existing backup/retirement safeguards remain.
zsh -f -c 'source "$HOME/.zshrc.d/95-update.zsh"; zupdate -y'
[[ $(wc -l < "$MOCK_ASSET_LOG") == 2 ]]
grep -Fxq "typeset -g _ZshFilesVersion=$Tag" "$HOME/.zshrc.d/00-version.zsh"
[[ ! -e "$HOME/.zshrc.d/10-obsolete.zsh" ]]
grep -Fxq 'preserve personal settings' "$HOME/.zshrc.d/e0-personal.zsh"
find "$HOME/.config-backups/ubuntu-host-bootstrap" -type f -name 10-obsolete.zsh | grep -q .
find "$HOME/.config-backups/ubuntu-host-bootstrap" -type f -name .zshrc | grep -q .
zsh -f -c 'source "$HOME/.zshrc.d/95-update.zsh"; zupdate --version; zupdate; zupdate --check; zupdate -y'
[[ $(wc -l < "$MOCK_ASSET_LOG") == 2 ]]

# Reject ambiguous or unsupported update requests before any mutation.
for Args in '--check -y' '-y --check' '--yes' '--version -y'; do
   if zsh -f -c 'source "$HOME/.zshrc.d/95-update.zsh"; zupdate "${=1}"' zupdate-test "$Args" >/dev/null 2>&1; then
      echo "zupdate unexpectedly accepted: $Args" >&2
      exit 1
   fi
done

echo 'Zsh release and updater smoke test: PASS'
