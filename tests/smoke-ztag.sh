#!/usr/bin/env bash
# Exercise ztag in disposable local repositories with a bare origin.
set -euo pipefail

Root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
Module="$Root/files/zsh/.zshrc.d/96-ztag.zsh"
Temp=$(mktemp -d)
trap 'rm -rf -- "$Temp"' EXIT
Work="$Temp/work"
Origin="$Temp/origin.git"

zsh -n "$Module"
zsh -n "$Root/files/zsh/.zshrc.d/00-help-ztag.zsh"

run_on() {
   local directory=$1
   shift
   (cd -- "$directory" && zsh -f -c 'source "$1"; shift; ztag "$@"' ztag-test "$Module" "$@")
}

expect_failure() {
   local before after
   before=$(git -C "$Work" tag --list)
   if run_on "$Work" "$@" > "$Temp/output" 2>&1; then
      printf 'ztag unexpectedly succeeded: %s\n' "$*" >&2
      exit 1
   fi
   after=$(git -C "$Work" tag --list)
   [[ $before == "$after" ]] || {
      printf 'ztag created a tag despite a rejected request: %s\n' "$*" >&2
      exit 1
   }
}

verify_tag() {
   local tag=$1 comment=$2
   git -C "$Work" show-ref --verify --quiet "refs/tags/$tag"
   git --git-dir="$Origin" show-ref --verify --quiet "refs/tags/$tag"
   [[ $(git -C "$Work" cat-file -t "refs/tags/$tag") == tag ]]
   [[ $(git -C "$Work" for-each-ref --format='%(contents)' "refs/tags/$tag") == "$comment" ]]
}

git init --quiet --bare -b main "$Origin"
git init --quiet -b main "$Work"
git -C "$Work" config user.name 'Zsh Test'
git -C "$Work" config user.email 'zsh-test@example.invalid'
printf 'initial contents\n' > "$Work/tracked.txt"
git -C "$Work" add tracked.txt
git -C "$Work" commit --quiet -m initial

# Non-repository invocation and first-version bootstrap are both rejected.
if run_on "$Temp" -p 'Outside a repository' > "$Temp/output" 2>&1; then
   echo 'ztag succeeded outside a repository' >&2
   exit 1
fi
git -C "$Work" remote add origin "$Origin"
git -C "$Work" tag -a v1.10.0-rc1 -m 'Not a full release'
expect_failure -p 'No version tags'
grep -q 'first tag manually' "$Temp/output"

# Use intentionally out-of-order numeric versions and unrelated tags.
git -C "$Work" tag -a v1.2.3 -m 'Initial release'
git -C "$Work" tag -a v1.10.0 -m 'Latest version'
git -C "$Work" tag -a v1.9.0 -m 'Older release'
git -C "$Work" tag -a unrelated -m 'Other tag'
git -C "$Work" push --quiet origin main --tags

expect_failure -m ''
expect_failure -m '     '
expect_failure -x 'Unknown option'
expect_failure -v '1.11.0'
expect_failure -v01.11.0 'Invalid leading zero'
expect_failure -v1.10.0 'Duplicate'
expect_failure -v1.9.5 'Older than latest'

git -C "$Work" switch --quiet -c feature/not-main
expect_failure -p 'Wrong branch'
git -C "$Work" switch --quiet main

git -C "$Work" switch --quiet --detach
expect_failure -p 'Detached HEAD'
git -C "$Work" switch --quiet main

printf 'untracked\n' > "$Work/untracked.txt"
expect_failure -p 'Untracked change'
rm -- "$Work/untracked.txt"

printf 'unstaged\n' >> "$Work/tracked.txt"
expect_failure -p 'Unstaged change'
git -C "$Work" add tracked.txt
expect_failure -p 'Staged change'
git -C "$Work" restore --staged --worktree tracked.txt

git -C "$Work" remote remove origin
expect_failure -p 'Missing origin'
git -C "$Work" remote add origin "$Origin"

run_on "$Work" -p 'Patch fix'
verify_tag v1.10.1 'Patch fix'
run_on "$Work" -m 'Backward-compatible feature'
verify_tag v1.11.0 'Backward-compatible feature'
run_on "$Work" -M 'Breaking change'
verify_tag v2.0.0 'Breaking change'
run_on "$Work" -v2.4.0 'Exact version release'
verify_tag v2.4.0 'Exact version release'

# When the remote push fails, leave the new local annotated tag in place.
git -C "$Work" remote set-url origin "$Temp/missing-remote.git"
if run_on "$Work" -p 'Push failure' > "$Temp/output" 2>&1; then
   echo 'ztag unexpectedly pushed to missing origin' >&2
   exit 1
fi
grep -q 'local tag v2.4.1 remains available' "$Temp/output"
[[ $(git -C "$Work" cat-file -t refs/tags/v2.4.1) == tag ]]
! git --git-dir="$Origin" show-ref --verify --quiet refs/tags/v2.4.1

echo 'ztag: all Git tagging safeguards and push checks passed'
