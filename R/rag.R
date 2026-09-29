#' Retrieve RAG background context for a dataset's variables
#'
#' For each variable in `x`, searches `store` (a connected ragnar
#' `RagnarStore`, e.g. via `ragnar::ragnar_store_connect()`, built from
#' your own reference material) using the variable's name and label as
#' the query, and formats the retrieved chunks into a text block citing
#' their source. Meant to be passed as the `context` argument to
#' `sd_build_prompt()` / `sd_build_roxygen_prompt()`, or simply via the
#' `store` argument of `sd_document()` / `sd_generate_roxygen()`, which
#' call this automatically.
#'
#' RAG support in SurveyDokum is deliberately a thin, optional layer:
#' this function only *consumes* a store you have already built with
#' \pkg{ragnar} from whatever reference material you choose (survey
#' methodology glossaries, controlled vocabularies, prior codebooks,
#' house style guides, ...) -- SurveyDokum does not build or ship one
#' for you. See the "Using RAG with SurveyDokum" vignette for a
#' worked-through recipe with \pkg{ragnar}.
#'
#' @param x An `sd_data` object (see `sd_read()`) or an already-computed
#'   `sd_summary` object (see `sd_summarise()`).
#' @param store A connected ragnar `RagnarStore` (see
#'   `ragnar::ragnar_store_connect()` / `ragnar::ragnar_store_create()`),
#'   or `NULL` (the default) to skip retrieval entirely and return
#'   `NULL` -- this is what lets `store` stay an optional argument
#'   throughout the rest of the package.
#' @param top_k Number of chunks retrieved per variable.
#' @param max_chars Truncates each retrieved chunk to this many
#'   characters before including it, so a handful of long reference
#'   entries don't dominate the prompt.
#'
#' @return A single character string formatted for inclusion in a
#'   prompt (one bullet per retrieved chunk, source in parentheses), or
#'   `NULL` if `store` is `NULL` or nothing was retrieved.
#' @export
#'
#' @examples
#' \dontrun{
#' store <- ragnar::ragnar_store_connect("oma_rag_store.ragnar.duckdb")
#' aineisto <- sd_read("survey_data.csv")
#' tausta <- sd_retrieve_context(aineisto, store)
#' cat(tausta)
#'
#' # Kaytossa sd_generate_roxygen()/sd_document() kautta:
#' sd_generate_roxygen(aineisto, "survey_data", store = store)
#' }
sd_retrieve_context <- function(x, store = NULL, top_k = 2, max_chars = 600) {
  if (is.null(store)) {
    return(NULL)
  }
  if (!requireNamespace("ragnar", quietly = TRUE)) {
    stop(
      "Tama toiminto vaatii ragnar-paketin: install.packages(\"ragnar\")",
      call. = FALSE
    )
  }

  if (is_sd_data(x)) {
    nimet <- names(x$data)
    labelit <- vapply(nimet, function(nm) {
      l <- x$meta$labels[[nm]]
      if (is.null(l)) "" else l
    }, character(1))
  } else if (inherits(x, "sd_summary")) {
    nimet <- vapply(x$variables, function(v) v$name, character(1))
    labelit <- vapply(x$variables, function(v) {
      if (is.null(v$label)) "" else v$label
    }, character(1))
  } else {
    stop(
      "`x` pitaa olla sd_data- tai sd_summary-olio (ks. sd_read(), sd_summarise()).",
      call. = FALSE
    )
  }

  if (length(nimet) == 0) {
    return(NULL)
  }

  kyselyt <- ifelse(nzchar(labelit), paste(nimet, "-", labelit), nimet)

  osumat <- lapply(kyselyt, function(kysely) {
    tryCatch(
      ragnar::ragnar_retrieve(store, kysely, top_k = top_k),
      error = function(e) {
        warning(
          "RAG-haku epaonnistui kyselylla \"", kysely, "\": ",
          conditionMessage(e),
          call. = FALSE
        )
        NULL
      }
    )
  })
  osumat <- do.call(rbind, osumat)

  if (is.null(osumat) || nrow(osumat) == 0) {
    return(NULL)
  }

  # Sama chunk voi osua usean muuttujan kyselyyn -- nayta vain kerran.
  osumat <- osumat[!duplicated(osumat$text), , drop = FALSE]

  rivit <- sprintf(
    "- (%s) %s",
    basename(as.character(osumat$origin)),
    substr(trimws(osumat$text), 1, max_chars)
  )
  paste(rivit, collapse = "\n\n")
}
