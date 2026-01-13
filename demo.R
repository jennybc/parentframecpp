# Demo script for parentframecpp
# Run this interactively after: devtools::load_all()

# Label globalenv so we can identify it
I_am_globalenv <- TRUE

cat("=== Testing parent.frame() via pure R ===\n")
via_r()
# Expected: parent.frame() contents: I_am_via_r
#           Is globalenv?: FALSE

cat("\n=== Testing parent.frame() via C++ ===\n")
via_cpp()
# Expected: parent.frame() contents: I_am_globalenv
#           Is globalenv?: TRUE

cat("\n=== Testing withr::defer() via pure R ===\n")
path1 <- via_r_cleanup()
cat("File exists after via_r_cleanup() returns:", file.exists(path1), "\n")
# Expected: File cleaned up (FALSE), no global deferred message

cat("\n=== Testing withr::defer() via C++ ===\n")
path2 <- via_cpp_cleanup()
cat("File exists after via_cpp_cleanup() returns:", file.exists(path2), "\n")
# Expected: "Setting global deferred event(s)" message, file still exists (TRUE)
