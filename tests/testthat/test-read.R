test_that("sd_read() antaa virheen jos tiedostoa ei löydy", {
  expect_error(sd_read("ei_ole_olemassa.csv"), "löydy")
})

test_that("sd_read() antaa virheen tuntemattomalle tiedostopäätteelle", {
  tmp <- tempfile(fileext = ".foo")
  writeLines("a,b\n1,2", tmp)
  on.exit(unlink(tmp))
  expect_error(sd_read(tmp), "ei tueta")
})

test_that("sd_read() lukee csv-tiedoston sd_data-olioksi", {
  tmp <- tempfile(fileext = ".csv")
  write.csv(data.frame(a = 1:3, b = c("x", "y", "z")), tmp, row.names = FALSE)
  on.exit(unlink(tmp))

  x <- sd_read(tmp)
  expect_true(is_sd_data(x))
  expect_equal(nrow(x$data), 3)
  expect_equal(x$meta$labels, list())
})

test_that("sd_read() lukee tsv-tiedoston", {
  tmp <- tempfile(fileext = ".tsv")
  write.table(data.frame(a = 1:3, b = c("x", "y", "z")), tmp, sep = "\t", row.names = FALSE)
  on.exit(unlink(tmp))

  x <- sd_read(tmp)
  expect_true(is_sd_data(x))
  expect_equal(nrow(x$data), 3)
})

test_that("sd_read() lukee rds-tiedoston", {
  tmp <- tempfile(fileext = ".rds")
  saveRDS(data.frame(a = 1:3), tmp)
  on.exit(unlink(tmp))

  x <- sd_read(tmp)
  expect_true(is_sd_data(x))
  expect_equal(x$data$a, 1:3)
})

test_that("sd_read() lukee xlsx-tiedoston kun readxl on asennettu", {
  skip_if_not_installed("readxl")
  skip_if_not_installed("writexl")

  tmp <- tempfile(fileext = ".xlsx")
  writexl::write_xlsx(data.frame(a = 1:3, b = c("x", "y", "z")), tmp)
  on.exit(unlink(tmp))

  x <- sd_read(tmp)
  expect_true(is_sd_data(x))
  expect_equal(nrow(x$data), 3)
})

test_that("sd_read() lukee sav-tiedoston ja poimii haven-labelit", {
  skip_if_not_installed("haven")

  tmp <- tempfile(fileext = ".sav")
  df <- data.frame(a = haven::labelled(c(1, 2, 1), c(Kylla = 1, Ei = 2)))
  attr(df$a, "label") <- "Testimuuttuja"
  haven::write_sav(df, tmp)
  on.exit(unlink(tmp))

  x <- sd_read(tmp)
  expect_true(is_sd_data(x))
  expect_equal(x$meta$labels$a, "Testimuuttuja")
  expect_equal(unname(x$meta$value_labels$a), c(1, 2))
})
