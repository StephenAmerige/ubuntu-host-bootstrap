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
apt-get update -qq
apt-get install -y -qq --no-install-recommends zsh vim

useradd -m -s /bin/bash shell-editor-smoke
home=/home/shell-editor-smoke
chmod 0700 "$home"
mkdir -p "$home/.zshrc.d"
echo 'preserve me' > "$home/.zshrc.d/a0-custom.zsh"
echo 'remove me' > "$home/.zshrc.d/90-obsolete.zsh"
chown -R shell-editor-smoke:shell-editor-smoke "$home"

# Unprivileged mode must never touch /etc/skel, home ownership, or sudo/SSH.
runuser -u shell-editor-smoke -- "$PWD/configure-shell-editor.sh" \
  --user shell-editor-smoke --dry-run >/dev/null
runuser -u shell-editor-smoke -- "$PWD/configure-shell-editor.sh" \
  --user shell-editor-smoke >/tmp/shell-editor-smoke-first.log

[[ $(stat -c %a "$home") == 700 ]]
[[ $(stat -c %U "$home/.zshrc") == shell-editor-smoke ]]
[[ $(stat -c %U "$home/.vimrc") == shell-editor-smoke ]]
[[ $(cat "$home/.zshrc.d/a0-custom.zsh") == 'preserve me' ]]
[[ ! -e "$home/.zshrc.d/90-obsolete.zsh" ]]
[[ -f "$home/.vim/colors/summerfruit256.vim" ]]
[[ -f "$home/.vim/template/help" ]]
[[ -L "$home/.gvimrc" ]]
find "$home/.config-backups" -name '90-obsolete.zsh' | grep -q .

runuser -u shell-editor-smoke -- "$PWD/configure-shell-editor.sh" \
  --user shell-editor-smoke >/tmp/shell-editor-smoke-second.log
grep -q 'files updated=0; managed files removed=0; backups=0' \
   /tmp/shell-editor-smoke-second.log

# A non-sudo user must not be able to target root or any other user.
if runuser -u shell-editor-smoke -- "$PWD/configure-shell-editor.sh" \
   --user root >/dev/null 2>&1; then
   echo 'ERROR: cross-user unprivileged configuration was accepted' >&2
   exit 1
fi

# Root dry run exercises the privileged planning branch without host mutation.
./configure-shell-editor.sh --dry-run --user shell-editor-smoke >/dev/null

echo 'Unprivileged installation, namespace, backup, idempotence and privileged dry-run checks passed.'
