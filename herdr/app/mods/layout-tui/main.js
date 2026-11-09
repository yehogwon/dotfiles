// The tui layout's sidebar panels, herdr TUI style, in one mod.
// The layout gives each copy props { part }:
//   "brand":  the top row: logo, search (chrome.js)
//   "spaces": hosts and their spaces (spaces.js)
//   "agents": the agents list (agents.js), and its sort menu popup ({ part: "agents", sortMenu: true })
//   "footer": Settings, the sidebar collapse button, Add machine (chrome.js)

import { View, div } from "gpui-kit";
import { props } from "herdr";
import Spaces from "./spaces.js";
import Agents from "./agents.js";
import Chrome from "./chrome.js";

const PARTS = { brand: Chrome, spaces: Spaces, agents: Agents, footer: Chrome };

export default class LayoutTui extends View {
  init(p, cx) {
    const pr = props() ?? p ?? {};
    const Part = PARTS[pr.part];
    this.part = Part ? new Part() : null;
    this.part?.init?.(pr, cx);
  }

  render(cx) {
    if (!this.part) return div().child(`layout-tui: no part "${props()?.part}" (brand, spaces, agents or footer)`);
    return this.part.render(cx);
  }

  async close(cx) {
    await this.part?.close?.(cx);
  }
}
