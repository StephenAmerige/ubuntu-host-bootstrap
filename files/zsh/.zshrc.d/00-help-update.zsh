########################################################################
# 00-help-update.zsh - Document user-controlled GitHub Release updates.
########################################################################

function :help:update
{
   print -P -- '%BZsh Configuration Updates%b'
   print

   :help-wrap-indent 3 \
      'The %Bzupdate%b command updates the installed Zsh configuration' \
      'from the latest published ubuntu-host-bootstrap GitHub Release.' \
      'It runs only when requested, without Git or sudo.'
   print

   :help-command 'zupdate --version'
   :help-wrap-indent 6 'Show the installed release version (or source).'
   print

   :help-command 'zupdate --check'
   :help-wrap-indent 6 'Compare the installed version with the latest release.'
   print

   :help-command 'zupdate'
   :help-wrap-indent 6 \
      'Download and verify the latest zshfiles.zip and checksum, then' \
      'replace managed files and remove obsolete managed modules.'
   print

   :help-wrap-indent 3 \
      'Existing managed files are backed up under' \
      '%B$HOME/.config-backups/ubuntu-host-bootstrap/%b before changes.' \
      'Personal Zsh modules in the %Ba0-ff%b namespace are preserved.' \
      'Updates do not install Zsh, Vim, Conda, or other packages.'
   print

   :help-wrap-indent 3 \
      'Start a new Zsh session after updating to activate the new' \
      'configuration. Internet access, curl, unzip, and sha256sum are' \
      'required. No automatic checks are made during shell startup.'
   print

   :help-example 'https://github.com/StephenAmerige/ubuntu-host-bootstrap/releases'
}
