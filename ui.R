library(shiny)
library(shinythemes)
library(DT)
library(yaml)


# Packages and shared functions ----------------------------------------------------------

source("common.R")


# Configuration setup --------------------------------------------------------------------

## Load default configuration

config <- yaml::read_yaml(
  "configuration/config_Default.yaml"
)


## Find available configurations

configuration_files <- list.files(
  "configuration",
  pattern = "^config_.+\\.yaml$",
  full.names = FALSE
)


## Create configuration display names

configuration_choices <- setNames(
  configuration_files,
  sub(
    "^config_(.*)\\.yaml$",
    "\\1",
    configuration_files
  )
)


## Make the default configuration display as "Default"

if ("config_Default.yaml" %in% names(configuration_choices)) {
  configuration_choices["config_Default.yaml"] <- "Default"
}


# UI styling -----------------------------------------------------------------------------

theme <- shinythemes::shinytheme("spacelab")

ui <- fluidPage(
  
  tags$head(
    tags$style(HTML("
      
      /* Overall page */
      
      body {
        background-color: #f6f7fb;
        color: #4a5063;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI',
                     Roboto, Helvetica, Arial, sans-serif;
      }
      
      
      /* Application header */
      
      .app-title {
        background: linear-gradient(
          135deg,
          #e8f3f5 0%,
          #eeeaf7 100%
        );
        border: 1px solid #ddd9e9;
        border-radius: 16px;
        padding: 24px 30px 25px 30px;
        margin: 0 0 24px 0;
        box-shadow: 0 4px 12px rgba(70, 65, 95, 0.07);
        position: relative;
        overflow: hidden;
      }
      
      .app-title::before {
        content: '';
        position: absolute;
        width: 150px;
        height: 150px;
        right: -45px;
        top: -75px;
        border-radius: 50%;
        background-color: rgba(143, 130, 177, 0.12);
      }
      
      .app-title::after {
        content: '';
        position: absolute;
        width: 80px;
        height: 80px;
        right: 70px;
        bottom: -45px;
        border-radius: 50%;
        background-color: rgba(107, 155, 167, 0.09);
      }
      
      .app-title h2 {
        margin: 0;
        color: #554d72;
        font-weight: 600;
        letter-spacing: -0.4px;
        position: relative;
        z-index: 1;
      }
      
      
      /* Sidebar */
      
      .well {
        background-color: #ffffff;
        border: 1px solid #e0e0e8;
        border-radius: 14px;
        box-shadow: 0 3px 10px rgba(70, 65, 95, 0.06);
        padding: 20px;
      }
      
      .sidebarPanel h4 {
        color: #625d73;
        font-size: 14px;
        font-weight: 600;
        margin-top: 4px;
        margin-bottom: 8px;
      }
      
      
      /* No specifications message */
      
      .no-specifications {
        background-color: #f3f0f8;
        border: 1px solid #ddd7e9;
        border-left: 4px solid #8f82b1;
        border-radius: 8px;
        padding: 12px 14px;
        margin-top: 5px;
        margin-bottom: 15px;
      }
      
      .no-specifications strong {
        display: block;
        color: #554d72;
        margin-bottom: 5px;
      }
      
      .no-specifications p {
        color: #6a6877;
        font-size: 13px;
        line-height: 1.5;
        margin: 0;
      }
      
      
      /* Form controls */
      
      .form-control,
      .selectize-input {
        border: 1px solid #d5d5df;
        border-radius: 8px;
        box-shadow: none;
        color: #4d5364;
        background-color: #ffffff;
        min-height: 38px;
      }
      
      .form-control:focus,
      .selectize-input.focus {
        border-color: #9b8fbd;
        box-shadow: 0 0 0 3px rgba(155, 143, 189, 0.14);
      }
      
      .selectize-dropdown {
        border: 1px solid #d5d5df;
        border-radius: 8px;
        box-shadow: 0 4px 12px rgba(70, 65, 95, 0.10);
      }
      
      .selectize-dropdown .option {
        padding: 8px 10px;
      }
      
      
      /* Browse button */
      
      .form-group .btn-file,
      .form-group .btn-file:hover,
      .form-group .btn-file:focus,
      .form-group .btn-file:active,
      .form-group .btn-file:visited {
        background-color: #4b3d6d !important;
        background-image: none !important;
        border-color: #4b3d6d !important;
        color: #ffffff !important;
        text-shadow: none !important;
        box-shadow: none !important;
      }
      
      .form-group .btn-file span {
        color: #ffffff !important;
      }
      
      
      /* Download buttons */
      
      #downloadHighlighted,
      #downloadHighlighted:hover,
      #downloadHighlighted:focus,
      #downloadHighlighted:active,
      #downloadHighlighted:visited,
      
      #downloadSpecification,
      #downloadSpecification:hover,
      #downloadSpecification:focus,
      #downloadSpecification:active,
      #downloadSpecification:visited,
      
      #downloadConfiguration,
      #downloadConfiguration:hover,
      #downloadConfiguration:focus,
      #downloadConfiguration:active,
      #downloadConfiguration:visited {
        background-color: #4b3d6d !important;
        background-image: none !important;
        border-color: #4b3d6d !important;
        color: #ffffff !important;
        text-shadow: none !important;
        box-shadow: none !important;
      }
      
      #downloadHighlighted:hover,
      #downloadHighlighted:focus,
      
      #downloadSpecification:hover,
      #downloadSpecification:focus,
      
      #downloadConfiguration:hover,
      #downloadConfiguration:focus {
        background-color: #382c55 !important;
        border-color: #382c55 !important;
        color: #ffffff !important;
        transform: translateY(-1px);
        box-shadow: 0 3px 8px rgba(75, 61, 109, 0.20) !important;
      }
      
      
      /* Download button text */
      
      #downloadSpecification span,
      #downloadSpecification i,
      
      #downloadConfiguration span,
      #downloadConfiguration i,
      
      #downloadHighlighted span,
      #downloadHighlighted i {
        color: #ffffff !important;
      }
      
      
      /* Navigation */
      
      .navigation-menu {
        margin-top: 5px;
      }
      
      .navigation-menu .control-label {
        font-size: 14px;
        font-weight: 600;
        color: #625d73;
        margin-bottom: 10px;
      }
      
      .navigation-menu .radio {
        margin-top: 0;
        margin-bottom: 4px;
      }
      
      .navigation-menu .radio label {
        display: block;
        padding: 10px 12px;
        margin: 0;
        border-radius: 9px;
        cursor: pointer;
        font-weight: 400;
        color: #6a6d7c;
        transition: all 0.15s ease;
      }
      
      .navigation-menu .radio input[type='radio'] {
        position: absolute;
        opacity: 0;
      }
      
      .navigation-menu .radio label:hover {
        background-color: #f3f0f8;
        color: #5b5275;
        transform: translateX(2px);
      }
      
      .navigation-menu .radio input[type='radio']:checked + span {
        font-weight: 600;
      }
      
      .navigation-menu .radio:has(input[type='radio']:checked) label {
        background-color: #eeeaf7;
        color: #5b5275;
        box-shadow: inset 4px 0 0 #8f82b1;
      }
      
      
      /* Main content cards */
      
      .content-card {
        background-color: #ffffff;
        border: 1px solid #e0e0e8;
        border-radius: 14px;
        padding: 25px 28px;
        margin-bottom: 20px;
        box-shadow: 0 3px 11px rgba(70, 65, 95, 0.05);
      }
      
      
      /* Validation summary */
      
      .validation-summary {
        background-color: #f3f0f8;
        border: 1px solid #ddd7e9;
        border-left: 4px solid #8f82b1;
        border-radius: 8px;
        padding: 15px 18px;
        margin-bottom: 20px;
      }
      
      .validation-summary-title {
        color: #554d72;
        font-size: 16px;
        font-weight: 600;
        margin-bottom: 10px;
      }
      
      .validation-summary-success {
        background-color: #f1f7f3;
        border-color: #d5e5da;
        border-left-color: #6f9b7b;
      }
      
      .validation-summary-success .validation-summary-title {
        color: #52745c;
      }
      
      .validation-summary-count {
        color: #554d72;
        font-size: 15px;
        font-weight: 600;
        margin-bottom: 10px;
      }
      
      .validation-summary-details {
        color: #626878;
        font-size: 13px;
        line-height: 1.7;
      }
      
      .validation-summary-details strong {
        color: #5b5275;
      }
      
      
      /* Validation error display */
      
      .validation-errors-table {
        border: 1px solid #e0dce8;
        border-radius: 8px;
        overflow: hidden;
        margin-top: 10px;
        margin-bottom: 20px;
      }
      
      .validation-errors-header {
        display: grid;
        grid-template-columns: 20% 40% 40%;
        background-color: #f3f0f8;
        color: #554d72;
        font-weight: 600;
      }
      
      .validation-errors-header > div {
        padding: 12px 14px;
      }
      
      .validation-error-row {
        display: grid;
        grid-template-columns: 20% 40% 40%;
        border-top: 1px solid #e6e3eb;
      }
      
      .validation-error-row:nth-child(even) {
        background-color: #faf9fc;
      }
      
      .validation-error-location-cell,
      .validation-error-cell,
      .validation-explanation-cell {
        padding: 12px 14px;
      }
      
      .validation-error-location-cell {
        color: #554d72;
        font-weight: 600;
      }
      
      .validation-error-cell {
        color: #c0392b;
      }
      
      .validation-explanation-cell {
        color: #626878;
        border-left: 1px solid #e6e3eb;
      }
      
      @media (max-width: 768px) {
        
        .validation-errors-header,
        .validation-error-row {
          grid-template-columns: 1fr;
        }
        
        .validation-error-location-cell,
        .validation-error-cell,
        .validation-explanation-cell {
          border-left: none;
        }
        
        .validation-error-cell,
        .validation-explanation-cell {
          border-top: 1px solid #e6e3eb;
        }
      }
      
      
      /* Main headings */
      
      .main-panel h3 {
        color: #554d72;
        font-weight: 600;
        margin-top: 3px;
        margin-bottom: 20px;
      }
      
      .main-panel h4 {
        color: #665f7d;
        font-weight: 600;
        margin-top: 20px;
        margin-bottom: 12px;
      }
      
      
      /* Section titles */
      
      .content-card h3 {
        display: block;
        background-color: #f3f0f8;
        color: #554d72;
        padding: 11px 15px;
        margin-top: 0;
        margin-bottom: 20px;
        border-left: 4px solid #8f82b1;
        border-radius: 7px;
        font-weight: 600;
      }
      
      
      /* Text */
      
      .main-panel p {
        color: #626878;
        line-height: 1.65;
      }
      
      
      /* Buttons */
      
      .btn {
        border-radius: 8px;
        font-weight: 500;
        box-shadow: none;
        transition: all 0.15s ease;
      }
      
      
      /* Default buttons */
      
      .btn-default {
        background-color: #ffffff;
        border-color: #d3d1dc;
        color: #4f5060;
      }
      
      .btn-default:hover,
      .btn-default:focus {
        background-color: #f4f1f8;
        border-color: #bdb8ca;
        color: #554d72;
      }
      
      
      /* Checkboxes and radio buttons */
      
      .checkbox label,
      .radio label {
        color: #626878;
      }
      
      
      /* Data table */
      
      .dataTables_wrapper {
        background-color: #ffffff;
        border: 1px solid #e0e0e8;
        border-radius: 14px;
        padding: 16px;
        margin-top: 20px;
        box-shadow: 0 3px 10px rgba(70, 65, 95, 0.045);
      }
      
      
      /* Editable validation table */
      
      .dataTables_wrapper table.dataTable tbody td input {
        color: #333333 !important;
        background-color: #ffffff !important;
        border: 1px solid #b8afd0;
        border-radius: 4px;
        padding: 4px 6px;
      }
      
      
      /* Tabs */
      
      .nav-tabs {
        border-bottom: 1px solid #dfdce7;
      }
      
      .nav-tabs > li > a {
        color: #6a6877;
        border-radius: 8px 8px 0 0;
        transition: background-color 0.15s ease;
      }
      
      .nav-tabs > li > a:hover {
        background-color: #f3f0f8;
        border-color: #dfdce7;
      }
      
      .nav-tabs > li.active > a,
      .nav-tabs > li.active > a:hover,
      .nav-tabs > li.active > a:focus {
        color: #5b5275;
        font-weight: 600;
        border-color: #dfdce7;
        border-bottom-color: #ffffff;
      }
      
      
      /* Horizontal rules */
      
      hr {
        border-top: 1px solid #e3e1e8;
        margin-top: 22px;
        margin-bottom: 22px;
      }
      
      
      /* Labels */
      
      .control-label {
        color: #625d73;
      }
      
      
      /* Validation configuration content */
      
      .content-card strong {
        color: #5b5275;
      }
      
      .content-card em {
        color: #707180;
      }
      
      
      /* Text size controls */
      
      .text-size-controls {
        display: flex;
        align-items: center;
        justify-content: flex-end;
        gap: 5px;
        margin-top: -12px;
        margin-bottom: 18px;
      }
      
      .text-size-label {
        color: #625d73;
        font-weight: 600;
        margin-right: 5px;
      }
      
      .text-size-button {
        background-color: #ffffff;
        border: 1px solid #d3d1dc;
        color: #554d72;
        border-radius: 6px;
        padding: 4px 10px;
        cursor: pointer;
        font-size: 14px;
        line-height: 1.4;
      }
      
      .text-size-button:hover {
        background-color: #f3f0f8;
        border-color: #bdb8ca;
        color: #554d72;
      }
      
      .text-size-button:focus {
        outline: none;
        box-shadow: 0 0 0 3px rgba(155, 143, 189, 0.14);
      }
      
      
      /* Text size levels */
      
      body.text-size-xsmall {
        font-size: 12px;
      }
      
      body.text-size-small {
        font-size: 14px;
      }
      
      body.text-size-default {
        font-size: 15px;
      }
      
      body.text-size-large {
        font-size: 18px;
      }
      
      body.text-size-xlarge {
        font-size: 21px;
      }
      
    "))
  ),
  
  
  # Application header -------------------------------------------------------------------
  
  div(
    class = "app-title",
    uiOutput("app_title")
  ),
  
  
  ## Text size controls -------------------------------------------------------------------
  
  div(
    class = "text-size-controls",
    
    tags$span(
      class = "text-size-label",
      "Text size:"
    ),
    
    tags$button(
      id = "text_size_xsmall",
      class = "text-size-button",
      type = "button",
      "A−−"
    ),
    
    tags$button(
      id = "text_size_small",
      class = "text-size-button",
      type = "button",
      "A−"
    ),
    
    tags$button(
      id = "text_size_default",
      class = "text-size-button",
      type = "button",
      "A"
    ),
    
    tags$button(
      id = "text_size_large",
      class = "text-size-button",
      type = "button",
      "A+"
    ),
    
    tags$button(
      id = "text_size_xlarge",
      class = "text-size-button",
      type = "button",
      "A++"
    )
  ),
  
  
  # Main layout ---------------------------------------------------------------------------
  
  sidebarLayout(
    
    ## Sidebar
    
    sidebarPanel(
      width = 3,
      
      
      ## Configuration selection
      
      selectInput(
        "configuration",
        h4("Configuration"),
        choices = configuration_choices,
        selected = "config_default.yaml"
      ),
      
      
      ## Study and format selection
      
      uiOutput("study_selection"),
      
      uiOutput("study_format"),
      
      
      ## Dataset upload
      
      fileInput(
        "file",
        "Choose CSV File",
        multiple = FALSE,
        accept = c(
          "text/csv",
          "text/comma-separated-values,text/plain",
          ".csv"
        )
      ),
      
      hr(),
      
      
      ## Navigation
      
      div(
        class = "navigation-menu",
        
        radioButtons(
          "page",
          "Validator Functions",
          choices = c(
            "Validation Results" = "validation_results",
            "Specification Details" = "specification",
            "Specification Creation" = "specification_creation",
            "Configuration Creation" = "configuration_creation"
          ),
          selected = "validation_results"
        )
      )
    ),
    
    
    ## Main panel
    
    mainPanel(
      width = 9,
      
      
      ## Validation Results
      
      conditionalPanel(
        condition = "input.page == 'validation_results'",
        
        div(
          class = "content-card",
          
          uiOutput("validation_config_content"),
          
          br(),
          br(),
          
          downloadButton(
            "downloadHighlighted",
            "Download Edited & Highlighted File"
          ),
          
          br(),
          br(),
          
          radioButtons(
            "error_view",
            "Error display:",
            choices = c(
              "Error Summary" = "summary",
              "Errors by row" = "row",
              "Errors by column" = "column"
            ),
            selected = "summary",
            inline = TRUE
          ),
          
          uiOutput("errors_by_column")
        ),
        
        DTOutput("validation_preview")
      ),
      
      
      ## Specification Details
      
      conditionalPanel(
        condition = "input.page == 'specification'",
        
        div(
          class = "content-card",
          
          h3("Specification Details"),
          
          uiOutput("specification_message"),
          
          uiOutput("specification")
        )
      ),
      
      
      ## Specification Creation
      
      conditionalPanel(
        condition = "input.page == 'specification_creation'",
        
        div(
          class = "content-card",
          
          h3("Specification Creation"),
          
          h4("Create your specification"),
          
          p(
            "Create a data specification for your validator. ",
            "The fields below allow you to define the variables, data types, ",
            "allowed values, and validation requirements for your dataset. ",
            "Start by selecting how many variables you need for your specification."
          ),
          
          numericInput(
            "numVars",
            "Number of Variables:",
            value = 0,
            min = 0
          ),
          
          tabsetPanel(
            id = "variable_tabs",
            type = "tabs"
          ),
          
          conditionalPanel(
            condition = "input.numVars > 0",
            uiOutput("downloadSetupButton")
          )
        )
      ),
      
      
      ## Configuration Creation
      
      conditionalPanel(
        condition = "input.page == 'configuration_creation'",
        
        div(
          class = "content-card",
          
          uiOutput("configuration_creation_content")
        )
      )
    )
  ),
  
  
  # JavaScript ----------------------------------------------------------------------------
  
  tags$script(HTML("
    
    document.addEventListener('input', function(event) {
      
      // Variable tab names
      
      if (event.target.id.startsWith('field_name_')) {
        
        var number = event.target.id.replace('field_name_', '');
        var label = document.getElementById('tab_label_' + number);
        
        if (label) {
          
          if (event.target.value.trim() === '') {
            label.textContent = 'Variable ' + number;
          } else {
            label.textContent = event.target.value;
          }
        }
      }
      
      
      // Instruction Set 1 heading
      
      if (event.target.id === 'config_instruction_set_1_name') {
        
        var heading = document.getElementById(
          'instruction_set_1_creation_heading'
        );
        
        if (heading) {
          
          if (event.target.value.trim() === '') {
            heading.textContent = 'Instruction Set 1';
          } else {
            heading.textContent = event.target.value;
          }
        }
      }
      
      
      // Instruction Set 2 heading
      
      if (event.target.id === 'config_instruction_set_2_name') {
        
        var heading = document.getElementById(
          'instruction_set_2_creation_heading'
        );
        
        if (heading) {
          
          if (heading) {
            
            if (event.target.value.trim() === '') {
              heading.textContent = 'Instruction Set 2';
            } else {
              heading.textContent = event.target.value;
            }
          }
        }
      }
    });
  ")),
  
  
  ## Text size JavaScript -----------------------------------------------------------------
  
  tags$script(HTML("
    
    document.addEventListener('DOMContentLoaded', function() {
      document.body.classList.add('text-size-default');
    });
    
    
    document.addEventListener('click', function(event) {
      
      if (event.target.id === 'text_size_xsmall') {
        
        document.body.classList.remove(
          'text-size-small',
          'text-size-default',
          'text-size-large',
          'text-size-xlarge'
        );
        
        document.body.classList.add('text-size-xsmall');
      }
      
      
      if (event.target.id === 'text_size_small') {
        
        document.body.classList.remove(
          'text-size-xsmall',
          'text-size-default',
          'text-size-large',
          'text-size-xlarge'
        );
        
        document.body.classList.add('text-size-small');
      }
      
      
      if (event.target.id === 'text_size_default') {
        
        document.body.classList.remove(
          'text-size-xsmall',
          'text-size-small',
          'text-size-large',
          'text-size-xlarge'
        );
        
        document.body.classList.add('text-size-default');
      }
      
      
      if (event.target.id === 'text_size_large') {
        
        document.body.classList.remove(
          'text-size-xsmall',
          'text-size-small',
          'text-size-default',
          'text-size-xlarge'
        );
        
        document.body.classList.add('text-size-large');
      }
      
      
      if (event.target.id === 'text_size_xlarge') {
        
        document.body.classList.remove(
          'text-size-xsmall',
          'text-size-small',
          'text-size-default',
          'text-size-large'
        );
        
        document.body.classList.add('text-size-xlarge');
      }
    });
    
  "))
)