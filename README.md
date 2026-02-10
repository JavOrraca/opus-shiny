# AI SQL Chatbot — Natural Language to SQL Data Analysis

A template application that lets users ask questions about their data in plain
English. Powered by Claude (Anthropic) via R's [ellmer](https://ellmer.tidyverse.org/)
package, with a modern React frontend and an R Shiny alternative interface.

## Architecture

| Component | Tech Stack | Directory |
|-----------|-----------|-----------|
| **API Backend** | R, plumber, ellmer | `api/` |
| **Frontend** | React 19, Next.js 15, TypeScript, Tailwind CSS | `frontend/` |
| **Shiny UI** | R, bslib, shinychat | `shiny/` |
| **Sample Data** | SQLite (e-commerce demo) | `data/` |

```
User → React Chat UI → plumber API → ellmer → Claude API
                              ↓
                        SQLite Database
                              ↓
                     Query Results + Explanation
```

## Quick Start

### 1. Set your API key

```bash
# Copy and edit the example .Renviron file
cp api/.Renviron.example api/.Renviron
# Add your Anthropic API key (from console.anthropic.com)
```

### 2. Create the sample database

```bash
Rscript data/create_db.R
```

### 3. Start the API

```bash
Rscript api/run.R
# API running at http://localhost:8080
```

### 4a. Start the React frontend

```bash
cd frontend
npm install
npm run dev
# Frontend at http://localhost:3000
```

> **Tip:** The React frontend works especially well inside the
> [Positron](https://positron.posit.co/) IDE Viewer pane — open
> `http://localhost:3000` there for an integrated development experience.

### 4b. Or start the Shiny interface

```bash
Rscript -e "shiny::runApp('shiny', port = 3838)"
```

## Deployment to Posit Connect

Each component deploys as a separate content item:

- **API**: `rsconnect::deployAPI("api/")`
- **React frontend**: Build with `npm run build`, deploy the `out/` folder as a static site
- **Shiny app**: `rsconnect::deployApp("shiny/")`

Set `ANTHROPIC_API_KEY` as an encrypted environment variable in Connect.

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `ANTHROPIC_API_KEY` | Yes | — | Your Claude API key |
| `DB_PATH` | No | `data/sample.sqlite` | Path to database file |
| `API_PORT` | No | `8080` | API server port |
| `NEXT_PUBLIC_API_BASE_URL` | No | `http://localhost:8080` | API URL for frontend |

## Requirements

- **R** >= 4.3 with packages: ellmer, plumber, DBI, RSQLite, bslib, shinychat
- **Node.js** >= 20 (for React frontend)
- **Anthropic API key** from [console.anthropic.com](https://console.anthropic.com)

## License

MIT — See [LICENSE](LICENSE) for details.
