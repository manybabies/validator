library(openxlsx)


# Highlight validated dataset ----------------------------------------------------------

highlight_csv_to_xlsx <- function(df, issues) {
  
  
  # Workbook setup ----------------------------------------------------------------------
  
  wb <- createWorkbook()
  
  data_sheet <- "Data"
  
  addWorksheet(
    wb,
    data_sheet
  )
  
  
  # Write dataset -----------------------------------------------------------------------
  
  writeData(
    wb,
    sheet = data_sheet,
    x = df
  )
  
  
  # Create highlight style --------------------------------------------------------------
  
  highlight_style <- createStyle(
    fgFill = "yellow"
  )
  
  
  # Highlight invalid cells -------------------------------------------------------------
  
  for (issue in issues) {
    
    if (is.null(issue)) {
      next
    }
    
    
    # Skip missing columns --------------------------------------------------------------
    
    if (
      issue$type == "missing_column"
    ) {
      next
    }
    
    
    # Check that the column exists ------------------------------------------------------
    
    column_name <- issue$column
    
    if (!(column_name %in% names(df))) {
      next
    }
    
    
    # Identify column and rows ----------------------------------------------------------
    
    column_index <- which(
      names(df) == column_name
    )
    
    rows <- issue$invalid_row
    
    
    if (length(rows) == 0) {
      next
    }
    
    
    # Apply highlight -------------------------------------------------------------------
    
    addStyle(
      wb,
      sheet = data_sheet,
      style = highlight_style,
      rows = rows + 1,
      cols = column_index,
      gridExpand = FALSE,
      stack = TRUE
    )
  }
  
  
  # Create error log --------------------------------------------------------------------
  
  error_sheet <- "Error Log"
  
  addWorksheet(
    wb,
    error_sheet
  )
  
  error_rows <- list()
  
  
  # Build error log ---------------------------------------------------------------------
  
  for (issue in issues) {
    
    if (is.null(issue)) {
      next
    }
    
    
    # Missing column --------------------------------------------------------------------
    
    if (issue$type == "missing_column") {
      
      error_rows[[length(error_rows) + 1]] <- data.frame(
        Type = "Missing column",
        Row = NA,
        Column = issue$column,
        Value = NA,
        stringsAsFactors = FALSE
      )
      
      next
    }
    
    
    # Invalid cells ---------------------------------------------------------------------
    
    if (issue$type == "invalid_cell") {
      
      for (i in seq_along(issue$invalid_row)) {
        
        error_rows[[length(error_rows) + 1]] <- data.frame(
          Type = "Invalid cell",
          Row = issue$invalid_row[i],
          Column = issue$column,
          Value = as.character(
            issue$invalid_value[i]
          ),
          stringsAsFactors = FALSE
        )
      }
    }
  }
  
  
  # Write error log ---------------------------------------------------------------------
  
  if (length(error_rows) > 0) {
    
    error_log <- do.call(
      rbind,
      error_rows
    )
    
    writeData(
      wb,
      sheet = error_sheet,
      x = error_log
    )
    
    
    # Adjust column widths --------------------------------------------------------------
    
    setColWidths(
      wb,
      sheet = error_sheet,
      cols = 1:4,
      widths = "auto"
    )
  }
  
  
  # Return workbook ---------------------------------------------------------------------
  
  return(wb)
}