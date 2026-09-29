# Manually set the role of one variable

Overrides the role of a single variable in an `sd_data` object, e.g.
after inspecting the result of
[`sd_detect_roles()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_detect_roles.md)
and finding a mistake.

## Usage

``` r
sd_set_role(x, var, role)
```

## Arguments

- x:

  An `sd_data` object.

- var:

  Name of the variable to set the role for.

- role:

  One of `"id"`, `"likert"`, `"nominal"`, `"continuous"`, `"date"`,
  `"text"`, `"weight"`, or `"unknown"`.

## Value

The same `sd_data` object, with the role for `var` updated.

## Examples

``` r
if (FALSE) { # \dontrun{
aineisto <- sd_set_role(aineisto, "tyovuodet", "continuous")
} # }
```
