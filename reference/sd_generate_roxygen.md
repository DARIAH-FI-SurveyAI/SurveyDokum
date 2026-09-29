# Generate roxygen2 documentation for a dataset with a language model

The automated version of "03_generoi_roxygen.R": takes the labels, value
labels and paradata already attached to an `sd_data` object (see
[`sd_read()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_read.md),
or set manually) and asks a language model to write a complete roxygen2
documentation block for it, ready to save as `R/<object_name>.R` next to
a dataset saved with `usethis::use_data()`.

## Usage

``` r
sd_generate_roxygen(
  x,
  object_name,
  model = "gemma3:12b",
  backend = "ollama",
  instructions = NULL,
  dry_run = TRUE,
  file = NULL,
  overwrite = FALSE,
  timeout_s = 1200,
  language = "fi",
  store = NULL,
  top_k = 2
)
```

## Arguments

- x:

  An `sd_data` object. Labels and value labels (see
  [`sd_read()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_read.md)'s
  automatic haven-label import, or set them directly on
  `x$meta$labels`/`x$meta$value_labels`) make for a much better result —
  a dataset with no labels at all still works, but the model will have
  only variable names and value ranges to go on.

- object_name:

  Name the documented object will have once saved with
  `usethis::use_data()`, e.g. `"survey_data"`. Required — this is what
  the generated documentation is attached to.

- model, backend, timeout_s:

  As in
  [`sd_document()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_document.md).

- instructions:

  Passed on to `sd_build_roxygen_prompt()`.

- dry_run:

  If `TRUE` (the default), the result is only returned, not written to
  disk. Set to `FALSE` to write it to `file`.

- file:

  Path to write the documentation to when `dry_run = FALSE`. Defaults to
  `file.path("R", paste0(object_name, ".R"))`, matching where
  `usethis::use_data()` expects a dataset's documentation.

- overwrite:

  If `FALSE` (the default) and `file` already exists,
  `sd_generate_roxygen()` refuses to overwrite it and raises an error
  instead — set `TRUE` once you've checked the existing file.

- language:

  Language the generated roxygen2 documentation should be written in –
  one of `"fi"` (Finnish, the default), `"en"` (English) or `"sv"`
  (Swedish). Only affects the built-in `instructions` (and small field
  labels in the dataset-information block); has no effect when
  `instructions` is supplied explicitly. See
  `sd_build_roxygen_prompt()`.

- store:

  Optional connected ragnar `RagnarStore` (see
  [`ragnar::ragnar_store_connect()`](https://ragnar.tidyverse.org/reference/ragnar_store_create.html))
  built from your own reference material. When given,
  [`sd_retrieve_context()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_retrieve_context.md)
  looks up background material for each variable and inserts it into the
  prompt. `NULL` (the default) skips retrieval entirely – behaves
  exactly as before this parameter was added.

- top_k:

  Number of chunks retrieved per variable when `store` is given. Passed
  on to
  [`sd_retrieve_context()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_retrieve_context.md).

## Value

An object of class `sd_roxygen` with elements `text` (the generated
roxygen2 block), `prompt`, `object_name`, `model`, `backend`, `file`
(the path written to, or `NULL` when `dry_run = TRUE`), `chat` (the
underlying ellmer chat object), and `created`.

## Details

By default (`dry_run = TRUE`) nothing is written to disk — the generated
text is only returned (and can be inspected with
[`print()`](https://rdrr.io/r/base/print.html)/[`cat()`](https://rdrr.io/r/base/cat.html))
so you can check it before committing to a file. Set `dry_run = FALSE`
to write it out; an existing file is never silently overwritten unless
`overwrite = TRUE`.

## Requirements

Same as
[`sd_document()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_document.md)
— a running Ollama installation with `model` pulled. Run
[`sd_check_ollama()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_check_ollama.md)
first. A response can take from seconds to minutes;
`sd_generate_roxygen()` prints a message before sending the request so a
long wait doesn't look frozen.

## Examples

``` r
if (FALSE) { # \dontrun{
aineisto <- sd_read("survey_data.sav")
tulos <- sd_generate_roxygen(aineisto, "survey_data")
print(tulos)

# Kun teksti näyttää hyvältä, kirjoita tiedostoon:
tulos <- sd_generate_roxygen(aineisto, "survey_data", dry_run = FALSE)
} # }
```
