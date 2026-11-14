#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Apply repository-managed zsh and Vim configuration to existing Ubuntu users.
# Deliberately independent of vm-bootstrap.sh and provision-vm.sh.
set -euo pipefail

usage() {
   cat <<'USAGE'
Usage: configure-shell-editor.sh [-u USER|--user USER]... [--set-shell] [--dry-run]

Without --user, configure the invoking account (SUDO_USER when called via sudo).
Root or sudo-authorized callers also install/upgrade zsh and Vim, refresh
/etc/skel, and install the system Vim runtime. Non-sudo callers configure
only their own home, using whichever of zsh and Vim is already installed.

Options:
  -u, --user USER  Existing user to configure; repeat for multiple users
  --set-shell      Also change selected users' login shell to zsh (root/sudo only)
  --dry-run        Show intended changes without modifying files or packages
  -h, --help       Show this help
USAGE
}

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
warn() { printf 'Warning: %s\n' "$*" >&2; (( Warnings += 1 )); }
say() { printf '%s\n' "$*"; }

declare -a Users=() UserHomes=() UserUids=() UserGids=()
DryRun=false
SetShell=false
Warnings=0
FilesUpdated=0
FilesRemoved=0
FilesBackedUp=0
DirectoriesUpdated=0
Privileged=false
HaveZsh=false
HaveVim=false
RunId="$(date -u +%Y%m%dT%H%M%SZ)-$$"

ScriptDir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
ZshDir="$ScriptDir/files/zsh"
VimDir="$ScriptDir/files/vim"

parse_args() {
   while (( $# )); do
      case "$1" in
         -u|--user)
            (( $# >= 2 )) || die "$1 requires an existing username"
            Users+=("$2")
            shift 2 ;;
         --user=*)
            Users+=("${1#--user=}")
            shift ;;
         --set-shell) SetShell=true; shift ;;
         --dry-run) DryRun=true; shift ;;
         -h|--help) usage; exit 0 ;;
         *) die "unknown argument: $1" ;;
      esac
   done
}

# Refuse to operate through symlinked directory components, even as root.
# Ordinary file symlinks are backed up and safely replaced instead.
check_directory_path() {
   local path="$1" component part=''
   [[ $path == /* ]] || die "expected absolute directory: $path"
   local -a components=()
   IFS=/ read -r -a components <<< "${path#/}"
   for component in "${components[@]}"; do
      [[ -n $component ]] || continue
      part+="/$component"
      [[ ! -L $part ]] || die "unsafe symlinked directory: $part"
      [[ ! -e $part || -d $part ]] || die "not a directory: $part"
   done
}

ensure_dir() {
   local path="$1" uid="$2" gid="$3" mode="$4" existing_mode existing_owner
   check_directory_path "$path"
   if [[ -d $path ]]; then
      existing_mode=$(stat -c %a -- "$path")
      existing_owner=$(stat -c %u:%g -- "$path")
      [[ $existing_mode == "${mode#0}" && $existing_owner == "$uid:$gid" ]] && return 0
   fi
   if $DryRun; then
      say "PLAN directory: $path (owner $uid:$gid; mode $mode)"
      return 0
   fi
   if $Privileged; then
      install -d -o "$uid" -g "$gid" -m "$mode" -- "$path"
   else
      install -d -m "$mode" -- "$path"
   fi
   (( DirectoriesUpdated += 1 ))
}

# A parent that already exists is never chmodded or chowned. In
# particular, do NOT change an existing user's home-directory mode to 0755.
ensure_parent_dir() {
   local path="$1" uid="$2" gid="$3"
   check_directory_path "$path"
   [[ -d $path ]] || ensure_dir "$path" "$uid" "$gid" 0755
}

# Existing files and links are copied without dereferencing. Each run uses
# a unique backup directory, created only when something must be backed up.
backup_existing() {
   local path="$1" backup_root="$2" uid="$3" gid="$4"
   local relative="${path#/}" destination="$backup_root/${path#/}"
   if $DryRun; then
      say "PLAN backup: $path -> $destination"
      return 0
   fi
   ensure_dir "$backup_root" "$uid" "$gid" 0700
   ensure_dir "$(dirname -- "$destination")" "$uid" "$gid" 0700
   [[ ! -e $destination && ! -L $destination ]] ||
      die "backup already exists: $destination"
   cp -a --no-dereference -- "$path" "$destination"
   (( FilesBackedUp += 1 ))
}

# Install a regular source file; do not follow destination symlinks.
sync_file() {
   local source="$1" destination="$2" uid="$3" gid="$4" mode="$5" backups="$6"
   [[ -f $source && ! -L $source ]] || die "invalid source file: $source"
   ensure_parent_dir "$(dirname -- "$destination")" "$uid" "$gid"
   [[ ! -d $destination ]] || die "destination is a directory: $destination"
   if [[ -e $destination && ! -f $destination && ! -L $destination ]]; then
      die "unsupported destination type: $destination"
   fi
   if [[ -f $destination && ! -L $destination ]] &&
      cmp -s -- "$source" "$destination" &&
      [[ $(stat -c %a -- "$destination") == "${mode#0}" ]] &&
      [[ $(stat -c %u:%g -- "$destination") == "$uid:$gid" ]]; then
      return 0
   fi
   if [[ -e $destination || -L $destination ]]; then
      backup_existing "$destination" "$backups" "$uid" "$gid"
   fi
   if $DryRun; then
      say "PLAN file: $source -> $destination"
      return 0
   fi
   [[ ! -L $destination ]] || rm -f -- "$destination"
   if $Privileged; then
      install -o "$uid" -g "$gid" -m "$mode" -- "$source" "$destination"
   else
      install -m "$mode" -- "$source" "$destination"
   fi
   say "Updated: $destination"
   (( FilesUpdated += 1 ))
}

sync_link() {
   local destination="$1" target="$2" uid="$3" gid="$4" backups="$5"
   ensure_parent_dir "$(dirname -- "$destination")" "$uid" "$gid"
   [[ ! -d $destination ]] || die "destination is a directory: $destination"
   if [[ -L $destination && $(readlink -- "$destination") == "$target" ]]; then
      return 0
   fi
   if [[ -e $destination || -L $destination ]]; then
      backup_existing "$destination" "$backups" "$uid" "$gid"
   fi
   if $DryRun; then
      say "PLAN link: $destination -> $target"
      return 0
   fi
   rm -f -- "$destination"
   ln -s -- "$target" "$destination"
   $Privileged && chown -h "$uid:$gid" -- "$destination"
   (( FilesUpdated += 1 ))
}

sync_zsh() {
   local target="$1" uid="$2" gid="$3" backups="$4" file name prefix
   sync_file "$ZshDir/.zshrc" "$target/.zshrc" "$uid" "$gid" 0644 "$backups"
   sync_file "$ZshDir/.zshenv" "$target/.zshenv" "$uid" "$gid" 0644 "$backups"
   # Preserve the mode of an existing personal configuration directory.
   # On shared homes it may intentionally be private (0700).
   if [[ -d "$target/.zshrc.d" ]]; then
      check_directory_path "$target/.zshrc.d"
   else
      ensure_dir "$target/.zshrc.d" "$uid" "$gid" 0700
   fi

   shopt -s nullglob
   for file in "$ZshDir"/.zshrc.d/*.zsh; do
      sync_file "$file" "$target/.zshrc.d/${file##*/}" "$uid" "$gid" 0644 "$backups"
   done
   # Reconcile only the reserved 00-9f namespace; never touch a0-ff.
   for file in "$target"/.zshrc.d/*.zsh; do
      name="${file##*/}"
      if [[ $name =~ ^([[:xdigit:]]{2})-.+\.zsh$ ]]; then
         prefix="${BASH_REMATCH[1],,}"
         if (( 16#$prefix <= 16#9f )) &&
            [[ ! -e "$ZshDir/.zshrc.d/$name" && ! -L "$ZshDir/.zshrc.d/$name" ]]; then
            [[ ! -d $file ]] || die "managed file is a directory: $file"
            backup_existing "$file" "$backups" "$uid" "$gid"
            if $DryRun; then
               say "PLAN remove obsolete managed file: $file"
            else
               rm -f -- "$file"
               say "Removed obsolete managed file: $file"
               (( FilesRemoved += 1 ))
            fi
         fi
      fi
   done

   ensure_parent_dir "$target/.zshrc.d/examples" "$uid" "$gid"
   for file in "$ZshDir"/.zshrc.d/examples/*; do
      [[ -f $file ]] || continue
      sync_file "$file" "$target/.zshrc.d/examples/${file##*/}" \
         "$uid" "$gid" 0644 "$backups"
   done
}

sync_vim_home() {
   local target="$1" uid="$2" gid="$3" backups="$4"
   sync_file "$VimDir/.vimrc" "$target/.vimrc" "$uid" "$gid" 0644 "$backups"
   sync_link "$target/.gvimrc" .vimrc "$uid" "$gid" "$backups"
   ensure_dir "$target/.vim" "$uid" "$gid" 0700
   for directory in save swp undo; do
      ensure_dir "$target/.vim/$directory" "$uid" "$gid" 0700
   done
}

# Copy only repository-supplied files. In particular, retain personal
# ~/.vim/plugin/rc.vim and other unrelated user-local plugins.
sync_runtime() {
   local destination_base="$1" uid="$2" gid="$3" backups="$4" mode="$5"
   local source relative destination
   while IFS= read -r -d '' source; do
      relative="${source#"$VimDir/runtime/"}"
      if [[ $mode == local ]]; then
         if [[ $relative == vimfiles/* ]]; then
            destination="$destination_base/${relative#vimfiles/}"
         else
            destination="$destination_base/$relative"
         fi
      else
         destination="$destination_base/$relative"
      fi
      sync_file "$source" "$destination" "$uid" "$gid" 0644 "$backups"
   done < <(find "$VimDir/runtime" -type f -print0)
}

validate_repo() {
   [[ -f $ZshDir/.zshrc && -f $ZshDir/.zshenv ]] ||
      die "missing canonical zsh dotfiles in $ZshDir"
   [[ -d $ZshDir/.zshrc.d/examples && -f $VimDir/.vimrc &&
      -d $VimDir/runtime/vimfiles && -d $VimDir/runtime/template ]] ||
      die "incomplete repository configuration"
   local file name prefix
   shopt -s nullglob
   for file in "$ZshDir"/.zshrc.d/*.zsh; do
      [[ -f $file && ! -L $file ]] || die "invalid zsh source: $file"
      name="${file##*/}"
      [[ $name =~ ^([[:xdigit:]]{2})-.+\.zsh$ ]] ||
         die "invalid repository zsh module name: $name"
      prefix="${BASH_REMATCH[1],,}"
      (( 16#$prefix <= 16#9f )) ||
         die "repository module uses reserved user prefix: $name"
   done
   if find "$ZshDir" "$VimDir" -type l -print -quit | grep -q .; then
      die "repository configuration contains symlinks; refusing to install"
   fi
}

validate_users() {
   local user entry account password uid gid gecos home shell
   local -A seen=()
   local -a deduped=()
   if (( ${#Users[@]} == 0 )); then
      Users=("${SUDO_USER:-$(id -un)}")
   fi
   for user in "${Users[@]}"; do
      [[ $user =~ ^[a-z_][a-z0-9_-]*[$]?$ ]] ||
         die "invalid username: $user"
      [[ ! -v seen[$user] ]] || continue
      seen[$user]=1
      entry="$(getent passwd "$user")" || die "unknown user: $user"
      IFS=: read -r account password uid gid gecos home shell <<< "$entry"
      [[ $account == "$user" && $uid =~ ^[0-9]+$ && $gid =~ ^[0-9]+$ ]] ||
         die "invalid passwd record for $user"
      [[ $home == /* && $home != / && -d $home && ! -L $home ]] ||
         die "unsafe or missing home directory for $user: $home"
      check_directory_path "$home"
      if ! $Privileged && [[ $user != "$(id -un)" ]]; then
         die "without sudo, only the invoking user may be configured"
      fi
      # Preflight only the application directories we will actually touch.
      check_directory_path "$home/.config-backups"
      if $Privileged || $HaveZsh; then
         check_directory_path "$home/.zshrc.d"
         check_directory_path "$home/.zshrc.d/examples"
      fi
      if $Privileged || $HaveVim; then
         check_directory_path "$home/.vim"
      fi
      deduped+=("$user")
      UserHomes+=("$home")
      UserUids+=("$uid")
      UserGids+=("$gid")
   done
   Users=("${deduped[@]}")
}

maybe_elevate() {
   (( EUID != 0 )) || { Privileged=true; return; }
   if command -v sudo >/dev/null 2>&1; then
      if sudo -n -v >/dev/null 2>&1 || sudo -v; then
         exec sudo -H -- "$ScriptDir/configure-shell-editor.sh" "$@"
      fi
   fi
   Privileged=false
}

main() {
   parse_args "$@"
   validate_repo
   maybe_elevate "$@"
   if ! $Privileged; then
      $SetShell && die "--set-shell requires root or sudo access"
      command -v zsh >/dev/null 2>&1 && HaveZsh=true
      command -v vim >/dev/null 2>&1 && HaveVim=true
      if ! $HaveZsh && ! $HaveVim; then
         die "neither zsh nor Vim is installed, and this user has no sudo access"
      fi
      $HaveZsh || warn "zsh is unavailable; zsh configuration will not be installed"
      $HaveVim || warn "Vim is unavailable; Vim configuration will not be installed"
   fi
   validate_users

   if $Privileged; then
      say 'Using privileged mode (system packages, /etc/skel, selected users).'
      if $DryRun; then
         say 'PLAN apt-get update && apt-get install -y --no-install-recommends zsh vim'
         HaveZsh=true
         HaveVim=true
      else
         export DEBIAN_FRONTEND=noninteractive
         apt-get update
         apt-get install -y --no-install-recommends zsh vim
         command -v zsh >/dev/null || die "zsh not found after package install"
         command -v vim >/dev/null || die "Vim not found after package install"
         HaveZsh=true
         HaveVim=true
      fi
      local system_backup="/var/backups/ubuntu-host-bootstrap/$RunId"
      sync_zsh /etc/skel 0 0 "$system_backup"
      sync_vim_home /etc/skel 0 0 "$system_backup"
      sync_runtime /usr/share/vim 0 0 "$system_backup" system
   else
      say 'Using unprivileged mode (invoking user home only).'
   fi

   local i user home uid gid backups shellpath
   for i in "${!Users[@]}"; do
      user="${Users[$i]}"
      home="${UserHomes[$i]}"
      uid="${UserUids[$i]}"
      gid="${UserGids[$i]}"
      backups="$home/.config-backups/ubuntu-host-bootstrap/$RunId"
      say "Configuring: $user ($home)"
      $HaveZsh && sync_zsh "$home" "$uid" "$gid" "$backups"
      if $HaveVim; then
         sync_vim_home "$home" "$uid" "$gid" "$backups"
         if ! $Privileged; then
            sync_runtime "$home/.vim" "$uid" "$gid" "$backups" local
         fi
      fi
      if $SetShell; then
         shellpath="$(command -v zsh || true)"
         if $DryRun; then
            say "PLAN set login shell for $user to zsh"
         else
            [[ -n $shellpath && -f /etc/shells ]] ||
               die "zsh must be installed and listed in /etc/shells"
            if ! grep -Fxq -- "$shellpath" /etc/shells; then
               [[ -x /bin/zsh ]] && grep -Fxq /bin/zsh /etc/shells &&
                  shellpath=/bin/zsh ||
                  die "zsh is not registered in /etc/shells"
            fi
            if [[ $(getent passwd "$user" | cut -d: -f7) != "$shellpath" ]]; then
               usermod -s "$shellpath" "$user"
               say "Login shell updated for $user"
            fi
         fi
      fi
   done
   say "Finished: files updated=$FilesUpdated; managed files removed=$FilesRemoved; backups=$FilesBackedUp; warnings=$Warnings."
   if $DryRun; then
      say 'Dry run: no modifications were made.'
   fi
}

main "$@"
