test_that("sd_retrieve_context() palauttaa NULL kun store on NULL", {
  x <- new_sd_data(data.frame(a = 1:5), meta = list(labels = list(a = "Muuttuja A")))
  expect_null(sd_retrieve_context(x))
  expect_null(sd_retrieve_context(x, store = NULL))
})

test_that("sd_retrieve_context() vaatii sd_data- tai sd_summary-olion", {
  skip_if_not_installed("ragnar")
  store <- ragnar::ragnar_store_create(
    embed = \(x) matrix(stats::runif(10 * length(x)), nrow = length(x), ncol = 10),
    version = 1
  )
  expect_error(sd_retrieve_context(list(), store = store), "sd_data")
})

test_that("sd_retrieve_context() hakee ja muotoilee osumat sd_data-oliolle", {
  skip_if_not_installed("ragnar")
  store <- ragnar::ragnar_store_create(
    embed = \(x) matrix(stats::runif(10 * length(x)), nrow = length(x), ncol = 10),
    version = 1
  )
  ragnar::ragnar_store_insert(
    store,
    data.frame(text = "Testimateriaalia muuttujasta A.", origin = "testi.txt", hash = "1")
  )
  ragnar::ragnar_store_build_index(store)

  x <- new_sd_data(data.frame(a = 1:5), meta = list(labels = list(a = "Muuttuja A")))
  tausta <- sd_retrieve_context(x, store, top_k = 1)

  expect_type(tausta, "character")
  expect_match(tausta, "Testimateriaalia", fixed = TRUE)
  expect_match(tausta, "testi.txt", fixed = TRUE)
})

test_that("sd_retrieve_context() toimii myos sd_summary-oliolle", {
  skip_if_not_installed("ragnar")
  store <- ragnar::ragnar_store_create(
    embed = \(x) matrix(stats::runif(10 * length(x)), nrow = length(x), ncol = 10),
    version = 1
  )
  ragnar::ragnar_store_insert(
    store,
    data.frame(text = "Testimateriaalia muuttujasta A.", origin = "testi.txt", hash = "1")
  )
  ragnar::ragnar_store_build_index(store)

  x <- new_sd_data(
    data.frame(a = 1:5),
    meta = list(roles = c(a = "continuous"), labels = list(a = "Muuttuja A"))
  )
  s <- sd_summarise(x)
  tausta <- sd_retrieve_context(s, store, top_k = 1)

  expect_match(tausta, "Testimateriaalia", fixed = TRUE)
})

test_that("sd_build_prompt() ja sd_build_roxygen_prompt() lisaavat context-lohkon kun annettu", {
  x <- new_sd_data(
    data.frame(a = 1:5),
    meta = list(roles = c(a = "continuous"), labels = list(a = "Muuttuja A"))
  )
  s <- sd_summarise(x)

  kehote <- sd_build_prompt(s, context = "Tausta-aineisto tahan.")
  expect_match(kehote, "TAUSTA-AINEISTO", fixed = TRUE)
  expect_match(kehote, "Tausta-aineisto tahan.", fixed = TRUE)

  kehote_ilman <- sd_build_prompt(s)
  expect_false(grepl("TAUSTA-AINEISTO", kehote_ilman, fixed = TRUE))

  kehote_rox <- sd_build_roxygen_prompt(x, "testidata", context = "Tausta-aineisto tahan.")
  expect_match(kehote_rox, "TAUSTA-AINEISTO", fixed = TRUE)

  kehote_rox_ilman <- sd_build_roxygen_prompt(x, "testidata")
  expect_false(grepl("TAUSTA-AINEISTO", kehote_rox_ilman, fixed = TRUE))
})

test_that("sd_document() ja sd_generate_roxygen() tarkistavat syotteen store = NULL -oletuksella samoin kuin ennen", {
  expect_error(sd_document(list(), store = NULL), "sd_data")
  expect_error(sd_generate_roxygen(data.frame(a = 1), "x", store = NULL), "sd_data")
})
