#!/usr/bin/env node
// Pagent Ralph Loop Orchestrator
//
// A single Ralph-style loop that orchestrates all pipeline stages.
// Each stage loops until its exit condition is met, then advances.
// Only when ALL stages complete does it output DONE.
//
// This mimics human-like software development: iterate until done.

import { join } from 'node:path'
import { realpathSync } from 'node:fs'
import { readFile, writeFile, access, stat, readdir } from 'node:fs/promises'

// ============================================================
// Types
// ============================================================

interface ExitCondition {
  file_exists?: string
  min_lines?: number
  directory_exists?: string
  min_files?: number
  promise_in_output?: string
}

interface Stage {
  name: string
  prompt_file: string
  exit_when: ExitCondition
}

interface Iterations {
  [stageName: string]: number
}

interface PipelineState {
  stage: string
  max_stages: number
  workflow_type?: string
  started_at?: string
  prd_file?: string
  prd_path?: string
  iterations: Iterations
  stages: Stage[]
  completed_at?: string
}

interface HookInput {
  transcript_path?: string
}

interface HookOutput {
  decision: 'block'
  reason: string
  systemMessage: string
}

// ============================================================
// Constants
// ============================================================

const WORKDIR = process.env.CLAUDE_PROJECT_DIR ?? realpathSync(process.cwd())
const PIPELINE_STATE = join(WORKDIR, '.claude', 'pagent-pipeline.json')

// ============================================================
// Exit Condition Checkers
// ============================================================

async function checkExitCondition(
  condition: ExitCondition,
  workDir: string,
  transcriptPath: string
): Promise<boolean> {
  const type = Object.keys(condition)[0] as keyof ExitCondition

  switch (type) {
    case 'file_exists': {
      const file = condition.file_exists!
      const minLines = condition.min_lines ?? 0
      const filePath = join(workDir, file)

      try {
        await access(filePath)
        if (minLines > 0) {
          const content = await readFile(filePath, 'utf-8')
          const lines = content.split('\n').length
          return lines >= minLines
        }
        return true
      } catch {
        return false
      }
    }

    case 'directory_exists': {
      const dir = condition.directory_exists!
      const minFiles = condition.min_files ?? 0
      const dirPath = join(workDir, dir)

      try {
        const stats = await stat(dirPath)
        if (!stats.isDirectory()) return false
        if (minFiles > 0) {
          const files = await readdir(dirPath)
          const fileCount = files.length
          return fileCount >= minFiles
        }
        return true
      } catch {
        return false
      }
    }

    case 'promise_in_output': {
      const promise = condition.promise_in_output!
      try {
        const content = await readFile(transcriptPath, 'utf-8')
        return content.includes(`<promise>${promise}</promise>`)
      } catch {
        return false
      }
    }

    default:
      return true
  }
}

async function getStageProgress(workDir: string): Promise<string> {
  const outputs: string[] = []

  const checks = [
    { path: join(workDir, 'architecture.md'), name: 'architecture.md ✓' },
    { path: join(workDir, 'test-plan.md'), name: 'test-plan.md ✓' },
    { path: join(workDir, 'security-assessment.md'), name: 'security-assessment.md ✓' },
    { path: join(workDir, 'src'), name: 'src/ ✓', isDir: true },
    { path: join(workDir, 'verification-report.md'), name: 'verification-report.md ✓' }
  ]

  for (const check of checks) {
    try {
      if (check.isDir) {
        await stat(check.path)
        outputs.push(check.name)
      } else {
        await access(check.path)
        outputs.push(check.name)
      }
    } catch {
      // File doesn't exist, skip
    }
  }

  return outputs.length > 0 ? outputs.join(', ') : '(no outputs yet)'
}

// ============================================================
// Main Logic
// ============================================================

async function main(): Promise<void> {
  // Read hook input from stdin
  let hookInput: HookInput = {}
  try {
    const inputChunks: Buffer[] = []
    for await (const chunk of process.stdin) {
      inputChunks.push(chunk as Buffer)
    }
    const inputStr = Buffer.concat(inputChunks).toString()
    if (inputStr.trim()) {
      hookInput = JSON.parse(inputStr) as HookInput
    }
  } catch {
    hookInput = {}
  }

  const transcriptPath = hookInput.transcript_path ?? ''

  // Check if pipeline exists
  try {
    await access(PIPELINE_STATE)
  } catch {
    // No pipeline - allow exit
    process.exit(0)
  }

  // Read and validate pipeline state
  let state: PipelineState | undefined
  try {
    const content = await readFile(PIPELINE_STATE, 'utf-8')
    state = JSON.parse(content) as PipelineState
  } catch {
    console.error('⚠️  Pagent: Corrupted state. Run /pagent-run to reinitialize.')
    process.exit(1)
  }

  if (!state) {
    console.error('⚠️  Pagent: Corrupted state. Run /pagent-run to reinitialize.')
    process.exit(1)
  }

  const stage = state.stage
  const stages = state.stages ?? []
  const maxStages = state.max_stages ?? 0
  const prdPath = state.prd_path ?? ''

  if (!stage) {
    process.exit(0)
  }

  // Check max stages
  if (maxStages > 0) {
    const currentIndex = stages.findIndex(s => s.name === stage)
    if (currentIndex >= maxStages) {
      console.error(`🛑 Pagent: Max stages (${maxStages}) reached.`)
      state.stage = 'stopped_at_max'
      await writeFile(PIPELINE_STATE, JSON.stringify(state, null, 2))
      process.exit(0)
    }
  }

  // Find current stage index
  const stageIndex = stages.findIndex(s => s.name === stage)
  if (stageIndex === -1) {
    process.exit(0)
  }

  const stageConfig = stages[stageIndex]
  const stageName = stageConfig.name
  const exitCondition = stageConfig.exit_when ?? {}
  const promptFile = stageConfig.prompt_file ?? ''

  // Increment iteration count
  if (!state.iterations) state.iterations = {}
  const iterations = (state.iterations[stageName] ?? 0) + 1
  state.iterations[stageName] = iterations
  await writeFile(PIPELINE_STATE, JSON.stringify(state, null, 2))

  // Check if stage is complete
  const isComplete = await checkExitCondition(exitCondition, WORKDIR, transcriptPath)

  if (isComplete) {
    // Stage complete - try to advance
    const nextIndex = stageIndex + 1
    const nextStage = stages[nextIndex]

    if (!nextStage) {
      // All stages complete!
      state.stage = 'complete'
      state.completed_at = new Date().toISOString()
      await writeFile(PIPELINE_STATE, JSON.stringify(state, null, 2))

      console.error('')
      console.error('✅ Pagent: All stages complete!')
      console.error(`   ${stages.length} stages finished successfully.`)
      console.error('')

      // Output final completion promise
      const output: HookOutput = {
        decision: 'block',
        reason: 'Pipeline complete! All 5 stages finished successfully.',
        systemMessage: ''
      }
      console.log(JSON.stringify(output))
      process.exit(0)
    }

    // Advance to next stage
    const nextStageName = nextStage.name
    const nextPromptFile = nextStage.prompt_file ?? ''
    let nextPrompt = 'Prompt not found'
    try {
      const promptContent = await readFile(join(WORKDIR, nextPromptFile), 'utf-8')
      nextPrompt = promptContent.replace(/PRD_PATH/g, prdPath)
    } catch {
      // Use default
    }

    console.error(`🔄 Pagent: '${stageName}' → '${nextStageName}' (after ${iterations} iteration(s))`)

    // Update state
    state.stage = nextStageName
    await writeFile(PIPELINE_STATE, JSON.stringify(state, null, 2))

    // Inject next stage prompt
    const progress = await getStageProgress(WORKDIR)
    const systemMsg = `🔄 Pagent Stage: ${nextStageName}
Previous stage '${stageName}' completed after ${iterations} iteration(s).
Working with: ${progress}`

    const output: HookOutput = {
      decision: 'block',
      reason: nextPrompt,
      systemMessage: systemMsg
    }
    console.log(JSON.stringify(output))
    process.exit(0)
  }

  // Stage NOT complete - loop on same stage
  // Read the current prompt again
  let currentPrompt = 'Prompt not found'
  try {
    const promptContent = await readFile(join(WORKDIR, promptFile), 'utf-8')
    currentPrompt = promptContent.replace(/PRD_PATH/g, prdPath)
  } catch {
    // Use default
  }

  // Build retry message with iteration context
  const progress = await getStageProgress(WORKDIR)
  const systemMsg = `🔄 Pagent Stage: ${stageName} (iteration ${iterations})
Stage not complete yet. Continue working.
Progress: ${progress}
Tip: Focus on completing the exit condition: ${JSON.stringify(exitCondition)}`

  // Block exit and inject the same prompt (Ralph-style loop)
  const output: HookOutput = {
    decision: 'block',
    reason: currentPrompt,
    systemMessage: systemMsg
  }
  console.log(JSON.stringify(output))

  process.exit(0)
}

main().catch(err => {
  console.error('Error in orchestrator:', err)
  process.exit(1)
})
