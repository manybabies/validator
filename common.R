
# load specs
library(tidyverse)
studies <- data_frame(file = dir(path = "data_specifications")) %>%
  mutate(file = str_replace(file, ".yaml", "")) %>%
  separate(file, into = c("study","format"))


# this code based on github.com/langcog/metalab2/scripts/cache_datsets.R
# originally by Mika Braginksy (mikabr@mit.edu)

# Validate dataset's values for a given field
validate_dataset_field <- function(dataset_contents, field) {
  if (field$required) {
    if (field$field %in% names(dataset_contents)) {
      if (is.na(dataset_contents[[field$field]])){
        if(field$NA_allowed != TRUE){
          cat(sprintf("Dataset has blank required field: '%s'.\n",
                    field$field))
          return(FALSE)
        } else {
          return(TRUE)
        }
      }
      if (field$type == "options") {
        if (class(field$options) == "list") {
          options <- names(unlist(field$options, recursive = FALSE))
        } else {
          options <- field$options
        }
        invalid_values <- unique(dataset_contents[[field$field]]) %>%
          setdiff(options)
        if (!is.null(field$nullable) && field$nullable) {
          invalid_values <- na.omit(invalid_values)
        }
        if (length(invalid_values)) {
          for (value in invalid_values) {
            cat(sprintf("Dataset has invalid value '%s' for field '%s'.\n",
                        value, field$field))
          }
          return(FALSE)
        }
      } else if (field$type == "multiple_options"){
        if (class(field$options) == "list") {
          options <- names(unlist(field$options, recursive = FALSE))
        } else {
          options <- field$options
        }
        # Need to reprogram how dataset_contents are read off, to account for delimiters
        delimiter <- field$delimiter
        # Each line needs to be read off and split up into its own list.
        raw_field <- dataset_contents[[field$field]]
        invalid_values <- unique(dataset_contents[[field$field]]) %>%
          setdiff(options)
        if (!is.null(field$nullable) && field$nullable) {
          invalid_values <- na.omit(invalid_values)
        }
        if (length(invalid_values)) {
          for (value in invalid_values) {
            cat(sprintf("Dataset has invalid value '%s' for field '%s'.\n",
                        value, field$field))
          }
          return(FALSE)
        }
      } else if (field$type == "numeric") {
        field_contents <- dataset_contents[[field$field]]
        if (!(is.numeric(field_contents) || all(is.na(field_contents)))) {
          cat(sprintf("Dataset has wrong type for numeric field '%s'.\n",
                      field$field))
          return(FALSE)
        }
      } else if (field$type == "string"){
        if (field$format == "uncapitalized"){
          isCap = str_detect(field_contents, "[:upper:]")
          if (TRUE %in% isCap){
            return(FALSE)
          }
        } 
      } 
    } else {
      cat(sprintf("Dataset is missing required field: '%s'.\n",
                  field$field))
      return(FALSE)
    }
    
  } 
  return(TRUE)
}


# Validate dataset's values for all fields
validate_dataset <- function(fields, dataset_contents) {

  valid_fields <- map(fields, function(field) {
    validate_dataset_field(dataset_contents, field)
  })
  valid_dataset <- all(unlist(valid_fields))
  
  return(valid_dataset)
}


# # Manipulate a dataset's contents to prepare it for saving
# tidy_dataset <- function(fields, dataset_contents) {
#   
#   # Coerce each field's values to the field's type, discard any columns not in
#   # field spec, add NA columns for missing (optional) fields
#   dataset_data <- data_frame(row = 1:nrow(dataset_contents))
#   for (field in fields) {
#     if (field$field %in% names(dataset_contents)) {
#       if (field$type == "string") {
#         field_fun <- as.character
#       } else if (field$type == "numeric") {
#         field_fun <- as.numeric
#       } else {
#         field_fun <- function(x) x
#       }
#       dataset_data[,field$field] <- field_fun(dataset_contents[[field$field]])
#     } else {
#       dataset_data[,field$field] <- NA
#     }
#   }
# }
#   