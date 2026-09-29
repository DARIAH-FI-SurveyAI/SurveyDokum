test_that("sd_build_roxygen_prompt() sisältää muuttujien tiedot ja lopetusrivin ohjeen", {
  x <- new_sd_data(
    data.frame(a = 1:5),
    meta = list(labels = list(a = "Muuttuja A"))
  )
  kehote <- sd_build_roxygen_prompt(x, "testidata")

  expect_match(kehote, "testidata", fixed = TRUE)
  expect_match(kehote, "Muuttuja A", fixed = TRUE)
  expect_match(kehote, "AINEISTON TIEDOT:", fixed = TRUE)
})

test_that("sd_build_roxygen_prompt() vaatii kelvollisen object_name-argumentin", {
  x <- new_sd_data(data.frame(a = 1:5))
  expect_error(sd_build_roxygen_prompt(x, ""), "object_name")
  expect_error(sd_build_roxygen_prompt(x, c("a", "b")), "object_name")
  expect_error(sd_build_roxygen_prompt(data.frame(a = 1), "x"), "sd_data")
})

test_that("sd_build_roxygen_prompt() tukee language-parametria (fi/en)", {
  x <- new_sd_data(
    data.frame(a = 1:5),
    meta = list(labels = list(a = "Muuttuja A"))
  )
  kehote_en <- sd_build_roxygen_prompt(x, "testidata", language = "en")

  expect_match(kehote_en, "DATASET INFORMATION:", fixed = TRUE)
  expect_match(kehote_en, "Respondents: 5", fixed = TRUE)
  expect_match(kehote_en, "VARIABLES:", fixed = TRUE)
  expect_match(kehote_en, "Muuttuja A", fixed = TRUE)  # käyttäjän oma label-teksti ei käänny
  expect_false(grepl("AINEISTON TIEDOT", kehote_en, fixed = TRUE))

  expect_error(sd_build_roxygen_prompt(x, "testidata", language = "de"), "ei vielä tueta")
})

test_that("sd_build_roxygen_prompt() tukee ruotsia (sv)", {
  x <- new_sd_data(
    data.frame(a = 1:5),
    meta = list(labels = list(a = "Muuttuja A"))
  )
  kehote_sv <- sd_build_roxygen_prompt(x, "testidata", language = "sv")

  expect_match(kehote_sv, "DATASETUPPGIFTER:", fixed = TRUE)
  expect_match(kehote_sv, "Svarande: 5", fixed = TRUE)
  expect_match(kehote_sv, "VARIABLER:", fixed = TRUE)
  expect_match(kehote_sv, "Muuttuja A", fixed = TRUE)  # käyttäjän oma label-teksti ei käänny
  expect_false(grepl("AINEISTON TIEDOT", kehote_sv, fixed = TRUE))
})

test_that("sd_roxygen_var_line_() ei kaadu kun rooleja ei ole vielä asetettu", {
  x <- new_sd_data(data.frame(a = 1:5))
  rivi <- sd_roxygen_var_line_(x, "a")
  expect_match(rivi, "ei labelia", fixed = TRUE)
})

test_that("sd_roxygen_var_line_() käyttää englanninkielisiä kenttätekstejä kun language = \"en\"", {
  x <- new_sd_data(data.frame(a = 1:5))
  rivi <- sd_roxygen_var_line_(x, "a", language = "en")
  expect_match(rivi, "(no label)", fixed = TRUE)
  expect_match(rivi, "Type:", fixed = TRUE)
  expect_false(grepl("ei labelia", rivi, fixed = TRUE))
})

test_that("sd_roxygen_var_line_() käyttää ruotsinkielisiä kenttätekstejä kun language = \"sv\"", {
  x <- new_sd_data(data.frame(a = 1:5))
  rivi <- sd_roxygen_var_line_(x, "a", language = "sv")
  expect_match(rivi, "(ingen etikett)", fixed = TRUE)
  expect_match(rivi, "Typ:", fixed = TRUE)
  expect_false(grepl("ei labelia", rivi, fixed = TRUE))
})

test_that("sd_clean_llm_code_() poistaa markdown-koodiaidat", {
  teksti <- "```r\n#' Otsikko\n\"survey_data\"\n```"
  expect_equal(sd_clean_llm_code_(teksti), "#' Otsikko\n\"survey_data\"")
})

test_that("sd_strip_empty_roxygen_tags_() poistaa vain sisällöttömät tagit", {
  seka <- "#' Otsikko\n#'\n#' @details\n#' Oikea kuvaus tassa.\n#'\n#' @source\n\"survey_data\""
  tulos <- sd_strip_empty_roxygen_tags_(seka)

  expect_match(tulos, "@details", fixed = TRUE)
  expect_match(tulos, "Oikea kuvaus", fixed = TRUE)
  expect_false(grepl("@source", tulos, fixed = TRUE))
})

test_that("sd_ensure_object_line_() lisää puuttuvan lopetusrivin eikä duplikoi valmista", {
  puuttuu <- "#' Otsikko\n#'\n#' Kuvaus."
  lisatty <- sd_ensure_object_line_(puuttuu, "survey_data")
  rivit <- strsplit(lisatty, "\n", fixed = TRUE)[[1]]
  expect_equal(trimws(rivit[length(rivit)]), '"survey_data"')

  valmis <- "#' Otsikko\n\"survey_data\""
  expect_equal(sd_ensure_object_line_(valmis, "survey_data"), valmis)
})

test_that("regressio: Marian aito bugi -- puuttuva lopetusrivi ja tyhjät tagit korjataan", {
  # Tarkalleen se teksti jonka LLM tuotti oikeassa käyttötapauksessa
  # (2026-09-05): @details ja @source jäivät tyhjiksi eikä pakollista
  # "survey_data"-lopetusriviä ollut lainkaan. Ks. arkkitehtuurimuisti,
  # työkalu-/prosessihuomio 9.
  marian_teksti <- paste0(
    "#' Survey_data\n",
    "#'\n",
    "#' Aineisto on kerätty 200 vastaajalta. ",
    "Aineisto sisältää demografisia tietoja ja vastaajien mielipiteitä.\n",
    "#'\n",
    "#' @format Dataframe, jossa 200 riviä ja 17 muuttujaa:\n",
    "#' \\describe{\n",
    "#'   \\item{vastaaja_id}{Vastaajan yksilöllinen tunnus.}\n",
    "#' }\n",
    "#'\n",
    "#' @details\n",
    "#'\n",
    "#' @source"
  )

  skip_if_not_installed("ellmer")
  testthat::local_mocked_bindings(
    chat_ollama = function(model, system = NULL) list(chat = function(prompt) marian_teksti),
    .package = "ellmer"
  )

  x <- new_sd_data(data.frame(vastaaja_id = 1:5))
  tulos <- sd_generate_roxygen(x, "survey_data")

  rivit <- strsplit(tulos$text, "\n", fixed = TRUE)[[1]]
  expect_equal(trimws(rivit[length(rivit)]), '"survey_data"')
  expect_false(grepl("@details", tulos$text, fixed = TRUE))
  expect_false(grepl("@source", tulos$text, fixed = TRUE))
})

test_that("sd_generate_roxygen() ei kirjoita levylle kun dry_run = TRUE", {
  skip_if_not_installed("ellmer")
  testthat::local_mocked_bindings(
    chat_ollama = function(model, system = NULL) list(chat = function(prompt) "#' Otsikko\n\"survey_data\""),
    .package = "ellmer"
  )

  x <- new_sd_data(data.frame(a = 1:5))
  tmpdir <- tempfile("sdroxygentest")
  dir.create(tmpdir)
  old_wd <- setwd(tmpdir)
  on.exit({ setwd(old_wd); unlink(tmpdir, recursive = TRUE) }, add = TRUE)

  tulos <- sd_generate_roxygen(x, "survey_data")
  expect_null(tulos$file)
  expect_false(file.exists(file.path("R", "survey_data.R")))
})

test_that("sd_generate_roxygen() kirjoittaa levylle ja kunnioittaa overwrite-suojaa", {
  skip_if_not_installed("ellmer")
  testthat::local_mocked_bindings(
    chat_ollama = function(model, system = NULL) list(chat = function(prompt) "#' Otsikko\n\"survey_data\""),
    .package = "ellmer"
  )

  x <- new_sd_data(data.frame(a = 1:5))
  tmp <- tempfile(fileext = ".R")
  on.exit(unlink(tmp))

  tulos <- sd_generate_roxygen(x, "survey_data", dry_run = FALSE, file = tmp)
  expect_true(file.exists(tmp))
  expect_equal(tulos$file, tmp)

  expect_error(
    sd_generate_roxygen(x, "survey_data", dry_run = FALSE, file = tmp),
    "on jo olemassa"
  )

  tulos2 <- sd_generate_roxygen(x, "survey_data", dry_run = FALSE, file = tmp, overwrite = TRUE)
  expect_true(file.exists(tulos2$file))
})

test_that("sd_generate_roxygen() välittää language-parametrin system_promptiin mokatulla LLM:llä", {
  skip_if_not_installed("ellmer")

  captured_system <- NULL
  testthat::local_mocked_bindings(
    chat_ollama = function(model, system = NULL) {
      captured_system <<- system
      list(chat = function(prompt) "#' Otsikko\n\"survey_data\"")
    },
    .package = "ellmer"
  )

  x <- new_sd_data(data.frame(a = 1:5))
  tulos <- sd_generate_roxygen(x, "survey_data", language = "en")

  expect_match(captured_system, "English", fixed = TRUE)
  expect_match(tulos$prompt, "DATASET INFORMATION:", fixed = TRUE)
})

test_that("sd_generate_roxygen() välittää language = \"sv\" system_promptiin mokatulla LLM:llä", {
  skip_if_not_installed("ellmer")

  captured_system <- NULL
  testthat::local_mocked_bindings(
    chat_ollama = function(model, system = NULL) {
      captured_system <<- system
      list(chat = function(prompt) "#' Otsikko\n\"survey_data\"")
    },
    .package = "ellmer"
  )

  x <- new_sd_data(data.frame(a = 1:5))
  tulos <- sd_generate_roxygen(x, "survey_data", language = "sv")

  expect_match(captured_system, "svenska", fixed = TRUE)
  expect_match(tulos$prompt, "DATASETUPPGIFTER:", fixed = TRUE)
})
