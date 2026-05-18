#!/usr/bin/env bash

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
OS="$(uname)"

OK=0
BROKEN=0
MISSING=0

check() {
  local src="$DOTFILES/$1"
  local dst="$HOME/$2"
  local label="${2}"

  if [ ! -e "$src" ]; then
    return
  fi

  if [ -L "$dst" ]; then
    local resolved
    resolved="$(cd "$(dirname "$dst")" && realpath "$(readlink "$dst")" 2>/dev/null || true)"
    if [ "$resolved" = "$src" ]; then
      echo "  ✓  $label"
      OK=$((OK + 1))
    else
      echo "  ✗  $label  (points to: $resolved)"
      BROKEN=$((BROKEN + 1))
    fi
  elif [ -e "$dst" ]; then
    echo "  !  $label  (real file — not symlinked, run ./install.sh)"
    MISSING=$((MISSING + 1))
  else
    echo "  -  $label  (missing entirely)"
    MISSING=$((MISSING + 1))
  fi
}

echo ""
echo "Shell"
check ".zshrc" ".zshrc"

echo ""
echo "Editors & terminal"
check ".config/nvim"    ".config/nvim"
check ".config/tmux"    ".config/tmux"
check ".config/btop"    ".config/btop"
check ".config/kitty"   ".config/kitty"
check ".config/ghostty" ".config/ghostty"

echo ""
echo "CLI tools"
check ".config/git"           ".config/git"
check ".config/gh/config.yml" ".config/gh/config.yml"
check ".config/pgcli/config"  ".config/pgcli/config"

echo ""
echo "Claude"
check ".claude/CLAUDE.md"           ".claude/CLAUDE.md"
check ".claude/settings.json"       ".claude/settings.json"
check ".claude/keybindings.json"    ".claude/keybindings.json"
check ".claude/statusline-usage.sh" ".claude/statusline-usage.sh"
check ".claude/agents"              ".claude/agents"
check ".claude/hooks"               ".claude/hooks"
check ".claude/skills"              ".claude/skills"

for f in "$DOTFILES/.claude/commands/"*.md; do
  check ".claude/commands/$(basename "$f")" ".claude/commands/$(basename "$f")"
done

echo ""
echo "Agents"
check ".agents/skills" ".agents/skills"

if [ "$OS" = "Darwin" ]; then
  echo ""
  echo "macOS only"
  check ".config/zed/settings.json" ".config/zed/settings.json"
  check ".config/zed/keymap.json"   ".config/zed/keymap.json"
  check ".config/cmux/cmux.json"    ".config/cmux/cmux.json"
fi

echo ""
echo "─────────────────────────────"
echo "  ✓ $OK linked   ! $MISSING missing   ✗ $BROKEN broken"
echo ""
