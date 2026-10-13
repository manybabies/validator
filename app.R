library(shiny)
library(DT)

options(shiny.maxRequestSize = 50 * 1024^2)

source("ui.R")
source("app_server.R")

shinyApp(ui = ui, server = server)