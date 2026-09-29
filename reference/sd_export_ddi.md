# Export a survey dataset's codebook as a DDI Codebook XML file

Builds a DDI Codebook 2.6 `codeBook` element from an `sd_data` object's
metadata (`meta$roles`, `meta$labels`, `meta$value_labels`,
`meta$missing_codes`) and writes it to an XML file using the DDIwR
package. This is metadata-only: unlike
[`DDIwR::convert()`](https://rdrr.io/pkg/DDIwR/man/convert.html), it
does not require (or embed) the actual data values, since `sd_data`'s
metadata is kept separately from the data (see
[`new_sd_data()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/new_sd_data.md)).

## Usage

``` r
sd_export_ddi(x, file = "codebook.xml", title = NULL, overwrite = FALSE, ...)
```

## Arguments

- x:

  An `sd_data` object.

- file:

  Path to write the XML file to. Default `"codebook.xml"`.

- title:

  Study title. Defaults to `x$meta$paradata$nimi` if set, otherwise
  `"Untitled dataset"`. Passed on to
  [`DDIwR::exportCodebook()`](https://rdrr.io/pkg/DDIwR/man/exportCodebook.html)
  as `titl`, which auto-fills the mandatory `stdyDscr`/`docDscr`
  elements when they are not already present in `codeBook`.

- overwrite:

  If `FALSE` (the default) and `file` already exists, `sd_export_ddi()`
  refuses to overwrite it.

- ...:

  Further arguments passed on to
  [`DDIwR::exportCodebook()`](https://rdrr.io/pkg/DDIwR/man/exportCodebook.html)
  (e.g. `agency`, `IDNo`, `abstract`, `monolang`).

## Value

Invisibly, the `codeBook` list object passed to
[`DDIwR::exportCodebook()`](https://rdrr.io/pkg/DDIwR/man/exportCodebook.html)
(before its internal auto-fill of `stdyDscr`/`docDscr` — read the
exported file back with
[`DDIwR::getCodebook()`](https://rdrr.io/pkg/DDIwR/man/getCodebook.html)
to inspect the complete, final structure).

## Recommended order

Run
[`sd_detect_roles()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_detect_roles.md)
and
[`sd_set_missing()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_set_missing.md)
before `sd_export_ddi()` — the DDI export uses `meta$roles` to set each
variable's format type, and `meta$missing_codes` to mark categories as
`missing="Y"` in the codebook (via
[`DDIwR::makeCategories()`](https://rdrr.io/pkg/DDIwR/man/makeCategories.html)).

## Examples

``` r
if (FALSE) { # \dontrun{
aineisto <- sd_read("survey_data.sav")
aineisto <- sd_detect_roles(aineisto)
aineisto <- sd_set_missing(aineisto, codes = c(99, -9))
sd_export_ddi(aineisto, file = "codebook.xml", title = "Tyotyytyvaisyyskysely 2026")
} # }
```
