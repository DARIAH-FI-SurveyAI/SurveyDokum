#' Check whether a dataset's roxygen2 documentation is up to date
#'
#' A fast, LLM-free diagnostic: compares the variable names in `x` against
#' the variables already documented in the existing roxygen2 file (parsed
#' from its `\describe{}` block), and reports any that are missing. Run
#' this any time you suspect a dataset has grown new variables since it
#' was last documented -- if it finds any, follow up with
#' [sd_update_roxygen()].
#'
#' Because `sd_document()`'s descriptive text is based on the same
#' underlying data, undocumented variables here are also a signal that the
#' `sd_document()` text may be stale and worth regenerating.
#'
#' @param x An `sd_data` object.
#' @param object_name Name the documented object has, e.g. `"survey_data"`
#'   -- the same name used with [sd_generate_roxygen()].
#' @param file Path to the existing roxygen2 file. Defaults to
#'   `file.path("R", paste0(object_name, ".R"))`, matching
#'   [sd_generate_roxygen()]'s default.
#'
#' @return Invisibly, a character vector of variable names present in `x`
#'   but not found in `file`'s `\describe{}` block (empty if none). Called
#'   for its printed message.
#' @export
#'
#' @examples
#' \dontrun{
#' sd_check_documentation_current(aineisto, "survey_data")
#' }
sd_check_documentation_current <- function(x, object_name, file = NULL) {
  if (!is_sd_data(x)) {
    stop("`x` ei ole sd_data-olio (ks. sd_read()).", call. = FALSE)
  }
  sd_check_object_name_(object_name)

  if (is.null(file)) {
    file <- file.path("R", paste0(object_name, ".R"))
  }
  if (!file.exists(file)) {
    stop(
      "Tiedostoa ei löydy: ", file, "\n",
      "Luo dokumentaatio ensin sd_generate_roxygen()-funktiolla.",
      call. = FALSE
    )
  }

  teksti <- paste(readLines(file, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  dokumentoidut <- sd_parse_documented_vars_(teksti)

  if (is.null(dokumentoidut)) {
    stop(
      "Tiedostosta ", file, " ei löytynyt \\describe{}-lohkoa -- ",
      "automaattinen tunnistus ei onnistu tälle tiedostolle. Tarkista ",
      "tiedoston rakenne käsin.",
      call. = FALSE
    )
  }

  uudet <- setdiff(names(x$data), dokumentoidut)

  if (length(uudet) == 0) {
    message(
      "Dokumentaatio (", file, ") näyttää olevan ajan tasalla -- ",
      "kaikki ", ncol(x$data), " muuttujaa on dokumentoitu."
    )
  } else {
    message(
      "Datassa on ", length(uudet), " muuttujaa joita ei löydy tiedostosta ",
      file, ": ", paste(uudet, collapse = ", "), ".\n",
      "Aja sd_update_roxygen(x, \"", object_name, "\") päivittääksesi ",
      "roxygen2-dokumentaation. Koska sd_document()-kuvaus perustuu samaan ",
      "dataan, harkitse myös sen päivittämistä jos aineisto on muuttunut ",
      "merkittävästi."
    )
  }

  invisible(uudet)
}

#' Update roxygen2 documentation with newly added variables
#'
#' Surveys and other research datasets often grow new variables over time
#' -- computed sum scores, a new wave's questions, and so on. Regenerating
#' the whole roxygen2 block with [sd_generate_roxygen()] every time would
#' throw away any text you already reviewed and approved. `sd_update_roxygen()`
#' instead only asks the language model to describe the NEW variables, and
#' inserts them into the existing `\describe{}` block, leaving the title,
#' description, `@details`, `@source`, and all previously documented
#' variables untouched. The `@format` line's variable count is corrected
#' automatically (never left to the model).
#'
#' New variables are found automatically by parsing which variables are
#' already documented in `file` and comparing them to `names(x$data)` --
#' the same idea `sd_check_documentation_current()` uses. If that parsing
#' is uncertain (e.g. a heavily hand-edited file) or you simply know which
#' variables you want described, pass `new_vars` explicitly instead.
#'
#' By default (`dry_run = TRUE`) nothing is written to disk. Set
#' `dry_run = FALSE` to write the update; the previous version of `file` is
#' always copied to `<file>.bak` first, so an unwanted update can be
#' undone by restoring that copy.
#'
#' @param x An `sd_data` object containing the CURRENT, full set of
#'   variables (old and new).
#' @param object_name Name the documented object has, e.g. `"survey_data"`
#'   -- the same name used with [sd_generate_roxygen()].
#' @param file Path to the existing roxygen2 file to update. Defaults to
#'   `file.path("R", paste0(object_name, ".R"))`.
#' @param new_vars Character vector of variable names to describe. `NULL`
#'   (the default) auto-detects them by comparing `x` against what is
#'   already documented in `file`.
#' @param model,backend,timeout_s As in `sd_document()`.
#' @param language Language the new variable descriptions should be
#'   written in -- one of `"fi"` (Finnish, the default), `"en"`
#'   (English) or `"sv"` (Swedish). Should normally match the language `file` was already
#'   written in. See `sd_build_prompt()`.
#' @param dry_run If `TRUE` (the default), the updated text is only
#'   returned, not written to disk. Set to `FALSE` to write it to `file`
#'   (a `.bak` backup of the previous version is made first).
#'
#' @return An object of class `sd_roxygen_update` with elements `text`
#'   (the full updated file content), `added_vars` (character vector of
#'   variables that were newly documented -- empty if none were found),
#'   `file`, `backup_file` (path to the `.bak` copy, or `NULL` when
#'   `dry_run = TRUE` or nothing changed), `prompt`, `model`, `backend`,
#'   `chat`, and `created`.
#' @export
#'
#' @examples
#' \dontrun{
#' # aineisto sisältää nyt esim. uuden summamuuttujan "tt_mean":
#' tulos <- sd_update_roxygen(aineisto, "survey_data")
#' print(tulos)   # tarkista lisätyt kuvaukset ennen tallennusta
#' sd_update_roxygen(aineisto, "survey_data", dry_run = FALSE)
#' }
sd_update_roxygen <- function(x,
                               object_name,
                               file = NULL,
                               new_vars = NULL,
                               model = "gemma3:12b",
                               backend = "ollama",
                               language = "fi",
                               timeout_s = 1200,
                               dry_run = TRUE) {
  if (!is_sd_data(x)) {
    stop("`x` ei ole sd_data-olio (ks. sd_read()).", call. = FALSE)
  }
  sd_check_object_name_(object_name)
  sd_check_language_(language)

  if (is.null(file)) {
    file <- file.path("R", paste0(object_name, ".R"))
  }
  if (!file.exists(file)) {
    stop(
      "Tiedostoa ei löydy: ", file, "\n",
      "sd_update_roxygen() päivittää OLEMASSA OLEVAA roxygen2-",
      "dokumentaatiota -- luo se ensin sd_generate_roxygen()-funktiolla.",
      call. = FALSE
    )
  }

  alkuperainen <- paste(readLines(file, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  dokumentoidut <- sd_parse_documented_vars_(alkuperainen)
  kaikki_muuttujat <- names(x$data)

  if (is.null(new_vars)) {
    if (is.null(dokumentoidut)) {
      stop(
        "Muuttujien automaattinen tunnistus tiedostosta ", file, " ",
        "epäonnistui (ei löytynyt \\describe{}-lohkoa) -- anna `new_vars` ",
        "käsin listana uusien muuttujien nimistä.",
        call. = FALSE
      )
    }
    uudet <- setdiff(kaikki_muuttujat, dokumentoidut)
  } else {
    tuntemattomat <- setdiff(new_vars, kaikki_muuttujat)
    if (length(tuntemattomat) > 0) {
      stop(
        "`new_vars` sisältää muuttujia joita ei löydy datasta: ",
        paste(tuntemattomat, collapse = ", "), ".",
        call. = FALSE
      )
    }
    if (!is.null(dokumentoidut)) {
      jo_dokumentoitu <- intersect(new_vars, dokumentoidut)
      if (length(jo_dokumentoitu) > 0) {
        warning(
          "Nämä new_vars-muuttujat näyttävät jo dokumentoiduilta ",
          "tiedostossa ", file, " -- dokumentoidaan silti uudelleen ",
          "pyynnöstä: ", paste(jo_dokumentoitu, collapse = ", "),
          call. = FALSE
        )
      }
    }
    uudet <- new_vars
  }

  if (length(uudet) == 0) {
    message(
      "Ei uusia dokumentoimattomia muuttujia löytynyt -- dokumentaatio (",
      file, ") näyttää olevan ajan tasalla."
    )
    return(invisible(structure(
      list(
        text = alkuperainen, added_vars = character(0), file = file,
        backup_file = NULL, prompt = NULL, model = model, backend = backend,
        chat = NULL, created = Sys.time()
      ),
      class = "sd_roxygen_update"
    )))
  }

  kehote <- sd_build_roxygen_update_prompt_(x, uudet, language)

  system_prompt <- if (identical(language, "en")) {
    paste(
      "You are an expert in R programming and survey research.",
      "You write precise, professional roxygen2 \\item{}{} documentation",
      "lines in English.",
      "You use the given information as-is -- you do not invent additional details."
    )
  } else if (identical(language, "sv")) {
    paste(
      "Du är expert på R-programmering och enkätforskning.",
      "Du skriver exakta, professionella roxygen2 \\item{}{}-dokumentationsrader",
      "på svenska.",
      "Du använder given information som den är — du hittar inte på ytterligare detaljer."
    )
  } else {
    paste(
      "Olet R-ohjelmoinnin ja survey-tutkimuksen asiantuntija.",
      "Kirjoitat tarkkoja, ammattimaisia roxygen2 \\item{}{}-dokumentaatioriviä",
      "suomeksi.",
      "Käytät annettuja tietoja sellaisenaan — et keksi lisätietoja."
    )
  }

  tulos <- sd_ollama_chat_(
    prompt        = kehote,
    model         = model,
    backend       = backend,
    system_prompt = system_prompt,
    timeout_s     = timeout_s
  )

  vastaus <- sd_clean_llm_code_(tulos$text)
  saadut_rivit <- sd_extract_items_(vastaus)

  # Varmista deterministisesti että JOKAINEN pyydetty muuttuja saa rivin,
  # vaikka LLM unohtaisi jonkin -- ks. yleinen oppi 9 (älä luota pelkkään
  # kehotteeseen kun tiedetään etukäteen mitä pitää syntyä).
  varapaikka <- if (identical(language, "en")) {
    "(description could not be generated automatically -- please edit)"
  } else if (identical(language, "sv")) {
    "(beskrivningen kunde inte genereras automatiskt -- redigera vid behov)"
  } else {
    "(kuvausta ei saatu automaattisesti -- muokkaa tarvittaessa)"
  }
  for (nm in setdiff(uudet, names(saadut_rivit))) {
    saadut_rivit[[nm]] <- varapaikka
  }

  uudet_item_rivit <- vapply(
    uudet,
    function(nm) paste0("  \\item{", nm, "}{", saadut_rivit[[nm]], "}"),
    character(1)
  )

  paivitetty <- sd_insert_items_(alkuperainen, uudet_item_rivit)
  paivitetty <- sd_fix_format_var_count_(paivitetty, ncol(x$data))

  varmuuskopio <- NULL
  if (isTRUE(dry_run)) {
    message(
      "dry_run = TRUE (oletus) — muutosta ei kirjoitettu tiedostoon, vain ",
      "palautettiin. Tarkista teksti (print()/cat()) ja aja uudelleen ",
      "dry_run = FALSE kun olet tyytyväinen. Uudet muuttujat: ",
      paste(uudet, collapse = ", ")
    )
  } else {
    varmuuskopio <- paste0(file, ".bak")
    file.copy(file, varmuuskopio, overwrite = TRUE)
    # useBytes = TRUE: teksti on jo UTF-8-koodattua (roxygen2-tiedostot ovat
    # perinteisesti UTF-8), joten kirjoitetaan tavut sellaisenaan äläkä
    # yritetä muuntaa nykyisen locale-asetuksen mukaan -- muuten esim.
    # suomalaiset ääkköset voisivat vioittua jos R-istunnon locale ei ole
    # UTF-8 (ks. yleinen oppi 16).
    writeLines(paivitetty, file, useBytes = TRUE)
    message(
      "Roxygen2-dokumentaatio päivitetty tiedostoon: ", file, "\n",
      "Alkuperäinen versio varmuuskopioitu tiedostoon: ", varmuuskopio, "\n",
      "Lisätyt muuttujat: ", paste(uudet, collapse = ", ")
    )
  }

  structure(
    list(
      text = paivitetty, added_vars = uudet, file = file,
      backup_file = varmuuskopio, prompt = kehote, model = model,
      backend = backend, chat = tulos$chat, created = Sys.time()
    ),
    class = "sd_roxygen_update"
  )
}

#' @export
print.sd_roxygen_update <- function(x, ...) {
  if (length(x$added_vars) == 0) {
    cat("Ei uusia muuttujia -- dokumentaatio on ajan tasalla.\n")
  } else {
    cat("Lisätyt muuttujat:", paste(x$added_vars, collapse = ", "), "\n\n")
    cat(x$text, "\n")
  }
  invisible(x)
}

#' Check whether a roxygen2 file's documented row count matches the data
#'
#' A fast, LLM-free diagnostic, symmetric to [sd_check_documentation_current()]
#' but for ROWS (respondents) instead of variables. Reads the row count
#' recorded in the existing roxygen2 file's `@format` line (e.g. "A data
#' frame with 200 rows and 17 variables:") and compares it to
#' `nrow(x$data)`.
#'
#' Unlike new variables, new rows do not require any change to the
#' `\describe{}` block itself -- only the row count in `@format` needs
#' correcting, which [sd_update_row_count()] does deterministically. But
#' because `sd_document()`'s descriptive text (respondent counts,
#' distributions, and so on) is computed from the WHOLE dataset, a change
#' in row count is also a strong signal that that text is now stale and
#' worth regenerating by hand with `sd_document()` -- this function does
#' not attempt to do that automatically.
#'
#' @param x An `sd_data` object containing the CURRENT data.
#' @param object_name Name the documented object has, e.g. `"survey_data"`
#'   -- the same name used with [sd_generate_roxygen()].
#' @param file Path to the existing roxygen2 file. Defaults to
#'   `file.path("R", paste0(object_name, ".R"))`.
#'
#' @return Invisibly, the difference `nrow(x$data) - <documented count>`
#'   (`0` when up to date). Called for its printed message.
#' @export
#'
#' @examples
#' \dontrun{
#' sd_check_row_count(aineisto, "survey_data")
#' }
sd_check_row_count <- function(x, object_name, file = NULL) {
  if (!is_sd_data(x)) {
    stop("`x` ei ole sd_data-olio (ks. sd_read()).", call. = FALSE)
  }
  sd_check_object_name_(object_name)

  if (is.null(file)) {
    file <- file.path("R", paste0(object_name, ".R"))
  }
  if (!file.exists(file)) {
    stop(
      "Tiedostoa ei löydy: ", file, "\n",
      "Luo dokumentaatio ensin sd_generate_roxygen()-funktiolla.",
      call. = FALSE
    )
  }

  teksti <- paste(readLines(file, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  dokumentoitu <- sd_extract_format_row_count_(teksti)

  if (is.na(dokumentoitu)) {
    stop(
      "Tiedoston ", file, " @format-riviltä ei löytynyt tunnistettavaa ",
      "rivimäärää (odotettu esim. \"200 riviä\"/\"200 rows\"/\"200 rader\") ",
      "-- ehkä rivi on käsin muokattu. Tarkista tiedoston rakenne käsin.",
      call. = FALSE
    )
  }

  nykyinen <- nrow(x$data)

  if (identical(nykyinen, dokumentoitu)) {
    message(
      "Rivimäärä (", file, ") on ajan tasalla -- sekä data että ",
      "dokumentaatio kertovat ", nykyinen, " riviä (vastaajaa)."
    )
  } else {
    message(
      "Datassa on nyt ", nykyinen, " riviä (vastaajaa), mutta ",
      file, " kertoo ", dokumentoitu, ". ",
      "Aja sd_update_row_count(x, \"", object_name, "\") päivittääksesi ",
      "@format-rivin rivimäärän. Koska sd_document()-kuvaus (esim. ",
      "vastaajamäärä, jakaumat) perustuu koko aineistoon, harkitse myös ",
      "sen uudelleengenerointia käsin jos muutos on merkittävä."
    )
  }

  invisible(nykyinen - dokumentoitu)
}

#' Update a roxygen2 file's row count for new observations
#'
#' Companion to [sd_update_roxygen()], but for new ROWS (respondents)
#' instead of new variables. When a dataset gains observations but no new
#' variables, the `\describe{}` block itself needs no change -- only the
#' row count recorded in the `@format` line (e.g. "... with 200 rows and
#' 17 variables:") is now wrong. `sd_update_row_count()` corrects that
#' number deterministically -- no language model call is needed, because
#' unlike a variable description, a row count has exactly one correct
#' value.
#'
#' This function intentionally does NOT touch `sd_document()`'s
#' descriptive text -- its prose (respondent counts, distributions, and
#' so on) is generated from the whole dataset and cannot be patched
#' incrementally the way new variable descriptions can. Re-run
#' `sd_document()` by hand if the row-count change is significant enough
#' to warrant it. See [sd_check_row_count()] for a quick check of
#' whether an update is needed at all.
#'
#' @param x An `sd_data` object containing the CURRENT, full data
#'   (including the new rows).
#' @param object_name Name the documented object has, e.g. `"survey_data"`
#'   -- the same name used with [sd_generate_roxygen()].
#' @param file Path to the existing roxygen2 file to update. Defaults to
#'   `file.path("R", paste0(object_name, ".R"))`.
#' @param dry_run If `TRUE` (the default), the updated text is only
#'   returned, not written to disk. Set to `FALSE` to write it to `file`
#'   (a `.bak` backup of the previous version is made first, as in
#'   [sd_update_roxygen()]).
#'
#' @return An object of class `sd_row_count_update` with elements `text`
#'   (the full updated file content), `old_count`, `new_count`, `file`,
#'   `backup_file` (path to the `.bak` copy, or `NULL` when
#'   `dry_run = TRUE` or nothing changed), and `created`.
#' @export
#'
#' @examples
#' \dontrun{
#' # aineistoon on lisätty uusia vastaajia, muuttujat pysyivät samoina:
#' tulos <- sd_update_row_count(aineisto, "survey_data")
#' print(tulos)   # tarkista muutos ennen tallennusta
#' sd_update_row_count(aineisto, "survey_data", dry_run = FALSE)
#' }
sd_update_row_count <- function(x, object_name, file = NULL, dry_run = TRUE) {
  if (!is_sd_data(x)) {
    stop("`x` ei ole sd_data-olio (ks. sd_read()).", call. = FALSE)
  }
  sd_check_object_name_(object_name)

  if (is.null(file)) {
    file <- file.path("R", paste0(object_name, ".R"))
  }
  if (!file.exists(file)) {
    stop(
      "Tiedostoa ei löydy: ", file, "\n",
      "sd_update_row_count() päivittää OLEMASSA OLEVAA roxygen2-",
      "dokumentaatiota -- luo se ensin sd_generate_roxygen()-funktiolla.",
      call. = FALSE
    )
  }

  alkuperainen <- paste(readLines(file, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  vanha <- sd_extract_format_row_count_(alkuperainen)

  if (is.na(vanha)) {
    stop(
      "Tiedoston ", file, " @format-riviltä ei löytynyt tunnistettavaa ",
      "rivimäärää (odotettu esim. \"200 riviä\"/\"200 rows\"/\"200 rader\") ",
      "-- ehkä rivi on käsin muokattu. Päivitä @format-rivi käsin.",
      call. = FALSE
    )
  }

  uusi <- nrow(x$data)

  if (identical(uusi, vanha)) {
    message(
      "Rivimäärä ei ole muuttunut (", uusi, ") -- dokumentaatio (", file,
      ") näyttää olevan ajan tasalla."
    )
    return(invisible(structure(
      list(
        text = alkuperainen, old_count = vanha, new_count = uusi,
        file = file, backup_file = NULL, created = Sys.time()
      ),
      class = "sd_row_count_update"
    )))
  }

  paivitetty <- sd_fix_format_row_count_(alkuperainen, uusi)

  varmuuskopio <- NULL
  if (isTRUE(dry_run)) {
    message(
      "dry_run = TRUE (oletus) — muutosta ei kirjoitettu tiedostoon, vain ",
      "palautettiin. Rivimäärä: ", vanha, " -> ", uusi, ". Aja uudelleen ",
      "dry_run = FALSE kun olet tyytyväinen."
    )
  } else {
    varmuuskopio <- paste0(file, ".bak")
    file.copy(file, varmuuskopio, overwrite = TRUE)
    # useBytes = TRUE: ks. sd_update_roxygen():n vastaava kommentti (oppi 16).
    writeLines(paivitetty, file, useBytes = TRUE)
    message(
      "Roxygen2-dokumentaation rivimäärä päivitetty tiedostoon: ", file, "\n",
      "Alkuperäinen versio varmuuskopioitu tiedostoon: ", varmuuskopio, "\n",
      "Rivimäärä: ", vanha, " -> ", uusi
    )
  }

  structure(
    list(
      text = paivitetty, old_count = vanha, new_count = uusi, file = file,
      backup_file = varmuuskopio, created = Sys.time()
    ),
    class = "sd_row_count_update"
  )
}

#' @export
print.sd_row_count_update <- function(x, ...) {
  if (identical(x$old_count, x$new_count)) {
    cat("Rivimäärä ei muuttunut (", x$new_count, ") -- ajan tasalla.\n", sep = "")
  } else {
    cat("Rivimäärä päivitetty:", x$old_count, "->", x$new_count, "\n\n")
    cat(x$text, "\n")
  }
  invisible(x)
}

# -- Sisäiset apufunktiot: roxygen-tiedoston jäsennys ja muokkaus ------
#
# Näiden varassa sd_update_roxygen()/sd_check_documentation_current()
# lukevat mitä muuttujia on JO dokumentoitu (sd_parse_documented_vars_),
# jäsentävät LLM:n vastauksen \item-riveiksi (sd_extract_items_), ja
# lisäävät uudet rivit olemassa olevaan \describe{}-lohkoon
# (sd_insert_items_) sekä korjaavat @format-rivin muuttujamäärän
# (sd_fix_format_var_count_) deterministisesti koodissa -- ei LLM:n
# varaan, ks. yleinen oppi 9.

# Etsii tekstistä sulkevan aaltosulun jolle `start` on vastaava avaava
# aaltosulku JÄLKEEN (eli `start` osoittaa ensimmäiseen merkkiin sisällön
# alussa). Ottaa huomioon sisäkkäiset aaltosulut. Palauttaa
# list(content=..., end=...) missä `end` on indeksi heti sulkevan
# aaltosulun jälkeen, tai NULL jos sulkeva aaltosulku puuttuu.
sd_extract_braces_ <- function(text, start) {
  n <- nchar(text)
  if (start > n) return(NULL)

  depth <- 1L
  for (i in start:n) {
    ch <- substr(text, i, i)
    if (ch == "{") {
      depth <- depth + 1L
    } else if (ch == "}") {
      depth <- depth - 1L
      if (depth == 0L) {
        return(list(content = substr(text, start, i - 1L), end = i + 1L))
      }
    }
  }
  NULL
}

# Jäsentää roxygen2-tiedoston tekstistä mitkä muuttujat on jo dokumentoitu
# (\describe{}-lohkon \item{nimi}{...}-rivit). Palauttaa character(0) jos
# lohko löytyy mutta on tyhjä, ja NULL jos \describe{}-lohkoa ei löydy
# lainkaan (ero on tärkeä: NULL tarkoittaa "automaattinen tunnistus ei
# onnistu", character(0) tarkoittaa "tunnistus onnistui, ei vain löytynyt
# mitään").
sd_parse_documented_vars_ <- function(text) {
  alku <- regexpr("\\describe{", text, fixed = TRUE)
  if (alku[1] == -1L) return(NULL)

  lohko_alku <- alku[1] + attr(alku, "match.length")
  lohko <- sd_extract_braces_(text, lohko_alku)
  if (is.null(lohko)) return(NULL)

  osumat <- gregexpr("\\item{", lohko$content, fixed = TRUE)[[1]]
  if (osumat[1] == -1L) return(character(0))
  pituudet <- attr(osumat, "match.length")

  nimet <- character(0)
  for (k in seq_along(osumat)) {
    nimi_alku <- osumat[k] + pituudet[k]
    nimi <- sd_extract_braces_(lohko$content, nimi_alku)
    if (!is.null(nimi)) nimet <- c(nimet, trimws(nimi$content))
  }
  unique(nimet)
}

# Jäsentää LLM:n vastauksesta \item{nimi}{kuvaus}-rivit nimetyksi listaksi
# (nimi -> kuvaus). Sietää välilyöntejä/rivinvaihtoja nimen ja kuvauksen
# sulkujen välissä, koska mallit eivät aina noudata kehotetta pilkuntarkasti.
sd_extract_items_ <- function(text) {
  osumat <- gregexpr("\\item{", text, fixed = TRUE)[[1]]
  if (osumat[1] == -1L) return(list())
  pituudet <- attr(osumat, "match.length")

  tulos <- list()
  n <- nchar(text)
  for (k in seq_along(osumat)) {
    nimi_alku <- osumat[k] + pituudet[k]
    nimi <- sd_extract_braces_(text, nimi_alku)
    if (is.null(nimi)) next

    pos <- nimi$end
    while (pos <= n && substr(text, pos, pos) %in% c(" ", "\n", "\t", "\r")) {
      pos <- pos + 1L
    }
    if (pos > n || substr(text, pos, pos) != "{") next

    kuvaus <- sd_extract_braces_(text, pos + 1L)
    if (is.null(kuvaus)) next

    tulos[[trimws(nimi$content)]] <- trimws(kuvaus$content)
  }
  tulos
}

# Lisää uudet \item-rivit olemassa olevan tiedoston \describe{}-lohkoon,
# juuri ennen sen sulkevaa aaltosulkua. Pysäyttää selkeällä virheellä jos
# lohkoa ei löydy -- ei arvaa/riko tiedostoa hiljaisesti.
sd_insert_items_ <- function(text, uudet_rivit) {
  alku <- regexpr("\\describe{", text, fixed = TRUE)
  if (alku[1] == -1L) {
    stop(
      "Tiedostosta ei löytynyt \\describe{}-lohkoa -- automaattinen ",
      "päivitys ei onnistu tälle tiedostolle. Tarkista tiedoston rakenne ",
      "tai päivitä se käsin.",
      call. = FALSE
    )
  }

  lohko_alku <- alku[1] + attr(alku, "match.length")
  lohko <- sd_extract_braces_(text, lohko_alku)
  if (is.null(lohko)) {
    stop(
      "\\describe{}-lohkon sulkevaa aaltosulkua ei löytynyt -- tiedosto ",
      "saattaa olla rikki tai käsin muokattu tavalla joka estää ",
      "automaattisen päivityksen.",
      call. = FALSE
    )
  }

  sulku_kohta <- lohko$end - 1L
  ennen <- substr(text, 1, sulku_kohta - 1L)
  jalkeen <- substr(text, sulku_kohta, nchar(text))

  paste0(ennen, "\n", paste(uudet_rivit, collapse = "\n"), "\n", jalkeen)
}

# Korjaa @format-rivin muuttujamäärän deterministisesti (esim.
# "... jossa 200 riviä ja 17 muuttujaa:" -> "... 19 muuttujaa:") vastaamaan
# datan nykyistä sarakemäärää. Tunnistaa nykyisen tekstin kielen suoraan
# rivin sanoista ("muuttujaa" vs. "variables" vs. "variabler") sen sijaan
# että vaatisi language-argumentin -- rivin oma kieli on se joka ratkaisee,
# ei kutsun language-parametri (ks. myös sd_update_roxygen()'s language,
# joka koskee vain UUSIEN muuttujien kuvauksia). Jos rivi ei täsmää mihinkään
# sanamalliin (esim. käsin muokattu), jätetään koskematta.
sd_fix_format_var_count_ <- function(text, uusi_maara) {
  rivit <- strsplit(text, "\n", fixed = TRUE)[[1]]
  kohde <- grep("^#'\\s*@format\\b", rivit)
  if (length(kohde) == 0L) return(text)

  i <- kohde[1]
  if (grepl("\\bmuuttujaa\\b", rivit[i])) {
    rivit[i] <- sub(
      "(\\d+)(\\s+muuttujaa\\b)", paste0(uusi_maara, "\\2"), rivit[i],
      perl = TRUE
    )
  } else if (grepl("\\bvariabler\\b", rivit[i])) {
    rivit[i] <- sub(
      "(\\d+)(\\s+variabler\\b)", paste0(uusi_maara, "\\2"), rivit[i],
      perl = TRUE
    )
  } else if (grepl("\\bvariables\\b", rivit[i])) {
    rivit[i] <- sub(
      "(\\d+)(\\s+variables\\b)", paste0(uusi_maara, "\\2"), rivit[i],
      perl = TRUE
    )
  }

  paste(rivit, collapse = "\n")
}

# Etsii @format-riviltä tekstissä jo dokumentoidun rivimäärän (esim.
# "jossa 200 riviä ja 2 muuttujaa:" -> 200L). Tunnistaa rivin kielen
# suoraan sanoista ("riviä"/"rows"/"rader"), samaan tapaan kuin
# sd_fix_format_var_count_(). Palauttaa NA_integer_ jos @format-riviä ei
# löydy tai rivimäärää ei tunnisteta (esim. käsin muokattu rivi).
sd_extract_format_row_count_ <- function(text) {
  rivit <- strsplit(text, "\n", fixed = TRUE)[[1]]
  kohde <- grep("^#'\\s*@format\\b", rivit)
  if (length(kohde) == 0L) return(NA_integer_)

  rivi <- rivit[kohde[1]]
  sana <- if (grepl("\\briviä\\b", rivi)) {
    "riviä"
  } else if (grepl("\\brader\\b", rivi)) {
    "rader"
  } else if (grepl("\\brows\\b", rivi)) {
    "rows"
  } else {
    NA_character_
  }
  if (is.na(sana)) return(NA_integer_)

  # (*UCP): "riviä" sisältää ei-ASCII-merkin ("ä"), ja ilman tätä PCRE:n
  # \b-sanaraja ei tunnista sitä sanamerkiksi (TRE-moottori, jota grepl()
  # käyttää ilman perl=TRUE:ta, tekee tämän jo oletuksena -- vain
  # perl=TRUE-tilassa tarvitaan eksplisiittinen (*UCP)).
  kuvio <- paste0("(*UCP)(\\d+)(?=\\s+", sana, "\\b)")
  osuma <- regmatches(rivi, regexpr(kuvio, rivi, perl = TRUE))
  if (length(osuma) == 0L) return(NA_integer_)
  as.integer(osuma)
}

# Korjaa @format-rivin RIVIMÄÄRÄN deterministisesti (esim. "... jossa 200
# riviä ja 17 muuttujaa:" -> "... jossa 250 riviä ..."), analogisesti
# sd_fix_format_var_count_():n kanssa mutta rivimäärälle eikä
# muuttujamäärälle. Jos rivi ei täsmää mihinkään sanamalliin (esim. käsin
# muokattu), jätetään koskematta.
sd_fix_format_row_count_ <- function(text, uusi_maara) {
  rivit <- strsplit(text, "\n", fixed = TRUE)[[1]]
  kohde <- grep("^#'\\s*@format\\b", rivit)
  if (length(kohde) == 0L) return(text)

  i <- kohde[1]
  if (grepl("\\briviä\\b", rivit[i])) {
    # (*UCP): ks. sd_extract_format_row_count_():n kommentti -- "riviä"
    # sisältää ei-ASCII-merkin, joten PCRE tarvitsee eksplisiittisen
    # Unicode-sanaraja-tilan \b:n tunnistaakseen sen oikein.
    rivit[i] <- sub(
      "(*UCP)(\\d+)(\\s+riviä\\b)", paste0(uusi_maara, "\\2"), rivit[i],
      perl = TRUE
    )
  } else if (grepl("\\brader\\b", rivit[i])) {
    rivit[i] <- sub(
      "(\\d+)(\\s+rader\\b)", paste0(uusi_maara, "\\2"), rivit[i],
      perl = TRUE
    )
  } else if (grepl("\\brows\\b", rivit[i])) {
    rivit[i] <- sub(
      "(\\d+)(\\s+rows\\b)", paste0(uusi_maara, "\\2"), rivit[i],
      perl = TRUE
    )
  }

  paste(rivit, collapse = "\n")
}

# Rakentaa kehotteen JOTA käytetään VAIN uusien muuttujien kuvaamiseen --
# ei koko roxygen-lohkoa (otsikko, @format, @details, @source pysyvät
# koskemattomina sd_update_roxygen()-funktiossa). Käyttää samaa
# sd_roxygen_var_line_()-apufunktiota kuin sd_build_roxygen_prompt(), joten
# muuttujien kuvausformaatti on identtinen alkuperäisen generoinnin kanssa.
sd_build_roxygen_update_prompt_ <- function(x, new_vars, language = "fi") {
  ohje <- if (identical(language, "en")) {
    paste0(
      "You are documenting NEW variables added to a survey dataset that ",
      "already has roxygen2 documentation. Below are the details of ONLY ",
      "the new variables -- do not describe any other variable.\n\n",
      "IMPORTANT: Write PLAIN R code with no markdown formatting. ",
      "Do not use ```r or ``` fences. Respond with EXACTLY one line per ",
      "variable, in the SAME ORDER as given below, each in this exact ",
      "form:\n\n",
      "#'   \\item{variable_name}{Description. Type. Values if categorical.}\n\n",
      "Do not add a title, @format, @details, @source, or any other text ",
      "-- ONLY the \\item lines, one per variable listed below. Use ONLY ",
      "the information given -- do not invent new figures or variables."
    )
  } else if (identical(language, "sv")) {
    paste0(
      "Du dokumenterar NYA variabler som har lagts till i ett enkätdataset ",
      "som redan har roxygen2-dokumentation. Nedan finns uppgifter om ENDAST ",
      "de nya variablerna -- beskriv ingen annan variabel.\n\n",
      "VIKTIGT: Skriv REN R-kod utan markdown-formatering. ",
      "Använd inte ```r eller ``` -tecken. Svara med EXAKT en rad per ",
      "variabel, i SAMMA ORDNING som anges nedan, var och en i denna ",
      "exakta form:\n\n",
      "#'   \\item{variabelnamn}{Beskrivning. Typ. Värden om kategorisk.}\n\n",
      "Lägg inte till någon titel, @format, @details, @source eller annan ",
      "text -- ENDAST \\item-raderna, en per variabel listad nedan. Använd ",
      "ENDAST given information -- hitta inte på nya siffror eller variabler."
    )
  } else {
    paste0(
      "Dokumentoit UUSIA muuttujia, jotka on lisätty survey-aineistoon ",
      "jolla on jo roxygen2-dokumentaatio. Alla on tiedot VAIN uusista ",
      "muuttujista -- älä kuvaa mitään muuta muuttujaa.\n\n",
      "TÄRKEÄÄ: Kirjoita PELKKÄ R-koodi ilman markdown-muotoilua. ",
      "Älä käytä ```r tai ``` -merkkejä. Vastaa TÄSMÄLLEEN yhdellä ",
      "rivillä per muuttuja, SAMASSA JÄRJESTYKSESSÄ kuin alla, kukin ",
      "tässä muodossa:\n\n",
      "#'   \\item{muuttujan_nimi}{Kuvaus. Tyyppi. Arvot jos kategorinen.}\n\n",
      "Älä lisää otsikkoa, @format-, @details- tai @source-osioita tai ",
      "mitään muuta tekstiä -- VAIN \\item-rivit, yksi per alla listattu ",
      "muuttuja. Käytä VAIN annettuja tietoja äläkä keksi uusia lukuja ",
      "tai muuttujia."
    )
  }

  muuttuja_teksti <- paste(
    vapply(new_vars, function(nm) sd_roxygen_var_line_(x, nm, language), character(1)),
    collapse = "\n\n"
  )

  otsikko <- switch(language,
    en = "NEW VARIABLES:",
    sv = "NYA VARIABLER:",
    "UUDET MUUTTUJAT:"
  )
  paste0(ohje, "\n\n", otsikko, "\n", muuttuja_teksti)
}
