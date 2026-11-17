########################################################################
#
# 00-help-ztag.zsh
#
# Explain guarded semantic-version tagging for Git repositories.
#
########################################################################

function :help:ztag
{
   print -P -- '%BGit Semantic Version Tags%b'
   print

   :help-wrap-indent 3 \
      'The %Bztag%b command creates an annotated semantic-version Git tag' \
      'on the current %Bmain%b branch and pushes it to the configured' \
      '%Borigin%b remote. It works with any Git remote; it does not depend' \
      'on GitHub or release automation.'
   print

   print -P -- '%BUsage%b'
   print

   :help-command 'ztag {-M|-m|-p|-v<major>.<minor>.<patch>} <comment>'
   print

   :help-command '-M'
   :help-wrap-indent 6 \
      'Increment MAJOR and reset MINOR and PATCH to zero.'
   print

   :help-command '-m'
   :help-wrap-indent 6 \
      'Increment MINOR and reset PATCH to zero.'
   print

   :help-command '-p'
   :help-wrap-indent 6 \
      'Increment PATCH.'
   print

   :help-command '-v<major>.<minor>.<patch>'
   :help-wrap-indent 6 \
      'Use an explicit version, for example %B-v1.4.0%b. The version is' \
      'attached to -v, without a space.'
   print

   :help-wrap-indent 3 \
      'The required comment is one argument. Quote comments containing' \
      'spaces. Versions use the form %BvMAJOR.MINOR.PATCH%b and must be' \
      'strictly greater than the highest existing version.'
   print

   print -P -- '%BExamples%b'
   print

   :help-example "ztag -p 'Fix Zsh prompt layout'"
   :help-example "ztag -m 'Add Git tag utility'"
   :help-example "ztag -M 'Change incompatible configuration defaults'"
   :help-example "ztag -v2.1.0 'Publish version 2.1.0'"
   print

   print -P -- '%BRequired conditions%b'
   print

   :help-wrap-indent 3 \
      'You must be inside a Git working tree, on the %Bmain%b branch,' \
      'with no staged, unstaged, or untracked changes. Ignored files' \
      'do not count as untracked changes.'
   print

   :help-wrap-indent 3 \
      'At least one valid vMAJOR.MINOR.PATCH tag must already exist' \
      'locally. Create the first tag manually. The %Borigin%b remote' \
      'must be configured. Tags are compared numerically, not by' \
      'creation date; unrelated tag names are ignored.'
   print

   print -P -- '%BActions%b'
   print

   :help-example "git tag -a <version> -m '<comment>'"
   :help-example "git push origin <version>"
   print

   :help-wrap-indent 3 \
      'The command does not switch branches, fetch or pull, or create' \
      'commits. Ensure main is the intended revision before tagging.' \
      'If the push fails, the local tag is retained and the error is' \
      'reported for manual resolution.'
}
