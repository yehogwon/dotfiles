export type HudLimit = { kind: string; percentUsed: number; resetsAt?: string }

export type HudMain = {
  model: string
  project: string
  branch: string | null
  isDirty: boolean
  startedAt: number | null
  contextPercent: number | null
  limits: HudLimit[]
  counts: { claudeMd: number; rules: number; mcps: number; hooks: number }
}

export type HudLoop = {
  model: string
  effort?: string | number
  input: number
  cache: number
}

export type HudAgent = {
  id: string
  type: string
  description: string
  model?: string
  status: string
  startedAt: number
  endedAt?: number
}

export type HudTodo = { id?: string; content: string; status: string }

declare module 'claude-code' {
  interface PluginState {
    hud: {
      main: HudMain
      loops: Record<string, HudLoop>
      agents: HudAgent[]
      todos: HudTodo[]
      now: number
    }
  }
}
