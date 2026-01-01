# Changelog

All notable changes to the pagent plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.0.1] - 2025-12-31

### Added
- Initial release of pagent plugin (Bash implementation)
- Five-stage pipeline: architect → qa → security → implementer → verifier
- Ralph loop orchestration for iterative development
- Commands: `/pagent-run`, `/pagent-status`, `/pagent-cancel`
- Hook-based pipeline state management using Claude Code Stop hook
- PRD to working software transformation
- No external dependencies (bash + jq only)

