import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { HudAgent, HudLimit, HudLoop, HudMain, HudTodo } from '../types'

type Seg = { text: string; color?: string; dim?: boolean }
type TodoRow = { tool: string; input: Record<string, unknown>; result?: unknown }

const MAIN = ''
const TICK_MS = 5000
const EFFORT_SYMBOLS: Record<string, string> = { low: '○', medium: '◔', high: '◑', xhigh: '◕', max: '●' }
const TODO_TOOLS = new Set(['TodoWrite', 'TaskCreate', 'TaskUpdate'])
const ENDED = new Set(['completed', 'failed', 'killed'])
const SEP: Seg = { text: ' │ ' }

const main = atom({ plugin: 'hud', key: 'main' } as const, {
  model: '',
  project: '',
  branch: null,
  isDirty: false,
  startedAt: null,
  contextPercent: null,
  limits: [],
  counts: { claudeMd: 0, rules: 0, mcps: 0, hooks: 0 },
})
const loops = atom({ plugin: 'hud', key: 'loops' } as const, {})
const agents = atom({ plugin: 'hud', key: 'agents' } as const, [])
const todos = atom({ plugin: 'hud', key: 'todos' } as const, [])
const now = atom({ plugin: 'hud', key: 'now' } as const, 0)

let isGitStale = true
let areCountsStale = true

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const result = await next(e)
    isGitStale = true
    areCountsStale = true
    const plan = await readPlan($)
    await update($, main, ({ plan: _, ...m }) => ({ ...m, ...(plan !== undefined && { plan }) }))
    $.clock.every(TICK_MS, () => void tick($))
    await tick($)
    const messages = await $.session.messages()
    const rows = messages.flatMap(m => m.toolUses).filter(u => TODO_TOOLS.has(u.tool))
    await update($, todos, () => rows.reduce(applyTodo, [] as HudTodo[]))
    return result
  })

  on('session.end', async ($, e, next) => {
    if (e.reason === 'clear') {
      await update($, loops, () => ({}))
      await update($, agents, () => [])
      await update($, todos, () => [])
    }
    return next(e)
  })

  on('session.measure', async ($, e, next) => {
    await update($, main, m => ({
      ...m,
      contextPercent: e.context.percent ?? null,
      limits: e.rateLimits.map(toLimit),
    }))
    return next(e)
  })

  on('turn.step', async function* ($, e, next) {
    const response = yield* next(e)
    const usage = response.usage
    if (usage !== null) {
      const loop: HudLoop = {
        model: usage.model,
        input: usage.input_tokens,
        cache: usage.cache_read_input_tokens + usage.cache_creation_input_tokens,
        ...(e.effort !== undefined && { effort: e.effort }),
      }
      await update($, loops, all => ({ ...all, [e.agentId ?? MAIN]: loop }))
    }
    return response
  })

  on('agent.spawn', async ($, e, next) => {
    const result = await next(e)
    if (result.agentId !== undefined) {
      const model = result.model ?? e.model
      const agent: HudAgent = {
        id: result.agentId,
        type: e.subagentType,
        description: e.description,
        status: 'running',
        startedAt: await $.clock.now(),
        ...(model !== undefined && { model }),
      }
      await update($, agents, list => [...list.slice(-19), agent])
    }
    return result
  })

  on('turn.complete', async ($, e, next) => {
    if (e.agentId === undefined) {
      isGitStale = true
      areCountsStale = true
    } else {
      const at = await $.clock.now()
      await update($, agents, list => list.map(a => (a.id === e.agentId ? settle(a, 'completed', at) : a)))
    }
    return next(e)
  })

  on('tool.call', async ($, e, next) => {
    const result = await next(e)
    if (e.agentId === undefined) {
      isGitStale = true
      const tool = String(e.tool)
      if (TODO_TOOLS.has(tool)) {
        const row: TodoRow = { tool, input: e as unknown as Record<string, unknown>, result: result.result }
        await update($, todos, list => applyTodo(list, row))
      }
    }
    return result
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    if (e.props.hasSurvey) {
      return next(e)
    }
    const [m, loopMap, agentList, todoList, at] = await Promise.all([
      read($, main),
      read($, loops),
      read($, agents),
      read($, todos),
      read($, now),
    ])
    const viewedId = e.props.view.agentId
    const viewed = viewedId === undefined ? undefined : agentList.find(a => a.id === viewedId)
    const rows: Seg[][] =
      viewedId === undefined
        ? [identityRow(m, loopMap[MAIN], at), [...contextRow(m, loopMap[MAIN]), ...usageRow(m.limits, at)]]
        : [agentIdentityRow(viewedId, viewed, loopMap[viewedId]), [...agentContextRow(loopMap[viewedId]), ...usageRow(m.limits, at)]]
    rows.push(countsRow(m.counts), ...agentRows(agentList, at), todoRow(todoList))

    const { Box, Text } = $.ui.resolve(e)
    return (
      <Box flexDirection="column" borderStyle="round" borderDimColor paddingX={1}>
        {rows
          .filter(row => row.length > 0)
          .map(row => (
            <Text wrap="truncate-end">
              {row.map(s => (
                <Text color={s.color ?? 'text'} dimColor={s.dim === true}>
                  {s.text}
                </Text>
              ))}
            </Text>
          ))}
      </Box>
    )
  })
}

async function tick($: EngineInterface): Promise<void> {
  const [model, usage, listed, cwd, at] = await Promise.all([
    $.session.model(),
    $.session.usage(),
    $.agent.list(),
    $.session.cwd(),
    $.clock.now(),
  ])
  const git = isGitStale ? await readGit($, cwd) : {}
  isGitStale = false
  if (areCountsStale) {
    areCountsStale = false
    await refreshCounts($)
  }
  await update($, main, m => ({
    ...m,
    ...git,
    model,
    project: cwd.split('/').filter(Boolean).pop() ?? '/',
    startedAt: usage.startedAt,
    contextPercent: usage.context.percent ?? null,
    limits: usage.rateLimits.map(toLimit),
  }))
  const statuses = new Map(listed.map(a => [a.id, a.status as string]))
  await update($, agents, list => list.map(a => settle(a, statuses.get(a.id), at)))
  await update($, now, () => at)
}

async function readGit($: EngineInterface, cwd: string): Promise<Pick<HudMain, 'branch' | 'isDirty'>> {
  const run = await $.process.run(['git', '--no-optional-locks', 'status', '--porcelain', '-b'], { cwd, timeoutMs: 3000 })
  if (run.exitCode !== 0) {
    return { branch: null, isDirty: false }
  }
  const [head = '', ...changes] = run.stdout.split('\n')
  const branch = /^## (?:No commits yet on )?(.+?)(?:\.\.\.| \[|$)/.exec(head)?.[1] ?? null
  return { branch, isDirty: changes.some(line => line.trim() !== '') }
}

// The login record in .claude.json, not .credentials.json, which holds the tokens.
async function readPlan($: EngineInterface): Promise<string | undefined> {
  const dir = (await $.env.get('CLAUDE_CONFIG_DIR')) ?? (await $.env.get('HOME'))
  if (dir === undefined) {
    return undefined
  }
  const account = await $.fs
    .read(`${dir}/.claude.json`)
    .then(text => (JSON.parse(text) as { oauthAccount?: Record<string, unknown> }).oauthAccount)
    .catch(() => undefined)
  const type = account?.organizationType
  if (typeof type !== 'string' || type === '') {
    return undefined
  }
  const name = type.replace(/^claude_/, '').replace(/_/g, ' ')
  const tier = account?.organizationRateLimitTier
  const multiplier = typeof tier === 'string' ? /_(\d+x)$/.exec(tier)?.[1] : undefined
  return `${name.charAt(0).toUpperCase()}${name.slice(1)}${multiplier === undefined ? '' : ` ${multiplier}`}`
}

async function refreshCounts($: EngineInterface): Promise<void> {
  const [usage, hooks] = await Promise.all([
    $.session.usage({ breakdown: 'summary' }),
    $.settings.read({ key: 'hooks' }),
  ])
  const files = usage.context.breakdown?.memoryFiles ?? []
  const counts = {
    claudeMd: files.filter(f => /(^|\/)CLAUDE(\.local)?\.md$/.test(f.path)).length,
    rules: files.filter(f => f.path.includes('/rules/')).length,
    mcps: new Set((usage.context.breakdown?.mcpTools ?? []).map(t => t.serverName)).size,
    hooks: hooks !== null && typeof hooks === 'object' ? Object.keys(hooks).length : 0,
  }
  await update($, main, m => ({ ...m, counts }))
}

function applyTodo(list: HudTodo[], row: TodoRow): HudTodo[] {
  const { input } = row
  if (row.tool === 'TodoWrite') {
    const items = Array.isArray(input.todos) ? (input.todos as { content: string; status: string }[]) : []
    return items.map(t => ({ content: t.content, status: t.status }))
  }
  if (row.tool === 'TaskCreate') {
    const id = (row.result as { task?: { id?: string } } | undefined)?.task?.id ?? String(list.length + 1)
    const content = String(input.subject || input.description || 'Untitled task')
    return [...list, { id, content, status: 'pending' }]
  }
  if (input.status === 'deleted') {
    return list.filter(t => t.id !== String(input.taskId))
  }
  return list.map(t =>
    t.id === String(input.taskId)
      ? { ...t, status: typeof input.status === 'string' ? input.status : t.status, content: typeof input.subject === 'string' ? input.subject : t.content }
      : t,
  )
}

function settle(agent: HudAgent, status: string | undefined, at: number): HudAgent {
  if (status === undefined || status === agent.status) {
    return agent
  }
  const { endedAt, ...rest } = agent
  return ENDED.has(status) ? { ...rest, status, endedAt: endedAt ?? at } : { ...rest, status }
}

function toLimit(limit: HudLimit): HudLimit {
  return { kind: limit.kind, percentUsed: limit.percentUsed, ...(limit.resetsAt !== undefined && { resetsAt: limit.resetsAt }) }
}

function identityRow(m: HudMain, loop: HudLoop | undefined, at: number): Seg[] {
  const row: Seg[] = []
  if (m.model) {
    const plan = m.plan === undefined ? '' : ` | ${m.plan}`
    row.push({ text: `[${modelName(m.model)}${effortSuffix(loop?.effort)}${plan}]`, color: 'cyan' })
  }
  if (m.project) {
    row.push(...(row.length > 0 ? [SEP] : []), { text: m.project, color: 'yellow' })
  }
  if (m.branch !== null) {
    row.push(
      { text: ' git:(', color: 'magenta' },
      { text: m.branch + (m.isDirty ? '*' : ''), color: 'cyan' },
      { text: ')', color: 'magenta' },
    )
  }
  if (m.startedAt !== null && at > 0) {
    row.push(SEP, { text: `⏱ ${span(at - m.startedAt)}`, dim: true })
  }
  return row
}

function agentIdentityRow(id: string, agent: HudAgent | undefined, loop: HudLoop | undefined): Seg[] {
  const model = loop?.model ?? agent?.model
  return [
    { text: '⤷ ' },
    { text: agent?.type ?? id, color: 'magenta' },
    ...(agent?.description ? [{ text: `: ${truncate(agent.description, 40)}`, dim: true }] : []),
    ...(model === undefined ? [] : [SEP, { text: `[${modelName(model)}${effortSuffix(loop?.effort)}]`, color: 'cyan' }]),
  ]
}

function contextRow(m: HudMain, loop: HudLoop | undefined): Seg[] {
  const percent = m.contextPercent ?? 0
  const color = percent >= 85 ? 'red' : percent >= 70 ? 'yellow' : 'green'
  const breakdown =
    percent >= 85 && loop !== undefined ? [{ text: ` (in: ${tokens(loop.input)}, cache: ${tokens(loop.cache)})`, dim: true }] : []
  return [{ text: 'Context ', dim: true }, ...bar(percent, color), { text: ` ${percent}%`, color }, ...breakdown]
}

function agentContextRow(loop: HudLoop | undefined): Seg[] {
  return [{ text: 'Context ', dim: true }, { text: loop === undefined ? '…' : tokens(loop.input + loop.cache), color: 'green' }]
}

function usageRow(limits: HudLimit[], at: number): Seg[] {
  const five = limits.find(l => l.kind === 'five_hour')
  const seven = limits.find(l => l.kind === 'seven_day')
  if (five === undefined && seven === undefined) {
    return []
  }
  const head: Seg[] = [SEP, { text: 'Usage ', dim: true }]
  const full = [five, seven].find(l => l !== undefined && l.percentUsed >= 100)
  if (full !== undefined) {
    return [...head, { text: `⚠ Limit reached${resetText(full, at)}`, color: 'red' }]
  }
  const window = (limit: HudLimit): Seg[] => {
    const color = limit.percentUsed >= 90 ? 'red' : limit.percentUsed >= 75 ? 'magentaBright' : 'blueBright'
    const percent = Math.round(limit.percentUsed)
    return [...bar(percent, color), { text: ` ${percent}%`, color }, { text: resetText(limit, at), dim: true }]
  }
  const weekly = seven === undefined ? [] : [{ text: 'Weekly ', dim: true }, ...window(seven)]
  if (five === undefined) {
    return [...head, ...weekly]
  }
  return [...head, ...window(five), ...(weekly.length > 0 ? [{ text: ' | ' }, ...weekly] : [])]
}

function countsRow(counts: HudMain['counts']): Seg[] {
  const parts = [
    [counts.claudeMd, 'CLAUDE.md'],
    [counts.rules, 'rules'],
    [counts.mcps, 'MCPs'],
    [counts.hooks, 'hooks'],
  ] as const
  const text = parts
    .filter(([n]) => n > 0)
    .map(([n, label]) => `${n} ${label}`)
    .join(' | ')
  return text ? [{ text, dim: true }] : []
}

function agentRows(list: HudAgent[], at: number): Seg[][] {
  const running = list.filter(a => !ENDED.has(a.status))
  const finished = list.filter(a => ENDED.has(a.status)).slice(-2)
  return [...running, ...finished].slice(-3).map(a => {
    const icon: Seg =
      a.status === 'completed'
        ? { text: '✓', color: 'green' }
        : ENDED.has(a.status)
          ? { text: '✗', color: 'red' }
          : { text: '◐', color: 'yellow' }
    return [
      icon,
      { text: ' ' },
      { text: a.type, color: 'magenta' },
      ...(a.model === undefined ? [] : [{ text: ` [${modelName(a.model)}]`, dim: true }]),
      ...(a.description ? [{ text: `: ${truncate(a.description, 40)}`, dim: true }] : []),
      { text: ` (${elapsed((a.endedAt ?? at) - a.startedAt)})`, dim: true },
    ]
  })
}

function todoRow(list: HudTodo[]): Seg[] {
  const done = list.filter(t => t.status === 'completed').length
  const current = list.find(t => t.status === 'in_progress')
  if (current !== undefined) {
    return [
      { text: '▸ ', color: 'yellow' },
      { text: truncate(current.content, 50) },
      { text: ` (${done}/${list.length})`, dim: true },
    ]
  }
  if (list.length > 0 && done === list.length) {
    return [{ text: '✓ ', color: 'green' }, { text: 'All todos complete' }, { text: ` (${done}/${list.length})`, dim: true }]
  }
  return []
}

function bar(percent: number, color: string): Seg[] {
  const filled = Math.round(Math.min(100, Math.max(0, percent)) / 10)
  return [
    { text: '█'.repeat(filled), color },
    { text: '░'.repeat(10 - filled), dim: true },
  ]
}

function resetText(limit: HudLimit, at: number): string {
  const resetsAt = limit.resetsAt === undefined ? NaN : Date.parse(limit.resetsAt)
  return Number.isNaN(resetsAt) || at === 0 ? '' : ` (resets in ${span(resetsAt - at)})`
}

function modelName(model: string): string {
  const bare = model.replace(/\[[^\]]*\]$/, '').replace(/\s*\([^)]*context[^)]*\)/i, '').trim()
  const id = /claude-([a-z]+)-(\d+)(?:-(\d{1,2}))?(?!\d)/i.exec(bare)
  if (id === null) {
    return bare.charAt(0).toUpperCase() + bare.slice(1)
  }
  const [, family = '', major, minor] = id
  return `${family.charAt(0).toUpperCase()}${family.slice(1)} ${major}${minor === undefined ? '' : `.${minor}`}`
}

function effortSuffix(effort: string | number | undefined): string {
  if (effort === undefined) {
    return ''
  }
  const symbol = typeof effort === 'string' ? EFFORT_SYMBOLS[effort] : undefined
  return symbol === undefined ? ` ${effort}` : ` ${symbol} ${effort}`
}

function span(ms: number): string {
  const mins = Math.floor(Math.max(0, ms) / 60000)
  if (mins < 1) return '<1m'
  if (mins < 60) return `${mins}m`
  const hours = Math.floor(mins / 60)
  if (hours < 24) return `${hours}h ${mins % 60}m`
  return `${Math.floor(hours / 24)}d ${hours % 24}h`
}

function elapsed(ms: number): string {
  const secs = Math.floor(Math.max(0, ms) / 1000)
  if (secs < 1) return '<1s'
  if (secs < 60) return `${secs}s`
  if (secs < 3600) return `${Math.floor(secs / 60)}m ${secs % 60}s`
  return span(ms)
}

function tokens(n: number): string {
  if (n < 1000) return String(n)
  if (n < 1_000_000) return `${Math.round(n / 1000)}k`
  return `${(n / 1_000_000).toFixed(1)}M`
}

function truncate(text: string, max: number): string {
  return text.length > max ? `${text.slice(0, max - 1)}…` : text
}
