library(tidyverse)
library(stringr)
library(openxlsx)


# Safe helpers ---------------------------------------------------------------------------

# Load uploaded YAML without ever evaluating R code (!expr tags) and cap the file size
read_yaml_safe <- function(path, max_bytes = 1024^2) {
  
  if (!file.exists(path)) {
    stop("File not found.")
  }
  
  if (file.info(path)$size > max_bytes) {
    stop("The YAML file is too large (limit 1 MB).")
  }
  
  yaml::yaml.load_file(path, eval.expr = FALSE)
}


# Only allow http(s) links; returns NULL for anything else (javascript:, data:, ...)
safe_link_url <- function(url) {
  
  if (is.null(url) || length(url) != 1 || is.na(url)) {
    return(NULL)
  }
  
  url <- trimws(as.character(url))
  
  if (grepl("^https?://[^[:space:]]+$", url, ignore.case = TRUE)) {
    url
  } else {
    NULL
  }
}


# Normalise yes/no/true/false (YAML may give logicals or strings) to TRUE/FALSE/NA
flag <- function(x) {
  
  if (is.null(x) || length(x) != 1 || is.na(x)) {
    return(NA)
  }
  
  if (is.logical(x)) {
    return(x)
  }
  
  v <- tolower(trimws(as.character(x)))
  
  if (v %in% c("yes", "true")) {
    TRUE
  } else if (v %in% c("no", "false")) {
    FALSE
  } else {
    NA
  }
}


regex_escape <- function(x) {
  gsub("([.|()\\^{}+$*?\\[\\]\\\\])", "\\\\\\1", x, perl = TRUE)
}


# sample() that is safe for length-1 vectors
pick <- function(v, n) {
  v[sample.int(length(v), n, replace = TRUE)]
}


# A single number, or a default when the value is missing / NA / not numeric
num_or <- function(x, default) {
  
  x <- suppressWarnings(as.numeric(x))
  
  if (length(x) == 1 && !is.na(x)) {
    x
  } else {
    default
  }
}


# Build the standard (valid, issue) result for a column
cell_result <- function(field, x, rows) {
  
  rows <- sort(unique(as.integer(rows)))
  
  if (length(rows) == 0) {
    return(list(TRUE, NULL))
  }
  
  list(
    FALSE,
    list(
      type = "invalid_cell",
      column = field$field,
      invalid_value = x[rows],
      invalid_row = rows
    )
  )
}


# Delimiter detection --------------------------------------------------------------------

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
    stringr::str_detect(values, "^[-+]?[0-9]+,[0-9]+$"),
    na.rm = TRUE
  )
  
  period_decimals <- sum(
    stringr::str_detect(values, "^[-+]?[0-9]+\\.[0-9]+$"),
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


# Standardize decimal mark ---------------------------------------------------------------

standardize_decimal_mark <- function(data, decimal_mark) {
  
  if (decimal_mark == ",") {
    
    data <- data |>
      mutate(
        across(
          everything(),
          ~ str_replace_all(.x, "(?<=\\d),(?=\\d)", ".")
        )
      )
  }
  
  data
}


# Main validation function ---------------------------------------------------------------

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
  
  for (column in unexpected_columns) {
    
    issues[[length(issues) + 1]] <- list(
      type = "unexpected_column",
      column = column,
      invalid_value = NA,
      invalid_row = integer(0)
    )
  }
  
  # Check for missing columns
  # (a field without a `required` key is treated as required)
  
  for (field in fields) {
    
    if (
      !isFALSE(flag(field$required)) &&
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
    
    result <- validate_dataset_field(dataset_contents, field)
    
    if (!result[[1]]) {
      
      issue <- result[[2]]
      
      if (!is.null(issue)) {
        issues[[length(issues) + 1]] <- issue
      }
    }
  }
  
  valid <- length(issues) == 0
  
  # Named, but [[1]] and [[2]] still work for existing callers
  list(valid = valid, issues = issues)
}


# Create highlighted Excel file ----------------------------------------------------------

highlight_csv_to_xlsx_v2 <- function(df, issues, file) {
  
  workbook <- openxlsx::createWorkbook()
  
  openxlsx::addWorksheet(workbook, "Validated Dataset")
  
  # Write dataset to Excel
  
  openxlsx::writeData(
    workbook,
    "Validated Dataset",
    as.data.frame(df),
    keepNA = TRUE,
    na.string = "NA"
  )
  
  # Create highlight style
  
  invalid_style <- openxlsx::createStyle(fgFill = "#FFFF00")
  
  # Highlight invalid cells
  
  for (issue in issues) {
    
    if (is.null(issue) || issue$type != "invalid_cell") {
      next
    }
    
    column_name <- issue$column
    rows <- as.integer(issue$invalid_row)
    
    if (column_name %in% names(df) && length(rows) > 0) {
      
      column_index <- which(names(df) == column_name)
      
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
    
    if (is.null(issue) || issue$type != "unexpected_column") {
      next
    }
    
    column_name <- issue$column
    
    if (column_name %in% names(df)) {
      
      column_index <- which(names(df) == column_name)
      
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
  
  openxlsx::saveWorkbook(workbook, file, overwrite = TRUE)
}


# Validate a field -----------------------------------------------------------------------

validate_dataset_field <- function(dataset_contents, field) {
  
  if (!(field$field %in% names(dataset_contents))) {
    return(list(TRUE, NULL))
  }
  
  x <- dataset_contents[[field$field]]
  bad <- integer(0)
  
  # NA values
  
  if (!isTRUE(flag(field$NA_allowed))) {
    bad <- c(bad, which(is.na(x)))
  }
  
  # Empty cells
  
  if (!isTRUE(flag(field$empty_allowed))) {
    bad <- c(bad, which(!is.na(x) & x == ""))
  }
  
  # Field type
  
  type <- as.character(field$type)[1]
  
  check <- if (identical(type, "options")) {
    ValidateOption
  } else if (identical(type, "numeric")) {
    ValidateNumeric
  } else if (identical(type, "string")) {
    if (identical(field$format, "regex")) ValidateRegex else ValidateString
  } else {
    NULL
  }
  
  # Type checks run even when NA/empty checks failed, so users see every
  # problem in a column in one pass
  
  if (!is.null(check)) {
    
    res <- check(dataset_contents, field)
    
    if (!res[[1]]) {
      bad <- c(bad, res[[2]]$invalid_row)
    }
  }
  
  cell_result(field, x, bad)
}


# Validate option fields -----------------------------------------------------------------

ValidateOption <- function(dataset_contents, field) {
  
  x <- dataset_contents[[field$field]]
  
  options <- as.character(unlist(field$options, use.names = FALSE))
  
  present <- !is.na(x) & x != ""
  
  cell_result(field, x, which(present & !(x %in% options)))
}


# Validate numeric fields ----------------------------------------------------------------

ValidateNumeric <- function(dataset_contents, field) {
  
  x <- dataset_contents[[field$field]]
  
  present <- !is.na(x) & x != ""
  
  # Strict parse: plain decimals or scientific notation only
  # (rejects hex like 0x1A, "Inf", values with surrounding spaces, ...)
  
  looks_numeric <- present &
    grepl("^[-+]?([0-9]+\\.?[0-9]*|\\.[0-9]+)([eE][-+]?[0-9]+)?$", x)
  
  values <- rep(NA_real_, length(x))
  values[looks_numeric] <- as.numeric(x[looks_numeric])
  
  # Non-numeric and non-finite values
  
  bad <- which(present & !looks_numeric)
  bad <- c(bad, which(looks_numeric & !is.finite(values)))
  
  # Range
  
  if (identical(field$format, "restricted")) {
    
    lower <- num_or(field$lowerlimit, NA)
    upper <- num_or(field$upperlimit, NA)
    
    if (!is.na(lower)) {
      bad <- c(bad, which(looks_numeric & values < lower))
    }
    
    if (!is.na(upper)) {
      bad <- c(bad, which(looks_numeric & values > upper))
    }
  }
  
  # Decimals
  
  allow_decimals <- flag(field$allow_decimals)
  
  if (isFALSE(allow_decimals)) {
    bad <- c(
      bad,
      which(looks_numeric & is.finite(values) & values %% 1 != 0)
    )
  }
  
  if (isTRUE(allow_decimals)) {
    
    min_decimals <- num_or(field$min_decimals, 0)
    max_decimals <- num_or(field$max_decimals, Inf)
    
    plain <- looks_numeric & !grepl("[eE]", x)
    
    places <- ifelse(
      plain & grepl("\\.", x),
      nchar(sub("^[^.]*\\.", "", x)),
      0
    )
    
    bad <- c(
      bad,
      which(plain & (places < min_decimals | places > max_decimals))
    )
  }
  
  cell_result(field, x, bad)
}


# Validate string fields -----------------------------------------------------------------

ValidateString <- function(dataset_contents, field) {
  
  x <- dataset_contents[[field$field]]
  
  present <- !is.na(x) & x != ""
  
  bad <- integer(0)
  
  # Lowercase only
  
  if (identical(field$format, "uncapitalized")) {
    bad <- c(bad, which(present & grepl("[[:upper:]]", x)))
  }
  
  # Uppercase only
  
  if (identical(field$format, "capitalized")) {
    bad <- c(bad, which(present & grepl("[[:lower:]]", x)))
  }
  
  # Length limits
  
  lower <- num_or(field$lowerlimit, NA)
  upper <- num_or(field$upperlimit, NA)
  
  if (!is.na(lower)) {
    bad <- c(bad, which(present & nchar(x) < lower))
  }
  
  if (!is.na(upper)) {
    bad <- c(bad, which(present & nchar(x) > upper))
  }
  
  cell_result(field, x, bad)
}


# Generate regex from examples -----------------------------------------------------------

GenerateRegex <- function(examples) {
  
  examples <- examples[!is.na(examples) & examples != ""]
  
  if (length(examples) < 2) {
    return(NA_character_)
  }
  
  # Longest common prefix
  
  prefix <- examples[1]
  
  for (example in examples[-1]) {
    
    n <- min(nchar(prefix), nchar(example))
    i <- 0
    
    while (
      i < n &&
      substr(prefix, i + 1, i + 1) == substr(example, i + 1, i + 1)
    ) {
      i <- i + 1
    }
    
    prefix <- substr(prefix, 1, i)
  }
  
  # What is left after the prefix decides the rest of the pattern
  
  remaining <- substr(examples, nchar(prefix) + 1, nchar(examples))
  
  suffixes <- c(
    "^[0-9]+$"       = "[0-9]+",
    "^[a-z]+$"       = "[a-z]+",
    "^[A-Z]+$"       = "[A-Z]+",
    "^[A-Za-z]+$"    = "[A-Za-z]+",
    "^[A-Za-z0-9]+$" = "[A-Za-z0-9]+"
  )
  
  for (check in names(suffixes)) {
    
    if (all(grepl(check, remaining))) {
      
      # The prefix is escaped so characters such as . or ( are taken literally
      return(paste0("^", regex_escape(prefix), suffixes[[check]], "$"))
    }
  }
  
  NA_character_
}


# Validate regex fields ------------------------------------------------------------------

ValidateRegex <- function(dataset_contents, field) {
  
  x <- dataset_contents[[field$field]]
  
  pattern <- field$pattern
  
  # A missing pattern used to validate nothing silently; fail loudly instead
  
  if (
    is.null(pattern) ||
    length(pattern) != 1 ||
    is.na(pattern) ||
    !nzchar(pattern)
  ) {
    stop(
      sprintf(
        "Variable '%s' uses a pattern-based format but has no valid pattern.",
        field$field
      ),
      call. = FALSE
    )
  }
  
  pattern <- as.character(pattern)
  
  # Check whether the regex is valid
  
  tryCatch(
    grepl(pattern, "", perl = TRUE),
    error = function(e) {
      stop(
        sprintf(
          "Invalid regular expression for variable '%s': %s",
          field$field,
          pattern
        ),
        call. = FALSE
      )
    }
  )
  
  present <- !is.na(x) & x != ""
  
  cell_result(field, x, which(present & !grepl(pattern, x, perl = TRUE)))
}


# Generate error explanations ------------------------------------------------------------

explain_error <- function(issue, fields) {
  
  field_index <- which(
    vapply(
      fields,
      function(x) {
        identical(as.character(x$field), as.character(issue$column))
      },
      logical(1)
    )
  )
  
  if (length(field_index) == 0) {
    return("This value does not meet the requirements in the specification.")
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
    return("This column is not included in the dataset specification.")
  }
  
  # Missing column
  
  if (issue$type == "missing_column") {
    return("This is a required column, but it was not found in the dataset.")
  }
  
  # Options
  
  if (identical(field$type, "options")) {
    
    options <- as.character(unlist(field$options, use.names = FALSE))
    
    return(
      paste0(
        "The value must be one of: ",
        paste(shQuote(options), collapse = ", "),
        "."
      )
    )
  }
  
  # Numeric
  
  if (identical(field$type, "numeric")) {
    
    explanations <- character(0)
    
    lower <- field$lowerlimit
    upper <- field$upperlimit
    
    if (length(lower) == 1 && !is.na(lower)) {
      explanations <- c(explanations, paste0("Values must be at least ", lower, "."))
    }
    
    if (length(upper) == 1 && !is.na(upper)) {
      explanations <- c(
        explanations,
        paste0("Values must be no greater than ", upper, ".")
      )
    }
    
    allow_decimals <- flag(field$allow_decimals)
    
    if (isFALSE(allow_decimals)) {
      explanations <- c(explanations, "Decimal values are not allowed.")
    }
    
    if (isTRUE(allow_decimals)) {
      
      min_decimals <- as.numeric(field$min_decimals)
      max_decimals <- as.numeric(field$max_decimals)
      
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
      return(paste(explanations, collapse = " "))
    }
  }
  
  # String and regex
  
  if (identical(field$type, "string")) {
    
    pattern <- field$pattern
    
    if (length(pattern) == 1 && !is.na(pattern)) {
      
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
      
      return(paste0("The value must match the required pattern: ", pattern, "."))
    }
    
    if (identical(field$format, "uncapitalized")) {
      return("The value must contain lowercase letters only.")
    }
    
    if (identical(field$format, "capitalized")) {
      return("The value must contain uppercase letters only.")
    }
  }
  
  # Default error message
  
  return("The value does not meet the requirements in the specification.")
}


# Generate sample dataset ----------------------------------------------------------------

rand_text <- function(len, pool) {
  paste(pick(pool, len), collapse = "")
}


# Length of generated text, respecting any length limits in the specification
string_length <- function(field, default = 8) {
  
  lower <- num_or(field$lowerlimit, 1)
  upper <- num_or(field$upperlimit, Inf)
  
  max(1, floor(min(max(default, lower), upper)))
}


# Generate one value that matches a (simple) regular expression body
generate_regex_value <- function(body, field_name) {
  
  classes <- list(
    "0-9"       = as.character(0:9),
    "a-z"       = letters,
    "A-Z"       = LETTERS,
    "A-Za-z"    = c(LETTERS, letters),
    "A-Za-z0-9" = c(LETTERS, letters, as.character(0:9))
  )
  
  n <- nchar(body)
  at <- function(i) substr(body, i, i)
  
  out <- character(0)
  pos <- 1
  
  while (pos <= n) {
    
    ch <- at(pos)
    
    if (ch == "[") {
      
      # Character class
      
      close <- pos + 1
      
      while (close <= n && at(close) != "]") {
        close <- close + 1
      }
      
      if (close > n) {
        stop(
          "Invalid regex pattern for variable '", field_name, "'.",
          call. = FALSE
        )
      }
      
      cls <- substr(body, pos + 1, close - 1)
      pool <- classes[[cls]]
      
      if (is.null(pool)) {
        stop(
          "Regex character class '", cls,
          "' is not supported for variable '", field_name, "'.",
          call. = FALSE
        )
      }
      
      pos <- close + 1
      count <- 1
      
      if (pos <= n && at(pos) == "{") {
        
        # Exact {3} or bounded {1,4} quantifier
        
        end <- pos + 1
        
        while (end <= n && at(end) != "}") {
          end <- end + 1
        }
        
        if (end > n) {
          stop(
            "Invalid quantifier in regex for variable '", field_name, "'.",
            call. = FALSE
          )
        }
        
        quantifier <- substr(body, pos + 1, end - 1)
        
        if (grepl(",", quantifier, fixed = TRUE)) {
          limits <- as.integer(strsplit(quantifier, ",", fixed = TRUE)[[1]])
          count <- pick(limits[1]:limits[2], 1)
        } else {
          count <- as.integer(quantifier)
        }
        
        pos <- end + 1
        
      } else if (pos <= n && at(pos) == "+") {
        
        # One or more
        
        count <- pick(1:8, 1)
        pos <- pos + 1
      }
      
      out <- c(out, pick(pool, count))
      
    } else if (ch == "\\" && pos < n) {
      
      # Escaped literal, e.g. \.
      
      out <- c(out, at(pos + 1))
      pos <- pos + 2
      
    } else {
      
      # Literal character
      
      out <- c(out, ch)
      pos <- pos + 1
    }
  }
  
  paste(out, collapse = "")
}


generate_sample_dataset <- function(fields, n = 10) {
  
  sample_data <- list()
  
  for (field in fields) {
    
    name <- field$field
    type <- field$type
    
    # Options ------------------------------------------------------------------------
    
    if (identical(type, "options")) {
      
      sample_data[[name]] <- pick(
        as.character(unlist(field$options, use.names = FALSE)),
        n
      )
      
      # Numeric ------------------------------------------------------------------------
      
    } else if (identical(type, "numeric")) {
      
      lower <- num_or(field$lowerlimit, 0)
      upper <- num_or(field$upperlimit, 100)
      
      if (lower > upper) {
        stop(
          "Lower limit exceeds upper limit for variable '", name, "'.",
          call. = FALSE
        )
      }
      
      if (isFALSE(flag(field$allow_decimals))) {
        
        lower <- ceiling(lower)
        upper <- floor(upper)
        
        if (lower > upper) {
          stop(
            "No whole numbers fit the range for variable '", name, "'.",
            call. = FALSE
          )
        }
        
        values <- lower + floor(runif(n) * (upper - lower + 1))
        
        # Strings avoid write_csv turning 100000 into 1e+05
        sample_data[[name]] <- formatC(values, format = "f", digits = 0)
        
      } else {
        
        min_decimals <- num_or(field$min_decimals, 0)
        max_decimals <- max(
          min_decimals,
          num_or(field$max_decimals, max(min_decimals, 2))
        )
        
        decimals <- pick(min_decimals:max_decimals, n)
        
        values <- runif(n, lower, upper)
        
        # Truncate so a value never exceeds the upper limit
        values <- floor(values * 10^decimals) / 10^decimals
        values <- pmax(values, ceiling(lower * 10^decimals) / 10^decimals)
        
        # Formatted strings keep trailing zeros (3.50 stays 3.50)
        sample_data[[name]] <- unname(
          mapply(
            function(value, digits) {
              formatC(value, format = "f", digits = digits)
            },
            values,
            decimals
          )
        )
      }
      
      # String -------------------------------------------------------------------------
      
    } else if (identical(type, "string")) {
      
      format <- if (is.null(field$format)) "open" else field$format
      
      len <- string_length(field)
      
      if (identical(format, "capitalized")) {
        
        # ValidateString requires no lowercase letters for "capitalized"
        sample_data[[name]] <- replicate(n, rand_text(len, LETTERS))
        
      } else if (identical(format, "regex")) {
        
        pattern <- field$pattern
        
        if (is.null(pattern) || length(pattern) != 1 || is.na(pattern)) {
          stop("Variable '", name, "' has no pattern.", call. = FALSE)
        }
        
        # Remove regex anchors
        
        body <- sub("^\\^", "", pattern)
        body <- sub("\\$$", "", body)
        
        values <- replicate(n, generate_regex_value(body, name))
        
        # Verify generated values against the original regex
        
        if (!all(grepl(pattern, values, perl = TRUE))) {
          stop(
            "Could not generate valid sample values for regex variable '",
            name, "'.",
            call. = FALSE
          )
        }
        
        sample_data[[name]] <- values
        
      } else {
        
        # Open and lowercase strings
        sample_data[[name]] <- replicate(n, rand_text(len, letters))
      }
      
      # Unknown field type -------------------------------------------------------------
      
    } else {
      
      stop("Unknown field type for variable '", name, "'.", call. = FALSE)
    }
  }
  
  # Keeps column names such as "Participant ID" intact
  tibble::as_tibble(sample_data, .name_repair = "minimal")
}

# Certified CSV signing and verification ---------------------------------------------------

# Same formula the app has always used, so existing certified files keep verifying.
generate_download_code <- function(lab_id, study, study_format, csv_contents, secret_key) {
  
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


# Reads "LabID_Study_Format_CODE.csv" and returns the parts it can recover.
# Returns NULL when the name does not look like a certified file.
parse_certified_filename <- function(filename) {
  
  if (is.null(filename) || length(filename) != 1 || is.na(filename)) {
    return(NULL)
  }
  
  base <- sub("\\.csv$", "", basename(filename), ignore.case = TRUE)
  parts <- strsplit(base, "_", fixed = TRUE)[[1]]
  
  if (length(parts) < 4) {
    return(NULL)
  }
  
  code <- tolower(parts[length(parts)])
  
  if (!grepl("^[0-9a-f]{16}$", code)) {
    return(NULL)
  }
  
  middle <- parts[2:(length(parts) - 1)]
  
  list(
    lab_id = parts[1],
    code = code,
    study_guess = if (length(middle) == 2) middle[1] else NA_character_,
    format_guess = if (length(middle) == 2) middle[2] else NA_character_,
    middle = paste(middle, collapse = "_")
  )
}


# Checks a certified CSV against the server's secret key.
# csv_contents is the raw bytes of the file exactly as uploaded.
verify_download_code <- function(lab_id, study, study_format, csv_contents, claimed_code, secret_key) {
  
  fail <- function(reason) list(verified = FALSE, reason = reason)
  
  lab_id <- trimws(lab_id)
  claimed_code <- tolower(trimws(claimed_code))
  
  if (!nzchar(lab_id) || !grepl("^[A-Za-z0-9-]+$", lab_id)) {
    return(fail("The Lab ID is missing or contains characters that are not allowed."))
  }
  
  if (is.null(study) || is.na(study) || !nzchar(trimws(study)) ||
      is.null(study_format) || is.na(study_format) || !nzchar(trimws(study_format))) {
    return(fail("Study and format are required."))
  }
  
  if (!grepl("^[0-9a-f]{16}$", claimed_code)) {
    return(fail("The code in the file name is not a valid 16-character code."))
  }
  
  if (is.null(secret_key) || !nzchar(secret_key)) {
    return(fail("The server has no signing key configured."))
  }
  
  expected <- tryCatch(
    generate_download_code(
      lab_id = lab_id,
      study = trimws(study),
      study_format = trimws(study_format),
      csv_contents = csv_contents,
      secret_key = secret_key
    ),
    error = function(e) NA_character_
  )
  
  if (is.na(expected)) {
    return(fail("The file could not be read as text."))
  }
  
  if (identical(expected, claimed_code)) {
    list(verified = TRUE, reason = "")
  } else {
    list(
      verified = FALSE,
      reason = paste(
        "The code does not match. The file was changed after it was certified,",
        "or the Lab ID, study or format is not the one it was certified with."
      )
    )
  }
}

# Suggested fixes --------------------------------------------------------------------------

# Looks at the cells that currently fail validation and proposes mechanical corrections.
# Nothing is changed here: the result is a table of proposals that a person reviews and
# approves. A proposal is only returned if the proposed value passes ALL of the field's own
# checks. NA and empty cells are never touched. A field with `auto_fix: no` is skipped.
#
# Each proposal has a confidence:
#   "safe"  - only the way the value is written changes, not what it says
#   "check" - a judgement call (yes/no synonyms, restored leading zeros) that a person must
#             look at individually
#
# Fixes tried (smallest change first):
#   all fields   : unusual characters (non-breaking spaces, zero-width characters), leading and
#                  trailing spaces, repeated spaces
#   options      : match ignoring capitalization; match ignoring spacing, punctuation and
#                  accents; yes/no synonyms (check)
#   string       : the capitalization the specification requires; for regex fields, a case or
#                  spacing variant when exactly one variant fits the pattern; restored
#                  leading zeros when exactly one length fits (check)
#   numeric      : decimal comma; special minus signs andfull-width digits; trailing zeros removed or added
#
# Values like "1,234" are not changed, because the comma could be a thousands separator.

fix_strip_accents <- function(x) {
  
  from <- intToUtf8(c(0xe0:0xe5, 0xe7:0xef, 0xf1:0xf6, 0xf9:0xfd, 0xff))
  to <- paste0("aaaaaa", "ceeeeiiii", "nooooo", "uuuuy", "y")
  
  chartr(from, to, tolower(x))
}

# Spacing, punctuation, accents and capitalization removed, for comparing option names
fix_key <- function(x) {
  gsub("[^a-z0-9]", "", fix_strip_accents(x))
}

# Replaces every character with the given Unicode code points by `with`
fix_replace_chars <- function(x, codes, with) {
  
  for (ch in intToUtf8(codes, multiple = TRUE)) {
    x <- gsub(ch, with, x, fixed = TRUE)
  }
  
  x
}

# Candidate fixes for one cell, in order of preference
fix_candidates <- function(v, field) {
  
  type <- as.character(field$type)[1]
  format <- field$format
  options <- as.character(unlist(field$options, use.names = FALSE))
  
  out <- list()
  
  add <- function(value, reasons, confidence = "safe", mode = "ordered") {
    out[[length(out) + 1]] <<- data.frame(
      value = value,
      reason = paste(reasons, collapse = "; "),
      confidence = confidence,
      mode = mode,
      stringsAsFactors = FALSE
    )
  }
  
  cur <- v
  why <- character(0)
  
  # Unusual characters
  
  cleaned <- fix_replace_chars(cur, c(0xA0, 0x2007, 0x202F), " ")
  cleaned <- fix_replace_chars(cleaned, c(0x200B, 0x200C, 0x200D, 0xFEFF), "")
  
  if (identical(type, "numeric")) {
    cleaned <- fix_replace_chars(cleaned, c(0x2212, 0x2013, 0x2014), "-")
    cleaned <- chartr(intToUtf8(0xFF10:0xFF19), "0123456789", cleaned)
    cleaned <- fix_replace_chars(cleaned, 0xFF0E, ".")
    cleaned <- fix_replace_chars(cleaned, 0xFF0C, ",")
  }
  
  if (!identical(cleaned, cur)) {
    cur <- cleaned
    why <- c(why, "Replaced unusual characters (such as non-breaking spaces or special minus signs)")
  }
  
  # Spaces
  
  trimmed <- trimws(cur)
  if (!identical(trimmed, cur)) {
    cur <- trimmed
    why <- c(why, "Removed leading or trailing spaces")
  }
  
  collapsed <- gsub("[[:space:]]{2,}", " ", cur)
  if (!identical(collapsed, cur)) {
    cur <- collapsed
    why <- c(why, "Collapsed repeated spaces")
  }
  
  if (length(why) > 0) {
    add(cur, why)
  }
  
  # Options
  
  if (identical(type, "options")) {
    
    m <- unique(options[tolower(options) == tolower(cur)])
    
    if (length(m) == 1) {
      
      if (!identical(m, cur)) {
        add(m, c(why, sprintf("Matches the allowed option \"%s\" apart from capitalization", m)))
      }
      
    } else if (length(m) == 0) {
      
      key <- fix_key(cur)
      
      if (nzchar(key)) {
        
        km <- unique(options[fix_key(options) == key])
        
        if (length(km) == 1) {
          add(km, c(why, sprintf(
            "Matches the allowed option \"%s\" apart from capitalization, spacing or accents", km)))
        }
      }
      
      if (length(options) == 2) {
        
        lo <- tolower(options)
        yes_opt <- options[lo %in% c("yes", "true")]
        no_opt <- options[lo %in% c("no", "false")]
        
        if (length(yes_opt) == 1 && length(no_opt) == 1) {
          
          lc <- tolower(cur)
          
          if (lc %in% c("y", "t", "1", "yes", "true")) {
            add(yes_opt, c(why, sprintf("Read as the yes option \"%s\"", yes_opt)), "check")
          } else if (lc %in% c("n", "f", "0", "no", "false")) {
            add(no_opt, c(why, sprintf("Read as the no option \"%s\"", no_opt)), "check")
          }
        }
      }
    }
  }
  
  # Strings
  
  if (identical(type, "string")) {
    
    if (identical(format, "capitalized")) {
      
      up <- toupper(cur)
      if (!identical(up, cur)) add(up, c(why, "The specification requires upper case"))
      
    } else if (identical(format, "uncapitalized")) {
      
      low <- tolower(cur)
      if (!identical(low, cur)) add(low, c(why, "The specification requires lower case"))
      
    } else if (identical(format, "regex")) {
      
      nospace <- gsub("[[:space:]]", "", cur)
      
      variants <- unique(c(
        toupper(cur), tolower(cur), nospace, toupper(nospace), tolower(nospace)
      ))
      variants <- variants[variants != cur]
      
      for (vv in variants) {
        add(vv, c(why, "Capitalization or spacing changed to match the required pattern"),
            "safe", "unique")
      }
    }
    
    # Restored leading zeros (only if exactly one length fits)
    
    if (grepl("^[0-9]+$", cur)) {
      for (extra in 1:8) {
        add(paste0(strrep("0", extra), cur), c(why, "Leading zeros restored"),
            "check", "unique")
      }
    }
  }
  
  # Numbers
  
  if (identical(type, "numeric")) {
    
    s <- cur
    swhy <- why
    
    if (grepl("^-?[0-9]+,[0-9]+$", s) && !grepl(",[0-9]{3}$", s)) {
      s <- sub(",", ".", s, fixed = TRUE)
      swhy <- c(swhy, "Decimal comma changed to a decimal point")
    }
    
    
    if (!identical(s, cur)) {
      add(s, swhy)
    }
    
    if (grepl("^-?[0-9]+(\\.[0-9]*)?$", s)) {
      
      int <- sub("\\..*$", "", s)
      dec <- if (grepl(".", s, fixed = TRUE)) sub("^[^.]*\\.", "", s) else ""
      
      # Trailing zeros removed (never removes a non-zero digit)
      
      if (nchar(dec) > 0) {
        
        for (n in (nchar(dec) - 1):0) {
          
          if (grepl("[^0]", substr(dec, n + 1, nchar(dec)))) break
          
          shorter <- if (n == 0) int else paste0(int, ".", substr(dec, 1, n))
          
          add(shorter, c(swhy, "Trailing zeros removed (the value is unchanged)"))
        }
      }
      
      # Trailing zeros added (the value is unchanged)
      
      for (n in 1:6) {
        
        longer <- paste0(int, ".", dec, strrep("0", n))
        
        add(longer, c(swhy, "Trailing zeros added to reach the required number of decimal places (the value is unchanged)"))
      }
    }
  }
  
  if (length(out) == 0) {
    return(data.frame(value = character(0), reason = character(0),
                      confidence = character(0), mode = character(0),
                      stringsAsFactors = FALSE))
  }
  
  do.call(rbind, out)
}


suggest_fixes <- function(fields, dataset_contents) {
  
  empty <- data.frame(
    row = integer(0),
    column = character(0),
    current = character(0),
    proposed = character(0),
    reason = character(0),
    confidence = character(0),
    stringsAsFactors = FALSE
  )
  
  if (is.null(dataset_contents) || length(fields) == 0) {
    return(empty)
  }
  
  found <- list()
  
  for (field in fields) {
    
    col <- as.character(field$field)
    
    if (!(col %in% names(dataset_contents))) next
    if (identical(flag(field$auto_fix), FALSE)) next
    
    x <- as.character(dataset_contents[[col]])
    
    res <- validate_dataset_field(dataset_contents, field)
    if (isTRUE(res[[1]])) next
    
    rows <- res[[2]]$invalid_row
    rows <- rows[!is.na(x[rows]) & x[rows] != ""]
    if (length(rows) == 0) next
    
    pool <- list()
    
    for (k in seq_along(rows)) {
      
      cand <- fix_candidates(x[rows[k]], field)
      
      if (nrow(cand) > 0) {
        cand$cell <- k
        pool[[length(pool) + 1]] <- cand
      }
    }
    
    if (length(pool) == 0) next
    
    pool <- do.call(rbind, pool)
    pool <- pool[pool$value != x[rows[pool$cell]], , drop = FALSE]
    if (nrow(pool) == 0) next
    
    # Keep only candidates that pass every check the field has
    
    test <- data.frame(pool$value, stringsAsFactors = FALSE)
    names(test) <- col
    
    chk <- validate_dataset_field(test, field)
    still_bad <- if (isTRUE(chk[[1]])) integer(0) else chk[[2]]$invalid_row
    
    pool <- pool[!(seq_len(nrow(pool)) %in% still_bad), , drop = FALSE]
    if (nrow(pool) == 0) next
    
    # One proposal per cell: the first passing "ordered" candidate, otherwise the single
    # passing "unique" candidate
    
    picked <- lapply(split(seq_len(nrow(pool)), pool$cell), function(ix) {
      
      sub <- pool[ix, , drop = FALSE]
      
      ord <- sub[sub$mode == "ordered", , drop = FALSE]
      if (nrow(ord) > 0) return(ord[1, , drop = FALSE])
      
      uni <- sub[sub$mode == "unique", , drop = FALSE]
      if (length(unique(uni$value)) == 1) return(uni[1, , drop = FALSE])
      
      NULL
    })
    
    picked <- do.call(rbind, picked)
    if (is.null(picked) || nrow(picked) == 0) next
    
    picked <- picked[order(picked$cell), , drop = FALSE]
    
    found[[length(found) + 1]] <- data.frame(
      row = as.integer(rows[picked$cell]),
      column = col,
      current = x[rows[picked$cell]],
      proposed = picked$value,
      reason = picked$reason,
      confidence = picked$confidence,
      stringsAsFactors = FALSE
    )
  }
  
  if (length(found) == 0) {
    return(empty)
  }
  
  out <- do.call(rbind, found)
  rownames(out) <- NULL
  out
}


# Applies the proposals a person approved. A proposal is skipped if the cell no longer holds
# the value it was made for (for example because it was edited in the meantime).
# Returns the new dataset and the proposals that were actually applied.
apply_fixes <- function(dataset_contents, fixes) {
  
  if (is.null(dataset_contents) || is.null(fixes) || nrow(fixes) == 0) {
    return(list(data = dataset_contents, applied = fixes[0, , drop = FALSE]))
  }
  
  done <- logical(nrow(fixes))
  
  for (i in seq_len(nrow(fixes))) {
    
    col <- fixes$column[i]
    r <- fixes$row[i]
    
    if (!(col %in% names(dataset_contents))) next
    if (is.na(r) || r < 1 || r > nrow(dataset_contents)) next
    
    now <- as.character(dataset_contents[[col]][r])
    
    if (!is.na(now) && identical(now, fixes$current[i])) {
      dataset_contents[[col]][r] <- fixes$proposed[i]
      done[i] <- TRUE
    }
  }
  
  list(data = dataset_contents, applied = fixes[done, , drop = FALSE])
}