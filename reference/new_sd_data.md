# Create a new sd_data object

Internal constructor for the `sd_data` class, which bundles a survey
dataset together with metadata about it (variable roles, labels,
missing-value codes, and paradata such as fielding dates or response
rate). Pipeline functions such as
[`sd_summarise()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_summarise.md),
[`sd_document()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_document.md),
[`sd_generate_roxygen()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_generate_roxygen.md)
and
[`sd_codebook()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_codebook.md)
all take an `sd_data` object as input.

## Usage

``` r
new_sd_data(data, meta = list())
```

## Arguments

- data:

  A data frame or tibble containing the survey data.

- meta:

  A list of metadata. See Details for the expected structure.

## Value

An object of class `sd_data`.

## Details

`meta` is a list with (at least) these elements:

- roles:

  Named character vector mapping variable names to a role: one of
  `"id"`, `"likert"`, `"nominal"`, `"continuous"`, `"date"`, `"text"`,
  `"weight"`, or `"unknown"`.

- labels:

  Named list mapping variable names to a human-readable label.

- value_labels:

  Named list mapping variable names to a named vector of value labels
  (value = name).

- missing_codes:

  Named list mapping variable names to a vector of sentinel codes that
  should be treated as missing.

- paradata:

  A list of dataset-level metadata, e.g. `collection_mode`, `fieldwork`,
  `response_rate`, `sampling_frame`.

If `meta$labels`/`meta$value_labels` are not supplied, they are
harvested automatically from any `label`/`labels` attributes already
present on `data`'s columns (the same haven-style convention
[`sd_read()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_read.md)
uses for SPSS/Stata files) — see `sd_harvest_attr_labels_()`. This means
a `data.frame` that already carries these attributes (e.g. one saved to
`.rds` from a previous haven session, or shipped as a package's built-in
example data) gets its labels picked up even when it isn't read in via
[`sd_read()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_read.md)'s
`.sav`/`.dta` path. Pass
`meta = list(labels = list(), value_labels = list())` explicitly to opt
out and start with no labels regardless of what `data`'s attributes
contain.
