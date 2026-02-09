# AI SQL Chatbot — Natural Language to SQL Data Analysis

## Project Overview

A template application for natural language to SQL data analysis, powered by
Claude (Anthropic) via R's `ellmer` package. The app lets users ask questions
about their data in plain English and receives SQL queries, executed results,
and natural language summaries.

## Architecture

```
┌─────────────────────────┐     HTTP/JSON     ┌──────────────────────────┐
│   React / Next.js SPA   │ ◄──────────────► │   plumber2 API (R)       │
│   (frontend/)           │                   │   (api/)                 │
│                         │                   │                          │
│  • Modern chat UI       │                   │  • ellmer ↔ Claude API   │
│  • Data tables          │                   │  • SQL generation        │
│  • SQL syntax preview   │                   │  • Query execution       │
│  • Chart rendering      │                   │  • Database connections   │
└─────────────────────────┘                   └──────────┬───────────────┘
                                                         │
┌─────────────────────────┐                              │
│   Shiny (bslib) UI      │ ◄───── calls same API ──────┘
│   (shiny/)              │        or embedded via        │
│                         │        api_shiny()            │
│  • Alternative interface│                               │
│  • shinychat widget     │                   ┌───────────▼──────────┐
│  • Quick prototyping    │                   │   Database (SQLite/  │
└─────────────────────────┘                   │   DuckDB/Postgres)   │
                                              └──────────────────────┘
```

### Components

| Directory    | Technology         | Purpose                                    |
|-------------|--------------------|--------------------------------------------|
| `api/`      | R, plumber2, ellmer| Core API — LLM chat, SQL gen, query exec   |
| `frontend/` | React, Next.js, TS | Modern chat UI (static export for Connect) |
| `shiny/`    | R, bslib, shinychat| Alternative Shiny-based chat interface      |
| `data/`     | R, SQLite/DuckDB   | Sample database and seed script            |

### Deployment Target: Posit Connect

- **React frontend**: Deployed as a static SPA (`next export`)
- **plumber2 API**: Deployed via `rsconnect::deployAPI()`
- **Shiny app**: Deployed via `rsconnect::deployApp()` (optional)
- All three are separate content items on Connect
- API keys stored as encrypted environment variables on Connect

## Development Setup

### Prerequisites

- R >= 4.3 with packages: `ellmer`, `plumber2`, `DBI`, `RSQLite`, `bslib`, `shinychat`
- Node.js >= 20 with npm/pnpm
- An Anthropic API key (set `ANTHROPIC_API_KEY` in `.Renviron`)

### Quick Start

```bash
# 1. Create sample database
Rscript data/create_db.R

# 2. Start the plumber2 API (port 8080)
Rscript api/run.R

# 3. Start the React frontend (port 3000)
cd frontend && npm install && npm run dev
```

## Environment Variables

| Variable             | Required | Description                          |
|---------------------|----------|--------------------------------------|
| `ANTHROPIC_API_KEY` | Yes      | Claude API key from console.anthropic.com |
| `DB_PATH`           | No       | Path to SQLite/DuckDB file (default: `data/sample.sqlite`) |
| `API_PORT`          | No       | plumber2 API port (default: 8080)    |
| `API_BASE_URL`      | No       | URL of plumber2 API for frontend     |

## Claude Team Agents

This project is designed for multi-agent development. Each component has its
own `CLAUDE.md` with domain-specific instructions:

- **`api/CLAUDE.md`** — R API agent: plumber2 routes, ellmer integration, SQL safety
- **`frontend/CLAUDE.md`** — Frontend agent: React/Next.js, TypeScript, chat UX
- **`shiny/CLAUDE.md`** — Shiny agent: bslib layouts, shinychat, reactive patterns

## Key Design Decisions

1. **plumber2 (not plumber v1)** — Modern R API framework with better routing and Shiny embedding
2. **ellmer for LLM** — Tidyverse-maintained, consistent interface, tool-use support
3. **Static Next.js export** — Required for Posit Connect (no Node.js runtime on Connect)
4. **SQLite for demo** — Zero-config database; swap for DuckDB/Postgres in production
5. **Read-only SQL** — LLM generates SELECT-only queries; never mutates data
6. **API key as env var** — Never hardcoded; use Connect's encrypted env vars in production
