# AI SQL Chatbot

Ask your data questions in plain English. This R Shiny app converts natural
language to SQL using Claude (Anthropic), executes the queries, and
summarises the results -- all in a chat interface.

**Stack:** [Shiny](https://shiny.posit.co/) +
[bslib](https://rstudio.github.io/bslib/) (Bootstrap 5) +
[shinychat](https://posit-dev.github.io/shinychat/) +
[ellmer](https://ellmer.tidyverse.org/) (Claude API)

## Quick Start

### 1. Clone and restore packages

This project uses [renv](https://rstudio.github.io/renv/) so that every
contributor gets the exact same package versions. After cloning, open R in
the project directory and restore:

```r
# renv bootstraps itself automatically when R starts in this directory.
# Then install all packages at the exact locked versions:
renv::restore()
```

That's it -- no need to manually `install.packages()` anything. The
`renv.lock` file pins every dependency.

> **First time using renv?** See the [Package Management with renv](#package-management-with-renv)
> section below for more details.

### 2. Get an Anthropic API key

Sign up at [console.anthropic.com](https://console.anthropic.com) and create
an API key. Then create a `.Renviron` file in the project root:

```bash
cp .Renviron.example .Renviron
# Edit .Renviron and replace "your-api-key-here" with your actual key
```

### 3. Create the sample database

```bash
Rscript data/create_db.R
```

This creates a small e-commerce SQLite database with customers, products,
orders, and order items.

### 4. Run the app

```r
shiny::runApp()
```

That's it. Open the app in your browser and start asking questions like
"What are the top 10 products by revenue?" or "Show monthly sales trends."

## How It Works

```
You ask a question in plain English
        |
        v
Claude (via ellmer) generates a SQL query
        |
        v
The execute_sql tool runs the query against your database
        |
        v
Claude summarises the results in natural language
        |
        v
Results appear in the chat + an interactive table below
```

The app uses [ellmer's tool calling](https://ellmer.tidyverse.org/articles/tool-calling.html)
to register an `execute_sql` tool. Claude decides when to call it, what SQL
to write, and how to interpret the results. All queries are validated to be
read-only (SELECT/WITH only) before execution.

## Use Your Own Data

### Option A: Any SQLite or DuckDB file

Point the app at your own database file:

```bash
# In your .Renviron file:
DB_PATH=/path/to/your/database.sqlite
```

### Option B: Any R dataframe or tibble

You can query any dataframe in your R environment by writing it to an
ephemeral in-memory DuckDB. Install `duckdb` first:

```r
install.packages("duckdb")
```

Then modify `app.R` -- replace the `get_connection()` call in the server
function with `connect_tibble()`:

```r
# In the server function, replace:
#   db_con <- tryCatch(get_connection(), ...)
# With:
db_con <- connect_tibble(
  flights = nycflights13::flights,
  airlines = nycflights13::airlines,
  airports = nycflights13::airports
)
```

Each named argument becomes a SQL table. Now you can ask questions like
"Which airline had the most delays in December?"

## Connect to Remote Databases (ADBC)

[ADBC](https://arrow.apache.org/adbc/) (Arrow Database Connectivity) is a
modern alternative to ODBC that transfers data in Apache Arrow's columnar
format. This means no row-to-column conversion overhead, native support for
complex types, and efficient memory usage.

### Why ADBC over ODBC?

| | ODBC | ADBC |
|---|---|---|
| **Data format** | Row-oriented | Columnar (Arrow) |
| **Transfer overhead** | Row-to-column conversion | Zero-copy or minimal-copy |
| **Large results** | Must materialise in memory | Streaming via RecordBatch |
| **Cross-language** | Different APIs per language | Same Arrow format everywhere |

### Supported databases

| Database | Driver name | Install command |
|----------|-------------|-----------------|
| PostgreSQL | `postgresql` | `dbc install postgresql` |
| Amazon Redshift | `redshift` | `dbc install redshift` |
| Snowflake | `snowflake` | `dbc install snowflake` |
| Google BigQuery | `bigquery` | `dbc install bigquery` |
| Oracle | `oracle` | `dbc install oracle` |
| MySQL | `mysql` | `dbc install mysql` |
| SQL Server | `mssql` | `dbc install mssql` |
| DuckDB | `duckdb` | `dbc install duckdb` |

Drivers are installed with the [`dbc` CLI](https://columnar.tech/dbc) from
[Columnar](https://columnar.tech).

### Setup example: PostgreSQL

1. Install the ADBC driver and R packages:

```bash
dbc install postgresql
```

```r
install.packages(c("adbi", "adbcdrivermanager"))
```

2. Configure environment variables in `.Renviron`:

```bash
DB_TYPE=adbc
ADBC_DRIVER=postgresql
ADBC_URI=postgresql://user:password@host:5432/mydb
```

3. Run the app as usual: `shiny::runApp()`

### Setup example: Snowflake

```bash
dbc install snowflake
```

```r
install.packages(c("adbi", "adbcdrivermanager"))
```

For Snowflake you'll modify `app.R` to pass driver-specific options
(account, warehouse, role) via `connect_adbc()`:

```r
db_con <- connect_adbc(
  "snowflake",
  adbc.snowflake.sql.account = "your-account",
  adbc.snowflake.sql.warehouse = "COMPUTE_WH",
  adbc.snowflake.sql.role = "ANALYST",
  adbc.snowflake.sql.db = "MY_DATABASE",
  adbc.snowflake.sql.schema = "PUBLIC",
  username = "your_user",
  password = "your_pass"
)
```

### Setup example: Google BigQuery

```bash
dbc install bigquery
```

```r
install.packages(c("adbi", "adbcdrivermanager"))
```

```r
db_con <- connect_adbc(
  "bigquery",
  adbc.bigquery.sql.project_id = "my-gcp-project",
  adbc.bigquery.sql.dataset_id = "my_dataset"
)
```

### Federated queries across databases

A key advantage of ADBC is that all drivers return data in the same Arrow
columnar format. You can pull results from multiple databases and join them
locally with dplyr -- no serialisation overhead between systems:

```r
library(adbcdrivermanager)

# Connect to Redshift
con_redshift <- adbc_connection_init(adbc_database_init(
  adbc_driver("redshift"), uri = "postgresql://..."
))

# Connect to Snowflake
con_snowflake <- adbc_connection_init(adbc_database_init(
  adbc_driver("snowflake"), adbc.snowflake.sql.account = "..."
))

# Pull Arrow tables from each system
orders <- con_redshift |>
  read_adbc("SELECT * FROM orders WHERE year = 2025") |>
  tibble::as_tibble()

customers <- con_snowflake |>
  read_adbc("SELECT * FROM customers") |>
  tibble::as_tibble()

# Join locally -- efficient because both arrived as Arrow columnar data
combined <- dplyr::inner_join(orders, customers, by = "customer_id")
```

## Package Management with renv

This project uses [renv](https://rstudio.github.io/renv/) to create a
reproducible R package environment. Instead of installing packages globally,
renv gives this project its own private library so everyone works with
identical package versions.

### What renv does

| File | Purpose |
|------|---------|
| `renv.lock` | Records the exact version of every package (the "lockfile") |
| `.Rprofile` | Activates renv automatically when R starts in this directory |
| `renv/activate.R` | Bootstrap script -- installs renv itself if needed |
| `renv/settings.json` | Project settings (snapshot type, etc.) |
| `renv/library/` | Private package library (gitignored, rebuilt via `restore()`) |

### Common renv commands

```r
renv::restore()    # Install packages from renv.lock (run after cloning)
renv::status()     # Check if lockfile is in sync with your library
renv::install()    # Install a new package into the project library
renv::snapshot()   # Update renv.lock after installing/updating packages
```

### Adding a new package

```r
renv::install("duckdb")   # Install into the project library
# ... verify your code works ...
renv::snapshot()           # Save the new package to renv.lock
# Commit the updated renv.lock to git
```

### How it works for new contributors

When you clone this repo and open R in the project directory:

1. `.Rprofile` runs automatically and activates renv
2. If renv is not installed, `renv/activate.R` bootstraps it for you
3. renv detects the library is out of sync and prompts you to run
   `renv::restore()`
4. `renv::restore()` installs every package at the exact version recorded
   in `renv.lock`

No manual package installation is needed. The lockfile is the single source
of truth for package versions.

## Deploy to Posit Connect

```r
rsconnect::deployApp(appTitle = "AI SQL Chatbot")
```

Set `ANTHROPIC_API_KEY` (and optionally `DB_PATH`, `DB_TYPE`, `ADBC_DRIVER`,
`ADBC_URI`) as encrypted environment variables in the Connect dashboard.

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `ANTHROPIC_API_KEY` | Yes | -- | Claude API key from [console.anthropic.com](https://console.anthropic.com) |
| `DB_PATH` | No | `data/sample.sqlite` | Path to SQLite/DuckDB file |
| `CLAUDE_MODEL` | No | `claude-sonnet-4-20250514` | Claude model identifier |
| `DB_TYPE` | No | `sqlite` | `sqlite` or `adbc` |
| `ADBC_DRIVER` | No | -- | ADBC driver name (required when `DB_TYPE=adbc`) |
| `ADBC_URI` | No | -- | Connection URI for ADBC |

## Project Structure

```
app.R                 # Shiny application (UI + server)
R/
  database.R          # Connection layer (SQLite, DuckDB, ADBC)
  schema.R            # DBI-generic schema introspection
  tool_sql.R          # ellmer tool() for SQL execution
data/
  create_db.R         # Sample e-commerce database generator
renv.lock             # Locked package versions (renv)
renv/
  activate.R          # renv bootstrap script
  settings.json       # renv project settings
DESCRIPTION           # R package dependency declarations
.Rprofile             # Activates renv on R startup
.Renviron.example     # Environment variable template
```

## License

MIT -- See [LICENSE](LICENSE) for details.
