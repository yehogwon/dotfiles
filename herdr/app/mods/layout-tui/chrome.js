// The sidebar's top row (brand, search) and footer (settings, add machine), from the
// shipped workspace-chrome, with the collapse button moved down beside Settings.
// Icons are the shipped mod's own (mods/workspace-chrome/*.svg).

import { View, div, image, svg } from "gpui-kit";
import { h_flex, v_flex } from "gpui-base";
import { theme, run, props, window, shared, setShared, updates, layout } from "herdr";

function find(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = find(child, id);
    if (found) return found;
  }
  return null;
}

// The sidebar's rail goes by its width, not a flag: dragging its edge narrows it too.
const narrow = () => (find(layout(), "sidebar")?.size?.px ?? Infinity) < 160;

// To the rail (on macOS wide enough for the traffic lights), or back to the width it had.
function toggleSidebar() {
  const width = find(layout(), "sidebar")?.size?.px;
  if (!narrow()) setShared("sidebar.width", width);
  // Mods edited before the rail went by width still read the flag.
  setShared("sidebar.collapsed", !narrow());
  run("layout.resize", { id: "sidebar", px: narrow() ? (shared("sidebar.width") ?? 268) : window()?.platform === "macos" ? 76 : 44 });
}

const icon = (name) => svg(`mods/workspace-chrome/${name}.svg`);

export default class Chrome extends View {
  button(id, label, action, tip) {
    const t = theme();
    return div().id(id).size(26).flex_none().flex().items_center().justify_center().rounded(6).text_color(t.muted).hover(s => s.bg(t.hover).text_color(t.foreground))
      .when(Boolean(tip), el => el.tooltip(tip))
      .on_mouse_down("left", (_e, cx) => cx.stop_propagation()).on_click(action).child(label);
  }

  footer(t, collapsed) {
    const row = (id, name, label, dim, action) => h_flex().id(id).h(28).flex_1().min_w(0).px(8).gap(9).items_center().rounded(8)
      .text_color(dim ? t.dim : t.muted).hover(s => s.bg(t.hover).text_color(t.foreground)).cursor_pointer()
      .on_click(action).child(icon(name).size(14))
      .when(!collapsed, el => el.child(label));
    const toggle = this.button("sidebar-toggle", icon("sidebar").size(15), toggleSidebar, collapsed ? "Expand sidebar" : "Collapse sidebar");
    return v_flex().size_full().bg(t.chrome).border_t(1).border_color(t.border).px(8).pt(4).pb(8).text_size(13)
      // Expanded: the toggle at the end of the Add machine row. On the narrow rail there's
      // no room beside it, so it takes that row's place.
      .child(row("settings", "settings", "Settings", false, () => run("app.settings"))
        .when(Boolean(updates().app.ready), el => el.child(div().size(6).rounded_full().bg(t.accent))))
      .child(collapsed
        ? h_flex().px(1).child(toggle)
        : h_flex().items_center().gap(2)
          .child(row("machine", "plus", "Add machine", true, () => run("mod.open", { name: "machine-add" })))
          .child(toggle));
  }

  brand(t, collapsed) {
    return h_flex().size_full().bg(t.chrome).pl(collapsed ? 6 : 14).pr(10).gap(4).items_center().text_size(13.5)
      .when(window()?.platform === "macos" && !window()?.fullscreen && !collapsed, el => el.pl(76))
      .when(!collapsed, el => el.child(h_flex().flex_1().gap(8).items_center().child(image("frame/welcome/herdr.png").size(20).rounded(5)).child(div().font_semibold().text_color(t.foreground).child("Herdr"))))
      .when(!collapsed, el => el.child(this.button("search", icon("search").size(15), () => run("mod.open", { name: "picker" }))));
  }

  render() {
    const t = theme();
    const collapsed = narrow();
    return props()?.part === "footer" ? this.footer(t, collapsed) : this.brand(t, collapsed);
  }
}
