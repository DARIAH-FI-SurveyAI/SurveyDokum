# -- Puhtaat jäsennys-/muokkausapufunktiot (ei riipu LLM:stä eikä levystä) --

test_that("sd_extract_braces_() käsittelee sisäkkäiset aaltosulut oikein", {
  teksti <- "abc{outer{inner}more}xyz"
  tulos <- sd_extract_braces_(teksti, 5)
  expect_equal(tulos$content, "outer{inner}more")
  expect_equal(substr(teksti, tulos$end, tulos$end), "x")
})

test_that("sd_extract_braces_() palauttaa NULL kun sulkeva aaltosulku puuttuu", {
  expect_null(sd_extract_braces_("abc{ei sulkeutumista", 5))
})

test_that("sd_extract_braces_() palauttaa NULL kun start > nchar (ei mene taaksepäin)", {
  # Regressio: R:n `start:n` menisi laskevaan järjestykseen jos start > n.
  expect_null(sd_extract_braces_("abc", 10))
})

roxygen_teksti <- paste0(
  "#' Survey_data\n",
  "#'\n",
  "#' Kuvausteksti.\n",
  "#'\n",
  "#' @format Dataframe, jossa 200 rivi\u00e4 ja 2 muuttujaa:\n",
  "#' \\describe{\n",
  "#'   \\item{a}{Muuttuja A. Numeerinen.}\n",
  "#'   \\item{b}{Muuttuja B. Numeerinen.}\n",
  "#' }\n",
  "#'\n",
  "#' @details\n",
  "#' Yksityiskohdat.\n",
  "#'\n",
  "#' @source L\u00e4hde.\n",
  "\"survey_data\"\n"
)

test_that("sd_parse_documented_vars_() löytää dokumentoidut muuttujat", {
  expect_equal(sd_parse_documented_vars_(roxygen_teksti), c("a", "b"))
})

test_that("sd_parse_documented_vars_() palauttaa NULL kun \\describe{}-lohkoa ei ole", {
  expect_null(sd_parse_documented_vars_("#' Otsikko\n\"survey_data\""))
})

test_that("sd_parse_documented_vars_() palauttaa character(0) kun lohko on tyhjä", {
  expect_identical(sd_parse_documented_vars_("#' \\describe{\n#' }\n"), character(0))
})

test_that("sd_extract_items_() jäsentää LLM:n vastauksen nimetyksi listaksi", {
  vastaus <- "\\item{c}{Uusi muuttuja C.}\n\n\\item{d}{Uusi muuttuja D.}"
  rivit <- sd_extract_items_(vastaus)
  expect_equal(names(rivit), c("c", "d"))
  expect_equal(rivit[["c"]], "Uusi muuttuja C.")
})

test_that("sd_extract_items_() sietää välilyöntejä/rivinvaihtoja sulkujen välissä", {
  rivit <- sd_extract_items_("\\item{c}  \n  {Kuvaus C.}")
  expect_equal(rivit[["c"]], "Kuvaus C.")
})

test_that("sd_insert_items_() lisää uudet rivit olemassa olevaan lohkoon koskematta muuhun", {
  paivitetty <- sd_insert_items_(roxygen_teksti, "  \\item{c}{Uusi C.}")
  expect_match(paivitetty, "\\item{c}{Uusi C.}", fixed = TRUE)
  expect_match(paivitetty, "\\item{a}{Muuttuja A. Numeerinen.}", fixed = TRUE)
  expect_match(paivitetty, "@details", fixed = TRUE)
})

test_that("sd_insert_items_() antaa selkeän virheen kun \\describe{}-lohkoa ei löydy", {
  expect_error(sd_insert_items_("ei lohkoa tässä", "x"), "describe")
})

test_that("sd_fix_format_var_count_() korjaa suomenkielisen muuttujamäärän", {
  korjattu <- sd_fix_format_var_count_(roxygen_teksti, 3)
  expect_match(korjattu, "ja 3 muuttujaa", fixed = TRUE)
})

test_that("sd_fix_format_var_count_() korjaa englanninkielisen muuttujamäärän", {
  korjattu <- sd_fix_format_var_count_("#' @format Dataframe with 200 rows and 2 variables:\n", 5)
  expect_match(korjattu, "200 rows and 5 variables", fixed = TRUE)
})

test_that("sd_fix_format_var_count_() korjaa ruotsinkielisen muuttujamäärän", {
  korjattu <- sd_fix_format_var_count_("#' @format En data frame med 200 rader och 2 variabler:\n", 5)
  expect_match(korjattu, "200 rader och 5 variabler", fixed = TRUE)
})

test_that("sd_fix_format_var_count_() ei tee mitään jos @format-riviä ei löydy", {
  teksti <- "#' Otsikko\n\"x\""
  expect_identical(sd_fix_format_var_count_(teksti, 9), teksti)
})

# -- sd_extract_format_row_count_() / sd_fix_format_row_count_() -------

test_that("sd_extract_format_row_count_() löytää suomenkielisen rivimäärän", {
  expect_equal(sd_extract_format_row_count_(roxygen_teksti), 200L)
})

test_that("sd_extract_format_row_count_() löytää englanninkielisen rivimäärän", {
  expect_equal(
    sd_extract_format_row_count_("#' @format A data frame with 200 rows and 2 variables:\n"),
    200L
  )
})

test_that("sd_extract_format_row_count_() löytää ruotsinkielisen rivimäärän", {
  expect_equal(
    sd_extract_format_row_count_("#' @format En data frame med 200 rader och 2 variabler:\n"),
    200L
  )
})

test_that("sd_extract_format_row_count_() palauttaa NA kun @format-riviä ei ole", {
  expect_true(is.na(sd_extract_format_row_count_("#' Otsikko\n\"x\"")))
})

test_that("sd_extract_format_row_count_() palauttaa NA kun rivimäärää ei tunnisteta", {
  expect_true(is.na(sd_extract_format_row_count_("#' @format käsin muokattu rivi\n")))
})

test_that("sd_fix_format_row_count_() korjaa suomenkielisen rivimäärän koskematta muuttujamäärään", {
  korjattu <- sd_fix_format_row_count_(roxygen_teksti, 250)
  expect_match(korjattu, "jossa 250 riviä", fixed = TRUE)
  expect_match(korjattu, "ja 2 muuttujaa", fixed = TRUE)
})

test_that("sd_fix_format_row_count_() korjaa englanninkielisen rivimäärän", {
  korjattu <- sd_fix_format_row_count_(
    "#' @format A data frame with 200 rows and 2 variables:\n", 250
  )
  expect_match(korjattu, "250 rows and 2 variables", fixed = TRUE)
})

test_that("sd_fix_format_row_count_() korjaa ruotsinkielisen rivimäärän", {
  korjattu <- sd_fix_format_row_count_(
    "#' @format En data frame med 200 rader och 2 variabler:\n", 250
  )
  expect_match(korjattu, "250 rader och 2 variabler", fixed = TRUE)
})

test_that("sd_fix_format_row_count_() ei tee mitään jos @format-riviä ei löydy", {
  teksti <- "#' Otsikko\n\"x\""
  expect_identical(sd_fix_format_row_count_(teksti, 9), teksti)
})

# -- sd_check_documentation_current() ---------------------------------

test_that("sd_check_documentation_current() ei löydä uusia muuttujia kun kaikki on dokumentoitu", {
  tmpdir <- tempfile("sdupdatetest"); dir.create(tmpdir); dir.create(file.path(tmpdir, "R"))
  old_wd <- setwd(tmpdir)
  on.exit({ setwd(old_wd); unlink(tmpdir, recursive = TRUE) })
  writeLines(roxygen_teksti, file.path("R", "survey_data.R"), useBytes = TRUE)

  x <- new_sd_data(data.frame(a = 1:5, b = 1:5))
  uudet <- sd_check_documentation_current(x, "survey_data")
  expect_identical(uudet, character(0))
})

test_that("sd_check_documentation_current() löytää uuden muuttujan", {
  tmpdir <- tempfile("sdupdatetest"); dir.create(tmpdir); dir.create(file.path(tmpdir, "R"))
  old_wd <- setwd(tmpdir)
  on.exit({ setwd(old_wd); unlink(tmpdir, recursive = TRUE) })
  writeLines(roxygen_teksti, file.path("R", "survey_data.R"), useBytes = TRUE)

  x <- new_sd_data(data.frame(a = 1:5, b = 1:5, c = 1:5))
  expect_message(uudet <- sd_check_documentation_current(x, "survey_data"), "c")
  expect_identical(uudet, "c")
})

test_that("sd_check_documentation_current() antaa selkeän virheen kun tiedostoa ei löydy", {
  tmpdir <- tempfile("sdupdatetest"); dir.create(tmpdir)
  old_wd <- setwd(tmpdir)
  on.exit({ setwd(old_wd); unlink(tmpdir, recursive = TRUE) })

  x <- new_sd_data(data.frame(a = 1:5))
  expect_error(sd_check_documentation_current(x, "ei_olemassa"), "löydy")
})

test_that("sd_check_documentation_current() antaa selkeän virheen kun \\describe{}-lohkoa ei löydy", {
  tmpdir <- tempfile("sdupdatetest"); dir.create(tmpdir); dir.create(file.path(tmpdir, "R"))
  old_wd <- setwd(tmpdir)
  on.exit({ setwd(old_wd); unlink(tmpdir, recursive = TRUE) })
  writeLines("#' Otsikko\n\"kasin_muokattu\"", file.path("R", "kasin_muokattu.R"))

  x <- new_sd_data(data.frame(z = 1:5))
  expect_error(sd_check_documentation_current(x, "kasin_muokattu"), "describe")
})

# -- sd_check_row_count() / sd_update_row_count() (ei riipu LLM:stä) ----
# roxygen_teksti-fixturessa on "200 riviä ja 2 muuttujaa" -- sama
# rivimäärä kuin muuttujien datassa (5 riviä) EI täsmää, joten alla
# olevat testit rakentavat oikean rivimäärän omaavan datan tapaus
# kerrallaan.

test_that("sd_check_row_count() ei löydä eroa kun rivimäärä täsmää", {
  tmpdir <- tempfile("sdupdatetest"); dir.create(tmpdir); dir.create(file.path(tmpdir, "R"))
  old_wd <- setwd(tmpdir)
  on.exit({ setwd(old_wd); unlink(tmpdir, recursive = TRUE) })
  writeLines(roxygen_teksti, file.path("R", "survey_data.R"), useBytes = TRUE)

  x <- new_sd_data(data.frame(a = 1:200, b = 1:200))
  expect_message(ero <- sd_check_row_count(x, "survey_data"), "ajan tasalla")
  expect_identical(ero, 0L)
})

test_that("sd_check_row_count() löytää rivimäärän kasvun", {
  tmpdir <- tempfile("sdupdatetest"); dir.create(tmpdir); dir.create(file.path(tmpdir, "R"))
  old_wd <- setwd(tmpdir)
  on.exit({ setwd(old_wd); unlink(tmpdir, recursive = TRUE) })
  writeLines(roxygen_teksti, file.path("R", "survey_data.R"), useBytes = TRUE)

  x <- new_sd_data(data.frame(a = 1:250, b = 1:250))
  expect_message(ero <- sd_check_row_count(x, "survey_data"), "sd_update_row_count")
  expect_identical(ero, 50L)
})

test_that("sd_check_row_count() antaa selkeän virheen kun tiedostoa ei löydy", {
  tmpdir <- tempfile("sdupdatetest"); dir.create(tmpdir)
  old_wd <- setwd(tmpdir)
  on.exit({ setwd(old_wd); unlink(tmpdir, recursive = TRUE) })

  x <- new_sd_data(data.frame(a = 1:5))
  expect_error(sd_check_row_count(x, "ei_olemassa"), "löydy")
})

test_that("sd_check_row_count() antaa selkeän virheen kun rivimäärää ei tunnisteta", {
  tmpdir <- tempfile("sdupdatetest"); dir.create(tmpdir); dir.create(file.path(tmpdir, "R"))
  old_wd <- setwd(tmpdir)
  on.exit({ setwd(old_wd); unlink(tmpdir, recursive = TRUE) })
  writeLines("#' @format käsin muokattu rivi\n\"kasin_muokattu\"", file.path("R", "kasin_muokattu.R"))

  x <- new_sd_data(data.frame(z = 1:5))
  expect_error(sd_check_row_count(x, "kasin_muokattu"), "rivimäärää")
})

test_that("sd_update_row_count() palauttaa päivitetyn tekstin dry_run = TRUE:lla koskematta tiedostoon", {
  tmpdir <- tempfile("sdupdatetest"); dir.create(tmpdir); dir.create(file.path(tmpdir, "R"))
  old_wd <- setwd(tmpdir)
  on.exit({ setwd(old_wd); unlink(tmpdir, recursive = TRUE) })
  writeLines(roxygen_teksti, file.path("R", "survey_data.R"), useBytes = TRUE)

  x <- new_sd_data(data.frame(a = 1:250, b = 1:250))
  tulos <- sd_update_row_count(x, "survey_data")

  expect_s3_class(tulos, "sd_row_count_update")
  expect_identical(tulos$old_count, 200L)
  expect_identical(tulos$new_count, 250L)
  expect_match(tulos$text, "jossa 250 riviä", fixed = TRUE)
  expect_null(tulos$backup_file)
  expect_false(file.exists(file.path("R", "survey_data.R.bak")))
  levylla <- paste(readLines(file.path("R", "survey_data.R"), encoding = "UTF-8"), collapse = "\n")
  expect_match(levylla, "jossa 200 riviä", fixed = TRUE)
})

test_that("sd_update_row_count() ei tee mitään kun rivimäärä ei ole muuttunut", {
  tmpdir <- tempfile("sdupdatetest"); dir.create(tmpdir); dir.create(file.path(tmpdir, "R"))
  old_wd <- setwd(tmpdir)
  on.exit({ setwd(old_wd); unlink(tmpdir, recursive = TRUE) })
  writeLines(roxygen_teksti, file.path("R", "survey_data.R"), useBytes = TRUE)

  x <- new_sd_data(data.frame(a = 1:200, b = 1:200))
  expect_message(tulos <- sd_update_row_count(x, "survey_data"), "ei ole muuttunut")
  expect_identical(tulos$old_count, tulos$new_count)
  expect_null(tulos$backup_file)
})

test_that("sd_update_row_count() kirjoittaa levylle ja ottaa varmuuskopion kun dry_run = FALSE", {
  tmpdir <- tempfile("sdupdatetest"); dir.create(tmpdir); dir.create(file.path(tmpdir, "R"))
  old_wd <- setwd(tmpdir)
  on.exit({ setwd(old_wd); unlink(tmpdir, recursive = TRUE) })
  writeLines(roxygen_teksti, file.path("R", "survey_data.R"), useBytes = TRUE)

  x <- new_sd_data(data.frame(a = 1:250, b = 1:250))
  tulos <- sd_update_row_count(x, "survey_data", dry_run = FALSE)

  expect_true(file.exists(tulos$backup_file))
  kirjoitettu <- paste(readLines(file.path("R", "survey_data.R"), encoding = "UTF-8"), collapse = "\n")
  expect_match(kirjoitettu, "jossa 250 riviä", fixed = TRUE)
  varmuuskopio <- paste(readLines(tulos$backup_file, encoding = "UTF-8"), collapse = "\n")
  expect_match(varmuuskopio, "jossa 200 riviä", fixed = TRUE)

  # ja sd_check_row_count() vahvistaa tiedoston olevan nyt ajan tasalla
  expect_message(ero <- sd_check_row_count(x, "survey_data"), "ajan tasalla")
  expect_identical(ero, 0L)
})

test_that("sd_update_row_count() antaa selkeän virheen kun tiedostoa ei löydy", {
  tmpdir <- tempfile("sdupdatetest"); dir.create(tmpdir)
  old_wd <- setwd(tmpdir)
  on.exit({ setwd(old_wd); unlink(tmpdir, recursive = TRUE) })

  x <- new_sd_data(data.frame(a = 1:5))
  expect_error(sd_update_row_count(x, "ei_olemassa"), "löydy")
})

test_that("print.sd_row_count_update() toimii sekä muuttuneella että muuttumattomalla rivimäärällä", {
  ajan_tasalla <- structure(
    list(text = "x", old_count = 200L, new_count = 200L, file = "x.R",
         backup_file = NULL, created = Sys.time()),
    class = "sd_row_count_update"
  )
  expect_output(print(ajan_tasalla), "ajan tasalla")

  muuttunut <- structure(
    list(text = "#' teksti", old_count = 200L, new_count = 250L, file = "x.R",
         backup_file = NULL, created = Sys.time()),
    class = "sd_row_count_update"
  )
  expect_output(print(muuttunut), "->", fixed = TRUE)
})

# -- sd_update_roxygen() (mokattu LLM) ----------------------------------

test_that("sd_update_roxygen() tunnistaa uuden muuttujan automaattisesti ja rakentaa oikean tekstin (dry_run)", {
  skip_if_not_installed("ellmer")
  tmpdir <- tempfile("sdupdatetest"); dir.create(tmpdir); dir.create(file.path(tmpdir, "R"))
  old_wd <- setwd(tmpdir)
  on.exit({ setwd(old_wd); unlink(tmpdir, recursive = TRUE) })
  writeLines(roxygen_teksti, file.path("R", "survey_data.R"), useBytes = TRUE)

  testthat::local_mocked_bindings(
    chat_ollama = function(model, system = NULL) {
      list(chat = function(prompt) "\\item{c}{Uusi muuttuja C. Numeerinen.}")
    },
    .package = "ellmer"
  )

  x <- new_sd_data(data.frame(a = 1:5, b = 1:5, c = 1:5))
  tulos <- sd_update_roxygen(x, "survey_data")

  expect_s3_class(tulos, "sd_roxygen_update")
  expect_equal(tulos$added_vars, "c")
  expect_null(tulos$backup_file)
  expect_match(tulos$text, "\\item{c}{Uusi muuttuja C. Numeerinen.}", fixed = TRUE)
  expect_match(tulos$text, "ja 3 muuttujaa", fixed = TRUE)
  # dry_run = TRUE (oletus): tiedostoon ei kosketa
  expect_false(file.exists(file.path("R", "survey_data.R.bak")))
  alkuperainen_levylla <- paste(readLines(file.path("R", "survey_data.R"), encoding = "UTF-8"), collapse = "\n")
  expect_false(grepl("\\item{c}", alkuperainen_levylla, fixed = TRUE))
})

test_that("sd_update_roxygen() välittää language-parametrin kehotteeseen ja system_promptiin", {
  skip_if_not_installed("ellmer")
  tmpdir <- tempfile("sdupdatetest"); dir.create(tmpdir); dir.create(file.path(tmpdir, "R"))
  old_wd <- setwd(tmpdir)
  on.exit({ setwd(old_wd); unlink(tmpdir, recursive = TRUE) })
  writeLines(roxygen_teksti, file.path("R", "survey_data.R"), useBytes = TRUE)

  captured_system <- NULL
  testthat::local_mocked_bindings(
    chat_ollama = function(model, system = NULL) {
      captured_system <<- system
      list(chat = function(prompt) "\\item{c}{New variable C. Numeric.}")
    },
    .package = "ellmer"
  )

  x <- new_sd_data(data.frame(a = 1:5, b = 1:5, c = 1:5))
  tulos <- sd_update_roxygen(x, "survey_data", language = "en")

  expect_match(tulos$prompt, "NEW VARIABLES:", fixed = TRUE)
  expect_match(captured_system, "English", fixed = TRUE)
  expect_match(tulos$text, "\\item{c}{New variable C. Numeric.}", fixed = TRUE)
})

test_that("sd_update_roxygen() välittää language = \"sv\" kehotteeseen ja system_promptiin", {
  skip_if_not_installed("ellmer")
  tmpdir <- tempfile("sdupdatetest"); dir.create(tmpdir); dir.create(file.path(tmpdir, "R"))
  old_wd <- setwd(tmpdir)
  on.exit({ setwd(old_wd); unlink(tmpdir, recursive = TRUE) })
  writeLines(roxygen_teksti, file.path("R", "survey_data.R"), useBytes = TRUE)

  captured_system <- NULL
  testthat::local_mocked_bindings(
    chat_ollama = function(model, system = NULL) {
      captured_system <<- system
      list(chat = function(prompt) "\\item{c}{Ny variabel C. Numerisk.}")
    },
    .package = "ellmer"
  )

  x <- new_sd_data(data.frame(a = 1:5, b = 1:5, c = 1:5))
  tulos <- sd_update_roxygen(x, "survey_data", language = "sv")

  expect_match(tulos$prompt, "NYA VARIABLER:", fixed = TRUE)
  expect_match(captured_system, "svenska", fixed = TRUE)
  expect_match(tulos$text, "\\item{c}{Ny variabel C. Numerisk.}", fixed = TRUE)
})

test_that("sd_update_roxygen() ei kutsu LLM:ää kun uusia muuttujia ei ole", {
  skip_if_not_installed("ellmer")
  tmpdir <- tempfile("sdupdatetest"); dir.create(tmpdir); dir.create(file.path(tmpdir, "R"))
  old_wd <- setwd(tmpdir)
  on.exit({ setwd(old_wd); unlink(tmpdir, recursive = TRUE) })
  writeLines(roxygen_teksti, file.path("R", "survey_data.R"), useBytes = TRUE)

  kutsuttu <- FALSE
  testthat::local_mocked_bindings(
    chat_ollama = function(model, system = NULL) {
      kutsuttu <<- TRUE
      list(chat = function(prompt) "ei pitäisi kutsua")
    },
    .package = "ellmer"
  )

  x <- new_sd_data(data.frame(a = 1:5, b = 1:5))
  expect_message(tulos <- sd_update_roxygen(x, "survey_data"), "ajan tasalla")
  expect_identical(tulos$added_vars, character(0))
  expect_false(kutsuttu)
})

test_that("sd_update_roxygen() new_vars ohittaa automaattisen tunnistuksen ja varoittaa jo dokumentoiduista", {
  skip_if_not_installed("ellmer")
  tmpdir <- tempfile("sdupdatetest"); dir.create(tmpdir); dir.create(file.path(tmpdir, "R"))
  old_wd <- setwd(tmpdir)
  on.exit({ setwd(old_wd); unlink(tmpdir, recursive = TRUE) })
  writeLines(roxygen_teksti, file.path("R", "survey_data.R"), useBytes = TRUE)

  testthat::local_mocked_bindings(
    chat_ollama = function(model, system = NULL) {
      list(chat = function(prompt) "\\item{a}{Uusi kuvaus A:lle.}")
    },
    .package = "ellmer"
  )

  x <- new_sd_data(data.frame(a = 1:5, b = 1:5))
  expect_warning(
    tulos <- sd_update_roxygen(x, "survey_data", new_vars = "a"),
    "jo dokumentoiduilta"
  )
  expect_identical(tulos$added_vars, "a")
})

test_that("sd_update_roxygen() antaa virheen kun new_vars sisältää muuttujia joita ei ole datassa", {
  tmpdir <- tempfile("sdupdatetest"); dir.create(tmpdir); dir.create(file.path(tmpdir, "R"))
  old_wd <- setwd(tmpdir)
  on.exit({ setwd(old_wd); unlink(tmpdir, recursive = TRUE) })
  writeLines(roxygen_teksti, file.path("R", "survey_data.R"), useBytes = TRUE)

  x <- new_sd_data(data.frame(a = 1:5, b = 1:5))
  expect_error(
    sd_update_roxygen(x, "survey_data", new_vars = "ei_olemassa"),
    "ei löydy datasta"
  )
})

test_that("sd_update_roxygen() antaa selkeän virheen kun tiedostoa ei löydy", {
  tmpdir <- tempfile("sdupdatetest"); dir.create(tmpdir)
  old_wd <- setwd(tmpdir)
  on.exit({ setwd(old_wd); unlink(tmpdir, recursive = TRUE) })

  x <- new_sd_data(data.frame(a = 1:5))
  expect_error(sd_update_roxygen(x, "ei_olemassa"), "löydy")
})

test_that("sd_update_roxygen() antaa selkeän virheen kun new_vars annettu mutta \\describe{}-lohkoa ei ole", {
  skip_if_not_installed("ellmer")
  tmpdir <- tempfile("sdupdatetest"); dir.create(tmpdir); dir.create(file.path(tmpdir, "R"))
  old_wd <- setwd(tmpdir)
  on.exit({ setwd(old_wd); unlink(tmpdir, recursive = TRUE) })
  writeLines("#' Otsikko\n\"kasin_muokattu\"", file.path("R", "kasin_muokattu.R"))

  testthat::local_mocked_bindings(
    chat_ollama = function(model, system = NULL) {
      list(chat = function(prompt) "\\item{z}{Kuvaus Z:lle.}")
    },
    .package = "ellmer"
  )

  x <- new_sd_data(data.frame(z = 1:5))
  expect_error(sd_update_roxygen(x, "kasin_muokattu", new_vars = "z"), "describe")
})

test_that("sd_update_roxygen() kirjoittaa levylle ja ottaa varmuuskopion kun dry_run = FALSE", {
  skip_if_not_installed("ellmer")
  tmpdir <- tempfile("sdupdatetest"); dir.create(tmpdir); dir.create(file.path(tmpdir, "R"))
  old_wd <- setwd(tmpdir)
  on.exit({ setwd(old_wd); unlink(tmpdir, recursive = TRUE) })
  writeLines(roxygen_teksti, file.path("R", "survey_data.R"), useBytes = TRUE)

  testthat::local_mocked_bindings(
    chat_ollama = function(model, system = NULL) {
      list(chat = function(prompt) "\\item{c}{Uusi muuttuja C. Numeerinen.}")
    },
    .package = "ellmer"
  )

  x <- new_sd_data(data.frame(a = 1:5, b = 1:5, c = 1:5))
  tulos <- sd_update_roxygen(x, "survey_data", dry_run = FALSE)

  expect_true(file.exists(tulos$backup_file))
  expect_true(file.exists(file.path("R", "survey_data.R")))
  kirjoitettu <- paste(readLines(file.path("R", "survey_data.R"), encoding = "UTF-8"), collapse = "\n")
  expect_match(kirjoitettu, "\\item{c}{Uusi muuttuja C. Numeerinen.}", fixed = TRUE)
  varmuuskopio <- paste(readLines(tulos$backup_file, encoding = "UTF-8"), collapse = "\n")
  expect_false(grepl("\\item{c}", varmuuskopio, fixed = TRUE))

  # ja sd_check_documentation_current() vahvistaa tiedoston olevan nyt ajan tasalla
  expect_message(uudet <- sd_check_documentation_current(x, "survey_data"), "ajan tasalla")
  expect_identical(uudet, character(0))
})

test_that("print.sd_roxygen_update() toimii sekä uusilla että ilman uusia muuttujia", {
  tyhja <- structure(
    list(text = "x", added_vars = character(0), file = "x.R", backup_file = NULL,
         prompt = NULL, model = "m", backend = "ollama", chat = NULL, created = Sys.time()),
    class = "sd_roxygen_update"
  )
  expect_output(print(tyhja), "ajan tasalla")

  uusia <- structure(
    list(text = "#' teksti", added_vars = "c", file = "x.R", backup_file = NULL,
         prompt = NULL, model = "m", backend = "ollama", chat = NULL, created = Sys.time()),
    class = "sd_roxygen_update"
  )
  expect_output(print(uusia), "muuttujat", fixed = TRUE)
})
