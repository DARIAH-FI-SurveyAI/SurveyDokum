# Define sentinel missing-value codes

Survey data often encodes missing responses with sentinel numeric or
text codes (e.g. `99`, `-9`, `"En osaa sanoa"`) instead of a true
missing value. `sd_set_missing()` records these codes in
`meta$missing_codes` and replaces matching values with `NA` in the data
itself, so that later pipeline steps (e.g.
[`sd_summarise()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_summarise.md))
compute correct statistics.

## Usage

``` r
sd_set_missing(x, codes, vars = NULL)
```

## Arguments

- x:

  An `sd_data` object.

- codes:

  Either a vector of codes to apply to `vars` (e.g. `c(99, -9)`), or a
  named list mapping variable names to their own codes (e.g.
  `list(tt1 = c(99, -9), avoin_palaute = "")`) — in which case `vars` is
  ignored.

- vars:

  Character vector of variable names to apply `codes` to. `NULL` (the
  default) applies to every variable in the data except those already
  known to have role `"id"` — see the warning above. Ignored when
  `codes` is a named list.

## Value

The same `sd_data` object, with matching values in the data replaced by
`NA` and `meta$missing_codes` updated.

## Always name `vars` explicitly

Leaving `vars` as `NULL` applies `codes` to *every* variable in the data
— including id, weight, and date columns. This is risky: an id variable
coded `1:200` legitimately contains the value `99`, and a blanket
`sd_set_missing(x, codes = 99)` would silently turn that respondent's id
into `NA`. In practice, always list the specific variables where the
sentinel code is meaningful (typically your substantive survey items),
e.g. `vars = c("tt1", "tt2", "tt3")` — never rely on the "apply to
everything" default. If variable roles have already been set (see
[`sd_detect_roles()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_detect_roles.md)),
leaving `vars` as `NULL` at least skips variables with role `"id"`
automatically and a warning is raised — but this is a safety net, not a
substitute for naming `vars`.

## Examples

``` r
if (FALSE) { # \dontrun{
# Suositeltu: nimeä muuttujat aina eksplisiittisesti
aineisto <- sd_set_missing(aineisto, codes = c(99, -9),
                            vars = c("tt1", "tt2", "tt3"))

# Eri koodit eri muuttujille:
aineisto <- sd_set_missing(aineisto, codes = list(
  tt1 = c(99, -9),
  avoin_palaute = ""
))
} # }
```
