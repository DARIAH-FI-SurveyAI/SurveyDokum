test_that("sd_export_ddi() vaatii sd_data-olion", {
  expect_error(sd_export_ddi(data.frame(a = 1)), "sd_data")
  expect_error(sd_export_ddi(list()), "sd_data")
})

test_that("sd_export_ddi() ei ylikirjoita ilman overwrite = TRUE", {
  skip_if_not_installed("DDIwR")

  x <- new_sd_data(data.frame(a = 1:3))
  tmp <- tempfile(fileext = ".xml")
  writeLines("jo olemassa oleva tiedosto", tmp)
  on.exit(unlink(tmp))

  expect_error(sd_export_ddi(x, file = tmp), "on jo olemassa")
})

test_that("sd_export_ddi() varoittaa jos muuttujarooleja ei ole määritetty, mutta jatkaa silti", {
  skip_if_not_installed("DDIwR")

  x <- new_sd_data(data.frame(a = 1:3))
  tmp <- tempfile(fileext = ".xml")
  on.exit(unlink(tmp))

  expect_message(sd_export_ddi(x, file = tmp), "rooleja")
  expect_true(file.exists(tmp))
})

test_that("sd_export_ddi() kirjoittaa otsikon, labelit, arvolabelit ja tyypit oikein (integraatiotesti)", {
  # Käyttää OIKEAA DDIwR-pakettia (ei mokkia) -- ks. arkkitehtuurimuisti:
  # DDIwR:n rajapinta (esim. makeCategories()-syötteen muoto,
  # addChildren()/changeContent()-argumenttinimet) poikkesi useassa
  # kohdassa CRAN-dokumentaation esimerkeistä, joten yhteensopivuus voidaan
  # varmistaa vain ajamalla oikeaa asennusta vasten.
  skip_if_not_installed("DDIwR")

  df <- data.frame(
    vastaaja_id = 1:5,
    tyytyvaisyys = c(1, 2, 4, 5, 9),
    nimi = c("a", "b", "c", "d", "e"),
    stringsAsFactors = FALSE
  )
  x <- new_sd_data(
    df,
    meta = list(
      roles = c(vastaaja_id = "id", tyytyvaisyys = "likert", nimi = "text"),
      labels = list(
        vastaaja_id = "Vastaajan tunnus",
        tyytyvaisyys = "Tyytyväisyys palveluun"
      ),
      value_labels = list(
        tyytyvaisyys = c(
          "Eri mieltä" = 1, "Samaa mieltä" = 5, "En osaa sanoa" = 9
        )
      ),
      missing_codes = list(tyytyvaisyys = 9)
    )
  )

  tmp <- tempfile(fileext = ".xml")
  on.exit(unlink(tmp))

  expect_message(
    sd_export_ddi(x, file = tmp, title = "Testiaineisto"),
    "tallennettu"
  )
  expect_true(file.exists(tmp))

  xml_teksti <- paste(readLines(tmp, encoding = "UTF-8"), collapse = "\n")

  expect_true(grepl("Testiaineisto", xml_teksti, fixed = TRUE))
  expect_true(grepl("Tyytyväisyys palveluun", xml_teksti, fixed = TRUE))
  expect_true(grepl('missing="Y"', xml_teksti, fixed = TRUE))
  expect_true(grepl('type="character"', xml_teksti, fixed = TRUE))
  expect_true(grepl('type="numeric"', xml_teksti, fixed = TRUE))
  # Puuttuva koodi (9) ei saa jäädä "tavalliseksi" arvolabeliksi ilman
  # missing="Y" -merkintää -- varmistetaan että se esiintyy juuri kerran,
  # kyseisen catgry-elementin sisällä.
  expect_equal(lengths(regmatches(xml_teksti, gregexpr('missing="Y"', xml_teksti))), 1)
})

test_that("sd_export_ddi() käyttää paradata$nimeä otsikkona kun title puuttuu", {
  skip_if_not_installed("DDIwR")

  x <- new_sd_data(
    data.frame(a = 1:3),
    meta = list(paradata = list(nimi = "Paradatan otsikko"))
  )
  tmp <- tempfile(fileext = ".xml")
  on.exit(unlink(tmp))

  sd_export_ddi(x, file = tmp)
  xml_teksti <- paste(readLines(tmp, encoding = "UTF-8"), collapse = "\n")
  expect_true(grepl("Paradatan otsikko", xml_teksti, fixed = TRUE))
})

test_that("sd_export_ddi() käyttää oletusotsikkoa kun mitään ei ole annettu", {
  skip_if_not_installed("DDIwR")

  x <- new_sd_data(data.frame(a = 1:3))
  tmp <- tempfile(fileext = ".xml")
  on.exit(unlink(tmp))

  sd_export_ddi(x, file = tmp)
  xml_teksti <- paste(readLines(tmp, encoding = "UTF-8"), collapse = "\n")
  expect_true(grepl("Untitled dataset", xml_teksti, fixed = TRUE))
})

test_that("sd_export_ddi() merkitsee tekstimuuttujan character- ja jatkuvan numeric-tyyppiseksi", {
  skip_if_not_installed("DDIwR")

  df <- data.frame(
    ika = c(25, 40, 33),
    palaute = c("hyvä", "huono", "ok"),
    stringsAsFactors = FALSE
  )
  x <- new_sd_data(
    df,
    meta = list(roles = c(ika = "continuous", palaute = "text"))
  )
  tmp <- tempfile(fileext = ".xml")
  on.exit(unlink(tmp))

  sd_export_ddi(x, file = tmp)
  xml_teksti <- paste(readLines(tmp, encoding = "UTF-8"), collapse = "\n")

  ika_kohta <- sub('.*(<var name="ika">.*?</var>).*', "\\1", xml_teksti)
  palaute_kohta <- sub('.*(<var name="palaute">.*?</var>).*', "\\1", xml_teksti)

  expect_true(grepl('type="numeric"', ika_kohta, fixed = TRUE))
  expect_true(grepl('type="character"', palaute_kohta, fixed = TRUE))
})

test_that("sd_export_ddi() merkitsee date-roolin muuttujan type=\"date\"", {
  skip_if_not_installed("DDIwR")

  df <- data.frame(
    vastaaja_id = 1:3,
    syntymaaika = as.Date(c("1990-01-01", "1985-06-15", "2000-12-31")),
    stringsAsFactors = FALSE
  )
  x <- new_sd_data(
    df,
    meta = list(roles = c(vastaaja_id = "id", syntymaaika = "date"))
  )
  tmp <- tempfile(fileext = ".xml")
  on.exit(unlink(tmp))

  sd_export_ddi(x, file = tmp)
  xml_teksti <- paste(readLines(tmp, encoding = "UTF-8"), collapse = "\n")

  syntymaaika_kohta <- sub(
    '.*(<var name="syntymaaika">.*?</var>).*', "\\1", xml_teksti
  )
  expect_true(grepl('type="date"', syntymaaika_kohta, fixed = TRUE))
})

test_that("sd_export_ddi() ei luo catgry-elementtia muuttujalle jolla ei ole arvolabeleita eika puuttuvia koodeja", {
  skip_if_not_installed("DDIwR")

  df <- data.frame(ika = c(25, 30, 45))
  # Ei meta$value_labels- eika meta$missing_codes-merkintaa "ika"-muuttujalle
  # -- sd_ddi_var_():n pitaa jattaa catgry kokonaan pois eika kaatua NULL-
  # arvoihin (value_labels[[nm]] ja missing_codes[[nm]] palauttavat NULL
  # kun avainta ei loydy listasta).
  x <- new_sd_data(df, meta = list(roles = c(ika = "continuous")))
  tmp <- tempfile(fileext = ".xml")
  on.exit(unlink(tmp))

  sd_export_ddi(x, file = tmp)
  xml_teksti <- paste(readLines(tmp, encoding = "UTF-8"), collapse = "\n")

  ika_kohta <- sub('.*(<var name="ika">.*?</var>).*', "\\1", xml_teksti)
  expect_false(grepl("<catgry>", ika_kohta, fixed = TRUE))
  expect_true(grepl('type="numeric"', ika_kohta, fixed = TRUE))
})

test_that("sd_export_ddi() ei merkitse missing=\"Y\" kun arvolabelit on annettu mutta missing_codes on tyhja", {
  skip_if_not_installed("DDIwR")

  df <- data.frame(tyytyvaisyys = c(1, 2, 3, 4, 5))
  x <- new_sd_data(
    df,
    meta = list(
      value_labels = list(tyytyvaisyys = c("Huono" = 1, "Hyva" = 5))
      # missing_codes jatetaan asettamatta (oletus: list())
    )
  )
  tmp <- tempfile(fileext = ".xml")
  on.exit(unlink(tmp))

  sd_export_ddi(x, file = tmp)
  xml_teksti <- paste(readLines(tmp, encoding = "UTF-8"), collapse = "\n")

  tyytyvaisyys_kohta <- sub(
    '.*(<var name="tyytyvaisyys">.*?</var>).*', "\\1", xml_teksti
  )
  expect_true(grepl("<catgry>", tyytyvaisyys_kohta, fixed = TRUE))
  expect_false(grepl('missing="Y"', tyytyvaisyys_kohta, fixed = TRUE))
})
