import { expect, mock, test } from 'claude-code/testing'
import type { On } from 'claude-code'

const NOW = Date.parse('2026-10-28T12:00:00Z')
const MINUTE = 60_000
const HOUR = 60 * MINUTE

const BAND = {
  plugin: 'hud',
  component: 'AbovePrompt',
  props: {
    hasSurvey: false,
    isWorking: false,
    maxRows: 20,
    bodyColumns: 200,
    scroll: { offset: 0, bodyRows: 20 },
    view: {},
  },
} as const

const START = { cwd: '/home/u/obsidian', surface: 'terminal', isInteractive: true } as const

function engine(on: On, mcpServers: string[] = ['notion']) {
  const clock = mock.clock(on, { now: NOW })
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('session.messages', () => ({
    value: [
      {
        role: 'assistant',
        text: '',
        toolUses: [
          { tool_use_id: 't1', tool: 'TaskCreate', input: { subject: 'Write the band' }, result: { task: { id: '1' } } },
          { tool_use_id: 't2', tool: 'TaskCreate', input: { subject: 'Test it' }, result: { task: { id: '2' } } },
          { tool_use_id: 't3', tool: 'TaskUpdate', input: { taskId: '1', status: 'in_progress' } },
        ],
      },
    ],
  }) as never)
  on('session.usage', (_, e) => ({
    value: {
      startedAt: NOW - HOUR - 5 * MINUTE,
      context: {
        tokens: 82_000,
        window: 200_000,
        percent: 41,
        ...(e.breakdown && {
          breakdown: {
            memoryFiles: [
              { path: '/home/u/obsidian/CLAUDE.md', type: 'Project', tokens: 1 },
              { path: '/home/u/obsidian/.claude/rules/a.md', type: 'Project', tokens: 1 },
              { path: '/home/u/.claude/projects/x/memory/MEMORY.md', type: 'AutoMem', tokens: 1 },
            ],
            mcpTools: mcpServers.flatMap(server => [
              { name: `mcp__${server}__search`, serverName: server, tokens: 1, isLoaded: true },
              { name: `mcp__${server}__fetch`, serverName: server, tokens: 1, isLoaded: true },
            ]),
          },
        }),
      },
      rateLimits: [
        { kind: 'five_hour', percentUsed: 23, resetsAt: new Date(NOW + 2 * HOUR + 3 * MINUTE).toISOString() },
        { kind: 'seven_day', percentUsed: 61, resetsAt: new Date(NOW + 76 * HOUR).toISOString() },
      ],
    },
  }) as never)
  on('session.model', () => ({ value: 'claude-opus-5-5' }))
  on('session.cwd', () => ({ value: '/home/u/obsidian' }))
  on('agent.list', () => ({ value: [] }))
  on('settings.read', () => ({ value: { hooks: { Stop: [], PreToolUse: [] } } }) as never)
  on('process.run', () => ({
    value: { exitCode: 0, stdout: '## main...origin/main [ahead 1]\n M a.md\n', stderr: '', isStdoutTruncated: false, isStderrTruncated: false },
  }))
  on('tool.call', () => ({ result: {} }) as never)
  on('agent.spawn', () => ({ agentId: 'a1', model: 'claude-haiku-5-5-20261001' }))
  on('turn.step', async function* (_, e) {
    return {
      turnId: e.turnId,
      index: e.index,
      answer: '',
      toolUses: [],
      stopReason: 'end_turn',
      usage: {
        model: 'claude-haiku-5-5-20261001',
        input_tokens: 4_000,
        output_tokens: 10,
        cache_read_input_tokens: 80_000,
        cache_creation_input_tokens: 0,
      },
    } as never
  })
  on('turn.complete', () => ({ text: '' }))
  return clock
}

async function rowText(ui: { find: (q: { type: string; text: RegExp }) => Promise<{ text: string } | undefined> }, text: RegExp) {
  return (await ui.find({ type: 'Text', text }))?.text
}

test('the main view shows model, git, context, usage, counts and todos', async ($, on) => {
  engine(on)
  await $.session.start(START)
  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })

  expect(await rowText(ui, /^\[Opus/)).toBe('[Opus 5.5] │ obsidian git:(main*) │ ⏱ 1h 5m')
  expect(await rowText(ui, /^Context/)).toBe(
    'Context ████░░░░░░ 41% │ Usage ██░░░░░░░░ 23% (resets in 2h 3m) | Weekly ██████░░░░ 61% (resets in 3d 4h)',
  )
  expect(await rowText(ui, /CLAUDE\.md/)).toBe('1 CLAUDE.md | 1 rules | 1 MCPs | 2 hooks')
  expect(await rowText(ui, /^▸/)).toBe('▸ Write the band (0/2)')

  await $.tool.call({ tool: 'TaskUpdate', taskId: '1', status: 'completed' } as never)
  await $.tool.call({ tool: 'TaskUpdate', taskId: '2', status: 'in_progress' } as never)
  expect(await rowText(ui, /^▸/)).toBe('▸ Test it (1/2)')
  await ui.unmount()
})

test('counts catch up with MCP servers that connect after start', async ($, on) => {
  const servers: string[] = []
  const clock = engine(on, servers)
  await $.session.start(START)
  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect(await rowText(ui, /CLAUDE\.md/)).toBe('1 CLAUDE.md | 1 rules | 2 hooks')

  servers.push('notion')
  await $.turn.complete({ turnId: 't', answer: '', durationMs: 1, isAborted: false, reason: 'answer' } as never)
  await clock.advance(5000)
  expect(await rowText(ui, /CLAUDE\.md/)).toBe('1 CLAUDE.md | 1 rules | 1 MCPs | 2 hooks')
  await ui.unmount()
})

test('viewing an agent shows its model, effort and context', async ($, on) => {
  engine(on)
  await $.session.start(START)
  await $.agent.spawn({
    tool_use_id: 'x',
    prompt: 'p',
    description: 'find run configs',
    subagentType: 'Explore',
    parentModel: 'claude-opus-5-5',
    background: false,
    fork: false,
  } as never)
  const step = $.turn.step({ turnId: 't', index: 0, model: 'claude-haiku-5-5', effort: 'low', messageCount: 1, agentId: 'a1' })
  for await (const _ of step) {
  }

  const ui = await $.ui.mount({ ...BAND, props: { ...BAND.props, view: { agentId: 'a1' } }, surface: 'terminal' })
  expect(await rowText(ui, /^⤷/)).toBe('⤷ Explore: find run configs │ [Haiku 5.5 ○ low]')
  expect(await rowText(ui, /^Context/)).toMatch(/^Context 84k │ Usage /)
  expect(await rowText(ui, /^◐/)).toBe('◐ Explore [Haiku 5.5]: find run configs (<1s)')

  await $.turn.complete({ turnId: 't', answer: '', durationMs: 1, isAborted: false, reason: 'answer', agentId: 'a1' } as never)
  expect(await rowText(ui, /^✓/)).toBe('✓ Explore [Haiku 5.5]: find run configs (<1s)')
  await ui.unmount()
})

test('a survey holding the band gets it', async ($, on) => {
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>engine</Text>
  })
  const ui = await $.ui.mount({ ...BAND, props: { ...BAND.props, hasSurvey: true }, surface: 'terminal' })
  expect(await rowText(ui, /engine/)).toBe('engine')
  await ui.unmount()
})
