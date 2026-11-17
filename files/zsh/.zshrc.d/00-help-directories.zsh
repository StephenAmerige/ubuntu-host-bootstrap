########################################################################
#
# 00-help-directories.zsh
#
# Explain directory-stack navigation.
#
########################################################################

function :help:directories
{
   print -P -- "%BDirectory Stack%b"
   print

   :help-wrap-indent 3 \
      "The directory stack keeps recently visited locations available" \
      "for quick navigation, using Zsh pushd/popd behind convenient" \
      "wrappers and a numbered listing."
   print

   print -P -- "%BCommands%b"
   print

   :help-command "d"
   :help-wrap-indent 6 \
      "List the directory stack with numbered entries."
   print

   :help-command "push directory"
   :help-wrap-indent 6 \
      "Change directory, update the stack, and display it."
   print

   :help-command "push -r directory"
   :help-wrap-indent 6 \
      "Resolve the pathname before pushing."
   print

   :help-command "pop"
   :help-wrap-indent 6 \
      "Remove the current stack entry and display the stack."
   print

   :help-command "r"
   :help-wrap-indent 6 \
      "Rotate to the next stack entry."
   print

   :help-command "r number"
   :help-wrap-indent 6 \
      "Rotate to the numbered entry."
   print

   print -P -- "%BExamples%b"
   print

   :help-example "push ~/projects"
   :help-example "push /tmp"
   :help-example "d"
   :help-example "r 1"
   :help-example "pop"
   print

   :help-wrap-indent 3 \
      "This transient stack is separate from persistent named-directory" \
      "tags. Duplicate stack entries are suppressed."
   print

   :help-command "help tags"
   :help-wrap-indent 6 \
      "Learn how to create named shortcuts such as ~project."
}
