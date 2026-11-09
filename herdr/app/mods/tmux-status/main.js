import { View, div, svg } from "gpui-kit";
import { h_flex } from "gpui-base";
import { spaces, agents, terminals, focused, theme, shared, exec } from "herdr";

// The focused Claude Code's model and effort, read from Claude Code's own files on the
// terminal's machine: its process id (foreground.pid) names
// ~/.claude/sessions/<pid>.json, whose sessionId names the transcript; the
// transcript's last request model and effort (or a later /model or /effort)
// are the ones in use now.
// $2 is the transcript found last time, so later reads only tail it.
const EFFORT_SCRIPT = `
pid=$1; t=$2
dir=\${CLAUDE_CONFIG_DIR:-$HOME/.claude}
if [ -z "$t" ] || [ ! -f "$t" ]; then
  f=$dir/sessions/$pid.json
  [ -f "$f" ] || exit 0
  sid=$(sed -n 's/.*"sessionId":"\\([^"]*\\)".*/\\1/p' "$f")
  [ -n "$sid" ] || exit 0
  t=$(ls -t "$dir"/projects/*/"$sid".jsonl 2>/dev/null | head -1)
  [ -n "$t" ] || exit 0
fi
hits=$(tail -c 4000000 "$t" | grep -oE '"effort":"[a-z]+"|<local-command-stdout>Set effort level to [a-z]+|"model":"claude-[a-z]+|<local-command-stdout>Set model to .[A-Za-z]+')
e=$(printf '%s\\n' "$hits" | grep effort | tail -1 | grep -oE '[a-z]+"?$' | tr -d '"')
m=$(printf '%s\\n' "$hits" | grep model | tail -1 | grep -oE '[A-Za-z]+$' | tr 'A-Z' 'a-z')
printf '%s\\t%s\\t%s\\n' "$t" "$m" "$e"
`;

const TICK_MS = 1000;
const REFRESH_TICKS = 4;

function claudeOf(address) {
  const term = address ? terminals().find(x => x.address === address) : undefined;
  const pid = term?.foreground?.pid;
  const isClaude = term?.report?.app === "claude-code" || /(^|\/)claude$/.test(term?.foreground?.argv?.[0] ?? "");
  return isClaude && pid ? { key: `${address}:${pid}`, pid, machine: address.includes("/") ? address.split("/")[0] : undefined } : null;
}

export default class WorkspaceStatus extends View {
  init(_props, cx) {
    this.effort = {};      // "<address>:<pid>" -> "opus | high"
    this.transcript = {};  // "<address>:<pid>" -> transcript path on its machine
    this.lastKey = null;
    this.ticks = 0;
    this.reading = false;
    cx.timer.every(TICK_MS, (cx) => this.tick(cx));
    this.tick(cx);
  }

  // Reads at once when focus moves to another agent, else every few seconds.
  tick(cx) {
    const claude = claudeOf(focused()?.terminal);
    const key = claude?.key ?? null;
    this.ticks += 1;
    if (this.reading) return;
    if (!claude || (key === this.lastKey && this.ticks < REFRESH_TICKS)) {
      this.lastKey = key;
      return;
    }
    this.lastKey = key;
    this.ticks = 0;
    this.reading = true;
    cx.spawn(async (cx) => {
      try {
        const r = await exec("sh", ["-c", EFFORT_SCRIPT, "sh", String(claude.pid), this.transcript[key] ?? ""], claude.machine ? { on: claude.machine } : {});
        const [path, model, effort] = r.stdout.trim().split("\t");
        if (path) this.transcript[key] = path;
        const shown = [model, effort].filter(Boolean).join(" | ") || undefined;
        if (shown !== this.effort[key]) {
          this.effort[key] = shown;
          cx.notify();
        }
      } catch {
        // Machine unreachable: keep what was shown.
      } finally {
        this.reading = false;
      }
    });
  }

  render() {
    const t = theme();
    const space = spaces().find(s => s.active);
    const list = agents();
    const needs = list.filter(a => a.status === "blocked").length;
    const claude = claudeOf(focused()?.terminal);
    const effort = claude ? this.effort[claude.key] : undefined;
    const label = (icon, text) => h_flex().gap(6).items_center().child(svg(`mods/workspace-chrome/${icon}.svg`).size(13)).child(text);
    return h_flex().size_full().px(14).gap(16).items_center().bg(t.chrome).border_t(1).border_color(t.border).text_size(11.8).text_color(t.muted)
      .child(label(space?.machine ? "server" : "monitor", space?.machine ?? "This computer"))
      .when(Boolean(space?.branch), el => el.child(label("branch", space.branch)))
      .child(h_flex().gap(6).items_center().child(div().size(6).rounded(3).bg(t.dim)).child(`${list.length} agents`)
        .when(needs > 0, el => el.child(div().text_color(t.blocked).child(`· ${needs} needs you`))))
      .child(div().flex_1())
      .when(shared("prefix") === true, el => el.child(h_flex().gap(6).items_center()
        .child(div().text_color("#e5c07b").font_weight(700).child("prefix"))))
      .when(Boolean(effort), el => el.child(div().child(effort)));
  }
}
