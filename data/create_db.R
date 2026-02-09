# create_db.R
# Creates a sample e-commerce SQLite database with realistic demo data.
# Usage: Rscript data/create_db.R  (from project root)

library(DBI)
library(RSQLite)

set.seed(42)

db_path <- file.path("data", "sample.sqlite")

# Remove existing database if present
if (file.exists(db_path)) {
  file.remove(db_path)
  cat("Removed existing database at", db_path, "\n")
}

con <- dbConnect(RSQLite::SQLite(), db_path)
cat("Creating database at", db_path, "\n\n")

# ---------------------------------------------------------------------------
# Schema
# ---------------------------------------------------------------------------

dbExecute(con, "
  CREATE TABLE customers (
    customer_id  INTEGER PRIMARY KEY,
    name         TEXT    NOT NULL,
    email        TEXT    NOT NULL,
    city         TEXT    NOT NULL,
    state        TEXT    NOT NULL,
    signup_date  DATE    NOT NULL,
    tier         TEXT    NOT NULL
  );
")

dbExecute(con, "
  CREATE TABLE products (
    product_id     INTEGER PRIMARY KEY,
    name           TEXT    NOT NULL,
    category       TEXT    NOT NULL,
    price          REAL    NOT NULL,
    cost           REAL    NOT NULL,
    stock_quantity INTEGER NOT NULL
  );
")

dbExecute(con, "
  CREATE TABLE orders (
    order_id     INTEGER PRIMARY KEY,
    customer_id  INTEGER NOT NULL,
    order_date   DATE    NOT NULL,
    status       TEXT    NOT NULL,
    total_amount REAL    NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
  );
")

dbExecute(con, "
  CREATE TABLE order_items (
    item_id    INTEGER PRIMARY KEY,
    order_id   INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    quantity   INTEGER NOT NULL,
    unit_price REAL    NOT NULL,
    FOREIGN KEY (order_id)   REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
  );
")

cat("Tables created: customers, products, orders, order_items\n\n")

# ---------------------------------------------------------------------------
# Seed data helpers
# ---------------------------------------------------------------------------

first_names <- c(
  "James", "Mary", "Robert", "Patricia", "John", "Jennifer", "Michael",
  "Linda", "David", "Elizabeth", "William", "Barbara", "Richard", "Susan",
  "Joseph", "Jessica", "Thomas", "Sarah", "Christopher", "Karen",
  "Charles", "Lisa", "Daniel", "Nancy", "Matthew", "Betty", "Anthony",
  "Margaret", "Mark", "Sandra", "Donald", "Ashley", "Steven", "Kimberly",
  "Andrew", "Emily", "Paul", "Donna", "Joshua", "Michelle", "Kenneth",
  "Carol", "Kevin", "Amanda", "Brian", "Dorothy", "George", "Melissa",
  "Timothy", "Deborah"
)

last_names <- c(
  "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller",
  "Davis", "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez",
  "Wilson", "Anderson", "Thomas", "Taylor", "Moore", "Jackson", "Martin",
  "Lee", "Perez", "Thompson", "White", "Harris", "Sanchez", "Clark",
  "Ramirez", "Lewis", "Robinson", "Walker", "Young", "Allen", "King",
  "Wright", "Scott", "Torres", "Nguyen", "Hill", "Flores", "Green",
  "Adams", "Nelson", "Baker", "Hall", "Rivera", "Campbell", "Mitchell",
  "Carter", "Roberts"
)

cities_states <- data.frame(
  city = c(
    "New York", "Los Angeles", "Chicago", "Houston", "Phoenix",
    "Philadelphia", "San Antonio", "San Diego", "Dallas", "San Jose",
    "Austin", "Jacksonville", "Fort Worth", "Columbus", "Charlotte",
    "Indianapolis", "San Francisco", "Seattle", "Denver", "Nashville",
    "Oklahoma City", "Portland", "Las Vegas", "Memphis", "Louisville",
    "Baltimore", "Milwaukee", "Albuquerque", "Tucson", "Fresno",
    "Sacramento", "Mesa", "Atlanta", "Omaha", "Raleigh",
    "Miami", "Minneapolis", "Tampa", "New Orleans", "Cleveland",
    "Pittsburgh", "St. Louis", "Cincinnati", "Orlando", "Salt Lake City",
    "Richmond", "Boise", "Des Moines", "Honolulu", "Anchorage"
  ),
  state = c(
    "NY", "CA", "IL", "TX", "AZ",
    "PA", "TX", "CA", "TX", "CA",
    "TX", "FL", "TX", "OH", "NC",
    "IN", "CA", "WA", "CO", "TN",
    "OK", "OR", "NV", "TN", "KY",
    "MD", "WI", "NM", "AZ", "CA",
    "CA", "AZ", "GA", "NE", "NC",
    "FL", "MN", "FL", "LA", "OH",
    "PA", "MO", "OH", "FL", "UT",
    "VA", "ID", "IA", "HI", "AK"
  ),
  stringsAsFactors = FALSE
)

tiers <- c("bronze", "silver", "gold", "platinum")
tier_weights <- c(0.40, 0.30, 0.20, 0.10)

# ---------------------------------------------------------------------------
# Customers (50)
# ---------------------------------------------------------------------------

n_customers <- 50

customer_first <- sample(first_names, n_customers, replace = FALSE)
customer_last  <- sample(last_names, n_customers, replace = FALSE)
customer_names <- paste(customer_first, customer_last)

city_idx <- sample(seq_len(nrow(cities_states)), n_customers, replace = FALSE)

signup_start <- as.Date("2024-01-01")
signup_end   <- as.Date("2025-12-31")
signup_dates <- signup_start + sample(0:as.integer(signup_end - signup_start),
                                       n_customers, replace = FALSE)

make_email <- function(first, last, domain) {
  paste0(tolower(first), ".", tolower(last), "@", domain)
}
domains <- c("gmail.com", "yahoo.com", "outlook.com", "hotmail.com",
              "protonmail.com", "icloud.com", "aol.com", "mail.com")

customers <- data.frame(
  customer_id = seq_len(n_customers),
  name        = customer_names,
  email       = mapply(make_email, customer_first, customer_last,
                        sample(domains, n_customers, replace = TRUE),
                        USE.NAMES = FALSE),
  city        = cities_states$city[city_idx],
  state       = cities_states$state[city_idx],
  signup_date = as.character(signup_dates),
  tier        = sample(tiers, n_customers, replace = TRUE, prob = tier_weights),
  stringsAsFactors = FALSE
)

dbWriteTable(con, "customers", customers, append = TRUE, row.names = FALSE)
cat("Inserted", nrow(customers), "customers\n")

# ---------------------------------------------------------------------------
# Products (30)
# ---------------------------------------------------------------------------

product_defs <- list(
  Electronics = list(
    names  = c("Wireless Headphones", "Bluetooth Speaker", "USB-C Hub",
               "Mechanical Keyboard", "Webcam HD", "Portable Charger"),
    prices = c(79.99, 49.99, 34.99, 129.99, 59.99, 29.99)
  ),
  Clothing = list(
    names  = c("Cotton T-Shirt", "Denim Jeans", "Running Shoes",
               "Winter Jacket", "Baseball Cap", "Wool Socks 3-Pack"),
    prices = c(24.99, 59.99, 89.99, 149.99, 19.99, 14.99)
  ),
  `Home & Garden` = list(
    names  = c("Ceramic Plant Pot", "LED Desk Lamp", "Throw Blanket",
               "Kitchen Scale", "Wall Clock", "Tool Set 24-Piece"),
    prices = c(22.99, 39.99, 34.99, 24.99, 29.99, 54.99)
  ),
  Books = list(
    names  = c("Data Science Handbook", "Mystery Novel Collection",
               "Cooking for Beginners", "World Atlas 2025",
               "Sci-Fi Anthology", "Business Strategy Guide"),
    prices = c(44.99, 29.99, 19.99, 34.99, 24.99, 39.99)
  ),
  Sports = list(
    names  = c("Yoga Mat", "Resistance Bands Set", "Water Bottle 32oz",
               "Hiking Backpack", "Tennis Racket", "Jump Rope Pro"),
    prices = c(29.99, 19.99, 14.99, 79.99, 69.99, 12.99)
  )
)

products <- do.call(rbind, lapply(names(product_defs), function(cat_name) {
  defs <- product_defs[[cat_name]]
  data.frame(
    name     = defs$names,
    category = cat_name,
    price    = defs$prices,
    stringsAsFactors = FALSE
  )
}))

products$product_id     <- seq_len(nrow(products))
products$cost           <- round(products$price * runif(nrow(products), 0.35, 0.65), 2)
products$stock_quantity <- sample(10:500, nrow(products), replace = TRUE)

products <- products[, c("product_id", "name", "category", "price", "cost",
                          "stock_quantity")]

dbWriteTable(con, "products", products, append = TRUE, row.names = FALSE)
cat("Inserted", nrow(products), "products\n")

# ---------------------------------------------------------------------------
# Orders (200) and Order Items (500)
# ---------------------------------------------------------------------------

n_orders     <- 200
n_items      <- 500

order_start <- as.Date("2025-02-01")
order_end   <- as.Date("2026-01-31")
order_dates <- order_start + sample(0:as.integer(order_end - order_start),
                                     n_orders, replace = TRUE)
order_dates <- sort(order_dates)

statuses        <- c("completed", "pending", "shipped", "cancelled")
status_weights  <- c(0.55, 0.15, 0.20, 0.10)

orders <- data.frame(
  order_id     = seq_len(n_orders),
  customer_id  = sample(customers$customer_id, n_orders, replace = TRUE),
  order_date   = as.character(order_dates),
  status       = sample(statuses, n_orders, replace = TRUE, prob = status_weights),
  total_amount = 0,
  stringsAsFactors = FALSE
)

# Distribute 500 items across the 200 orders.
# Guarantee every order has at least one item, then distribute the rest.
item_order_ids <- c(
  seq_len(n_orders),
  sample(seq_len(n_orders), n_items - n_orders, replace = TRUE)
)
item_order_ids <- sort(item_order_ids)

order_items <- data.frame(
  item_id    = seq_len(n_items),
  order_id   = item_order_ids,
  product_id = sample(products$product_id, n_items, replace = TRUE),
  quantity   = sample(1:5, n_items, replace = TRUE, prob = c(0.40, 0.30, 0.15, 0.10, 0.05)),
  stringsAsFactors = FALSE
)

# Look up unit_price from products
order_items$unit_price <- products$price[match(order_items$product_id,
                                                products$product_id)]

# Compute order totals from the line items
line_totals <- order_items$quantity * order_items$unit_price
order_totals <- tapply(line_totals, order_items$order_id, sum)
orders$total_amount <- round(as.numeric(order_totals[as.character(orders$order_id)]), 2)

dbWriteTable(con, "orders", orders, append = TRUE, row.names = FALSE)
cat("Inserted", nrow(orders), "orders\n")

dbWriteTable(con, "order_items", order_items, append = TRUE, row.names = FALSE)
cat("Inserted", nrow(order_items), "order items\n")

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

cat("\n========================================\n")
cat("  Database creation complete!\n")
cat("========================================\n\n")

cat("File:", db_path, "\n")
cat("Size:", round(file.info(db_path)$size / 1024, 1), "KB\n\n")

cat("Table summary:\n")
for (tbl in dbListTables(con)) {
  n <- dbGetQuery(con, paste("SELECT COUNT(*) AS n FROM", tbl))$n
  cat(sprintf("  %-15s %d rows\n", tbl, n))
}

cat("\nOrder status breakdown:\n")
status_summary <- dbGetQuery(con, "
  SELECT status, COUNT(*) AS count,
         ROUND(SUM(total_amount), 2) AS total_revenue
  FROM orders
  GROUP BY status
  ORDER BY count DESC
")
for (i in seq_len(nrow(status_summary))) {
  cat(sprintf("  %-12s %3d orders  $%10.2f\n",
              status_summary$status[i],
              status_summary$count[i],
              status_summary$total_revenue[i]))
}

cat("\nProduct category breakdown:\n")
cat_summary <- dbGetQuery(con, "
  SELECT p.category,
         COUNT(DISTINCT p.product_id) AS products,
         SUM(oi.quantity) AS units_sold,
         ROUND(SUM(oi.quantity * oi.unit_price), 2) AS revenue
  FROM products p
  JOIN order_items oi ON p.product_id = oi.product_id
  GROUP BY p.category
  ORDER BY revenue DESC
")
for (i in seq_len(nrow(cat_summary))) {
  cat(sprintf("  %-15s %2d products  %4d units  $%10.2f\n",
              cat_summary$category[i],
              cat_summary$products[i],
              cat_summary$units_sold[i],
              cat_summary$revenue[i]))
}

cat("\nCustomer tier distribution:\n")
tier_summary <- dbGetQuery(con, "
  SELECT tier, COUNT(*) AS count
  FROM customers
  GROUP BY tier
  ORDER BY count DESC
")
for (i in seq_len(nrow(tier_summary))) {
  cat(sprintf("  %-10s %2d customers\n",
              tier_summary$tier[i],
              tier_summary$count[i]))
}

cat("\nDate range of orders:",
    dbGetQuery(con, "SELECT MIN(order_date) FROM orders")[[1]], "to",
    dbGetQuery(con, "SELECT MAX(order_date) FROM orders")[[1]], "\n")

dbDisconnect(con)
cat("\nDone. Database connection closed.\n")
