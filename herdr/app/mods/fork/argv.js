// ponytail: boolean flags copied from `claude --help` (2.1.319); a new one placed before a launch prompt carries that prompt into the fork.
const BOOLEAN = new Set([
  "--allow-dangerously-skip-permissions", "--ax-screen-reader", "--bg", "--background", "--bare", "--brief",
  "--chrome", "--no-chrome", "-c", "--continue", "--dangerously-skip-permissions", "--desktop",
  "--disable-slash-commands", "--exclude-dynamic-system-prompt-sections", "--fork-session",
  "--forward-subagent-text", "--ide", "--include-hook-events", "--include-partial-messages",
  "--no-session-persistence", "-p", "--print", "--replay-user-messages", "--restricted", "--safe-mode",
  "--strict-mcp-config", "--tmux", "--verbose",
]);
// Not carried into the fork: which session to resume, and the name (the fork gets its own).
const RESUME = new Set(["-c", "--continue", "-r", "--resume", "--session-id", "--fork-session", "-n", "--name"]);

// The fork's session name: "[F] " and the original's, else its id's first part.
export function forkName(name, sessionId) {
  return `[F] ${name || sessionId.split("-")[0]}`;
}

export function forkArgv(argv, sessionId, name) {
  const kept = [];
  const seen = new Set();
  for (let i = 1; i < argv.length; i++) {
    const arg = argv[i];
    if (!arg.startsWith("-")) continue;
    const name = arg.split("=")[0];
    const next = argv[i + 1];
    const value = !arg.includes("=") && !BOOLEAN.has(name) && next !== undefined && !next.startsWith("-");
    const flag = value ? [arg, next] : [arg];
    // An exact repeat goes (a shell function adding --settings again on every launch).
    const key = JSON.stringify(flag);
    if (!RESUME.has(name) && !seen.has(key)) kept.push(...flag);
    seen.add(key);
    if (value) i++;
  }
  return [argv[0], ...kept, "--resume", sessionId, "--fork-session", ...(name ? ["--name", name] : [])];
}

// The fork's first message. A fork's transcript is the original's, and an appended
// system prompt is ignored (the original's recorded one is reused), so the fork
// learns what it is from a message: it stays in the transcript across resumes.
// `terminal`: the original's address on its own machine (no "machine/" prefix).
export function forkNote(sessionId, terminal) {
  return `You are a fork of session ${sessionId}. The original session is still running in terminal ${terminal} on this machine and may be working on the same things. Don't continue its in-progress work unless asked. Reply only "forked" and wait.`;
}

// Runs argv through the machine's login shell, so the program resolves as when typed
// there: a shell function (dotfiles wrapping `claude`) or a PATH set only in the
// shell's profile. Herdr starts argv directly otherwise. sh-family shells only ($0, $@).
export function viaShell(argv) {
  return ["/bin/sh", "-c", `exec "\${SHELL:-/bin/sh}" -lic '"$0" "$@"' "$0" "$@"`, ...argv];
}
