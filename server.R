library(shiny)
library(tidyverse)
library(yaml)
library(DT)
library(digest)
library(openxlsx)

# Generate secret key if needed

if (!nzchar(Sys.getenv("VALIDATOR_SECRET_KEY"))) {
  
  if (!file.exists(".Renviron")) {
    
    key <- paste0(
      sprintf("%02x", as.integer(openssl::rand_bytes(32))),
      collapse = ""
    )
    
    writeLines(
      paste0("VALIDATOR_SECRET_KEY=", key),
      ".Renviron"
    )
    
    Sys.setenv(VALIDATOR_SECRET_KEY = key)
    
  } else {
    
    stop(
      "VALIDATOR_SECRET_KEY is not set, but .Renviron already exists. ",
      "Please check your .Renviron file."
    )
  }
}

source("common.R")
source("ErrorHandler.R")

# Load default configuration

config <- yaml::read_yaml("configuration/config_Default.yaml")

secret_key <- Sys.getenv("VALIDATOR_SECRET_KEY")

if (!nzchar(secret_key)) {
  stop(
    "VALIDATOR_SECRET_KEY is not set. ",
    "The Validator cannot generate authenticated downloads."
  )
}

if (nchar(secret_key) != 64) {
  stop(
    "VALIDATOR_SECRET_KEY must be a 64-character hexadecimal key."
  )
}

# Load shared functions ------------------------------------------------------------------

source("common.R")
source("ErrorHandler.R")


# Load default configuration and key ------------------------------------------------------

config <- yaml::read_yaml("configuration/config_Default.yaml")

secret_key <- Sys.getenv("VALIDATOR_SECRET_KEY")

if (!nzchar(secret_key)) {
  stop(
    "VALIDATOR_SECRET_KEY is not set. ",
    "The Validator cannot generate authenticated downloads."
  )
}

if (nchar(secret_key) != 64) {
  stop(
    "VALIDATOR_SECRET_KEY must be a 64-character hexadecimal key."
  )
}


# Logo resource path ---------------------------------------------------------------------

addResourcePath(
  "logos",
  "logos"
)


# Server --------------------------------------------------------------------------------

server <- function(input, output, session) {
  
  # Configuration -------------------------------------------------------------------------
  
  # Selected configuration ---------------------------------------------------------------
  
  selected_config <- reactive({
    
    if (identical(input$configuration_source, "local")) {
      
      req(input$local_configuration)
      
      yaml_file_path <- input$local_configuration$datapath
      
      req(file.exists(yaml_file_path))
      
      tryCatch(
        {
          config <- yaml::yaml.load_file(
            yaml_file_path
          )
          
          if (
            !is.list(config) ||
            length(config) == 0
          ) {
            stop(
              "The YAML file does not contain a valid ShinyValidator configuration."
            )
          }
          
          config
          
        },
        error = function(e) {
          validate(
            need(
              FALSE,
              paste0(
                "Could not load the YAML configuration: ",
                e$message
              )
            )
          )
        }
      )
      
    } else {
      
      req(input$configuration)
      
      yaml::yaml.load_file(
        file.path(
          "configuration",
          input$configuration
        )
      )
    }
  })
  
  # Local configuration status
  
  output$local_configuration_status <- renderUI({
    
    req(input$local_configuration)
    
    yaml_file_path <- input$local_configuration$datapath
    
    tryCatch(
      {
        config <- yaml::yaml.load_file(
          yaml_file_path
        )
        
        if (
          !is.list(config) ||
          length(config) == 0
        ) {
          stop(
            "The file does not contain a valid configuration."
          )
        }
        
        tags$p(
          style = "color: green;",
          paste0(
            "✓ Configuration loaded: ",
            input$local_configuration$name
          )
        )
        
      },
      error = function(e) {
        
        tags$p(
          style = "color: red;",
          paste0(
            "Unable to load configuration: ",
            e$message
          )
        )
      }
    )
  })
  
  # Apply selected theme
  
  observe({
    
    current_config <- selected_config()
    theme <- current_config$theme
    
    if (is.null(theme)) {
      theme <- "blue"
    }
    
    session$sendCustomMessage(
      "set-theme",
      theme
    )
  })
  
  # Preview selected theme
  
  observeEvent(input$config_theme, {
    
    theme <- input$config_theme
    
    if (is.null(theme)) {
      theme <- "blue"
    }
    
    session$sendCustomMessage(
      "set-theme",
      theme
    )
  })
  
  # Selected configuration name
  
  selected_configuration_name <- reactive({
    
    if (identical(input$configuration_source, "local")) {
      
      req(input$local_configuration)
      
      tools::file_path_sans_ext(
        input$local_configuration$name
      )
      
    } else {
      
      req(input$configuration)
      
      configuration_name <- tools::file_path_sans_ext(
        input$configuration
      )
      
      sub(
        "^config_",
        "",
        configuration_name
      )
    }
  })
  
  # Selected specification ---------------------------------------------------------------
  
  selected_specification_path <- reactive({
    
    if (identical(input$specification_source, "local")) {
      
      req(input$local_specification)
      
      input$local_specification$datapath
      
    } else {
      
      req(input$study, input$format)
      
      file.path(
        "data_specifications",
        paste0(
          selected_configuration_name(),
          "_",
          input$study,
          "_",
          input$format,
          ".yaml"
        )
      )
    }
  })
  
  
  selected_specification <- reactive({
    
    yaml_file_path <- selected_specification_path()
    
    req(file.exists(yaml_file_path))
    
    tryCatch(
      {
        fields <- yaml::yaml.load_file(
          yaml_file_path
        )
        
        if (
          !is.list(fields) ||
          length(fields) == 0
        ) {
          stop(
            "The YAML file does not contain a valid ShinyValidator specification."
          )
        }
        
        invalid_fields <- vapply(
          fields,
          function(field) {
            !is.list(field) ||
              is.null(field$field) ||
              is.null(field$type)
          },
          logical(1)
        )
        
        if (any(invalid_fields)) {
          stop(
            "The YAML file does not contain a valid ShinyValidator specification."
          )
        }
        
        fields
        
      },
      error = function(e) {
        validate(
          need(
            FALSE,
            paste0(
              "Could not load the YAML specification: ",
              e$message
            )
          )
        )
      }
    )
  })
  
  
  # Local specification status
  
  output$local_specification_status <- renderUI({
    
    req(input$local_specification)
    
    yaml_file_path <- input$local_specification$datapath
    
    tryCatch(
      {
        fields <- yaml::yaml.load_file(
          yaml_file_path
        )
        
        if (
          !is.list(fields) ||
          length(fields) == 0
        ) {
          stop(
            "The file does not contain any specification fields."
          )
        }
        
        invalid_fields <- vapply(
          fields,
          function(field) {
            !is.list(field) ||
              is.null(field$field) ||
              is.null(field$type)
          },
          logical(1)
        )
        
        if (any(invalid_fields)) {
          stop(
            "The file does not appear to be a valid ShinyValidator specification."
          )
        }
        
        tags$p(
          style = "color: green;",
          paste0(
            "✓ Specification loaded: ",
            input$local_specification$name
          )
        )
        
      },
      error = function(e) {
        
        tags$p(
          style = "color: red;",
          paste0(
            "Unable to load specification: ",
            e$message
          )
        )
      }
    )
  })
  
  # Available specifications
  
  available_specifications <- reactive({
    
    req(selected_configuration_name())
    
    config_name <- selected_configuration_name()
    
    list.files(
      "data_specifications",
      pattern = paste0(
        "^",
        config_name,
        "_.*\\.yaml$"
      ),
      full.names = FALSE
    )
  })
  
  
  # Specification information
  
  specification_info <- reactive({
    
    files <- available_specifications()
    
    tibble(
      file = files,
      study = sub(
        "^[^_]+_([^_]+)_.*\\.yaml$",
        "\\1",
        files
      ),
      format = sub(
        "^[^_]+_[^_]+_(.*)\\.yaml$",
        "\\1",
        files
      )
    )
  })
  
  
  # Study selection ----------------------------------------------------------------------
  
  output$study_selection <- renderUI({
    
    info <- specification_info()
    
    studies_available <- unique(info$study)
    
    if (length(studies_available) == 0) {
      
      div(
        class = "no-specifications",
        
        strong("No specifications available"),
        
        p(
          "No data specifications have been created for this configuration."
        )
      )
      
    } else {
      
      selectInput(
        "study",
        h4("Study"),
        choices = studies_available
      )
    }
  })
  
  
  # Reset study when configuration changes
  
  observeEvent(
    selected_configuration_name(),
    {
      info <- specification_info()
      
      studies_available <- unique(info$study)
      
      updateSelectInput(
        session,
        "study",
        choices = studies_available,
        selected = if (length(studies_available) > 0) {
          studies_available[1]
        } else {
          NULL
        }
      )
    },
    ignoreInit = FALSE
  )
  
  
  # Study format
  
  output$study_format <- renderUI({
    
    req(input$study)
    
    info <- specification_info()
    
    available_formats <- info |>
      filter(study == input$study) |>
      pull(format)
    
    selectInput(
      "format",
      label = h4("Study Format"),
      choices = available_formats
    )
  })
  
  
  # Reset format when study changes
  
  observeEvent(
    input$study,
    {
      info <- specification_info()
      
      formats_available <- info |>
        filter(study == input$study) |>
        pull(format) |>
        unique()
      
      updateSelectInput(
        session,
        "format",
        choices = formats_available,
        selected = if (length(formats_available) > 0) {
          formats_available[1]
        } else {
          NULL
        }
      )
    },
    ignoreInit = FALSE
  )
  
  
  # Configuration-driven UI --------------------------------------------------------------
  
  # Application title
  
  output$app_title <- renderText({
    
    current_config <- selected_config()
    
    current_config$app_title
  })
  
  # Specification message
  
  output$specification_message <- renderUI({
    
    current_config <- selected_config()
    
    p(
      current_config$specification_message
    )
  })
  
  
  # Validation Results configuration content
  
  output$validation_config_content <- renderUI({
    
    current_config <- selected_config()
    
    # Get instruction set names
    
    instruction_set_1_name <- if (
      !is.null(current_config$instruction_set_1_name) &&
      nzchar(current_config$instruction_set_1_name)
    ) {
      current_config$instruction_set_1_name
    } else {
      "Instruction Set 1"
    }
    
    instruction_set_2_name <- if (
      !is.null(current_config$instruction_set_2_name) &&
      nzchar(current_config$instruction_set_2_name)
    ) {
      current_config$instruction_set_2_name
    } else {
      "Instruction Set 2"
    }
    
    tagList(
      
      h3("Validation Results"),
      
      if (
        !is.null(current_config$welcome_message) &&
        nzchar(current_config$welcome_message)
      ) {
        p(
          strong(current_config$welcome_message)
        )
      },
      
      if (
        !is.null(current_config$secondary_message) &&
        nzchar(current_config$secondary_message)
      ) {
        p(
          em(current_config$secondary_message)
        )
      },
      
      fluidRow(
        
        
        # Instruction Sets
        
        column(
          width = 8,
          
          if (
            !is.null(current_config$instruction_set_1) &&
            length(current_config$instruction_set_1) > 0
          ) {
            tagList(
              h4(instruction_set_1_name),
              
              lapply(
                current_config$instruction_set_1,
                function(x) p(x)
              )
            )
          },
          
          if (
            !is.null(current_config$instruction_set_2) &&
            length(current_config$instruction_set_2) > 0
          ) {
            tagList(
              h4(instruction_set_2_name),
              
              lapply(
                current_config$instruction_set_2,
                function(x) p(x)
              )
            )
          }
        ),
        
        
        # Links
        
        column(
          width = 4,
          
          if (
            !is.null(current_config$links) &&
            length(current_config$links) > 0
          ) {
            tagList(
              h4("Links"),
              
              lapply(
                current_config$links,
                function(link) {
                  tags$p(
                    tags$a(
                      href = link$url,
                      link$text,
                      target = "_blank"
                    )
                  )
                }
              )
            )
          }
        )
      )
    )
  })
  
  
  # Configuration Creation content
  
  output$configuration_creation_content <- renderUI({
    
    current_config <- selected_config()
    
    # Get instruction set names
    
    instruction_set_1_name <- if (
      !is.null(current_config$instruction_set_1_name) &&
      nzchar(current_config$instruction_set_1_name)
    ) {
      current_config$instruction_set_1_name
    } else {
      "Instruction Set 1"
    }
    
    instruction_set_2_name <- if (
      !is.null(current_config$instruction_set_2_name) &&
      nzchar(current_config$instruction_set_2_name)
    ) {
      current_config$instruction_set_2_name
    } else {
      "Instruction Set 2"
    }
    
    tagList(
      
      h3("Configuration Creation"),
      
      h4("Create your configuration"),
      
      selectInput(
        "config_theme",
        "Application Theme:",
        choices = c(
          "Blue" = "blue",
          "Purple" = "purple",
          "Teal" = "teal"
        ),
        selected = "blue"
      ),
      
      uiOutput("theme_preview"),
      
      p(
        "Customize the text and links used by your ShinyValidator. ",
        "The fields below are pre-populated with the current configuration."
      ),
      
      
      fluidRow(
        
        column(
          width = 6,
          
          # Application title
          
          h4("Application Title"),
          
          textInput(
            "config_app_title",
            "Application title:",
            value = current_config$app_title
          )
        ),
        
        column(
          width = 6,
        )
      ),
      
      # Welcome message
      
      checkboxInput(
        "enable_welcome_message",
        "Enable welcome message",
        value = !is.null(current_config$welcome_message) &&
          nzchar(current_config$welcome_message)
      ),
      
      conditionalPanel(
        condition = "input.enable_welcome_message",
        
        textAreaInput(
          "config_welcome_message",
          "Welcome message:",
          value = if (
            is.null(current_config$welcome_message)
          ) {
            ""
          } else {
            current_config$welcome_message
          },
          rows = 3
        )
      ),
      
      
      # Secondary message
      
      checkboxInput(
        "enable_secondary_message",
        "Enable secondary message",
        value = !is.null(current_config$secondary_message) &&
          nzchar(current_config$secondary_message)
      ),
      
      conditionalPanel(
        condition = "input.enable_secondary_message",
        
        textAreaInput(
          "config_secondary_message",
          "Secondary message:",
          value = if (
            is.null(current_config$secondary_message)
          ) {
            ""
          } else {
            current_config$secondary_message
          },
          rows = 3
        )
      ),
      
      br(),
      
      
      # Instruction Sets and Links
      
      fluidRow(
        
        
        # Instruction Set 1
        
        column(
          width = 4,
          
          h4("Instruction Set 1"),
          
          textInput(
            "config_instruction_set_1_name",
            "Section name:",
            value = instruction_set_1_name
          ),
          
          checkboxInput(
            "enable_instruction_set_1",
            "Enable instruction set",
            value = !is.null(current_config$instruction_set_1) &&
              length(current_config$instruction_set_1) > 0
          ),
          
          conditionalPanel(
            condition = "input.enable_instruction_set_1",
            
            numericInput(
              "num_instruction_lines",
              "Number of instruction lines:",
              value = if (
                is.null(current_config$instruction_set_1)
              ) {
                1
              } else {
                length(unlist(current_config$instruction_set_1))
              },
              min = 1,
              max = 20
            ),
            
            uiOutput("instruction_fields")
          )
        ),
        
        
        # Instruction Set 2
        
        column(
          width = 4,
          
          h4("Instruction Set 2"),
          
          textInput(
            "config_instruction_set_2_name",
            "Section name:",
            value = instruction_set_2_name
          ),
          
          checkboxInput(
            "enable_instruction_set_2",
            "Enable instruction set",
            value = !is.null(current_config$instruction_set_2) &&
              length(current_config$instruction_set_2) > 0
          ),
          
          conditionalPanel(
            condition = "input.enable_instruction_set_2",
            
            numericInput(
              "num_upload_instruction_lines",
              "Number of instruction lines:",
              value = if (
                is.null(current_config$instruction_set_2)
              ) {
                1
              } else {
                length(unlist(current_config$instruction_set_2))
              },
              min = 1,
              max = 20
            ),
            
            uiOutput("upload_instruction_fields")
          )
        ),
        
        
        # Links
        
        column(
          width = 4,
          
          h4("Links"),
          
          checkboxInput(
            "enable_links",
            "Enable Links",
            value = !is.null(current_config$links) &&
              length(current_config$links) > 0
          ),
          
          conditionalPanel(
            condition = "input.enable_links",
            
            numericInput(
              "num_links",
              "Number of links:",
              value = if (
                is.null(current_config$links)
              ) {
                1
              } else {
                length(current_config$links)
              },
              min = 1,
              max = 20
            ),
            
            uiOutput("link_fields")
          )
        )
      ),
      
      br(),
      
      downloadButton(
        "downloadConfiguration",
        "Download Configuration"
      )
    )
  })
  
  
  # Theme preview
  
  output$theme_preview <- renderUI({
    
    theme <- input$config_theme
    
    if (is.null(theme)) {
      theme <- "blue"
    }
    
    theme_info <- switch(
      theme,
      
      blue = list(
        name = "Blue",
        banner = "#DCEEF7",
        accent = "#0072B2",
        light = "#E6F2F8",
        border = "#C7DDE8"
      ),
      
      purple = list(
        name = "Purple",
        banner = "#E8DDF1",
        accent = "#6A3D9A",
        light = "#F0EAF6",
        border = "#D8CBE2"
      ),
      
      teal = list(
        name = "Teal",
        banner = "#D7EEEE",
        accent = "#007C83",
        light = "#E4F3F3",
        border = "#C5DEDF"
      )
    )
    
    div(
      class = "theme-preview",
      
      h5("Theme Preview"),
      
      div(
        class = "theme-preview-banner",
        style = paste0(
          "background: linear-gradient(135deg, ",
          theme_info$banner,
          ", ",
          theme_info$light,
          "); ",
          "border-color: ",
          theme_info$border,
          ";"
        ),
        strong("Your Validator")
      ),
      
      div(
        class = "theme-preview-content",
        
        div(
          class = "theme-preview-button",
          style = paste0(
            "background-color: ",
            theme_info$accent,
            ";"
          ),
          "Example Button"
        ),
        
        div(
          class = "theme-preview-card",
          style = paste0(
            "background-color: ",
            theme_info$light,
            "; ",
            "border-color: ",
            theme_info$border,
            ";"
          ),
          paste0(
            theme_info$name,
            " theme"
          )
        )
      )
    )
  })
  
  
  # Configuration creation dynamic fields -----------------------------------------------
  
  # Instruction Set 1 fields
  
  output$instruction_fields <- renderUI({
    
    n <- input$num_instruction_lines
    
    if (
      is.null(n) ||
      is.na(n) ||
      n < 1
    ) {
      return(NULL)
    }
    
    current_config <- selected_config()
    
    existing_instructions <- current_config$instruction_set_1
    
    lapply(
      seq_len(n),
      function(i) {
        
        existing_value <- ""
        
        if (
          !is.null(existing_instructions) &&
          length(existing_instructions) >= i
        ) {
          existing_value <- existing_instructions[[i]]
        }
        
        textAreaInput(
          paste0("config_instruction_", i),
          paste0("Instruction ", i, ":"),
          value = existing_value,
          rows = 2
        )
      }
    )
  })
  
  
  # Instruction Set 2 fields
  
  output$upload_instruction_fields <- renderUI({
    
    n <- input$num_upload_instruction_lines
    
    if (
      is.null(n) ||
      is.na(n) ||
      n < 1
    ) {
      return(NULL)
    }
    
    current_config <- selected_config()
    
    existing_instructions <- current_config$instruction_set_2
    
    lapply(
      seq_len(n),
      function(i) {
        
        existing_value <- ""
        
        if (
          !is.null(existing_instructions) &&
          length(existing_instructions) >= i
        ) {
          existing_value <- existing_instructions[[i]]
        }
        
        textAreaInput(
          paste0("config_upload_instruction_", i),
          paste0("Instruction ", i, ":"),
          value = existing_value,
          rows = 2
        )
      }
    )
  })
  
  
  # Link fields
  
  output$link_fields <- renderUI({
    
    n <- input$num_links
    
    if (
      is.null(n) ||
      is.na(n) ||
      n < 1
    ) {
      return(NULL)
    }
    
    current_config <- selected_config()
    
    existing_links <- current_config$links
    
    lapply(
      seq_len(n),
      function(i) {
        
        existing_text <- ""
        existing_url <- ""
        
        if (
          !is.null(existing_links) &&
          length(existing_links) >= i
        ) {
          
          existing_link <- existing_links[[i]]
          
          if (!is.null(existing_link$text)) {
            existing_text <- existing_link$text
          }
          
          if (!is.null(existing_link$url)) {
            existing_url <- existing_link$url
          }
        }
        
        tagList(
          
          textInput(
            paste0("config_link_text_", i),
            paste0("Link ", i, " text:"),
            value = existing_text
          ),
          
          textInput(
            paste0("config_link_url_", i),
            paste0("Link ", i, " URL:"),
            value = existing_url
          ),
          
          if (i < n) {
            hr()
          }
        )
      }
    )
  })
  
  
  
  # Validation ---------------------------------------------------------------------------
  
  # Specification
  
  output$specification <- renderUI({
    
    fields <- selected_specification()
    
    type_labels <- c(
      options = "Options",
      numeric = "Numeric",
      string = "Text"
    )
    
    tagList(
      lapply(fields, function(field) {
        
        field_name <- field$field
        
        field_type <- if (!is.null(field$type)) {
          type_labels[[field$type]]
        } else {
          "Not specified"
        }
        
        required_text <- if (isTRUE(field$required)) {
          "Yes"
        } else {
          "No"
        }
        
        na_text <- if (isTRUE(field$NA_allowed)) {
          "Yes"
        } else {
          "No"
        }
        
        empty_text <- if (isTRUE(field$empty_allowed)) {
          "Yes"
        } else {
          "No"
        }
        
        requirements <- list()
        
        requirements[[length(requirements) + 1]] <- tags$li(
          tags$strong("Column Required: "),
          required_text
        )
        
        requirements[[length(requirements) + 1]] <- tags$li(
          tags$strong("Data type: "),
          field_type
        )
        
        requirements[[length(requirements) + 1]] <- tags$li(
          tags$strong("NA values allowed: "),
          na_text
        )
        
        requirements[[length(requirements) + 1]] <- tags$li(
          tags$strong("Empty cells allowed: "),
          empty_text
        )
        
        
        # Options
        
        if (field$type == "options") {
          
          options <- field$options
          
          if (is.list(options)) {
            options <- unlist(
              options,
              use.names = FALSE
            )
          }
          
          options <- as.character(options)
          
          requirements[[length(requirements) + 1]] <- tags$li(
            tags$strong("Allowed values: "),
            paste(options, collapse = ", ")
          )
        }
        
        
        # Numeric
        
        if (field$type == "numeric") {
          
          if (
            !is.null(field$format) &&
            field$format == "restricted"
          ) {
            
            requirements[[length(requirements) + 1]] <- tags$li(
              tags$strong("Allowed range: "),
              paste0(
                field$lowerlimit,
                " to ",
                field$upperlimit
              )
            )
          }
          
          if (
            !is.null(field$allow_decimals) &&
            field$allow_decimals == "no"
          ) {
            
            requirements[[length(requirements) + 1]] <- tags$li(
              tags$strong("Decimal values: "),
              "Not allowed"
            )
            
          } else if (
            !is.null(field$allow_decimals) &&
            field$allow_decimals == "yes"
          ) {
            
            min_decimals <- field$min_decimals
            max_decimals <- field$max_decimals
            
            decimal_text <- if (
              min_decimals == max_decimals
            ) {
              paste0(
                min_decimals,
                " decimal place",
                if (min_decimals != 1) "s" else ""
              )
            } else {
              paste0(
                min_decimals,
                "–",
                max_decimals,
                " decimal places"
              )
            }
            
            requirements[[length(requirements) + 1]] <- tags$li(
              tags$strong("Decimal places: "),
              decimal_text
            )
          }
        }
        
        
        # String
        
        if (field$type == "string") {
          
          validation_text <- switch(
            field$format,
            uncapitalized = "Lowercase only",
            capitalized = "Uppercase only",
            regex = "Must match the specified pattern",
            open = "Open text",
            field$format
          )
          
          requirements[[length(requirements) + 1]] <- tags$li(
            tags$strong("Text format: "),
            validation_text
          )
          
          if (
            !is.null(field$pattern) &&
            !is.na(field$pattern)
          ) {
            
            requirements[[length(requirements) + 1]] <- tags$li(
              tags$strong("Pattern: "),
              tags$code(field$pattern)
            )
          }
          
          if (
            !is.null(field$lowerlimit) &&
            !is.na(field$lowerlimit)
          ) {
            
            requirements[[length(requirements) + 1]] <- tags$li(
              tags$strong("Minimum length: "),
              field$lowerlimit
            )
          }
          
          if (
            !is.null(field$upperlimit) &&
            !is.na(field$upperlimit)
          ) {
            
            requirements[[length(requirements) + 1]] <- tags$li(
              tags$strong("Maximum length: "),
              field$upperlimit
            )
          }
        }
        
        
        tags$div(
          style = paste(
            "border: 1px solid #ddd;",
            "border-radius: 5px;",
            "padding: 15px;",
            "margin-bottom: 15px;",
            "background-color: #f9f9f9;"
          ),
          
          h4(
            style = "margin-top: 0;",
            field_name
          ),
          
          if (
            !is.null(field$description) &&
            !is.na(field$description) &&
            field$description != ""
          ) {
            tags$p(
              tags$em(field$description)
            )
          },
          
          tags$ul(requirements)
        )
      })
    )
  })
  
  # Download codebook --------------------------------------------------------------------
  
  output$downloadCodebook <- downloadHandler(
    
    filename = function() {
      
      if (identical(input$specification_source, "local")) {
        
        specification_name <- tools::file_path_sans_ext(
          input$local_specification$name
        )
        
      } else {
        
        specification_name <- paste(
          input$study,
          input$format,
          sep = "_"
        )
      }
      
      paste0(
        specification_name,
        "_codebook.xlsx"
      )
    },
    
    content = function(file) {
      
      fields <- selected_specification()
      
      
      ## Translate validation rules into human-readable text
      
      translate_requirements <- function(field) {
        
        requirements <- character(0)
        
        
        ## Data type
        
        if (!is.null(field$type)) {
          
          if (identical(field$type, "options")) {
            
            if (!is.null(field$options)) {
              
              options <- paste(
                as.character(field$options),
                collapse = ", "
              )
              
              requirements <- c(
                requirements,
                paste0(
                  "Must be one of: ",
                  options,
                  "."
                )
              )
            }
            
          } else if (identical(field$type, "numeric")) {
            
            ## Numeric range
            
            if (
              !is.null(field$lower) &&
              !is.null(field$upper)
            ) {
              
              requirements <- c(
                requirements,
                paste0(
                  "Must be between ",
                  field$lower,
                  " and ",
                  field$upper,
                  "."
                )
              )
              
            } else if (!is.null(field$lower)) {
              
              requirements <- c(
                requirements,
                paste0(
                  "Must be at least ",
                  field$lower,
                  "."
                )
              )
              
            } else if (!is.null(field$upper)) {
              
              requirements <- c(
                requirements,
                paste0(
                  "Must be no greater than ",
                  field$upper,
                  "."
                )
              )
            }
            
            
            ## Decimal requirements
            
            if (
              !is.null(field$allow_decimals) &&
              identical(
                tolower(as.character(field$allow_decimals)),
                "no"
              )
            ) {
              
              requirements <- c(
                requirements,
                "Whole numbers only."
              )
              
            } else if (
              !is.null(field$min_decimals) &&
              !is.null(field$max_decimals) &&
              identical(
                as.character(field$min_decimals),
                as.character(field$max_decimals)
              )
            ) {
              
              requirements <- c(
                requirements,
                paste0(
                  "Must have exactly ",
                  field$min_decimals,
                  " decimal places."
                )
              )
              
            } else if (!is.null(field$max_decimals)) {
              
              requirements <- c(
                requirements,
                paste0(
                  "May have up to ",
                  field$max_decimals,
                  " decimal places."
                )
              )
              
            } else if (!is.null(field$min_decimals)) {
              
              requirements <- c(
                requirements,
                paste0(
                  "Must have at least ",
                  field$min_decimals,
                  " decimal places."
                )
              )
            }
          }
          
          
          ## String requirements
          
          if (identical(field$type, "string")) {
            
            requirements <- c(
              requirements,
              "Text."
            )
          }
        }
        
        
        ## Regular expression
        
        if (!is.null(field$pattern)) {
          
          pattern <- as.character(field$pattern)
          
          if (identical(pattern, "^[A-Za-z0-9]+$")) {
            
            requirements <- c(
              requirements,
              "Letters and numbers only."
            )
            
          } else if (
            identical(pattern, "^[A-Za-z]+$")
          ) {
            
            requirements <- c(
              requirements,
              "Letters only."
            )
            
          } else if (
            identical(pattern, "^[0-9]+$")
          ) {
            
            requirements <- c(
              requirements,
              "Numbers only."
            )
            
          } else {
            
            requirements <- c(
              requirements,
              paste0(
                "Must match the required format: ",
                pattern,
                "."
              )
            )
          }
        }
        
        
        ## Empty values
        
        if (!is.null(field$empty_allowed)) {
          
          empty_allowed <- tolower(
            as.character(field$empty_allowed)
          )
          
          if (empty_allowed %in% c("no", "false")) {
            
            requirements <- c(
              requirements,
              "Empty values are not allowed."
            )
            
          } else if (
            empty_allowed %in% c("yes", "true")
          ) {
            
            requirements <- c(
              requirements,
              "Empty values are allowed."
            )
          }
        }
        
        
        ## Combine requirements
        
        if (length(requirements) == 0) {
          
          return("")
        }
        
        paste(
          requirements,
          collapse = " "
        )
      }
      
      
      ## Create human-readable codebook
      
      codebook <- purrr::map_dfr(
        fields,
        function(field) {
          
          data.frame(
            
            Variable = ifelse(
              is.null(field$field),
              "",
              as.character(field$field)
            ),
            
            `Validation requirements` = translate_requirements(
              field
            ),
            
            Description = ifelse(
              is.null(field$description),
              "",
              as.character(field$description)
            ),
            
            stringsAsFactors = FALSE,
            
            check.names = FALSE
          )
        }
      )
      
      
      ## Write codebook
      
      openxlsx::write.xlsx(
        codebook,
        file,
        overwrite = TRUE
      )
    }
  )
  
  # Specification creation ---------------------------------------------------------------
  
  # Creating from template
  
  template_columns <- reactiveVal(NULL)
  
  observeEvent(input$template_file, {
    req(input$template_file)
    
    template <- readr::read_csv(
      input$template_file$datapath,
      n_max = 0,
      show_col_types = FALSE
    )
    
    columns <- names(template)
    
    template_columns(columns)
    
    updateNumericInput(
      session,
      "numVars",
      value = length(columns)
    )
  })
  
  
  
  # User-created specification
  
  userData <- reactive({
    
    ids <- variable_ids()
    data_list <- list()
    
    # Validate variable names ------------------------------------------------------------
    
    variable_names <- vapply(
      ids,
      function(i) {
        
        value <- input[[paste0("field_name_", i)]]
        
        if (is.null(value)) {
          ""
        } else {
          trimws(value)
        }
      },
      character(1)
    )
    
    if (any(variable_names == "")) {
      stop(
        "Every variable must have a name."
      )
    }
    
    if (any(duplicated(variable_names))) {
      stop(
        "Variable names must be unique."
      )
    }
    
    if (length(ids) > 0) {
      
      for (i in ids) {
        
        field_type <- input[[paste0("field_type_", i)]]
        
        if (field_type == "numeric") {
          
          lowerlimit <- ifelse(
            input[[paste0("range_req_", i)]] == "yes",
            input[[paste0("min_value_", i)]],
            NA
          )
          
          upperlimit <- ifelse(
            input[[paste0("range_req_", i)]] == "yes",
            input[[paste0("max_value_", i)]],
            NA
          )
          
        } else {
          
          lowerlimit <- ifelse(
            field_type == "string" &&
              input[[paste0("range_req_string", i)]] == "yes",
            input[[paste0("min_value_s", i)]],
            NA
          )
          
          upperlimit <- ifelse(
            field_type == "string" &&
              input[[paste0("range_req_string", i)]] == "yes",
            input[[paste0("max_value_s", i)]],
            NA
          )
        }
        
        options <- character(0)
        
        if (field_type == "options") {
          
          n_options <- input[[paste0("num_options_", i)]]
          
          if (!is.null(n_options) && !is.na(n_options)) {
            
            for (j in seq_len(n_options)) {
              
              option_value <- input[[paste0("option_", j, "_", i)]]
              
              if (
                !is.null(option_value) &&
                !is.na(option_value) &&
                option_value != ""
              ) {
                
                options <- c(
                  options,
                  option_value
                )
              }
            }
          }
        }
        
        format <- if (
          field_type == "numeric" &&
          input[[paste0("range_req_", i)]] == "yes"
        ) {
          
          "restricted"
          
        } else if (field_type == "string") {
          
          validation <- input[[paste0("string_validation_", i)]]
          
          if (
            validation %in% c(
              "letters",
              "numbers",
              "alphanumeric",
              "examples"
            )
          ) {
            "regex"
          } else {
            validation
          }
          
        } else {
          "open"
        }
        
        pattern <- if (field_type == "string") {
          
          validation <- input[[paste0("string_validation_", i)]]
          
          if (validation == "letters") {
            
            "^[A-Za-z]+$"
            
          } else if (validation == "numbers") {
            
            "^[0-9]+$"
            
          } else if (validation == "alphanumeric") {
            
            "^[A-Za-z0-9]+$"
            
          } else if (validation == "examples") {
            
            examples <- c(
              input[[paste0("example_1_", i)]],
              input[[paste0("example_2_", i)]],
              input[[paste0("example_3_", i)]],
              input[[paste0("example_4_", i)]],
              input[[paste0("example_5_", i)]]
            )
            
            GenerateRegex(examples)
            
          } else {
            NA
          }
          
        } else {
          NA
        }
        
        required <- if (
          input[[paste0("is_required_", i)]] == "yes"
        ) {
          TRUE
        } else {
          FALSE
        }
        
        NA_allowed <- if (
          input[[paste0("allow_na_", i)]] == "yes"
        ) {
          TRUE
        } else {
          FALSE
        }
        
        empty_allowed <- if (
          input[[paste0("allow_empty_", i)]] == "yes"
        ) {
          TRUE
        } else {
          FALSE
        }
        
        data_list[[length(data_list) + 1]] <- list(
          field = input[[paste0("field_name_", i)]],
          description = input[[paste0("field_description_", i)]],
          type = field_type,
          options = options,
          format = format,
          pattern = pattern,
          lowerlimit = lowerlimit,
          upperlimit = upperlimit,
          allow_decimals = if (field_type == "numeric") {
            input[[paste0("allow_decimals_", i)]]
          } else {
            NA
          },
          min_decimals = if (
            field_type == "numeric" &&
            input[[paste0("allow_decimals_", i)]] == "yes"
          ) {
            as.numeric(input[[paste0("min_decimals_", i)]])
          } else {
            NA
          },
          max_decimals = if (
            field_type == "numeric" &&
            input[[paste0("allow_decimals_", i)]] == "yes"
          ) {
            as.numeric(input[[paste0("max_decimals_", i)]])
          } else {
            NA
          },
          required = required,
          NA_allowed = NA_allowed,
          empty_allowed = empty_allowed,
          error_message = toString(
            input[[paste0("error_message_", i)]]
          )
        )
      }
    }
    
    data_list
  })
  
  
  # Create variable tabs ---------------------------------------------------------------
  
  # Store the internal IDs of currently active variables
  
  variable_ids <- reactiveVal(integer(0))
  
  # Keep track of the next available internal ID
  
  next_variable_id <- reactiveVal(1)
  
  
  createVariableTab <- function(i, display_number = i) {
    
    tabPanel(
      
      actionButton(
        paste0("delete_variable_", i),
        "Delete Variable",
        class = "btn-danger"
      ),
      
      br(),
      
      title = tags$span(
        id = paste0("tab_label_", i),
        if (
          !is.null(template_columns()) &&
          length(template_columns()) >= display_number
        ) {
          template_columns()[display_number]
        } else {
          paste("Variable", display_number)
        }
      ),
      
      value = paste0("variable_", i),
      
      br(),
      
      fluidRow(
        
        column(
          width = 4,
          
          h4("Variable Information"),
          
          textInput(
            paste0("field_name_", i),
            "Variable/column name:",
            value = if (
              !is.null(template_columns()) &&
              length(template_columns()) >= display_number
            ) {
              template_columns()[display_number]
            } else {
              ""
            }
          ),
          
          textInput(
            paste0("field_description_", i),
            "Description:"
          ),
          
          br(),
          
          h4("General Settings"),
          
          selectInput(
            paste0("is_required_", i),
            "Is this variable required? (Selecting 'No' means the validator will not flag the dataset as invalid if this column is missing)",
            choices = c(
              "Yes" = "yes",
              "No" = "no"
            )
          ),
          
          selectInput(
            paste0("allow_na_", i),
            "Are NA values allowed?",
            choices = c(
              "Yes" = "yes",
              "No" = "no"
            ),
            selected = "no"
          ),
          
          selectInput(
            paste0("allow_empty_", i),
            "Are empty cells allowed?",
            choices = c(
              "Yes" = "yes",
              "No" = "no"
            ),
            selected = "no"
          )
        ),
        
        column(
          width = 4,
          
          h4("Data Type"),
          
          selectInput(
            paste0("field_type_", i),
            "Choose your data type:",
            choices = c(
              "Options" = "options",
              "Numeric" = "numeric",
              "String" = "string"
            )
          )
        ),
        
        column(
          width = 4,
          
          # Numeric
          
          conditionalPanel(
            condition = paste0(
              "input.field_type_", i,
              " == 'numeric'"
            ),
            
            h4("Numeric Settings"),
            
            selectInput(
              paste0("range_req_", i),
              "Are there range restrictions?",
              choices = c(
                "No" = "no",
                "Yes" = "yes"
              )
            ),
            
            conditionalPanel(
              condition = paste0(
                "input.range_req_", i,
                " == 'yes'"
              ),
              
              fluidRow(
                
                column(
                  width = 6,
                  numericInput(
                    paste0("min_value_", i),
                    "Minimum:",
                    value = NA
                  )
                ),
                
                column(
                  width = 6,
                  numericInput(
                    paste0("max_value_", i),
                    "Maximum:",
                    value = NA
                  )
                )
              )
            ),
            
            selectInput(
              paste0("allow_decimals_", i),
              "Are decimals allowed?",
              choices = c(
                "No" = "no",
                "Yes" = "yes"
              ),
              selected = "no"
            ),
            
            conditionalPanel(
              condition = paste0(
                "input.allow_decimals_", i,
                " == 'yes'"
              ),
              
              h5("Decimal Places"),
              
              fluidRow(
                
                column(
                  width = 6,
                  selectInput(
                    paste0("min_decimals_", i),
                    "Minimum:",
                    choices = 0:6,
                    selected = 0
                  )
                ),
                
                column(
                  width = 6,
                  selectInput(
                    paste0("max_decimals_", i),
                    "Maximum:",
                    choices = 0:6,
                    selected = 6
                  )
                )
              )
            )
          ),
          
          
          # Options
          
          conditionalPanel(
            condition = paste0(
              "input.field_type_", i,
              " == 'options'"
            ),
            
            h4("Option Settings"),
            
            selectInput(
              paste0("num_options_", i),
              "How many options are allowed?",
              choices = 1:20,
              selected = 2
            ),
            
            uiOutput(
              paste0("option_fields_", i)
            )
          ),
          
          
          # String
          
          conditionalPanel(
            condition = paste0(
              "input.field_type_", i,
              " == 'string'"
            ),
            
            h4("String Settings"),
            
            selectInput(
              paste0("string_validation_", i),
              "String validation:",
              choices = c(
                "Open text" = "open",
                "Lowercase only" = "uncapitalized",
                "Uppercase only" = "capitalized",
                "Letters only" = "letters",
                "Numbers only" = "numbers",
                "Letters and numbers" = "alphanumeric",
                "Match example values" = "examples"
              )
            ),
            
            conditionalPanel(
              condition = paste0(
                "input.string_validation_", i,
                " == 'examples'"
              ),
              
              textInput(
                paste0("example_1_", i),
                "Example value 1:"
              ),
              
              textInput(
                paste0("example_2_", i),
                "Example value 2:"
              ),
              
              textInput(
                paste0("example_3_", i),
                "Example value 3:"
              ),
              
              textInput(
                paste0("example_4_", i),
                "Example value 4:"
              ),
              
              textInput(
                paste0("example_5_", i),
                "Example value 5:"
              ),
              
              helpText(
                "Enter five examples of valid values."
              ),
              
              uiOutput(
                paste0("example_validation_", i)
              )
            ),
            
            br(),
            
            selectInput(
              paste0("range_req_string", i),
              "Are there length restrictions?",
              choices = c(
                "No" = "no",
                "Yes" = "yes"
              )
            ),
            
            conditionalPanel(
              condition = paste0(
                "input.range_req_string", i,
                " == 'yes'"
              ),
              
              fluidRow(
                
                column(
                  width = 6,
                  numericInput(
                    paste0("min_value_s", i),
                    "Minimum:",
                    value = NA
                  )
                ),
                
                column(
                  width = 6,
                  numericInput(
                    paste0("max_value_s", i),
                    "Maximum:",
                    value = NA
                  )
                )
              )
            )
          )
        )
      ),
      
      fluidRow(
        
        column(
          width = 12,
          
          br(),
          
          h4("Error Message"),
          
          textInput(
            paste0("error_message_", i),
            "Enter an error message for your data:"
          )
        )
      )
    )
  }
  
  
  # Manage variable tabs
  
  observeEvent(input$numVars, {
    
    new_num_vars <- input$numVars
    
    if (
      is.null(new_num_vars) ||
      is.na(new_num_vars)
    ) {
      return()
    }
    
    current_ids <- variable_ids()
    current_count <- length(current_ids)
    
    # Add variables
    
    if (new_num_vars > current_count) {
      
      number_to_add <- new_num_vars - current_count
      
      new_ids <- integer(number_to_add)
      
      for (j in seq_len(number_to_add)) {
        
        new_ids[j] <- next_variable_id()
        
        next_variable_id(
          next_variable_id() + 1
        )
      }
      
      updated_ids <- c(
        current_ids,
        new_ids
      )
      
      variable_ids(updated_ids)
      
      for (j in seq_along(new_ids)) {
        
        insertTab(
          inputId = "variable_tabs",
          tab = createVariableTab(
            new_ids[j],
            display_number = current_count + j
          ),
          target = NULL,
          position = "after",
          select = TRUE
        )
      }
    }
    
    
    # Remove variables from the end only when the
    # numeric input itself is manually decreased
    
    if (new_num_vars < current_count) {
      
      ids_to_remove <- current_ids[
        seq(
          new_num_vars + 1,
          current_count
        )
      ]
      
      for (id in ids_to_remove) {
        
        removeTab(
          inputId = "variable_tabs",
          target = paste0(
            "variable_",
            id
          )
        )
      }
      
      variable_ids(
        current_ids[
          seq_len(new_num_vars)
        ]
      )
    }
  })
  
  
  # Delete variable button observer
  
  observe({
    
    ids <- variable_ids()
    
    if (length(ids) == 0) {
      return()
    }
    
    for (position in seq_along(ids)) {
      
      local({
        
        j <- position
        variable_id <- ids[j]
        
        observeEvent(
          input[[paste0(
            "delete_variable_",
            variable_id
          )]],
          {
            
            current_ids <- variable_ids()
            
            delete_position <- match(
              variable_id,
              current_ids
            )
            
            if (is.na(delete_position)) {
              return()
            }
            
            # Remove the selected tab
            
            removeTab(
              inputId = "variable_tabs",
              target = paste0(
                "variable_",
                variable_id
              )
            )
            
            # Remove the selected ID
            
            updated_ids <- current_ids[
              -delete_position
            ]
            
            variable_ids(
              updated_ids
            )
            
            # Update the number displayed in the UI
            
            updateNumericInput(
              session,
              "numVars",
              value = length(updated_ids)
            )
            
          },
          ignoreInit = TRUE
        )
      })
    }
  })
  
  # Generate option inputs
  
  observe({
    
    ids <- variable_ids()
    
    if (length(ids) == 0) {
      return()
    }
    
    for (i in ids) {
      
      local({
        
        j <- i
        
        output[[paste0("option_fields_", j)]] <- renderUI({
          
          n_options <- input[[paste0("num_options_", j)]]
          
          if (is.null(n_options) || is.na(n_options)) {
            return(NULL)
          }
          
          lapply(seq_len(n_options), function(k) {
            
            textInput(
              paste0("option_", k, "_", j),
              paste0("Option ", k, ":"),
              value = input[[paste0("option_", k, "_", j)]]
            )
          })
        })
      })
    }
  })
  
  # Validate example inputs
  
  observe({
    
    ids <- variable_ids()
    
    if (length(ids) > 0) {
      
      for (i in ids) {
        
        local({
          
          j <- i
          
          output[[paste0("example_validation_", j)]] <- renderUI({
            
            validation <- input[[paste0(
              "string_validation_",
              j
            )]]
            
            if (
              is.null(validation) ||
              is.na(validation) ||
              validation != "examples"
            ) {
              return(NULL)
            }
            
            examples <- c(
              input[[paste0("example_1_", j)]],
              input[[paste0("example_2_", j)]],
              input[[paste0("example_3_", j)]],
              input[[paste0("example_4_", j)]],
              input[[paste0("example_5_", j)]]
            )
            
            if (
              any(is.null(examples)) ||
              any(examples == "")
            ) {
              
              return(
                tags$p(
                  style = "color: red;",
                  "Please enter all five example values."
                )
              )
            }
            
            NULL
          })
        })
      }
    }
  })
  
  
  # Download setup button ---------------------------------------------------------------
  
  output$downloadSetupButton <- renderUI({
    
    ids <- variable_ids()
    
    if (length(ids) == 0) {
      return(NULL)
    }
    
    # Check variable names ---------------------------------------------------------------
    
    variable_names <- vapply(
      ids,
      function(i) {
        
        value <- input[[paste0("field_name_", i)]]
        
        if (is.null(value)) {
          ""
        } else {
          trimws(value)
        }
      },
      character(1)
    )
    
    missing_variable_names <- any(
      variable_names == ""
    )
    
    duplicate_variable_names <- any(
      duplicated(variable_names[variable_names != ""])
    )
    
    # Check numeric ranges ----------------------------------------------------------------
    
    invalid_numeric_ranges <- FALSE
    
    for (i in ids) {
      
      field_type <- input[[paste0("field_type_", i)]]
      
      if (
        !is.null(field_type) &&
        !is.na(field_type) &&
        field_type == "numeric"
      ) {
        
        range_required <- input[[paste0("range_req_", i)]]
        
        if (
          identical(range_required, "yes")
        ) {
          
          minimum <- input[[paste0("min_value_", i)]]
          maximum <- input[[paste0("max_value_", i)]]
          
          if (
            !is.null(minimum) &&
            !is.null(maximum) &&
            !is.na(minimum) &&
            !is.na(maximum) &&
            minimum > maximum
          ) {
            invalid_numeric_ranges <- TRUE
          }
        }
      }
    }
    
    # Check string length ranges ----------------------------------------------------------
    
    invalid_string_ranges <- FALSE
    
    for (i in ids) {
      
      field_type <- input[[paste0("field_type_", i)]]
      
      if (
        !is.null(field_type) &&
        !is.na(field_type) &&
        field_type == "string"
      ) {
        
        range_required <- input[[paste0("range_req_string", i)]]
        
        if (
          identical(range_required, "yes")
        ) {
          
          minimum <- input[[paste0("min_value_s", i)]]
          maximum <- input[[paste0("max_value_s", i)]]
          
          if (
            !is.null(minimum) &&
            !is.null(maximum) &&
            !is.na(minimum) &&
            !is.na(maximum) &&
            minimum > maximum
          ) {
            invalid_string_ranges <- TRUE
          }
        }
      }
    }
    
    all_examples_complete <- TRUE
    
    for (i in ids) {
      
      field_type <- input[[paste0("field_type_", i)]]
      validation <- input[[paste0("string_validation_", i)]]
      
      if (
        !is.null(field_type) &&
        !is.na(field_type) &&
        field_type == "string" &&
        !is.null(validation) &&
        !is.na(validation) &&
        validation == "examples"
      ) {
        
        examples <- c(
          input[[paste0("example_1_", i)]],
          input[[paste0("example_2_", i)]],
          input[[paste0("example_3_", i)]],
          input[[paste0("example_4_", i)]],
          input[[paste0("example_5_", i)]]
        )
        
        if (
          any(is.null(examples)) ||
          any(is.na(examples)) ||
          any(examples == "")
        ) {
          all_examples_complete <- FALSE
        }
      }
    }
    
    if (
      !missing_variable_names &&
      !duplicate_variable_names &&
      !invalid_numeric_ranges &&
      !invalid_string_ranges &&
      all_examples_complete
    ) {
      
      downloadButton(
        "downloadSetup",
        "Download Setup"
      )
      
    } else {
      
      error_messages <- character(0)
      
      if (missing_variable_names) {
        error_messages <- c(
          error_messages,
          "Please enter a variable name for every variable."
        )
      }
      
      if (duplicate_variable_names) {
        error_messages <- c(
          error_messages,
          "Variable names must be unique."
        )
      }
      
      if (invalid_numeric_ranges) {
        error_messages <- c(
          error_messages,
          "Minimum value cannot be greater than maximum value."
        )
      }
      
      if (invalid_string_ranges) {
        error_messages <- c(
          error_messages,
          "Minimum string length cannot be greater than maximum string length."
        )
      }
      
      if (!all_examples_complete) {
        error_messages <- c(
          error_messages,
          "Please enter all five example values before downloading the setup."
        )
      }
      
      tagList(
        
        tags$button(
          type = "button",
          class = "btn btn-default disabled",
          disabled = "disabled",
          "Download Setup"
        ),
        
        lapply(
          error_messages,
          function(message) {
            tags$p(
              tags$strong(
                style = "color: red;",
                message
              )
            )
          }
        )
      )
    }
  })
  
  
  # Downloads ---------------------------------------------------------------------------
  
  # Download sample dataset
  
  output$downloadSampleDataset <- downloadHandler(
    
    filename = function() {
      paste0(
        "sample_dataset_",
        Sys.Date(),
        ".csv"
      )
    },
    
    contentType = "text/csv",
    
    content = function(file) {
      
      fields <- selected_specification()
      
      sample_dataset <- generate_sample_dataset(
        fields,
        n = 10
      )
      
      readr::write_csv(
        sample_dataset,
        file,
        na = ""
      )
    }
  )
  
  # Download specification
  
  output$downloadSetup <- downloadHandler(
    
    filename = function() {
      paste0(
        "data_settings_",
        Sys.Date(),
        ".yaml"
      )
    },
    
    contentType = "text/yaml",
    
    content = function(file) {
      
      tryCatch({
        
        data <- userData()
        
        # Write YAML to a temporary file first
        temp_file <- tempfile(fileext = ".yaml")
        
        yaml::write_yaml(
          data,
          temp_file
        )
        
        # Read the YAML as text
        yaml_text <- readLines(
          temp_file,
          warn = FALSE
        )
        
        # Quote option values that YAML could interpret as logical values
        yaml_text <- gsub(
          "^([[:space:]]*- )[Yy][Ee][Ss]$",
          '\\1"yes"',
          yaml_text
        )
        
        yaml_text <- gsub(
          "^([[:space:]]*- )[Nn][Oo]$",
          '\\1"no"',
          yaml_text
        )
        
        # Write the modified YAML to the requested download file
        writeLines(
          yaml_text,
          file,
          useBytes = TRUE
        )
        
        # Clean up temporary file
        unlink(temp_file)
        
      }, error = function(e) {
        
        stop(
          paste0(
            "Could not create YAML file: ",
            e$message
          )
        )
      })
    }
  )
  
  
  # Download configuration
  
  output$downloadConfiguration <- downloadHandler(
    
    filename = function() {
      "config.yaml"
    },
    
    contentType = "text/yaml",
    
    content = function(file) {
      
      
      # Welcome message
      
      welcome_message <- NULL
      
      if (isTRUE(input$enable_welcome_message)) {
        
        welcome_message <- input$config_welcome_message
        
        if (
          is.null(welcome_message) ||
          !nzchar(trimws(welcome_message))
        ) {
          welcome_message <- NULL
        }
      }
      
      
      # Secondary message
      
      secondary_message <- NULL
      
      if (isTRUE(input$enable_secondary_message)) {
        
        secondary_message <- input$config_secondary_message
        
        if (
          is.null(secondary_message) ||
          !nzchar(trimws(secondary_message))
        ) {
          secondary_message <- NULL
        }
      }
      
      
      # Instruction Set 1
      
      instructions <- character(0)
      
      if (isTRUE(input$enable_instruction_set_1)) {
        
        n_instructions <- input$num_instruction_lines
        
        if (
          !is.null(n_instructions) &&
          !is.na(n_instructions) &&
          n_instructions > 0
        ) {
          
          instructions <- vapply(
            seq_len(n_instructions),
            function(i) {
              
              value <- input[[paste0(
                "config_instruction_",
                i
              )]]
              
              if (is.null(value)) {
                ""
              } else {
                value
              }
            },
            character(1)
          )
        }
      }
      
      
      # Links
      
      links <- list()
      
      if (isTRUE(input$enable_links)) {
        
        n_links <- input$num_links
        
        if (
          !is.null(n_links) &&
          !is.na(n_links) &&
          n_links > 0
        ) {
          
          links <- lapply(
            seq_len(n_links),
            function(i) {
              
              text <- input[[paste0(
                "config_link_text_",
                i
              )]]
              
              url <- input[[paste0(
                "config_link_url_",
                i
              )]]
              
              list(
                text = if (is.null(text)) "" else text,
                url = if (is.null(url)) "" else url
              )
            }
          )
        }
      }
      
      
      # Instruction Set 2
      
      upload_instructions <- character(0)
      
      if (isTRUE(input$enable_instruction_set_2)) {
        
        n_upload_instructions <- input$num_upload_instruction_lines
        
        if (
          !is.null(n_upload_instructions) &&
          !is.na(n_upload_instructions) &&
          n_upload_instructions > 0
        ) {
          
          upload_instructions <- vapply(
            seq_len(n_upload_instructions),
            function(i) {
              
              value <- input[[paste0(
                "config_upload_instruction_",
                i
              )]]
              
              if (is.null(value)) {
                ""
              } else {
                value
              }
            },
            character(1)
          )
        }
      }
      
      
      # Instruction set names
      
      instruction_set_1_name <- input$config_instruction_set_1_name
      
      if (
        is.null(instruction_set_1_name) ||
        !nzchar(trimws(instruction_set_1_name))
      ) {
        instruction_set_1_name <- "Instruction Set 1"
      }
      
      instruction_set_2_name <- input$config_instruction_set_2_name
      
      if (
        is.null(instruction_set_2_name) ||
        !nzchar(trimws(instruction_set_2_name))
      ) {
        instruction_set_2_name <- "Instruction Set 2"
      }
      
      
      # Create configuration
      
      configuration <- list(
        theme = input$config_theme,
        app_title = input$config_app_title,
        welcome_message = welcome_message,
        secondary_message = secondary_message,
        instruction_set_1_name = instruction_set_1_name,
        instruction_set_1 = instructions,
        links = links,
        instruction_set_2_name = instruction_set_2_name,
        instruction_set_2 = upload_instructions,
        specification_message = config$specification_message
      )
      
      
      # Write YAML
      
      yaml::write_yaml(
        configuration,
        file
      )
    }
  )
  
  # Download edited dataset as Excel
  
  output$downloadHighlighted <- downloadHandler(
    
    filename = function() {
      paste0(
        "edited_dataset_",
        Sys.Date(),
        ".xlsx"
      )
    },
    
    content = function(file) {
      
      df <- edited_data()
      
      if (is.null(df)) {
        stop(
          "The edited dataset is not available."
        )
      }
      
      fields <- selected_specification()
      
      validated <- validate_dataset(
        fields,
        df
      )
      
      issues <- validated[[2]]
      
      tryCatch(
        {
          highlight_csv_to_xlsx_v2(
            df,
            issues,
            file
          )
        },
        error = function(e) {
          print(e)
          stop(
            paste0(
              "Excel creation failed: ",
              e$message
            )
          )
        }
      )
    }
  )
  
  # Download standardized validated CSV
  download_ready <- reactiveVal(FALSE)
  
  generate_download_code <- function(
    lab_id,
    study,
    study_format,
    csv_contents,
    secret_key
  ) {
    
    message <- paste(
      lab_id,
      study,
      study_format,
      rawToChar(csv_contents),
      sep = "|"
    )
    
    substr(
      digest::hmac(
        key = secret_key,
        object = message,
        algo = "sha256",
        serialize = FALSE
      ),
      1,
      16
    )
  }
  
  observeEvent(input$downloadCSV, {
    
    download_ready(FALSE)
    
    showModal(
      modalDialog(
        title = "Enter Lab ID",
        
        textInput(
          "download_lab_id",
          "Lab ID:",
          placeholder = "e.g., infantlab"
        ),
        
        uiOutput("download_confirmation"),
        
        footer = modalButton("Cancel"),
        
        easyClose = TRUE
      )
    )
  })
  
  
  output$download_confirmation <- renderUI({
    
    if (download_ready()) {
      
      downloadButton(
        "downloadCSV_confirmed",
        "Download Validated CSV File"
      )
      
    } else {
      
      actionButton(
        "confirm_download",
        "Continue"
      )
    }
  })
  
  
  observeEvent(input$confirm_download, {
    
    lab_id <- trimws(input$download_lab_id)
    
    if (!nzchar(lab_id)) {
      showNotification(
        "Lab ID is required.",
        type = "error"
      )
      return()
    }
    
    if (!grepl("^[A-Za-z0-9-]+$", lab_id)) {
      showNotification(
        "Lab ID may only contain letters, numbers, and hyphens.",
        type = "error"
      )
      return()
    }
    
    download_ready(TRUE)
  })
  
output$downloadCSV_confirmed <- downloadHandler(
  
  filename = function() {
    
    lab_id <- trimws(input$download_lab_id)
    
    if (!nzchar(lab_id)) {
      stop("Lab ID is required.")
    }
    
    if (!grepl("^[A-Za-z0-9-]+$", lab_id)) {
      stop(
        "Lab ID may only contain letters, numbers, and hyphens."
      )
    }
    
    if (identical(input$specification_source, "local")) {
      
      study <- tools::file_path_sans_ext(
        input$local_specification$name
      )
      
      study_format <- "local"
      
    } else {
      
      study <- input$study
      study_format <- input$format
      
    }
    
    # Remove characters that could cause problems in a filename
    
    lab_id_clean <- gsub(
      "[^A-Za-z0-9_-]",
      "_",
      lab_id
    )
    
    study_clean <- gsub(
      "[^A-Za-z0-9_.-]",
      "_",
      study
    )
    
    study_format_clean <- gsub(
      "[^A-Za-z0-9_.-]",
      "_",
      study_format
    )
    
    # Get the dataset that will be downloaded
    
    df <- edited_data()
    
    if (is.null(df)) {
      stop(
        "The edited dataset is not available. ",
        "Please upload a dataset before attempting to download."
      )
    }
    
    # Create the exact CSV contents that will be downloaded
    
    temp_file <- tempfile(fileext = ".csv")
    
    readr::write_csv(
      df,
      temp_file,
      na = ""
    )
    
    csv_contents <- readBin(
      temp_file,
      what = "raw",
      n = file.info(temp_file)$size
    )
    
    unlink(temp_file)
    
    # Generate cryptographic code
    
    download_code <- generate_download_code(
      lab_id = lab_id,
      study = study,
      study_format = study_format,
      csv_contents = csv_contents,
      secret_key = secret_key
    )
    
    paste0(
      lab_id_clean,
      "_",
      study_clean,
      "_",
      study_format_clean,
      "_",
      download_code,
      ".csv"
    )
  },
  
  contentType = "text/csv",
  
  content = function(file) {
    
    # Get edited dataset
    
    df <- edited_data()
    
    if (is.null(df)) {
      stop(
        "The edited dataset is not available. ",
        "Please upload a dataset before attempting to download."
      )
    }
    
    # Write standardized CSV
    
    readr::write_csv(
      df,
      file,
      na = ""
    )
  }
)
  
  
# Editable dataset

edited_data <- reactiveVal(NULL)

observeEvent(input$file, {
  
  req(input$file)
  
  delimiter <- detect_delimiter(
    input$file$datapath
  )
  
  req(!is.null(delimiter))
  
  decimal_mark <- detect_decimal_mark(
    input$file$datapath,
    delimiter
  )
  
  df <- readr::read_delim(
    input$file$datapath,
    delim = delimiter,
    col_types = readr::cols(.default = readr::col_character()),
    na = "NA",
    show_col_types = FALSE
  )
  
  df <- standardize_decimal_mark(
    df,
    decimal_mark
  )
  
  print("VALUES AFTER CSV IMPORT AND DECIMAL STANDARDIZATION:")
  print(df)
  print("IS NA:")
  print(is.na(df))
  
  edited_data(df)
  
})
  
  # Check whether edited dataset is valid
  
dataset_is_valid <- reactive({
  
  req(edited_data())
  
  fields <- selected_specification()
  
  validated <- validate_dataset(
    fields,
    edited_data()
  )
  
  validated[[1]]
})
  
  # Show CSV download only when dataset is valid
  
  output$csv_validated <- reactive({
    dataset_is_valid()
  })
  
  outputOptions(
    output,
    "csv_validated",
    suspendWhenHidden = FALSE
  )
  
  # Store table edits
  
  observeEvent(input$validation_preview_cell_edit, {
    
    info <- input$validation_preview_cell_edit
    
    df <- edited_data()
    
    req(df)
    
    edited_data(
      DT::editData(
        df,
        info,
        rownames = FALSE
      )
    )
    
  })
  
  # Validation preview
  
  output$validation_preview <- DT::renderDT({
    
    req(input$file)
    
    fields <- selected_specification()
    
    df <- edited_data()
    
    req(df)
    
    validated <- validate_dataset(
      fields,
      df
    )
    
    issues <- validated[[2]]
    
    # Highlight invalid cells and unexpected columns
    
    invalid_cells <- list()
    unexpected_column_indices <- integer(0)
    
    for (issue in issues) {
      
      if (is.null(issue)) {
        next
      }
      
      
      # Invalid cells
      
      if (issue$type == "invalid_cell") {
        
        column_name <- issue$column
        rows <- as.integer(issue$invalid_row)
        
        if (
          column_name %in% names(df) &&
          length(rows) > 0
        ) {
          
          column_index <- which(names(df) == column_name) - 1
          
          for (row in rows) {
            
            invalid_cells[[length(invalid_cells) + 1]] <- list(
              row = row - 1,
              column = column_index
            )
          }
        }
      }
      
      
      # Unexpected columns
      
      if (issue$type == "unexpected_column") {
        
        column_name <- issue$column
        
        if (column_name %in% names(df)) {
          
          unexpected_column_indices <- c(
            unexpected_column_indices,
            which(names(df) == column_name) - 1
          )
        }
      }
    }
    
    unexpected_column_indices <- unique(
      unexpected_column_indices
    )
    
    print(unexpected_column_indices)
    
    
    # Create JavaScript for cell highlighting
    
    highlight_js <- if (length(invalid_cells) > 0) {
      
      cells_json <- jsonlite::toJSON(
        invalid_cells,
        auto_unbox = TRUE
      )
      
      columns_json <- jsonlite::toJSON(
        unexpected_column_indices,
        auto_unbox = TRUE
      )
      
      DT::JS(
        paste0(
          "function(row, data, displayNum, displayIndex, dataIndex) {",
          "  var invalidCells = ", cells_json, ";",
          "  var unexpectedColumns = ", columns_json, ";",
          "  invalidCells.forEach(function(cell) {",
          "    if (cell.row === dataIndex) {",
          "      $('td', row).eq(cell.column).css('background-color', 'yellow');",
          "    }",
          "  });",
          "}"
        )
      )
      
    } else {
      
      DT::JS(
        "function(row, data, displayNum, displayIndex, dataIndex) {}"
      )
    }
    
    
    # Create editable table
    
    display_df <- df |>
      mutate(
        across(
          everything(),
          ~ ifelse(is.na(.x), "NA", as.character(.x))
        )
      )
    
    DT::datatable(
      display_df,
      editable = TRUE,
      options = list(
        pageLength = 10,
        scrollX = TRUE,
        rowCallback = highlight_js,
        columnDefs = list(
          list(
            targets = unexpected_column_indices,
            createdCell = DT::JS(
              "function(td) {
            $(td).css('background-color', 'yellow');
          }"
            )
          )
        )
      ),
      rownames = FALSE
    )
    
  })
}