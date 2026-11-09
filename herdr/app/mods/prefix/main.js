// tmux-style prefix: ctrl-b opens this invisible popup, the next key runs a command from KEYS.
// The status-bar mod shows "prefix" while shared("prefix") is true.

import { View, div } from "gpui-kit";
import { run, hc, focused, props, closeOverlay, nextCommand, setShared } from "herdr";

const KEYS = {
  '"': ["terminal.open", { place: "down" }],
  "%": ["terminal.open", { place: "right" }],
  c: ["tab.new"],
  n: ["tab.next"],
  p: ["tab.prev"],
  ",": ["tab.rename"],
  "&": ["tab.close"],
  x: ["pane.close"],
  z: ["pane.zoom"],
  left: ["pane.go", { direction: "left" }],
  down: ["pane.go", { direction: "down" }],
  up: ["pane.go", { direction: "up" }],
  right: ["pane.go", { direction: "right" }],
  h: ["pane.go", { direction: "left" }],
  j: ["pane.go", { direction: "down" }],
  k: ["pane.go", { direction: "up" }],
  l: ["pane.go", { direction: "right" }],
  "(": ["space.prev"],
  ")": ["space.next"],
  $: ["space.rename"],
  "?": ["app.help"],
};
for (let i = 1; i <= 9; i++) KEYS[i] = ["tab.select", { index: i }];

const HANGUL = { "ㅊ": "c", "ㅜ": "n", "ㅔ": "p", "ㅌ": "x", "ㅋ": "z", "ㅗ": "h", "ㅓ": "j", "ㅏ": "k", "ㅣ": "l" };

export default class Prefix extends View {
  init(_props, cx) {
    setShared("prefix", true);
    this.terminal = focused()?.terminal;
    this.handle = cx.focus_handle();
    this.handle.focus();
    cx.timer.after(50, () => this.handle.focus());
    cx.spawn(async () => {
      for (;;) {
        if ((await nextCommand()) === "literal") this.literal();
      }
    });
  }

  // Send ctrl-b to the terminal that had focus and close at once, so the pane
  // gets its focus back; the hc call already started outlives the popup.
  literal() {
    if (this.sent) return;
    this.sent = true;
    if (this.terminal) hc(["keys", this.terminal, "ctrl+b"]).catch(() => {});
    this.done();
  }

  done() {
    setShared("prefix", false);
    closeOverlay(props().overlay);
  }

  close() {
    setShared("prefix", false);
  }

  key(e) {
    const m = e.modifiers;
    if (m.control || m.alt || m.platform) return e.keystroke;
    const c = e.key_char ?? e.key;
    return HANGUL[c] ?? (c.length === 1 ? c : e.key);
  }

  render() {
    return div()
      .id("prefix")
      .track_focus(this.handle)
      .on_key_down((e) => {
        const k = this.key(e);
        if (k === "ctrl-b") return this.literal();
        if (k === "escape" || this.sent) return;
        this.done();
        const hit = KEYS[k];
        if (hit) run(...hit);
      })
      .size_full();
  }
}
