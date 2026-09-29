# Read survey data into an sd_data object

Reads a survey dataset from disk and wraps it in an `sd_data` object
(see
[`new_sd_data()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/new_sd_data.md)).
The file format is chosen automatically from the file extension.
Currently supported: `.csv`, `.tsv`, `.xlsx`, `.xls`, `.sav` (SPSS),
`.dta` (Stata), and `.rds`.

## Usage

``` r
sd_read(path, encoding = "UTF-8", ...)
```

## Arguments

- path:

  Path to the data file.

- encoding:

  Text encoding to assume for csv/tsv files. Defaults to `"UTF-8"`.
  Ignored for other formats.

- ...:

  Further arguments passed on to the underlying reader function
  ([`utils::read.csv()`](https://rdrr.io/r/utils/read.table.html),
  [`utils::read.delim()`](https://rdrr.io/r/utils/read.table.html),
  [`readxl::read_excel()`](https://readxl.tidyverse.org/reference/read_excel.html),
  [`haven::read_sav()`](https://haven.tidyverse.org/reference/read_spss.html),
  or
  [`haven::read_dta()`](https://haven.tidyverse.org/reference/read_dta.html)).

## Value

An `sd_data` object.

## Details

When the source data carries labels of its own (SPSS `.sav`, Stata
`.dta`, read via the haven package, or an `.rds` file containing an
already-labelled data frame from an earlier session), the variable
labels are copied into `meta$labels` and the value labels into
`meta$value_labels` automatically – this harvesting happens inside
[`new_sd_data()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/new_sd_data.md)
and applies to any data frame with `label`/`labels` column attributes,
regardless of source format. For formats without built-in labels (csv,
tsv, xlsx), these start out empty and can be filled in afterwards.

`sd_read()` does not itself set variable roles or missing-value codes —
those are the next steps in the pipeline
([`sd_detect_roles()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_detect_roles.md)
and
[`sd_set_missing()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_set_missing.md)).

## Examples

``` r
if (FALSE) { # \dontrun{
aineisto <- sd_read("survey_data.csv")
aineisto <- sd_read("survey_data.sav")
} # }
```
