# Title: City Federal Spending
# Description: All ingestion and processing steps for project
# Author: Derek Crowe
# Last Edited: 06/05/24

# Overview ================================

# [Full explanation of this workflow and methodology](https://www.notion.so/Federal-Spending-Methodology-e5d0d1e50f0e44879d46504e991ad036?pvs=4)

# Global Requirements ================================

library(tidyverse)
library(glue)
library(sf)


# Configuration ================================

source(file = "./r-delivery/spending-config.R", local = FALSE)


# USA Spending Data Collection ================================

# PostgresSQL databases were created locally and populated with transaction
# data from USA Spending using the [awardsreport API endpoint]
# (https://github.com/govex/awardsreport).

# See the overview document for a full description of data collection methods

# Connect to postgresSQL databases
source(file = "./r-delivery/spending-postgres.R", local = FALSE)


# Recipient Identification ================================

# Define a list of recipients for which we will analyze transactions data

source(file = "./r-delivery/spending-recipient_id.R", local = FALSE)


# Transaction Collection ================================

# Obtain and process all transactions for identified recipients from 
# postgres databases

source(file = "./r-delivery/spending-transactions.R", local = FALSE)


# Transaction Filtering ================================

# Filter transactions using recipient business type codes and place of 
# performance

source(file = "./r-delivery/spending-transaction_filters.R", local = FALSE)


# Deobligations ================================

# Spread deobligations across years to eliminate negative 
# values in yearly summations of city spending

source(file = "./r-delivery/spending-deobligations.R", local = FALSE)


# Spending Summary ================================

# Summarize federal spending to local governments for each city by fiscal year. 

source(file = "./r-delivery/spending-summary.R", local = FALSE)



