# ---------------------------------------------------------------------------
# utils.R — Utility functions for error formatting, responses, and CORS
# ---------------------------------------------------------------------------

library(jsonlite)

#' Create a standardised error response list.
#'
#' @param message Human-readable error description.
#' @param status_code HTTP status code (integer).
#' @return A named list with `success`, `error`, and `status_code` fields.
format_error <- function(message, status_code = 400L) {
  list(
    success = FALSE,
    error = message,
    status_code = as.integer(status_code)
  )
}


#' Create a standardised success response list.
#'
#' @param data The payload to include in the response (list, data.frame, etc.).
#' @param message Optional human-readable message.
#' @return A named list with `success`, `message`, and `data` fields.
format_success <- function(data = NULL, message = "OK") {
  list(
    success = TRUE,
    message = message,
    data = data
  )
}


#' Return a named list of CORS headers.
#'
#' During development all origins are allowed ("*"). For production, restrict
#' to your actual frontend domain by setting the CORS_ORIGIN env var.
#'
#' @return A named list of HTTP header name-value pairs.
cors_headers <- function() {
  allowed_origin <- Sys.getenv("CORS_ORIGIN", "*")

  list(
    "Access-Control-Allow-Origin"  = allowed_origin,
    "Access-Control-Allow-Methods" = "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers" = "Content-Type, Authorization",
    "Access-Control-Max-Age"       = "86400"
  )
}


#' Convert a data.frame to a list-of-lists structure for JSON serialisation.
#'
#' Each row becomes a named list, which serialises to a JSON array of objects.
#' This avoids the column-oriented format that jsonlite uses by default for
#' data frames.
#'
#' @param df A data.frame.
#' @return A list of named lists (one per row).
df_to_rows <- function(df) {
  if (is.null(df) || nrow(df) == 0) {
    return(list())
  }

  # Split the data frame into a list of single-row named lists
  lapply(seq_len(nrow(df)), function(i) as.list(df[i, , drop = FALSE]))
}
