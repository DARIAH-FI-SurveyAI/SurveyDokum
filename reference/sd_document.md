# Generate documentation for a survey dataset with a language model

The "Vaihe 2" of the documentation pipeline: takes the statistics R
already computed
([`sd_summarise()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_summarise.md))
and asks a language model to turn them into readable prose. Currently
supports a local Ollama model via the ellmer package.

## Usage

``` r
sd_document(
  x,
  model = "gemma3:12b",
  backend = "ollama",
  system_prompt = NULL,
  instructions = NULL,
  timeout_s = 1200,
  save_to = NULL,
  language = "fi",
  store = NULL,
  top_k = 2
)
```

## Arguments

- x:

  An `sd_data` object (statistics are computed automatically — see
  [`sd_summarise()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_summarise.md)
  for the recommended order of
  [`sd_set_missing()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_set_missing.md)
  and
  [`sd_detect_roles()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_detect_roles.md)
  first) or an already-computed `sd_summary` object.

- model:

  Name of the Ollama model to use, e.g. `"gemma3:12b"`.

- backend:

  Which chat backend to use. Currently only `"ollama"` is supported.

- system_prompt:

  System prompt for the model. `NULL` (the default) uses a built-in
  system prompt, in the language given by `language`, instructing the
  model to write professional documentation and use only the given
  figures.

- instructions:

  Passed on to
  [`sd_build_prompt()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_build_prompt.md).

- timeout_s:

  Request timeout in seconds (local models can be slow on a first
  response). Default `1200` (20 minutes).

- save_to:

  Optional file path. If given, the generated text is also written there
  with [`writeLines()`](https://rdrr.io/r/base/writeLines.html).

- language:

  Language the generated documentation should be written in – one of
  `"fi"` (Finnish, the default), `"en"` (English) or `"sv"` (Swedish).
  Only affects the built-in `system_prompt` and `instructions`; has no
  effect when both are supplied explicitly. See
  [`sd_build_prompt()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_build_prompt.md).

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

An object of class `sd_documentation` with elements `text` (the
generated documentation), `prompt` (the full prompt sent), `model`,
`backend`, `chat` (the underlying ellmer chat object — use
`chat$chat("...")` to ask follow-up questions in the same conversation),
and `created`.

## Requirements

`sd_document()` needs a running Ollama installation with the chosen
model already pulled — see <https://ollama.com>, then
`ollama pull <model>` on the command line. Run
[`sd_check_ollama()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_check_ollama.md)
first to verify this quickly, without waiting for a full generation. A
response can take anywhere from a few seconds to several minutes —
larger models without GPU acceleration are slow, and the very first call
after starting Ollama also pays a one-off cost to load the model into
memory. `sd_document()` prints a message before sending the request so a
long wait doesn't look like it has silently frozen.

## Examples

``` r
if (FALSE) { # \dontrun{
aineisto <- sd_read("survey_data.csv")
aineisto <- sd_set_missing(aineisto, codes = c(99, -9), vars = c("tt1", "tt2"))
aineisto <- sd_detect_roles(aineisto)
dokumentaatio <- sd_document(aineisto, model = "gemma3:12b")
print(dokumentaatio)

# Jatkokeskustelu samassa kontekstissa:
dokumentaatio$chat$chat("Mikä ulottuvuus sai parhaat keskiarvot?")
} # }
```
