# Check whether a dataset's roxygen2 documentation is up to date

A fast, LLM-free diagnostic: compares the variable names in `x` against
the variables already documented in the existing roxygen2 file (parsed
from its `\describe{}` block), and reports any that are missing. Run
this any time you suspect a dataset has grown new variables since it was
last documented – if it finds any, follow up with
[`sd_update_roxygen()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_update_roxygen.md).

## Usage

``` r
sd_check_documentation_current(x, object_name, file = NULL)
```

## Arguments

- x:

  An `sd_data` object.

- object_name:

  Name the documented object has, e.g. `"survey_data"` – the same name
  used with
  [`sd_generate_roxygen()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_generate_roxygen.md).

- file:

  Path to the existing roxygen2 file. Defaults to
  `file.path("R", paste0(object_name, ".R"))`, matching
  [`sd_generate_roxygen()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_generate_roxygen.md)'s
  default.

## Value

Invisibly, a character vector of variable names present in `x` but not
found in `file`'s `\describe{}` block (empty if none). Called for its
printed message.

## Details

Because
[`sd_document()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_document.md)'s
descriptive text is based on the same underlying data, undocumented
variables here are also a signal that the
[`sd_document()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_document.md)
text may be stale and worth regenerating.

## Examples

``` r
if (FALSE) { # \dontrun{
sd_check_documentation_current(aineisto, "survey_data")
} # }
```
