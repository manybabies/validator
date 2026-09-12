# ManyBabies Data Validator

* (Current version: 2.0.0, Sept 11, 2026)

A Shiny application for validating individual lab datasets against study-specific data specifications.

## Table of Contents

1. [User Manual - For Data Contributor](#1-user-manual---for-data-contributor)
2. [User Manual - For Project Leads](#2-user-manual---for-project-leads)
3. [User Manual - Developer Documentation](#3-user-manual---for-developers)
4. [Files and Folder Structure](#4-files-and-folder-structure)

---

## 1. User Manual - For Data Contributor

This section details instructions on how to use the validator as a lab contributing data to an MB project. The data validator allows you to check whether your dataset meets the formatting and data requirements for a particular project before submitting it.

You do not need to modify any code or understand how the validator works behind the scenes (you don't even need to download R)! A live version of the validator is hosted [here](https://manybabies.shinyapps.io/validator/). Simply select the appropriate study and specification, upload your dataset, and follow the validation results.

<details>
<summary><strong>Before you begin</strong></summary>

Before using the validator, here are a few pre-checks you should do:

* your dataset is saved as a `.csv` file
* you know which project specification you should check against
* your column names have not been changed from those expected by the project/provided template

</details>

<details>
<summary><strong>Step 1: Open the validator and select your project</strong></summary>

Go to the [live version of the validator](https://manybabies.shinyapps.io/validator/). Select the study and study format that you are contributing data to from the drop-down menu on the left.

![](images_for_readme/step_1.png)

</details>

<details>
<summary><strong>Step 2: Verify that you are using the correct specifications</strong></summary>

Each project has its own specification that defines which variables are expected and what values or formats are permitted. Click on the Specification tab, and check that you are using the correct specifications.

![](images_for_readme/step_2.png)

</details>

<details>
<summary><strong>Step 3: Upload your dataset</strong></summary>

Click "Browse..." to select and upload your `.csv` dataset. The validator will compare your dataset against the selected project specification.

![](images_for_readme/step_3.png)

</details>

<details>
<summary><strong>Step 4: Review the validation results</strong></summary>

On the Validation Results tab, you will be able to see any errors identified by the validator. You can either view the errors by column (i.e. see which rows/observations are incorrect for given column X) or by row (i.e. see which columns are incorrect for given row/observation X). For each error, the validator will remind you of the specification for that particular column. Depending on how the specification was set up, it might not be able to pinpoint *exactly* what is wrong. Please consult your specific project manual or codebook, or contact your project lead if you are unsure what is causing the error. **Please do not ignore errors and submit datasets that did not pass validation**.

There will be a preview table of the dataset with incorrect cells highlighted.

![](images_for_readme/step_4.png)

</details>

<details>
<summary><strong>Step 5: Correct your dataset</strong></summary>

Use the validation results to identify and correct the errors in your original dataset. You can press the "Download Highlighted File" button to download a `.xlsx` file with these highlights to facilitate correcting your dataset. **Note: the downloaded file is in `.xlsx` format to preserve the highlights, but you must save the file as a `.csv` before trying to validate again!**

</details>

<details>
<summary><strong>Step 6: Validate your dataset again</strong></summary>

After making corrections, upload the revised dataset and run the validator again.

Repeat this process until your dataset passes validation.

</details>

<details>
<summary><strong>When your dataset passes</strong></summary>

Once the validator reports that your dataset is valid, it meets the requirements defined by the selected project specification and is ready for submission.

</details>

---

## 2. User Manual - For Project Leads

Project leads are responsible for creating and maintaining the specification that defines what a valid dataset should look like for their project.

The specification is written as a **YAML file** and contains the expected fields, data types, and validation rules for the project. Once the specification has been created, data contributors can use it to validate their datasets without needing to know the project's specific validation requirements.

**Important Note:** As of version 2.0, project leads no longer need to know how to make a `.yaml` from scratch. You can use the built-in Specification Creation feature available in the [live version of the validator](https://manybabies.shinyapps.io/validator/). This section contains instructions on using this feature; for details on the `.yaml` file, please see the [Developer Documentation](#3-user-manual---for-developers).

### Creating a new specification

<details>
<summary><strong>Step 1: Open Specification Creation</strong></summary>

Open the **Specification Creation** feature in the application, and select how many variables you want to create. Note that you can change this later, but **decreasing the number of variables will erase part of your progress**.

![](images_for_readme/SC_step1.png)

</details>

<details>
<summary><strong>Step 2: Define your variables</strong></summary>

There are three parts you need to define: Variable Information (left), Data Type (middle), and Settings (right).

![](images_for_readme/SC_step2.png)

For each variable/column in your dataset, first choose and enter:

* the **Variable/column name** — the exact name of the column in the dataset
* a **Description** of the variable (optional, but useful)
* whether the field is **required**
* whether **missing values (`NA`) are allowed**
* an optional **custom error message** (you can leave this blank, and the validator will autogenerate one for you)

</details>

<details>
<summary><strong>Step 3: Select the data type</strong></summary>

Choose the type of validation that should be applied to the variable.

The validator supports:

* **Options** — when a variable must contain one of a predefined set of values
* **Numeric** — when a variable must contain numeric values
* **String** — when a variable contains text

Depending on the selected type, the Specification Creation feature will provide additional options for defining the validation requirements.

</details>

<details>
<summary><strong>Step 4: Define validation requirements</strong></summary>

Specify the restrictions that should apply to each variable.

For example, an `options` variable can be restricted to a defined set of values:

```text
condition
    experimental
    control
```

A numeric variable can be restricted by:

* minimum value
* maximum value
* whether decimals are allowed
* minimum number of decimal places
* maximum number of decimal places

A string variable can be restricted by:

* capitalization
* minimum character length
* maximum character length
* a regular expression pattern

Only specify restrictions that are appropriate for the variable. If a particular restriction does not apply, leave it unset.

</details>

<details>
<summary><strong>Step 5: Review your specification</strong></summary>

Before creating the specification, review the variables and validation requirements you have entered.

Pay particular attention to:

* spelling and capitalization of field names
* required fields
* whether `NA` values are allowed
* permitted option values
* numeric ranges
* decimal restrictions
* string length restrictions
* regular expression patterns

The field names in the specification must exactly match the column names expected in contributors' datasets.

</details>

<details>
<summary><strong>Step 6: Download your specification</strong></summary>

Once the specification is complete, press **Download Setup** to download the `.yaml` file.

**Important:** Please save your `.yaml` file following the conventional naming scheme:

```text
ManyBabies_project_format.yaml
```

For example, if you are creating a specification for the MB8 project, and the validation is for the subjects-level data, you could name it:

```text
ManyBabies_MB8_subjects.yaml
```

This naming scheme means MB8 will be listed under the "Study" dropdown, and "subjects" will be presented as an option in the "Study Format" dropdown.

</details>

<details>
<summary><strong>Step 7: Submit your specification to the developer(s)</strong></summary>

Before distributing the specification to data contributors, you should verify that your specification works. Please email the developer, [Francis Yuen](francis.yuen@psych.ubc.ca), the following three files:

* your project `.yaml`
* a dataset containing **only valid values**
* a dataset containing **intentional errors**, ideally ones you anticipate will be common

The developer will test your specifications and notify you when your specification is added to the live version.

</details>

---

## 3. User Manual - For Developers

The **Back-end Developer Documentation** provides detailed information about the underlying code of the validator. Note that this section is identical to that of the base version, [ShinyValidator](https://github.com/manybabies/ShinyValidator), as they share the same underlying infrastructure.

This section is intended for researchers and developers who wish to add new functions, modify existing functionality, or otherwise customize the validator beyond the options described in Section 2.

If you only want to create a validator for your own project, you generally do not need to modify the code described in this section.

---

<details>
<summary><strong>3.1 Application architecture</strong></summary>

The validator is organized across five primary R files:

| File             | Purpose                                            |
| ---------------- | -------------------------------------------------- |
| `app.R`          | Application initialization and launch              |
| `ui.R`           | User interface, layout, and styling                |
| `server.R`       | Server-side application logic and reactive outputs |
| `common.R`       | Shared functions and dataset validation            |
| `ErrorHandler.R` | Error handling and downloadable validation reports |

The validator also relies on two important collections of YAML files:

| Folder                 | Purpose                                                    |
| ---------------------- | ---------------------------------------------------------- |
| `configuration/`       | Defines application-level settings and user-facing content |
| `data_specifications/` | Defines study- and format-specific dataset requirements    |

The general relationship between these components is:

```text
Configuration
     │
     ├── Application title
     ├── Instructions
     ├── Links
     └── Specification message
     │
     ▼
Selected configuration
     │
     ▼
Study + Format
     │
     ▼
Data specification
     │
     ▼
Uploaded CSV
     │
     ▼
validate_dataset()
     │
     ├── Validation Results
     ├── Validation Preview
     ├── Error Display
     └── Highlighted Excel Download
```

</details>

<details>
<summary><strong>3.2 Configuration system</strong></summary>

The configuration system allows the same Shiny application code to support multiple projects or study collections.

Configuration files are stored in:

```text
configuration/
```

and must begin with:

```text
config_
```

For example:

```text
config_default.yaml
config_ManyBabies.yaml
```

`ui.R` identifies available configuration files automatically using the filename pattern:

```r
^config_.+\.(yaml|yml)$
```

The selected configuration is loaded reactively in `server.R`.

The configuration determines application-level content such as:

```yaml
app_title:
welcome_message:
secondary_message:
instruction_set_1_name:
instruction_set_1:
links:
instruction_set_2_name:
instruction_set_2:
specification_message:
```

This approach means that user-facing content can be changed without modifying the application logic.

### Configuration-specific specifications

Specifications are associated with configurations through their filenames.

For a configuration:

```text
config_ManyBabies.yaml
```

a corresponding specification might be:

```text
ManyBabies_MB1_subjects.yaml
```

The configuration name is extracted from the configuration filename and used by `server.R` to identify the appropriate specifications.

This prevents specifications belonging to different projects from being mixed together.

</details>

<details>
<summary><strong>3.3 app.R</strong></summary>

`app.R` is the entry point for the Shiny application. It:

1. Loads the core application components.
2. Sources `ui.R` and `server.R`.
3. Launches the application with `shinyApp()`.

The file generally does not need to be modified when adapting the validator.

If additional R files are added, they should generally be sourced from the appropriate component file rather than directly from `app.R`.

</details>

<details>
<summary><strong>3.4 ui.R</strong></summary>

`ui.R` defines the application's user interface, layout, and visual styling.

The sidebar provides:

* configuration selection;
* study selection;
* format selection;
* CSV upload; and
* navigation between the validator functions.

The main panel contains four functions:

* **Validation Results**
* **Specification Details**
* **Specification Creation**
* **Configuration Creation**

### Dynamic UI

Several parts of the interface are generated dynamically using `uiOutput()` and server-side `renderUI()` calls.

Examples include:

* study selection;
* study format selection;
* configuration creation fields;
* specification creation variable tabs;
* validation errors;
* specification details.

### JavaScript components

A small JavaScript component in `ui.R` updates dynamically generated labels in the specification and configuration creation interfaces.

For example, variable tabs are automatically renamed as users enter variable names.

The configuration creation interface also updates the displayed instruction-set headings when users change the names of Instruction Set 1 or Instruction Set 2.

These JavaScript components should generally be left unchanged unless the corresponding UI elements are modified.

### Styling

The application uses custom CSS in `ui.R` to provide:

* application header styling;
* content cards;
* purple accent colors;
* styled navigation;
* form controls;
* buttons;
* validation tables; and
* other visual elements.

The application also uses `shinythemes` for the base theme and `DT` for interactive validation tables.

</details>

<details>
<summary><strong>3.5 server.R</strong></summary>

`server.R` contains the server-side logic for the application. It connects UI inputs to the validation functions in `common.R` and generates the application's outputs.

### Configuration loading

The selected configuration is loaded using a reactive expression:

```r
selected_config <- reactive({
  req(input$configuration)
  yaml::read_yaml(
    file.path("configuration", input$configuration)
  )
})
```

The configuration name is also extracted from the selected filename so that the appropriate data specifications can be identified.

### Study and format selection

Available specifications are determined from the selected configuration.

For example, if the selected configuration is:

```text
ManyBabies
```

the application searches for specifications beginning with:

```text
ManyBabies_
```

This allows different configurations to have different collections of studies and formats.

### Main server components

`server.R` contains logic for:

* loading the selected configuration;
* identifying available specifications;
* generating study and format selectors;
* displaying configuration-specific instructions;
* displaying specification details;
* validating uploaded datasets;
* displaying errors by column or row;
* generating the validation preview;
* generating highlighted Excel downloads;
* creating specification fields dynamically;
* creating configuration fields dynamically;
* generating downloadable YAML specifications; and
* generating downloadable YAML configurations.

### Validation workflow

The main validation outputs follow this general workflow:

1. Identify the selected configuration.
2. Identify the selected study and format.
3. Construct the corresponding specification filename.
4. Load the YAML specification.
5. Read the uploaded CSV dataset.
6. Pass the specification and dataset to `validate_dataset()` in `common.R`.
7. Process the returned issues.
8. Display the results or generate the highlighted Excel file.

Configuration-specific specification paths generally follow:

```r
yaml_file_path <- paste0(
  "data_specifications/",
  selected_configuration_name(),
  "_",
  input$study,
  "_",
  input$format,
  ".yaml"
)
```

It is important that all validation-related outputs use this same configuration-aware naming structure.

</details>

<details>
<summary><strong>3.6 common.R</strong></summary>

`common.R` contains the core data-validation functions used by the application.

### Study and format discovery

Available specifications are identified from the YAML files stored in `data_specifications`.

The configuration name is used to distinguish specifications belonging to different configurations.

For example:

```text
ManyBabies_MB1_subjects.yaml
```

can be interpreted as:

| Component     | Value        |
| ------------- | ------------ |
| Configuration | `ManyBabies` |
| Study         | `MB1`  |
| Format        | `subjects`    |

Adding a correctly named specification automatically makes it available to the corresponding configuration.

### Dataset validation

`validate_dataset()` is the main validation function. It:

1. Checks that all required columns are present.
2. Passes each existing field to `validate_dataset_field()`.
3. Collects validation issues.
4. Returns whether the dataset is valid and, if not, a list of issues.

`validate_dataset_field()` determines which validation function should be used based on the field specification.

| Field type | Validation function                     |
| ---------- | --------------------------------------- |
| `options`  | `ValidateOption()`                      |
| `numeric`  | `ValidateNumeric()`                     |
| `string`   | `ValidateString()` or `ValidateRegex()` |

### Validation functions

The individual validation functions perform the following checks:

* **`ValidateOption()`** — checks whether values match one of the allowed options.
* **`ValidateNumeric()`** — checks numeric values, ranges, decimal restrictions, and decimal places.
* **`ValidateString()`** — checks capitalization and character-length restrictions.
* **`ValidateRegex()`** — checks values against a specified regular expression.
* **`GenerateRegex()`** — generates a regular expression from compatible example values.

All validation functions return the same basic structure:

```r
list(TRUE, NULL)
```

when the field is valid, or:

```r
list(FALSE, issue)
```

when an error is detected.

Issues contain information such as the error type, column, invalid value, and row number. This standardized structure allows the server and error-handling components to process validation errors consistently.

### Error explanations

`explain_error()` converts validation issues into user-facing explanations.

It uses the field specification to describe the relevant requirement while allowing individual fields to provide a custom `error_message`.

### Developer notes

When adding a new validation function, maintain the existing return structure and include the affected column and row information in the issue object.

If adding a new field type, update `validate_dataset_field()` so that the new type is routed to the appropriate validation function.

</details>

<details>
<summary><strong>3.7 ErrorHandler.R</strong></summary>

`ErrorHandler.R` contains the functions used to generate downloadable Excel validation reports.

### `highlight_csv_to_xlsx()`

`highlight_csv_to_xlsx()` takes the uploaded dataset and the validation issues returned by `validate_dataset()` and creates an Excel workbook containing:

* **Data** — the original dataset, with invalid cells highlighted.
* **Error Log** — a record of missing columns and invalid cells, including the row, column, and invalid value where applicable.

Missing columns are recorded in the error log but cannot be highlighted in the dataset because the column does not exist.

The function returns an `openxlsx` workbook object, which is saved by the download handler in `server.R`.

### Developer notes

If new issue types are added to `common.R`, update `highlight_csv_to_xlsx()` if those issues should appear in the downloadable error report.

</details>

---

## 4. File and Folder Structure

A typical ShinyValidator project contains the following structure:

```text
ShinyValidator/
│
├── app.R
├── ui.R
├── server.R
├── common.R
├── ErrorHandler.R
├── ShinyValidator.Rproj
│
├── configuration/
│   ├── config_default.yaml
│   └── config_ManyBabies.yaml
│
├── data_specifications/
│   ├── ManyBabies_StudyA_Format1.yaml
│   └── ManyBabies_StudyB_Format1.yaml

```

The most important distinction is:

**Configurations define how the validator behaves and what it tells the user.**

**Specifications define what the user's dataset must contain.**

This separation allows the same application code to be reused across different projects.

---

# Summary of the Recommended Workflow

For most users, creating a new validator should require little or no R programming.

The recommended workflow is:

```text
1. Download ShinyValidator
          ↓
2. Run the app locally
          ↓
3. Create a configuration
          ↓
4. Create one or more specifications
          ↓
5. Add specifications to data_specifications/
          ↓
6. Test with sample datasets
          ↓
7. Customize the UI if necessary
          ↓
8. Deploy locally or to shinyapps.io
```

The **Configuration Creation** and **Specification Creation** functions are intended to handle most customization needs. Direct modification of `ui.R`, `server.R`, or `common.R` should generally only be necessary when adding functionality beyond the existing template.
