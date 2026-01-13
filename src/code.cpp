#include <cpp11.hpp>
#include <R_ext/Parse.h>

[[cpp11::register]]
void call_report_from_cpp() {
  cpp11::function report_parent = cpp11::package("parentframecpp")["report_parent"];
  report_parent();
}

// Attempt to fix by evaluating a call in the caller's environment
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

[[cpp11::register]]
cpp11::sexp call_cleanup_from_cpp() {
  cpp11::function helper = cpp11::package("parentframecpp")["helper_with_cleanup"];
  return helper();
}

[[cpp11::register]]
SEXP call_cleanup_from_cpp_fixed(SEXP caller_env) {
  SEXP ns = PROTECT(R_FindNamespace(Rf_mkString("parentframecpp")));
  SEXP fn = Rf_findVarInFrame(ns, Rf_install("helper_with_cleanup"));

  SEXP call = PROTECT(Rf_lang1(fn));
  SEXP result = PROTECT(Rf_eval(call, caller_env));

  UNPROTECT(3);
  return result;
}

[[cpp11::register]]
void call_error_from_cpp(cpp11::sexp x) {
  cpp11::function helper = cpp11::package("parentframecpp")["helper_that_errors"];
  helper(x);
}

[[cpp11::register]]
void call_error_from_cpp_fixed(SEXP x, SEXP caller_env) {
  SEXP ns = PROTECT(R_FindNamespace(Rf_mkString("parentframecpp")));
  SEXP fn = Rf_findVarInFrame(ns, Rf_install("helper_that_errors"));

  // Build call: helper_that_errors(x)
  SEXP call = PROTECT(Rf_lang2(fn, x));
  Rf_eval(call, caller_env);

  UNPROTECT(2);
}
