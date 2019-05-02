library(shiny)
library(shinythemes)

shinyUI(fluidPage(
  theme = shinytheme("spacelab"),
  
  titlePanel("ManyBabies Data Validator"),
  br(),
  
  sidebarLayout(
    sidebarPanel(
      selectInput("study", h4("Study"), 
                  choices = unique(studies$study)),
      uiOutput("study_format"),
      fileInput("file", "Choose CSV File",
                multiple = FALSE,
                accept = c("text/csv",
                           "text/comma-separated-values,text/plain",
                           ".csv"))
    ),
    mainPanel(
      verbatimTextOutput("validator_output"))
  )
))

