# Check whether a roxygen2 file's documented row count matches the data

A fast, LLM-free diagnostic, symmetric to
[`sd_check_documentation_current()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_check_documentation_current.md)
but for ROWS (respondents) instead of variables. Reads the row count
recorded in the existing roxygen2 file's `@format` line (e.g. "A data
frame with 200 rows and 17 variables:") and compares it to
`nrow(x$data)`.

## Usage

``` r
sd_check_row_count(x, object_name, file = NULL)
```

## Arguments

- x:

  An `sd_data` object containing the CURRENT data.

- object_name:

  Name the documented object has, e.g. `"survey_data"` – the same name
  used with
  [`sd_generate_roxygen()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_generate_roxygen.md).

- file:

  Path to the existing roxygen2 file. Defaults to
  `file.path("R", paste0(object_name, ".R"))`.

## Value

Invisibly, the difference `nrow(x$data) - <documented count>` (`0` when
up to date). Called for its printed message.

## Details

Unlike new variables, new rows do not require any change to the
`\describe{}` block itself – only the row count in `@format` needs
correcting, which
[`sd_update_row_count()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_update_row_count.md)
does deterministically. But because
[`sd_document()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_document.md)'s
descriptive text (respondent counts, distributions, and so on) is
computed from the WHOLE dataset, a change in row count is also a strong
signal that that text is now stale and worth regenerating by hand with
[`sd_document()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_document.md)
– this function does not attempt to do that automatically.

## Examples

``` r
if (FALSE) { # \dontrun{
sd_check_row_count(aineisto, "survey_data")
} # }
```
