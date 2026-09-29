# Update roxygen2 documentation with newly added variables

Surveys and other research datasets often grow new variables over time –
computed sum scores, a new wave's questions, and so on. Regenerating the
whole roxygen2 block with
[`sd_generate_roxygen()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_generate_roxygen.md)
every time would throw away any text you already reviewed and approved.
`sd_update_roxygen()` instead only asks the language model to describe
the NEW variables, and inserts them into the existing `\describe{}`
block, leaving the title, description, `@details`, `@source`, and all
previously documented variables untouched. The `@format` line's variable
count is corrected automatically (never left to the model).

## Usage

``` r
sd_update_roxygen(
  x,
  object_name,
  file = NULL,
  new_vars = NULL,
  model = "gemma3:12b",
  backend = "ollama",
  language = "fi",
  timeout_s = 1200,
  dry_run = TRUE
)
```

## Arguments

- x:

  An `sd_data` object containing the CURRENT, full set of variables (old
  and new).

- object_name:

  Name the documented object has, e.g. `"survey_data"` – the same name
  used with
  [`sd_generate_roxygen()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_generate_roxygen.md).

- file:

  Path to the existing roxygen2 file to update. Defaults to
  `file.path("R", paste0(object_name, ".R"))`.

- new_vars:

  Character vector of variable names to describe. `NULL` (the default)
  auto-detects them by comparing `x` against what is already documented
  in `file`.

- model, backend, timeout_s:

  As in
  [`sd_document()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_document.md).

- language:

  Language the new variable descriptions should be written in – one of
  `"fi"` (Finnish, the default), `"en"` (English) or `"sv"` (Swedish).
  Should normally match the language `file` was already written in. See
  [`sd_build_prompt()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_build_prompt.md).

- dry_run:

  If `TRUE` (the default), the updated text is only returned, not
  written to disk. Set to `FALSE` to write it to `file` (a `.bak` backup
  of the previous version is made first).

## Value

An object of class `sd_roxygen_update` with elements `text` (the full
updated file content), `added_vars` (character vector of variables that
were newly documented – empty if none were found), `file`, `backup_file`
(path to the `.bak` copy, or `NULL` when `dry_run = TRUE` or nothing
changed), `prompt`, `model`, `backend`, `chat`, and `created`.

## Details

New variables are found automatically by parsing which variables are
already documented in `file` and comparing them to `names(x$data)` – the
same idea
[`sd_check_documentation_current()`](https://dariah-fi-surveyai.github.io/SurveyDokum/reference/sd_check_documentation_current.md)
uses. If that parsing is uncertain (e.g. a heavily hand-edited file) or
you simply know which variables you want described, pass `new_vars`
explicitly instead.

By default (`dry_run = TRUE`) nothing is written to disk. Set
`dry_run = FALSE` to write the update; the previous version of `file` is
always copied to `<file>.bak` first, so an unwanted update can be undone
by restoring that copy.

## Examples

``` r
if (FALSE) { # \dontrun{
# aineisto sisältää nyt esim. uuden summamuuttujan "tt_mean":
tulos <- sd_update_roxygen(aineisto, "survey_data")
print(tulos)   # tarkista lisätyt kuvaukset ennen tallennusta
sd_update_roxygen(aineisto, "survey_data", dry_run = FALSE)
} # }
```
