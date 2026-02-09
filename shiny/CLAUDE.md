# Shiny Component -- Agent Instructions

## Overview

This is an R Shiny (bslib) alternative interface for the AI SQL Chatbot. It
provides a lightweight chat UI that can operate in two modes:

1. **Direct mode** -- uses the `ellmer` package directly to call the Claude API
2. **API mode** -- calls the plumber2 API backend (same backend the React
   frontend uses)

The default is direct mode (ellmer). To switch to API mode, set the
`API_BASE_URL` environment variable to the URL of the running plumber2 server
(e.g., `http://localhost:8080`).

## Tech Stack

- **UI framework**: shiny + bslib (Bootstrap 5 with dark theme)
- **Chat widget**: shinychat (provides `chat_ui()` / `chat_append()`)
- **LLM integration**: ellmer (direct mode) or httr2 (API mode)
- **Database**: DBI + RSQLite for local query execution
- **Results table**: reactable for interactive data tables
- **Other**: htmltools for custom HTML elements

## Architecture

```
shiny/
  app.R               # Complete Shiny application (ui + server)
  CLAUDE.md           # This file -- agent instructions
  DESCRIPTION         # Dependency manifest for rsconnect deployment
  .Renviron.example   # Template for environment variables
```

## Key Design Decisions

- **Dark theme**: Uses `bslib::bs_theme()` with a dark palette (`bg = "#0a0a12"`,
  `fg = "#e2e8f0"`, `primary = "#6366f1"`) to match the React frontend aesthetic.
- **shinychat integration**: The `chat_ui("chat")` widget handles message display
  and user input. The `chat_append("chat", stream)` function supports streaming
  responses from ellmer.
- **SQL extraction**: After each LLM response, the app extracts SQL from
  ` ```sql ` code fences and auto-executes it against the database. Results are
  displayed in a reactable table below the chat.
- **Read-only safety**: The `validate_query()` function rejects any non-SELECT
  statement before execution.
- **Sidebar with schema**: The sidebar displays the database schema and provides
  clickable suggested questions for quick exploration.

## Coding Style

- Tidyverse conventions throughout
- Use the base R pipe operator `|>`
- Use `snake_case` for all function and variable names
- Add clear comments explaining intent
- Handle errors gracefully with `tryCatch()`

## Environment Variables

| Variable            | Required | Default                  | Description                                |
|---------------------|----------|--------------------------|--------------------------------------------|
| `ANTHROPIC_API_KEY` | Yes      | --                       | Anthropic API key for Claude access        |
| `DB_PATH`           | No       | `../data/sample.sqlite`  | Path to SQLite database file               |
| `API_BASE_URL`      | No       | (empty = direct mode)    | URL of plumber2 API for API mode           |
| `CLAUDE_MODEL`      | No       | `claude-sonnet-4-20250514` | Claude model identifier                  |

## Running Locally

```bash
cd shiny
cp .Renviron.example .Renviron
# Edit .Renviron and set your ANTHROPIC_API_KEY
Rscript -e "shiny::runApp('.', port = 3838)"
```

## Deployment to Posit Connect

```r
rsconnect::deployApp(
  appDir = "shiny",
  appTitle = "AI SQL Chatbot (Shiny)"
)
```

Set `ANTHROPIC_API_KEY` and `DB_PATH` as encrypted environment variables in the
Connect dashboard.

## Key Packages

| Package    | Purpose                                      |
|------------|----------------------------------------------|
| shiny      | Core reactive web framework                  |
| bslib      | Bootstrap 5 theming and layout components    |
| shinychat  | Chat UI widget with streaming support        |
| ellmer     | LLM communication (Anthropic / Claude)       |
| DBI        | Database interface                           |
| RSQLite    | SQLite driver                                |
| reactable  | Interactive data tables                      |
| htmltools  | HTML generation utilities                    |
| httr2      | HTTP client (used in API mode)               |
