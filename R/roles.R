#' Detect variable roles heuristically
#'
#' Guesses a role for each variable in an `sd_data` object, based on
#' simple rules (data type, value range, name pattern, cardinality). This
#' is a heuristic starting point, not a guarantee — always check the
#' result and correct individual variables with `sd_set_role()` where the
#' guess is wrong.
#'
#' Roles used elsewhere in the package: `"id"`, `"likert"`, `"nominal"`,
#' `"continuous"`, `"date"`, `"text"`, `"weight"`, `"unknown"`.
#'
#' The heuristic, checked in this order for each variable:
#' \describe{
#'   \item{date}{Column class is `Date`, `POSIXct` or `POSIXt`.}
#'   \item{id}{Variable name matches `id`/`tunnus` (whole word or suffix,
#'     e.g. `vastaaja_id`), OR every non-missing value is unique and there
#'     are more than 10 respondents.}
#'   \item{weight}{Variable name matches `paino`/`weight`/`wt` and the
#'     variable is numeric.}
#'   \item{likert}{Numeric, whole-number values, 2–11 distinct values, and
#'     a value range of 10 or less. This is a common shape for
#'     Likert/ordinal scales, but it also matches other small-range counts
#'     (e.g. number of children) — check the result.}
#'   \item{continuous}{Any other numeric variable.}
#'   \item{text}{Character/factor where more than half the values are
#'     unique, or the average value length is over 30 characters — a
#'     proxy for open-ended text.}
#'   \item{nominal}{Any other character, factor, or logical variable.}
#'   \item{unknown}{Anything not covered above.}
#' }
#'
#' @section Recommended order:
#' Run `sd_set_missing()` *before* `sd_detect_roles()` whenever your data
#' uses sentinel missing-value codes (e.g. `99`, `-9`). Otherwise a
#' sentinel code widens a variable's apparent value range — a 1–5 Likert
#' item with a handful of `99`s looks like it ranges from 1 to 99, and
#' gets classified as `"continuous"` instead of `"likert"`.
#'
#' @param x An `sd_data` object.
#' @return The same `sd_data` object, with `meta$roles` filled in.
#' @export
#'
#' @examples
#' \dontrun{
#' aineisto <- sd_read("survey_data.csv")
#' aineisto <- sd_detect_roles(aineisto)
#' print(aineisto)
#' }
sd_detect_roles <- function(x) {
  if (!is_sd_data(x)) {
    stop("`x` ei ole sd_data-olio (ks. sd_read()).", call. = FALSE)
  }

  data <- x$data
  roles <- vapply(
    names(data),
    function(nm) sd_detect_role_(data[[nm]], nm),
    character(1)
  )
  names(roles) <- names(data)

  x$meta$roles <- roles

  role_counts <- table(roles)
  yhteenveto <- paste0(
    "  ", names(role_counts), ": ", as.integer(role_counts),
    collapse = "\n"
  )
  message(
    "Roolit päätelty ", length(roles), " muuttujalle:\n",
    yhteenveto,
    "\nTämä on heuristiikka, ei varma totuus — ",
    "tarkista tulos ja korjaa tarvittaessa sd_set_role():lla."
  )

  x
}

# Yhden muuttujan roolin päättely.
sd_detect_role_ <- function(col, name) {
  valid <- col[!is.na(col)]
  n_unique <- length(unique(valid))
  n_valid <- length(valid)

  if (inherits(col, c("Date", "POSIXct", "POSIXt"))) {
    return("date")
  }

  # Huom: pelkkä "kaikki arvot uniikkeja" ei riitä id-tunnisteeksi, koska
  # se pätee lähes aina myös jatkuville muuttujille (esim. tulot, mitatut
  # arvot) ja vapaalle tekstille. Nimettömälle sarakkeelle vaaditaan siksi
  # kokonaislukuarvot, jotta uniikkius on oikeasti merkki juoksevasta
  # tunnisteesta eikä vain mittaustarkkuudesta.
  id_pattern <- "(^|_)(id|tunnus)$"
  valid_int <- is.numeric(col) && n_valid > 0 && all(valid == round(valid))
  looks_like_id <- grepl(id_pattern, name, ignore.case = TRUE) ||
    (n_valid > 10 && n_unique == n_valid && valid_int)
  if (looks_like_id) {
    return("id")
  }

  weight_pattern <- "(^|_)(paino|weight|wt)$"
  if (grepl(weight_pattern, name, ignore.case = TRUE) && is.numeric(col)) {
    return("weight")
  }

  if (is.logical(col)) {
    return("nominal")
  }

  if (is.numeric(col)) {
    if (n_valid == 0) {
      return("unknown")
    }
    kokonaisluku <- all(valid == round(valid))
    vaihteluvali <- max(valid) - min(valid)
    if (kokonaisluku && n_unique >= 2 && n_unique <= 11 && vaihteluvali <= 10) {
      return("likert")
    }
    return("continuous")
  }

  if (is.character(col) || is.factor(col)) {
    if (n_valid == 0) {
      return("unknown")
    }
    merkkijonot <- as.character(valid)
    keskipituus <- mean(nchar(merkkijonot))
    osuus_uniikkeja <- n_unique / n_valid
    if (osuus_uniikkeja > 0.5 || keskipituus > 30) {
      return("text")
    }
    return("nominal")
  }

  "unknown"
}

#' Manually set the role of one variable
#'
#' Overrides the role of a single variable in an `sd_data` object, e.g.
#' after inspecting the result of `sd_detect_roles()` and finding a
#' mistake.
#'
#' @param x An `sd_data` object.
#' @param var Name of the variable to set the role for.
#' @param role One of `"id"`, `"likert"`, `"nominal"`, `"continuous"`,
#'   `"date"`, `"text"`, `"weight"`, or `"unknown"`.
#'
#' @return The same `sd_data` object, with the role for `var` updated.
#' @export
#'
#' @examples
#' \dontrun{
#' aineisto <- sd_set_role(aineisto, "tyovuodet", "continuous")
#' }
sd_set_role <- function(x, var, role) {
  if (!is_sd_data(x)) {
    stop("`x` ei ole sd_data-olio (ks. sd_read()).", call. = FALSE)
  }

  sallitut_roolit <- c(
    "id", "likert", "nominal", "continuous",
    "date", "text", "weight", "unknown"
  )
  role <- match.arg(role, sallitut_roolit)

  if (!var %in% names(x$data)) {
    stop("Muuttujaa '", var, "' ei löydy datasta.", call. = FALSE)
  }

  x$meta$roles[[var]] <- role
  x
}

#' Define sentinel missing-value codes
#'
#' Survey data often encodes missing responses with sentinel numeric or
#' text codes (e.g. `99`, `-9`, `"En osaa sanoa"`) instead of a true
#' missing value. `sd_set_missing()` records these codes in
#' `meta$missing_codes` and replaces matching values with `NA` in the
#' data itself, so that later pipeline steps (e.g. `sd_summarise()`)
#' compute correct statistics.
#'
#' @section Always name `vars` explicitly:
#' Leaving `vars` as `NULL` applies `codes` to *every* variable in the
#' data — including id, weight, and date columns. This is risky: an id
#' variable coded `1:200` legitimately contains the value `99`, and a
#' blanket `sd_set_missing(x, codes = 99)` would silently turn that
#' respondent's id into `NA`. In practice, always list the specific
#' variables where the sentinel code is meaningful (typically your
#' substantive survey items), e.g.
#' `vars = c("tt1", "tt2", "tt3")` — never rely on the "apply to
#' everything" default. If variable roles have already been set (see
#' `sd_detect_roles()`), leaving `vars` as `NULL` at least skips
#' variables with role `"id"` automatically and a warning is raised —
#' but this is a safety net, not a substitute for naming `vars`.
#'
#' @param x An `sd_data` object.
#' @param codes Either a vector of codes to apply to `vars` (e.g.
#'   `c(99, -9)`), or a named list mapping variable names to their own
#'   codes (e.g. `list(tt1 = c(99, -9), avoin_palaute = "")`) — in which
#'   case `vars` is ignored.
#' @param vars Character vector of variable names to apply `codes` to.
#'   `NULL` (the default) applies to every variable in the data except
#'   those already known to have role `"id"` — see the warning above.
#'   Ignored when `codes` is a named list.
#'
#' @return The same `sd_data` object, with matching values in the data
#'   replaced by `NA` and `meta$missing_codes` updated.
#' @export
#'
#' @examples
#' \dontrun{
#' # Suositeltu: nimeä muuttujat aina eksplisiittisesti
#' aineisto <- sd_set_missing(aineisto, codes = c(99, -9),
#'                             vars = c("tt1", "tt2", "tt3"))
#'
#' # Eri koodit eri muuttujille:
#' aineisto <- sd_set_missing(aineisto, codes = list(
#'   tt1 = c(99, -9),
#'   avoin_palaute = ""
#' ))
#' }
sd_set_missing <- function(x, codes, vars = NULL) {
  if (!is_sd_data(x)) {
    stop("`x` ei ole sd_data-olio (ks. sd_read()).", call. = FALSE)
  }

  if (is.list(codes)) {
    if (is.null(names(codes)) || any(names(codes) == "")) {
      stop(
        "Kun `codes` on lista, sen jokaisella alkiolla pitää olla muuttujan nimi.",
        call. = FALSE
      )
    }
    koodikartta <- codes
  } else {
    if (is.null(vars)) {
      vars <- names(x$data)
      id_muuttujat <- names(x$meta$roles)[x$meta$roles == "id"]
      ohitetut <- intersect(vars, id_muuttujat)
      if (length(ohitetut) > 0) {
        vars <- setdiff(vars, ohitetut)
        message(
          "Ohitetaan tunnistemuuttujat (rooli \"id\") automaattisesti: ",
          paste(ohitetut, collapse = ", ")
        )
      }
      warning(
        "`vars` ei ole annettu — koodit (", paste(codes, collapse = ", "),
        ") sovelletaan KAIKKIIN muihin muuttujiin (", length(vars), " kpl). ",
        "Anna `vars` eksplisiittisesti, ettei koodi vahingossa poista ",
        "oikeita arvoja (esim. tunnisteen tai painon sattumalta samaa arvoa).",
        call. = FALSE
      )
    }
    koodikartta <- rep(list(codes), length(vars))
    names(koodikartta) <- vars
  }

  tuntemattomat <- setdiff(names(koodikartta), names(x$data))
  if (length(tuntemattomat) > 0) {
    stop(
      "Muuttujia ei löydy datasta: ", paste(tuntemattomat, collapse = ", "),
      call. = FALSE
    )
  }

  for (nm in names(koodikartta)) {
    osumat <- x$data[[nm]] %in% koodikartta[[nm]]
    x$data[[nm]][osumat] <- NA
    x$meta$missing_codes[[nm]] <- unique(c(x$meta$missing_codes[[nm]], koodikartta[[nm]]))
  }

  x
}
