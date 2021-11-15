library(shiny)
library(tidyverse)
library(yaml)

source("common.R")



shinyServer(function(input, output, session) {
  output$study_format <- renderUI({
    selectInput("format", label = h4("Study Format"),
                choices = filter(studies, study == input$study)$format)
  })
  
  output$specification <- renderPrint({
    yaml::yaml.load_file(paste0("data_specifications/",
                                input$study, "_", input$format, 
                                ".yaml"))
  })
    
  output$validator_output <- renderPrint({
    req(input$file) 
    
    fields <- yaml::yaml.load_file(paste0("data_specifications/",
                                          input$study, "_", input$format, 
                                          ".yaml"))
    
    
    # 
  
  
    tryCatch(
      {
        df <- read_csv(input$file$datapath)
        cat("Upload successful!\n\n")
      },
      error = function(e) {
        # return a safeError if a parsing error occurs
        stop(safeError(e))
      }
    )
    
    valid <- validate_dataset(fields, df)
    
    if (valid) {
      cat("\nDataset is valid!")
    } else {
      cat("\nDataset is NOT valid, please correct and try again!")
    }
    
  })
})
  


  