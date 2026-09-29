#' Read survey data into an sd_data object
#'
#' Reads a survey dataset from disk and wraps it in an `sd_data` object
#' (see [new_sd_data()]). The file format is chosen automatically from the
#' file extension. Currently supported: `.csv`, `.tsv`, `.xlsx`, `.xls`,
#' `.sav` (SPSS), `.dta` (Stata), and `.rds`.
#'
#' When the source data carries labels of its own (SPSS `.sav`, Stata
#' `.dta`, read via the \pkg{haven} package, or an `.rds` file containing
#' an already-labelled data frame from an earlier session), the variable
#' labels are copied into `meta$labels` and the value labels into
#' `meta$value_labels` automatically -- this harvesting happens inside
#' [new_sd_data()] and applies to any data frame with `label`/`labels`
#' column attributes, regardless of source format. For formats without
#' built-in labels (csv, tsv, xlsx), these start out empty and can be
#' filled in afterwards.
#'
#' [sd_read()] does not itself set variable roles or missing-value codes —
#' those are the next steps in the pipeline (`sd_detect_roles()` and
#' `sd_set_missing()`).
#'
#' @param path Path to the data file.
#' @param encoding Text encoding to assume for csv/tsv files. Defaults to
#'   `"UTF-8"`. Ignored for other formats.
#' @param ... Further arguments passed on to the underlying reader
#'   function ([utils::read.csv()], [utils::read.delim()],
#'   `readxl::read_excel()`, `haven::read_sav()`, or `haven::read_dta()`).
#'
#' @return An `sd_data` object.
#' @export
#'
#' @examples
#' \dontrun{
#' aineisto <- sd_read("survey_data.csv")
#' aineisto <- sd_read("survey_data.sav")
#' }
sd_read <- function(path, encoding = "UTF-8", ...) {
  if (!file.exists(path)) {
    stop("Tiedostoa ei löydy: ", path, call. = FALSE)
  }

  ext <- tolower(tools::file_ext(path))

  result <- switch(ext,
    csv  = sd_read_csv_(path, encoding = encoding, ...),
    tsv  = sd_read_tsv_(path, encoding = encoding, ...),
    xlsx = sd_read_excel_(path, ...),
    xls  = sd_read_excel_(path, ...),
    sav  = sd_read_haven_(path, reader = "read_sav", ...),
    dta  = sd_read_haven_(path, reader = "read_dta", ...),
    rds  = list(data = readRDS(path), meta = list()),
    stop(
      "Tiedostomuotoa '.", ext, "' ei tueta vielä. ",
      "Tuetut muodot: csv, tsv, xlsx, xls, sav, dta, rds.",
      call. = FALSE
    )
  )

  new_sd_data(result$data, result$meta)
}

# -- Sisäiset apufunktiot ----------------------------------------------

sd_read_csv_ <- function(path, encoding = "UTF-8", ...) {
  data <- utils::read.csv(
    path,
    fileEncoding = encoding,
    stringsAsFactors = FALSE,
    ...
  )
  list(data = data, meta = list())
}

sd_read_tsv_ <- function(path, encoding = "UTF-8", ...) {
  data <- utils::read.delim(
    path,
    fileEncoding = encoding,
    stringsAsFactors = FALSE,
    ...
  )
  list(data = data, meta = list())
}

sd_read_excel_ <- function(path, ...) {
  if (!requireNamespace("readxl", quietly = TRUE)) {
    stop(
      "xlsx-tiedostojen lukeminen vaatii readxl-paketin: ",
      "install.packages(\"readxl\")",
      call. = FALSE
    )
  }
  data <- readxl::read_excel(path, ...)
  list(data = data, meta = list())
}

sd_read_haven_ <- function(path, reader = c("read_sav", "read_dta"), ...) {
  reader <- match.arg(reader)
  if (!requireNamespace("haven", quietly = TRUE)) {
    stop(
      "SPSS/Stata-tiedostojen lukeminen vaatii haven-paketin: ",
      "install.packages(\"haven\")",
      call. = FALSE
    )
  }
  lue <- getExportedValue("haven", reader)
  data <- lue(path, ...)
  # Huom: meta jätetään tyhjäksi -- new_sd_data() poimii label/labels-
  # attribuutit automaattisesti (ks. sd_harvest_attr_labels_() class.R:ssä).
  list(data = data, meta = list())
}
