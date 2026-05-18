# Shell environment

`cat` is aliased to `bat` in this user's shell, and `bat` is **not** installed. Any command that uses `cat` will fail silently or with `command not found: bat` — including heredocs of the form `"$(cat <<'EOF' ... EOF)"`, which will produce empty output and can lead to publishing empty content (e.g., a GitHub issue created via `gh issue create --body "$(cat <<'EOF' ...)"` ends up with no body).

**How to apply:**
- Never wrap heredocs in `$(cat <<'EOF' ...)` when shelling out via Bash. Write the content to a file with the Write tool, then pass `--body-file`, `-F`, `--file`, or shell redirection (`<file`) to the consuming command.
- Specifically for `gh`: prefer `gh issue create --body-file <path>`, `gh issue edit <n> --body-file <path>`, `gh pr create --body-file <path>`.
- Avoid `cat` in Bash commands generally. To read a file, use the Read tool. If a tool truly needs piped file content, use `< file` redirection or a different reader.
