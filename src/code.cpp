#include <cpp11.hpp>

[[cpp11::register]]
void call_report_from_cpp() {
  cpp11::function report_parent = cpp11::package("parentframecpp")["report_parent"];
  report_parent();
}

[[cpp11::register]]
cpp11::sexp call_cleanup_from_cpp() {
  cpp11::function helper = cpp11::package("parentframecpp")["helper_with_cleanup"];
  return helper();
}

[[cpp11::register]]
void call_error_from_cpp(cpp11::sexp x) {
  cpp11::function helper = cpp11::package("parentframecpp")["helper_that_errors"];
  helper(x);
}
