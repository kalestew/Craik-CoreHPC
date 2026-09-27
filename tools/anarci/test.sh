#!/bin/sh
# ANARCI self-test: it numbers, in more than one scheme, and the schemes differ.
# Run:  chpc-tool test anarci              (CPU; no GPU, no weights, ~10 s)
#
# WHY AN IMPORT PROVES NOTHING HERE. ANARCI numbers by writing a FASTA to a
# temporary file and shelling out to the `hmmscan` BINARY against a 128-column
# IMGT profile set that must have been PRESSED with hmmpress. None of that is
# touched by `import anarci`: the module imports cleanly with no hmmscan on
# PATH and no profiles on disk, and then every call raises
# FileNotFoundError: 'hmmscan' or fails inside HMMER. The PyPI package is
# exactly this shape -- it bundles the profiles and declares no HMMER
# dependency at all -- so "it imports" is the single least informative thing
# that can be said about an ANARCI installation.
set -eu

# The 12e8 heavy chain, from upstream's own README, and the sequence bioconda's
# recipe tests with. Using upstream's example means the expected numbering is
# not something invented here.
H="EVQLQQSGAEVVRSGASVKLSCTASGFNIKDYYIHWVKQRPEKGLEWIGWIDPEIGDTEYVPKFQGKATMTADTSSNTAYLQLSSLTSEDTAVYYCNAGHDYDRGRFPYWGQGTLVTVSA"

if ! "$CHPC_TOOL" exec anarci -- python - "$H" > num.log 2>&1 <<'PY'
import sys
from anarci import number, run_anarci

seq = sys.argv[1]

# --- 1: IMGT, with its conserved anchors ------------------------------------
# IMGT is a fixed 128-position frame, and four of those positions are anchors
# the scheme is DEFINED by: 23 1st-CYS, 41 CONSERVED-TRP, 104 2nd-CYS,
# 118 J-TRP. Asserting the anchors is asserting that the alignment landed where
# the scheme says, which is the whole job. A tool that returned a plausible
# list of 128 pairs with the anchors in the wrong place would be useless and
# would pass any length check.
numbering, chain_type = number(seq, scheme="imgt")
assert chain_type == "H", ("chain type", chain_type)
assert len(numbering) == 128, ("IMGT is 128 positions wide, got", len(numbering))
d = dict(numbering)
for pos, aa in ((23, "C"), (41, "W"), (104, "C"), (118, "W")):
    got = d[(pos, " ")]
    assert got == aa, ("IMGT position %d should be %s, got %r" % (pos, aa, got))
print("imgt     128 positions, chain H, anchors 23C 41W 104C 118W")

# --- 2: the gaps are real ---------------------------------------------------
# A 119-residue sequence in a 128-wide frame must be padded, and the padding is
# information: it is where the CDR lengths differ from the germline frame. If
# nothing is gapped, the frame was not applied.
gaps = sum(1 for _, aa in numbering if aa == "-")
assert gaps > 0, "no gap positions in a 128-wide frame over a 119-residue chain"
residues = "".join(aa for _, aa in numbering if aa != "-")
assert residues in seq, "the numbered residues are not a subsequence of the input"
print("imgt     %d gap positions; numbered residues are a subsequence of the input" % gaps)

# --- 3: a DIFFERENT scheme must give a DIFFERENT answer ----------------------
# This is the assertion a constant or a cached answer cannot satisfy. IMGT and
# Kabat genuinely disagree about where the CDRs start and how insertions are
# lettered, so the two position lists must not be identical. A wrapper that
# ignored `scheme=` would pass every check above.
kab, kab_type = number(seq, scheme="kabat")
assert kab_type == "H", kab_type
imgt_positions = [p for p, aa in numbering if aa != "-"]
kabat_positions = [p for p, aa in kab if aa != "-"]
assert imgt_positions != kabat_positions, (
    "imgt and kabat returned identical position lists -- the scheme argument "
    "is being ignored")
print("kabat    differs from imgt, as it must")

# --- 4: it identifies the germline, which needs the profile set --------------
# run_anarci returns the hmmscan hit details. Reaching them proves the PRESSED
# profiles were actually searched, rather than a bundled shortcut being taken.
_, numbered, details, _ = run_anarci([("12e8H", seq)], scheme="imgt")
det = details[0][0]
assert det["chain_type"] == "H", det
assert det["species"], ("no species assigned", det)
assert float(det["bitscore"]) > 50, ("hmmscan bitscore too low", det.get("bitscore"))
print("hmmscan  species=%s bitscore=%s evalue=%s"
      % (det["species"], det["bitscore"], det.get("evalue")))

# --- 5: a non-antibody sequence must be REFUSED ------------------------------
# The other half of "it discriminates": a tool that numbered anything handed to
# it would be worse than no tool, because it would put IMGT positions on a
# lysozyme and nothing downstream would know.
#
# IT RETURNS False, NOT None. Measured 2026-09-26 against anarci 2024.05.21 --
# an earlier version of this assertion tested `res is None` and failed against a
# perfectly good installation. That distinction is not cosmetic: a caller
# written as `if numbering is None: skip` treats a REFUSAL as a successful
# numbering and carries `False` forward into whatever consumes it. Test
# falsiness, which is what a caller has to do anyway.
junk = "MKTAYIAKQRQISFVKSHFSRQLEERLGLIEVQAPILSRVGDGTQDNLSGAEKAVQVKVKALPDAQFEVVHSLAKWKR"
res, ct = number(junk, scheme="imgt")
assert not res, ("a non-antibody sequence was numbered anyway: %r" % (res,))
assert res is False, (
    "expected False for a non-antibody sequence, got %r. The value matters: "
    "callers testing `is None` would mistake a refusal for a result." % (res,))
print("refusal  a non-antibody sequence returns False (NOT None), as it should")
PY
then
    echo "anarci numbering failed:" >&2
    tail -30 num.log >&2
    echo >&2
    echo "FileNotFoundError: 'hmmscan' means the image has no HMMER on PATH." >&2
    echo "A HMMER error about the profile file means the IMGT profiles were" >&2
    echo "not pressed -- hmmscan needs ALL.hmm.h3f/.h3i/.h3m/.h3p, not just" >&2
    echo "ALL.hmm. chpc-tool doctor anarci checks both." >&2
    exit 1
fi
cat num.log

# The command-line entry point too, because that is what a pipeline calls and
# it takes a different path through the package than `number()` does.
printf '>12e8H\n%s\n' "$H" > h.fasta
if ! "$CHPC_TOOL" exec anarci -- ANARCI -i h.fasta --scheme imgt > cli.log 2>&1; then
    echo "the ANARCI command-line entry point failed:" >&2; tail -20 cli.log >&2; exit 1
fi
grep -q '^# 12e8H' cli.log || { echo "CLI output has no record for 12e8H:"; head -20 cli.log; exit 1; }
grep -qE '^H 23 +C' cli.log || { echo "CLI output lacks the IMGT 23 CYS anchor:"; head -30 cli.log; exit 1; }
echo "cli      ANARCI -i numbered the FASTA and printed the 23 CYS anchor"

echo
echo "ok: ANARCI numbers the 12e8 heavy chain in IMGT with its four conserved"
echo "    anchors in place, gives a different frame for kabat, reports an"
echo "    hmmscan species and bitscore (so the pressed profiles were really"
echo "    searched), refuses a non-antibody sequence, and works from the CLI."
