# Prepare survey data for codebook generation

The data-preparation half of "06_generoi_codebook.R", pulled out so it
can be tested and used on its own without needing the codebook package.
Takes an `sd_data` object and returns a plain data frame with:

- variable labels and value labels attached as `label`/`labels`
  attributes (the same haven-style convention
  [`sd_read()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_read.md)
  reads them from) — this is what lets codebook show readable
  descriptions and value labels;

- automatically detected Likert-item groups turned into `<group>_mean`
  scale-score columns, so codebook's reliability calculations (e.g.
  Cronbach's alpha) have something to work with.

## Usage

``` r
sd_prepare_codebook_data(x, groups = NULL, min_items = 2)
```

## Arguments

- x:

  An `sd_data` object.

- groups:

  Optional named list mapping a group name to a character vector of
  variable names, e.g. `list(tt = c("tt1", "tt2", "tt3"))`. Use this to
  override automatic detection — for instance when your scale items
  don't share a numbered-suffix naming pattern. `NULL` (the default)
  detects groups automatically.

- min_items:

  Minimum number of variables a detected group must have to be treated
  as a scale (default `2`). Ignored when `groups` is given explicitly.

## Value

A data frame (not an `sd_data` object) with label/value-label attributes
attached and scale-mean columns added, an attribute `"sd_groups"`
recording which groups were used.

## Details

Likert groups are detected from variable names that share a common
prefix before a trailing number — e.g. `tt1`, `tt2`, `tt3`, `tt4` become
the group `"tt"`. This generalises the hardcoded
`tt_mean`/`joh_mean`/`imu_mean` computation from the original script.
Only variables with role `"likert"` (see
[`sd_detect_roles()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_detect_roles.md))
are considered, and a group needs at least `min_items` members by
default — a lone `"likert"` variable with no siblings is left alone.

## Examples

``` r
if (FALSE) { # \dontrun{
aineisto <- sd_read("survey_data.sav")
aineisto <- sd_detect_roles(aineisto)
df <- sd_prepare_codebook_data(aineisto)
attr(df, "sd_groups")
} # }
```
