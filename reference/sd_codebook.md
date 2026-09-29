# Generate a codebook for a survey dataset

The automated version of "06_generoi_codebook.R": prepares the data with
[`sd_prepare_codebook_data()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_prepare_codebook_data.md)
(labels, value labels, automatic Likert scale-mean columns), writes a
minimal R Markdown document that calls
[`codebook::codebook()`](https://rubenarslan.github.io/codebook/reference/codebook.html)
on it, and renders that document to a self-contained HTML file with
[`rmarkdown::render()`](https://pkgs.rstudio.com/rmarkdown/reference/render.html).

## Usage

``` r
sd_codebook(
  x,
  out_dir = "inst/codebook",
  file_name = NULL,
  groups = NULL,
  min_items = 2,
  overwrite = FALSE
)
```

## Arguments

- x:

  An `sd_data` object.

- out_dir:

  Directory to save the codebook HTML to. Default `"inst/codebook"`,
  matching where a codebook is conventionally kept in a package.

- file_name:

  File name for the saved codebook. Defaults to `"codebook.html"`. A
  `.html` extension is added if missing.

- groups, min_items:

  Passed on to
  [`sd_prepare_codebook_data()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_prepare_codebook_data.md).

- overwrite:

  If `FALSE` (the default) and the target file already exists,
  `sd_codebook()` refuses to overwrite it and raises an error instead —
  set `TRUE` once you've checked the existing file.

## Value

An object of class `sd_codebook` with elements `data` (the prepared data
frame passed into the codebook), `groups` (detected/used scale groups),
`file` (the rendered HTML's path), and `created`.

## Why via R Markdown

[`codebook::codebook()`](https://rubenarslan.github.io/codebook/reference/codebook.html)
is designed to run inside a knitted R Markdown document — called
directly at the console (as the original script did) it returns a
`knit_asis` object (confirmed by testing against a real installation),
which is only meaningful once actually knitted: it isn't a complete,
standalone HTML page on its own; plots and interactive tables are only
fully assembled during a real
[`rmarkdown::render()`](https://pkgs.rstudio.com/rmarkdown/reference/render.html)
pass. So instead of guessing at that object, `sd_codebook()` builds a
tiny `.Rmd` behind the scenes and renders it properly, which is the
standard supported way to automate codebook outside of RStudio's
interactive Viewer/Ctrl+S workflow.

## Examples

``` r
if (FALSE) { # \dontrun{
aineisto <- sd_read("survey_data.sav")
aineisto <- sd_detect_roles(aineisto)
tulos <- sd_codebook(aineisto)
tulos$file
} # }
```
