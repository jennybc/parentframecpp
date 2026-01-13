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

#' Test parent.frame() via C++ (attempted fix using Rf_eval)
#' @export
via_cpp_fixed <- function() {
  I_am_via_cpp_fixed <- TRUE
  call_report_from_cpp_fixed(environment())
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
  path <- call_cleanup_from_cpp()
  cat("File exists after helper via C++:", file.exists(path), "\n")
  path
}

#' Test withr::defer() via C++ (fixed using Rf_eval)
#' @export
via_cpp_cleanup_fixed <- function() {
  I_am_via_cpp_cleanup_fixed <- TRUE
  path <- call_cleanup_from_cpp_fixed(environment())
  cat("File exists after helper via C++ (fixed):", file.exists(path), "\n")
  path
}

# Helper that throws an error, attributed to its caller
helper_that_errors <- function(x, call = rlang::caller_env()) {
  rlang::abort(
    "`x` must be positive.",
    call = call
  )
}

#' Test rlang::abort() error attribution via pure R
#' @param x A number
#' @export
via_r_error <- function(x = -1) {
  I_am_via_r_error <- TRUE
  helper_that_errors(x)
  invisible(x)
}

#' Test rlang::abort() error attribution via C++
#' @param x A number
#' @export
via_cpp_error <- function(x = -1) {
  I_am_via_cpp_error <- TRUE
  call_error_from_cpp(x)
  invisible(x)
}

#' Test rlang::abort() error attribution via C++ (fixed using Rf_eval)
#' @param x A number
#' @export
via_cpp_error_fixed <- function(x = -1) {
  I_am_via_cpp_error_fixed <- TRUE
  call_error_from_cpp_fixed(x, environment())
  invisible(x)
}
