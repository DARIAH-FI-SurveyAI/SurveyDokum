#' Build the LLM prompt from a summary
#'
#' Turns an `sd_summary` object (see `sd_summarise()`) into the full text
#' prompt that `sd_document()` sends to the language model — instructions
#' followed by the statistics themselves. Kept separate from
#' `sd_document()` so the prompt can be inspected or unit-tested without
#' needing Ollama (or any model) running.
#'
#' @param summary An `sd_summary` object, as returned by `sd_summarise()`.
#' @param instructions Character string with the instructions placed
#'   before the statistics. `NULL` (the default) uses a built-in
#'   instruction template (see `language`) asking for an overview,
#'   descriptions of the categorical/demographic and Likert-type
#'   variables, and a short data quality note.
#' @param language Language of the built-in `instructions` template when
#'   `instructions` is left at its default `NULL` -- one of `"fi"`
#'   (Finnish, the default), `"en"` (English) or `"sv"` (Swedish). Has no effect when
#'   `instructions` is supplied explicitly. This is independent of the
#'   language the survey data itself (variable labels etc.) happens to be
#'   in -- a Finnish-language survey can still be documented in English,
#'   or vice versa. Note that `format(summary)` itself (the statistics
#'   block appended after `instructions`) is currently always formatted
#'   using Finnish labels regardless of `language` -- see
#'   `format.sd_summary()`.
#' @param context Optional character string of retrieved background
#'   material to insert before the statistics block -- typically the
#'   output of `sd_retrieve_context()`. `NULL` (the default) omits this
#'   section entirely, leaving the prompt exactly as before this
#'   parameter was added.
#'
#' @return A single character string: the full prompt.
#' @export
#'
#' @examples
#' \dontrun{
#' kooste <- sd_summarise(aineisto)
#' kehote <- sd_build_prompt(kooste)
#' cat(kehote)
#'
#' # Englanninkieliset ohjeet samalle datalle:
#' kehote_en <- sd_build_prompt(kooste, language = "en")
#'
#' # RAG-taustatiedolla:
#' store <- ragnar::ragnar_store_connect("oma_rag_store.ragnar.duckdb")
#' kehote_rag <- sd_build_prompt(kooste, context = sd_retrieve_context(kooste, store))
#' }
sd_build_prompt <- function(summary, instructions = NULL, language = "fi", context = NULL) {
  if (!inherits(summary, "sd_summary")) {
    stop("`summary` ei ole sd_summary-olio (ks. sd_summarise()).", call. = FALSE)
  }
  sd_check_language_(language)

  if (is.null(instructions)) {
    instructions <- sd_default_instructions_(language)
  }

  otsikko <- switch(language,
    en = "STATISTICS:",
    sv = "STATISTIK:",
    "TILASTOTIEDOT:"
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

  paste0(osiot, "\n\n", otsikko, "\n", format(summary))
}

sd_default_instructions_ <- function(language = "fi") {
  if (identical(language, "en")) {
    return(paste0(
      "You have been given statistics below about a survey dataset.\n",
      "Based on them, write professional documentation in English that includes:\n",
      "1. Overview of the data (number of respondents, variables)\n",
      "2. Descriptions of the categorical/demographic variables with their distributions\n",
      "3. Descriptions of the Likert-type variables (scale, means, notable patterns)\n",
      "4. A brief assessment of data quality (missing values, notes)\n\n",
      "Use ONLY the statistics provided -- do not invent new figures."
    ))
  }

  if (identical(language, "sv")) {
    return(paste0(
      "Du har fått statistik nedan om ett enkätdataset (survey-data).\n",
      "Skriv utifrån dem en professionell dokumentation på svenska som innehåller:\n",
      "1. Översikt av datan (antal svarande, variabler)\n",
      "2. Beskrivningar av de kategoriska/demografiska variablerna med sina fördelningar\n",
      "3. Beskrivningar av Likert-typvariablerna (skala, medelvärden, anmärkningsvärda mönster)\n",
      "4. En kort bedömning av datakvaliteten (saknade värden, anmärkningar)\n\n",
      "Använd ENDAST den statistik som ges -- hitta inte på nya siffror."
    ))
  }

  paste0(
    "Sinulle on annettu alla tilastotiedot kyselyaineistosta.\n",
    "Kirjoita niiden pohjalta ammattimainen dokumentaatio suomeksi, joka sisältää:\n",
    "1. Datan yleiskuvaus (vastaajamäärä, muuttujat)\n",
    "2. Kategoristen/demografisten muuttujien kuvaukset jakaumatietoineen\n",
    "3. Likert-tyyppisten muuttujien kuvaukset (asteikko, keskiarvot, huomiot)\n",
    "4. Lyhyt arvio datan laadusta (puuttuvat arvot, huomiot)\n\n",
    "Käytä VAIN annettuja tilastotietoja äläkä keksi uusia lukuja."
  )
}

# -- Sisäinen apu: kieliparametrin tuki ---------------------------------
#
# Yhteinen kielituki kaikille LLM:ää kutsuville funktioille (sd_document(),
# sd_generate_roxygen()) ja niiden kehotteenrakentajille. Uusi kieli
# lisätään laajentamalla sd_supported_languages_ ja lisäämällä vastaava
# haara kunkin kehote-/system-prompt-mallin sisältävään apufunktioon --
# funktioiden julkinen rajapinta (parametrin nimi "language" ja oletusarvo
# "fi") pysyy tällöin muuttumattomana.
sd_supported_languages_ <- c("fi", "en", "sv")

sd_check_language_ <- function(language) {
  if (!is.character(language) || length(language) != 1 || !nzchar(language)) {
    stop(
      "`language` pitää olla yksi kielikoodi merkkijonona (esim. \"fi\" tai \"en\").",
      call. = FALSE
    )
  }
  if (!language %in% sd_supported_languages_) {
    stop(
      "Kieltä \"", language, "\" ei vielä tueta. Tuetut kielet: ",
      paste(sd_supported_languages_, collapse = ", "), ".",
      call. = FALSE
    )
  }
  invisible(language)
}

#' Generate documentation for a survey dataset with a language model
#'
#' The "Vaihe 2" of the documentation pipeline: takes the statistics R
#' already computed (`sd_summarise()`) and asks a language model to turn
#' them into readable prose. Currently supports a local Ollama model via
#' the \pkg{ellmer} package.
#'
#' @param x An `sd_data` object (statistics are computed automatically —
#'   see `sd_summarise()` for the recommended order of `sd_set_missing()`
#'   and `sd_detect_roles()` first) or an already-computed `sd_summary`
#'   object.
#' @param model Name of the Ollama model to use, e.g. `"gemma3:12b"`.
#' @param backend Which chat backend to use. Currently only `"ollama"` is
#'   supported.
#' @param system_prompt System prompt for the model. `NULL` (the default)
#'   uses a built-in system prompt, in the language given by `language`,
#'   instructing the model to write professional documentation and use
#'   only the given figures.
#' @param instructions Passed on to `sd_build_prompt()`.
#' @param timeout_s Request timeout in seconds (local models can be slow
#'   on a first response). Default `1200` (20 minutes).
#' @param save_to Optional file path. If given, the generated text is
#'   also written there with [writeLines()].
#' @param language Language the generated documentation should be
#'   written in -- one of `"fi"` (Finnish, the default), `"en"`
#'   (English) or `"sv"` (Swedish). Only affects the built-in `system_prompt` and
#'   `instructions`; has no effect when both are supplied explicitly. See
#'   `sd_build_prompt()`.
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
#' `sd_document()` needs a running Ollama installation with the chosen
#' model already pulled — see <https://ollama.com>, then
#' `ollama pull <model>` on the command line. Run `sd_check_ollama()`
#' first to verify this quickly, without waiting for a full generation.
#' A response can take anywhere from a few seconds to several minutes —
#' larger models without GPU acceleration are slow, and the very first
#' call after starting Ollama also pays a one-off cost to load the model
#' into memory. `sd_document()` prints a message before sending the
#' request so a long wait doesn't look like it has silently frozen.
#'
#' @return An object of class `sd_documentation` with elements `text`
#'   (the generated documentation), `prompt` (the full prompt sent),
#'   `model`, `backend`, `chat` (the underlying \pkg{ellmer} chat object —
#'   use `chat$chat("...")` to ask follow-up questions in the same
#'   conversation), and `created`.
#' @export
#'
#' @examples
#' \dontrun{
#' aineisto <- sd_read("survey_data.csv")
#' aineisto <- sd_set_missing(aineisto, codes = c(99, -9), vars = c("tt1", "tt2"))
#' aineisto <- sd_detect_roles(aineisto)
#' dokumentaatio <- sd_document(aineisto, model = "gemma3:12b")
#' print(dokumentaatio)
#'
#' # Jatkokeskustelu samassa kontekstissa:
#' dokumentaatio$chat$chat("Mikä ulottuvuus sai parhaat keskiarvot?")
#' }
sd_document <- function(x,
                         model = "gemma3:12b",
                         backend = "ollama",
                         system_prompt = NULL,
                         instructions = NULL,
                         timeout_s = 1200,
                         save_to = NULL,
                         language = "fi",
                         store = NULL,
                         top_k = 2) {
  sd_check_language_(language)

  if (is_sd_data(x)) {
    summary <- sd_summarise(x)
  } else if (inherits(x, "sd_summary")) {
    summary <- x
  } else {
    stop(
      "`x` pitää olla sd_data- tai sd_summary-olio (ks. sd_read(), sd_summarise()).",
      call. = FALSE
    )
  }

  if (is.null(system_prompt)) {
    system_prompt <- if (identical(language, "en")) {
      paste(
        "You are an expert in survey research data documentation.",
        "You write clear, professional documentation in English.",
        "You use the statistics given to you as-is",
        "-- you do not invent new figures."
      )
    } else if (identical(language, "sv")) {
      paste(
        "Du är expert på dokumentation av enkätforskningsdata.",
        "Du skriver tydlig, professionell dokumentation på svenska.",
        "Du använder den statistik du får som den är",
        "-- du hittar inte på nya siffror."
      )
    } else {
      paste(
        "Olet asiantuntija kyselytutkimusdatan dokumentoinnissa.",
        "Kirjoitat selkeitä, ammattimaisia dokumentaatioita suomeksi.",
        "Käytät sinulle annettuja tilastotietoja sellaisenaan",
        "— älä keksi uusia lukuja."
      )
    }
  }

  kehote <- sd_build_prompt(
    summary, instructions, language,
    context = sd_retrieve_context(summary, store, top_k = top_k)
  )

  tulos <- sd_ollama_chat_(
    prompt        = kehote,
    model         = model,
    backend       = backend,
    system_prompt = system_prompt,
    timeout_s     = timeout_s
  )

  teksti <- tulos$text

  if (!is.null(save_to)) {
    writeLines(teksti, save_to)
  }

  structure(
    list(
      text    = teksti,
      prompt  = kehote,
      model   = model,
      backend = backend,
      chat    = tulos$chat,
      created = Sys.time()
    ),
    class = "sd_documentation"
  )
}

#' @export
print.sd_documentation <- function(x, ...) {
  cat(x$text, "\n")
  invisible(x)
}

#' Check whether Ollama is reachable and the model is pulled
#'
#' A fast diagnostic for `sd_document()`'s Ollama backend: checks whether
#' the local Ollama server responds at all, and whether `model` is among
#' the models it already has pulled. This only queries Ollama's model
#' list — it does not generate anything, so it returns in well under a
#' second and is safe to run before committing to a slow `sd_document()`
#' call.
#'
#' @param model Name of the model to look for, e.g. `"gemma3:12b"`.
#' @param host Base URL of the Ollama server. Defaults to
#'   `"http://localhost:11434"`, the standard local address.
#'
#' @return Invisibly, `TRUE` if Ollama is reachable and `model` is
#'   pulled, `FALSE` otherwise. Called for its printed message.
#' @export
#'
#' @examples
#' \dontrun{
#' sd_check_ollama("gemma3:12b")
#' }
sd_check_ollama <- function(model = "gemma3:12b", host = "http://localhost:11434") {
  vastaus <- tryCatch(
    suppressWarnings(readLines(paste0(host, "/api/tags"), warn = FALSE)),
    error = function(e) NULL
  )

  if (is.null(vastaus)) {
    message(
      "Ollamaa ei löydy osoitteesta ", host, ".\n",
      "Tarkista että:\n",
      "  1. Ollama on asennettu (https://ollama.com)\n",
      "  2. Ollama-sovellus on käynnissä (tai aja `ollama serve` komentoriviltä)"
    )
    return(invisible(FALSE))
  }

  sisalto <- paste(vastaus, collapse = "")
  malli_loytyy <- grepl(model, sisalto, fixed = TRUE)

  if (malli_loytyy) {
    message(
      "Ollama vastaa ja malli \"", model, "\" on ladattu. ",
      "Valmis käytettäväksi sd_document()-funktiolla."
    )
  } else {
    message(
      "Ollama vastaa, mutta mallia \"", model, "\" ei löydy ladattujen ",
      "joukosta.\nLataa se komentoriviltä: ollama pull ", model
    )
  }

  invisible(malli_loytyy)
}

# -- Sisäinen apufunktio Ollama/ellmer-kutsuille ------------------------
#
# Yhteinen runko kaikille funktioille, jotka lähettävät kehotteen
# paikalliselle Ollama-mallille ellmer-paketin kautta (sd_document(),
# sd_generate_roxygen()). Kokoaa yhteen: ellmer-riippuvuuden tarkistuksen,
# timeout-asetuksen, ennakoivan "tämä voi kestää" -viestin, ja
# virhetilanteiden selkeät suomenkieliset vinkit. Ei viety-luokkaa —
# tämä on paketin sisäinen apufunktio, ei julkinen rajapinta.
sd_ollama_chat_ <- function(prompt, model, backend = "ollama",
                             system_prompt = NULL, timeout_s = 1200) {
  backend <- match.arg(backend, c("ollama"))

  if (!requireNamespace("ellmer", quietly = TRUE)) {
    stop(
      "Tämä toiminto vaatii ellmer-paketin: install.packages(\"ellmer\")",
      call. = FALSE
    )
  }

  vanha_timeout <- getOption("ellmer_timeout_s")
  options(ellmer_timeout_s = timeout_s)
  on.exit(options(ellmer_timeout_s = vanha_timeout), add = TRUE)

  message(
    "Lähetetään pyyntö mallille \"", model, "\" (backend: ", backend, ").\n",
    "Tämä voi kestää sekunneista useisiin minuutteihin — isot mallit ilman ",
    "GPU-kiihdytystä ja mallin ensimmäinen lataus muistiin ovat hitaita. ",
    "Tämä ei ole jumissa, vaikka mitään ei näy hetkeen."
  )

  chat <- tryCatch(
    ellmer::chat_ollama(model = model, system = system_prompt),
    error = function(e) {
      stop(
        conditionMessage(e),
        "\n\nVinkki: varmista että Ollama on käynnissä koneellasi ",
        "(avaa Ollama-sovellus tai aja `ollama serve` komentoriviltä) ja ",
        "että malli on ladattu (`ollama pull ", model, "`).",
        call. = FALSE
      )
    }
  )

  teksti <- tryCatch(
    chat$chat(prompt),
    error = function(e) {
      stop(
        conditionMessage(e),
        "\n\nVinkki: tarkista että malli \"", model, "\" on ladattu ",
        "(`ollama pull ", model, "`) ja että Ollama on yhä käynnissä.",
        call. = FALSE
      )
    }
  )

  list(text = teksti, chat = chat)
}
