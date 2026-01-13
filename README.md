
<!-- README.md is generated from README.Rmd. Please edit that file -->

# parentframecpp

<!-- badges: start -->

<!-- badges: end -->

This package demonstrates a quirk with `parent.frame()` in R when the
call stack routes through C++.

When you have a function signature like
`foo <- function(..., envir = parent.frame())` and call it through a C++
intermediate (R → C++ → R), `parent.frame()` resolves to `globalenv()`
instead of the expected parent frame. This happens because invoking an R
function from C++ doesn’t create an R evaluation frame.

This messes up things like `withr::defer()` cleanup and error messaging.

## Installation

You can install the development version of parentframecpp like so:

``` r
pak::pak("jennybc/parentframecpp")
```

## The demo

``` r
library(parentframecpp)
```

The key player is `report_parent()`, an unexported helper function,
which captures its `parent.frame()` as a default argument.

``` r
parentframecpp:::report_parent
#> function (envir = parent.frame()) 
#> {
#>     force(envir)
#>     cat("envir contents:", paste(ls(envir), collapse = ", "), 
#>         "\n")
#>     cat("Is globalenv?:", identical(envir, globalenv()), "\n")
#> }
#> <bytecode: 0x1086178d0>
#> <environment: namespace:parentframecpp>
```

We call `report_parent()` from two wrapper functions that each create a
local sentinel variable, then call `report_parent()`. The difference is
*how* they call it.

``` r
via_r
#> function () 
#> {
#>     I_am_via_r <- TRUE
#>     report_parent()
#> }
#> <bytecode: 0x10912f278>
#> <environment: namespace:parentframecpp>

via_cpp
#> function () 
#> {
#>     I_am_via_cpp <- TRUE
#>     call_report_from_cpp()
#> }
#> <bytecode: 0x1091fafe0>
#> <environment: namespace:parentframecpp>
```

The C++ intermediate (`call_report_from_cpp`) simply looks up and
invokes `report_parent()`:

``` cpp
[[cpp11::register]]
void call_report_from_cpp() {
  cpp11::function report_parent = cpp11::package("parentframecpp")["report_parent"];
  report_parent();
}
```

Now the demo:

``` r
# morally, we want:
# I_am_globalenv <- TRUE
# but because of knitr stuff, this is more reliable in the context of README.Rmd
assign("I_am_globalenv", TRUE, envir = globalenv())

via_r()
#> envir contents: I_am_via_r 
#> Is globalenv?: FALSE

via_cpp()
#> envir contents: I_am_globalenv 
#> Is globalenv?: TRUE
```

When called via pure R, `parent.frame()` correctly resolves to
`via_r()`’s environment (we see `I_am_via_r`). When routed through C++,
`parent.frame()` resolves to `globalenv()` instead of `via_cpp()`’s
environment.

## The `withr::defer()` example

Let’s explore via another angle: scheduling cleanup with
`withr::defer()`.

The helper creates a temp file and schedules its deletion in its
`parent.frame()`:

``` r
parentframecpp:::helper_with_cleanup
#> function () 
#> {
#>     tmp <- tempfile()
#>     writeLines("test", tmp)
#>     cat("Created:", tmp, "\n")
#>     withr::defer(unlink(tmp), envir = parent.frame())
#>     tmp
#> }
#> <bytecode: 0x128b29a88>
#> <environment: namespace:parentframecpp>
```

Again, two wrappers that differ only in *how* they call the helper:

``` r
via_r_cleanup
#> function () 
#> {
#>     I_am_via_r_cleanup <- TRUE
#>     path <- helper_with_cleanup()
#>     cat("File exists after helper:", file.exists(path), "\n")
#>     path
#> }
#> <bytecode: 0x1082196d8>
#> <environment: namespace:parentframecpp>

via_cpp_cleanup
#> function () 
#> {
#>     I_am_via_cpp_cleanup <- TRUE
#>     path <- call_cleanup_from_cpp()
#>     cat("File exists after helper via C++:", file.exists(path), 
#>         "\n")
#>     path
#> }
#> <bytecode: 0x108264888>
#> <environment: namespace:parentframecpp>
```

The C++ intermediate:

``` cpp
[[cpp11::register]]
cpp11::sexp call_cleanup_from_cpp() {
  cpp11::function helper = cpp11::package("parentframecpp")["helper_with_cleanup"];
  return helper();
}
```

Now the demo:

``` r
tf1 <- via_r_cleanup()
#> Created: /tmp/Rtmpa0JkWD/file7c6a56f716cf 
#> File exists after helper: TRUE
file.exists(tf1)
#> [1] FALSE

tf2 <- via_cpp_cleanup()
#> Created: /tmp/Rtmpa0JkWD/file7c6a77fa9ca3 
#> File exists after helper via C++: TRUE
file.exists(tf2)
#> [1] TRUE
```

When called via pure R, cleanup is scheduled in `via_r_cleanup()`’s
environment and runs when that function exits, i.e. the tempfile no
longer exists. When routed through C++, cleanup is scheduled in
`globalenv()` and the tempfile persists after `via_cpp_cleanup()`
returns.

## The `rlang::abort()` example

Another angle: attributing errors to the correct user-facing function
via
[`rlang::abort()`](https://rlang.r-lib.org/reference/topic-error-call.html).

The helper throws an error, using `caller_env()` to attribute it to its
caller:

``` r
parentframecpp:::helper_that_errors
#> function (x, call = rlang::caller_env()) 
#> {
#>     rlang::abort("`x` must be positive.", call = call)
#> }
#> <bytecode: 0x1094c5738>
#> <environment: namespace:parentframecpp>
```

Two wrappers that differ only in *how* they call the helper:

``` r
via_r_error
#> function (x = -1) 
#> {
#>     I_am_via_r_error <- TRUE
#>     helper_that_errors(x)
#> }
#> <bytecode: 0x109906668>
#> <environment: namespace:parentframecpp>

via_cpp_error
#> function (x = -1) 
#> {
#>     I_am_via_cpp_error <- TRUE
#>     call_error_from_cpp(x)
#> }
#> <bytecode: 0x1099f1ff8>
#> <environment: namespace:parentframecpp>
```

The C++ intermediate:

``` cpp
[[cpp11::register]]
void call_error_from_cpp(cpp11::sexp x) {
  cpp11::function helper = cpp11::package("parentframecpp")["helper_that_errors"];
  helper(x);
}
```

Now the demo:

``` r
via_r_error()
#> Error in `via_r_error()`:
#> ! `x` must be positive.

via_cpp_error()
#> Error:
#> ! `x` must be positive.
```

When called via pure R, the error correctly reports `via_r_error()` as
the source. When routed through C++, `caller_env()` resolves to
`globalenv()` and the error doesn’t mention `via_cpp_error()` at all.
