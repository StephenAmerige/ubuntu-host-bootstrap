########################################################################
#
# 00-help-python.zsh
#
# Explain Python venv and Conda management.
#
########################################################################

function :help:python
{
   print -P -- "%BPython Environments%b"
   print

   :help-wrap-indent 3 \
      "The %Bvstart%b and %Bvstop%b commands activate or deactivate" \
      "Python venv and Conda environments in this shell. They do not" \
      "create environments or install Python/Conda."
   print

   print -P -- "%BCommands%b"
   print

   :help-command "vstart"
   :help-wrap-indent 6 \
      "Activate the environment named after the current Git worktree."
   print

   :help-command "vstart name"
   :help-wrap-indent 6 \
      "Find the named environment and activate it."
   print

   :help-command "vstart -v|--venv [name]"
   :help-wrap-indent 6 \
      "Select a Python venv. Without name, use the Git worktree name."
   print

   :help-command "vstart -c|--conda [name]"
   :help-wrap-indent 6 \
      "Select a Conda environment, optionally by name."
   print

   :help-command "vstop"
   :help-wrap-indent 6 \
      "Deactivate the current venv or Conda environment."
   print

   print -P -- "%BSearch directories%b"
   print

   :help-wrap-indent 3 \
      "Configure %BVENV_DIRS%b and %BCONDA_DIRS%b as ordered arrays" \
      "in %B$HOME/.zshrc.d/e0-python-env.zsh%b, based on the supplied" \
      "example. No locations are searched until configured."
   print

   :help-example "typeset -ga VENV_DIRS CONDA_DIRS"
   :help-example 'VENV_DIRS=( "$HOME/.venv" /opt/venv )'
   :help-example 'CONDA_DIRS=( "$HOME/.conda-envs" )'
   print

   :help-wrap-indent 3 \
      "A venv named %Bmyproject%b contains %Bbin/activate%b inside" \
      "its environment directory. A Conda environment contains" \
      "%Bconda-meta%b. Conda may optionally be loaded from the" \
      "site-specific %BCONDA_MODULE%b configured in the same file."
   print

   print -P -- "%BGit naming and ambiguity%b"
   print

   :help-wrap-indent 3 \
      "Without a name, %Bvstart%b uses the current Git worktree" \
      "basename. If the selected name is present in both venv and" \
      "Conda locations, choose a type explicitly."
   print

   :help-example "cd ~/projects/myproject"
   :help-example "vstart"
   :help-example "vstart --venv"
   :help-example "vstart --conda myproject"
   print

   print -P -- "%BPrompt indicators%b"
   print

   :help-wrap-indent 3 \
      "When a Git-matching environment is available but inactive," \
      "the prompt shows brown %Bvenv%b, %Bconda%b, or %Bvenv+conda%b." \
      "An active venv is blue and an active Conda environment is" \
      "orange. The Zsh prompt owns these indicators."
   print

   :help-command "help prompt"
   :help-wrap-indent 6 \
      "Show complete prompt color and layout guidance."
}
