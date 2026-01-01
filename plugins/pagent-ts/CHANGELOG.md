# Changelog

All notable changes to the pagent-ts plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.0.1] - 2025-12-31

### Added
- Initial release of pagent-ts plugin (TypeScript implementation)
- Five-stage pipeline: architect → qa → security → implementer → verifier
- Ralph loop orchestration for iterative development
- Commands: `/pagent-run`, `/pagent-status`, `/pagent-cancel`
- Hook-based pipeline state management using Claude Code Stop hook
- PRD to working software transformation
- Full TypeScript type safety with strict mode enabled
- Native JSON handling (no jq dependency)
- Async/await for cleaner async operations
- Runtime via tsx (no build step required)
