# ---------------------------------------------------------------------------
# app.R -- AI SQL Chatbot (Shiny / bslib)
#
# A natural language to SQL data analysis app powered by Claude (Anthropic)
# via the ellmer package. Ask questions about your data in plain English
# and get SQL queries, results, and summaries.
#
# Supports: SQLite (default), DuckDB (for tibbles), ADBC (remote databases)
# ---------------------------------------------------------------------------

library(shiny)
library(bslib)
library(shinychat)
library(ellmer)
library(DBI)
library(RSQLite)
library(reactable)
library(htmltools)
library(jsonlite)

source("R/database.R")
source("R/schema.R")
source("R/tool_sql.R")

# --- Configuration ---
llm_model <- Sys.getenv("CLAUDE_MODEL", "claude-sonnet-4-20250514")


# ==========================================================================
# System prompt builder
# ==========================================================================

build_system_prompt <- function(schema_text) {
  paste0(
    "You are a data analysis assistant. You help users explore a SQL database ",
    "by converting their natural language questions into SQL queries.\n\n",
    "You have access to an `execute_sql` tool that runs read-only SQL queries ",
    "against the database. Use this tool to answer data questions.\n\n",
    "RULES:\n",
    "1. Only generate SELECT queries (or WITH/CTE). Never attempt INSERT, ",
    "UPDATE, DELETE, DROP, or any data-modifying statement.\n",
    "2. Always use the execute_sql tool to run your query.\n",
    "3. After receiving results, provide a clear natural language summary.\n",
    "4. If the question is ambiguous, ask for clarification before querying.\n",
    "5. If the question cannot be answered with the available schema, say so.\n",
    "6. For large result sets, suggest the user refine their query with LIMIT ",
    "or filters.\n\n",
    "DATABASE SCHEMA:\n```\n", schema_text, "\n```"
  )
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

    # Model info
    card(
      card_header(class = "py-2", "Model"),
      card_body(
        class = "py-2 small text-muted",
        textOutput("model_display", inline = TRUE)
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
          "Ask questions about your data in plain English. ",
          "Claude generates and executes SQL queries, then summarises the results."
        ),
        tags$p(
          class = "mb-0",
          "Built with ",
          tags$a(href = "https://rstudio.github.io/bslib/", "bslib", target = "_blank"),
          " + ",
          tags$a(href = "https://posit-dev.github.io/shinychat/", "shinychat", target = "_blank"),
          " + ",
          tags$a(href = "https://ellmer.tidyverse.org/", "ellmer", target = "_blank"),
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
        actionButton(
          "clear_chat", "Clear",
          class = "btn-sm btn-outline-secondary"
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

  # -- Database connection ---------------------------------------------------
  db_con <- tryCatch(
    get_connection(),
    error = function(e) {
      showNotification(
        paste("Database error:", conditionMessage(e)),
        type = "error",
        duration = NULL
      )
      NULL
    }
  )

  onSessionEnded(function() {
    if (!is.null(db_con)) try(DBI::dbDisconnect(db_con), silent = TRUE)
  })

  # -- Schema ----------------------------------------------------------------
  schema_text <- if (!is.null(db_con)) {
    tryCatch(get_db_schema(db_con), error = function(e) "(schema unavailable)")
  } else {
    "(database not connected)"
  }

  # -- ellmer chat + tool registration ---------------------------------------
  api_key <- Sys.getenv("ANTHROPIC_API_KEY")

  chat <- if (nzchar(api_key) && !is.null(db_con)) {
    ch <- chat_anthropic(
      system_prompt = build_system_prompt(schema_text),
      model = llm_model
    )
    sql_tool <- create_sql_tool(db_con, latest_results, latest_sql)
    ch$register_tool(sql_tool)
    ch
  } else {
    if (!nzchar(api_key)) {
      showNotification(
        "ANTHROPIC_API_KEY is not set. Please set it in .Renviron and restart.",
        type = "error",
        duration = NULL
      )
    }
    NULL
  }

  # -- Outputs ---------------------------------------------------------------
  output$model_display <- renderText(llm_model)

  output$schema_display <- renderText(schema_text)

  output$results_badge <- renderUI({
    results <- latest_results()
    if (is.null(results)) return(NULL)
    tags$span(class = "badge bg-primary", paste(nrow(results), "rows"))
  })

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

  # -- Helper: send a question to Claude ------------------------------------
  ask_question <- function(question) {
    if (is.null(chat)) {
      chat_append(
        "chat",
        "Cannot process your question: check that ANTHROPIC_API_KEY is set and the database is connected."
      )
      return(invisible(NULL))
    }

    tryCatch(
      {
        stream <- chat$stream_async(question)
        chat_append("chat", stream)
      },
      error = function(e) {
        chat_append("chat", paste("Error:", conditionMessage(e)))
      }
    )
  }

  # -- Chat input observer ---------------------------------------------------
  observeEvent(input$chat_user_input, {
    ask_question(input$chat_user_input)
  })

  # -- Suggested question buttons --------------------------------------------
  observeEvent(input$q1, {
    chat_append("chat", "What are the top 10 products by revenue?", role = "user")
    ask_question("What are the top 10 products by revenue?")
  })

  observeEvent(input$q2, {
    chat_append("chat", "Show monthly sales trends", role = "user")
    ask_question("Show monthly sales trends")
  })

  observeEvent(input$q3, {
    chat_append("chat", "Which customers have the most orders?", role = "user")
    ask_question("Which customers have the most orders?")
  })

  observeEvent(input$q4, {
    chat_append("chat", "What is the average order value?", role = "user")
    ask_question("What is the average order value?")
  })

  # -- Clear chat button -----------------------------------------------------
  observeEvent(input$clear_chat, {
    latest_results(NULL)
    latest_sql(NULL)
    chat_clear("chat")

    # Re-create the ellmer chat object to reset conversation history
    if (!is.null(db_con) && nzchar(api_key)) {
      sql_tool <- create_sql_tool(db_con, latest_results, latest_sql)
      chat <<- chat_anthropic(
        system_prompt = build_system_prompt(schema_text),
        model = llm_model
      )
      chat$register_tool(sql_tool)
    }
  })

  # -- Query results display -------------------------------------------------
  output$query_results_ui <- renderUI({
    results <- latest_results()

    if (is.null(results)) {
      div(
        class = "text-muted text-center py-4",
        tags$p("Query results will appear here after you ask a question."),
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
          paste0(nrow(results), " rows x ", ncol(results), " columns")
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
            paginationStyle = list(color = "#a5b4fc"),
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
