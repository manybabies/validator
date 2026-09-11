# ManyBabies Data Validator (Current version: 2.0.0, Sept 11, 2026)

A Shiny application for validating individual lab datasets against study-specific data specifications.

The validator checks whether a dataset conforms to a predefined set of requirements, including:

- required variables
- permitted values
- numeric restrictions
- string formats
- regular-expression patterns (Regex)

Validation errors are reported at the level of individual cells, allowing researchers to identify and correct problems directly in their dataset. 

Researchers can choose to view the errors by column (i.e. identify which rows in column X has errors) or by row (i.e. identify which columns in row X has errors).

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

You can email Mike, Melissa, or Francis with any questions!
