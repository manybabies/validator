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
    
    # Theme JavaScript --------------------------------------------------------------------
    
    tags$script(HTML("
      Shiny.addCustomMessageHandler('set-theme', function(theme) {
        
        document.body.classList.remove(
          'theme-blue',
          'theme-purple',
          'theme-teal'
        );
        
        document.body.classList.add('theme-' + theme);
      });
    ")),
    
    
    # Theme colours -----------------------------------------------------------------------
    
    tags$style(HTML("
      
      /* Blue theme */
      
      body.theme-blue {
        --theme-accent: #0072B2;
        --theme-accent-light: #E6F2F8;
        --theme-accent-dark: #004C73;
        --theme-banner-start: #DCEEF7;
        --theme-banner-end: #E6F2F8;
        --theme-border: #C7DDE8;
      }
      
      
      /* Purple theme */
      
      body.theme-purple {
        --theme-accent: #6A3D9A;
        --theme-accent-light: #F0EAF6;
        --theme-accent-dark: #47296B;
        --theme-banner-start: #E8DDF1;
        --theme-banner-end: #F0EAF6;
        --theme-border: #D8CBE2;
      }
      
      
      /* Teal theme */
      
      body.theme-teal {
        --theme-accent: #007C83;
        --theme-accent-light: #E4F3F3;
        --theme-accent-dark: #00565B;
        --theme-banner-start: #D7EEEE;
        --theme-banner-end: #E4F3F3;
        --theme-border: #C5DEDF;
      }
      
    ")),
    
    
    tags$style(HTML("
      
      /* Overall page */
      
      body {
        background-color: #F7F7F7;
        color: #222222;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI',
                     Roboto, Helvetica, Arial, sans-serif;
      }
      
      
      /* Application banner */
      
      .validator-banner {
        background: linear-gradient(
          135deg,
          var(--theme-banner-start) 0%,
          var(--theme-banner-end) 100%
        );
        border: 1px solid var(--theme-border);
        border-radius: 16px;
        padding: 28px 30px;
        margin: 0 0 24px 0;
        box-shadow: 0 4px 12px rgba(70, 65, 95, 0.07);
        position: relative;
        overflow: hidden;
        text-align: center;
      }
      
      .validator-banner::before {
        content: '';
        position: absolute;
        width: 150px;
        height: 150px;
        right: -45px;
        top: -75px;
        border-radius: 50%;
        background-color: var(--theme-accent);
        opacity: 0.10;
      }
      
      .validator-banner::after {
        content: '';
        position: absolute;
        width: 80px;
        height: 80px;
        left: 70px;
        bottom: -45px;
        border-radius: 50%;
        background-color: var(--theme-accent);
        opacity: 0.07;
      }
      
      .validator-banner h1 {
        margin: 0;
        color: var(--theme-accent);
        font-size: 32px;
        font-weight: 600;
        letter-spacing: -0.4px;
        position: relative;
        z-index: 1;
      }
      
      
      /* Sidebar */
      
      .well {
        background-color: #FFFFFF;
        border: 1px solid #DDDDDD;
        border-radius: 14px;
        box-shadow: 0 3px 10px rgba(70, 65, 95, 0.06);
        padding: 20px;
      }
      
      .sidebarPanel h4 {
        color: #444444;
        font-size: 14px;
        font-weight: 600;
        margin-top: 4px;
        margin-bottom: 8px;
      }
      
      
      /* No specifications message */
      
      .no-specifications {
        background-color: var(--theme-accent-light);
        border: 1px solid var(--theme-border);
        border-left: 4px solid var(--theme-accent);
        border-radius: 8px;
        padding: 12px 14px;
        margin-top: 5px;
        margin-bottom: 15px;
      }
      
      .no-specifications strong {
        display: block;
        color: var(--theme-accent);
        margin-bottom: 5px;
      }
      
      .no-specifications p {
        color: #555555;
        font-size: 13px;
        line-height: 1.5;
        margin: 0;
      }
      
      
      /* Form controls */
      
      .form-control,
      .selectize-input {
        border: 1px solid #CCCCCC;
        border-radius: 8px;
        box-shadow: none;
        color: #333333;
        background-color: #FFFFFF;
        min-height: 38px;
      }
      
      .form-control:focus,
      .selectize-input.focus {
        border-color: var(--theme-accent);
        box-shadow: 0 0 0 3px rgba(0, 114, 178, 0.14);
      }
      
      .selectize-dropdown {
        border: 1px solid #CCCCCC;
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
        background-color: var(--theme-accent) !important;
        background-image: none !important;
        border-color: var(--theme-accent) !important;
        color: #FFFFFF !important;
        text-shadow: none !important;
        box-shadow: none !important;
      }
      
      .form-group .btn-file span {
        color: #FFFFFF !important;
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
        background-color: var(--theme-accent) !important;
        background-image: none !important;
        border-color: var(--theme-accent) !important;
        color: #FFFFFF !important;
        text-shadow: none !important;
        box-shadow: none !important;
      }
      
      #downloadHighlighted:hover,
      #downloadHighlighted:focus,
      
      #downloadSpecification:hover,
      #downloadSpecification:focus,
      
      #downloadConfiguration:hover,
      #downloadConfiguration:focus {
        background-color: var(--theme-accent-dark) !important;
        border-color: var(--theme-accent-dark) !important;
        color: #FFFFFF !important;
        transform: translateY(-1px);
        box-shadow: 0 3px 8px rgba(70, 65, 95, 0.20) !important;
      }
      
      
      /* Download button text */
      
      #downloadSpecification span,
      #downloadSpecification i,
      
      #downloadConfiguration span,
      #downloadConfiguration i,
      
      #downloadHighlighted span,
      #downloadHighlighted i {
        color: #FFFFFF !important;
      }
      
      
      /* Navigation */
      
      .navigation-menu {
        margin-top: 5px;
      }
      
      .navigation-menu .control-label {
        font-size: 14px;
        font-weight: 600;
        color: #444444;
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
        color: #555555;
        transition: all 0.15s ease;
      }
      
      .navigation-menu .radio input[type='radio'] {
        position: absolute;
        opacity: 0;
      }
      
      .navigation-menu .radio label:hover {
        background-color: var(--theme-accent-light);
        color: var(--theme-accent);
        transform: translateX(2px);
      }
      
      .navigation-menu .radio input[type='radio']:checked + span {
        font-weight: 600;
      }
      
      .navigation-menu .radio:has(input[type='radio']:checked) label {
        background-color: var(--theme-accent-light);
        color: var(--theme-accent);
        box-shadow: inset 4px 0 0 var(--theme-accent);
      }
      
      
      /* Main content cards */
      
      .content-card {
        background-color: #FFFFFF;
        border: 1px solid #DDDDDD;
        border-radius: 14px;
        padding: 25px 28px;
        margin-bottom: 20px;
        box-shadow: 0 3px 11px rgba(70, 65, 95, 0.05);
      }
      
      
      /* Validation summary */
      
      .validation-summary {
        background-color: var(--theme-accent-light);
        border: 1px solid var(--theme-border);
        border-left: 4px solid var(--theme-accent);
        border-radius: 8px;
        padding: 15px 18px;
        margin-bottom: 20px;
      }
      
      .validation-summary-title {
        color: var(--theme-accent);
        font-size: 16px;
        font-weight: 600;
        margin-bottom: 10px;
      }
      
      /* Success colours are independent of the theme */
      
      .validation-summary-success {
        background-color: #E8F4EF;
        border-color: #BFDCCF;
        border-left-color: #009E73;
      }
      
      .validation-summary-success .validation-summary-title {
        color: #007A59;
      }
      
      .validation-summary-count {
        color: var(--theme-accent);
        font-size: 15px;
        font-weight: 600;
        margin-bottom: 10px;
      }
      
      .validation-summary-details {
        color: #555555;
        font-size: 13px;
        line-height: 1.7;
      }
      
      .validation-summary-details strong {
        color: var(--theme-accent);
      }
      
      
      /* Validation error display */
      
      .validation-errors-table {
        border: 1px solid #DDDDDD;
        border-radius: 8px;
        overflow: hidden;
        margin-top: 10px;
        margin-bottom: 20px;
      }
      
      .validation-errors-header {
        display: grid;
        grid-template-columns: 20% 40% 40%;
        background-color: var(--theme-accent-light);
        color: var(--theme-accent);
        font-weight: 600;
      }
      
      .validation-errors-header > div {
        padding: 12px 14px;
      }
      
      .validation-error-row {
        display: grid;
        grid-template-columns: 20% 40% 40%;
        border-top: 1px solid #E0E0E0;
      }
      
      .validation-error-row:nth-child(even) {
        background-color: #FAFAFA;
      }
      
      .validation-error-location-cell,
      .validation-error-cell,
      .validation-explanation-cell {
        padding: 12px 14px;
      }
      
      .validation-error-location-cell {
        color: var(--theme-accent);
        font-weight: 600;
      }
      
      /* Error colour is independent of the theme */
      
      .validation-error-cell {
        color: #D55E00;
      }
      
      .validation-explanation-cell {
        color: #555555;
        border-left: 1px solid #E0E0E0;
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
          border-top: 1px solid #E0E0E0;
        }
      }
      
      
      /* Main headings */
      
      .main-panel h3 {
        color: var(--theme-accent);
        font-weight: 600;
        margin-top: 3px;
        margin-bottom: 20px;
      }
      
      .main-panel h4 {
        color: var(--theme-accent);
        font-weight: 600;
        margin-top: 20px;
        margin-bottom: 12px;
      }
      
      
      /* Section titles */
      
      .content-card h3 {
        display: block;
        background-color: var(--theme-accent-light);
        color: var(--theme-accent);
        padding: 11px 15px;
        margin-top: 0;
        margin-bottom: 20px;
        border-left: 4px solid var(--theme-accent);
        border-radius: 7px;
        font-weight: 600;
      }
      
      
      /* Text */
      
      .main-panel p {
        color: #444444;
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
        background-color: #FFFFFF;
        border-color: #CCCCCC;
        color: #333333;
      }
      
      .btn-default:hover,
      .btn-default:focus {
        background-color: var(--theme-accent-light);
        border-color: var(--theme-accent);
        color: var(--theme-accent);
      }
      
      
      /* Checkboxes and radio buttons */
      
      .checkbox label,
      .radio label {
        color: #444444;
      }
      
      
      /* Data table */
      
      .dataTables_wrapper {
        background-color: #FFFFFF;
        border: 1px solid #DDDDDD;
        border-radius: 14px;
        padding: 16px;
        margin-top: 20px;
        box-shadow: 0 3px 10px rgba(70, 65, 95, 0.045);
      }
      
      
      /* Editable validation table */
      
      .dataTables_wrapper table.dataTable tbody td input {
        color: #333333 !important;
        background-color: #FFFFFF !important;
        border: 1px solid var(--theme-accent);
        border-radius: 4px;
        padding: 4px 6px;
      }
      
      
      /* Tabs */
      
      .nav-tabs {
        border-bottom: 1px solid #DDDDDD;
      }
      
      .nav-tabs > li > a {
        color: #555555;
        border-radius: 8px 8px 0 0;
        transition: background-color 0.15s ease;
      }
      
      .nav-tabs > li > a:hover {
        background-color: var(--theme-accent-light);
        border-color: #DDDDDD;
      }
      
      .nav-tabs > li.active > a,
      .nav-tabs > li.active > a:hover,
      .nav-tabs > li.active > a:focus {
        color: var(--theme-accent);
        font-weight: 600;
        border-color: #DDDDDD;
        border-bottom-color: #FFFFFF;
      }
      
      
      /* Horizontal rules */
      
      hr {
        border-top: 1px solid #DDDDDD;
        margin-top: 22px;
        margin-bottom: 22px;
      }
      
      
      /* Labels */
      
      .control-label {
        color: #444444;
      }
      
      
      /* Validation configuration content */
      
      .content-card strong {
        color: var(--theme-accent);
      }
      
      .content-card em {
        color: #555555;
      }
      
      
      /* Theme preview */
      
      .theme-preview {
        margin-top: 10px;
        margin-bottom: 20px;
        padding: 15px;
        background-color: #FFFFFF;
        border: 1px solid #DDDDDD;
        border-radius: 8px;
      }
      
      .theme-preview h5 {
        margin-top: 0;
        margin-bottom: 12px;
        font-weight: 600;
        color: var(--theme-accent);
      }
      
      .theme-preview-banner {
        padding: 14px 16px;
        border: 1px solid;
        border-radius: 6px;
        font-size: 16px;
      }
      
      .theme-preview-banner strong {
        color: var(--theme-accent);
      }
      
      .theme-preview-content {
        display: flex;
        align-items: center;
        gap: 10px;
        margin-top: 10px;
      }
      
      .theme-preview-button {
        padding: 7px 12px;
        color: #FFFFFF;
        border-radius: 4px;
        font-size: 13px;
        font-weight: 600;
      }
      
      .theme-preview-card {
        padding: 7px 12px;
        border: 1px solid;
        border-radius: 4px;
        font-size: 13px;
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
        color: #444444;
        font-weight: 600;
        margin-right: 5px;
      }
      
      .text-size-button {
        background-color: #FFFFFF;
        border: 1px solid #CCCCCC;
        color: var(--theme-accent);
        border-radius: 6px;
        padding: 4px 10px;
        cursor: pointer;
        font-size: 14px;
        line-height: 1.4;
      }
      
      .text-size-button:hover {
        background-color: var(--theme-accent-light);
        border-color: var(--theme-accent);
        color: var(--theme-accent);
      }
      
      .text-size-button:focus {
        outline: none;
        box-shadow: 0 0 0 3px rgba(0, 114, 178, 0.14);
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
    class = "validator-banner",
    h1(
      textOutput("app_title")
    )
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
        selected = "config_Default.yaml"
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