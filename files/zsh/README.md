# Zsh developer environment

This directory provides the repository-managed Zsh configuration from
[ubuntu-host-bootstrap](https://github.com/StephenAmerige/ubuntu-host-bootstrap).
It adds an adaptive prompt, Python environment support, Slurm session helpers,
directory navigation, command-path utilities, and terminal customization.

## Installing or updating

From the repository root, use the existing installer for an Ubuntu account:

```bash
./configure-shell-editor.sh --dry-run
./configure-shell-editor.sh
```

With appropriate sudo/root privileges the installer can also update system
packages, `/etc/skel`, and other users. It accepts `--user` and `--set-shell`;
review the dry run and `--help` before applying. It backs up replaced files
and preserves per-user configuration. Existing root provisioning workflows
may install the same Zsh files without this standalone installer.

## Layout

| Path | Purpose |
| --- | --- |
| `.zshenv` | Early environment configuration |
| `.zshrc` | Interactive shell options, aliases and module loader |
| `.zshrc.d/00-help.zsh` | Short `help` entrypoint and automatic discovery |
| `.zshrc.d/00-help-*.zsh` | Focused help topics |
| `.zshrc.d/01-*.zsh` through `99-*.zsh` | Managed shell features |
| `.zshrc.d/examples/` | Templates for user-owned configuration |

`.zshrc` sources numbered `.zshrc.d/*.zsh` files in filename order.
Repository-managed files occupy `00`–`9f`; leave user customization in
the `a0`–`ff` range. Avoid editing managed files in-place because an
installation/update can replace them.

## Interactive help

Run `help` for a brief introduction and four examples, or `help -l`
to list currently available topics. More detailed topics include:

| Command | Content |
| --- | --- |
| `help zsh` | Overview of the shell environment |
| `help python` | venv/Conda activation and configuration |
| `help session` | Slurm interactive sessions |
| `help prompt` | Developer prompt, colors and layout |
| `help timer` | Optional prompt timers |
| `help tags` | Persistent directory tags |
| `help directories` | Directory stack navigation |
| `help path` | PATH and MANPATH helpers |
| `help title` | Terminal window/tab title |

Each help topic is automatically discovered from a `:help:<topic>`
function, so no central topic registry is needed.

## Per-user configuration

Examples are in `.zshrc.d/examples/`:

- `ff-user.zsh` — prompt spacing, Slurm configuration, PATH, timezone.
- `e0-python-env.zsh` — ordered `VENV_DIRS` and `CONDA_DIRS`, and optional `CONDA_MODULE`.
- `a0-tags.zsh` — persistent directory tags managed by `tag`/`rmtag`.

`session` requires `_SessionAccount` and `_SessionShell`; `_SessionPartition`
is optional. It requires an installed Slurm `srun`. Python environment
activation requires existing Python venv/Conda installations; these
utilities do not create environments or modify Slurm cluster settings.

Source: https://github.com/StephenAmerige/ubuntu-host-bootstrap/tree/main/files/zsh/
