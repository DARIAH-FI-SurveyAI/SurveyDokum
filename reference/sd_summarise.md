# Summarise a survey dataset, variable by variable

Computes per-variable statistics from an `sd_data` object, choosing
which statistics to compute based on each variable's role (see
[`sd_detect_roles()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_detect_roles.md)).
This is "Vaihe 1" of the documentation pipeline — plain R computing
numbers — kept separate from "Vaihe 2", where an LLM turns the numbers
into prose (see
[`sd_build_prompt()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_build_prompt.md)/[`sd_document()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_document.md)).

## Usage

``` r
sd_summarise(x)
```

## Arguments

- x:

  An `sd_data` object.

## Value

An object of class `sd_summary`. Use
[`format()`](https://rdrr.io/r/base/format.html) or
[`print()`](https://rdrr.io/r/base/print.html) to turn it into a text
report (also used as the input for
[`sd_build_prompt()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_build_prompt.md)).

## Details

If some or all variables in `x` do not yet have a role assigned (see
[`sd_detect_roles()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_detect_roles.md)),
`sd_summarise()` detects roles for those variables automatically. Roles
you have already set (with
[`sd_detect_roles()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_detect_roles.md)
or
[`sd_set_role()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_set_role.md))
are always kept as-is.

Open-ended text variables (role `"text"`) are summarised only by
aggregate figures (count, missing count, average length, number of
unique responses) — the actual text content is never included, so that
it is not, for example, sent on to an LLM by accident.

## Recommended order

Call
[`sd_set_missing()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_set_missing.md)
before `sd_summarise()` (directly, or before
[`sd_detect_roles()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_detect_roles.md)
if you call that yourself first) — otherwise sentinel missing-value
codes (e.g. `99`) are treated as real values and distort both the role
detection and the statistics themselves.

## Examples

``` r
if (FALSE) { # \dontrun{
aineisto <- sd_read("survey_data.csv")
aineisto <- sd_set_missing(aineisto, codes = c(99, -9))
aineisto <- sd_detect_roles(aineisto)
kooste <- sd_summarise(aineisto)
print(kooste)
} # }
```
