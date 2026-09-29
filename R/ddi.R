#' Export a survey dataset's codebook as a DDI Codebook XML file
#'
#' Builds a DDI Codebook 2.6 `codeBook` element from an `sd_data` object's
#' metadata (`meta$roles`, `meta$labels`, `meta$value_labels`,
#' `meta$missing_codes`) and writes it to an XML file using the
#' \pkg{DDIwR} package. This is metadata-only: unlike `DDIwR::convert()`,
#' it does not require (or embed) the actual data values, since
#' `sd_data`'s metadata is kept separately from the data (see
#' [new_sd_data()]).
#'
#' @section Recommended order:
#' Run `sd_detect_roles()` and `sd_set_missing()` before
#' `sd_export_ddi()` — the DDI export uses `meta$roles` to set each
#' variable's format type, and `meta$missing_codes` to mark categories
#' as `missing="Y"` in the codebook (via `DDIwR::makeCategories()`).
#'
#' @param x An `sd_data` object.
#' @param file Path to write the XML file to. Default `"codebook.xml"`.
#' @param title Study title. Defaults to `x$meta$paradata$nimi` if set,
#'   otherwise `"Untitled dataset"`. Passed on to `DDIwR::exportCodebook()`
#'   as `titl`, which auto-fills the mandatory `stdyDscr`/`docDscr`
#'   elements when they are not already present in `codeBook`.
#' @param overwrite If `FALSE` (the default) and `file` already exists,
#'   `sd_export_ddi()` refuses to overwrite it.
#' @param ... Further arguments passed on to `DDIwR::exportCodebook()`
#'   (e.g. `agency`, `IDNo`, `abstract`, `monolang`).
#'
#' @return Invisibly, the `codeBook` list object passed to
#'   `DDIwR::exportCodebook()` (before its internal auto-fill of
#'   `stdyDscr`/`docDscr` — read the exported file back with
#'   `DDIwR::getCodebook()` to inspect the complete, final structure).
#' @export
#'
#' @examples
#' \dontrun{
#' aineisto <- sd_read("survey_data.sav")
#' aineisto <- sd_detect_roles(aineisto)
#' aineisto <- sd_set_missing(aineisto, codes = c(99, -9))
#' sd_export_ddi(aineisto, file = "codebook.xml", title = "Tyotyytyvaisyyskysely 2026")
#' }
sd_export_ddi <- function(x, file = "codebook.xml", title = NULL,
                           overwrite = FALSE, ...) {
  if (!is_sd_data(x)) {
    stop("`x` ei ole sd_data-olio (ks. sd_read()).", call. = FALSE)
  }
  if (!requireNamespace("DDIwR", quietly = TRUE)) {
    stop(
      "sd_export_ddi() vaatii DDIwR-paketin: install.packages(\"DDIwR\")",
      call. = FALSE
    )
  }
  if (file.exists(file) && !overwrite) {
    stop(
      "Tiedosto on jo olemassa: ", file, "\n",
      "Aseta overwrite = TRUE jos haluat korvata sen, ",
      "tai anna toinen polku file-argumentilla.",
      call. = FALSE
    )
  }

  if (length(x$meta$roles) == 0) {
    message(
      "Muuttujarooleja ei ole viela maaritetty -- suosittelemme ajamaan ",
      "sd_detect_roles() ennen vientia, jotta DDI-tyyppitiedot ",
      "(varFormat) ovat tarkempia."
    )
  }

  title <- title %||% x$meta$paradata$nimi %||% "Untitled dataset"

  vars <- lapply(names(x$data), function(nm) {
    # Huom: meta$roles on nimetty character-vektori, ei lista -- [[nm]]
    # heittäisi "subscript out of bounds" -virheen jos nm puuttuu siitä
    # (toisin kuin listalle, jolle [[nm]] palauttaisi NULL). Siksi
    # eksplisiittinen jäsenyystarkistus tässä.
    role <- if (nm %in% names(x$meta$roles)) x$meta$roles[[nm]] else "unknown"
    sd_ddi_var_(
      col           = x$data[[nm]],
      name          = nm,
      role          = role,
      label         = x$meta$labels[[nm]],
      value_labels  = x$meta$value_labels[[nm]],
      missing_codes = x$meta$missing_codes[[nm]]
    )
  })

  codeBook <- DDIwR::makeElement("codeBook", children = list(
    DDIwR::makeElement("dataDscr", children = vars)
  ))

  DDIwR::exportCodebook(codeBook, file, titl = title, monolang = TRUE, ...)

  message("DDI-koodikirja tallennettu: ", file)
  invisible(codeBook)
}

# -- Sisainen apufunktio: yhden muuttujan "var"-elementti ---------------

sd_ddi_var_ <- function(col, name, role, label = NULL,
                         value_labels = NULL, missing_codes = NULL) {
  children <- list()

  if (!is.null(label) && nzchar(label)) {
    children <- c(children, list(DDIwR::makeElement("labl", content = label)))
  }

  if (!is.null(value_labels)) {
    catgry <- DDIwR::makeCategories(list(
      labels = value_labels,
      na_values = missing_codes
    ))
    children <- c(children, catgry)
  }

  ddi_type <- switch(role,
    continuous = , weight = "numeric",
    date       = "date",
    text       = "character",
    if (is.numeric(col)) "numeric" else "character"
  )
  children <- c(
    children,
    list(DDIwR::makeElement("varFormat", attributes = c(type = ddi_type)))
  )

  DDIwR::makeElement("var", attributes = c(name = name), children = children)
}

`%||%` <- function(a, b) if (is.null(a) || (length(a) == 1 && is.na(a))) b else a
