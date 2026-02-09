# ---------------------------------------------------------------------------
# plumber.R — Main API entry point with plumber2 route definitions
# ---------------------------------------------------------------------------

library(plumber2)
library(jsonlite)

# Source all helper modules from the R/ directory
source("R/utils.R")
source("R/database.R")
source("R/chat.R")

# ---------------------------------------------------------------------------
# Startup: initialise the database connection and schema
# ---------------------------------------------------------------------------

db_conn <- tryCatch(
  get_db_connection(),
  error = function(e) {
    message("WARNING: Could not connect to database on startup: ",
            conditionMessage(e))
    message("The /api/chat and /api/execute endpoints will not work until ",
            "a valid DB_PATH is configured.")
    NULL
  }
)

db_schema <- if (!is.null(db_conn)) {
  get_db_schema(db_conn)
} else {
  "(database not connected)"
}

# In-memory store for chat sessions (keyed by session_id)
chat_sessions <- new.env(parent = emptyenv())

# ---------------------------------------------------------------------------
# Helper: ensure the DB connection is alive
# ---------------------------------------------------------------------------

ensure_db <- function() {
  if (is.null(db_conn) || !dbIsValid(db_conn)) {
    db_conn <<- get_db_connection()
    db_schema <<- get_db_schema(db_conn)
  }
  invisible(db_conn)
}

# ---------------------------------------------------------------------------
# Build the plumber2 API
# ---------------------------------------------------------------------------

api() |>
  # ------------------------------------------------------------------
  # CORS preflight handler — respond to OPTIONS requests
  # ------------------------------------------------------------------
  api_options("*", function(req, res) {
    headers <- cors_headers()
    for (name in names(headers)) {
      res$set_header(name, headers[[name]])
    }
    res$status <- 204L
    ""
  }) |>

  # ------------------------------------------------------------------
  # Global after-hook: attach CORS headers to every response
  # ------------------------------------------------------------------
  api_after(function(req, res) {
    headers <- cors_headers()
    for (name in names(headers)) {
      res$set_header(name, headers[[name]])
    }
  }) |>

  # ------------------------------------------------------------------
  # GET /api/health — Health check
  # ------------------------------------------------------------------
  api_get("/api/health", function(req, res) {
    db_ok <- tryCatch(
      {
        if (!is.null(db_conn) && dbIsValid(db_conn)) {
          dbGetQuery(db_conn, "SELECT 1")
          TRUE
        } else {
          FALSE
        }
      },
      error = function(e) FALSE
    )

    api_key_set <- Sys.getenv("ANTHROPIC_API_KEY", "") != ""

    format_success(
      data = list(
        status    = "ok",
        database  = if (db_ok) "connected" else "disconnected",
        api_key   = if (api_key_set) "configured" else "missing"
      ),
      message = "API is running"
    )
  }) |>

  # ------------------------------------------------------------------
  # GET /api/schema — Return the database schema
  # ------------------------------------------------------------------
  api_get("/api/schema", function(req, res) {
    tryCatch(
      {
        ensure_db()
        current_schema <- get_db_schema(db_conn)
        format_success(
          data = list(schema = current_schema),
          message = "Schema retrieved successfully"
        )
      },
      error = function(e) {
        res$status <- 500L
        format_error(conditionMessage(e), 500L)
      }
    )
  }) |>

  # ------------------------------------------------------------------
  # POST /api/chat — Natural language to SQL via Claude
  #
  # Expects JSON body: { "message": "...", "session_id": "..." (optional) }
  # ------------------------------------------------------------------
  api_post("/api/chat", function(req, res) {
    tryCatch(
      {
        # Parse the request body
        body <- req$body

        # Validate required field
        if (is.null(body$message) || body$message == "") {
          res$status <- 400L
          return(format_error("'message' field is required", 400L))
        }

        user_message <- body$message
        session_id   <- if (!is.null(body$session_id)) body$session_id else paste0("session_", as.integer(Sys.time()))

        # Ensure DB is available
        ensure_db()
        db_schema <<- get_db_schema(db_conn)

        # Retrieve or create the chat session
        if (!exists(session_id, envir = chat_sessions)) {
          chat_sessions[[session_id]] <- create_chat_session(db_schema)
        }
        chat <- chat_sessions[[session_id]]

        # Send the user message and get structured response
        llm_result <- send_chat_message(chat, user_message)

        # Attempt to execute the generated SQL
        query_results <- NULL
        query_error   <- NULL

        tryCatch(
          {
            query_results <- execute_query(db_conn, llm_result$sql_query)
          },
          error = function(e) {
            query_error <<- conditionMessage(e)
          }
        )

        # Build the response payload
        response_data <- list(
          session_id              = session_id,
          sql_query               = llm_result$sql_query,
          explanation             = llm_result$explanation,
          suggested_visualization = llm_result$suggested_visualization,
          results                 = if (!is.null(query_results)) {
            df_to_rows(query_results)
          } else {
            NULL
          },
          row_count               = if (!is.null(query_results)) {
            nrow(query_results)
          } else {
            0L
          },
          columns                 = if (!is.null(query_results)) {
            names(query_results)
          } else {
            list()
          },
          query_error             = query_error
        )

        format_success(
          data = response_data,
          message = "Chat response generated"
        )
      },
      error = function(e) {
        res$status <- 500L
        format_error(paste("Chat error:", conditionMessage(e)), 500L)
      }
    )
  }) |>

  # ------------------------------------------------------------------
  # POST /api/execute — Execute a user-supplied SQL query
  #
  # Expects JSON body: { "sql": "SELECT ..." }
  # ------------------------------------------------------------------
  api_post("/api/execute", function(req, res) {
    tryCatch(
      {
        body <- req$body

        if (is.null(body$sql) || body$sql == "") {
          res$status <- 400L
          return(format_error("'sql' field is required", 400L))
        }

        sql <- body$sql

        # Validate (will stop() on violation)
        validate_query(sql)

        # Execute
        ensure_db()
        results <- execute_query(db_conn, sql)

        format_success(
          data = list(
            sql       = sql,
            results   = df_to_rows(results),
            row_count = nrow(results),
            columns   = names(results)
          ),
          message = "Query executed successfully"
        )
      },
      error = function(e) {
        status <- if (grepl("validation failed", conditionMessage(e),
                            ignore.case = TRUE)) 400L else 500L
        res$status <- status
        format_error(conditionMessage(e), status)
      }
    )
  })
