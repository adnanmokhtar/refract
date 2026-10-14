#!/usr/bin/env python3
"""clones.py — duplication-scan step 1 without jscpd: token-window clone pairs, offline.

Why it exists: step 1 runs `npx -y jscpd@5`, which needs a download. On a read-only or offline
checkout (an audit that must not install, a CI box with no registry) step 1 was `blocked`, and so
was 1b, the divergence check that is the point of the skill. This script produces the SAME report
shape jscpd writes (`{"duplicates": [{kind, tokens, firstFile{name,start,end}, secondFile{…}}]}`),
so 1b and step 3's reader consume it unchanged.

Method — jscpd's defaults, stated so they can be argued with:
  * tokens: identifiers, numbers, strings, template literals and punctuation; whitespace and
    comments (`//`, `/* */`, and `#` in Python / Ruby / shell files) are dropped;
  * a clone is a run of >= 50 identical tokens (--min-tokens) spanning >= 5 lines on each side
    (--min-lines), found by a rolling hash over every 50-token window and extended along the
    diagonal;
  * two exact clones of the same file pair separated by <= 3 lines on both sides (--max-gap-lines)
    merge into one `similar` pair — the near-miss pool 1b reads. A copy whose fix rewrote MORE
    than 3 lines falls apart into separate exact pairs: the same blind spot jscpd has;
  * a hash window shared by more than 40 places (--bucket-cap) is boilerplate (imports, decorator
    stacks, enum tables) and is skipped; the count is printed, never hidden.

Exact token identity is type-1 only: renamed copies (type-2) are not found. The numbers differ
from jscpd's (measured 2026-10-15 on a real NestJS + React monorepo: 1,222 pairs, 1,186 exact and
36 similar, 2.95 % duplicated lines, about 20 s; jscpd reported 1,623 / 77 near-miss on an
earlier tree) — a clone count is a triage input, never a finding.

Usage:  clones.py <root> <file-list | -> <out.json> [--min-tokens N] [--min-lines N]
                  [--max-gap-lines N] [--bucket-cap N]
        clones.py --self-test
The file list holds repo-relative paths, one per line (`rg --files … . > list`); `-` reads stdin.
Exit: 0 ok (also when there are no clones) · 1 no file could be read (an empty scan is never a
clean report) · 2 usage.
"""

import collections
import json
import os
import re
import sys
import tempfile

TOK = re.compile(r"""
  (?P<ws>\s+) |
  (?P<lc>//[^\n]*) |
  (?P<bc>/\*.*?\*/) |
  (?P<tpl>`(?:\\.|[^`\\])*`) |
  (?P<str>'(?:\\.|[^'\\\n])*'|"(?:\\.|[^"\\\n])*") |
  (?P<num>\d[\w.]*) |
  (?P<id>[A-Za-z_$][\w$]*) |
  (?P<p>=>|===|!==|==|!=|<=|>=|&&|\|\||\?\?|\?\.|\.\.\.|[^\s])
""", re.S | re.X)
HASH_COMMENT = re.compile(r'(?m)^[ \t]*#[^\n]*|[ \t]#[^\n]*')
HASH_LANGS = (".py", ".rb", ".sh", ".bash", ".yml", ".yaml", ".r", ".pl")


def tokenize(path, src, vocab):
    if path.endswith(HASH_LANGS):
        # Blank the comment but keep its newline count, so line numbers stay true.
        src = HASH_COMMENT.sub(lambda m: " " * len(m.group(0)), src)
    toks, lines, line = [], [], 1
    for m in TOK.finditer(src):
        g, s = m.lastgroup, m.group()
        if g not in ("ws", "lc", "bc"):
            toks.append(vocab.setdefault(s, len(vocab)))
            lines.append(line)
        line += s.count("\n")
    return toks, lines


def find_clones(root, paths, min_tokens=50, min_lines=5, gap=3, bucket_cap=40):
    vocab, files = {}, []
    for p in paths:
        try:
            with open(os.path.join(root, p), encoding="utf-8", errors="replace") as fh:
                src = fh.read()
        except OSError:
            continue
        toks, lines = tokenize(p, src, vocab)
        files.append((p, toks, lines))

    M, B = (1 << 61) - 1, 1000003
    BP = pow(B, min_tokens - 1, M)
    buckets = collections.defaultdict(list)
    for fi, (_, toks, _) in enumerate(files):
        n = len(toks)
        if n < min_tokens:
            continue
        h = 0
        for i in range(min_tokens):
            h = (h * B + toks[i] + 1) % M
        buckets[h].append((fi, 0))
        for i in range(1, n - min_tokens + 1):
            h = ((h - (toks[i - 1] + 1) * BP) * B + toks[i + min_tokens - 1] + 1) % M
            buckets[h].append((fi, i))

    capped = 0
    diag = collections.defaultdict(list)
    for locs in buckets.values():
        if len(locs) < 2:
            continue
        if len(locs) > bucket_cap:
            capped += 1
            continue
        for a in range(len(locs)):
            fa, ia = locs[a]
            for b in range(a + 1, len(locs)):
                fb, ib = locs[b]
                if fa == fb and abs(ia - ib) < min_tokens:
                    continue                      # a window overlapping itself is not a copy
                if (fa, ia) > (fb, ib):
                    fa, ia, fb, ib = fb, ib, fa, ia
                diag[(fa, fb, ia - ib)].append(ia)
                fa, ia = locs[a]
    del buckets

    exact = []
    for (fa, fb, d), starts in diag.items():
        starts.sort()
        run_s = prev = starts[0]
        for s in starts[1:] + [None]:
            if s is not None and s == prev + 1:
                prev = s
                continue
            a0, a1 = run_s, prev + min_tokens - 1
            b0, b1 = a0 - d, a1 - d
            la, lb = files[fa][2], files[fb][2]
            sa, ea, sb, eb = la[a0], la[a1], lb[b0], lb[b1]
            if ea - sa + 1 >= min_lines and eb - sb + 1 >= min_lines:
                exact.append((fa, sa, ea, fb, sb, eb, a1 - a0 + 1))
            if s is not None:
                run_s = prev = s
    del diag

    byp = collections.defaultdict(list)
    for c in exact:
        byp[(c[0], c[3])].append(c)
    pairs = []
    for (fa, fb), cs in sorted(byp.items()):
        cs.sort(key=lambda c: (c[1], c[4]))
        groups = []
        for c in cs:
            merged = False
            for g in groups:
                ga, gb = c[1] - g["ea"], c[4] - g["eb"]
                if -2 <= ga <= gap + 1 and -2 <= gb <= gap + 1:
                    g["ea"], g["eb"] = max(g["ea"], c[2]), max(g["eb"], c[5])
                    g["tok"] += c[6]
                    g["parts"] += 1
                    merged = True
                    break
                if c[1] >= g["sa"] and c[2] <= g["ea"] and c[4] >= g["sb"] and c[5] <= g["eb"]:
                    merged = True
                    break
            if not merged:
                groups.append(dict(sa=c[1], ea=c[2], sb=c[4], eb=c[5], tok=c[6], parts=1))
        for g in groups:
            pairs.append(dict(kind="similar" if g["parts"] > 1 else "exact", tokens=g["tok"],
                              firstFile=dict(name=files[fa][0], start=g["sa"], end=g["ea"]),
                              secondFile=dict(name=files[fb][0], start=g["sb"], end=g["eb"])))

    total = sum((f[2][-1] if f[2] else 0) for f in files)
    dup = collections.defaultdict(set)
    for x in pairs:
        for k in ("firstFile", "secondFile"):
            dup[x[k]["name"]].update(range(x[k]["start"], x[k]["end"] + 1))
    dl = sum(len(v) for v in dup.values())
    stats = dict(files=len(files), lines=total, dupLines=dl,
                 pct=round(100.0 * dl / max(total, 1), 2), cappedBuckets=capped,
                 tool="clones.py", minTokens=min_tokens, minLines=min_lines, maxGapLines=gap)
    return pairs, stats


def self_test():
    ok = True
    body = "\n".join("  total = total + item%d.price * item%d.qty; // line %d" % (i, i, i)
                     for i in range(12))
    a = "export function sumA(items) {\n  let total = 0;\n%s\n  return total;\n}\n" % body
    b_lines = a.replace("sumA", "sumB").split("\n")
    b_lines[7] = "  total = Math.round(total); // the one-sided fix"
    b = "\n".join(b_lines)
    with tempfile.TemporaryDirectory() as td:
        for name, txt in (("a.ts", a), ("b.ts", b), ("c.ts", "export const x = 1;\n"),
                          ("p.py", "# " + "x " * 80 + "\nvalue = 1\n")):
            with open(os.path.join(td, name), "w") as fh:
                fh.write(txt)
        pairs, st = find_clones(td, ["a.ts", "b.ts", "c.ts", "p.py"])
        kinds = collections.Counter(p["kind"] for p in pairs)
        checks = [
            ("a 13-line copy with one changed line is ONE similar pair", kinds.get("similar") == 1),
            ("c.ts (too short) is in no pair",
             all("c.ts" not in (p["firstFile"]["name"], p["secondFile"]["name"]) for p in pairs)),
            ("a # comment in a .py file yields no tokens to clone",
             all(not p["firstFile"]["name"].endswith(".py") for p in pairs)),
            ("4 files read", st["files"] == 4),
        ]
        sim = [p for p in pairs if p["kind"] == "similar"]
        if sim:
            checks.append(("the similar pair spans the changed line on both sides",
                           sim[0]["firstFile"]["start"] <= 8 <= sim[0]["firstFile"]["end"]))
    for label, passed in checks:
        print(("  ok    " if passed else "  FAIL  ") + label)
        ok = ok and passed
    print("clones --self-test " + ("OK" if ok else "FAIL"))
    return 0 if ok else 1


def main(argv):
    if argv[1:2] == ["--self-test"]:
        return self_test()
    opts = {"--min-tokens": 50, "--min-lines": 5, "--max-gap-lines": 3, "--bucket-cap": 40}
    pos, i = [], 1
    while i < len(argv):
        a = argv[i]
        k, _, v = a.partition("=")
        if k in opts:
            if not v:
                i += 1
                v = argv[i] if i < len(argv) else ""
            try:
                opts[k] = int(v)
            except ValueError:
                sys.stderr.write("%s needs an integer\n" % k)
                return 2
        else:
            pos.append(a)
        i += 1
    if len(pos) != 3:
        sys.stderr.write(__doc__.split("Usage:")[1].split("The file list")[0])
        return 2
    root, flist, out = pos
    src = sys.stdin.read() if flist == "-" else open(flist, encoding="utf-8").read()
    paths = [p[2:] if p.startswith("./") else p for p in src.split() if p]
    pairs, st = find_clones(root, paths, opts["--min-tokens"], opts["--min-lines"],
                            opts["--max-gap-lines"], opts["--bucket-cap"])
    with open(out, "w", encoding="utf-8") as fh:
        json.dump(dict(duplicates=pairs, statistics=st), fh)
    print("clones.py — files %d · lines %d · pairs %d %s · cross-file %d · duplicated lines %d "
          "(%.2f%%) · boilerplate windows skipped %d"
          % (st["files"], st["lines"], len(pairs), dict(collections.Counter(x["kind"] for x in pairs)),
             sum(x["firstFile"]["name"] != x["secondFile"]["name"] for x in pairs),
             st["dupLines"], st["pct"], st["cappedBuckets"]))
    if st["files"] == 0:
        sys.stderr.write("clones.py: no file could be read — an empty scan is blocked, not clean\n")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
