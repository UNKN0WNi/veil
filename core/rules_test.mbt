///|
test "builtin rule regexes compile" {
  let pats = [
    "[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}", "[1-9][0-9]{5}(19|20)[0-9]{2}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])[0-9]{3}[0-9Xx]",
    "1[3-9][0-9]{9}", "[0-9]{16,19}", "[0-9A-HJ-NPQRTUWXY]{18}", "(AKIA|ASIA)[0-9A-Z]{16}",
    "gh[pousr]_[A-Za-z0-9]{36}", "-----BEGIN [A-Z ]*PRIVATE KEY-----", "xox[baprs]-[A-Za-z0-9\\-]{10,}",
    "https?://[A-Za-z0-9._%+\\-]+:[^@[:space:]]+@[A-Za-z0-9.\\-]+", "[[:digit:]]{1,3}\\.[[:digit:]]{1,3}\\.[[:digit:]]{1,3}\\.[[:digit:]]{1,3}",
  ]
  for p in pats {
    try {
      let _ = @string.Regex(p)
    } catch {
      e => fail("regex failed: " + p + " -> \{e}")
    }
  }
}
