# agents.sb — macOS Sandbox Profile

`agents.sb` is a [sandbox-exec](https://www.unix.com/man-page/osx/1/sandbox-exec/) profile that constrains AI coding agents (Claude Code, openCode) to a defined set of filesystem, process, and network permissions. It is applied at launch by `sandbox-run` and has no effect on processes started outside of it.

> **Deprecation notice.** `sandbox-exec` and the underlying `sandbox_init` API are formally deprecated since macOS 10.15. They continue to work on current releases but Apple may remove them without notice. There is no supported CLI replacement — App Sandbox requires code signing and does not apply to CLI tools. Monitor macOS release notes.

## How it works

The profile opens with `(deny default)`, which blocks every operation not explicitly permitted. Rules are evaluated with **last-match-wins** semantics within each rule class, so targeted `(deny ...)` blocks placed at the bottom of the file override any broader `(allow ...)` rules above them.

`SANDBOX_HOME_DIR` is a placeholder in the profile that `sandbox-run` substitutes with the real `$HOME` at launch time via `sed`, making the profile portable across machines without modification.

## Usage

```zsh
sandbox-run claude [args...]
sandbox-run opencode [args...]
```

`sandbox-run` renders the profile to a temp file (substituting `SANDBOX_HOME_DIR`), then calls `sandbox-exec -f <tmpfile> <agent-binary> [args...]`. The temp file is deleted on exit.

`sandbox-run` always injects ancestor `file-read*` literals and a `file-read* file-write*` subpath rule for the current working directory, scoping write access to that directory and its descendants. Running from `~/dev/myproject` grants write only to that project; running from `~/dotfiles` grants write to the entire dotfiles tree. Paths containing `"` or `\` are rejected to prevent SBPL injection.

## Permissions reference

### File system

| Resource | Permission | Notes |
|---|---|---|
| `/`, `/Users`, `HOME`, `~/Library` | read | macOS requires parent directory read access to resolve file paths inside them — without these, even explicitly allowed subpaths cannot be opened |
| `/usr`, `/bin`, `/sbin`, `/System/Library`, `/Library/Developer`, `/Library/Frameworks`, `/opt` | read | Agents invoke compilers, interpreters, and system utilities from these directories at runtime; write access is withheld so agents cannot replace host binaries |
| `/Library/Preferences/.GlobalPreferences.plist`, `/Library/Preferences/com.apple.networkd.plist` | read | Many frameworks read locale and time-zone settings at startup; the networkd plist provides DNS resolver bootstrap |
| `/private/etc/hosts`, `/private/etc/resolv.conf`, `/private/etc/ssl` | read | Hostname lookups and TLS certificate validation require these at runtime; blocking them breaks `curl`, `git`, and virtually every networked tool |
| `/tmp`, `/private/tmp`, `/var/folders` | read + write | Agents need temporary scratch space for build artifacts, intermediate files, and tool output. Launchd listener sockets (`com.apple.launchd.*/Listeners`) are explicitly denied to block SSH agent socket access |
| `/dev/stdout`, `/dev/stderr`, `/dev/tty`, `/dev/ptmx`, `/dev/tty[s]*`, `/dev/pty*`, `/dev/fd` | read + write + ioctl | Standard I/O and PTY devices — required for interactive terminal agents to render output and handle terminal control sequences |
| `/dev/urandom`, `/dev/random`, `/dev/zero` | read | Many CLIs and crypto libraries read entropy at startup; `/dev/zero` is used for memory initialization by some system libraries |
| `~/.homebrew` | read | Agents need to invoke Homebrew-installed binaries and link against their libraries; write is withheld so agents cannot replace host tooling |
| `~/.nvm`, `~/.volta`, npm/pnpm/yarn/turbo caches | read + write | Agents running npm, yarn, or pnpm must download and cache packages during installs; write access is required for those workflows |
| `~/.npmrc` | read | npm reads this file to authenticate with private registries; write is withheld so agents cannot redirect or rotate credentials |
| `~/.cache/pip`, `~/.config/pip`, `~/.virtualenvs`, `~/.python_history` | read + write | pip downloads and caches packages here; virtualenvs hold project-scoped Python installs that agents create and modify during setup |
| `~/.pypirc` | read | `twine` and pip read this to authenticate with PyPI and private package indexes; write is withheld so agents cannot rotate credentials |
| `~/.skills`, `~/.agents`, `~/AGENTS.md` | read | Generic agent and skill definitions loaded at startup; read-only so agents cannot alter shared instructions |
| `~/.claude/agents`, `~/.claude/skills`, `~/CLAUDE.md` | read | Claude Code loads these at startup to configure agent behavior; read-only and write-denied by the security overrides below |
| `~/.gitconfig`, `~/.gitignore`, `~/.config/git`, `~/.gitattributes` | read | Git reads identity and ignore rules on every operation; without this, commits fail and global ignores do not apply |
| `~/.ssh/config`, `~/.ssh/known_hosts` | read | Git over SSH and remote operations need to resolve host aliases and verify server identity; private keys are denied separately |
| `~/.ssh/id_*` | **deny** | All SSH private keys blocked regardless of any earlier broad allows |
| `~/.gnupg` | **deny** | GnuPG keyring and private keys fully blocked |
| `~/.aws`, `~/.azure`, `~/.kube`, `~/.config/gcloud` | **deny** | Cloud provider credentials fully blocked |
| `~/.config/gh` | read | `gh` reads OAuth tokens from here to authenticate API requests; write is blocked to prevent silent token rotation |
| `~/.cache/gh`, `~/.local/share/gh`, `~/.local/state/gh` | read + write | GH CLI writes cache, command history, and API response state here during normal operation |
| `~/Library/Keychains`, `~/Library/Preferences/com.apple.security.plist` | read + write | Required for Claude Code OAuth token refresh — the macOS Keychain API needs read/write access to update stored tokens |
| `/Library/Keychains/System.keychain`, `/private/var/db/mds` | read | `securityd` requires these paths to resolve IPC handles during keychain operations |
| `~/.cache/claude`, `~/.claude`, `~/.config/claude`, `~/.local/state/claude`, `~/.local/share/claude`, `~/.mcp.json` | read + write | Claude Code reads and writes session state, MCP config, and conversation data here; intentionally broad to avoid breaking internal I/O |
| `~/.claude/CLAUDE.md`, `~/.claude/settings.json`, `~/.claude/settings.local.json`, `~/.claude/agents`, `~/.claude/skills` | **deny write** | Self-modification guard — agents cannot alter their own global instructions, permissions, or agent/skill definitions |
| `*/.claude/settings.json`, `*/.claude/settings.local.json` (regex across all repos) | **deny write** | Prevents per-project permission escalation — agents cannot grant themselves new permissions for future sessions |
| `~/.opencode`, `~/.config/opencode`, `~/.cache/opencode`, related state | read + write | openCode reads and writes session data, config, and cache here during normal operation |
| `~/.config/opencode/AGENTS.md`, `~/.config/opencode/opencode.json`, `~/.opencode.json` | **deny write** | openCode self-modification guard, mirroring the Claude Code equivalent |
| `~/.config/github-copilot` | read | Copilot CLI reads auth tokens from here; write is blocked to prevent silent token rotation |
| `~/dev/` | CWD-scoped read + write | No static grant. `sandbox-run` injects a `file-read* file-write*` subpath rule scoped to the launch CWD and ancestor `file-read*` literals for path traversal. Agents launched from `~/dev/myproject` can write only within that project; sibling repos are inaccessible |
| `~/dotfiles` | read (static); CWD-scoped read + write (injected) | Static read-only grant so symlink targets (`.gitconfig`, `.tmux.conf`, etc.) resolve correctly from any CWD. When launched from inside `~/dotfiles`, `sandbox-run` additionally injects a `file-read* file-write*` subpath rule granting write access |
| `~/.local/bin` | read | Binary symlinks (e.g. `claude`) are resolved from here; read-only prevents PATH poisoning — agents cannot drop executables that survive the session |
| `~/.local/scripts`, `~/.oh-my-zsh`, `~/.local/share/zinit`, `~/.config/nvim`, `~/.config/tmux`, `~/.config/lazygit`, `~/.config/bat`, `~/.config/btop`, `~/.zshrc`, `~/.zshenv`, `~/.zprofile`, `~/.zlogin`, `~/.aliases.zsh` | read | Agents source these indirectly through the tools they spawn; read access is required for normal shell and tool startup |
| `~/.local/share/zoxide` | read + write | Zoxide jump database; writable because it is updated on every directory change |
| `~/Library/Application Support/Google/Chrome`, Firefox, Safari, `~/Library/Safari` | **deny** | Browser history, cookies, and stored passwords fully blocked |
| `~/Library/Mail`, `~/Library/Messages` | **deny** | Personal communication data fully blocked |

### Process

| Permission | Scope | Notes |
|---|---|---|
| `process-exec` | Unrestricted | Agents invoke compilers, linters, test runners, and other tools — no reliable allowlist exists in SBPL without breaking normal toolchain use |
| `process-fork` | Unrestricted | Agents spawn subshells and parallel tool chains; without fork, most CLI workflows break |
| `process-info*` | Same sandbox only | Agents query process state to check exit codes, PIDs, and child process health; scoped to the sandbox instance |
| `signal` | Same sandbox only | Agents need to cancel or interrupt child processes they spawned; scoped so agents cannot kill unrelated host processes |
| `mach-priv-task-port` | Same sandbox only | Required by some macOS system frameworks at process startup; scoped to the sandbox to limit inspection to co-running sandboxed processes |
| `pseudo-tty` | Unrestricted | Many CLI tools require a TTY for interactive prompts and terminal control sequences |

### Network

| Permission | Scope | Notes |
|---|---|---|
| `network*` | Unrestricted — all interfaces, all ports, inbound and outbound | Full network access is intentionally granted. Data exfiltration is explicitly out of scope per the threat model. Any secret readable in the filesystem (tokens, code) can be sent to an external endpoint. Domain-level filtering is not achievable within SBPL and belongs in a complementary app firewall (e.g. LuLu, Little Snitch) |

### IPC / System

| Permission | Resource | Notes |
|---|---|---|
| `mach-lookup` | Logging, DNS, FSEvents, trust, launch services | Required for normal process startup — these services handle log delivery, name resolution, file-system event notifications, and code-signing checks |
| `mach-lookup` | `com.apple.SecurityServer`, `com.apple.secd`, `com.apple.trustd`, related | Required for keychain operations; combined with keychain R/W, this gives agents full programmatic keychain access |
| `sysctl-read` | Kernel parameters | Many CLIs query CPU count, memory size, and OS version at startup; blocking sysctl causes widespread tool failures |
| `system-socket` | Raw socket creation | Some network diagnostic tools require raw socket access for ICMP and low-level probing; complements `network*` |
| `ipc-posix-shm-read-data` | `apple.shm.notification_center` | System frameworks read this shared memory region during notification dispatch at process initialization |
| `ipc-posix-shm-*` | `com.apple.AppleDatabaseChanged` | Keychain change notification channel; required so keychain clients learn when the database is modified |

## Accepted risks

| Risk | Mitigation |
|---|---|
| Unrestricted network (exfiltration) | Out of scope by design. Use a per-process app firewall externally |
| CWD-scoped read/write (injected at launch) | Scoped to the launch directory — sibling repos are inaccessible. Git history provides recovery within the project |
| Keychain read/write | Scoped to `~/Library/Keychains`; required for Claude Code OAuth. No tighter grant is possible while keeping auth functional |
| Readable auth tokens (`.npmrc`, `.pypirc`, `~/.config/gh`, `~/.config/github-copilot`) | All are read-only. Exfiltration risk remains due to `network*` |
| Unrestricted `process-exec` | No known mitigation within SBPL without breaking toolchain usability |
