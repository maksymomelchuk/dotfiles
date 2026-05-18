# Dotfiles

## Setup on a new machine

```bash
git clone <your-repo> ~/dotfiles
cd ~/dotfiles && ./install.sh
```

Verify everything is symlinked:

```bash
~/dotfiles/check.sh
```

## Keeping dotfiles updated

### When you change a config

Nothing extra needed — edits go directly into `~/dotfiles` via symlinks. Just commit:

```bash
cd ~/dotfiles && git add -A && git commit -m "update zsh aliases"
```

### When you install a new app

```bash
# 1. move config into dotfiles
cp ~/.config/newapp/config ~/dotfiles/.config/newapp/config

# 2. symlink it back
rm ~/.config/newapp/config
ln -s ~/dotfiles/.config/newapp/config ~/.config/newapp/config

# 3. add entries to install.sh and check.sh, then commit
cd ~/dotfiles && git add -A && git commit -m "add newapp config"
```

### Syncing to another machine (e.g. Pi)

```bash
# on this machine
cd ~/dotfiles && git push

# on the other machine
cd ~/dotfiles && git pull
```

## What's tracked

| Path | Notes |
|------|-------|
| `~/.zshrc` | shell config |
| `~/.config/nvim` | neovim |
| `~/.config/tmux` | tmux |
| `~/.config/btop` | btop |
| `~/.config/kitty` | kitty terminal |
| `~/.config/ghostty` | ghostty terminal |
| `~/.config/git` | global gitignore |
| `~/.config/gh/config.yml` | GitHub CLI (not `hosts.yml` — contains tokens) |
| `~/.config/pgcli/config` | postgres CLI |
| `~/.config/zed/settings.json` | Zed editor (macOS only) |
| `~/.config/zed/keymap.json` | Zed keybindings (macOS only) |
| `~/.config/cmux/cmux.json` | cmux terminal (macOS only) |
| `~/.claude/CLAUDE.md` | global Claude instructions |
| `~/.claude/settings.json` | Claude permissions & hooks |
| `~/.claude/keybindings.json` | Claude keybindings |
| `~/.claude/statusline-usage.sh` | Claude statusline script |
| `~/.claude/agents/` | custom agents |
| `~/.claude/hooks/` | notification hooks |
| `~/.claude/skills/` | custom skills |
| `~/.claude/commands/` | slash commands |
| `~/.agents/skills/` | global agent skills |

## What's intentionally ignored

- `~/.config/gh/hosts.yml` — auth tokens
- `~/.config/zed/development_credentials` — credentials
- `~/.config/zed/conversations/`, `embeddings/` — generated
- `~/.config/github-copilot/apps.json` — OAuth tokens
- `~/.claude/history.jsonl`, `sessions/`, `cache/`, `logs/` — ephemeral
- `~/.claude/projects/`, `tasks/`, `todos/` — per-project runtime data
- `User/History/` — VS Code local history
- `User/sync/` — VS Code settings sync cache
- `.DS_Store` — macOS metadata
