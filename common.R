library(tidyverse)
library(stringr)
library(openxlsx)


# Load available studies ---------------------------------------------------------------

studies <- tibble(
  file = list.files(
    path = "data_specifications",
    pattern = "\\.yaml$",
    full.names = FALSE
  )
) |>
  mutate(
    file = str_remove(file, "\\.yaml$")
  ) |>
  separate(
    file,
    into = c("study", "format"),
    sep = "_",
    extra = "merge",
    remove = TRUE
  )


# Delimiter detection -----------------------------------------------------

detect_delimiter <- function(file) {
  
  delimiters <- c(",", ";", "\t")
  
  results <- lapply(
    delimiters,
    function(delim) {
      
      data <- tryCatch(
        readr::read_delim(
          file,
          delim = delim,
          n_max = 10,
          show_col_types = FALSE,
          progress = FALSE
        ),
        error = function(e) NULL
      )
      
      if (is.null(data)) {
        return(0)
      }
      
      ncol(data)
    }
  )
  
  column_counts <- unlist(results)
  
  if (max(column_counts) <= 1) {
    return(NULL)
  }
  
  delimiters[which.max(column_counts)]
}


# Detect CSV decimal mark (this is to account for European decimal system)

detect_decimal_mark <- function(file, delimiter) {
  
  data <- readr::read_delim(
    file,
    delim = delimiter,
    col_types = readr::cols(.default = readr::col_character()),
    n_max = 100,
    show_col_types = FALSE,
    progress = FALSE
  )
  
  values <- unlist(data, use.names = FALSE)
  
  comma_decimals <- sum(
    stringr::str_detect(
      values,
      "^[-+]?[0-9]+,[0-9]+$"
    ),
    na.rm = TRUE
  )
  
  period_decimals <- sum(
    stringr::str_detect(
      values,
      "^[-+]?[0-9]+\\.[0-9]+$"
    ),
    na.rm = TRUE
  )
  
  if (comma_decimals > period_decimals) {
    return(",")
  }
  
  if (period_decimals > comma_decimals) {
    return(".")
  }
  
  return(".")
}

# Main validation function --------------------------------------------------------------

validate_dataset <- function(fields, dataset_contents) {
  
  issues <- list()
  
  # Check for unexpected columns
  
  specified_columns <- vapply(
    fields,
    function(field) {
      as.character(field$field)
    },
    character(1)
  )
  
  unexpected_columns <- setdiff(
    names(dataset_contents),
    specified_columns
  )
  
  if (length(unexpected_columns) > 0) {
    
    for (column in unexpected_columns) {
      
      issues[[length(issues) + 1]] <- list(
        type = "unexpected_column",
        column = column,
        invalid_value = NA,
        invalid_row = integer(0)
      )
    }
  }
  
  # Check for missing columns
  
  for (field in fields) {
    
    if (
      field$required &&
      !(field$field %in% names(dataset_contents))
    ) {
      
      issues[[length(issues) + 1]] <- list(
        type = "missing_column",
        column = field$field,
        invalid_value = NA,
        invalid_row = integer(0)
      )
    }
  }
  
  # Validate cells
  
  for (field in fields) {
    
    if (!(field$field %in% names(dataset_contents))) {
      next
    }
    
    result <- validate_dataset_field(
      dataset_contents,
      field
    )
    
    if (!result[[1]]) {
      
      issue <- result[[2]]
      
      if (!is.null(issue)) {
        issues[[length(issues) + 1]] <- issue
      }
    }
  }
  
  valid <- length(issues) == 0
  
  list(
    valid,
    issues
  )
}

# Create highlighted Excel file

highlight_csv_to_xlsx_v2 <- function(df, issues, file) {
  
  workbook <- openxlsx::createWorkbook()
  
  openxlsx::addWorksheet(
    workbook,
    "Validated Dataset"
  )
  
  # Write dataset to Excel
  
  openxlsx::writeData(
    workbook,
    "Validated Dataset",
    as.data.frame(df),
    keepNA = TRUE,
    na.string = "NA"
  )
  
  print("ISSUES SENT TO EXCEL EXPORT:")
  print(issues)
  
  # Create highlight style
  
  invalid_style <- openxlsx::createStyle(
    fgFill = "#FFFF00"
  )
  
  
  
  # Highlight invalid cells
  
  for (issue in issues) {
    
    if (
      is.null(issue) ||
      issue$type != "invalid_cell"
    ) {
      next
    }
    
    column_name <- issue$column
    rows <- as.integer(issue$invalid_row)
    
    if (
      column_name %in% names(df) &&
      length(rows) > 0
    ) {
      
      column_index <- which(
        names(df) == column_name
      )
      
      openxlsx::addStyle(
        workbook,
        "Validated Dataset",
        style = invalid_style,
        rows = rows + 1,
        cols = column_index,
        gridExpand = TRUE,
        stack = TRUE
      )
    }
  }
  
  # Highlight unexpected columns
  
  for (issue in issues) {
    
    if (
      is.null(issue) ||
      issue$type != "unexpected_column"
    ) {
      next
    }
    
    column_name <- issue$column
    
    if (column_name %in% names(df)) {
      
      column_index <- which(
        names(df) == column_name
      )
      
      openxlsx::addStyle(
        workbook,
        "Validated Dataset",
        style = invalid_style,
        rows = seq_len(nrow(df)) + 1,
        cols = column_index,
        gridExpand = TRUE,
        stack = TRUE
      )
    }
  }
  
  # Save Excel file
  
  openxlsx::saveWorkbook(
    workbook,
    file,
    overwrite = TRUE
  )
}

# Validate a field ----------------------------------------------------------------------

validate_dataset_field <- function(dataset_contents, field) {
  
  if (!(field$field %in% names(dataset_contents))) {
    return(list(TRUE, NULL))
  }
  
  field_contents <- dataset_contents[[field$field]]
  
  
  # Check missing values
  
  if (!field$NA_allowed) {
    
    missing_rows <- which(is.na(field_contents))
    
    if (length(missing_rows) > 0) {
      
      incorrect <- list(
        type = "invalid_cell",
        column = field$field,
        invalid_value = field_contents[missing_rows],
        invalid_row = missing_rows
      )
      
      return(list(FALSE, incorrect))
    }
  }
  
  
  # Validate field type
  
  if (field$type == "options") {
    
    return(
      ValidateOption(
        dataset_contents,
        field
      )
    )
    
  } else if (field$type == "numeric") {
    
    return(
      ValidateNumeric(
        dataset_contents,
        field
      )
    )
    
  } else if (field$type == "string") {
    
    if (field$format == "regex") {
      
      return(
        ValidateRegex(
          dataset_contents,
          field
        )
      )
      
    } else {
      
      return(
        ValidateString(
          dataset_contents,
          field
        )
      )
    }
  }
  
  return(list(TRUE, NULL))
}


# Validate option fields ---------------------------------------------------------------

ValidateOption <- function(dataset_contents, field) {
  
  field_contents <- dataset_contents[[field$field]]
  
  options <- if (is.list(field$options)) {
    unlist(
      field$options,
      use.names = FALSE
    )
  } else {
    field$options
  }
  
  invalid_rows <- which(
    !is.na(field_contents) &
      !(field_contents %in% options)
  )
  
  if (length(invalid_rows) > 0) {
    
    incorrect <- list(
      type = "invalid_cell",
      column = field$field,
      invalid_value = field_contents[invalid_rows],
      invalid_row = invalid_rows
    )
    
    return(list(FALSE, incorrect))
  }
  
  return(list(TRUE, NULL))
}


# Validate numeric fields --------------------------------------------------------------

ValidateNumeric <- function(dataset_contents, field) {
  
  field_contents <- dataset_contents[[field$field]]
  
  invalid_content <- c()
  invalid_rows <- c()
  
  numeric_values <- suppressWarnings(
    as.numeric(field_contents)
  )
  
  # Check non-numeric values
  
  non_numeric_indices <- which(
    is.na(numeric_values) &
      !is.na(field_contents)
  )
  
  if (length(non_numeric_indices) > 0) {
    
    invalid_content <- c(
      invalid_content,
      field_contents[non_numeric_indices]
    )
    
    invalid_rows <- c(
      invalid_rows,
      non_numeric_indices
    )
  }
  
  
  # Check numeric range
  
  if (field$format == "restricted") {
    
    lowerLimit <- as.numeric(field$lowerlimit)
    upperLimit <- as.numeric(field$upperlimit)
    
    valid_numeric_indices <- which(
      !is.na(numeric_values)
    )
    
    below_lower_indices <- valid_numeric_indices[
      numeric_values[valid_numeric_indices] < lowerLimit
    ]
    
    if (length(below_lower_indices) > 0) {
      
      invalid_content <- c(
        invalid_content,
        field_contents[below_lower_indices]
      )
      
      invalid_rows <- c(
        invalid_rows,
        below_lower_indices
      )
    }
    
    above_upper_indices <- valid_numeric_indices[
      numeric_values[valid_numeric_indices] > upperLimit
    ]
    
    if (length(above_upper_indices) > 0) {
      
      invalid_content <- c(
        invalid_content,
        field_contents[above_upper_indices]
      )
      
      invalid_rows <- c(
        invalid_rows,
        above_upper_indices
      )
    }
  }
  
  
  # Check decimal restrictions
  
  if (field$allow_decimals == "no") {
    
    decimal_indices <- which(
      !is.na(numeric_values) &
        numeric_values %% 1 != 0
    )
    
    if (length(decimal_indices) > 0) {
      
      invalid_content <- c(
        invalid_content,
        field_contents[decimal_indices]
      )
      
      invalid_rows <- c(
        invalid_rows,
        decimal_indices
      )
    }
  }
  
  
  # Check decimal places
  
  if (field$allow_decimals == "yes") {
    
    min_decimals <- as.numeric(field$min_decimals)
    max_decimals <- as.numeric(field$max_decimals)
    
    valid_numeric_indices <- which(
      !is.na(numeric_values)
    )
    
    decimal_places <- sapply(
      field_contents[valid_numeric_indices],
      function(x) {
        
        x <- as.character(x)
        
        if (!grepl("\\.", x)) {
          return(0)
        }
        
        nchar(
          sub(
            "^[^.]*\\.",
            "",
            x
          )
        )
      }
    )
    
    too_few_decimals <- valid_numeric_indices[
      decimal_places < min_decimals
    ]
    
    too_many_decimals <- valid_numeric_indices[
      decimal_places > max_decimals
    ]
    
    if (length(too_few_decimals) > 0) {
      
      invalid_content <- c(
        invalid_content,
        field_contents[too_few_decimals]
      )
      
      invalid_rows <- c(
        invalid_rows,
        too_few_decimals
      )
    }
    
    if (length(too_many_decimals) > 0) {
      
      invalid_content <- c(
        invalid_content,
        field_contents[too_many_decimals]
      )
      
      invalid_rows <- c(
        invalid_rows,
        too_many_decimals
      )
    }
  }
  
  
  # Return validation result
  
  if (length(invalid_rows) > 0) {
    
    incorrect <- list(
      type = "invalid_cell",
      column = field$field,
      invalid_value = field_contents[invalid_rows],
      invalid_row = sort(unique(invalid_rows))
    )
    
    return(list(FALSE, incorrect))
  }
  
  return(list(TRUE, NULL))
}


# Validate string fields ----------------------------------------------------------------

ValidateString <- function(dataset_contents, field) {
  
  field_contents <- dataset_contents[[field$field]]
  
  invalid_rows <- c()
  
  
  # Check lowercase
  
  if (field$format == "uncapitalized") {
    
    uppercase_rows <- which(
      !is.na(field_contents) &
        grepl("[[:upper:]]", field_contents)
    )
    
    invalid_rows <- c(
      invalid_rows,
      uppercase_rows
    )
  }
  
  
  # Check uppercase
  
  if (field$format == "capitalized") {
    
    lowercase_rows <- which(
      !is.na(field_contents) &
        grepl("[[:lower:]]", field_contents)
    )
    
    invalid_rows <- c(
      invalid_rows,
      lowercase_rows
    )
  }
  
  
  # Check minimum length
  
  if (!is.na(field$lowerlimit)) {
    
    lowerLimit <- as.numeric(field$lowerlimit)
    
    short_rows <- which(
      !is.na(field_contents) &
        nchar(field_contents) < lowerLimit
    )
    
    invalid_rows <- c(
      invalid_rows,
      short_rows
    )
  }
  
  
  # Check maximum length
  
  if (!is.na(field$upperlimit)) {
    
    upperLimit <- as.numeric(field$upperlimit)
    
    long_rows <- which(
      !is.na(field_contents) &
        nchar(field_contents) > upperLimit
    )
    
    invalid_rows <- c(
      invalid_rows,
      long_rows
    )
  }
  
  
  # Return validation result
  
  invalid_rows <- sort(unique(invalid_rows))
  
  if (length(invalid_rows) > 0) {
    
    incorrect <- list(
      type = "invalid_cell",
      column = field$field,
      invalid_value = field_contents[invalid_rows],
      invalid_row = invalid_rows
    )
    
    return(list(FALSE, incorrect))
  }
  
  return(list(TRUE, NULL))
}


# Generate regex from examples ----------------------------------------------------------

GenerateRegex <- function(examples) {
  
  examples <- examples[
    !is.na(examples) &
      examples != ""
  ]
  
  if (length(examples) < 2) {
    return(NA)
  }
  
  
  # Find common prefix
  
  common_prefix <- examples[1]
  
  for (example in examples[-1]) {
    
    max_length <- min(
      nchar(common_prefix),
      nchar(example)
    )
    
    i <- 1
    
    while (
      i <= max_length &&
      substr(common_prefix, i, i) ==
      substr(example, i, i)
    ) {
      i <- i + 1
    }
    
    common_prefix <- substr(
      common_prefix,
      1,
      i - 1
    )
  }
  
  
  # Identify remaining characters
  
  remaining <- substr(
    examples,
    nchar(common_prefix) + 1,
    nchar(examples)
  )
  
  
  # Numeric pattern
  
  if (all(grepl("^[0-9]+$", remaining))) {
    return(
      paste0(
        "^",
        common_prefix,
        "[0-9]+",
        "$"
      )
    )
  }
  
  
  # Lowercase pattern
  
  if (all(grepl("^[a-z]+$", remaining))) {
    return(
      paste0(
        "^",
        common_prefix,
        "[a-z]+",
        "$"
      )
    )
  }
  
  
  # Uppercase pattern
  
  if (all(grepl("^[A-Z]+$", remaining))) {
    return(
      paste0(
        "^",
        common_prefix,
        "[A-Z]+",
        "$"
      )
    )
  }
  
  
  # Letters pattern
  
  if (all(grepl("^[A-Za-z]+$", remaining))) {
    return(
      paste0(
        "^",
        common_prefix,
        "[A-Za-z]+",
        "$"
      )
    )
  }
  
  
  # Alphanumeric pattern
  
  if (all(grepl("^[A-Za-z0-9]+$", remaining))) {
    return(
      paste0(
        "^",
        common_prefix,
        "[A-Za-z0-9]+",
        "$"
      )
    )
  }
  
  NA
}


# Validate regex fields ----------------------------------------------------------------

ValidateRegex <- function(dataset_contents, field) {
  
  field_contents <- dataset_contents[[field$field]]
  
  
  # Check whether regex is valid
  
  regex_valid <- tryCatch(
    {
      grepl(
        field$pattern,
        "",
        perl = TRUE
      )
      
      TRUE
    },
    error = function(e) {
      FALSE
    }
  )
  
  if (!regex_valid) {
    
    stop(
      sprintf(
        "Invalid regular expression for variable '%s': %s",
        field$field,
        field$pattern
      )
    )
  }
  
  
  # Find invalid cells
  
  invalid_rows <- which(
    !is.na(field_contents) &
      !grepl(
        field$pattern,
        field_contents,
        perl = TRUE
      )
  )
  
  if (length(invalid_rows) > 0) {
    
    incorrect <- list(
      type = "invalid_cell",
      column = field$field,
      invalid_value = field_contents[invalid_rows],
      invalid_row = invalid_rows
    )
    
    return(list(FALSE, incorrect))
  }
  
  return(list(TRUE, NULL))
}


# Generate error explanations -----------------------------------------------------------

explain_error <- function(issue, fields) {
  
  field_index <- which(
    vapply(
      fields,
      function(x) {
        identical(
          as.character(x$field),
          as.character(issue$column)
        )
      },
      logical(1)
    )
  )
  
  if (length(field_index) == 0) {
    return(
      "This value does not meet the requirements in the specification."
    )
  }
  
  field <- fields[[field_index[1]]]
  
  
  # Custom error message
  
  error_message <- field$error_message
  
  if (
    !is.null(error_message) &&
    length(error_message) == 1 &&
    !is.na(error_message) &&
    error_message != ""
  ) {
    return(as.character(error_message))
  }
  
  # Unexpected column
  
  if (issue$type == "unexpected_column") {
    return(
      "This column is not included in the dataset specification."
    )
  }
  
  # Missing column
  
  if (issue$type == "missing_column") {
    return(
      "This is a required column, but it was not found in the dataset."
    )
  }
  
  
  # Options
  
  if (identical(field$type, "options")) {
    
    options <- field$options
    
    if (is.list(options)) {
      options <- unlist(
        options,
        use.names = FALSE
      )
    }
    
    options <- as.character(options)
    
    return(
      paste0(
        "The value must be one of: ",
        paste(
          shQuote(options),
          collapse = ", "
        ),
        "."
      )
    )
  }
  
  
  # Numeric
  
  if (identical(field$type, "numeric")) {
    
    explanations <- character(0)
    
    lower <- field$lowerlimit
    upper <- field$upperlimit
    
    if (
      length(lower) == 1 &&
      !is.na(lower)
    ) {
      explanations <- c(
        explanations,
        paste0(
          "Values must be at least ",
          lower,
          "."
        )
      )
    }
    
    if (
      length(upper) == 1 &&
      !is.na(upper)
    ) {
      explanations <- c(
        explanations,
        paste0(
          "Values must be no greater than ",
          upper,
          "."
        )
      )
    }
    
    allow_decimals <- field$allow_decimals
    
    if (
      length(allow_decimals) == 1 &&
      identical(
        as.character(allow_decimals),
        "no"
      )
    ) {
      explanations <- c(
        explanations,
        "Decimal values are not allowed."
      )
    }
    
    if (
      length(allow_decimals) == 1 &&
      identical(
        as.character(allow_decimals),
        "yes"
      )
    ) {
      
      min_decimals <- as.numeric(
        field$min_decimals
      )
      
      max_decimals <- as.numeric(
        field$max_decimals
      )
      
      if (
        length(min_decimals) == 1 &&
        length(max_decimals) == 1 &&
        !is.na(min_decimals) &&
        !is.na(max_decimals)
      ) {
        explanations <- c(
          explanations,
          paste0(
            "Values may have ",
            min_decimals,
            " to ",
            max_decimals,
            " decimal places."
          )
        )
      }
    }
    
    if (length(explanations) > 0) {
      return(
        paste(
          explanations,
          collapse = " "
        )
      )
    }
  }
  
  
  # String and regex
  
  if (identical(field$type, "string")) {
    
    pattern <- field$pattern
    
    if (
      length(pattern) == 1 &&
      !is.na(pattern)
    ) {
      
      pattern <- as.character(pattern)
      
      if (identical(pattern, "^[A-Za-z0-9]+$")) {
        return(
          "The value may contain letters and numbers only. Spaces and special characters are not allowed."
        )
      }
      
      if (identical(pattern, "^[A-Za-z]+$")) {
        return(
          "The value may contain letters only. Numbers, spaces, and special characters are not allowed."
        )
      }
      
      if (identical(pattern, "^[0-9]+$")) {
        return(
          "The value may contain numbers only. Letters, spaces, and special characters are not allowed."
        )
      }
      
      return(
        paste0(
          "The value must match the required pattern: ",
          pattern,
          "."
        )
      )
    }
    
    if (identical(field$format, "uncapitalized")) {
      return(
        "The value must contain lowercase letters only."
      )
    }
    
    if (identical(field$format, "capitalized")) {
      return(
        "The value must contain uppercase letters only."
      )
    }
  }
  
  
  # Default error message
  
  return(
    "The value does not meet the requirements in the specification."
  )
}