#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
OS="$(uname)"

link() {
  local src="$DOTFILES/$1"
  local dst="$HOME/$2"

  mkdir -p "$(dirname "$dst")"

  if [ -L "$dst" ]; then
    return
  fi

  if [ -e "$dst" ]; then
    mv "$dst" "$dst.bak"
    echo "backed up: $dst"
  fi

  ln -s "$src" "$dst"
  echo "linked:    $dst"
}

# Shell
link ".zshrc" ".zshrc"

# Editors & terminal
link ".config/nvim"    ".config/nvim"
link ".config/tmux"    ".config/tmux"
link ".config/btop"    ".config/btop"
link ".config/kitty"   ".config/kitty"
link ".config/ghostty" ".config/ghostty"

# CLI tools
link ".config/git"           ".config/git"
link ".config/gh/config.yml" ".config/gh/config.yml"
link ".config/pgcli/config"  ".config/pgcli/config"

# Claude
link ".claude/CLAUDE.md"          ".claude/CLAUDE.md"
link ".claude/settings.json"      ".claude/settings.json"
link ".claude/keybindings.json"   ".claude/keybindings.json"
link ".claude/statusline-usage.sh" ".claude/statusline-usage.sh"
link ".claude/agents"             ".claude/agents"
link ".claude/hooks"              ".claude/hooks"
link ".claude/skills"             ".claude/skills"

mkdir -p "$HOME/.claude/commands"
for f in "$DOTFILES/.claude/commands/"*.md; do
  link ".claude/commands/$(basename "$f")" ".claude/commands/$(basename "$f")"
done

# Global agents
link ".agents/skills" ".agents/skills"

# macOS only
if [ "$OS" = "Darwin" ]; then
  link ".config/zed/settings.json" ".config/zed/settings.json"
  link ".config/zed/keymap.json"   ".config/zed/keymap.json"
  link ".config/cmux/cmux.json"    ".config/cmux/cmux.json"
fi

echo "done"
