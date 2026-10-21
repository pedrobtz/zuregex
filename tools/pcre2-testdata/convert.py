# Converts PCRE2's own test results (testdata/testoutput1 and testoutput4
# of the vendored release) into tests/testthat/fixtures/pcre2-testdata.tsv.gz,
# the conformance corpus the C API is checked against (design section 9),
# and tools/pcre2-testdata/skipped.tsv, every case left out and why.
#
#   python3 -I tools/pcre2-testdata/convert.py <pcre2-release-dir>
#
# Run it from the package root after a PCRE2 update. The release directory
# is the unpacked tarball tools/vendor/manifest.tsv pins; testdata/ is not
# vendored. Bytes are written as hex, so NUL bytes and invalid UTF-8
# survive the TSV.
#
# testoutput1 is Perl-compatible tests without UTF; testoutput4 with UTF.
# A case is kept when its pattern's modifiers map onto zuregex flags and
# its subject has no pcre2test data modifiers; the expected result is the
# whole match and its groups as pcre2test printed them, or no match, or a
# compile error.

import gzip
import os
import re
import sys

ALLOWED = {"i", "m", "s", "x", "xx", "n", "utf", "ucp", "dupnames"}


def split_modifiers(mods):
    """pcre2test modifiers, with runs of single letters such as "isx" split
    into one modifier per letter."""
    out = []
    for token in (x.strip() for x in mods.split(",")):
        if not token:
            continue
        if token not in ALLOWED and re.fullmatch(r"[imnsx]+", token):
            out += list(token)
        else:
            out.append(token)
    return out


def unescape_data(s, utf):
    """pcre2test's escapes in a data line, as bytes."""
    out = bytearray()
    i = 0
    simple = {"a": 7, "b": 8, "e": 27, "f": 12, "n": 10, "r": 13, "t": 9, "v": 11}
    while i < len(s):
        c = s[i]
        if c != "\\":
            # The file was read as latin-1: this is the byte it holds.
            out += c.encode("latin-1")
            i += 1
            continue
        i += 1
        if i >= len(s):
            raise ValueError("trailing backslash")
        c = s[i]
        if c in simple:
            out.append(simple[c])
            i += 1
        elif c == "x" and i + 1 < len(s) and s[i + 1] == "{":
            j = s.index("}", i)
            v = int(s[i + 2:j], 16)
            if utf:
                out += chr(v).encode("utf-8", "surrogatepass")
            else:
                if v > 255:
                    raise ValueError("wide \\x{} without UTF")
                out.append(v)
            i = j + 1
        elif c == "x":
            m = re.match(r"[0-9A-Fa-f]{1,2}", s[i + 1:])
            v = int(m.group(0), 16) if m else 0
            out.append(v)
            i += 1 + (len(m.group(0)) if m else 0)
        elif c in "01234567":
            m = re.match(r"[0-7]{1,3}", s[i:])
            out.append(int(m.group(0), 8) & 0xFF)
            i += len(m.group(0))
        elif c == "o" and i + 1 < len(s) and s[i + 1] == "{":
            j = s.index("}", i)
            v = int(s[i + 2:j], 8)
            out += chr(v).encode("utf-8") if utf else bytes([v & 0xFF])
            i = j + 1
        elif c == "N" and s.startswith("{U+", i + 1):
            j = s.index("}", i)
            v = int(s[i + 4:j], 16)
            if not utf:
                raise ValueError("\\N{U+} without UTF")
            out += chr(v).encode("utf-8", "surrogatepass")
            i = j + 1
        elif c == "=":
            raise ValueError("data modifiers")
        else:
            out += c.encode("latin-1")
            i += 1
    return bytes(out)


def parse(path, source):
    lines = open(path, "rb").read().decode("latin-1").split("\n")
    kept, skipped = [], []
    i = 0
    pattern = None
    pattern_ok = False
    reason = ""
    flags = ""
    utf = False
    case_id = 0
    while i < len(lines):
        line = lines[i]
        if line.startswith("/"):
            # The pattern runs to the next unescaped "/", maybe over lines.
            text = line[1:]
            while True:
                m = re.search(r"(?<!\\)(?:\\\\)*/", text)
                if m:
                    break
                i += 1
                text += "\n" + lines[i]
            body = text[:m.end() - 1]
            mods = text[m.end():].strip()
            mod_list = split_modifiers(mods)
            pattern = body
            utf = "utf" in mod_list
            bad = [x for x in mod_list if x not in ALLOWED]
            pattern_ok = not bad
            reason = "modifier " + ",".join(bad) if bad else ""
            flags = "".join(x for x in mod_list if x in {"i", "m", "s", "x", "xx", "n"})
            if "ucp" in mod_list:
                flags += "u"
            if "dupnames" in mod_list:
                flags += "J"
            i += 1
            # A compile error is reported on the next line.
            if i < len(lines) and lines[i].startswith("Failed: error"):
                case_id += 1
                rec = (source, case_id, pattern, flags, utf, None, "error")
                (kept if pattern_ok else skipped).append(rec + ((reason,) if not pattern_ok else ()))
                i += 1
            continue
        if pattern is not None and line.startswith("    ") and line.strip() and not line.strip().startswith("\\="):
            subject_line = line.strip()
            # Results follow until the next data, comment or pattern line.
            results = []
            j = i + 1
            while j < len(lines) and not lines[j].startswith("    ") and not lines[j].startswith("/") \
                    and not lines[j].startswith("\\=") and lines[j].strip() != "" and not lines[j].startswith("#"):
                results.append(lines[j])
                j += 1
            i = j
            case_id += 1
            base = (source, case_id, pattern, flags, utf, subject_line)
            if not pattern_ok:
                skipped.append(base + ("-", reason))
                continue
            try:
                subj = unescape_data(subject_line, utf)
            except (ValueError, UnicodeEncodeError) as e:
                skipped.append(base + ("-", "subject: " + str(e)))
                continue
            if b"\x00" in subj:
                skipped.append(base + ("-", "subject contains NUL"))
                continue
            if len(results) == 1 and results[0] == "No match":
                kept.append((source, case_id, pattern, flags, utf, subj, "nomatch"))
                continue
            groups = {}
            ok = True
            for r in results:
                m = re.match(r"^ *(\d+): (.*)$", r)
                if not m:
                    ok = False
                    reason2 = "result line: " + r[:30]
                    break
                g = int(m.group(1))
                if g in groups:
                    ok = False  # a second match: global (/g) output
                    reason2 = "several matches"
                    break
                # pcre2test's printed text, kept as printed: a literal
                # backslash and an escape look alike, so the harness prints
                # zuregex's match the same way and compares the text.
                groups[g] = None if m.group(2) == "<unset>" else m.group(2).encode("latin-1")
            if not ok or 0 not in groups:
                skipped.append(base + ("-", reason2 if not ok else "no group 0 result"))
                continue
            top = max(groups)
            expected = [groups.get(g) for g in range(top + 1)]
            kept.append((source, case_id, pattern, flags, utf, subj, expected))
            continue
        i += 1
    return kept, skipped


class TextWriter:
    """Writes str to a binary file object as ASCII."""

    def __init__(self, raw):
        self.raw = raw

    def write(self, text):
        self.raw.write(text.encode("ascii"))


def hexs(b):
    return b.hex() if b is not None else "-"


def main():
    release = sys.argv[1]
    root = os.getcwd()
    kept, skipped = [], []
    for name in ("testoutput1", "testoutput4"):
        k, s = parse(os.path.join(release, "testdata", name), name)
        kept += k
        skipped += s
    fixtures = os.path.join(root, "tests", "testthat", "fixtures")
    os.makedirs(fixtures, exist_ok=True)
    # gzip: the corpus is 1 MB as text and 60 kB compressed. mtime=0 so the
    # file is the same bytes on every run.
    path = os.path.join(fixtures, "pcre2-testdata.tsv.gz")
    with gzip.GzipFile(path, "wb", mtime=0) as raw:
        f = TextWriter(raw)
        f.write("source\tcase\tpattern\tflags\tutf\tsubject\texpected\n")
        for source, cid, pat, flags, utf, subj, exp in kept:
            # The file was read as latin-1, so this is its bytes again.
            pat_b = pat.encode("latin-1")
            if exp == "error":
                e = "error"
            elif exp == "nomatch":
                e = "nomatch"
            else:
                e = ",".join(hexs(x) for x in exp)
            f.write(f"{source}\t{cid}\t{pat_b.hex()}\t{flags or '-'}\t{int(utf)}\t{hexs(subj) if subj is not None else '-'}\t{e}\n")
    with open(os.path.join(root, "tools", "pcre2-testdata", "skipped.tsv"), "w") as f:
        f.write("source\tcase\treason\n")
        for rec in skipped:
            f.write(f"{rec[0]}\t{rec[1]}\t{rec[-1]}\n")
    print(f"kept {len(kept)} cases, skipped {len(skipped)}")


main()
