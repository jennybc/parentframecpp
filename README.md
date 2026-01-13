
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
#> <bytecode: 0x11a2ca5d8>
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
#> <bytecode: 0x11a52df40>
#> <environment: namespace:parentframecpp>

via_cpp
#> function () 
#> {
#>     I_am_via_cpp <- TRUE
#>     call_report_from_cpp()
#> }
#> <bytecode: 0x11a5fb8f8>
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
#> <bytecode: 0x119d9e810>
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
#> <bytecode: 0x11cc9f680>
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
#> <bytecode: 0x11cce93a8>
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
#> Created: /tmp/RtmpVZtbeg/file71fb26b8365f 
#> File exists after helper: TRUE
file.exists(tf1)
#> [1] FALSE

tf2 <- via_cpp_cleanup()
#> Created: /tmp/RtmpVZtbeg/file71fb7f9aad5 
#> File exists after helper via C++: TRUE
file.exists(tf2)
#> [1] TRUE
```

When called via pure R, cleanup is scheduled in `via_r_cleanup()`’s
environment and runs when that function exits, i.e. the tempfile no
longer exists. When routed through C++, cleanup is scheduled in
`globalenv()` and the tempfile persists after `via_cpp_cleanup()`
returns.
