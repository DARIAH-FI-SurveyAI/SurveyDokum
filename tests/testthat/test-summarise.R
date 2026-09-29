test_that("sd_summarise() laskee oikeat tilastot rooleittain", {
  df <- data.frame(
    id    = 1:10,
    tt1   = c(1, 2, 3, 4, 5, 1, 2, 3, 4, 5),
    ika   = c("18-29", "30-44", "18-29", "30-44", "18-29",
              "30-44", "18-29", "30-44", "18-29", "30-44"),
    tulot = c(2000, 2500, 3000, NA, 4000, 2200, 2700, 3100, 3900, 4100),
    stringsAsFactors = FALSE
  )
  x <- new_sd_data(df, meta = list(roles = c(
    id = "id", tt1 = "likert", ika = "nominal", tulot = "continuous"
  )))
  s <- sd_summarise(x)

  expect_s3_class(s, "sd_summary")
  expect_equal(s$variables$id$role, "id")
  expect_equal(s$variables$tt1$mean, mean(df$tt1))
  expect_equal(s$variables$tulot$n_missing, 1)
  expect_equal(s$variables$tulot$mean, mean(df$tulot, na.rm = TRUE))
  expect_equal(s$variables$ika$n_categories, 2)
})

test_that("sd_summarise() päättelee puuttuvat roolit automaattisesti mutta säilyttää annetut", {
  set.seed(2)
  df <- data.frame(id = 1:12, tt1 = sample(1:5, 12, replace = TRUE))
  x <- new_sd_data(df, meta = list(roles = c(id = "id")))
  s <- suppressMessages(sd_summarise(x))

  expect_equal(s$variables$id$role, "id")
  expect_true(s$variables$tt1$role %in% c("likert", "continuous"))
})

test_that("sd_summarise() vaatii sd_data-olion", {
  expect_error(sd_summarise(data.frame(a = 1)), "sd_data")
})

test_that("tekstimuuttujan yhteenveto sisältää vain agregaatit, ei raakaa tekstiä", {
  vastaukset <- c(
    "Tämä on ensimmäinen avoin vastaus.",
    "Toinen erilainen vastaus tähän kyselyyn.",
    NA
  )
  df <- data.frame(avoin = vastaukset, stringsAsFactors = FALSE)
  x <- new_sd_data(df, meta = list(roles = c(avoin = "text")))
  s <- sd_summarise(x)

  v <- s$variables$avoin
  expect_equal(v$role, "text")
  expect_true(is.numeric(v$avg_length))
  expect_equal(v$n_unique, 2)

  teksti <- format(s)
  for (vastaus in vastaukset[!is.na(vastaukset)]) {
    expect_false(grepl(vastaus, teksti, fixed = TRUE))
  }
})

test_that("format()/print.sd_summary() tuottavat luettavan raportin", {
  x <- new_sd_data(data.frame(a = 1:5), meta = list(roles = c(a = "continuous")))
  s <- sd_summarise(x)
  expect_output(print(s), "AINEISTON TIIVISTELMÄ")
  expect_match(format(s), "Muuttujia yhteensä: 1")
})
