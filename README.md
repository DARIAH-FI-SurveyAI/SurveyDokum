
<!-- README.md is generated from README.Rmd. Please edit that file -->

# SurveyDokum

<!-- badges: start -->

<!-- badges: end -->

SurveyDokum helps you document survey datasets without writing
everything by hand. It works in two stages:

1.  **R computes.** The package reads your data, flags missing-value
    codes, detects each variable’s role (ID, Likert item, categorical,
    continuous, open text, date, weight) and computes the statistics
    that fit that role. These steps are deterministic and give the same
    result every time.
2.  **A local language model writes.** The statistics are turned into a
    prompt, and a model running on your own machine through
    [Ollama](https://ollama.com/) writes a readable description of the
    dataset and the roxygen2 text for its R help page, in Finnish,
    English or Swedish.

The model only ever sees aggregate statistics. Individual responses, and
the text of open-ended answers in particular, are never included in a
prompt, and nothing is sent to an external service.

On top of that, SurveyDokum produces an HTML codebook, exports a DDI
Codebook 2.6 XML file for archiving, and keeps the documentation up to
date when new variables or respondents are added.

**New to the package?** The [visual overview](overview.html) shows the
whole workflow on one page (also [suomeksi](yleiskuva.html) and [på
svenska](oversikt.html)).

## Installation

SurveyDokum is not on CRAN. Install the development version from GitHub:

``` r
# install.packages("pak")
pak::pak("your-github-user/SurveyDokum")
```

The language-model steps also need Ollama installed and running, with a
model pulled, for example:

``` sh
ollama pull gemma3:12b
```

## Example: from data to statistics

This part runs in plain R, without a language model. It uses the example
dataset that ships with the package, a workplace wellbeing survey with
200 respondents. To keep the output short, we take five of its 17
variables.

``` r
library(SurveyDokum)

# sd_read() accepts csv, tsv, xlsx, xls, sav, dta and rds files.
# Here we save part of the example data as .rds so there is a file to read.
path <- tempfile(fileext = ".rds")
saveRDS(
  survey_data[, c("vastaaja_id", "sukupuoli", "tyovuodet", "tt1", "avoin_palaute")],
  path
)

aineisto <- sd_read(path)
aineisto <- sd_detect_roles(aineisto)
#> Roolit päätelty 5 muuttujalle:
#>   continuous: 1
#>   id: 1
#>   likert: 1
#>   nominal: 1
#>   text: 1
#> Tämä on heuristiikka, ei varma totuus — tarkista tulos ja korjaa tarvittaessa sd_set_role():lla.
aineisto$meta$roles
#>   vastaaja_id     sukupuoli     tyovuodet           tt1 avoin_palaute 
#>          "id"     "nominal"  "continuous"      "likert"        "text"
```

The detected roles decide which statistics are computed. For the
open-ended variable `avoin_palaute`, only the number of distinct answers
and their average length are reported, never the answers themselves:

``` r
sd_summarise(aineisto)
#> === AINEISTON TIIVISTELMÄ ===
#> 
#> Muuttujia yhteensä: 5
#> 
#> [vastaaja_id] rooli: id
#> Puuttuvia: 0 / 200
#> Tunnistemuuttuja, ei tilastoja.
#> 
#> [sukupuoli (Vastaajan sukupuoli)] rooli: nominal
#> Puuttuvia: 0 / 200
#> Kategorinen muuttuja (3 luokkaa). Jakauma: Mies (72, 36%); Muu/en halua kertoa (10, 5%); Nainen (118, 59%)
#> 
#> [tyovuodet (Työvuodet nykyisessä organisaatiossa)] rooli: continuous
#> Puuttuvia: 0 / 200
#> Jatkuva muuttuja. Keskiarvo: 19.45, keskihajonta: 10.56, mediaani: 20.50, vaihteluväli: 1.00–35.00
#> 
#> [tt1 (Olen tyytyväinen nykyiseen työhöni)] rooli: likert
#> Puuttuvia: 0 / 200
#> Likert-tyyppinen muuttuja. Jakauma: 1 = 6, 2 = 20, 3 = 54, 4 = 71, 5 = 49. Keskiarvo: 3.68, keskihajonta: 1.04, mediaani: 4.00
#> 
#> [avoin_palaute] rooli: text
#> Puuttuvia: 22 / 200
#> Avoin tekstimuuttuja. Uniikkeja vastauksia: 8, keskipituus: 37 merkkiä.
```

The statistics text is currently always in Finnish. The `language`
argument only changes the language of the text the model writes.

## Example: letting the model write

These steps need a running Ollama. Model output should always be
reviewed before it is saved, so the functions that write files only
preview by default (`dry_run = TRUE`).

``` r
sd_check_ollama(model = "gemma3:12b")

# A readable description of the dataset
description <- sd_document(aineisto, language = "en")
print(description)

# Follow-up questions in the same conversation
description$chat$chat("Which items have the highest mean?")

# roxygen2 documentation for the ?survey_data help page
sd_generate_roxygen(aineisto, "survey_data", language = "en")   # preview
sd_generate_roxygen(aineisto, "survey_data", language = "en", dry_run = FALSE)
```

## Example: codebooks

``` r
sd_codebook(aineisto)                           # inst/codebook/codebook.html
sd_export_ddi(aineisto, file = "codebook.xml")  # DDI Codebook 2.6
```

## Keeping documentation up to date

``` r
# New variables: describe only those, keep the reviewed text
sd_check_documentation_current(aineisto, "survey_data")
sd_update_roxygen(aineisto, "survey_data", dry_run = FALSE)

# New respondents: fix the row count, no language model needed
sd_check_row_count(aineisto, "survey_data")
sd_update_row_count(aineisto, "survey_data", dry_run = FALSE)
```

## Learn more

The guides walk through setting up a documentation package for your own
dataset, from start to publishing a website. Each guide is available in
three languages:

- **Getting started**: [English](articles/getting-started.html),
  [suomeksi](articles/kayttoonotto.html), [på
  svenska](articles/kom-igang.html)
- **Using RAG** (adding background from your own reference material):
  [English](articles/using-rag.html),
  [suomeksi](articles/ragin-kaytto.html), [på
  svenska](articles/anvanda-rag.html)

Every function has its own help page, for example `?sd_read`,
`?sd_detect_roles` and `?sd_document`.
