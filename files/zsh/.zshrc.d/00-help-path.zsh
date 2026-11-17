########################################################################
#
# 00-help-path.zsh
#
# Explain PATH lookup and modification helpers.
#
########################################################################

function :help:path
{
   print -P -- "%BCommand Paths%b"
   print

   :help-wrap-indent 3 \
      "Use %Bpath%b to inspect the PATH search list or find executable" \
      "files. Use %Baddpath%b and %Baddmanpath%b to update ordered" \
      "search paths without duplicate entries."
   print

   print -P -- "%BLookup%b"
   print

   :help-command "path"
   :help-wrap-indent 6 \
      "Print PATH entries, one directory per line."
   print

   :help-command "path command ..."
   :help-wrap-indent 6 \
      "Find the first executable pathname for each command."
   print

   :help-command "path -a command ..."
   :help-wrap-indent 6 \
      "Show all executable matches."
   print

   :help-command "path -d command ..."
   :help-wrap-indent 6 \
      "Show only the matching directory names."
   print

   :help-command "path -ad command ..."
   :help-wrap-indent 6 \
      "Combine all-matches and directory-only options."
   print

   print -P -- "%BConfiguration%b"
   print

   :help-command "addpath before directory ..."
   :help-command "addpath after directory ..."
   :help-wrap-indent 6 \
      "Give the specified directories higher or lower PATH priority."
   print

   :help-command "addmanpath before directory ..."
   :help-command "addmanpath after directory ..."
   :help-wrap-indent 6 \
      "Perform the equivalent operations on MANPATH."
   print

   :help-wrap-indent 3 \
      "These commands update the current shell. For persistent" \
      "customizations, edit %B$HOME/.zshrc.d/ff-user.zsh%b."
   print

   print -P -- "%BExamples%b"
   print

   :help-example "path zsh"
   :help-example "path -a python3"
   :help-example 'addpath before "$HOME/bin"'
   :help-example "addmanpath after /opt/vendor/share/man"
}
