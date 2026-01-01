#!/usr/bin/env node
// Pagent Status Checker
//
// Outputs pipeline status as key=value pairs for consumption by pagent-status.md

import { join } from 'node:path'
import { realpathSync, Dirent } from 'node:fs'
import { readFile, access, stat, readdir } from 'node:fs/promises'

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

// ============================================================
// Constants
// ============================================================

const WORKDIR = process.env.CLAUDE_PROJECT_DIR ?? realpathSync(process.cwd())
const PIPELINE_STATE = join(WORKDIR, '.claude', 'pagent-pipeline.json')

// ============================================================
// Helper Functions
// ============================================================

async function getLineCount(filePath: string): Promise<number> {
  try {
    const content = await readFile(filePath, 'utf-8')
    return content.split('\n').length
  } catch {
    return 0
  }
}

async function getFileCount(dirPath: string): Promise<number> {
  try {
    const files = await readdir(dirPath, { withFileTypes: true })
    return files.filter((f: Dirent) => f.isFile()).length
  } catch {
    return 0
  }
}

// ============================================================
// Main Logic
// ============================================================

async function main(): Promise<void> {
  try {
    await access(PIPELINE_STATE)
  } catch {
    console.log('ACTIVE=false')
    return
  }

  const content = await readFile(PIPELINE_STATE, 'utf-8')
  const state = JSON.parse(content) as PipelineState

  const stage = state.stage ?? ''
  const started = state.started_at ?? ''
  const prd = state.prd_file ?? 'unknown'
  const stages = state.stages ?? []
  const total = stages.length

  let completed = 0
  if (stage === 'complete') {
    completed = total
  } else {
    completed = stages.findIndex(s => s.name === stage)
    if (completed < 0) completed = 0
  }

  console.log(`ACTIVE=true`)
  console.log(`STAGE=${stage}`)
  console.log(`STARTED=${started}`)
  console.log(`PRD=${prd}`)
  console.log(`COMPLETED=${completed}`)
  console.log(`TOTAL=${total}`)

  // Check outputs
  try {
    await access(join(WORKDIR, 'architecture.md'))
    console.log(`OUTPUT_architecture=${await getLineCount(join(WORKDIR, 'architecture.md'))}`)
  } catch {}
  try {
    await access(join(WORKDIR, 'test-plan.md'))
    console.log(`OUTPUT_test_plan=${await getLineCount(join(WORKDIR, 'test-plan.md'))}`)
  } catch {}
  try {
    await access(join(WORKDIR, 'security-assessment.md'))
    console.log(`OUTPUT_security=${await getLineCount(join(WORKDIR, 'security-assessment.md'))}`)
  } catch {}
  try {
    await access(join(WORKDIR, 'src'))
    console.log(`OUTPUT_src=${await getFileCount(join(WORKDIR, 'src'))} files`)
  } catch {}
  try {
    await access(join(WORKDIR, 'verification-report.md'))
    console.log(`OUTPUT_verification=${await getLineCount(join(WORKDIR, 'verification-report.md'))}`)
  } catch {}
}

main().catch(err => {
  console.error(`ACTIVE=false`)
  console.error(`ERROR=${err.message}`)
  process.exit(1)
})
