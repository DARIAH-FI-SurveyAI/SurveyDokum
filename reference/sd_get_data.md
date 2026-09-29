# Get the underlying data frame from an `sd_data` object

Get the underlying data frame from an `sd_data` object

## Usage

``` r
sd_get_data(x)
```

## Arguments

- x:

  An `sd_data` object, as created by
  [`sd_read()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_read.md).

## Value

A tibble.

## Examples

``` r
if (FALSE) { # \dontrun{
aineisto <- sd_read("survey_data.csv")
sd_get_data(aineisto)
} # }
```
