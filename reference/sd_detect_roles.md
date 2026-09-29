# Detect variable roles heuristically

Guesses a role for each variable in an `sd_data` object, based on simple
rules (data type, value range, name pattern, cardinality). This is a
heuristic starting point, not a guarantee — always check the result and
correct individual variables with
[`sd_set_role()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_set_role.md)
where the guess is wrong.

## Usage

``` r
sd_detect_roles(x)
```

## Arguments

- x:

  An `sd_data` object.

## Value

The same `sd_data` object, with `meta$roles` filled in.

## Details

Roles used elsewhere in the package: `"id"`, `"likert"`, `"nominal"`,
`"continuous"`, `"date"`, `"text"`, `"weight"`, `"unknown"`.

The heuristic, checked in this order for each variable:

- date:

  Column class is `Date`, `POSIXct` or `POSIXt`.

- id:

  Variable name matches `id`/`tunnus` (whole word or suffix, e.g.
  `vastaaja_id`), OR every non-missing value is unique and there are
  more than 10 respondents.

- weight:

  Variable name matches `paino`/`weight`/`wt` and the variable is
  numeric.

- likert:

  Numeric, whole-number values, 2–11 distinct values, and a value range
  of 10 or less. This is a common shape for Likert/ordinal scales, but
  it also matches other small-range counts (e.g. number of children) —
  check the result.

- continuous:

  Any other numeric variable.

- text:

  Character/factor where more than half the values are unique, or the
  average value length is over 30 characters — a proxy for open-ended
  text.

- nominal:

  Any other character, factor, or logical variable.

- unknown:

  Anything not covered above.

## Recommended order

Run
[`sd_set_missing()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_set_missing.md)
*before* `sd_detect_roles()` whenever your data uses sentinel
missing-value codes (e.g. `99`, `-9`). Otherwise a sentinel code widens
a variable's apparent value range — a 1–5 Likert item with a handful of
`99`s looks like it ranges from 1 to 99, and gets classified as
`"continuous"` instead of `"likert"`.

## Examples

``` r
if (FALSE) { # \dontrun{
aineisto <- sd_read("survey_data.csv")
aineisto <- sd_detect_roles(aineisto)
print(aineisto)
} # }
```
