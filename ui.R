library(shiny)
library(shinythemes)
source("common.R")

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
      tabsetPanel(
        tabPanel("Validation Results", 
                 p('Welcome to the validator! Choose a study and upload a file to check validity.'), 
                 verbatimTextOutput("validator_output")),
        tabPanel("Specification", 
                 p('This is the full text of the specification you have chosen'),
                 div(style="display: inline-block;","The format is: "),
                 div(style="display: inline-block;",textOutput("specification_format")),
                 verbatimTextOutput("specification"))
      )
    )
  )
))

