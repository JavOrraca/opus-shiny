# ---------------------------------------------------------------------------
# run.R — Start the plumber API server locally
# ---------------------------------------------------------------------------

library(plumber)

# Read port from environment (default: 8080)
port <- as.integer(Sys.getenv("API_PORT", "8080"))

message("Starting API server on http://0.0.0.0:", port)

# Create and run the plumber router from plumber.R
pr("plumber.R") |>
  pr_run(port = port, host = "0.0.0.0")
