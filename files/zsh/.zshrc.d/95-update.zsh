########################################################################
# 95-update.zsh - User-controlled updates from GitHub Releases.
# No network requests or update checks occur during shell startup.
########################################################################

function :zupdate:version
{
   local File="$HOME/.zshrc.d/00-version.zsh"
   local Value=source

   if [[ -r $File ]]; then
      Value=$(command sed -n 's/^typeset -g _ZshFilesVersion=//p' "$File" | command head -n 1)
   fi

   REPLY=${Value:-source}
}

function :zupdate:replace
{
   local Source=$1 Destination=$2 Temporary
   Temporary=$(command mktemp "${Destination}.zupdate.XXXXXXXX") || return 1

   if ! command install -m 0644 -- "$Source" "$Temporary" ||
      ! command mv -f -- "$Temporary" "$Destination"; then
      command rm -f -- "$Temporary"
      return 1
   fi
}

function :zupdate:rollback
{
   local Backup=$1 Relative Destination Previous
   shift

   for Relative in "$@"; do
      Destination="$HOME/$Relative"
      Previous="$Backup/$Relative"
      command rm -f -- "$Destination" || return 1
      if [[ -e $Previous || -L $Previous ]]; then
         command cp -a --no-dereference -- "$Previous" "$Destination" || return 1
      fi
   done
}

function :zupdate:apply
{
   local Version=$1
   local ArchiveDir=$2
   local Archive="$ArchiveDir/zshfiles.zip"
   local Checksum="$ArchiveDir/zshfiles.zip.sha256"
   local Extracted="$ArchiveDir/unpacked"
   local Entries Relative Source Destination Previous
   local BackupBase="$HOME/.config-backups/ubuntu-host-bootstrap"
   local Backup
   local -a Updated=() Removed=() Touched=()
   local -A Present=()

   [[ $(command wc -l < "$Checksum") == 1 ]] &&
      command grep -Eq '^[0-9a-f]{64}  zshfiles[.]zip$' "$Checksum" || {
      print -u2 -r -- 'zupdate: invalid checksum format'
      return 1
   }

   (cd -- "$ArchiveDir" && command sha256sum -c --status zshfiles.zip.sha256) || {
      print -u2 -r -- 'zupdate: SHA-256 verification failed'
      return 1
   }

   Entries=$(command unzip -Z -1 "$Archive") || return 1
   for Relative in ${(f)Entries}; do
      if ! [[ $Relative =~ '^([.]zshenv|[.]zshrc|[.]zshrc[.]d/[0-9][0-9a-f]-[^/]+[.]zsh|[.]zshrc[.]d/examples/[^/]+[.]zsh)$' ]]; then
         print -u2 -r -- "zupdate: unexpected archive entry: $Relative"
         return 1
      fi
      if [[ -n ${Present[$Relative]-} ]]; then
         print -u2 -r -- "zupdate: duplicate archive entry: $Relative"
         return 1
      fi
      Present[$Relative]=1
   done

   for Relative in .zshenv .zshrc .zshrc.d/00-version.zsh .zshrc.d/95-update.zsh .zshrc.d/00-help-update.zsh; do
      [[ -n ${Present[$Relative]-} ]] || {
         print -u2 -r -- "zupdate: missing required archive entry: $Relative"
         return 1
      }
   done

   command mkdir -p -- "$Extracted" || return 1
   command unzip -q -- "$Archive" -d "$Extracted" || return 1

   for Relative in ${(k)Present}; do
      Source="$Extracted/$Relative"
      [[ -f $Source && ! -L $Source ]] || {
         print -u2 -r -- "zupdate: invalid extracted file: $Relative"
         return 1
      }
   done

   local StagedVersion
   StagedVersion=$(command sed -n 's/^typeset -g _ZshFilesVersion=//p' "$Extracted/.zshrc.d/00-version.zsh")
   [[ $StagedVersion == "$Version" ]] || {
      print -u2 -r -- 'zupdate: archive version does not match the release'
      return 1
   }

   # Refuse symlinked managed directories, including the backup path.
   for Relative in .zshrc.d .zshrc.d/examples .config-backups .config-backups/ubuntu-host-bootstrap; do
      Destination="$HOME/$Relative"
      [[ ! -L $Destination && ( ! -e $Destination || -d $Destination ) ]] || {
         print -u2 -r -- "zupdate: unsafe directory: $Destination"
         return 1
      }
   done

   for Relative in ${(ok)Present}; do
      Destination="$HOME/$Relative"
      [[ ! -d $Destination ]] || {
         print -u2 -r -- "zupdate: destination is a directory: $Destination"
         return 1
      }
      if [[ ! -f $Destination || -L $Destination ]] ||
         ! command cmp -s -- "$Extracted/$Relative" "$Destination" ||
         [[ $(command stat -c %a -- "$Destination") != 644 ]]; then
         Updated+=("$Relative")
      fi
   done

   # Snapshot numeric-prefix candidates with Zsh's (N) null-glob qualifier.
   # Only valid, absent-from-release managed modules are eligible for removal.
   # Personal a0-ff modules and unrelated files must remain untouched.
   local Old
   local -a ExistingManaged
   ExistingManaged=( "$HOME"/.zshrc.d/[0-9]*.zsh(N) )
   for Old in "${ExistingManaged[@]}"; do
      Relative=".zshrc.d/${Old:t}"
      [[ $Relative =~ '^[.]zshrc[.]d/[0-9][0-9a-f]-[^/]+[.]zsh

   if (( ${#Updated} == 0 && ${#Removed} == 0 )); then
      print -r -- "zupdate: configuration already matches $Version"
      return 0
   fi

   Backup="$BackupBase/zupdate-$(command date -u +%Y%m%dT%H%M%SZ)-$$"
   command mkdir -m 700 -p -- "$Backup" || return 1

   # Complete backups before changing the installed files.
   for Relative in "${Updated[@]}" "${Removed[@]}"; do
      Source="$HOME/$Relative"
      if [[ -e $Source || -L $Source ]]; then
         Destination="$Backup/$Relative"
         command mkdir -p -- "${Destination:h}" || return 1
         command cp -a --no-dereference -- "$Source" "$Destination" || return 1
      fi
   done

   command mkdir -p -- "$HOME/.zshrc.d/examples" || return 1

   for Relative in "${Updated[@]}"; do
      Touched+=("$Relative")
      if ! :zupdate:replace "$Extracted/$Relative" "$HOME/$Relative"; then
         print -u2 -r -- "zupdate: failed to install $Relative; rolling back"
         :zupdate:rollback "$Backup" "${Touched[@]}" ||
            print -u2 -r -- "zupdate: rollback needs manual review: $Backup"
         return 1
      fi
   done

   for Relative in "${Removed[@]}"; do
      Touched+=("$Relative")
      if ! command rm -f -- "$HOME/$Relative"; then
         print -u2 -r -- "zupdate: failed to remove $Relative; rolling back"
         :zupdate:rollback "$Backup" "${Touched[@]}" ||
            print -u2 -r -- "zupdate: rollback needs manual review: $Backup"
         return 1
      fi
   done

   print -r -- "zupdate: installed $Version (${#Updated} updated, ${#Removed} removed)"
   print -r -- "Backup: $Backup"
   print -r -- 'Start a new Zsh session to activate the updated configuration.'
}

function :zupdate:main
{
   emulate -L zsh
   setopt null_glob
   umask 077

   local ReleaseURL='https://github.com/StephenAmerige/ubuntu-host-bootstrap/releases'
   local ApiURL='https://api.github.com/repos/StephenAmerige/ubuntu-host-bootstrap/releases/latest'
   local Current Latest Details Directory Lock Status
   local Mode=check
   local Usage='Usage: zupdate [-y|--check|--version|--help]'

   case ${1-} in
   --version)
      (( $# == 1 )) || { print -u2 -r -- "$Usage"; return 2; }
      :zupdate:version
      print -r -- "Installed Zsh configuration: $REPLY"
      return 0
      ;;
   --check|'')
      (( $# <= 1 )) || { print -u2 -r -- "$Usage"; return 2; }
      ;;
   -y)
      (( $# == 1 )) || { print -u2 -r -- "$Usage"; return 2; }
      Mode=apply
      ;;
   --help|-h)
      (( $# == 1 )) || { print -u2 -r -- "$Usage"; return 2; }
      print -rl -- "$Usage" '' \
         '  zupdate            Check for a newer release (no changes)' \
         '  zupdate --check    Same as zupdate' \
         '  zupdate -y         Download, verify, and install the latest release' \
         '  zupdate --version  Show the installed version'
      return 0
      ;;
   *)
      print -u2 -r -- "$Usage"
      return 2
      ;;
   esac

   for Details in curl unzip sha256sum sed grep cmp cp mv rm install mktemp; do
      whence -p "$Details" >/dev/null 2>&1 || {
         print -u2 -r -- "zupdate: required command not found: $Details"
         return 1
      }
   done

   :zupdate:version
   Current=$REPLY
   Details=$(command curl -fsSL --connect-timeout 10 --max-time 60 \
      -H 'Accept: application/vnd.github+json' "$ApiURL") || {
      print -u2 -r -- 'zupdate: unable to find the latest published GitHub release'
      return 1
   }

   if ! [[ $Details =~ '"tag_name"[[:space:]]*:[[:space:]]*"(v[0-9]+[.]([0-9]+)[.]([0-9]+))"' ]]; then
      print -u2 -r -- 'zupdate: latest release has no supported version tag'
      return 1
   fi
   Latest=$match[1]

   print -r -- "Installed: $Current"
   print -r -- "Latest:    $Latest"

   if [[ $Current == $Latest ]]; then
      print -r -- 'Zsh configuration is up to date.'
      return 0
   fi

   if [[ $Current == v<->.<->.<-> ]]; then
      local Highest
      Highest=$(print -rl -- "$Current" "$Latest" | command sort -V | command tail -n 1)
      if [[ $Highest == $Current ]]; then
         print -r -- 'Installed version is newer than the latest published release; no downgrade performed.'
         return 0
      fi
   fi

   if [[ $Mode == check ]]; then
      print -r -- 'An update is available.'
      print -r -- 'Run zupdate -y to download and apply the update.'
      return 0
   fi

   [[ -d $HOME/.zshrc.d && ! -L $HOME/.zshrc.d ]] || {
      print -u2 -r -- 'zupdate: expected a real ~/.zshrc.d directory'
      return 1
   }

   Lock="$HOME/.zshrc.d/.zupdate.lock"
   if ! command mkdir -- "$Lock" 2>/dev/null; then
      print -u2 -r -- "zupdate: another update may be running; inspect $Lock"
      return 1
   fi

   Directory=$(command mktemp -d) || { command rmdir -- "$Lock"; return 1; }
   Status=0
   print -r -- "Downloading release $Latest..."
   command curl -fLsS --retry 2 --connect-timeout 10 --max-time 120 \
      -o "$Directory/zshfiles.zip" "$ReleaseURL/download/$Latest/zshfiles.zip" || Status=1
   if (( Status == 0 )); then
      command curl -fLsS --retry 2 --connect-timeout 10 --max-time 60 \
         -o "$Directory/zshfiles.zip.sha256" "$ReleaseURL/download/$Latest/zshfiles.zip.sha256" || Status=1
   fi
   if (( Status == 0 )); then
      :zupdate:apply "$Latest" "$Directory" || Status=1
   fi

   command rm -rf -- "$Directory"
   command rmdir -- "$Lock" || Status=1
   return $Status
}

# A subshell isolates update options and variables from the live shell.
function zupdate
{
   ( :zupdate:main "$@" )
}
 ]] || continue
      [[ -n ${Present[$Relative]-} ]] || Removed+=("$Relative")
   done

   if (( ${#Updated} == 0 && ${#Removed} == 0 )); then
      print -r -- "zupdate: configuration already matches $Version"
      return 0
   fi

   Backup="$BackupBase/zupdate-$(command date -u +%Y%m%dT%H%M%SZ)-$$"
   command mkdir -m 700 -p -- "$Backup" || return 1

   # Complete backups before changing the installed files.
   for Relative in "${Updated[@]}" "${Removed[@]}"; do
      Source="$HOME/$Relative"
      if [[ -e $Source || -L $Source ]]; then
         Destination="$Backup/$Relative"
         command mkdir -p -- "${Destination:h}" || return 1
         command cp -a --no-dereference -- "$Source" "$Destination" || return 1
      fi
   done

   command mkdir -p -- "$HOME/.zshrc.d/examples" || return 1

   for Relative in "${Updated[@]}"; do
      Touched+=("$Relative")
      if ! :zupdate:replace "$Extracted/$Relative" "$HOME/$Relative"; then
         print -u2 -r -- "zupdate: failed to install $Relative; rolling back"
         :zupdate:rollback "$Backup" "${Touched[@]}" ||
            print -u2 -r -- "zupdate: rollback needs manual review: $Backup"
         return 1
      fi
   done

   for Relative in "${Removed[@]}"; do
      Touched+=("$Relative")
      if ! command rm -f -- "$HOME/$Relative"; then
         print -u2 -r -- "zupdate: failed to remove $Relative; rolling back"
         :zupdate:rollback "$Backup" "${Touched[@]}" ||
            print -u2 -r -- "zupdate: rollback needs manual review: $Backup"
         return 1
      fi
   done

   print -r -- "zupdate: installed $Version (${#Updated} updated, ${#Removed} removed)"
   print -r -- "Backup: $Backup"
   print -r -- 'Start a new Zsh session to activate the updated configuration.'
}

function :zupdate:main
{
   emulate -L zsh
   setopt null_glob
   umask 077

   local ReleaseURL='https://github.com/StephenAmerige/ubuntu-host-bootstrap/releases'
   local ApiURL='https://api.github.com/repos/StephenAmerige/ubuntu-host-bootstrap/releases/latest'
   local Current Latest Details Directory Lock Status
   local Mode=check
   local Usage='Usage: zupdate [-y|--check|--version|--help]'

   case ${1-} in
   --version)
      (( $# == 1 )) || { print -u2 -r -- "$Usage"; return 2; }
      :zupdate:version
      print -r -- "Installed Zsh configuration: $REPLY"
      return 0
      ;;
   --check|'')
      (( $# <= 1 )) || { print -u2 -r -- "$Usage"; return 2; }
      ;;
   -y)
      (( $# == 1 )) || { print -u2 -r -- "$Usage"; return 2; }
      Mode=apply
      ;;
   --help|-h)
      (( $# == 1 )) || { print -u2 -r -- "$Usage"; return 2; }
      print -rl -- "$Usage" '' \
         '  zupdate            Check for a newer release (no changes)' \
         '  zupdate --check    Same as zupdate' \
         '  zupdate -y         Download, verify, and install the latest release' \
         '  zupdate --version  Show the installed version'
      return 0
      ;;
   *)
      print -u2 -r -- "$Usage"
      return 2
      ;;
   esac

   for Details in curl unzip sha256sum sed grep cmp cp mv rm install mktemp; do
      whence -p "$Details" >/dev/null 2>&1 || {
         print -u2 -r -- "zupdate: required command not found: $Details"
         return 1
      }
   done

   :zupdate:version
   Current=$REPLY
   Details=$(command curl -fsSL --connect-timeout 10 --max-time 60 \
      -H 'Accept: application/vnd.github+json' "$ApiURL") || {
      print -u2 -r -- 'zupdate: unable to find the latest published GitHub release'
      return 1
   }

   if ! [[ $Details =~ '"tag_name"[[:space:]]*:[[:space:]]*"(v[0-9]+[.]([0-9]+)[.]([0-9]+))"' ]]; then
      print -u2 -r -- 'zupdate: latest release has no supported version tag'
      return 1
   fi
   Latest=$match[1]

   print -r -- "Installed: $Current"
   print -r -- "Latest:    $Latest"

   if [[ $Current == $Latest ]]; then
      print -r -- 'Zsh configuration is up to date.'
      return 0
   fi

   if [[ $Current == v<->.<->.<-> ]]; then
      local Highest
      Highest=$(print -rl -- "$Current" "$Latest" | command sort -V | command tail -n 1)
      if [[ $Highest == $Current ]]; then
         print -r -- 'Installed version is newer than the latest published release; no downgrade performed.'
         return 0
      fi
   fi

   if [[ $Mode == check ]]; then
      print -r -- 'An update is available.'
      print -r -- 'Run zupdate -y to download and apply the update.'
      return 0
   fi

   [[ -d $HOME/.zshrc.d && ! -L $HOME/.zshrc.d ]] || {
      print -u2 -r -- 'zupdate: expected a real ~/.zshrc.d directory'
      return 1
   }

   Lock="$HOME/.zshrc.d/.zupdate.lock"
   if ! command mkdir -- "$Lock" 2>/dev/null; then
      print -u2 -r -- "zupdate: another update may be running; inspect $Lock"
      return 1
   fi

   Directory=$(command mktemp -d) || { command rmdir -- "$Lock"; return 1; }
   Status=0
   print -r -- "Downloading release $Latest..."
   command curl -fLsS --retry 2 --connect-timeout 10 --max-time 120 \
      -o "$Directory/zshfiles.zip" "$ReleaseURL/download/$Latest/zshfiles.zip" || Status=1
   if (( Status == 0 )); then
      command curl -fLsS --retry 2 --connect-timeout 10 --max-time 60 \
         -o "$Directory/zshfiles.zip.sha256" "$ReleaseURL/download/$Latest/zshfiles.zip.sha256" || Status=1
   fi
   if (( Status == 0 )); then
      :zupdate:apply "$Latest" "$Directory" || Status=1
   fi

   command rm -rf -- "$Directory"
   command rmdir -- "$Lock" || Status=1
   return $Status
}

# A subshell isolates update options and variables from the live shell.
function zupdate
{
   ( :zupdate:main "$@" )
}
