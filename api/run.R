# ---------------------------------------------------------------------------
# run.R — Start the plumber2 API server locally
# ---------------------------------------------------------------------------

library(plumber2)

# Parse the API definition from plumber.R
server <- api_parse("plumber.R")

# Read port from environment (default: 8080)
port <- as.integer(Sys.getenv("API_PORT", "8080"))

message("Starting API server on http://0.0.0.0:", port)
api_run(server, port = port, host = "0.0.0.0")
