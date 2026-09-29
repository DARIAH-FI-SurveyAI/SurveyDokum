test_that("new_sd_data() rakentaa sd_data-olion oletusmetatiedoilla", {
  df <- data.frame(a = 1:3, b = c("x", "y", "z"))
  x <- new_sd_data(df)

  expect_s3_class(x, "sd_data")
  expect_true(is_sd_data(x))
  expect_s3_class(x$data, "tbl_df")
  expect_equal(nrow(x$data), 3)
  expect_equal(x$meta$roles, character(0))
  expect_equal(x$meta$labels, list())
  expect_equal(x$meta$value_labels, list())
  expect_equal(x$meta$missing_codes, list())
  expect_equal(x$meta$paradata, list())
})

test_that("new_sd_data() yhdistää osittaisen metan oletuksiin", {
  df <- data.frame(a = 1:3)
  x <- new_sd_data(df, meta = list(labels = list(a = "Muuttuja A")))

  expect_equal(x$meta$labels, list(a = "Muuttuja A"))
  expect_equal(x$meta$roles, character(0))
})

test_that("new_sd_data() vaatii data.framen", {
  expect_error(new_sd_data(1:5))
})

test_that("is_sd_data() erottelee sd_data-oliot muista", {
  x <- new_sd_data(data.frame(a = 1))
  expect_true(is_sd_data(x))
  expect_false(is_sd_data(data.frame(a = 1)))
  expect_false(is_sd_data(list()))
})

test_that("sd_get_data() ja sd_get_meta() palauttavat oikeat osat", {
  x <- new_sd_data(data.frame(a = 1:3), meta = list(roles = c(a = "continuous")))
  expect_equal(sd_get_data(x), x$data)
  expect_equal(sd_get_meta(x), x$meta)
})

test_that("sd_get_data()/sd_get_meta() vaativat sd_data-olion", {
  expect_error(sd_get_data(data.frame(a = 1)), "sd_data")
  expect_error(sd_get_meta(list()), "sd_data")
})

test_that("print.sd_data() tulostaa perustiedot", {
  x <- new_sd_data(data.frame(a = 1:5, b = 1:5))
  expect_output(print(x), "<sd_data> 5 vastaajaa, 2 muuttujaa")
  expect_output(print(x), "Muuttujarooleja ei ole vielä määritetty")
})

test_that("print.sd_data() näyttää roolijakauman kun roolit on asetettu", {
  x <- new_sd_data(data.frame(a = 1:5, b = 1:5), meta = list(roles = c(a = "id", b = "continuous")))
  expect_output(print(x), "id = 1")
  expect_output(print(x), "continuous = 1")
})

test_that("summary.sd_data() tulostaa sekä sd_data- että data.frame-yhteenvedon", {
  x <- new_sd_data(data.frame(a = 1:5))
  expect_output(summary(x), "<sd_data>")
})

# -- sd_harvest_attr_labels_() / automaattinen label-poiminta -----------

test_that("sd_harvest_attr_labels_() poimii label- ja labels-attribuutit", {
  df <- data.frame(a = 1:3, b = c("x", "y", "z"))
  attr(df$a, "label") <- "Muuttuja A"
  attr(df$a, "labels") <- c(Eka = 1, Toka = 2)

  meta <- sd_harvest_attr_labels_(df)

  expect_equal(meta$labels$a, "Muuttuja A")
  expect_equal(unname(meta$value_labels$a), c(1, 2))
  expect_equal(names(meta$value_labels$a), c("Eka", "Toka"))
  expect_null(meta$labels$b)
  expect_null(meta$value_labels$b)
})

test_that("sd_harvest_attr_labels_() palauttaa tyhjät listat kun attribuutteja ei ole", {
  df <- data.frame(a = 1:3, b = c("x", "y", "z"))
  meta <- sd_harvest_attr_labels_(df)
  expect_equal(meta$labels, list())
  expect_equal(meta$value_labels, list())
})

test_that("new_sd_data() poimii label/labels-attribuutit automaattisesti datasta", {
  df <- data.frame(a = 1:3, b = c(1, 2, 1))
  attr(df$a, "label") <- "Muuttuja A"
  attr(df$b, "label") <- "Muuttuja B"
  attr(df$b, "labels") <- c(Kylla = 1, Ei = 2)

  x <- new_sd_data(df)

  expect_equal(x$meta$labels$a, "Muuttuja A")
  expect_equal(x$meta$labels$b, "Muuttuja B")
  expect_equal(unname(x$meta$value_labels$b), c(1, 2))
})

test_that("new_sd_data() ei poimi mitään plain data.framelle jolla ei ole attribuutteja", {
  df <- data.frame(a = 1:3, b = c("x", "y", "z"))
  x <- new_sd_data(df)
  expect_equal(x$meta$labels, list())
  expect_equal(x$meta$value_labels, list())
})

test_that("new_sd_data() antaa eksplisiittisen metan voittaa automaattisen poiminnan", {
  df <- data.frame(a = 1:3)
  attr(df$a, "label") <- "Datan oma label"

  x <- new_sd_data(df, meta = list(labels = list(a = "Käsin annettu label")))

  expect_equal(x$meta$labels$a, "Käsin annettu label")
})

test_that("new_sd_data() sallii tyhjän metan pakottamisen vaikka data kantaisi attribuutteja", {
  df <- data.frame(a = 1:3)
  attr(df$a, "label") <- "Datan oma label"

  x <- new_sd_data(df, meta = list(labels = list(), value_labels = list()))

  expect_equal(x$meta$labels, list())
  expect_equal(x$meta$value_labels, list())
})
