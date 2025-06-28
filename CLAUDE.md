# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an experimental project that will first write a plan, then write engineering specs from that plan, and then build from those specs. The project is a clone of the WinAmp player as specified in the plan document "WinAmp_Plan.md"

## Key Commands

### Running the Infinite Agentic Loop

```bash
claude
```

Then use the `/project:infinite` slash command with these variants:

```bash
# Single generation
/project:infinite specs/invent_new_winamp_skin.md src 1

# Small batch (5 iterations)
/project:infinite specs/vent_new_winamp_skin.md src_new 5

# Large batch (20 iterations)
/project:infinite specs/vent_new_winamp_skin.md src_new 20

# Infinite mode (continuous generation)
/project:infinite specs/invvent_new_winamp_skin.md infinite_src_new/ infinite
```

## Architecture & Structure

### Command System
The project uses Claude Code's custom commands feature:
- `.claude/commands/infinite.md` - Main infinite loop orchestrator command
- `.claude/commands/prime.md` - Additional command (if present)
- `.claude/settings.json` - Permissions configuration allowing Write, MultiEdit, Edit, and Bash

### Specification-Driven Generation
- Specifications in `specs/` directory define what type of content to generate
- Current main spec: `specs/invent_new_winamp_skins.md` - WinAmp skins specfiication
- Specs define naming patterns, content structure, design dimensions, and quality standards

### Multi-Agent Orchestration Pattern
The infinite command implements sophisticated parallel agent coordination:
1. **Specification Analysis** - Deeply understands the spec requirements
2. **Directory Reconnaissance** - Analyzes existing iterations to maintain uniqueness
3. **Parallel Sub-Agent Deployment** - Launches multiple agents with distinct creative directions
4. **Wave-Based Generation** - For infinite mode, manages successive agent waves
5. **Context Management** - Optimizes context usage across all agents

### Generated Content Organization
- `src/` - Primary output directory for generated UI components
- `src_infinite/` - Alternative output for infinite generation runs
- `legacy/` - Previous iteration attempts and experiments

### Key Implementation Details
- Sub-agents receive complete context including spec, existing iterations, and unique creative assignments
- Parallel execution managed through Task tool with batch sizes optimized by count
- Progressive sophistication strategy for infinite mode waves
- Each iteration must be genuinely unique while maintaining spec compliance