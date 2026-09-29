test_that("sd_build_prompt() yhdistää ohjeet ja tilastot", {
  x <- new_sd_data(data.frame(a = 1:5), meta = list(roles = c(a = "continuous")))
  s <- sd_summarise(x)

  kehote <- sd_build_prompt(s)
  expect_type(kehote, "character")
  expect_match(kehote, "TILASTOTIEDOT:", fixed = TRUE)
  expect_match(kehote, "Käytä VAIN annettuja tilastotietoja", fixed = TRUE)
})

test_that("sd_build_prompt() sallii omat ohjeet ja vaatii sd_summary-olion", {
  x <- new_sd_data(data.frame(a = 1:5), meta = list(roles = c(a = "continuous")))
  s <- sd_summarise(x)

  kehote <- sd_build_prompt(s, instructions = "Oma ohje.")
  expect_match(kehote, "^Oma ohje\\.")
  expect_error(sd_build_prompt(list()), "sd_summary")
})

test_that("sd_build_prompt() tukee language-parametria (fi/en) ja tarkistaa sen kelvollisuuden", {
  x <- new_sd_data(data.frame(a = 1:5), meta = list(roles = c(a = "continuous")))
  s <- sd_summarise(x)

  kehote_fi <- sd_build_prompt(s)
  kehote_en <- sd_build_prompt(s, language = "en")

  expect_match(kehote_fi, "TILASTOTIEDOT:", fixed = TRUE)
  expect_match(kehote_en, "STATISTICS:", fixed = TRUE)
  expect_match(kehote_en, "Use ONLY the statistics provided", fixed = TRUE)
  expect_false(grepl("TILASTOTIEDOT", kehote_en, fixed = TRUE))

  # Omat ohjeet ohittavat kielimallipohjan, mutta otsikko riippuu silti language-arvosta
  kehote_custom_en <- sd_build_prompt(s, instructions = "My own instructions.", language = "en")
  expect_match(kehote_custom_en, "^My own instructions\\.")
  expect_match(kehote_custom_en, "STATISTICS:", fixed = TRUE)

  expect_error(sd_build_prompt(s, language = "de"), "ei vielä tueta")
  expect_error(sd_build_prompt(s, language = c("fi", "en")), "language")
})

test_that("sd_build_prompt() tukee ruotsia (sv)", {
  x <- new_sd_data(data.frame(a = 1:5), meta = list(roles = c(a = "continuous")))
  s <- sd_summarise(x)

  kehote_sv <- sd_build_prompt(s, language = "sv")

  expect_match(kehote_sv, "STATISTIK:", fixed = TRUE)
  expect_match(kehote_sv, "Använd ENDAST den statistik som ges", fixed = TRUE)
  expect_false(grepl("TILASTOTIEDOT", kehote_sv, fixed = TRUE))
  expect_false(grepl("STATISTICS:", kehote_sv, fixed = TRUE))
})

test_that("sd_document() ja sd_generate_roxygen() tarkistavat syötteen tyypin ennen LLM-kutsua", {
  expect_error(sd_document(list()), "sd_data")
  expect_error(sd_generate_roxygen(data.frame(a = 1), "x"), "sd_data")
})

test_that("sd_ollama_chat_() palauttaa tekstin onnistuneesta keskustelusta", {
  skip_if_not_installed("ellmer")

  fake_chat <- list(chat = function(prompt) paste("VASTAUS:", prompt))
  testthat::local_mocked_bindings(
    chat_ollama = function(model, system = NULL) fake_chat,
    .package = "ellmer"
  )

  tulos <- sd_ollama_chat_("kysymys", model = "testimalli")
  expect_equal(tulos$text, "VASTAUS: kysymys")
  expect_identical(tulos$chat, fake_chat)
})

test_that("sd_ollama_chat_() antaa selkeän virheen kun yhteys epäonnistuu", {
  skip_if_not_installed("ellmer")

  testthat::local_mocked_bindings(
    chat_ollama = function(model, system = NULL) stop("connection refused"),
    .package = "ellmer"
  )

  expect_error(sd_ollama_chat_("kysymys", model = "testimalli"), "Ollama on käynnissä")
})

test_that("sd_ollama_chat_() antaa selkeän virheen kun malli ei vastaa kunnolla", {
  skip_if_not_installed("ellmer")

  fake_chat <- list(chat = function(prompt) stop("model not found"))
  testthat::local_mocked_bindings(
    chat_ollama = function(model, system = NULL) fake_chat,
    .package = "ellmer"
  )

  expect_error(sd_ollama_chat_("kysymys", model = "testimalli"), "malli")
})

test_that("sd_document() tuottaa sd_documentation-olion mokatulla LLM:llä", {
  skip_if_not_installed("ellmer")

  fake_chat <- list(chat = function(prompt) "Tämä on generoitu dokumentaatio.")
  testthat::local_mocked_bindings(
    chat_ollama = function(model, system = NULL) fake_chat,
    .package = "ellmer"
  )

  x <- new_sd_data(data.frame(a = 1:5), meta = list(roles = c(a = "continuous")))
  tulos <- sd_document(x)

  expect_s3_class(tulos, "sd_documentation")
  expect_equal(tulos$text, "Tämä on generoitu dokumentaatio.")
  expect_match(tulos$prompt, "TILASTOTIEDOT:", fixed = TRUE)
})

test_that("sd_document() välittää language-parametrin kehotteeseen ja system_promptiin mokatulla LLM:llä", {
  skip_if_not_installed("ellmer")

  captured_system <- NULL
  fake_chat <- list(chat = function(prompt) prompt)  # kaiuttaa kehotteen takaisin tarkistusta varten
  testthat::local_mocked_bindings(
    chat_ollama = function(model, system = NULL) {
      captured_system <<- system
      fake_chat
    },
    .package = "ellmer"
  )

  x <- new_sd_data(data.frame(a = 1:5), meta = list(roles = c(a = "continuous")))
  tulos <- sd_document(x, language = "en")

  expect_match(tulos$prompt, "STATISTICS:", fixed = TRUE)
  expect_match(tulos$text, "STATISTICS:", fixed = TRUE)
  expect_match(captured_system, "English", fixed = TRUE)
})

test_that("sd_document() välittää language = \"sv\" kehotteeseen ja system_promptiin mokatulla LLM:llä", {
  skip_if_not_installed("ellmer")

  captured_system <- NULL
  fake_chat <- list(chat = function(prompt) prompt)  # kaiuttaa kehotteen takaisin tarkistusta varten
  testthat::local_mocked_bindings(
    chat_ollama = function(model, system = NULL) {
      captured_system <<- system
      fake_chat
    },
    .package = "ellmer"
  )

  x <- new_sd_data(data.frame(a = 1:5), meta = list(roles = c(a = "continuous")))
  tulos <- sd_document(x, language = "sv")

  expect_match(tulos$prompt, "STATISTIK:", fixed = TRUE)
  expect_match(tulos$text, "STATISTIK:", fixed = TRUE)
  expect_match(captured_system, "svenska", fixed = TRUE)
})

test_that("sd_document() kirjoittaa tuloksen tiedostoon kun save_to on annettu", {
  skip_if_not_installed("ellmer")

  fake_chat <- list(chat = function(prompt) "Kuvausteksti.")
  testthat::local_mocked_bindings(
    chat_ollama = function(model, system = NULL) fake_chat,
    .package = "ellmer"
  )

  tmp <- tempfile(fileext = ".txt")
  on.exit(unlink(tmp))
  x <- new_sd_data(data.frame(a = 1:5), meta = list(roles = c(a = "continuous")))
  sd_document(x, save_to = tmp)

  expect_true(file.exists(tmp))
  expect_equal(readLines(tmp), "Kuvausteksti.")
})

test_that("sd_check_ollama() ei kaadu vaikka Ollamaa ei löydy annetusta osoitteesta", {
  skip_on_cran()

  expect_false(isTRUE(suppressMessages(
    sd_check_ollama(model = "ei-mitaan-mallia", host = "http://localhost:1")
  )))
})
