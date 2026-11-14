#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Safe smoke test: run on a disposable Ubuntu host/CI runner, never production.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
bash -n configure-shell-editor.sh vm-bootstrap.sh provision-vm.sh create-user.sh create-shared-group.sh
./configure-shell-editor.sh --help >/dev/null
test -f files/vim/runtime/vimfiles/colors/summerfruit256.vim
# Confirm no existing provisioning script invokes the new tool implicitly.
! grep -E '(^|[[:space:]])(source|bash|exec)[[:space:]]+.*configure-shell-editor' vm-bootstrap.sh provision-vm.sh example-invocation.sh
echo 'Syntax and OpenStack bootstrap isolation checks passed.'
