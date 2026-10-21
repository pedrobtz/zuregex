# Records Python's re.split() and re.sub() results for
# tests/testthat/test-python.R. Run with python3 -I; the test file's
# expectations are generated from this output (see the comment there).
import re, json, sys
split_cases = [
  (r",\s*", "a, b,c", 0), (r"(\d+)", "a1b22c", 0), (r"(-)|(\+)", "1-2+3", 0),
  (r"x*", "axbc", 0), (r"", "abc", 0), (r"\b", "hi there", 0), (r"-", "a-b-c-d", 1),
  (r"-", "a-b-c-d", 2), (r"(-)", "a-b-c-d", 2), (r",", ",a,,b,", 0), (r"\s+", "  lead and trail  ", 0),
  (r"(a)|b", "xaybz", 0), (r"\d", "no digits", 0), (r"(?=b)", "abab", 0), (r"(é)", "café crème", 0),
]
sub_cases = [
  (r"x*", "-", "abc", 0), (r"a", "b", "aaa", 2), (r"(\w+)@(\w+)", r"\2 at \1", "me@host you@there", 0),
  (r"", "-", "abc", 0), (r"a|", "-", "baac", 0), (r"\d+", "#", "a1b22c333", 1),
]
out = {"split": [], "sub": []}
for pat, s, maxsplit in split_cases:
    out["split"].append({"pattern": pat, "x": s, "maxsplit": maxsplit,
                         "result": re.split(pat, s, maxsplit=maxsplit)})
for pat, repl, s, count in sub_cases:
    out["sub"].append({"pattern": pat, "repl": repl, "x": s, "count": count,
                       "result": re.sub(pat, repl, s, count=count)})
json.dump(out, sys.stdout, ensure_ascii=True, indent=1)
