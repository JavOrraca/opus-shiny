# ---------------------------------------------------------------------------
# tool_sql.R -- ellmer tool() definition for SQL execution
#
# Registers an `execute_sql` tool with ellmer so Claude calls it directly
# instead of outputting SQL in markdown fences.
# ---------------------------------------------------------------------------

#' Create an ellmer tool for executing SQL queries.
#'
#' The tool validates that the query is read-only, executes it via DBI,
#' updates the reactive values for the results panel (side effect), and
#' returns JSON to Claude for summarisation.
#'
#' @param con A DBI connection object.
#' @param results_rv A `reactiveVal` to store the latest query results (data.frame).
#' @param sql_rv A `reactiveVal` to store the latest SQL query text.
#' @return An ellmer `tool()` object ready for `chat$register_tool()`.
create_sql_tool <- function(con, results_rv, sql_rv) {
  ellmer::tool(
    function(sql) {
      # Validate: only SELECT/WITH allowed
      validate_query(sql)

      # Execute the query
      result <- DBI::dbGetQuery(con, sql)
      total_rows <- nrow(result)

      # Update reactive values for the results panel
      sql_rv(sql)

      # Truncate large results to avoid overwhelming the LLM context
      if (total_rows > 100) {
        results_rv(head(result, 100))
        json <- jsonlite::toJSON(head(result, 100), auto_unbox = TRUE)
        paste0(
          json,
          "\n[Results truncated to 100 of ", total_rows, " total rows. ",
          "Suggest the user add LIMIT or more specific filters if they need to see more.]"
        )
      } else {
        results_rv(result)
        jsonlite::toJSON(result, auto_unbox = TRUE)
      }
    },
    name = "execute_sql",
    description = paste0(
      "Execute a read-only SQL SELECT query against the user's database and ",
      "return the results as JSON. Only SELECT queries (and WITH/CTE) are ",
      "allowed. INSERT, UPDATE, DELETE, DROP, and other data-modifying ",
      "statements will be rejected."
    ),
    arguments = list(
      sql = ellmer::type_string(
        "A valid SQL SELECT query to execute against the database."
      )
    )
  )
}
