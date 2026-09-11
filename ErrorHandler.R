library(openxlsx)


highlight_csv_to_xlsx <- function(df, issues) {
  
  wb <- createWorkbook()
  
  data_sheet <- "Data"
  
  addWorksheet(
    wb,
    data_sheet
  )
  
  
  writeData(
    wb,
    sheet = data_sheet,
    x = df
  )
  
  
  # Highlight style
  highlight_style <- createStyle(
    fgFill = "yellow"
  )
  
  for (issue in issues) {
    
    if (is.null(issue)) {
      next
    }
    
    
    # Missing columns cannot have cells highlighted
    if (
      issue$type == "missing_column"
    ) {
      next
    }
    
    
    column_name <- issue$column
    
    # Check that the column exists
    if (!(column_name %in% names(df))) {
      next
    }
    
    
    column_index <- which(
      names(df) == column_name
    )
    
    
    rows <- issue$invalid_row
    
    
    if (length(rows) == 0) {
      next
    }
    
    
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
  
  error_sheet <- "Error Log"
  
  addWorksheet(
    wb,
    error_sheet
  )
  
  
  error_rows <- list()
  
  
  for (issue in issues) {
    
    if (is.null(issue)) {
      next
    }
    
    
    # Missing column
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
    
    
    # Invalid cells
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
    
    setColWidths(
      wb,
      sheet = error_sheet,
      cols = 1:4,
      widths = "auto"
    )
  }
  
  
  return(wb)
}