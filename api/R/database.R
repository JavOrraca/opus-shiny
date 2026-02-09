# ---------------------------------------------------------------------------
# database.R — Database connection, schema extraction, and query execution
# ---------------------------------------------------------------------------

library(DBI)
library(RSQLite)

#' Open a connection to a SQLite database.
#'
#' @param db_path Path to the SQLite database file. Defaults to the DB_PATH
#'   environment variable, falling back to "../data/sample.sqlite".
#' @return A DBI connection object.
get_db_connection <- function(db_path = Sys.getenv("DB_PATH",
                                                    "../data/sample.sqlite")) {
  if (!file.exists(db_path)) {
    stop("Database file not found at: ", db_path,
         ". Please set the DB_PATH environment variable to a valid SQLite file.")
  }

  conn <- dbConnect(RSQLite::SQLite(), dbname = db_path)
  conn
}


#' Extract the database schema as a human-readable string.
#'
#' Iterates over every table in the database and lists each column with its
#' declared type. The output is formatted so it can be embedded directly into
#' the LLM system prompt.
#'
#' @param conn A DBI connection object.
#' @return A character string describing all tables, columns, and types.
get_db_schema <- function(conn) {
  tables <- dbListTables(conn)

  if (length(tables) == 0) {
    return("(no tables found in database)")
  }

  schema_parts <- tables |>
    lapply(function(table_name) {
      # Fetch column metadata via PRAGMA
      columns <- dbGetQuery(conn, paste0("PRAGMA table_info('", table_name, "')"))

      column_lines <- columns |>
        apply(1, function(row) {
          pk_marker <- if (as.integer(row[["pk"]]) > 0) " [PRIMARY KEY]" else ""
          not_null  <- if (as.integer(row[["notnull"]]) == 1) " NOT NULL" else ""
          paste0("    ", row[["name"]], " ", row[["type"]], not_null, pk_marker)
        })

      paste0("TABLE ", table_name, "\n", paste(column_lines, collapse = "\n"))
    })

  paste(schema_parts, collapse = "\n\n")
}


#' Validate that a SQL string is read-only.
#'
#' Rejects any statement that is not a plain SELECT. This is a safety measure
#' to prevent accidental (or malicious) data modification.
#'
#' @param sql A SQL query string.
#' @return TRUE invisibly if the query is valid; otherwise stops with an error.
validate_query <- function(sql) {
  # Normalise whitespace and convert to upper case for pattern matching
  sql_upper <- sql |>
    trimws() |>
    toupper()

  # List of forbidden keywords that indicate mutation

  forbidden <- c(
    "\\bINSERT\\b",
    "\\bUPDATE\\b",
    "\\bDELETE\\b",
    "\\bDROP\\b",
    "\\bALTER\\b",
    "\\bCREATE\\b",
    "\\bTRUNCATE\\b",
    "\\bREPLACE\\b",
    "\\bGRANT\\b",
    "\\bREVOKE\\b",
    "\\bATTACH\\b",
    "\\bDETACH\\b",
    "\\bPRAGMA\\b"
  )

  for (pattern in forbidden) {
    if (grepl(pattern, sql_upper)) {
      keyword <- gsub("\\\\b", "", pattern)
      stop("Query validation failed: ", keyword,
           " statements are not allowed. Only SELECT queries are permitted.")
    }
  }

  # Must start with SELECT (after optional whitespace / WITH for CTEs)
  if (!grepl("^(WITH\\b|SELECT\\b)", sql_upper)) {
    stop("Query validation failed: query must begin with SELECT (or WITH for CTEs).")
  }

  invisible(TRUE)
}


#' Safely execute a read-only SQL query and return results as a data frame.
#'
#' The query is validated before execution. On error, a descriptive message is
#' raised so the caller can return it to the client.
#'
#' @param conn A DBI connection object.
#' @param sql A SQL SELECT query string.
#' @return A data.frame containing the query results.
execute_query <- function(conn, sql) {
  # Validate the query is read-only before executing
validate_query(sql)

  result <- tryCatch(
    {
      dbGetQuery(conn, sql)
    },
    error = function(e) {
      stop("SQL execution error: ", conditionMessage(e))
    }
  )

  result
}
