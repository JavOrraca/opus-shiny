# API Component — Agent Instructions

## Overview

This is an R plumber2 API backend for a natural language to SQL chatbot. It uses the `ellmer` package to communicate with Claude (Anthropic) for converting natural language questions into SQL queries.

## Tech Stack

- **Framework**: plumber2 (R HTTP API framework)
- **LLM Integration**: ellmer (R package for Anthropic/Claude communication)
- **Database**: SQLite by default (configurable via `DB_PATH` env var)
- **Key packages**: plumber2, ellmer, DBI, RSQLite, jsonlite

## Architecture

```
api/
  plumber.R        # Main API entry point, route definitions
  run.R            # Script to start the server locally
  _server.yml      # plumber2 server configuration
  DESCRIPTION      # R package-style dependency manifest
  .Renviron.example # Template for environment variables
  R/
    chat.R         # Core chat logic using ellmer + Claude
    database.R     # Database connection, schema extraction, query execution
    utils.R        # Utility functions (error formatting, CORS, etc.)
```

## Key Constraints

- **Read-only SQL**: All generated SQL must be SELECT-only. No INSERT, UPDATE, DELETE, DROP, ALTER, or CREATE statements are permitted. The `validate_query()` function enforces this.
- **ANTHROPIC_API_KEY**: Must be set as an environment variable. The API will not start without it.
- **Database path**: Configured via `DB_PATH` env var; defaults to `../data/sample.sqlite`.

## Coding Style

- Tidyverse conventions throughout
- Use the base R pipe operator `|>`
- Use `snake_case` for all function and variable names
- Add clear comments explaining intent
- Handle errors gracefully with `tryCatch()`

## Environment Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `ANTHROPIC_API_KEY` | Yes | — | Anthropic API key for Claude access |
| `DB_PATH` | No | `../data/sample.sqlite` | Path to SQLite database file |
| `API_PORT` | No | `8080` | Port the API server listens on |
| `CLAUDE_MODEL` | No | `claude-sonnet-4-20250514` | Claude model identifier |

## API Endpoints

| Method | Path | Description |
|---|---|---|
| `POST` | `/api/chat` | Send a natural language message, get SQL + results back |
| `GET` | `/api/schema` | Return the database schema |
| `POST` | `/api/execute` | Validate and execute a raw SQL query |
| `GET` | `/api/health` | Health check |

## Running Locally

```bash
cd api
cp .Renviron.example .Renviron
# Edit .Renviron and set your ANTHROPIC_API_KEY
Rscript run.R
```
