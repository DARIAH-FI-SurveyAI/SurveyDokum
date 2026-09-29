#' Build the roxygen2-generation prompt from an sd_data object
#'
#' Turns the metadata already attached to an `sd_data` object (variable
#' labels, value labels, missing counts, dataset-level paradata) into the
#' full text prompt that `sd_generate_roxygen()` sends to the language
#' model. Kept separate from `sd_generate_roxygen()` so the prompt can be
#' inspected or unit-tested without needing Ollama (or any model)
#' running — the same idea as `sd_build_prompt()` for `sd_document()`.
#'
#' Only metadata is included (labels, value labels, per-variable missing
#' counts, dataset-level paradata) — never the raw data values themselves,
#' so open-text responses are never sent to the model.
#'
#' @param x An `sd_data` object.
#' @param object_name Name the documented object will have once saved
#'   with `usethis::use_data()`, e.g. `"survey_data"`. Written into the
#'   generated roxygen2 block as the final line (the line that normally
#'   follows a dataset's documentation and names the object it documents).
#' @param instructions Character string with the instructions placed
#'   before the dataset information. `NULL` (the default) uses a built-in
#'   instruction template (see `language`) asking for a roxygen2 block
#'   following the usual `@format`/`@details`/`@source` structure for a
#'   documented dataset.
#' @param language Language of the built-in `instructions` template (and
#'   of the small field labels in the dataset-information block, e.g.
#'   "Label"/"Type"/"Missing") when `instructions` is left at its default
#'   `NULL` -- one of `"fi"` (Finnish, the default), `"en"` (English) or
#'   `"sv"` (Swedish).
#'   Has no effect when `instructions` is supplied explicitly. Independent
#'   of the language the survey data itself (variable labels etc.)
#'   happens to be in -- see `sd_build_prompt()` for the same idea applied
#'   to `sd_document()`.
#' @param context Optional character string of retrieved background
#'   material to insert before the dataset information -- typically the
#'   output of `sd_retrieve_context()`. `NULL` (the default) omits this
#'   section entirely, leaving the prompt exactly as before this
#'   parameter was added.
#'
#' @return A single character string: the full prompt.
#' @export
#'
#' @examples
#' \dontrun{
#' aineisto <- sd_read("survey_data.csv")
#' kehote <- sd_build_roxygen_prompt(aineisto, "survey_data")
#' cat(kehote)
#'
#' # Englanninkielinen roxygen-dokumentaatio samasta aineistosta:
#' kehote_en <- sd_build_roxygen_prompt(aineisto, "survey_data", language = "en")
#'
#' # RAG-taustatiedolla:
#' store <- ragnar::ragnar_store_connect("oma_rag_store.ragnar.duckdb")
#' kehote_rag <- sd_build_roxygen_prompt(
#'   aineisto, "survey_data",
#'   context = sd_retrieve_context(aineisto, store)
#' )
#' }
# Yhteinen object_name-validointi kaikille funktioille jotka käsittelevät
# roxygen2-datadokumentaatiota (sd_build_roxygen_prompt(), sd_generate_roxygen(),
# sd_update_roxygen(), sd_check_documentation_current() -- ks. update.R). Sama
# tarkistus, sama virheviesti kaikkialla -- ks. yleinen oppi 7.
sd_check_object_name_ <- function(object_name) {
  if (!is.character(object_name) || length(object_name) != 1 || !nzchar(object_name)) {
    stop(
      "`object_name` pitää olla yhden objektin nimi merkkijonona ",
      "(esim. \"survey_data\") — nimi jonka annat usethis::use_data():lle.",
      call. = FALSE
    )
  }
  invisible(object_name)
}

sd_build_roxygen_prompt <- function(x, object_name, instructions = NULL,
                                     language = "fi", context = NULL) {
  if (!is_sd_data(x)) {
    stop("`x` ei ole sd_data-olio (ks. sd_read()).", call. = FALSE)
  }
  sd_check_object_name_(object_name)
  sd_check_language_(language)

  if (is.null(instructions)) {
    instructions <- sd_default_roxygen_instructions_(object_name, language)
  }

  otsikko <- switch(language,
    en = "DATASET INFORMATION:",
    sv = "DATASETUPPGIFTER:",
    "AINEISTON TIEDOT:"
  )

  osiot <- instructions
  if (!is.null(context) && nzchar(context)) {
    tausta_otsikko <- switch(language,
      en = "BACKGROUND MATERIAL (for reference -- use only if relevant, do not quote verbatim):",
      sv = "BAKGRUNDSMATERIAL (endast som referens -- citera inte ordagrant):",
      "TAUSTA-AINEISTO (vain viitteeksi -- kayta harkiten, ala lainaa sanasta sanaan):"
    )
    osiot <- paste0(osiot, "\n\n", tausta_otsikko, "\n", context)
  }

  paste0(osiot, "\n\n", otsikko, "\n", sd_roxygen_data_summary_(x, language))
}

sd_default_roxygen_instructions_ <- function(object_name, language = "fi") {
  if (identical(language, "en")) {
    return(paste0(
      "You have been given a survey dataset's metadata and variable descriptions.\n",
      "Write a complete roxygen2 documentation block for an R package from them.\n",
      "IMPORTANT: Write PLAIN R code with no markdown formatting. ",
      "Do not use ```r or ``` fences. Start directly with the #' marker.\n\n",

      "Follow this roxygen2 structure EXACTLY:\n\n",

      "#' [Name of the dataset]\n",
      "#'\n",
      "#' [2-3 sentence description of the dataset: topic, collection, target group]\n",
      "#'\n",
      "#' @format A data frame with [n] rows and [n] variables:\n",
      "#' \\describe{\n",
      "#'   \\item{variable_name}{Description. Type. Values if categorical.}\n",
      "#'   ... (all variables)\n",
      "#' }\n",
      "#'\n",
      "#' @details\n",
      "#' Write a short description here of dataset-level information (e.g.\n",
      "#' data collection method, fieldwork period, response rate) BUT ONLY to\n",
      "#' the extent it is given below under \"Paradata\". If some information\n",
      "#' is not given, leave it out entirely rather than inventing it.\n",
      "#'\n",
      "#' @source Source of the dataset, if given -- otherwise omit this line.\n",
      "\"", object_name, "\"\n\n",

      "Use ONLY the information given -- do not invent new variables, figures, ",
      "or descriptions.\n\n",

      "VERY IMPORTANT: regardless of whether you filled in the @details and ",
      "@source sections, ALWAYS end your response with a final line containing ",
      "just the quoted name \"", object_name, "\" -- this line is MANDATORY in ",
      "every case, it is not part of the \"omit if not given\" instruction."
    ))
  }

  if (identical(language, "sv")) {
    return(paste0(
      "Du har fått ett enkätdatasets metadata och variabelbeskrivningar.\n",
      "Skriv utifrån dem ett komplett roxygen2-dokumentationsblock för ett R-paket.\n",
      "VIKTIGT: Skriv REN R-kod utan markdown-formatering. ",
      "Använd inte ```r eller ``` -tecken. Börja direkt med #'-markören.\n\n",

      "Följ EXAKT denna roxygen2-struktur:\n\n",

      "#' [Datasetets namn]\n",
      "#'\n",
      "#' [2-3 meningars beskrivning av datasetet: ämne, insamling, målgrupp]\n",
      "#'\n",
      "#' @format En data frame med [n] rader och [n] variabler:\n",
      "#' \\describe{\n",
      "#'   \\item{variabelnamn}{Beskrivning. Typ. Värden om kategorisk.}\n",
      "#'   ... (alla variabler)\n",
      "#' }\n",
      "#'\n",
      "#' @details\n",
      "#' Skriv här en kort beskrivning av information på datasetnivå (t.ex.\n",
      "#' insamlingsmetod, fältperiod, svarsfrekvens) MEN ENDAST i den mån den är\n",
      "#' given nedan under \"Paradata\". Om någon uppgift inte ges, utelämna den\n",
      "#' helt istället för att hitta på den.\n",
      "#'\n",
      "#' @source Datasetets källa, om den anges -- annars utelämna denna rad.\n",
      "\"", object_name, "\"\n\n",

      "Använd ENDAST given information -- hitta inte på nya variabler, siffror ",
      "eller beskrivningar.\n\n",

      "MYCKET VIKTIGT: oavsett om du fyllde i @details- och @source-avsnitten, ",
      "avsluta ALLTID ditt svar med en sista rad som endast innehåller det ",
      "citerade namnet \"", object_name, "\" -- denna rad är OBLIGATORISK i ",
      "varje fall, den är inte en del av \"utelämna om inte given\"-instruktionen."
    ))
  }

  paste0(
    "Sinulle on annettu survey-aineiston metatiedot ja muuttujakuvaukset.\n",
    "Kirjoita niistä valmis roxygen2-dokumentaatio R-pakettia varten.\n",
    "TÄRKEÄÄ: Kirjoita PELKKÄ R-koodi ilman markdown-muotoilua. ",
    "Älä käytä ```r tai ``` -merkkejä. Aloita suoraan #' -merkillä.\n\n",

    "Noudata TARKASTI tätä roxygen2-rakennetta:\n\n",

    "#' [Aineiston nimi]\n",
    "#'\n",
    "#' [2-3 lauseen kuvaus aineistosta: aihe, keruu, kohderyhmä]\n",
    "#'\n",
    "#' @format Dataframe, jossa [n] riviä ja [n] muuttujaa:\n",
    "#' \\describe{\n",
    "#'   \\item{muuttujanimi}{Kuvaus. Tyyppi. Arvot jos kategorinen.}\n",
    "#'   ... (kaikki muuttujat)\n",
    "#' }\n",
    "#'\n",
    "#' @details\n",
    "#' Kirjoita tähän kohtaan lyhyt kuvaus aineistotason tiedoista (esim.\n",
    "#' keruutapa, kenttäaika, vastausaste) MUTTA VAIN niiltä osin kuin ne on\n",
    "#' annettu alla \"Paradata\"-kohdassa. Jos jotain tietoa ei ole annettu,\n",
    "#' jätä se kokonaan pois äläkä keksi sitä.\n",
    "#'\n",
    "#' @source Aineiston lähde, jos se on annettu — muuten jätä rivi pois.\n",
    "\"", object_name, "\"\n\n",

    "Käytä VAIN annettuja tietoja äläkä keksi uusia muuttujia, lukuja tai ",
    "kuvauksia.\n\n",

    "ERITTÄIN TÄRKEÄÄ: riippumatta siitä täytitkö @details- ja @source-kohdat, ",
    "lopeta vastauksesi AINA viimeisenä rivinä pelkkään lainausmerkkeihin ",
    "kirjoitettuun nimeen \"", object_name, "\" — tämä rivi on PAKOLLINEN ",
    "joka tilanteessa, se ei ole osa \"jätä pois jos ei annettu\" -ohjetta."
  )
}

# Pienet otsikko-/kenttätekstit roxygen-kehotteen data-yhteenvedossa,
# kielen mukaan (vaikuttaa vain kehotteen luettavuuteen -- ei itse dataan).
sd_roxygen_labels_ <- function(language = "fi") {
  if (identical(language, "en")) {
    return(list(
      respondents = "Respondents",
      variables   = "Variables",
      no_paradata = "  (no paradata given)",
      vars_header = "VARIABLES",
      label       = "Label",
      type        = "Type",
      values      = "Values",
      missing     = "Missing",
      no_label    = "(no label)",
      continuous  = "continuous / open"
    ))
  }

  if (identical(language, "sv")) {
    return(list(
      respondents = "Svarande",
      variables   = "Variabler",
      no_paradata = "  (inga paradata angivna)",
      vars_header = "VARIABLER",
      label       = "Etikett",
      type        = "Typ",
      values      = "Värden",
      missing     = "Saknas",
      no_label    = "(ingen etikett)",
      continuous  = "kontinuerlig / öppen"
    ))
  }

  list(
    respondents = "Vastaajia",
    variables   = "Muuttujia",
    no_paradata = "  (ei paradatatietoja annettu)",
    vars_header = "MUUTTUJAT",
    label       = "Label",
    type        = "Tyyppi",
    values      = "Arvot",
    missing     = "Puuttuvat",
    no_label    = "(ei labelia)",
    continuous  = "jatkuva / avoin"
  )
}

sd_roxygen_data_summary_ <- function(x, language = "fi") {
  data <- x$data
  meta <- x$meta
  lab  <- sd_roxygen_labels_(language)

  paradata_teksti <- if (length(meta$paradata) == 0) {
    lab$no_paradata
  } else {
    paste0(
      "  ", names(meta$paradata), ": ",
      vapply(meta$paradata, function(v) paste(format(v), collapse = ", "), character(1)),
      collapse = "\n"
    )
  }

  muuttuja_teksti <- paste(
    vapply(names(data), function(nm) sd_roxygen_var_line_(x, nm, language), character(1)),
    collapse = "\n\n"
  )

  paste0(
    lab$respondents, ": ", nrow(data), "\n",
    lab$variables, ": ", ncol(data), "\n",
    "Paradata:\n", paradata_teksti, "\n\n",
    lab$vars_header, ":\n", muuttuja_teksti
  )
}

# Yhden muuttujan tiedot tekstimuodossa: label, tyyppi/rooli, arvolebelit
# (jos annettu) ja puuttuvien määrä. Huom: EI koskaan itse datan arvoja
# (avoin teksti mukaan lukien) — vain metatietoja.
sd_roxygen_var_line_ <- function(x, nm, language = "fi") {
  col   <- x$data[[nm]]
  label <- x$meta$labels[[nm]]
  vlab  <- x$meta$value_labels[[nm]]
  lab   <- sd_roxygen_labels_(language)
  # Huom: meta$roles on oletuksena nimetön character(0) (ei lista), joten
  # `[[nm]]` puuttuvalle nimelle kaataisi virheeseen "subscript out of
  # bounds" -- roxygenin generointi ei vaadi rooleja etukäteen (toisin kuin
  # sd_summarise(), joka täydentää puuttuvat roolit ennen tätä kohtaa).
  role  <- if (nm %in% names(x$meta$roles)) x$meta$roles[[nm]] else NULL

  puuttuvat <- sum(is.na(col))
  tyyppi <- if (!is.null(role)) role else paste(class(col), collapse = "/")

  arvot_str <- if (!is.null(vlab) && length(vlab) > 0) {
    paste(paste0(vlab, " = ", names(vlab)), collapse = ", ")
  } else {
    lab$continuous
  }

  paste0(
    "  ", nm, ":\n",
    "    ", lab$label, ": ", if (is.null(label) || !nzchar(label)) lab$no_label else label, "\n",
    "    ", lab$type, ": ", tyyppi, "\n",
    "    ", lab$values, ": ", arvot_str, "\n",
    "    ", lab$missing, ": ", puuttuvat
  )
}

#' Generate roxygen2 documentation for a dataset with a language model
#'
#' The automated version of "03_generoi_roxygen.R": takes the labels,
#' value labels and paradata already attached to an `sd_data` object (see
#' `sd_read()`, or set manually) and asks a language model to write a
#' complete roxygen2 documentation block for it, ready to save as
#' `R/<object_name>.R` next to a dataset saved with
#' `usethis::use_data()`.
#'
#' By default (`dry_run = TRUE`) nothing is written to disk — the
#' generated text is only returned (and can be inspected with
#' `print()`/`cat()`) so you can check it before committing to a file.
#' Set `dry_run = FALSE` to write it out; an existing file is never
#' silently overwritten unless `overwrite = TRUE`.
#'
#' @param x An `sd_data` object. Labels and value labels (see
#'   `sd_read()`'s automatic haven-label import, or set them directly on
#'   `x$meta$labels`/`x$meta$value_labels`) make for a much better result
#'   — a dataset with no labels at all still works, but the model will
#'   have only variable names and value ranges to go on.
#' @param object_name Name the documented object will have once saved
#'   with `usethis::use_data()`, e.g. `"survey_data"`. Required — this is
#'   what the generated documentation is attached to.
#' @param model,backend,timeout_s As in `sd_document()`.
#' @param instructions Passed on to `sd_build_roxygen_prompt()`.
#' @param dry_run If `TRUE` (the default), the result is only returned,
#'   not written to disk. Set to `FALSE` to write it to `file`.
#' @param file Path to write the documentation to when `dry_run = FALSE`.
#'   Defaults to `file.path("R", paste0(object_name, ".R"))`, matching
#'   where `usethis::use_data()` expects a dataset's documentation.
#' @param overwrite If `FALSE` (the default) and `file` already exists,
#'   `sd_generate_roxygen()` refuses to overwrite it and raises an error
#'   instead — set `TRUE` once you've checked the existing file.
#' @param language Language the generated roxygen2 documentation should
#'   be written in -- one of `"fi"` (Finnish, the default), `"en"`
#'   (English) or `"sv"` (Swedish). Only affects the built-in `instructions` (and small field
#'   labels in the dataset-information block); has no effect when
#'   `instructions` is supplied explicitly. See `sd_build_roxygen_prompt()`.
#' @param store Optional connected ragnar `RagnarStore` (see
#'   `ragnar::ragnar_store_connect()`) built from your own reference
#'   material. When given, `sd_retrieve_context()` looks up background
#'   material for each variable and inserts it into the prompt. `NULL`
#'   (the default) skips retrieval entirely -- behaves exactly as before
#'   this parameter was added.
#' @param top_k Number of chunks retrieved per variable when `store` is
#'   given. Passed on to `sd_retrieve_context()`.
#'
#' @section Requirements:
#' Same as `sd_document()` — a running Ollama installation with `model`
#' pulled. Run `sd_check_ollama()` first. A response can take from
#' seconds to minutes; `sd_generate_roxygen()` prints a message before
#' sending the request so a long wait doesn't look frozen.
#'
#' @return An object of class `sd_roxygen` with elements `text` (the
#'   generated roxygen2 block), `prompt`, `object_name`, `model`,
#'   `backend`, `file` (the path written to, or `NULL` when
#'   `dry_run = TRUE`), `chat` (the underlying \pkg{ellmer} chat object),
#'   and `created`.
#' @export
#'
#' @examples
#' \dontrun{
#' aineisto <- sd_read("survey_data.sav")
#' tulos <- sd_generate_roxygen(aineisto, "survey_data")
#' print(tulos)
#'
#' # Kun teksti näyttää hyvältä, kirjoita tiedostoon:
#' tulos <- sd_generate_roxygen(aineisto, "survey_data", dry_run = FALSE)
#' }
sd_generate_roxygen <- function(x,
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
                                 top_k = 2) {
  if (!is_sd_data(x)) {
    stop("`x` ei ole sd_data-olio (ks. sd_read()).", call. = FALSE)
  }
  sd_check_object_name_(object_name)
  sd_check_language_(language)
  if (!grepl("^[a-zA-Z.][a-zA-Z0-9._]*$", object_name)) {
    warning(
      "`object_name` (\"", object_name, "\") ei näytä kelvolliselta ",
      "R-objektin nimeltä — tarkista kirjoitusasu.",
      call. = FALSE
    )
  }

  kehote <- sd_build_roxygen_prompt(
    x, object_name, instructions, language,
    context = sd_retrieve_context(x, store, top_k = top_k)
  )

  system_prompt <- if (identical(language, "en")) {
    paste(
      "You are an expert in R programming and survey research.",
      "You write precise, professional roxygen2 documentation in English.",
      "You use the given information as-is -- you do not invent additional details."
    )
  } else if (identical(language, "sv")) {
    paste(
      "Du är expert på R-programmering och enkätforskning.",
      "Du skriver exakt, professionell roxygen2-dokumentation på svenska.",
      "Du använder given information som den är — du hittar inte på ytterligare detaljer."
    )
  } else {
    paste(
      "Olet R-ohjelmoinnin ja survey-tutkimuksen asiantuntija.",
      "Kirjoitat tarkkaa, ammattimaista roxygen2-dokumentaatiota suomeksi.",
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

  teksti <- sd_clean_llm_code_(tulos$text)
  teksti <- sd_strip_empty_roxygen_tags_(teksti)
  teksti <- sd_ensure_object_line_(teksti, object_name)

  if (isTRUE(dry_run)) {
    file <- NULL
    message(
      "dry_run = TRUE (oletus) — tulosta ei kirjoitettu tiedostoon, vain ",
      "palautettiin. Tarkista teksti (print()/cat()) ja aja uudelleen ",
      "dry_run = FALSE kun olet tyytyväinen."
    )
  } else {
    if (is.null(file)) {
      file <- file.path("R", paste0(object_name, ".R"))
    }
    if (file.exists(file) && !overwrite) {
      stop(
        "Tiedosto on jo olemassa: ", file, "\n",
        "Tarkista sisältö ja aseta overwrite = TRUE jos haluat korvata sen, ",
        "tai anna toinen polku `file`-argumentilla.",
        call. = FALSE
      )
    }
    if (!dir.exists(dirname(file))) {
      dir.create(dirname(file), recursive = TRUE)
    }
    writeLines(teksti, file)
    message("Roxygen2-dokumentaatio kirjoitettu tiedostoon: ", file)
  }

  structure(
    list(
      text        = teksti,
      prompt      = kehote,
      object_name = object_name,
      model       = model,
      backend     = backend,
      file        = file,
      chat        = tulos$chat,
      created     = Sys.time()
    ),
    class = "sd_roxygen"
  )
}

#' @export
print.sd_roxygen <- function(x, ...) {
  cat(x$text, "\n")
  invisible(x)
}

# Siivoaa mahdolliset markdown-koodiblokit (```r ... ```), joita mallit
# joskus lisäävät pyynnöstä huolimatta.
sd_clean_llm_code_ <- function(teksti) {
  teksti <- gsub("^```[rR]?\\s*\\n?", "", teksti)
  teksti <- gsub("```\\s*$", "", teksti)
  trimws(teksti)
}

# Poistaa roxygen-tagit (esim. "#' @details", "#' @source") joilla ei ole
# lainkaan sisältöä -- malli jättää joskus tagin paikalleen tyhjänä sen
# sijaan että jättäisi koko tagin pois, vaikka ohjeistus pyysi jälkimmäistä.
# Tyhjä tagi ei ole virhe roxygen2:lle, mutta on siisti karsia pois.
sd_strip_empty_roxygen_tags_ <- function(teksti) {
  rivit <- strsplit(teksti, "\n", fixed = TRUE)[[1]]
  if (length(rivit) == 0) return(teksti)

  on_kommentti      <- function(s) grepl("^#'", s)
  on_tyhja_kommentti <- function(s) grepl("^#'\\s*$", s)
  on_tagirivi        <- function(s) grepl("^#'\\s*@[[:alpha:]]+", s)
  on_tagirivi_tyhja  <- function(s) grepl("^#'\\s*@[[:alpha:]]+\\s*$", s)

  poistettavat <- rep(FALSE, length(rivit))
  i <- 1L
  n <- length(rivit)
  while (i <= n) {
    if (on_tagirivi_tyhja(rivit[i])) {
      j <- i + 1L
      while (j <= n && on_tyhja_kommentti(rivit[j])) j <- j + 1L
      sisalto_puuttuu <- (j > n) || !on_kommentti(rivit[j]) || on_tagirivi(rivit[j])
      if (sisalto_puuttuu) {
        poistettavat[i:(j - 1L)] <- TRUE
        i <- j
        next
      }
    }
    i <- i + 1L
  }

  paste(rivit[!poistettavat], collapse = "\n")
}

# Varmistaa että teksti päättyy täsmälleen riviin "<object_name>" (lainaus-
# merkeissä) -- roxygen2 liittää dokumentaatiolohkon siihen R-ilmaukseen
# joka seuraa heti perässä, joten tämä rivi on välttämätön. Mallit jättävät
# sen joskus pois (esim. tulkitsevat sen osaksi "jätä pois jos ei annettu"
# -ohjetta, vaikka sitä ei ole tarkoitettu niin) -- tässä varmistetaan rivin
# olemassaolo koodissa sen sijaan että luotettaisiin pelkkään kehotteeseen.
sd_ensure_object_line_ <- function(teksti, object_name) {
  odotettu <- paste0("\"", object_name, "\"")
  teksti <- sub("\\s+$", "", teksti)

  rivit <- strsplit(teksti, "\n", fixed = TRUE)[[1]]
  if (length(rivit) > 0 && identical(trimws(rivit[length(rivit)]), odotettu)) {
    return(teksti)
  }

  paste0(teksti, "\n", odotettu)
}
