# Check whether Ollama is reachable and the model is pulled

A fast diagnostic for
[`sd_document()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_document.md)'s
Ollama backend: checks whether the local Ollama server responds at all,
and whether `model` is among the models it already has pulled. This only
queries Ollama's model list — it does not generate anything, so it
returns in well under a second and is safe to run before committing to a
slow
[`sd_document()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_document.md)
call.

## Usage

``` r
sd_check_ollama(model = "gemma3:12b", host = "http://localhost:11434")
```

## Arguments

- model:

  Name of the model to look for, e.g. `"gemma3:12b"`.

- host:

  Base URL of the Ollama server. Defaults to `"http://localhost:11434"`,
  the standard local address.

## Value

Invisibly, `TRUE` if Ollama is reachable and `model` is pulled, `FALSE`
otherwise. Called for its printed message.

## Examples

``` r
if (FALSE) { # \dontrun{
sd_check_ollama("gemma3:12b")
} # }
```
