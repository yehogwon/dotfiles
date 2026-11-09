// cmd-shift-f: fork the focused Claude Code pane's conversation into a split beside it.
import { View, div } from "gpui-kit";
import { hc, exec, run, notify, focused, spaces, props, closeOverlay } from "herdr";
import { forkArgv, forkName, forkNote, viaShell } from "./argv.js";

const PLACE = "right";

async function fork(terminal, machine) {
  if (!terminal) throw new Error("No terminal is focused.");
  const got = JSON.parse((await hc(["get", terminal, "--json"])).stdout);
  if (got.status?.app !== "claude-code") throw new Error("The focused pane isn't running Claude Code.");
  const pid = String(got.foreground.pid);
  const read = await exec("sh", ["-c", 'cat "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/sessions/$1.json"', "sh", pid], { on: machine });
  if (read.code !== 0) throw new Error(`No Claude session file for pid ${pid}.`);
  const session = JSON.parse(read.stdout);
  // Through the login shell: on a machine where `claude` is a shell function or on
  // the profile's PATH only (a remote Linux box), starting it directly fails with "not found".
  // The note goes last, as claude's launch prompt: the fork's first message.
  const note = forkNote(session.sessionId, terminal.split("/").pop());
  const name = forkName(session.name, session.sessionId);
  run("terminal.open", { argv: viaShell([...forkArgv(got.foreground.argv, session.sessionId, name), note]), folder: session.cwd ?? got.foreground.cwd, place: PLACE });
}

export default class Fork extends View {
  init(_props, cx) {
    const { overlay } = props() ?? {};
    if (!overlay) return;
    const f = focused();
    const machine = spaces().find((s) => s.id === f?.space)?.machine ?? null;
    cx.spawn(async () => {
      try {
        await fork(f?.terminal, machine);
      } catch (e) {
        notify({ title: "Fork failed", body: String(e?.message ?? e), level: "error" });
      } finally {
        closeOverlay(overlay);
      }
    });
  }

  render() {
    return div();
  }
}
