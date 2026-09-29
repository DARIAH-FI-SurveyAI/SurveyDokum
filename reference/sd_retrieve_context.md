# Retrieve RAG background context for a dataset's variables

For each variable in `x`, searches `store` (a connected ragnar
`RagnarStore`, e.g. via
[`ragnar::ragnar_store_connect()`](https://ragnar.tidyverse.org/reference/ragnar_store_create.html),
built from your own reference material) using the variable's name and
label as the query, and formats the retrieved chunks into a text block
citing their source. Meant to be passed as the `context` argument to
[`sd_build_prompt()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_build_prompt.md)
/ `sd_build_roxygen_prompt()`, or simply via the `store` argument of
[`sd_document()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_document.md)
/
[`sd_generate_roxygen()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_generate_roxygen.md),
which call this automatically.

## Usage

``` r
sd_retrieve_context(x, store = NULL, top_k = 2, max_chars = 600)
```

## Arguments

- x:

  An `sd_data` object (see
  [`sd_read()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_read.md))
  or an already-computed `sd_summary` object (see
  [`sd_summarise()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_summarise.md)).

- store:

  A connected ragnar `RagnarStore` (see
  [`ragnar::ragnar_store_connect()`](https://ragnar.tidyverse.org/reference/ragnar_store_create.html)
  /
  [`ragnar::ragnar_store_create()`](https://ragnar.tidyverse.org/reference/ragnar_store_create.html)),
  or `NULL` (the default) to skip retrieval entirely and return `NULL` –
  this is what lets `store` stay an optional argument throughout the
  rest of the package.

- top_k:

  Number of chunks retrieved per variable.

- max_chars:

  Truncates each retrieved chunk to this many characters before
  including it, so a handful of long reference entries don't dominate
  the prompt.

## Value

A single character string formatted for inclusion in a prompt (one
bullet per retrieved chunk, source in parentheses), or `NULL` if `store`
is `NULL` or nothing was retrieved.

## Details

RAG support in SurveyDokum is deliberately a thin, optional layer: this
function only *consumes* a store you have already built with ragnar from
whatever reference material you choose (survey methodology glossaries,
controlled vocabularies, prior codebooks, house style guides, ...) –
SurveyDokum does not build or ship one for you. See the "Using RAG with
SurveyDokum" vignette for a worked-through recipe with ragnar.

## Examples

``` r
if (FALSE) { # \dontrun{
store <- ragnar::ragnar_store_connect("oma_rag_store.ragnar.duckdb")
aineisto <- sd_read("survey_data.csv")
tausta <- sd_retrieve_context(aineisto, store)
cat(tausta)

# Kaytossa sd_generate_roxygen()/sd_document() kautta:
sd_generate_roxygen(aineisto, "survey_data", store = store)
} # }
```
