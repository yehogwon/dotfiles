# dotfiles

## Commits

`dot pull` prints each pulled commit's subject as the changelog, so write the subject for someone reading what changed on their machine.

- **Subject:** `<area>: <what changed>`, lowercase, no closing period, at most 72 characters. Say what changes for someone using it, not which functions moved.
- **Area:** the top-level directory the commit's main change is in: `shell`, `git`, `ssh`, `tmux`, `vim`, `ghostty`, `vscode` or `modules`. Use `dot` for `bin/` (the `dot` command and the installers) and for files outside these directories (`README.md`, `.permissions`, `misc/`).
- **Several areas:** use the one the commit changes most, or `a, b: ...` when two matter equally.
- **Body:** optional `- ` bullets on what changed and why.
