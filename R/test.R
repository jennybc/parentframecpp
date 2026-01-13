# Helper that reports its parent.frame()
report_parent <- function(envir = parent.frame()) {
  force(envir)
  cat("envir contents:", paste(ls(envir), collapse = ", "), "\n")
  cat("Is globalenv?:", identical(envir, globalenv()), "\n")
}

#' Test parent.frame() via pure R
#' @export
via_r <- function() {
  I_am_via_r <- TRUE
  report_parent()
}

#' Test parent.frame() via C++
#' @export
via_cpp <- function() {
  I_am_via_cpp <- TRUE
  call_report_from_cpp()
}

# Helper that uses withr::defer() with parent.frame()
helper_with_cleanup <- function() {
  tmp <- tempfile()
  writeLines("test", tmp)
  cat("Created:", tmp, "\n")
  withr::defer(unlink(tmp), envir = parent.frame())
  tmp
}

#' Test withr::defer() via pure R
#' @export
via_r_cleanup <- function() {
  I_am_via_r_cleanup <- TRUE
  path <- helper_with_cleanup()
  cat("File exists after helper:", file.exists(path), "\n")
  path
}

#' Test withr::defer() via C++
#' @export
via_cpp_cleanup <- function() {
  I_am_via_cpp_cleanup <- TRUE
  call_cleanup_from_cpp()
}
