# ManyBabies Data Validator 

- (Current version: 2.0.0, Sept 11, 2026)

A Shiny application for validating individual lab datasets against study-specific data specifications.

## Table of Contents

1. [User Manual - For Data Contributor](#1-user-manual---for-data-contributor)
2. [User Manual - For Project Leads](#2-user-manual---for-project-leads)
3. [User Manual - Developer Documentation](#3-developer-documentation)

## 1. User Manual - For Data Contributor

This section details instructions on how to use the validator as a lab contributing data to an MB project. The data validator allows you to check whether your dataset meets the formatting and data requirements for a particular project before submitting it.

You do not need to modify any code or understand how the validator works behind the scenes (you don't even need to download R)! A live version of the validator is hosted [here](https://manybabies.shinyapps.io/validator/). Simply select the appropriate study and specification, upload your dataset, and follow the validation results.

### Before you begin

Before using the validator, here are a few pre-checks you should do:

* your dataset is saved as a `.csv` file
* you know which project specification you should check against
* your column names have not been changed from those expected by the project/provided template

### Step 1: Open the validator and select your project

Go to the [live version of the validator](https://manybabies.shinyapps.io/validator/). Select the study and study format that you are contributing data to from the drop-down menu on the left.

![](images_for_readme/step_1.png)

### Step 2: Verify that you are using the correct specifications

Each project has its own specification that defines which variables are expected and what values or formats are permitted. Click on the Specification tab, and check that you are using the correct specifications.

![](images_for_readme/step_2.png)

### Step 3: Upload your dataset

Click "Browse..." to select and upload your `.csv` dataset. The validator will compare your dataset against the selected project specification.

![](images_for_readme/step_3.png)

### Step 4: Review the validation results

On the Validation Results tab, you will be able to see any errors identified by the validator. You can either view the errors by column (i.e. see which rows/observations are incorrect for given column X) or by row (i.e. see which columns are incorrect for given row/observation X). For each error, the validator will remind you of the specification for that particular column. Depending on how the specification was setup, it might not be able to pinpoint *exactly* what is wrong. Please consult your specific project manual or codebook, or contact your project lead if you are unsure what is causing the error. **Please do not ignore errors and submit datasets that did not pass validation**.

There will be a preview table of the dataset with incorrect cells highlighted. 

![](images_for_readme/step_4.png)

### Step 5: Correct your dataset

Use the validation results to identify and correct the errors in your original dataset. You can press the "Download Highlighted File" button to download a .xlsx file with these highlights to facilitate correcting your dataset. **Note: the downloaded file is in .xlsx format to preserve the highlights, but you must save the file as a .csv before trying to validate again!**

### Step 6: Validate your dataset again

After making corrections, upload the revised dataset and run the validator again.

Repeat this process until your dataset passes validation.

### When your dataset passes

Once the validator reports that your dataset is valid, it meets the requirements defined by the selected project specification and is ready for submission.

## 2. User Manual - For Project Leads

Project leads are responsible for creating and maintaining the specification that defines what a valid dataset should look like for their project.

The specification is written as a **YAML file** and contains the expected fields, data types, and validation rules for the project. Once the specification has been created, data contributors can use it to validate their datasets without needing to know the project's specific validation requirements.

**Important Note:** As of version 2.0, project leads no longer need to know how to make a .yaml from scratch. You can use the built-in Specification Creation feature available in the [live version of the validator](https://manybabies.shinyapps.io/validator/). This section contains instructions on using this feature; for details on the .yaml file, please see [3. User Manual - For Developers](#3-developer-documentation).

### Creating a new specification

#### Step 1: Open Specification Creation

Open the **Specification Creation** feature in the application, and select how many variables you want to create. Note that you can change this later, but **decreasing the number of variables will erase part of your progress**.

![](images_for_readme/SC_step1.png)

#### Step 2: Define your variables

There are three parts you need to define: Variable Information (left), Data Type (middle), and Settings (right)

![](images_for_readme/SC_step2.png)

For each variable/column in your dataset, first choose and enter:

* the **Variable/column name** — the exact name of the column in the dataset
* a **Description** of the variable (optional, but useful)
* whether the field is **required**
* whether **missing values (`NA`) are allowed**
* An optional custom error message (you can leave this blank, and the validator will autogenerate one for you)

#### Step 3: Select the data type

Choose the type of validation that should be applied to the variable.

The validator supports:

* **Options** — when a variable must contain one of a predefined set of values
* **Numeric** — when a variable must contain numeric values
* **String** — when a variable contains text

Depending on the selected type, the Specification Creation feature will provide additional options for defining the validation requirements.

#### Step 4: Define validation requirements

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

#### Step 5: Review your specification

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

#### Step 6: Download your specification

Once the specification is complete, press **Download Setup** to download the .yaml file.

**Important**: Please save your .yaml file following the conventional naming scheme:

project_format.yaml

For example, if you are creating a specification for the MB8 project, and the validation is for the subjects level data, you could name it:

MB8_subjects.yaml

This naming scheme means MB8 will be listed under the "Study" dropdown, and "subjects" will be presented as an option in the "Study Format" dropdown.

#### Step 7: Submit your specification to the developer(s)

Before distributing the specification to data contributors, you should verify that your specification works. Please email the developer, [Francis Yuen](francis.yuen@psych.ubc.ca), the following three files:

* your project .yaml
* a dataset containing **only valid values**
* a dataset containing **intentional errors**, ideally ones you anticipate will be common

The developer will test your specifications and notify you when your specification is added to the live version.


## 3. User Manual - For Developers (THIS SECTION IS INCOMPLETE)

The validator checks whether a dataset conforms to a predefined set of requirements, including:

- required variables
- permitted values
- numeric restrictions
- string formats
- regular-expression patterns (Regex)

Validation errors are reported at the level of individual cells, allowing researchers to identify and correct problems directly in their dataset. 

## Overview

The ManyBabies Data Validator intends to provide a standardized way of checking each lab's dataset before they are submitted, to ensure that datasets are compatible and mergable.

Validation rules are stored in **YAML specification files**. This allows new studies and datasets to be added by creating or modifying a specification file without changing the core validation functions.

To create new specification files, you can either manually create one using an existing file as a guide, or use the App's Specification Creation function.

The general workflow is:

1. Select the appropriate study/data specification.
2. Upload a dataset (must be .csv).
3. The validator compares the dataset against the specification.
4. Required columns and individual cells are checked.
5. Validation errors are identified and explained.
6. The researcher corrects the dataset and validates it again.

## Features

The validator currently supports both validation and specification creation.

### Validation Features

* Checking for required columns
* Identifying missing values in fields where `NA` is not permitted
* Validating variables against a predefined set of options
* Validating numeric variables, enforcing minimum and maximum numeric values, restricting whether decimal values are permitted, and the number of decimal places
* Validating strings according to capitalization requirements and string length
* Validating values against regular expressions (Regex)
* Reporting invalid values and their corresponding row numbers
* Providing human-readable explanations of validation errors
* Download copy of dataset with error values highlighted

### Specification Creation Features

* Auto-generating .yaml files without manual coding
* Generating regular expressions from example values
* Auto-generated error messages using the specification
* Custom error messages defined in the data specification

## Data Specifications

Each study has its own YAML specification file located in:

```text
data_specifications/
```

The specification describes the variables that are expected in the corresponding dataset and the rules that those variables must satisfy.

### Supported field types

#### `options`

Used when a variable can contain only a predefined set of values. For example, if a variable "condition" only has two options, "experimental" and "control":

```yaml
- field: condition
  description: experimental condition
  type: options
  options:
    - experimental
    - control
  required: yes
  NA_allowed: no
```

Any non-missing value that is not included in `options` is flagged as invalid.


#### `numeric`

Used for variables that must contain numeric values. 

Numeric specifications can additionally define:

* lower and upper limits
* whether decimal values are allowed
* the minimum number of decimal places
* the maximum number of decimal places

For example, if the variable "looking_time" has a range of 0 - 30, and cannot exceed 2 decimal places:

```yaml
- field: looking_time
  description: duration of looking time in seconds
  type: numeric
  format: restricted
  lowerlimit: 0
  upperlimit: 30
  allow_decimals: yes
  min_decimals: 0
  max_decimals: 2
  required: yes
  NA_allowed: no
```

#### `string`

Used for variables that must contain string values.

String specifications can additionally define:

* whether values must be capitalized or uncapitalized
* minimum and maximum character length
* a regular expression pattern that values must match

For example, if the variable "participant_code" must contain no lowercase letters and must be between 2 and 10 characters:

```yaml
- field: participant_code
  description: participant identification code
  type: string
  format: capitalized
  lowerlimit: 2
  upperlimit: 10
  required: yes
  NA_allowed: no
```

The `format` field can be used to apply additional restrictions:

* `capitalized` — values cannot contain lowercase letters
* `uncapitalized` — values cannot contain uppercase letters
* `regex` — values must match the regular expression specified in `pattern`

For example, to require a study ID consisting of lowercase letters followed by numbers:

```yaml
- field: study_ID
  description: uniquely identifies a study
  type: string
  format: regex
  pattern: "^[a-z]+[0-9]+$"
  required: yes
  NA_allowed: no
```

The `lowerlimit` and `upperlimit` fields specify the minimum and maximum number of characters allowed. These restrictions can be used with string formats other than `regex`.

## Contributions

If you would like to contribute to the validator, please [make a fork](https://help.github.com/en/articles/fork-a-repo). 

## Contact

Main developer

-[Francis Yuen](francis.yuen@psych.ubc.ca)

MB contacts

-[Mike Frank](mcfrank@stanford.edu)
-[Heidi Baumgartner](heidib@manybabies.org)


## Credit and Acknowledgement

We thank Mika Braginky, Jonathan Kominsky, Christopher Green, and Abteen Arab for their work on developing the previous versions of this validator.
