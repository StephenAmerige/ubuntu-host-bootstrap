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

export HOME="$Temp/home"
export MOCK_ASSET_DIR="$Temp/assets"
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
      cp -- "$MOCK_ASSET_DIR/${URL##*/}" "$Output" ;;
   *) printf 'Unexpected mock URL: %s\n' "$URL" >&2; exit 1 ;;
esac
MOCK
chmod +x "$Temp/bin/curl"
export PATH="$Temp/bin:$PATH"

zsh -f -c 'source "$HOME/.zshrc.d/95-update.zsh"; zupdate --version; zupdate --check; zupdate'
grep -Fxq "typeset -g _ZshFilesVersion=$Tag" "$HOME/.zshrc.d/00-version.zsh"
[[ ! -e "$HOME/.zshrc.d/10-obsolete.zsh" ]]
grep -Fxq 'preserve personal settings' "$HOME/.zshrc.d/e0-personal.zsh"
find "$HOME/.config-backups/ubuntu-host-bootstrap" -type f -name 10-obsolete.zsh | grep -q .
find "$HOME/.config-backups/ubuntu-host-bootstrap" -type f -name .zshrc | grep -q .
zsh -f -c 'source "$HOME/.zshrc.d/95-update.zsh"; zupdate --version; zupdate --check; zupdate'

echo 'Zsh release and updater smoke test: PASS'
