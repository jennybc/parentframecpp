
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
#> <bytecode: 0x11a728b48>
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
#> <bytecode: 0x103b35af8>
#> <environment: namespace:parentframecpp>

via_cpp
#> function () 
#> {
#>     I_am_via_cpp <- TRUE
#>     call_report_from_cpp()
#> }
#> <bytecode: 0x103bc0dc8>
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
#> <bytecode: 0x12b11bd90>
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
#> <bytecode: 0x11a32d008>
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
#> <bytecode: 0x11a48d760>
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
#> Created: /tmp/Rtmp0uTbE9/file9c2f2a682251 
#> File exists after helper: TRUE
file.exists(tf1)
#> [1] FALSE

tf2 <- via_cpp_cleanup()
#> Created: /tmp/Rtmp0uTbE9/file9c2f1aa50997 
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
#> <bytecode: 0x12b545360>
#> <environment: namespace:parentframecpp>
```

Two wrappers that differ only in *how* they call the helper:

``` r
via_r_error
#> function (x = -1) 
#> {
#>     I_am_via_r_error <- TRUE
#>     helper_that_errors(x)
#>     invisible(x)
#> }
#> <bytecode: 0x10487e348>
#> <environment: namespace:parentframecpp>

via_cpp_error
#> function (x = -1) 
#> {
#>     I_am_via_cpp_error <- TRUE
#>     call_error_from_cpp(x)
#>     invisible(x)
#> }
#> <bytecode: 0x1199ff7c8>
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

## A fix: using `Rf_eval()` with the caller’s environment

The problem occurs because directly invoking an R function from C++ (via
`cpp11::function`) creates a “top-level” call that isn’t nested in the R
call stack.

The fix: instead of calling the function directly, construct a call
object and evaluate it *in* the caller’s environment using `Rf_eval()`.

The R wrapper passes its environment to C++:

``` r
via_cpp_fixed
#> function () 
#> {
#>     I_am_via_cpp_fixed <- TRUE
#>     call_report_from_cpp_fixed(environment())
#> }
#> <bytecode: 0x119c478f8>
#> <environment: namespace:parentframecpp>
```

The C++ code builds a call and evaluates it in that environment:

``` cpp
[[cpp11::register]]
void call_report_from_cpp_fixed(SEXP caller_env) {
  // Look up function using R's namespace API
  SEXP ns = PROTECT(R_FindNamespace(Rf_mkString("parentframecpp")));
  SEXP fn = Rf_findVarInFrame(ns, Rf_install("report_parent"));

  // Build a call: report_parent()
  SEXP call = PROTECT(Rf_lang1(fn));

  // Evaluate the call in the caller's environment
  Rf_eval(call, caller_env);

  UNPROTECT(2);
}
```

Now `parent.frame()` correctly resolves:

``` r
via_cpp_fixed()
#> envir contents: I_am_via_cpp_fixed 
#> Is globalenv?: FALSE
```

The same pattern fixes the other examples:

``` r
tf_fixed <- via_cpp_cleanup_fixed()
#> Created: /tmp/Rtmp0uTbE9/file9c2f44ece84a 
#> File exists after helper via C++ (fixed): TRUE
file.exists(tf_fixed)
#> [1] FALSE
```

``` r
via_cpp_error_fixed()
#> Error in `via_cpp_error_fixed()`:
#> ! `x` must be positive.
```
