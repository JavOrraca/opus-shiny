# AI SQL Chatbot -- Agent Instructions

## Overview

A Shiny app for natural language to SQL data analysis, powered by Claude
(Anthropic) via R's `ellmer` package. Users ask questions in plain English,
Claude generates SQL via tool calling, the query executes against the
database, and results are displayed with a natural language summary.

## Architecture

```
User question (plain English)
        |
        v
shinychat (chat UI widget)
        |
        v
ellmer chat_anthropic() + stream_async()
        |
        v
Claude decides to call execute_sql tool
        |
        v
R/tool_sql.R validates + executes via DBI
        |
        v
Results -> Claude summarises -> chat + reactable table
```

### File Structure

```
app.R                 # Shiny UI + server (sources R/*.R)
R/
  database.R          # Connection layer: connect_sqlite(), connect_tibble(),
                      #   connect_adbc(), get_connection(), validate_query()
  schema.R            # get_db_schema() -- DBI-generic, no SQLite PRAGMA
  tool_sql.R          # create_sql_tool() -- ellmer tool() for SQL execution
data/
  create_db.R         # Sample e-commerce SQLite database generator
renv.lock             # Locked package versions (reproducibility)
renv/
  activate.R          # renv bootstrap script (committed to git)
  settings.json       # renv project settings
DESCRIPTION           # Dependency declarations (read by renv in explicit mode)
.Rprofile             # Activates renv on R startup
.Renviron.example     # Environment variable template
```

## Key Design Decisions

1. **ellmer tool()** -- Claude calls `execute_sql` directly via tool use
   instead of outputting SQL in markdown fences. More reliable than regex.
2. **stream_async()** -- Non-blocking streaming in Shiny so the UI stays
   responsive during Claude's response.
3. **DBI-generic** -- Schema introspection uses `dbListTables()` +
   `dbColumnInfo()`, not SQLite-specific PRAGMA. Works with any backend.
4. **Three database tiers** -- SQLite (zero-config), DuckDB (for tibbles),
   ADBC (remote databases). Only SQLite is required; others are optional.
5. **Read-only safety** -- `validate_query()` rejects non-SELECT statements.
   Defence in depth: system prompt instructs Claude, tool function validates.
6. **Bootstrap 5 dark theme** -- via `bslib::bs_theme()` with custom palette.
7. **renv for reproducibility** -- `renv.lock` pins exact package versions.
   Uses "explicit" snapshot type (reads from DESCRIPTION Imports).
   After adding/updating packages, run `renv::snapshot()` to update the lockfile.

## Coding Style

- Tidyverse conventions throughout
- Use the base R pipe operator `|>`
- Use `snake_case` for all function and variable names
- Handle errors with `tryCatch()`
- Keep `app.R` focused on UI/server; put logic in `R/*.R` modules

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `ANTHROPIC_API_KEY` | Yes | -- | Anthropic API key |
| `DB_PATH` | No | `data/sample.sqlite` | Path to database file |
| `CLAUDE_MODEL` | No | `claude-sonnet-4-20250514` | Claude model ID |
| `DB_TYPE` | No | `sqlite` | `sqlite` or `adbc` |
| `ADBC_DRIVER` | No | -- | ADBC driver name |
| `ADBC_URI` | No | -- | ADBC connection URI |

## Running Locally

```bash
cp .Renviron.example .Renviron
# Edit .Renviron and set ANTHROPIC_API_KEY
Rscript -e "renv::restore()"       # Install locked package versions
Rscript data/create_db.R
Rscript -e "shiny::runApp()"
```

## Package Management

This project uses renv with "explicit" snapshot type -- it reads the
`Imports` field of `DESCRIPTION` to determine which packages to lock.

- After adding a new package: add it to DESCRIPTION Imports, run
  `renv::install("pkg")`, then `renv::snapshot()`
- After updating a package: run `renv::update("pkg")`, then
  `renv::snapshot()`
- Commit `renv.lock` to git after any snapshot

## Key Packages

| Package | Purpose |
|---------|---------|
| shiny | Core reactive web framework |
| bslib | Bootstrap 5 theming and layout |
| shinychat | Chat UI widget with streaming |
| ellmer | LLM communication (Claude) with tool use |
| DBI | Database interface |
| RSQLite | SQLite driver |
| reactable | Interactive data tables |
| jsonlite | JSON serialisation for tool results |
