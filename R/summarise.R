#' Summarise a survey dataset, variable by variable
#'
#' Computes per-variable statistics from an `sd_data` object, choosing
#' which statistics to compute based on each variable's role (see
#' `sd_detect_roles()`). This is "Vaihe 1" of the documentation pipeline —
#' plain R computing numbers — kept separate from "Vaihe 2", where an LLM
#' turns the numbers into prose (see `sd_build_prompt()`/`sd_document()`).
#'
#' If some or all variables in `x` do not yet have a role assigned (see
#' `sd_detect_roles()`), [sd_summarise()] detects roles for those
#' variables automatically. Roles you have already set (with
#' `sd_detect_roles()` or `sd_set_role()`) are always kept as-is.
#'
#' Open-ended text variables (role `"text"`) are summarised only by
#' aggregate figures (count, missing count, average length, number of
#' unique responses) — the actual text content is never included, so that
#' it is not, for example, sent on to an LLM by accident.
#'
#' @section Recommended order:
#' Call `sd_set_missing()` before `sd_summarise()` (directly, or before
#' `sd_detect_roles()` if you call that yourself first) — otherwise
#' sentinel missing-value codes (e.g. `99`) are treated as real values and
#' distort both the role detection and the statistics themselves.
#'
#' @param x An `sd_data` object.
#' @return An object of class `sd_summary`. Use `format()` or `print()` to
#'   turn it into a text report (also used as the input for
#'   `sd_build_prompt()`).
#' @export
#'
#' @examples
#' \dontrun{
#' aineisto <- sd_read("survey_data.csv")
#' aineisto <- sd_set_missing(aineisto, codes = c(99, -9))
#' aineisto <- sd_detect_roles(aineisto)
#' kooste <- sd_summarise(aineisto)
#' print(kooste)
#' }
sd_summarise <- function(x) {
  if (!is_sd_data(x)) {
    stop("`x` ei ole sd_data-olio (ks. sd_read()).", call. = FALSE)
  }

  puuttuvat_roolit <- setdiff(names(x$data), names(x$meta$roles))
  if (length(puuttuvat_roolit) > 0) {
    if (length(x$meta$roles) == 0) {
      message(
        "Muuttujaroolit puuttuvat kokonaan — päätellään ne ",
        "automaattisesti sd_detect_roles()-heuristiikalla."
      )
    } else {
      message(
        "Näiltä muuttujilta puuttuu rooli, päätellään automaattisesti: ",
        paste(puuttuvat_roolit, collapse = ", ")
      )
    }
    apu_data <- new_sd_data(x$data[puuttuvat_roolit])
    apu <- suppressMessages(sd_detect_roles(apu_data))
    x$meta$roles[puuttuvat_roolit] <- apu$meta$roles[puuttuvat_roolit]
  }

  muuttujat <- lapply(names(x$data), function(nm) {
    sd_summarise_var_(
      col          = x$data[[nm]],
      name         = nm,
      role         = x$meta$roles[[nm]],
      label        = x$meta$labels[[nm]],
      value_labels = x$meta$value_labels[[nm]]
    )
  })
  names(muuttujat) <- names(x$data)

  structure(
    list(variables = muuttujat, paradata = x$meta$paradata),
    class = "sd_summary"
  )
}

# -- Yhden muuttujan tilastot -------------------------------------------

sd_summarise_var_ <- function(col, name, role, label = NULL, value_labels = NULL) {
  if (is.null(role)) role <- "unknown"

  n <- length(col)
  n_missing <- sum(is.na(col))
  valid <- col[!is.na(col)]

  extra <- switch(role,
    id         = list(),
    weight     = sd_summarise_continuous_(valid),
    likert     = sd_summarise_likert_(valid, value_labels),
    continuous = sd_summarise_continuous_(valid),
    nominal    = sd_summarise_categorical_(valid, value_labels),
    date       = sd_summarise_date_(valid),
    text       = sd_summarise_text_(valid),
    list()
  )

  utils::modifyList(
    list(
      name = name, role = role, label = label,
      n = n, n_missing = n_missing
    ),
    extra
  )
}

sd_summarise_continuous_ <- function(valid) {
  if (length(valid) == 0) return(list())
  list(
    mean   = mean(valid),
    sd     = stats::sd(valid),
    median = stats::median(valid),
    min    = min(valid),
    max    = max(valid)
  )
}

sd_summarise_likert_ <- function(valid, value_labels = NULL) {
  if (length(valid) == 0) return(list())
  list(
    mean         = mean(valid),
    sd           = stats::sd(valid),
    median       = stats::median(valid),
    distribution = table(valid),
    value_labels = value_labels
  )
}

sd_summarise_categorical_ <- function(valid, value_labels = NULL) {
  if (length(valid) == 0) return(list())
  jakauma <- table(valid)
  list(
    n_categories = length(jakauma),
    distribution = jakauma,
    percentages  = round(prop.table(jakauma) * 100, 1),
    value_labels = value_labels
  )
}

sd_summarise_date_ <- function(valid) {
  if (length(valid) == 0) return(list())
  list(min = min(valid), max = max(valid))
}

sd_summarise_text_ <- function(valid) {
  # Huom: tallennetaan vain agregoidut tunnusluvut, EI itse tekstisisältöä
  # — avointa tekstiä ei haluta viedä LLM:lle oletusarvoisesti.
  if (length(valid) == 0) {
    return(list(avg_length = NA_real_, n_unique = 0L))
  }
  list(
    avg_length = mean(nchar(as.character(valid))),
    n_unique   = length(unique(valid))
  )
}

# -- Tekstimuotoinen esitys (LLM-koostetta ja tulostusta varten) -------

#' @export
format.sd_summary <- function(x, ...) {
  osat <- vapply(
    x$variables,
    sd_format_variable_,
    character(1)
  )

  paste0(
    "=== AINEISTON TIIVISTELMÄ ===\n\n",
    "Muuttujia yhteensä: ", length(x$variables), "\n\n",
    paste(osat, collapse = "\n\n")
  )
}

#' @export
print.sd_summary <- function(x, ...) {
  cat(format(x), "\n")
  invisible(x)
}

sd_format_variable_ <- function(v) {
  otsikko <- if (!is.null(v$label) && nzchar(v$label)) {
    paste0(v$name, " (", v$label, ")")
  } else {
    v$name
  }

  runko <- switch(v$role,
    id         = "Tunnistemuuttuja, ei tilastoja.",
    weight     = sd_format_continuous_(v, "Painomuuttuja."),
    likert     = sd_format_likert_(v),
    continuous = sd_format_continuous_(v, "Jatkuva muuttuja."),
    nominal    = sd_format_categorical_(v),
    date       = sprintf("Päivämäärämuuttuja. Vaihteluväli: %s – %s", v$min, v$max),
    text       = sprintf(
      "Avoin tekstimuuttuja. Uniikkeja vastauksia: %d, keskipituus: %.0f merkkiä.",
      v$n_unique, v$avg_length
    ),
    "Tuntematon muuttujatyyppi, ei tilastoja."
  )

  sprintf(
    "[%s] rooli: %s\nPuuttuvia: %d / %d\n%s",
    otsikko, v$role, v$n_missing, v$n, runko
  )
}

sd_format_continuous_ <- function(v, otsikko) {
  sprintf(
    "%s Keskiarvo: %.2f, keskihajonta: %.2f, mediaani: %.2f, vaihteluväli: %.2f–%.2f",
    otsikko, v$mean, v$sd, v$median, v$min, v$max
  )
}

sd_format_likert_ <- function(v) {
  jakauma <- v$distribution
  jakauma_teksti <- paste(names(jakauma), jakauma, sep = " = ", collapse = ", ")
  sprintf(
    "Likert-tyyppinen muuttuja. Jakauma: %s. Keskiarvo: %.2f, keskihajonta: %.2f, mediaani: %.2f",
    jakauma_teksti, v$mean, v$sd, v$median
  )
}

sd_format_categorical_ <- function(v) {
  jakauma <- v$distribution
  osuudet <- v$percentages
  jakauma_teksti <- paste0(
    names(jakauma), " (", jakauma, ", ", osuudet, "%)",
    collapse = "; "
  )
  sprintf(
    "Kategorinen muuttuja (%d luokkaa). Jakauma: %s",
    v$n_categories, jakauma_teksti
  )
}
