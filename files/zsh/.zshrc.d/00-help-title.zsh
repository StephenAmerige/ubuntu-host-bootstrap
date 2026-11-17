########################################################################
#
# 00-help-title.zsh
#
# Explain terminal window/tab title management.
#
########################################################################

function :help:title
{
   print -P -- "%BTerminal Titles%b"
   print

   :help-wrap-indent 3 \
      "The %Btitle%b command manages the terminal window or tab" \
      "title independently of the shell prompt. It sends an OSC 2" \
      "title sequence in interactive terminal sessions."
   print

   print -P -- "%BCommands%b"
   print

   :help-command "title"
   :help-wrap-indent 6 \
      "Display the current mode and fixed text, if any."
   print

   :help-command "title host"
   :help-wrap-indent 6 \
      "Use the current hostname. This is the default and refreshes" \
      "before every prompt."
   print

   :help-command "title fixed <text>"
   :help-wrap-indent 6 \
      "Set a fixed title string."
   print

   :help-command "title none"
   :help-wrap-indent 6 \
      "Stop managing the title and clear the previously set title."
   print

   print -P -- "%BExamples%b"
   print

   :help-example "title host"
   :help-example "title fixed Atlas development"
   :help-example "title"
   :help-example "title none"
   print

   :help-wrap-indent 3 \
      "Terminal emulators differ in how they display or override" \
      "shell-supplied titles."
}
