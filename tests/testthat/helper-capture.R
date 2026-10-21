# Capture patterns for parity tests: each has at least one group and means
# the same in PCRE2 and ICU over the parity corpus.
capture_patterns <- function() {
  c(
    "(\\d+)",
    "(\\d{4})-(\\d{2})-(\\d{2})",
    "(\\w+)=(\\d+)",
    "([a-z])\\1",
    "(o)(\\s)?(\\w)",
    "^(\\S+)\\s+(\\S+)",
    "(é)(t)",
    "(caf)(.)",
    "(foo)(\\d+)?(bar)?",
    "([A-Z][a-z]+)([A-Z][a-z]+)?",
    "(repeat)",
    "(\\()(\\w+)(\\))"
  )
}
