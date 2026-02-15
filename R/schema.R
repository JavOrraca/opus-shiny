# ---------------------------------------------------------------------------
# schema.R -- DBI-generic schema introspection
#
# Works across SQLite, DuckDB, PostgreSQL, Snowflake, BigQuery, and any
# other DBI-compliant backend. No SQLite-specific PRAGMA calls.
# ---------------------------------------------------------------------------

#' Extract the database schema as a human-readable string.
#'
#' Uses DBI-generic methods (`dbListTables`, `dbListFields`) so it works
#' with any database backend, not just SQLite.
#'
#' @param con A DBI connection object.
#' @return A character string describing all tables, columns, and types.
get_db_schema <- function(con) {
  tables <- DBI::dbListTables(con)

  if (length(tables) == 0) {
    return("(no tables found in database)")
  }

  tables |>
    lapply(function(tbl) {
      col_info <- tryCatch(
        {
          # Try to get column types via a zero-row query
          rs <- DBI::dbSendQuery(con, paste0(
            "SELECT * FROM \"", tbl, "\" WHERE 1 = 0"
          ))
          info <- DBI::dbColumnInfo(rs)
          DBI::dbClearResult(rs)
          paste0("    ", info$name, " ", toupper(info$type))
        },
        error = function(e) {
          # Fallback: just list column names without types
          fields <- DBI::dbListFields(con, tbl)
          paste0("    ", fields)
        }
      )
      paste0("TABLE ", tbl, "\n", paste(col_info, collapse = "\n"))
    }) |>
    paste(collapse = "\n\n")
}
