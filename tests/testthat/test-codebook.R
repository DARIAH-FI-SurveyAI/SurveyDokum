test_that("sd_detect_scale_groups_() ryhmittelee likert-muuttujat yhteisen etuliitteen mukaan", {
  x <- new_sd_data(
    data.frame(
      vastaaja_id = 1:10,
      tt1 = 1, tt2 = 1, tt3 = 1, tt4 = 1,
      joh1 = 1, joh2 = 1, joh3 = 1,
      yksinainen = 1
    ),
    meta = list(roles = c(
      vastaaja_id = "id",
      tt1 = "likert", tt2 = "likert", tt3 = "likert", tt4 = "likert",
      joh1 = "likert", joh2 = "likert", joh3 = "likert",
      yksinainen = "likert"
    ))
  )

  ryhmat <- sd_detect_scale_groups_(x)
  expect_equal(names(ryhmat), c("tt", "joh"))
  expect_equal(ryhmat$tt, c("tt1", "tt2", "tt3", "tt4"))
  expect_false("yksinainen" %in% unlist(ryhmat))
})

test_that("sd_detect_scale_groups_() palauttaa tyhjän listan ilman likert-muuttujia tai rooleja", {
  expect_equal(sd_detect_scale_groups_(new_sd_data(data.frame(a = 1:5))), list())

  x <- new_sd_data(data.frame(a = 1:5), meta = list(roles = c(a = "continuous")))
  expect_equal(sd_detect_scale_groups_(x), list())
})

test_that("min_items ohjaa kuinka monta jäsentä ryhmä tarvitsee", {
  x <- new_sd_data(
    data.frame(a1 = 1, a2 = 1),
    meta = list(roles = c(a1 = "likert", a2 = "likert"))
  )
  expect_equal(names(sd_detect_scale_groups_(x, min_items = 1)), "a")
  # Huom: kun suodatus jättää nimetystä listasta jäljelle nolla alkiota,
  # tulos on tyhjä MUTTA edelleen nimetty lista (names = character(0)) --
  # ei täsmälleen sama rakenne kuin paljas list(). expect_length()
  # tarkistaa oikean asian (tyhjyyden) välittämättä tästä yksityiskohdasta.
  expect_length(sd_detect_scale_groups_(x, min_items = 3), 0)
})

test_that("sd_prepare_codebook_data() liittää labelit ja laskee summamuuttujat", {
  df <- data.frame(tt1 = c(1, 2, 3), tt2 = c(2, 3, 4), tt3 = c(3, 4, 5))
  x <- new_sd_data(
    df,
    meta = list(
      roles = c(tt1 = "likert", tt2 = "likert", tt3 = "likert"),
      labels = list(tt1 = "Ensimmäinen väittämä"),
      value_labels = list(tt1 = c(Eri_mielta = 1, Samaa_mielta = 5))
    )
  )

  valmis <- sd_prepare_codebook_data(x)
  expect_equal(attr(valmis$tt1, "label"), "Ensimmäinen väittämä")
  expect_equal(unname(attr(valmis$tt1, "labels")), c(1, 5))
  expect_true("tt_mean" %in% names(valmis))
  expect_equal(valmis$tt_mean[1], mean(c(1, 2, 3)))
  expect_equal(names(attr(valmis, "sd_groups")), "tt")
})

test_that("sd_prepare_codebook_data() ei täytä NA:ta summamuuttujaan (ei na.rm)", {
  df <- data.frame(tt1 = c(1, NA), tt2 = c(2, 3))
  x <- new_sd_data(df, meta = list(roles = c(tt1 = "likert", tt2 = "likert")))
  valmis <- sd_prepare_codebook_data(x)
  expect_true(is.na(valmis$tt_mean[2]))
})

test_that("groups-parametri ohittaa automaattitunnistuksen kokonaan", {
  df <- data.frame(tt1 = c(1, 2), joh1 = c(3, 4))
  x <- new_sd_data(df, meta = list(roles = c(tt1 = "likert", joh1 = "likert")))
  omat <- list(oma = c("tt1", "joh1"))

  valmis <- sd_prepare_codebook_data(x, groups = omat)
  expect_true("oma_mean" %in% names(valmis))
  expect_false("tt_mean" %in% names(valmis))
  expect_equal(attr(valmis, "sd_groups"), omat)
})

test_that("sd_prepare_codebook_data()/sd_codebook() vaativat sd_data-olion", {
  expect_error(sd_prepare_codebook_data(data.frame(a = 1)), "sd_data")
  expect_error(sd_codebook(data.frame(a = 1)), "sd_data")
})

test_that("sd_codebook() renderöi HTML-koodikirjan ja suojaa ylikirjoitukselta (hidas integraatiotesti)", {
  # Tämä testi käyttää OIKEAA codebook- ja rmarkdown-pakettia (ei mokkia) --
  # se on ainoa tapa varmistaa yhteensopivuus niiden todellisen
  # käyttäytymisen kanssa (ks. arkkitehtuurimuisti: codebook.R vaati kaksi
  # korjauskierrosta juuri siksi että sen käyttäytymistä ei voitu testata
  # etukäteen pilviympäristössä). Voi kestää kymmeniä sekunteja.
  skip_if_not_installed("codebook")
  skip_if_not_installed("rmarkdown")
  skip_on_cran()

  set.seed(3)
  x <- new_sd_data(
    data.frame(
      tt1 = sample(1:5, 15, replace = TRUE),
      tt2 = sample(1:5, 15, replace = TRUE)
    ),
    meta = list(roles = c(tt1 = "likert", tt2 = "likert"))
  )

  tmpdir <- tempfile("sdcodebooktest")
  dir.create(tmpdir)
  old_wd <- setwd(tmpdir)
  on.exit({ setwd(old_wd); unlink(tmpdir, recursive = TRUE) }, add = TRUE)

  tulos <- sd_codebook(x)
  expect_s3_class(tulos, "sd_codebook")
  expect_true(file.exists(tulos$file))
  expect_equal(names(tulos$groups), "tt")

  expect_error(sd_codebook(x), "on jo olemassa")

  tulos2 <- sd_codebook(x, overwrite = TRUE)
  expect_true(file.exists(tulos2$file))
})
