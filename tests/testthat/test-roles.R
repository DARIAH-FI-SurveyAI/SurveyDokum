test_that("sd_detect_roles() tunnistaa tyypilliset roolit oikein", {
  set.seed(1)
  df <- data.frame(
    vastaaja_id = 1:20,
    paino       = runif(20, 0.5, 1.5),
    ika_luokka  = sample(c("18-29", "30-44", "45-59"), 20, replace = TRUE),
    tt1         = sample(1:5, 20, replace = TRUE),
    tulot       = rnorm(20, 3000, 800),
    pvm         = as.Date("2024-01-01") + 1:20,
    vapaateksti = paste(
      "Tämä on aika pitkä avoin vastaus numero", 1:20,
      "joka sisältää yli 30 merkkiä varmasti."
    ),
    stringsAsFactors = FALSE
  )
  x <- suppressMessages(sd_detect_roles(new_sd_data(df)))
  roles <- x$meta$roles

  expect_equal(unname(roles["vastaaja_id"]), "id")
  expect_equal(unname(roles["paino"]), "weight")
  expect_equal(unname(roles["ika_luokka"]), "nominal")
  expect_equal(unname(roles["tt1"]), "likert")
  expect_equal(unname(roles["tulot"]), "continuous")
  expect_equal(unname(roles["pvm"]), "date")
  expect_equal(unname(roles["vapaateksti"]), "text")
})

test_that("sd_detect_roles() viestittää tuloksesta ja vaatii sd_data-olion", {
  x <- new_sd_data(data.frame(a = 1:15))
  expect_message(sd_detect_roles(x), "Roolit päätelty")
  expect_error(sd_detect_roles(data.frame(a = 1)), "sd_data")
})

test_that("looginen muuttuja saa roolin nominal", {
  x <- suppressMessages(sd_detect_roles(new_sd_data(data.frame(a = c(TRUE, FALSE, TRUE)))))
  expect_equal(unname(x$meta$roles["a"]), "nominal")
})

test_that("riittävän suuri kaikki-uniikki numeerinen muuttuja tunnistetaan idksi ilman id-nimeäkin", {
  x <- suppressMessages(sd_detect_roles(new_sd_data(data.frame(jokumuu = 1:15))))
  expect_equal(unname(x$meta$roles["jokumuu"]), "id")
})

test_that("pieni näyte ei tulkitse uniikkia numeerista automaattisesti idksi", {
  x <- suppressMessages(sd_detect_roles(new_sd_data(data.frame(jokumuu = 1:5))))
  expect_false(unname(x$meta$roles["jokumuu"]) == "id")
})

test_that("sd_set_role() ylikirjoittaa yhden muuttujan roolin", {
  x <- new_sd_data(data.frame(a = 1:5), meta = list(roles = c(a = "continuous")))
  x <- sd_set_role(x, "a", "nominal")
  expect_equal(unname(x$meta$roles["a"]), "nominal")
})

test_that("sd_set_role() antaa virheen tuntemattomalle muuttujalle tai roolille", {
  x <- new_sd_data(data.frame(a = 1:5))
  expect_error(sd_set_role(x, "b", "nominal"), "löydy")
  expect_error(sd_set_role(x, "a", "vaarin"))
})

test_that("sd_set_missing() korvaa koodit NA:lla annetuille muuttujille", {
  x <- new_sd_data(data.frame(tt1 = c(1, 2, 99, 4), tt2 = c(99, 2, 3, 4)))
  x <- sd_set_missing(x, codes = 99, vars = c("tt1", "tt2"))

  expect_true(is.na(x$data$tt1[3]))
  expect_true(is.na(x$data$tt2[1]))
  expect_equal(x$meta$missing_codes$tt1, 99)
})

test_that("sd_set_missing() tukee muuttujakohtaisia koodilistoja", {
  x <- new_sd_data(data.frame(tt1 = c(1, 99), avoin = c("", "vastaus"), stringsAsFactors = FALSE))
  x <- sd_set_missing(x, codes = list(tt1 = 99, avoin = ""))

  expect_true(is.na(x$data$tt1[2]))
  expect_true(is.na(x$data$avoin[1]))
})

test_that("sd_set_missing() ilman vars-argumenttia varoittaa ja ohittaa id-muuttujat", {
  x <- new_sd_data(
    data.frame(vastaaja_id = 1:3, tt1 = c(1, 99, 3)),
    meta = list(roles = c(vastaaja_id = "id", tt1 = "likert"))
  )
  expect_warning(
    x2 <- suppressMessages(sd_set_missing(x, codes = 99)),
    "KAIKKIIN"
  )
  expect_false(any(is.na(x2$data$vastaaja_id)))
  expect_true(is.na(x2$data$tt1[2]))
})

test_that("sd_set_missing() antaa virheen tuntemattomalle muuttujalle koodilistassa", {
  x <- new_sd_data(data.frame(a = 1:3))
  expect_error(sd_set_missing(x, codes = list(b = 99)), "löydy")
})

test_that("sd_set_missing() antaa virheen nimeämättömälle koodilistalle", {
  x <- new_sd_data(data.frame(a = 1:3))
  expect_error(sd_set_missing(x, codes = list(99)), "nimi")
})
