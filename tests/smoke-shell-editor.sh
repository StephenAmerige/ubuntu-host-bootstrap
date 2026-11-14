#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Safe isolated smoke test: intended for a disposable Ubuntu CI runner.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

for file in configure-shell-editor.sh vm-bootstrap.sh provision-vm.sh \
            create-user.sh create-shared-group.sh example-invocation.sh; do
   bash -n "$file"
done
./configure-shell-editor.sh --help >/dev/null

# Confirm OpenStack provisioning remains separate and unchanged by this utility.
! grep -E '(^|[[:space:]])(source|bash|exec)[[:space:]]+.*configure-shell-editor' \
   vm-bootstrap.sh provision-vm.sh example-invocation.sh

if [[ ${1:-} != --integration ]]; then
   echo 'Syntax and provisioning-isolation checks passed.'
   exit 0
fi

# The integration portion must run on a disposable CI runner with root access.
(( EUID == 0 )) || { echo 'Integration tests require root' >&2; exit 1; }
# GitHub's /home/runner directory may be private to the runner account.
# Copy sources into a traversable temporary checkout for the test user.
testrepo=$(mktemp -d /tmp/ubuntu-host-bootstrap-test.XXXXXX)
trap 'rm -rf -- "$testrepo"; rm -f /etc/sudoers.d/91-shell-editor-smoke' EXIT
chmod 0755 "$testrepo"
cp -a configure-shell-editor.sh files "$testrepo/"
apt-get update -qq
apt-get install -y -qq --no-install-recommends zsh vim

useradd -m -s /bin/bash shell-editor-smoke
home=/home/shell-editor-smoke
chmod 0700 "$home"
mkdir -p "$home/.zshrc.d"
echo 'preserve me' > "$home/.zshrc.d/a0-custom.zsh"
echo 'remove me' > "$home/.zshrc.d/90-obsolete.zsh"
chown -R shell-editor-smoke:shell-editor-smoke "$home"
chmod 0700 "$home/.zshrc.d"

# Unprivileged mode must never touch /etc/skel, home ownership, or sudo/SSH.
# A dry run must not fall through to an interactive sudo password prompt.
# Put a fake sudo first in PATH: -n is safe, every other invocation leaves
# a marker and fails the test.
mkdir -p "$testrepo/testbin"
cat > "$testrepo/testbin/sudo" <<'FAKE_SUDO'
#!/bin/sh
if [ "${1:-}" = -n ]; then
   exit 1
fi
: > "$HOME/sudo-interactive-was-called"
exit 77
FAKE_SUDO
chmod 0755 "$testrepo/testbin/sudo"
runuser -u shell-editor-smoke -- env PATH="$testrepo/testbin:$PATH" \
  "$testrepo/configure-shell-editor.sh" --dry-run --user shell-editor-smoke \
  >/tmp/shell-editor-dry-run.log
[[ ! -e "$home/sudo-interactive-was-called" ]]
grep -q 'Previewing user-local changes only' /tmp/shell-editor-dry-run.log

runuser -u shell-editor-smoke -- "$testrepo/configure-shell-editor.sh" \
  --user shell-editor-smoke --dry-run >/dev/null
runuser -u shell-editor-smoke -- "$testrepo/configure-shell-editor.sh" \
  --user shell-editor-smoke >/tmp/shell-editor-smoke-first.log

[[ $(stat -c %a "$home") == 700 ]]
[[ $(stat -c %a "$home/.zshrc.d") == 700 ]]
[[ $(stat -c %U "$home/.zshrc") == shell-editor-smoke ]]
[[ $(stat -c %U "$home/.vimrc") == shell-editor-smoke ]]
[[ $(cat "$home/.zshrc.d/a0-custom.zsh") == 'preserve me' ]]
[[ ! -e "$home/.zshrc.d/90-obsolete.zsh" ]]
[[ -f "$home/.vim/colors/summerfruit256.vim" ]]
[[ -f "$home/.vim/template/help" ]]
[[ -L "$home/.gvimrc" ]]
find "$home/.config-backups" -name '90-obsolete.zsh' | grep -q .

runuser -u shell-editor-smoke -- "$testrepo/configure-shell-editor.sh" \
  --user shell-editor-smoke >/tmp/shell-editor-smoke-second.log
grep -q 'files updated=0; managed files removed=0; backups=0' \
   /tmp/shell-editor-smoke-second.log

# A non-sudo user must not be able to target root or any other user.
if runuser -u shell-editor-smoke -- "$testrepo/configure-shell-editor.sh" \
   --user root >/dev/null 2>&1; then
   echo 'ERROR: cross-user unprivileged configuration was accepted' >&2
   exit 1
fi

# Verify the sudo NOPASSWD path also uses noninteractive elevation.
# This temporary policy is confined to the disposable CI runner and is
# deleted by the test cleanup trap.
printf '%s\n' 'shell-editor-smoke ALL=(ALL:ALL) NOPASSWD: ALL' \
   >/etc/sudoers.d/91-shell-editor-smoke
chmod 0440 /etc/sudoers.d/91-shell-editor-smoke
visudo -cf /etc/sudoers.d/91-shell-editor-smoke
runuser -u shell-editor-smoke -- sudo -n true
runuser -u shell-editor-smoke -- "$testrepo/configure-shell-editor.sh" \
   --dry-run --user shell-editor-smoke >/tmp/shell-editor-nopasswd.log
grep -q 'Using privileged mode' /tmp/shell-editor-nopasswd.log
rm -f /etc/sudoers.d/91-shell-editor-smoke

# Root dry run exercises the privileged planning branch without host mutation.
./configure-shell-editor.sh --dry-run --user shell-editor-smoke >/dev/null

# Privileged installation also refreshes /etc/skel and the shared Vim runtime.
# It must leave this selected user's personal Vim override untouched.
echo 'let g:personal_override = 1' > "$home/.vim/plugin/rc.vim"
chown shell-editor-smoke:shell-editor-smoke "$home/.vim/plugin/rc.vim"
./configure-shell-editor.sh --user shell-editor-smoke   >/tmp/shell-editor-smoke-root.log
[[ -f /etc/skel/.zshrc ]]
[[ -f /etc/skel/.vimrc ]]
[[ -f /usr/share/vim/vimfiles/colors/summerfruit256.vim ]]
[[ -f /usr/share/vim/template/help ]]
[[ $(stat -c %a "$home") == 700 ]]
[[ $(cat "$home/.vim/plugin/rc.vim") == 'let g:personal_override = 1' ]]
[[ $(cat "$home/.zshrc.d/a0-custom.zsh") == 'preserve me' ]]
./configure-shell-editor.sh --user shell-editor-smoke    >/tmp/shell-editor-smoke-root-rerun.log
grep -q 'files updated=0; managed files removed=0; backups=0'    /tmp/shell-editor-smoke-root-rerun.log

echo 'Unprivileged and privileged installation, namespace, backup, idempotence and isolation checks passed.'
