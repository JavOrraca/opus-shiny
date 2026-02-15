# ---------------------------------------------------------------------------
# database.R -- Database connection layer
#
# Three connection strategies, all returning a standard DBI connection:
#   1. connect_sqlite(path) -- Default, zero-config
#   2. connect_tibble(...)  -- Named dataframes -> ephemeral DuckDB
#   3. connect_adbc(driver, uri, ...) -- Remote databases via ADBC
# ---------------------------------------------------------------------------

#' Open a read-only connection to a SQLite database file.
#'
#' @param path Path to the SQLite database file.
#' @return A DBI connection object.
connect_sqlite <- function(path) {
  if (!file.exists(path)) {
    stop(
      "Database file not found at: ", path,
      "\nRun `Rscript data/create_db.R` to create the sample database, ",
      "or set the DB_PATH environment variable to your own SQLite file."
    )
  }
  DBI::dbConnect(RSQLite::SQLite(), dbname = path)
}


#' Write named dataframes into an ephemeral in-memory DuckDB and return the
#' connection. Each dataframe becomes a table whose name matches the argument.
#'
#' @param ... Named dataframes. Example: `connect_tibble(sales = df1, users = df2)`
#' @return A DBI connection object to the in-memory DuckDB.
connect_tibble <- function(...) {
  if (!requireNamespace("duckdb", quietly = TRUE)) {
    stop(
      "The 'duckdb' package is required to query dataframes via SQL.\n",
      "Install it with: install.packages('duckdb')"
    )
  }

  dfs <- list(...)
  if (length(dfs) == 0 || is.null(names(dfs)) || any(names(dfs) == "")) {
    stop("connect_tibble() requires named arguments: connect_tibble(table_name = your_dataframe)")
  }

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  for (name in names(dfs)) {
    DBI::dbWriteTable(con, name, dfs[[name]])
  }
  con
}


#' Open a DBI-compliant connection to a remote database via ADBC.
#'
#' Requires the `adbi` and `adbcdrivermanager` packages, plus the appropriate
#' ADBC driver installed via `dbc install <driver>`.
#'
#' @param driver ADBC driver name (e.g., "postgresql", "snowflake", "bigquery").
#' @param uri Connection URI (e.g., "postgresql://user:pass@host:5432/db").
#' @param ... Additional connection parameters passed to `DBI::dbConnect()`.
#' @return A DBI connection object.
connect_adbc <- function(driver, uri = NULL, ...) {
  if (!requireNamespace("adbi", quietly = TRUE) ||
      !requireNamespace("adbcdrivermanager", quietly = TRUE)) {
    stop(
      "ADBC connections require the 'adbi' and 'adbcdrivermanager' packages.\n",
      "Install them with: install.packages(c('adbi', 'adbcdrivermanager'))\n",
      "Also install the ADBC driver: dbc install ", driver
    )
  }

  args <- list(drv = adbi::adbi(driver), ...)
  if (!is.null(uri)) args$uri <- uri
  do.call(DBI::dbConnect, args)
}


#' Dispatcher: open a database connection based on environment variables.
#'
#' @param db_type "sqlite" (default) or "adbc". Set via DB_TYPE env var.
#' @param db_path Path to SQLite file. Set via DB_PATH env var.
#' @param adbc_driver ADBC driver name. Set via ADBC_DRIVER env var.
#' @param adbc_uri ADBC connection URI. Set via ADBC_URI env var.
#' @return A DBI connection object.
get_connection <- function(
  db_type = Sys.getenv("DB_TYPE", "sqlite"),
  db_path = Sys.getenv("DB_PATH", "data/sample.sqlite"),
  adbc_driver = Sys.getenv("ADBC_DRIVER", ""),
  adbc_uri = Sys.getenv("ADBC_URI", "")
) {
  switch(db_type,
    "sqlite" = connect_sqlite(db_path),
    "adbc" = {
      if (!nzchar(adbc_driver)) {
        stop("DB_TYPE is 'adbc' but ADBC_DRIVER is not set. ",
             "Set it to a driver name like 'postgresql', 'snowflake', etc.")
      }
      connect_adbc(adbc_driver, if (nzchar(adbc_uri)) adbc_uri else NULL)
    },
    stop("Unknown DB_TYPE: '", db_type, "'. Use 'sqlite' or 'adbc'.")
  )
}


#' Validate that a SQL string is read-only (SELECT or WITH/CTE only).
#'
#' @param sql A SQL query string.
#' @return TRUE invisibly if valid; otherwise stops with an error.
validate_query <- function(sql) {
  sql_upper <- sql |> trimws() |> toupper()

  forbidden <- c(
    "\\bINSERT\\b", "\\bUPDATE\\b", "\\bDELETE\\b", "\\bDROP\\b",
    "\\bALTER\\b", "\\bCREATE\\b", "\\bTRUNCATE\\b", "\\bREPLACE\\b",
    "\\bGRANT\\b", "\\bREVOKE\\b", "\\bATTACH\\b", "\\bDETACH\\b",
    "\\bPRAGMA\\b", "\\bEXEC\\b"
  )

  for (pattern in forbidden) {
    if (grepl(pattern, sql_upper)) {
      keyword <- gsub("\\\\b", "", pattern)
      stop("Query rejected: ", keyword, " statements are not allowed. Only SELECT queries are permitted.")
    }
  }

  if (!grepl("^(WITH\\b|SELECT\\b)", sql_upper)) {
    stop("Query rejected: query must begin with SELECT (or WITH for CTEs).")
  }

  invisible(TRUE)
}
