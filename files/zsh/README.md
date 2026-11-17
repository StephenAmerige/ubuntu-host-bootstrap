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

`.zshrc` sources only files named `HH-name.zsh` where `HH` is two
lowercase hexadecimal digits (`00`–`ff`) and `name` is nonempty. It uses
a no-match-safe Zsh array so unrelated `*.zsh` files are not sourced.
Repository-managed files occupy `00`–`9f`; leave user customization in
the `a0`–`ff` range. Avoid editing managed files in-place because an
installation/update can replace them.

## GitHub Release ZIP and user updates

A versioned [GitHub Release](https://github.com/StephenAmerige/ubuntu-host-bootstrap/releases)
provides a ready-to-extract `zshfiles.zip` and `zshfiles.zip.sha256`.
Release tags use `vMAJOR.MINOR.PATCH`. The ZIP keeps the intentional entry
order: `.zshenv`, `.zshrc`, managed `.zshrc.d/[0-9]*.zsh` files, and
`.zshrc.d/examples/*.zsh`. It excludes the README and active user-owned
configuration in the `a0`–`ff` namespace.

For an initial direct ZIP installation, after a release has been published:

```bash
wget https://github.com/StephenAmerige/ubuntu-host-bootstrap/releases/latest/download/zshfiles.zip
wget https://github.com/StephenAmerige/ubuntu-host-bootstrap/releases/latest/download/zshfiles.zip.sha256
sha256sum -c zshfiles.zip.sha256
unzip -l zshfiles.zip
unzip -o zshfiles.zip -d "$HOME"
```

**Caution:** Direct extraction overwrites matching files without backups and
does not remove obsolete managed modules. Back up your configuration first.
The repository's `configure-shell-editor.sh` remains the safer administrative
installation method.

Once the release ZIP is installed, a new Zsh session provides:

```text
zupdate --version   Show the installed release version
zupdate             Check for the latest release (does not change files)
zupdate --check     Same check-only behavior as zupdate
zupdate -y          Download and install an available release
help zupdate        Explain the updater and its safeguards
```

`zupdate` and `zupdate --check` only compare versions and advise when an
update is available. Apply changes explicitly with **`zupdate -y`**.
**Transition for older installations:** If the installed updater does not yet
recognize `-y`, run its existing `zupdate` command **once** to install the
release with this new behavior. From then on, bare `zupdate` only checks and
`zupdate -y` explicitly installs. Avoid assuming `-y` works before upgrading.

The apply mode verifies the downloaded archive checksum and allowed members
before modifying files. It backs up and then **removes every top-level
numeric-prefixed entry** in `~/.zshrc.d/` and the **entire
`~/.zshrc.d/examples/` directory**, before installing the current
release-managed modules and examples. Obsolete files cannot linger.
The top-level user-reserved `a0`–`ff` modules are left untouched. A
failed installation attempts to restore the previous managed files and
examples from the backup. Do not put personal data in the `examples/`
directory; its contents are replaced on every installed update.

`zupdate -y` never uses `sudo` or performs network checks during shell
startup. Restart Zsh afterward to load the new modules. These features
require `curl`, `unzip`, and standard Ubuntu utilities; `zupdate`
does not install packages.

To build a ZIP locally from the repository source:

```bash
bash scripts/build-zsh-release.sh v1.0.0 dist/
```

The [release workflow](../../.github/workflows/release-zsh.yml)
publishes the ZIP and checksum when an existing version tag is pushed
(or the workflow is manually run for that tag). A pull request alone
does not publish a release.

## Interactive help

Run `help` for a brief introduction, **the installed Zsh configuration
version**, and the safe release commands (`zupdate` checks; `zupdate -y`
installs). It reads the local version marker; it does not contact GitHub or
check whether a newer release exists. Use `help -l` to list currently
available topics. More detailed topics include:

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
| `help zupdate` | Check for releases and explicitly apply them with `zupdate -y` |
| `help ztag` | Create and push guarded semantic-version Git tags |

Each help topic is automatically discovered from a `:help:<topic>`
function, so no central topic registry is needed.

## Semantic-version Git tagging

The `ztag` utility works with **any Git repository and Git remote**, not
just repositories that publish GitHub Releases:

```text
ztag -M 'Breaking configuration changes'      # v1.2.3 -> v2.0.0
ztag -m 'Add backward-compatible features'    # v1.2.3 -> v1.3.0
ztag -p 'Fix version-related bug'              # v1.2.3 -> v1.2.4
ztag -v1.5.0 'Publish version 1.5.0'           # select exact version
help ztag
```

The comment is a required single quoted argument. Only strict tags of the
form `vMAJOR.MINOR.PATCH` are considered; the highest **numeric** semantic
version, not the most recently created tag, determines the next version.
Create the very first version tag manually.

The current branch must be **main**, the Git working tree must have no staged,
unstaged, or untracked changes, and an `origin` remote must be configured.
Explicit versions must advance beyond the highest existing version. `ztag`
creates an annotated tag and pushes it to `origin`, but does not switch branches,
commit, fetch, pull, or depend on GitHub Actions. If the push fails, the
created local tag is retained for manual resolution.

In **this repository only**, pushing a `vMAJOR.MINOR.PATCH` tag triggers the
Zsh GitHub Release workflow. A user still running `v1.0.0` must publish the
next release using ordinary `git tag` and `git push` commands; after running
`zupdate -y` to install that release, `ztag` becomes available for later versions.

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
