# Build the LLM prompt from a summary

Turns an `sd_summary` object (see
[`sd_summarise()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_summarise.md))
into the full text prompt that
[`sd_document()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_document.md)
sends to the language model — instructions followed by the statistics
themselves. Kept separate from
[`sd_document()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_document.md)
so the prompt can be inspected or unit-tested without needing Ollama (or
any model) running.

## Usage

``` r
sd_build_prompt(summary, instructions = NULL, language = "fi", context = NULL)
```

## Arguments

- summary:

  An `sd_summary` object, as returned by
  [`sd_summarise()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_summarise.md).

- instructions:

  Character string with the instructions placed before the statistics.
  `NULL` (the default) uses a built-in instruction template (see
  `language`) asking for an overview, descriptions of the
  categorical/demographic and Likert-type variables, and a short data
  quality note.

- language:

  Language of the built-in `instructions` template when `instructions`
  is left at its default `NULL` – one of `"fi"` (Finnish, the default),
  `"en"` (English) or `"sv"` (Swedish). Has no effect when
  `instructions` is supplied explicitly. This is independent of the
  language the survey data itself (variable labels etc.) happens to be
  in – a Finnish-language survey can still be documented in English, or
  vice versa. Note that `format(summary)` itself (the statistics block
  appended after `instructions`) is currently always formatted using
  Finnish labels regardless of `language` – see `format.sd_summary()`.

- context:

  Optional character string of retrieved background material to insert
  before the statistics block – typically the output of
  [`sd_retrieve_context()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_retrieve_context.md).
  `NULL` (the default) omits this section entirely, leaving the prompt
  exactly as before this parameter was added.

## Value

A single character string: the full prompt.

## Examples

``` r
if (FALSE) { # \dontrun{
kooste <- sd_summarise(aineisto)
kehote <- sd_build_prompt(kooste)
cat(kehote)

# Englanninkieliset ohjeet samalle datalle:
kehote_en <- sd_build_prompt(kooste, language = "en")

# RAG-taustatiedolla:
store <- ragnar::ragnar_store_connect("oma_rag_store.ragnar.duckdb")
kehote_rag <- sd_build_prompt(kooste, context = sd_retrieve_context(kooste, store))
} # }
```
