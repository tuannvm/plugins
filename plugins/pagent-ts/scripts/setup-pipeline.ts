#!/usr/bin/env node
// Pagent Pipeline Setup Script
//
// Initializes the Ralph loop that orchestrates the entire pipeline.
//
// Usage: setup-pipeline.ts <prd-file> [--workflow prd-to-code] [--max-stages N]

import { join, resolve } from 'node:path'
import { realpathSync } from 'node:fs'
import { mkdir, writeFile, readFile, access } from 'node:fs/promises'

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
  workflow_type: string
  started_at: string
  prd_file: string
  prd_path: string
  iterations: Iterations
  stages: Stage[]
}

// ============================================================
// Constants
// ============================================================

const WORKDIR = realpathSync(process.cwd())
const CLAUDE_DIR = join(WORKDIR, '.claude')
const PROMPTS_DIR = join(CLAUDE_DIR, 'prompts')
const PIPELINE_STATE = join(CLAUDE_DIR, 'pagent-pipeline.json')

// ============================================================
// Parse Arguments
// ============================================================

let prdFile = ''
let workflowType = 'prd-to-code'
let maxStages = 0

for (let i = 2; i < process.argv.length; i++) {
  const arg = process.argv[i]
  if (arg === '--workflow') {
    workflowType = process.argv[++i]
  } else if (arg === '--max-stages') {
    maxStages = parseInt(process.argv[++i], 10)
  } else if (arg.startsWith('-')) {
    console.error(`❌ Error: Unknown option: ${arg}`)
    console.error('   Usage: /pagent-run <prd-file> [--workflow prd-to-code] [--max-stages N]')
    process.exit(1)
  } else {
    prdFile = arg.startsWith('@') ? arg.slice(1) : arg
  }
}

// ============================================================
// Validation
// ============================================================

if (!prdFile) {
  console.error('❌ Error: No PRD file specified')
  console.error('   Usage: /pagent-run <prd-file>')
  process.exit(1)
}

const prdPath = resolve(WORKDIR, prdFile)

try {
  await readFile(prdPath, 'utf-8')
} catch {
  console.error(`❌ Error: PRD file not found: ${prdFile}`)
  process.exit(1)
}

// Check for existing pipeline
try {
  const existingState = await readFile(PIPELINE_STATE, 'utf-8')
  const state = JSON.parse(existingState) as PipelineState
  const currentStage = state.stage
  if (currentStage && currentStage !== 'complete') {
    console.error(`⚠️  Active pipeline found at stage: ${currentStage}`)
    console.error('   Use /pagent-cancel first to stop it, then run again.')
    process.exit(1)
  }
} catch {
  // No existing pipeline, continue
}

// ============================================================
// Prompt Templates
// ============================================================

const prompts: Record<string, string> = {
  architect: `You are the Software Architect.

Read the PRD at PRD_PATH and create a comprehensive technical architecture in architecture.md.

Your architecture.md should include:
1. **System Overview**: High-level system design and components
2. **Technology Stack**: Recommended languages, frameworks, and libraries (justify choices)
3. **API Design**: All endpoints with methods, paths, request/response schemas
4. **Data Models**: Database schema, data structures, relationships
5. **Architecture Decisions (ADRs)**: Key technical decisions with rationale
6. **Security Considerations**: Authentication, authorization, data protection
7. **Deployment Architecture**: How the system will be deployed and scaled

Be thorough and specific. Use markdown formatting with clear sections.
Target 100+ lines of detailed technical specification.
`,

  qa: `You are the QA Engineer.

Read architecture.md and create a comprehensive test plan in test-plan.md.

Your test-plan.md should include:
1. **Test Strategy**: Overall approach (unit, integration, e2e, performance)
2. **Test Coverage Plan**: What will be tested, coverage targets
3. **Test Cases**: Specific test scenarios with preconditions, steps, expected results, priority
4. **Acceptance Criteria**: Definition of done for each feature
5. **Testing Tools**: Recommended frameworks and tools
6. **Test Data Strategy**: How test data will be managed

Focus on practical, actionable test cases that validate the architecture.
Target 80+ lines.
`,

  security: `You are the Security Analyst.

Read architecture.md and create a security assessment in security-assessment.md.

Your security-assessment.md should include:
1. **Threat Model**: Potential attack vectors and threats
2. **Security Requirements**: Authentication, authorization, encryption, audit logging
3. **Vulnerability Analysis**: OWASP Top 10, common vulnerabilities to address
4. **Security Controls**: Mitigation strategies for identified threats
5. **Compliance**: GDPR, SOC2, PCI-DSS considerations (if applicable)
6. **Security Testing Plan**: How security will be validated
7. **Secure Development Practices**: Guidelines for secure coding

Be specific about security measures. Don't just say 'use encryption' - specify what, where, and how.
Target 60+ lines.
`,

  implementer: `You are the Software Implementer.

Read the PRD, architecture.md, test-plan.md, and security-assessment.md.
Implement the complete, working codebase in a src/ directory.

Requirements:
1. **Follow the architecture**: Implement what was specified in architecture.md
2. **Write clean code**: Follow language best practices, proper error handling
3. **Include comments**: Document non-obvious code, complex logic
4. **Security first**: Implement the security controls from security-assessment.md
5. **API implementation**: All endpoints from architecture.md must work
6. **Data models**: Implement the database schema and data structures
7. **Entry point**: Include main.go or equivalent entry point
8. **README**: Create README.md with setup/run instructions
9. **Dependencies**: Include go.mod, package.json, requirements.txt, etc.

The code should be production-ready, fully functional, well-organized, and error-handled.
Create at least 3 source files in src/ directory.
`,

  verifier: `You are the Verification Engineer.

Review all work: PRD requirements, architecture.md, test-plan.md, security-assessment.md, src/ code.

Your tasks:
1. **Verify completeness**: Check all PRD requirements are addressed
2. **Add tests**: Create comprehensive tests (src/*_test.go or tests/)
3. **Verify implementation**: Code matches architecture specifications
4. **Security check**: Confirm security controls are implemented
5. **Create verification-report.md** documenting what was verified, test results, issues found, recommendations

After completing verification and all tests pass, output:
<promise>DONE</promise>

This signals the pipeline is complete.
`
}

// ============================================================
// Initialize Pipeline
// ============================================================

// Create directories
await mkdir(PROMPTS_DIR, { recursive: true })

// Write prompt files
await writeFile(join(PROMPTS_DIR, 'architect.txt'), prompts.architect)
await writeFile(join(PROMPTS_DIR, 'qa.txt'), prompts.qa)
await writeFile(join(PROMPTS_DIR, 'security.txt'), prompts.security)
await writeFile(join(PROMPTS_DIR, 'implementer.txt'), prompts.implementer)
await writeFile(join(PROMPTS_DIR, 'verifier.txt'), prompts.verifier)

// Generate pipeline state
const pipelineState: PipelineState = {
  stage: 'architect',
  max_stages: maxStages,
  workflow_type: workflowType,
  started_at: new Date().toISOString().slice(0, 19) + 'Z',
  prd_file: prdFile,
  prd_path: prdPath,
  iterations: {},
  stages: [
    {
      name: 'architect',
      prompt_file: '.claude/prompts/architect.txt',
      exit_when: { file_exists: 'architecture.md', min_lines: 50 }
    },
    {
      name: 'qa',
      prompt_file: '.claude/prompts/qa.txt',
      exit_when: { file_exists: 'test-plan.md', min_lines: 30 }
    },
    {
      name: 'security',
      prompt_file: '.claude/prompts/security.txt',
      exit_when: { file_exists: 'security-assessment.md', min_lines: 20 }
    },
    {
      name: 'implementer',
      prompt_file: '.claude/prompts/implementer.txt',
      exit_when: { directory_exists: 'src', min_files: 3 }
    },
    {
      name: 'verifier',
      prompt_file: '.claude/prompts/verifier.txt',
      exit_when: { promise_in_output: 'DONE' }
    }
  ]
}

await writeFile(PIPELINE_STATE, JSON.stringify(pipelineState, null, 2))

// ============================================================
// Output Summary
// ============================================================

console.log('')

console.log('🤖 Pagent pipeline initialized!')
console.log('')
console.log('The Ralph loop orchestrator is now active.')
console.log('It will automatically progress through 5 stages:')
console.log('  1. architect → 2. qa → 3. security → 4. implementer → 5. verifier')
console.log('')
console.log('Use /pagent-status to check progress.')
console.log('Use /pagent-cancel to stop.')
console.log('')
console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
console.log('Starting Stage 1: Architect')
console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
console.log('')

// Output the first prompt (substituting PRD_PATH)
const firstPrompt = prompts.architect.replace(/PRD_PATH/g, prdPath)
console.log(firstPrompt)
