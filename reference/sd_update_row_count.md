# Update a roxygen2 file's row count for new observations

Companion to
[`sd_update_roxygen()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_update_roxygen.md),
but for new ROWS (respondents) instead of new variables. When a dataset
gains observations but no new variables, the `\describe{}` block itself
needs no change – only the row count recorded in the `@format` line
(e.g. "... with 200 rows and 17 variables:") is now wrong.
`sd_update_row_count()` corrects that number deterministically – no
language model call is needed, because unlike a variable description, a
row count has exactly one correct value.

## Usage

``` r
sd_update_row_count(x, object_name, file = NULL, dry_run = TRUE)
```

## Arguments

- x:

  An `sd_data` object containing the CURRENT, full data (including the
  new rows).

- object_name:

  Name the documented object has, e.g. `"survey_data"` – the same name
  used with
  [`sd_generate_roxygen()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_generate_roxygen.md).

- file:

  Path to the existing roxygen2 file to update. Defaults to
  `file.path("R", paste0(object_name, ".R"))`.

- dry_run:

  If `TRUE` (the default), the updated text is only returned, not
  written to disk. Set to `FALSE` to write it to `file` (a `.bak` backup
  of the previous version is made first, as in
  [`sd_update_roxygen()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_update_roxygen.md)).

## Value

An object of class `sd_row_count_update` with elements `text` (the full
updated file content), `old_count`, `new_count`, `file`, `backup_file`
(path to the `.bak` copy, or `NULL` when `dry_run = TRUE` or nothing
changed), and `created`.

## Details

This function intentionally does NOT touch
[`sd_document()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_document.md)'s
descriptive text – its prose (respondent counts, distributions, and so
on) is generated from the whole dataset and cannot be patched
incrementally the way new variable descriptions can. Re-run
[`sd_document()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_document.md)
by hand if the row-count change is significant enough to warrant it. See
[`sd_check_row_count()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_check_row_count.md)
for a quick check of whether an update is needed at all.

## Examples

``` r
if (FALSE) { # \dontrun{
# aineistoon on lisätty uusia vastaajia, muuttujat pysyivät samoina:
tulos <- sd_update_row_count(aineisto, "survey_data")
print(tulos)   # tarkista muutos ennen tallennusta
sd_update_row_count(aineisto, "survey_data", dry_run = FALSE)
} # }
```
