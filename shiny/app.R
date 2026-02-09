# ---------------------------------------------------------------------------
# app.R -- AI SQL Chatbot (Shiny / bslib)
#
# A lightweight alternative to the React frontend. Provides a chat interface
# for natural language to SQL queries using shinychat + ellmer.
#
# Two operating modes:
#   (a) Direct mode: uses ellmer to call the Claude API directly
#   (b) API mode:    calls the plumber2 API backend via httr2
#
# Set API_BASE_URL to enable API mode; leave it unset for direct mode.
# ---------------------------------------------------------------------------

library(shiny)
library(bslib)
library(shinychat)
library(ellmer)
library(DBI)
library(RSQLite)
library(reactable)
library(htmltools)
library(httr2)
library(rlang)

# --- Configuration ---
# PLACEHOLDER: Set your Anthropic API key in one of these ways:
#   Option 1: Create a .Renviron file with ANTHROPIC_API_KEY=sk-ant-...
#   Option 2: Set the environment variable in your shell before running
#   Option 3: Set it in Posit Connect environment variables (for deployment)
api_key   <- Sys.getenv("ANTHROPIC_API_KEY")
db_path   <- Sys.getenv("DB_PATH", "../data/sample.sqlite")
api_url   <- Sys.getenv("API_BASE_URL", "")
llm_model <- Sys.getenv("CLAUDE_MODEL", "claude-sonnet-4-20250514")

# Determine operating mode
use_api_mode <- nzchar(api_url)


# ==========================================================================
# Database helpers (used in direct mode and for local query execution)
# ==========================================================================

#' Open a read-only connection to the SQLite database.
#'
#' @param path Path to the SQLite database file.
#' @return A DBI connection object.
get_db_connection <- function(path = db_path) {
  if (!file.exists(path)) {
    stop(
      "Database file not found at: ", path,
      ". Set the DB_PATH environment variable to a valid SQLite file."
    )
  }
  dbConnect(RSQLite::SQLite(), dbname = path)
}


#' Extract the database schema as a human-readable string.
#'
#' @param path Path to the SQLite database file.
#' @return A character string describing all tables, columns, and types.
get_db_schema <- function(path = db_path) {
  conn <- get_db_connection(path)
  on.exit(dbDisconnect(conn))

  tables <- dbListTables(conn)

  if (length(tables) == 0) {
    return("(no tables found in database)")
  }

  tables |>
    lapply(function(tbl) {
      info <- dbGetQuery(conn, paste0("PRAGMA table_info('", tbl, "')"))
      col_lines <- info |>
        apply(1, function(row) {
          pk     <- if (as.integer(row[["pk"]]) > 0) " [PK]" else ""
          notnul <- if (as.integer(row[["notnull"]]) == 1) " NOT NULL" else ""
          paste0("    ", row[["name"]], " ", row[["type"]], notnul, pk)
        })
      paste0("TABLE ", tbl, "\n", paste(col_lines, collapse = "\n"))
    }) |>
    paste(collapse = "\n\n")
}


#' Validate that a SQL string is read-only (SELECT only).
#'
#' @param sql A SQL query string.
#' @return TRUE if valid; otherwise stops with an error.
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


#' Execute a validated read-only SQL query.
#'
#' @param sql A SQL SELECT query string.
#' @param path Path to the SQLite database file.
#' @return A data.frame of query results.
execute_query <- function(sql, path = db_path) {
  validate_query(sql)

  conn <- get_db_connection(path)
  on.exit(dbDisconnect(conn))

  tryCatch(
    dbGetQuery(conn, sql),
    error = function(e) {
      stop("SQL execution error: ", conditionMessage(e))
    }
  )
}


# ==========================================================================
# System prompt builder
# ==========================================================================

#' Build the system prompt with the database schema embedded.
#'
#' @param path Path to the SQLite database file.
#' @return A character string containing the full system prompt.
build_system_prompt <- function(path = db_path) {
  schema <- get_db_schema(path)

  paste0(
    "You are a data analysis assistant. You help users explore a SQL database ",
    "by converting their natural language questions into SQL queries.\n\n",
    "IMPORTANT RULES:\n",
    "1. Only generate SELECT queries. Never generate INSERT, UPDATE, DELETE, DROP, ",
    "or any data-modifying statements.\n",
    "2. Always explain what the query does in plain language.\n",
    "3. If the user's question is ambiguous, ask for clarification.\n",
    "4. Format your response as:\n",
    "   - First, a brief explanation of your approach\n",
    "   - Then the SQL query wrapped in ```sql code fences\n",
    "   - Then a summary of what the results will show\n",
    "5. Write clear, well-formatted SQL that references only valid tables and columns.\n",
    "6. If the question cannot be answered with the available schema, say so clearly.\n\n",
    "DATABASE SCHEMA:\n```\n", schema, "\n```"
  )
}


# ==========================================================================
# API-mode helpers (calls plumber2 backend via httr2)
# ==========================================================================

#' Send a chat message via the plumber2 API.
#'
#' @param message The user's natural language question.
#' @param session_id A unique session identifier for multi-turn context.
#' @return A list with `response` (LLM text), `sql_query`, `results`, etc.
api_chat <- function(message, session_id = "shiny-default") {
  resp <- request(api_url) |>
    req_url_path_append("api", "chat") |>
    req_body_json(list(message = message, session_id = session_id)) |>
    req_headers("Content-Type" = "application/json") |>
    req_timeout(120) |>
    req_perform()

  resp |> resp_body_json()
}


#' Fetch the database schema from the plumber2 API.
#'
#' @return A list with schema information.
api_get_schema <- function() {
  resp <- request(api_url) |>
    req_url_path_append("api", "schema") |>
    req_timeout(30) |>
    req_perform()

  resp |> resp_body_json()
}


# ==========================================================================
# Extract SQL from LLM markdown response
# ==========================================================================

#' Extract SQL query from a markdown response containing ```sql fences.
#'
#' @param text The full LLM response text.
#' @return The extracted SQL string, or NULL if none found.
extract_sql_from_response <- function(text) {
  # Match ```sql ... ``` blocks
 match <- regmatches(
    text,
    regexpr("```sql\\s*\\n([\\s\\S]*?)\\n\\s*```", text, perl = TRUE)
  )

  if (length(match) == 0 || nchar(match) == 0) {
    return(NULL)
  }

  # Strip the fence markers
  sql <- match |>
    gsub(pattern = "```sql\\s*\\n", replacement = "", perl = TRUE) |>
    gsub(pattern = "\\n\\s*```", replacement = "", perl = TRUE) |>
    trimws()

  if (nchar(sql) == 0) NULL else sql
}


# ==========================================================================
# UI
# ==========================================================================

ui <- page_sidebar(
  title = "AI SQL Chatbot",
  theme = bs_theme(
    version = 5,
    preset = "shiny",
    bg = "#0a0a12",
    fg = "#e2e8f0",
    primary = "#6366f1",
    secondary = "#1e1e2e",
    success = "#22c55e",
    info = "#38bdf8",
    warning = "#f59e0b",
    danger = "#ef4444",
    "font-size-base" = "0.95rem",
    "enable-rounded" = TRUE,
    "card-bg" = "#111122",
    "card-border-color" = "#2d2d3f",
    "input-bg" = "#1a1a2e",
    "input-color" = "#e2e8f0",
    "input-border-color" = "#3d3d5c"
  ),
  sidebar = sidebar(
    title = "Database Info",
    width = 320,
    open = "open",
    bg = "#0d0d1a",

    # Mode indicator
    card(
      card_header(
        class = "py-2",
        tags$span(
          class = "badge rounded-pill",
          style = paste0(
            "background-color: ",
            if (use_api_mode) "#22c55e" else "#6366f1", ";"
          ),
          if (use_api_mode) "API Mode" else "Direct Mode"
        )
      ),
      card_body(
        class = "py-2 small text-muted",
        if (use_api_mode) {
          paste0("Connected to: ", api_url)
        } else {
          paste0("Model: ", llm_model)
        }
      )
    ),

    # Schema display
    card(
      card_header("Schema"),
      card_body(
        style = "max-height: 300px; overflow-y: auto;",
        verbatimTextOutput("schema_display", placeholder = TRUE)
      )
    ),

    # Suggested questions
    card(
      card_header("Try asking..."),
      card_body(
        tags$ul(
          class = "list-unstyled mb-0",
          tags$li(
            class = "mb-2",
            actionLink(
              "q1", "What are the top 10 products by revenue?",
              class = "text-decoration-none",
              style = "color: #a5b4fc;"
            )
          ),
          tags$li(
            class = "mb-2",
            actionLink(
              "q2", "Show monthly sales trends",
              class = "text-decoration-none",
              style = "color: #a5b4fc;"
            )
          ),
          tags$li(
            class = "mb-2",
            actionLink(
              "q3", "Which customers have the most orders?",
              class = "text-decoration-none",
              style = "color: #a5b4fc;"
            )
          ),
          tags$li(
            actionLink(
              "q4", "What is the average order value?",
              class = "text-decoration-none",
              style = "color: #a5b4fc;"
            )
          )
        )
      )
    ),

    # About
    card(
      card_body(
        class = "small text-muted",
        tags$p(
          "This Shiny app is a lightweight alternative to the React frontend. ",
          "It calls the same plumber2 API or uses ellmer directly."
        ),
        tags$p(
          class = "mb-0",
          "Built with ",
          tags$a(href = "https://rstudio.github.io/bslib/", "bslib", target = "_blank"),
          " + ",
          tags$a(href = "https://github.com/posit-dev/shinychat", "shinychat", target = "_blank"),
          "."
        )
      )
    )
  ),

  # Main content area
  layout_columns(
    col_widths = 12,

    # Chat panel
    card(
      card_header(
        class = "d-flex justify-content-between align-items-center",
        tags$span("Chat"),
        div(
          actionButton(
            "clear_chat", "Clear Chat",
            class = "btn-sm btn-outline-secondary",
            icon = icon("trash-can")
          )
        )
      ),
      card_body(
        class = "p-0",
        style = "height: 500px;",
        chat_ui("chat", fill = TRUE)
      )
    ),

    # Query results panel
    card(
      card_header(
        class = "d-flex justify-content-between align-items-center",
        tags$span("Query Results"),
        uiOutput("results_badge", inline = TRUE)
      ),
      card_body(
        uiOutput("executed_sql_display"),
        uiOutput("query_results_ui")
      )
    )
  )
)


# ==========================================================================
# Server
# ==========================================================================

server <- function(input, output, session) {

  # -- Reactive values -------------------------------------------------------
  latest_results <- reactiveVal(NULL)
  latest_sql     <- reactiveVal(NULL)

  # -- Initialize ellmer chat session (direct mode) --------------------------
  chat_session <- NULL

  if (!use_api_mode) {
    if (!nzchar(api_key)) {
      # Show a warning but don't crash -- let the user see the UI
      showNotification(
        "ANTHROPIC_API_KEY is not set. Please set it in .Renviron or as an environment variable.",
        type = "error",
        duration = NULL
      )
    } else {
      chat_session <- chat_anthropic(
        system_prompt = build_system_prompt(db_path),
        model = llm_model
      )
    }
  }

  # -- Schema display --------------------------------------------------------
  output$schema_display <- renderText({
    tryCatch(
      get_db_schema(db_path),
      error = function(e) {
        paste("Could not load schema:", conditionMessage(e))
      }
    )
  })

  # -- Results badge (row count) ---------------------------------------------
  output$results_badge <- renderUI({
    results <- latest_results()
    if (is.null(results)) return(NULL)
    tags$span(
      class = "badge bg-primary",
      paste(nrow(results), "rows")
    )
  })

  # -- Display the executed SQL ----------------------------------------------
  output$executed_sql_display <- renderUI({
    sql <- latest_sql()
    if (is.null(sql)) return(NULL)

    tags$details(
      class = "mb-3",
      tags$summary(
        class = "text-muted small",
        style = "cursor: pointer;",
        "Show executed SQL"
      ),
      tags$pre(
        class = "p-2 rounded mt-1",
        style = "background-color: #1a1a2e; color: #a5b4fc; font-size: 0.85rem; overflow-x: auto;",
        tags$code(sql)
      )
    )
  })

  # -- Helper: process a user question ---------------------------------------
  process_question <- function(question) {
    if (use_api_mode) {
      # --- API mode: call plumber2 backend ---
      tryCatch({
        api_result <- api_chat(question)

        if (isTRUE(api_result$success)) {
          # Build a response message from the API result
          response_text <- api_result$data$explanation %||% ""

          if (!is.null(api_result$data$sql_query)) {
            sql <- api_result$data$sql_query
            response_text <- paste0(
              response_text, "\n\n```sql\n", sql, "\n```"
            )
            latest_sql(sql)

            # Execute the query locally if we have a database
            tryCatch({
              results <- execute_query(sql, db_path)
              latest_results(results)

              response_text <- paste0(
                response_text,
                "\n\nQuery executed successfully. ",
                nrow(results), " rows returned."
              )
            }, error = function(e) {
              latest_results(NULL)
              response_text <<- paste0(
                response_text,
                "\n\n**Error executing query:** ", conditionMessage(e)
              )
            })
          }

          chat_append("chat", response_text)
        } else {
          chat_append("chat", paste("API error:", api_result$error %||% "Unknown error"))
        }
      }, error = function(e) {
        chat_append("chat", paste("Failed to reach API:", conditionMessage(e)))
      })

    } else {
      # --- Direct mode: use ellmer ---
      if (is.null(chat_session)) {
        chat_append(
          "chat",
          "Cannot process your question: ANTHROPIC_API_KEY is not configured. Please set it and restart the app."
        )
        return(invisible(NULL))
      }

      tryCatch({
        # Stream the response from Claude via ellmer
        stream <- chat_session$stream(question)
        chat_append("chat", stream)

        # After streaming completes, extract SQL from the response
        last_response <- chat_session$last_turn()@text

        sql <- extract_sql_from_response(last_response)

        if (!is.null(sql)) {
          latest_sql(sql)

          tryCatch({
            results <- execute_query(sql, db_path)
            latest_results(results)
          }, error = function(e) {
            latest_results(NULL)
            latest_sql(NULL)
            chat_append("chat", paste(
              "\n\n**Error executing query:** ", conditionMessage(e)
            ))
          })
        } else {
          # No SQL found in response -- that is fine (clarification, etc.)
          latest_results(NULL)
          latest_sql(NULL)
        }
      }, error = function(e) {
        chat_append("chat", paste("Error communicating with Claude:", conditionMessage(e)))
      })
    }
  }

  # -- Chat input observer (shinychat triggers this) -------------------------
  observeEvent(input$chat_user_input, {
    user_msg <- input$chat_user_input
    process_question(user_msg)
  })

  # -- Suggested question buttons --------------------------------------------
  observeEvent(input$q1, {
    chat_append("chat", "What are the top 10 products by revenue?", role = "user")
    process_question("What are the top 10 products by revenue?")
  })

  observeEvent(input$q2, {
    chat_append("chat", "Show monthly sales trends", role = "user")
    process_question("Show monthly sales trends")
  })

  observeEvent(input$q3, {
    chat_append("chat", "Which customers have the most orders?", role = "user")
    process_question("Which customers have the most orders?")
  })

  observeEvent(input$q4, {
    chat_append("chat", "What is the average order value?", role = "user")
    process_question("What is the average order value?")
  })

  # -- Clear chat button -----------------------------------------------------
  observeEvent(input$clear_chat, {
    # Reset results
    latest_results(NULL)
    latest_sql(NULL)

    # Re-initialize the ellmer chat session to clear conversation history
    if (!use_api_mode && nzchar(api_key)) {
      chat_session <<- chat_anthropic(
        system_prompt = build_system_prompt(db_path),
        model = llm_model,
        api_key = api_key
      )
    }

    # Notify the user (shinychat does not expose a clear method, so we inform)
    showNotification("Chat cleared. Refresh the page for a clean slate.", type = "message")
  })

  # -- Query results display -------------------------------------------------
  output$query_results_ui <- renderUI({
    results <- latest_results()

    if (is.null(results)) {
      div(
        class = "text-muted text-center py-4",
        tags$p(icon("table"), " Query results will appear here after you ask a question."),
        tags$p(class = "small", "Try one of the suggested questions in the sidebar.")
      )
    } else if (nrow(results) == 0) {
      div(
        class = "text-muted text-center py-4",
        tags$p("The query returned no rows.")
      )
    } else {
      tagList(
        div(
          class = "mb-2 text-muted small",
          paste0(
            nrow(results), " rows x ",
            ncol(results), " columns"
          )
        ),
        reactable(
          results,
          theme = reactableTheme(
            color = "#e2e8f0",
            backgroundColor = "#0f0f1e",
            borderColor = "#2d2d3f",
            stripedColor = "#161628",
            highlightColor = "#1e1e38",
            headerStyle = list(
              backgroundColor = "#1a1a2e",
              color = "#a5b4fc",
              fontWeight = 600,
              borderBottomColor = "#3d3d5c"
            ),
            searchInputStyle = list(
              backgroundColor = "#1a1a2e",
              color = "#e2e8f0",
              borderColor = "#3d3d5c"
            ),
            paginationStyle = list(
              color = "#a5b4fc"
            ),
            inputStyle = list(
              backgroundColor = "#1a1a2e",
              color = "#e2e8f0"
            )
          ),
          defaultPageSize = 10,
          pageSizeOptions = c(10, 25, 50),
          filterable = TRUE,
          searchable = TRUE,
          striped = TRUE,
          highlight = TRUE,
          bordered = TRUE,
          compact = TRUE
        )
      )
    }
  })
}


# ==========================================================================
# Launch
# ==========================================================================

shinyApp(ui = ui, server = server)
