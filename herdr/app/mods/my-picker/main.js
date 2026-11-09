// Go to a tab. Drops from the Terminals layout's space chip (popup, at: "top"). Spaces with
// something that needs you come first, quiet spaces (no agent running)
// fold into "earlier". Typing searches fuzzily (fuzzy.js): one list, best match
// first and selected, matched letters marked. ↑/↓ and Enter to go, ctrl+d to close
// a tab, Esc to leave. Last rows: new work (a tab here, a space on this
// computer or on each connected machine).

import { View, div, svg } from "gpui-kit";
import { v_flex, h_flex, InputState, Input } from "gpui-base";
import { agents, spaces, terminals, panes, run, hc, theme, settings, props, closeOverlay, openOverlay, shared, setShared } from "herdr";
import { terms, rank } from "./fuzzy.js";

// How much a match counts in each field of a tab: its name and its agents' titles
// most, then the space and its machine, then its other terminals (shells, editors,
// servers) and sub-agents, then what the agents run and their state.
const WEIGHT = { tab: 1, title: 1, space: 0.8, machine: 0.7, sub: 0.7, terminal: 0.6, program: 0.6, app: 0.5, status: 0.5 };

// Text with the matched letters in the accent color. Without matches, plain text
// that truncates; with them, runs of text side by side, clipped at the edge.
function marked(text, positions, color, accent) {
  if (!positions?.length) return div().min_w(0).truncate().text_color(color).child(text);
  const hit = new Set(positions);
  const runs = [];
  for (let i = 0; i < text.length; i++) {
    const on = hit.has(i);
    if (runs.length && runs[runs.length - 1].on === on) runs[runs.length - 1].s += text[i];
    else runs.push({ s: text[i], on });
  }
  return h_flex().min_w(0).overflow_hidden().whitespace_nowrap().text_color(color)
    .children(runs.map((r) => div().flex_none().when(r.on, (d) => d.text_color(accent).font_bold()).child(r.s)));
}

const MARK = { ansi6: "#22a99a", ansi3: "#e3814f", ansi4: "#5b8def", ansi5: "#8b7cf6", ansi2: "#3fae6a", ansi1: "#d9649a" };

// Space colors, kept by space id in shared "space.colors": a theme
// color name ("ansi6") or a picked #rrggbb. A space seen without one gets
// the theme color fewest spaces use, once; every mod does the same in the
// same order, so they agree, and adding or renaming spaces moves nothing.
const PROJECT_COLORS = ["ansi6", "ansi3", "ansi4", "ansi5", "ansi2", "ansi1"];
function spaceColors() {
  const ids = new Set(spaces().map((p) => p.id));
  const kept = Object.fromEntries(Object.entries(shared("space.colors") ?? {}).filter(([id]) => ids.has(id)));
  let changed = Object.keys(kept).length !== Object.keys(shared("space.colors") ?? {}).length;
  for (const p of spaces()) {
    if (kept[p.id] || p.name === "~") continue;
    const uses = (c) => Object.values(kept).filter((v) => v === c).length;
    kept[p.id] = PROJECT_COLORS.reduce((best, c) => (uses(c) < uses(best) ? c : best));
    changed = true;
  }
  if (changed) setShared("space.colors", kept);
  return kept;
}
function spaceColor(t, p) {
  if (p.name === "~") return t.dim;
  const c = spaceColors()[p.id] ?? PROJECT_COLORS[0];
  return c.startsWith("#") ? c : (MARK[c] ?? t[c]);
}

export default class Picker extends View {
  init(_props, cx) {
    // props().filter: opens already searching (from another mod's openOverlay).
    this.filter = props()?.filter ?? "";
    this.input = InputState.new({ placeholder: "Go to a tab, space or agent (name, title, status)…", value: this.filter });
    this.input.on("change", (_e, cx) => { this.filter = this.input.value(); this.at = 0; cx.notify(); });
    this.input.on("submit", () => this.go(this.rows().filter(r => r.kind === "ctx" || r.kind === "new" || r.kind === "space")[this.at]));
    this.input.focus();
    cx.timer.after(600, () => this.input.focus());
    this.at = null;
    this.scroll = 0;
    this.showEarlier = false;
    this.machines = [];
    this.handle = cx.focus_handle();
    cx.spawn(async (cx) => {
      try {
        const r = await hc(["machine", "ls", "--json"]);
        if (r.code === 0) this.machines = (JSON.parse(r.stdout).machines ?? []).filter((m) => m.state === "connected" && !m.temporary).map((m) => m.name);
      } catch {}
      cx.notify();
    });
  }

  close() {
    closeOverlay(props().overlay);
  }

  rows() {
    const ts = terms(this.filter);
    const all = agents();
    const live = terminals().filter((x) => x.state === "live");
    // Live sub-agents under these agents, all levels down.
    const subsOf = (addrs) => {
      const out = [];
      const walk = (a) => live.filter((x) => x.parent === a).forEach((k) => (out.push(k), walk(k.address)));
      addrs.forEach(walk);
      return out;
    };
    const teamOf = (addrs) => subsOf(addrs).length;
    const newWork = [{ kind: "new" }, { kind: "space", machine: null }, ...this.machines.map((m) => ({ kind: "space", machine: m }))];

    // Searching: every tab scored on its fields, one list, best first. `marks`
    // keeps the matched letters of what the row shows (tab, space, machine,
    // titles), and `also` the best hidden match (a shell, a sub-agent) to show why.
    if (ts.length) {
      const found = [];
      const allPanes = panes(); // read once: each read copies every pane
      for (const w of spaces()) {
        // This computer's spaces answer to "local", as the sidebar calls it.
        const machine = w.machine ?? "local";
        for (const ctx of w.tabs) {
          const mine = all.filter((a) => a.tab === ctx.id);
          const agentAt = new Set(mine.map((a) => a.address));
          const titles = mine.map((a) => (a.title ?? "").trim());
          // The tab's other terminals: what runs there and the title it set.
          const others = allPanes.filter((p) => p.tab === ctx.id && p.terminal && !agentAt.has(p.terminal));
          const subs = subsOf([...agentAt]);
          const shown = [
            { text: ctx.name, weight: WEIGHT.tab },
            { text: w.name, weight: WEIGHT.space },
            { text: machine, weight: WEIGHT.machine },
            ...titles.map((text) => ({ text, weight: WEIGHT.title })),
          ];
          const hidden = [
            ...others.flatMap((p) => [
              { text: (p.title ?? "").trim(), weight: WEIGHT.terminal, also: true },
              { text: p.program?.name ?? "", weight: WEIGHT.terminal, also: true },
            ]),
            ...subs.map((k) => ({ text: k.name || k.template || k.program?.name || "", weight: WEIGHT.sub, also: true })),
            ...mine.flatMap((a) => [
              { text: a.program?.name ?? "", weight: WEIGHT.program },
              { text: a.app ?? "", weight: WEIGHT.app },
              { text: a.status ?? "", weight: WEIGHT.status },
            ]),
          ];
          const fields = [...shown, ...hidden];
          const m = rank(ts, fields);
          if (!m) continue;
          const alsoAt = fields.findIndex((f, i) => f.also && m.hits[i].length);
          found.push({
            kind: "ctx", flat: true, w, ctx, mine, team: subs.length, score: m.score,
            marks: {
              tab: m.hits[0], space: m.hits[1], machine: m.hits[2],
              titles: titles.map((_, i) => m.hits[3 + i]),
              also: alsoAt >= 0 ? { text: fields[alsoAt].text, hits: m.hits[alsoAt] } : null,
            },
          });
        }
      }
      found.sort((a, b) => b.score - a.score);
      return [...found, ...newWork];
    }

    const groups = spaces().map((w) => {
      const ctxs = w.tabs.map((ctx) => {
        const mine = all.filter((a) => a.tab === ctx.id);
        return { w, ctx, mine, team: teamOf(mine.map((a) => a.address)) };
      });
      return { w, ctxs };
    });
    const busy = groups.filter((p) => p.w.status && p.ctxs.length);
    const quiet = groups.filter((p) => !p.w.status && p.ctxs.length);
    busy.sort((a, b) => (b.w.status === "blocked") - (a.w.status === "blocked"));
    const out = [];
    const add = (p) => {
      out.push({ kind: "head", w: p.w });
      for (const c of p.ctxs) out.push({ kind: "ctx", ...c });
    };
    busy.forEach(add);
    if (quiet.length) {
      out.push({ kind: "earlier", count: quiet.length });
      if (this.showEarlier) quiet.forEach(add);
    }
    return [...out, ...newWork];
  }

  go(r) {
    if (!r) return;
    this.close();
    if (r.kind === "ctx") run("tab.select", { id: r.ctx.id });
    else if (r.kind === "new") run("tab.new");
    else if (r.kind === "space") run("space.new", { machine: r.machine ?? "" });
  }

  glyph(t, st) {
    if (st === "working") return svg("mods/workspace-chrome/spinner.svg").size(12).flex_none().text_color(t.working).spin(900);
    return div().w(12).flex_none().text_color(t[st] ?? t.dim).child(st === "idle" ? "○" : st ? "●" : "·");
  }

  render() {
    const t = theme();
    const rows = this.rows();
    const pickable = rows.filter((r) => r.kind === "ctx" || r.kind === "new" || r.kind === "space");
    // Opens on where you are.
    if (this.at === null) this.at = Math.max(0, pickable.findIndex((r) => r.kind === "ctx" && r.w.active && r.ctx.active));
    this.at = Math.min(this.at, pickable.length - 1);
    const sel = pickable[this.at];
    // One continuous strip: each row (and the group title before it) at a fixed
    // y. Scrolling moves the strip only as far as it takes to keep the selected
    // row in view, so the arrows can't run the selection off the list.
    const H = { head: 29, earlier: 35, new: 36, ctx: 32, space: 32 };
    const tops = [];
    let y = 0;
    rows.forEach((r) => { tops.push(y); y += H[r.kind] ?? 32; });
    const total = y;
    const height = Math.min(320, this.listHeight ?? 320);
    const fixed = total > height;
    const maxScroll = Math.max(0, total - height);
    this.scroll = Math.max(0, Math.min(this.scroll, maxScroll));
    const si = rows.indexOf(sel);
    if (si >= 0) {
      if (tops[si] < this.scroll) this.scroll = tops[si];
      if (tops[si] + (H[sel.kind] ?? 32) > this.scroll + height) this.scroll = tops[si] + (H[sel.kind] ?? 32) - height;
    }
    const place = (el, i) =>
      fixed
        ? el.absolute().left(0).right(0).top(tops[i] - this.scroll).bottom(height - (tops[i] + (H[rows[i].kind] ?? 32) - this.scroll))
        : el;
    const visible = (i) => !fixed || (tops[i] + (H[rows[i].kind] ?? 32) > this.scroll && tops[i] < this.scroll + height);

    const row = (r) => {
      if (r.kind === "head") {
        return h_flex()
          .px(10)
          .pt(10)
          .pb(3)
          .gap(8)
          .items_center()
          .text_size(11)
          .font_semibold()
          .text_color(t.dim)
          .child(h_flex().size(18).rounded(5).bg(spaceColor(t, r.w)).items_center().justify_center().text_size(10.5).font_bold().text_color("#ffffff").child([...r.w.name][0]?.toUpperCase() ?? "?"))
          .child(r.w.name);
      }
      if (r.kind === "earlier") {
        return h_flex()
          .id("pk-earlier")
          .mt(6)
          .px(10)
          .py(6)
          .border_t(1)
          .border_color(t.border)
          .text_size(12)
          .text_color(t.dim)
          .cursor_pointer()
          .hover((s) => s.text_color(t.foreground))
          .on_click((_e, cx) => {
            this.showEarlier = !this.showEarlier;
            cx.notify();
          })
          .child(`earlier: ${r.count} quiet space${r.count > 1 ? "s" : ""} ${this.showEarlier ? "▴" : "▾"}`);
      }
      const on = r === sel;
      if (r.kind === "new" || r.kind === "space") {
        const label = r.kind === "new" ? "new tab" : r.machine ? `new space on ${r.machine}` : "new space";
        return h_flex()
          .id(r.kind === "new" ? "pk-new" : `pk-space-${r.machine ?? "here"}`)
          .mx(4)
          .when(r.kind === "new", (el) => el.mt(4))
          .px(10)
          .h(32)
          .items_center()
          .rounded(7)
          .gap(8)
          .text_color(t.muted)
          .cursor_pointer()
          .when(on, (el) => el.bg(t.hover))
          .hover((s) => s.bg(t.hover))
          .on_click(() => this.go(r))
          .child(div().w(12).child("+"))
          .child(label);
      }
      const who = r.mine.map((a) => a.program?.name ?? "agent").join(" · ");
      // The agents' titles after the tab's name, with their matched letters.
      const titleItems = r.mine
        .map((a, i) => ({ text: (a.title ?? "").trim(), marks: r.marks?.titles[i] }))
        .filter((x) => x.text && x.text !== r.ctx.name);
      const titles = titleItems.map((x) => x.text).join(" · ");
      const titlesMarked = titleItems.some((x) => x.marks?.length);
      const here = r.w.active && r.ctx.active;
      return h_flex()
        .id(`pk-${r.ctx.id}`)
        .mx(4)
        .px(10)
.h(32)
        .rounded(7)
        .gap(10)
        .items_center()
        .cursor_pointer()
        .when(on, (el) => el.bg(t.hover))
        .hover((s) => s.bg(t.hover))
        .on_click(() => this.go(r))
        .child(this.glyph(t, r.ctx.status))
        .child(h_flex().flex_1().min_w(0).gap(8).items_center()
          // Searching, the space headers are gone: its mark and name lead the row.
          .when(!!r.flat, (el) => el.child(h_flex().flex_none().gap(5).items_center()
            .child(h_flex().size(14).flex_none().rounded(4).bg(spaceColor(t, r.w)).items_center().justify_center().text_size(8.5).font_bold().text_color("#ffffff").child([...r.w.name][0]?.toUpperCase() ?? "?"))
            // "server/research": another machine's space says which; this computer's
            // only when "local" is what matched.
            .child(h_flex().flex_none().items_center().text_size(12)
              .when(!!r.w.machine || !!r.marks?.machine?.length, (m) => m
                .child(marked(r.w.machine ?? "local", r.marks?.machine, t.dim, t.accent))
                .child(div().text_color(t.dim).child("/")))
              .child(marked(r.w.name, r.marks?.space, t.dim, t.accent)))))
          .child(marked(r.ctx.name, r.marks?.tab, t.foreground, t.accent).flex_none().when(here, (d) => d.font_semibold()))
          .when(!!titles && !titlesMarked, (el) => el.child(div().flex_1().min_w(0).truncate().text_size(12).text_color(t.muted).child(titles)))
          .when(titlesMarked, (el) => el.child(h_flex().flex_1().min_w(0).overflow_hidden().whitespace_nowrap().text_size(12)
            .children(titleItems.flatMap((x, i) => [
              ...(i ? [div().flex_none().text_color(t.dim).child(" · ")] : []),
              marked(x.text, x.marks, t.muted, t.accent).flex_none(),
            ])))))
        // A match the row doesn't otherwise show (a shell's title, a sub-agent): why it's here.
        .when(!!r.marks?.also, (el) => el.child(h_flex().flex_none().max_w(200).min_w(0).gap(4).items_center().text_size(11)
          .child(div().flex_none().text_color(t.dim).child("↳"))
          .child(marked(r.marks.also.text, r.marks.also.hits, t.dim, t.accent))))
        .when(r.ctx.status === "blocked", (el) => el.child(div().text_size(11).text_color(t.blocked).child("needs you")))
        .when(r.ctx.status === "done", (el) => el.child(div().text_size(11).text_color(t.done).child("finished")))
        .child(div().text_size(11).text_color(t.dim).child(who + (r.team ? `  +${r.team}` : "")));
    };

    return v_flex()
      .id("picker")
      .track_focus(this.handle)
      .w_full()
      .min_h(0)
      .p(18)
      .gap(10)
      .bg(t.popover)
      .text_size(13)
      .on_key_down((e, cx) => {
        const k = e.key;
        if (k === "escape") return this.close();
        if (k === "down") this.at = (this.at + 1) % pickable.length;
        else if (k === "up") this.at = (this.at + pickable.length - 1) % pickable.length;
        else if (k === "d" && e.modifiers.control) {
          if (sel?.kind === "ctx") {
            this.close();
            run("tab.close", { id: sel.ctx.id });
          }
        } else return;
        cx.stop_propagation();
        cx.notify();
      })
      .child(h_flex().items_center().child(div().flex_1().text_size(15).font_semibold().text_color(t.foreground).child("Go to…")).child(div().text_size(11).text_color(t.dim).child("Esc")))
      .child(
        h_flex().h(36).flex_none().px(10).gap(8).items_center().rounded(9).border_1().border_color(t.accent).bg(t.background)
          .child(svg("mods/workspace-chrome/search.svg").size(15).text_color(t.dim))
          .child(Input.new(this.input).flex_1().h_full().text_size(12.8).text_color(t.foreground)),
      )
      .child(
        v_flex()
          .id("pk-list")
          .on_size_change((size, cx) => {
            this.listHeight = size.height / settings().zoom;
            cx.notify();
          })
          .h(Math.min(320, total))
          .min_h(0)
          .mb(6)
          .when(fixed, (el) =>
            el.overflow_hidden().on_scroll_wheel((e, cx) => {
              this.scroll = Math.max(0, Math.min(this.scroll - e.delta.y, maxScroll));
              // The selection follows the wheel, so the next frame doesn't scroll back to it.
              while (this.at < pickable.length - 1 && tops[rows.indexOf(pickable[this.at])] < this.scroll) this.at++;
              while (this.at > 0 && tops[rows.indexOf(pickable[this.at])] + (H[pickable[this.at].kind] ?? 32) > this.scroll + height) this.at--;
              cx.notify();
            }))
          .children(rows.map((r, i) => (visible(i) ? place(row(r), i) : null)).filter(Boolean)),
      );
  }
}
