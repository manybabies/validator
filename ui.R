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
                 p(strong('Welcome to the validator!')),
                 p(em('You can check your lab id here:'), 
                   tags$a(href="https://docs.google.com/spreadsheets/d/1O_c4QoRwBUQvpCABFC2XIlx4upsvHZm02VDV8xDUg8s/edit?usp=sharing",
                                                               "lab id list")),
                 p(strong('Choose a study and upload a file to check validity.')), 
                 verbatimTextOutput("validator_output")),
        tabPanel("Specification", 
                 p('This is the full text of the specification you have chosen'),
                 verbatimTextOutput("specification"))
      )
    )
  )
))

