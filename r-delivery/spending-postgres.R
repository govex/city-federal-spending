# Title: City Federal Spending - PostgresSQL DB Connections
# Description:
# Author: Derek Crowe
# Last Edited: 3/29/24

## Connect to PostgresSQL databases ================================

# Check to make sure awardsreport_db is running: 
stopifnot(DBI::dbCanConnect(RPostgres::Postgres(),
                            dbname = "ar_db_17",
                            port = 5432,
                            user = Sys.getenv("DB_USER"),
                            password = Sys.getenv("DB_PASSWORD")))

# Define vector of year numbers that we have databases for
years <- c(17:23)

# Define list of connection objects 
cons <- purrr::map(years, ~ DBI::dbConnect(RPostgres::Postgres(),
                                           dbname = glue("ar_db_", {.x}),
                                           port = 5432, 
                                           user = Sys.getenv("DB_USER"),
                                           password = Sys.getenv("DB_PASSWORD")))

### Define transactions tables ================================

# List of transactions tables for each year
trans <- purrr::map(cons, ~ dplyr::tbl(.x, "transactions"))

# Name each list item using corresponding year
names(trans) <- purrr::map(years, ~ glue::glue("trans_", {.x}))
