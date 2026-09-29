# Build the roxygen2-generation prompt from an sd_data object

Turns the metadata already attached to an `sd_data` object (variable
labels, value labels, missing counts, dataset-level paradata) into the
full text prompt that
[`sd_generate_roxygen()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_generate_roxygen.md)
sends to the language model. Kept separate from
[`sd_generate_roxygen()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_generate_roxygen.md)
so the prompt can be inspected or unit-tested without needing Ollama (or
any model) running — the same idea as
[`sd_build_prompt()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_build_prompt.md)
for
[`sd_document()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_document.md).

## Usage

``` r
sd_check_object_name_(object_name)
```

## Arguments

- object_name:

  Name the documented object will have once saved with
  `usethis::use_data()`, e.g. `"survey_data"`. Written into the
  generated roxygen2 block as the final line (the line that normally
  follows a dataset's documentation and names the object it documents).

- x:

  An `sd_data` object.

- instructions:

  Character string with the instructions placed before the dataset
  information. `NULL` (the default) uses a built-in instruction template
  (see `language`) asking for a roxygen2 block following the usual
  `@format`/`@details`/`@source` structure for a documented dataset.

- language:

  Language of the built-in `instructions` template (and of the small
  field labels in the dataset-information block, e.g.
  "Label"/"Type"/"Missing") when `instructions` is left at its default
  `NULL` – one of `"fi"` (Finnish, the default), `"en"` (English) or
  `"sv"` (Swedish). Has no effect when `instructions` is supplied
  explicitly. Independent of the language the survey data itself
  (variable labels etc.) happens to be in – see
  [`sd_build_prompt()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_build_prompt.md)
  for the same idea applied to
  [`sd_document()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_document.md).

- context:

  Optional character string of retrieved background material to insert
  before the dataset information – typically the output of
  [`sd_retrieve_context()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_retrieve_context.md).
  `NULL` (the default) omits this section entirely, leaving the prompt
  exactly as before this parameter was added.

## Value

A single character string: the full prompt.

## Details

Only metadata is included (labels, value labels, per-variable missing
counts, dataset-level paradata) — never the raw data values themselves,
so open-text responses are never sent to the model.

## Examples

``` r
if (FALSE) { # \dontrun{
aineisto <- sd_read("survey_data.csv")
kehote <- sd_build_roxygen_prompt(aineisto, "survey_data")
cat(kehote)

# Englanninkielinen roxygen-dokumentaatio samasta aineistosta:
kehote_en <- sd_build_roxygen_prompt(aineisto, "survey_data", language = "en")

# RAG-taustatiedolla:
store <- ragnar::ragnar_store_connect("oma_rag_store.ragnar.duckdb")
kehote_rag <- sd_build_roxygen_prompt(
  aineisto, "survey_data",
  context = sd_retrieve_context(aineisto, store)
)
} # }
```
