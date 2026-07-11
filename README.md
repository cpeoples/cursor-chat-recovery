<p align="center">
  <img src="https://www.cursor.com/brand/icon.svg" alt="Cursor Logo" width="80" height="80">
</p>

<h1 align="center">Cursor Chat Recovery Tool</h1>

<p align="center">
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT"></a>
  <a href="#platform-support"><img src="https://img.shields.io/badge/Platform-macOS%20|%20Linux%20|%20Windows-blue.svg" alt="Platform"></a>
  <a href="https://www.gnu.org/software/bash/"><img src="https://img.shields.io/badge/Shell-Bash-green.svg" alt="Shell"></a>
</p>

<p align="center">
  <b>Lost your AI chat history in Cursor? This tool recovers it in seconds.</b>
</p>

---

Move a project folder, rename a directory, or open Cursor from a different path — and your chat history vanishes. But it's not gone! It's just in a different workspace database. This tool finds it and brings it back.

## Quick Install

```bash
# Download and run
curl -fsSL https://raw.githubusercontent.com/cpeoples/cursor-chat-recovery/main/cursor-chat-recovery.sh -o cursor-chat-recovery.sh
bash cursor-chat-recovery.sh my-project-name
```

Or clone for development:

```bash
git clone https://github.com/cpeoples/cursor-chat-recovery.git
cd cursor-chat-recovery
bash cursor-chat-recovery.sh my-project-name
```

## How It Works

Cursor creates a unique workspace for each project path. Different paths = different workspaces = "missing" chat history.

```
~/Library/Application Support/Cursor/User/workspaceStorage/
  ├── abc123.../state.vscdb  ← Your old chat history is here
  ├── xyz789.../state.vscdb  ← New workspace (empty)
```

This tool:

1. 🔍 Finds all workspaces matching your project name
2. 📊 Shows which has your chat history (largest file = most history)
3. 💾 Creates automatic backups
4. 🔄 Restores your conversations

## Usage

### Interactive Mode

```bash
# Either form works:
./cursor-chat-recovery.sh my-project
bash cursor-chat-recovery.sh my-project
```

You'll see your workspaces listed with size and date. Pick the source (has history) and target (current workspace), and you're done.

### ⚠️ Important: Before & After

**Before running:**
1. **Close Cursor completely** — the database can't be modified while Cursor is running

**After running:**
1. **Open Cursor**
2. **Open your project from the exact same path** — this is critical!
   - ✅ `~/projects/my-app` → `~/projects/my-app`
   - ❌ `~/projects/my-app` → `~/Downloads/my-app` (different path = different workspace)
3. Your chat history should now appear

> **Why path matters:** Cursor creates a unique workspace for each path. If you open from a different path, you'll get a different (empty) workspace.

### Command-Line Options

```bash
./cursor-chat-recovery.sh --help                              # Show all options
./cursor-chat-recovery.sh --version                           # Show version
./cursor-chat-recovery.sh --list my-project                   # List workspaces (non-interactive)
./cursor-chat-recovery.sh --restore 2 1 my-project            # Restore workspace 2 → 1
./cursor-chat-recovery.sh --dry-run --restore 2 1 my-project  # Preview without changes
```

## Platform Support

| Platform          | Status                  | Workspace Location                                             |
| ----------------- | ----------------------- | -------------------------------------------------------------- |
| **macOS**   | ✅ Works out of the box | `~/Library/Application Support/Cursor/User/workspaceStorage` |
| **Linux**   | ✅ Works out of the box | `~/.config/Cursor/User/workspaceStorage`*                    |
| **Windows** | ✅ Via Git Bash/WSL     | `%APPDATA%\Cursor\User\workspaceStorage`                     |

*Linux also checks `$XDG_CONFIG_HOME/Cursor/` if set, and `~/.cursor-server/` for remote/SSH mode.

**Windows users:** Install [Git for Windows](https://git-scm.com/download/win), open Git Bash, and run:

```bash
bash cursor-chat-recovery.sh my-project
```

PowerShell/CMD not supported.

## Troubleshooting

| Problem | Solution |
| ------- | -------- |
| "No workspaces found" | Check exact project name (case-sensitive). Ensure you've used AI chat in Cursor for this project. |
| "Cursor is running" | Close Cursor completely, then run the tool again. |
| Chat history not showing after restore | **You must open the project from the exact same path.** Check the "Project:" path shown in the workspace list — open Cursor from that exact location. |
| Restored to wrong workspace | No problem! Backups are automatic. Find the `.backup.YYYYMMDD_HHMMSS` file and rename it back to `state.vscdb`. |

## Safety

- ✅ Automatic timestamped backups before any changes
- ✅ Warns if Cursor is running
- ✅ Dry-run mode previews copy/merge operations without terminating Cursor or changing files
- ✅ Validates source/target selections

Backups are saved as `state.vscdb.backup.YYYYMMDD_HHMMSS` in the workspace directory.

## Development

```bash
make install    # Install to ~/.local/bin
make test       # Run platform tests
make lint       # Run shellcheck (if installed)
make uninstall  # Remove installation
```

## Contributing

Contributions welcome! Please:

1. Fork the repo and create a feature branch
2. Run `make test` to verify platform compatibility
3. Follow existing code style (4-space indent, meaningful names)
4. Submit a PR with clear description

For bugs or features, [open an issue](https://github.com/cpeoples/cursor-chat-recovery/issues).

## License

MIT License — see [LICENSE](LICENSE) for details.

---

<p align="center">
  <b>If this tool saved your chat history, ⭐ star the repo!</b><br>
  <a href="https://github.com/cpeoples/cursor-chat-recovery">github.com/cpeoples/cursor-chat-recovery</a>
</p>
