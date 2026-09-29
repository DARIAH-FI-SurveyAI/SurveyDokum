#' Create a new sd_data object
#'
#' Internal constructor for the `sd_data` class, which bundles a survey
#' dataset together with metadata about it (variable roles, labels,
#' missing-value codes, and paradata such as fielding dates or response
#' rate). Pipeline functions such as `sd_summarise()`, `sd_document()`,
#' `sd_generate_roxygen()` and `sd_codebook()` all take an `sd_data`
#' object as input.
#'
#' @param data A data frame or tibble containing the survey data.
#' @param meta A list of metadata. See Details for the expected structure.
#'
#' @details
#' `meta` is a list with (at least) these elements:
#' \describe{
#'   \item{roles}{Named character vector mapping variable names to a role:
#'     one of `"id"`, `"likert"`, `"nominal"`, `"continuous"`, `"date"`,
#'     `"text"`, `"weight"`, or `"unknown"`.}
#'   \item{labels}{Named list mapping variable names to a human-readable
#'     label.}
#'   \item{value_labels}{Named list mapping variable names to a named
#'     vector of value labels (value = name).}
#'   \item{missing_codes}{Named list mapping variable names to a vector of
#'     sentinel codes that should be treated as missing.}
#'   \item{paradata}{A list of dataset-level metadata, e.g.
#'     `collection_mode`, `fieldwork`, `response_rate`, `sampling_frame`.}
#' }
#'
#' If `meta$labels`/`meta$value_labels` are not supplied, they are
#' harvested automatically from any `label`/`labels` attributes already
#' present on `data`'s columns (the same haven-style convention
#' `sd_read()` uses for SPSS/Stata files) — see
#' `sd_harvest_attr_labels_()`. This means a `data.frame` that already
#' carries these attributes (e.g. one saved to `.rds` from a previous
#' \pkg{haven} session, or shipped as a package's built-in example data)
#' gets its labels picked up even when it isn't read in via `sd_read()`'s
#' `.sav`/`.dta` path. Pass `meta = list(labels = list(), value_labels =
#' list())` explicitly to opt out and start with no labels regardless of
#' what `data`'s attributes contain.
#'
#' @return An object of class `sd_data`.
#' @keywords internal
new_sd_data <- function(data, meta = list()) {
  stopifnot(is.data.frame(data))

  harvested <- sd_harvest_attr_labels_(data)

  # Huom: utils::modifyList() yhdistää sisäkkäiset listat REKURSIIVISESTI,
  # joten sille ei voi antaa labels/value_labels-avaimia suoraan
  # automaattisen poiminnan oletukseksi -- tyhjä lista argumenttina
  # ("haluan tyhjentää nämä") ei tyhjentäisi mitään, koska modifyList():lla
  # ei ole silloin mitään ylikirjoitettavaa (modifyList(list(a=1), list())
  # palauttaa muuttumattoman list(a=1)). Ratkaistaan siis labels ja
  # value_labels eksplisiittisesti ennen modifyList()-kutsua: jos kutsuja
  # antaa jommankumman ollenkaan (vaikka tyhjänä), se korvaa automaattisen
  # poiminnan kokonaan.
  labels <- if (is.null(meta[["labels"]])) harvested$labels else meta[["labels"]]
  value_labels <- if (is.null(meta[["value_labels"]])) {
    harvested$value_labels
  } else {
    meta[["value_labels"]]
  }

  meta <- utils::modifyList(
    list(
      roles         = character(0),
      labels        = labels,
      value_labels  = value_labels,
      missing_codes = list(),
      paradata      = list()
    ),
    meta
  )

  structure(
    list(data = tibble::as_tibble(data), meta = meta),
    class = "sd_data"
  )
}

# Poimii data.framen sarakkeiden label- ja value-label-attribuutit
# sd_data-metatiedon muotoon (haven-tyylinen konventio: attr(col,"label")
# ja attr(col,"labels")). Ei ole sidottu havenniin -- toimii mille
# tahansa data.framelle jonka sarakkeissa nämä attribuutit jo ovat,
# riippumatta siitä miten data on alunperin luettu.
sd_harvest_attr_labels_ <- function(data) {
  labels <- list()
  value_labels <- list()

  for (nm in names(data)) {
    col <- data[[nm]]

    lab <- attr(col, "label", exact = TRUE)
    if (!is.null(lab)) labels[[nm]] <- lab

    vlab <- attr(col, "labels", exact = TRUE)
    if (!is.null(vlab)) value_labels[[nm]] <- vlab
  }

  list(labels = labels, value_labels = value_labels)
}

#' Test whether an object is an `sd_data` object
#'
#' @param x An object.
#' @return `TRUE` or `FALSE`.
#' @export
is_sd_data <- function(x) {
  inherits(x, "sd_data")
}

#' Get the underlying data frame from an `sd_data` object
#'
#' @param x An `sd_data` object, as created by [sd_read()].
#' @return A tibble.
#' @export
#'
#' @examples
#' \dontrun{
#' aineisto <- sd_read("survey_data.csv")
#' sd_get_data(aineisto)
#' }
sd_get_data <- function(x) {
  if (!is_sd_data(x)) {
    stop("`x` ei ole sd_data-olio (ks. sd_read()).", call. = FALSE)
  }
  x$data
}

#' Get the metadata from an `sd_data` object
#'
#' @param x An `sd_data` object, as created by [sd_read()].
#' @return A list. See [new_sd_data()] for the expected structure.
#' @export
sd_get_meta <- function(x) {
  if (!is_sd_data(x)) {
    stop("`x` ei ole sd_data-olio (ks. sd_read()).", call. = FALSE)
  }
  x$meta
}

#' @export
print.sd_data <- function(x, ...) {
  n_row <- nrow(x$data)
  n_col <- ncol(x$data)
  roles <- x$meta$roles

  cat("<sd_data>", n_row, "vastaajaa,", n_col, "muuttujaa\n")

  if (length(roles) > 0) {
    role_counts <- table(roles)
    cat(
      "Muuttujaroolit:",
      paste(names(role_counts), role_counts, sep = " = ", collapse = ", "),
      "\n"
    )
  } else {
    cat("Muuttujarooleja ei ole vielä määritetty (ks. sd_detect_roles()).\n")
  }

  nimi <- x$meta$paradata$nimi
  if (!is.null(nimi)) cat("Aineisto:", nimi, "\n")

  invisible(x)
}

#' @export
summary.sd_data <- function(object, ...) {
  print(object)
  cat("\n")
  print(summary(object$data))
  invisible(object)
}
