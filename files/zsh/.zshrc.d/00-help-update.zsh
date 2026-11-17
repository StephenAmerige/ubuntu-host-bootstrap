########################################################################
# 00-help-update.zsh - Document the zupdate command.
#
# Keep this legacy filename: existing zupdate releases require this exact
# archive member while loading newer configuration versions.
########################################################################

# Re-sourcing ~/.zshrc (via the ".." alias) should drop the old topic
# immediately, without requiring a fresh Zsh process.
unfunction ':help:update' 2>/dev/null || true

function :help:zupdate
{
   print -P -- '%BZsh Configuration Updates%b'
   print

   :help-wrap-indent 3 \
      'The %Bzupdate%b command checks the latest published' \
      'ubuntu-host-bootstrap Zsh configuration release.' \
      'Installing an update requires explicit %B-y%b, without Git or sudo.'
   print

   :help-command 'zupdate --version'
   :help-wrap-indent 6 'Show the installed release version (or source).'
   print

   :help-command 'zupdate'
   :help-wrap-indent 6 \
      'Compare the installed version with the latest release without' \
      'making changes. If an update is available, suggest zupdate -y.'
   print

   :help-command 'zupdate --check'
   :help-wrap-indent 6 'Same as zupdate (check only).'
   print

   :help-command 'zupdate -y'
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
