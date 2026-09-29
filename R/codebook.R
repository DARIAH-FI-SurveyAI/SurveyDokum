#' Prepare survey data for codebook generation
#'
#' The data-preparation half of "06_generoi_codebook.R", pulled out so it
#' can be tested and used on its own without needing the \pkg{codebook}
#' package. Takes an `sd_data` object and returns a plain data frame with:
#' \itemize{
#'   \item variable labels and value labels attached as `label`/`labels`
#'     attributes (the same haven-style convention `sd_read()` reads them
#'     from) — this is what lets \pkg{codebook} show readable descriptions
#'     and value labels;
#'   \item automatically detected Likert-item groups turned into
#'     `<group>_mean` scale-score columns, so \pkg{codebook}'s reliability
#'     calculations (e.g. Cronbach's alpha) have something to work with.
#' }
#'
#' Likert groups are detected from variable names that share a common
#' prefix before a trailing number — e.g. `tt1`, `tt2`, `tt3`, `tt4`
#' become the group `"tt"`. This generalises the hardcoded
#' `tt_mean`/`joh_mean`/`imu_mean` computation from the original script.
#' Only variables with role `"likert"` (see `sd_detect_roles()`) are
#' considered, and a group needs at least `min_items` members by default
#' — a lone `"likert"` variable with no siblings is left alone.
#'
#' @param x An `sd_data` object.
#' @param groups Optional named list mapping a group name to a character
#'   vector of variable names, e.g. `list(tt = c("tt1", "tt2", "tt3"))`.
#'   Use this to override automatic detection — for instance when your
#'   scale items don't share a numbered-suffix naming pattern. `NULL`
#'   (the default) detects groups automatically.
#' @param min_items Minimum number of variables a detected group must
#'   have to be treated as a scale (default `2`). Ignored when `groups`
#'   is given explicitly.
#'
#' @return A data frame (not an `sd_data` object) with label/value-label
#'   attributes attached and scale-mean columns added, an
#'   attribute `"sd_groups"` recording which groups were used.
#' @export
#'
#' @examples
#' \dontrun{
#' aineisto <- sd_read("survey_data.sav")
#' aineisto <- sd_detect_roles(aineisto)
#' df <- sd_prepare_codebook_data(aineisto)
#' attr(df, "sd_groups")
#' }
sd_prepare_codebook_data <- function(x, groups = NULL, min_items = 2) {
  if (!is_sd_data(x)) {
    stop("`x` ei ole sd_data-olio (ks. sd_read()).", call. = FALSE)
  }

  if (is.null(groups)) {
    groups <- sd_detect_scale_groups_(x, min_items = min_items)
  }

  df <- x$data
  labels <- x$meta$labels
  vlabels <- x$meta$value_labels

  for (nm in intersect(names(labels), names(df))) {
    attr(df[[nm]], "label") <- labels[[nm]]
  }
  for (nm in intersect(names(vlabels), names(df))) {
    attr(df[[nm]], "labels") <- vlabels[[nm]]
  }

  if (length(groups) > 0) {
    for (g in names(groups)) {
      items <- groups[[g]]
      uusi_nimi <- paste0(g, "_mean")
      df[[uusi_nimi]] <- rowMeans(df[items], na.rm = FALSE)
      attr(df[[uusi_nimi]], "label") <- paste0(
        "Summamuuttuja (keskiarvo): ", paste(items, collapse = ", ")
      )
    }

    ryhma_teksti <- vapply(
      groups, function(v) paste(v, collapse = ", "), character(1)
    )
    message(
      "Havaittiin ", length(groups),
      if (length(groups) == 1) " Likert-ryhmä" else " Likert-ryhmää",
      " muuttujanimien yhteisen etuliitteen perusteella:\n",
      paste0("  ", names(groups), ": ", ryhma_teksti, collapse = "\n"),
      "\nLisätty summamuuttujat: ",
      paste(paste0(names(groups), "_mean"), collapse = ", ")
    )
  }

  attr(df, "sd_groups") <- groups
  df
}

# Ryhmittelee "likert"-roolin muuttujat yhteisen, numeroa edeltävän
# etuliitteen perusteella (esim. tt1, tt2, tt3 -> ryhmä "tt"). Säilyttää
# muuttujien alkuperäisen sarakejärjestyksen ryhmien sisällä.
sd_detect_scale_groups_ <- function(x, min_items = 2) {
  roles <- x$meta$roles
  if (length(roles) == 0) {
    return(list())
  }

  likert_vars <- names(roles)[roles == "likert"]
  if (length(likert_vars) == 0) {
    return(list())
  }

  etuliitteet <- sub("[0-9]+$", "", likert_vars)
  jarjestys <- unique(etuliitteet)

  ryhmat <- split(likert_vars, factor(etuliitteet, levels = jarjestys))
  ryhmat <- ryhmat[lengths(ryhmat) >= min_items]
  ryhmat <- lapply(ryhmat, as.character)
  ryhmat
}

#' Generate a codebook for a survey dataset
#'
#' The automated version of "06_generoi_codebook.R": prepares the data
#' with `sd_prepare_codebook_data()` (labels, value labels, automatic
#' Likert scale-mean columns), writes a minimal R Markdown document that
#' calls `codebook::codebook()` on it, and renders that document to a
#' self-contained HTML file with [rmarkdown::render()].
#'
#' @section Why via R Markdown:
#' `codebook::codebook()` is designed to run inside a knitted R Markdown
#' document — called directly at the console (as the original script
#' did) it returns a `knit_asis` object (confirmed by testing against a
#' real installation), which is only meaningful once actually knitted:
#' it isn't a complete, standalone HTML page on its own; plots and
#' interactive tables are only fully assembled during a real
#' `rmarkdown::render()` pass. So instead of guessing at that object,
#' `sd_codebook()` builds a tiny `.Rmd` behind the scenes and renders it
#' properly, which is the standard supported way to automate
#' \pkg{codebook} outside of RStudio's interactive Viewer/Ctrl+S
#' workflow.
#'
#' @param x An `sd_data` object.
#' @param out_dir Directory to save the codebook HTML to. Default
#'   `"inst/codebook"`, matching where a codebook is conventionally kept
#'   in a package.
#' @param file_name File name for the saved codebook. Defaults to
#'   `"codebook.html"`. A `.html` extension is added if missing.
#' @param groups,min_items Passed on to `sd_prepare_codebook_data()`.
#' @param overwrite If `FALSE` (the default) and the target file already
#'   exists, `sd_codebook()` refuses to overwrite it and raises an error
#'   instead — set `TRUE` once you've checked the existing file.
#'
#' @return An object of class `sd_codebook` with elements `data` (the
#'   prepared data frame passed into the codebook), `groups`
#'   (detected/used scale groups), `file` (the rendered HTML's path),
#'   and `created`.
#' @export
#'
#' @examples
#' \dontrun{
#' aineisto <- sd_read("survey_data.sav")
#' aineisto <- sd_detect_roles(aineisto)
#' tulos <- sd_codebook(aineisto)
#' tulos$file
#' }
sd_codebook <- function(x,
                         out_dir = "inst/codebook",
                         file_name = NULL,
                         groups = NULL,
                         min_items = 2,
                         overwrite = FALSE) {
  if (!is_sd_data(x)) {
    stop("`x` ei ole sd_data-olio (ks. sd_read()).", call. = FALSE)
  }

  df <- sd_prepare_codebook_data(x, groups = groups, min_items = min_items)
  havaitut_ryhmat <- attr(df, "sd_groups")

  if (!requireNamespace("codebook", quietly = TRUE)) {
    stop(
      "sd_codebook() vaatii codebook-paketin: install.packages(\"codebook\")",
      call. = FALSE
    )
  }
  if (!requireNamespace("rmarkdown", quietly = TRUE)) {
    stop(
      "sd_codebook() vaatii rmarkdown-paketin (yleensä valmiiksi asennettu ",
      "RStudion mukana): install.packages(\"rmarkdown\")",
      call. = FALSE
    )
  }

  if (is.null(file_name)) {
    file_name <- "codebook.html"
  }
  if (!grepl("\\.html?$", file_name, ignore.case = TRUE)) {
    file_name <- paste0(file_name, ".html")
  }
  polku <- file.path(out_dir, file_name)

  if (file.exists(polku) && !overwrite) {
    stop(
      "Tiedosto on jo olemassa: ", polku, "\n",
      "Tarkista sisältö ja aseta overwrite = TRUE jos haluat korvata sen, ",
      "tai anna toinen nimi file_name-argumentilla.",
      call. = FALSE
    )
  }
  if (!dir.exists(out_dir)) {
    dir.create(out_dir, recursive = TRUE)
  }

  message(
    "Renderöidään koodauskirja (codebook::codebook() + rmarkdown::render()). ",
    "Tämä voi kestää hetken -- jakaumat, kuvat ja mahdolliset ",
    "reliabiliteettilaskennat lasketaan nyt."
  )

  rmd_polku <- tempfile(fileext = ".Rmd")
  writeLines(sd_codebook_rmd_template_(), rmd_polku)
  on.exit(unlink(rmd_polku), add = TRUE)

  render_env <- new.env(parent = globalenv())
  assign("codebook_data", df, envir = render_env)

  tulos_polku <- tryCatch(
    rmarkdown::render(
      input       = rmd_polku,
      output_file = file_name,
      output_dir  = out_dir,
      envir       = render_env,
      quiet       = TRUE
    ),
    error = function(e) {
      stop(
        conditionMessage(e),
        "\n\nVinkki: varmista että codebook- ja rmarkdown-paketit (sekä ",
        "niiden riippuvuudet, esim. knitr) ovat kunnolla asennettuina. ",
        "rmarkdown::render() vaatii myös Pandocin -- RStudio sisältää sen ",
        "valmiina, mutta jos ajat ilman RStudiota, tarkista ",
        "rmarkdown::pandoc_available().",
        call. = FALSE
      )
    }
  )

  message("Koodauskirja tallennettu: ", tulos_polku)

  structure(
    list(
      data    = df,
      groups  = havaitut_ryhmat,
      file    = tulos_polku,
      created = Sys.time()
    ),
    class = "sd_codebook"
  )
}

# Minimaalinen .Rmd-pohja joka renderöi codebook::codebook()-tuloksen
# oikeaksi, itsenäiseksi HTML-tiedostoksi. "codebook_data" haetaan
# renderöinnin envir-parametrista (sd_codebook() asettaa sen).
#
# Huom: EI erillistä "setup"-nimistä lohkoa -- codebook::codebook() knittaa
# sisäisesti omaa pakettikohtaista sisältöään (havaittu käytännössä: se
# sisältää OMAN "setup"-nimisen lohkonsa), ja knitr vaatii lohkonimien
# olevan uniikkeja koko renderöinnin ajalta. Siksi kaikki on yhdessä
# selkeästi nimetyssä lohkossa, jonka nimi ei todennäköisesti törmää
# codebookin sisäisiin nimiin.
sd_codebook_rmd_template_ <- function() {
  c(
    "---",
    "title: \"Koodauskirja\"",
    "output: html_document",
    "---",
    "",
    "```{r sd-codebook-runko, echo=FALSE}",
    "knitr::opts_chunk$set(echo = FALSE)",
    "library(codebook)",
    "codebook(codebook_data)",
    "```"
  )
}

#' @export
print.sd_codebook <- function(x, ...) {
  cat("<sd_codebook>\n")
  cat("Tiedosto:", x$file, "\n")
  if (length(x$groups) > 0) {
    cat("Havaitut Likert-ryhmät:", paste(names(x$groups), collapse = ", "), "\n")
  }
  invisible(x)
}
