#!/bin/sh
# DockQ v2 self-test.
# Run:  chpc-tool test dockq              (CPU; no GPU, no weights, ~30 s)
#
# NEVER RUN. tools/dockq is STATUS=planned; there is no image.
#
# A self-comparison alone proves NOTHING. `DockQ x x` returns 1.000 from a tool
# that has silently mapped every chain to itself, which is the one case where a
# broken chain mapping cannot show. So this test has four cases:
#
#   1. native vs itself            -> the perfect score
#   2. a genuinely different pose  -> NOT the perfect score, and low
#   3. renamed chains + the RIGHT --mapping  -> back to the perfect score
#   4. renamed chains + the WRONG --mapping  -> exit 0, and a plausible,
#                                               completely wrong number
#
# Case 4 is the one worth having. DockQ's --mapping is load-bearing: model
# chains and native chains are different alphabets, DockQ will search chain
# permutations and report the best it finds, and a wrong mapping does not
# error -- it returns a number. In bulk scoring that is indistinguishable from
# a result. This test asserts that behaviour explicitly so nobody has to
# rediscover it from a campaign's worth of quietly wrong scores.
#
# Two things below are UNCONFIRMED against a built image, and both are marked
# where they appear: the JSON key holding the global score, and whether the
# generated fixture makes an interface DockQ is willing to score.
set -eu

M="$TOOLDIR/../_template/make_test_pdb.sh"
[ -f "$M" ] || { echo "no fixture generator at $M"; exit 1; }

# --- the fixture -------------------------------------------------------------
# Two 40-residue mixed-topology chains, parallel, axes 7.0 A apart. Measured on
# the generated coordinates (not in DockQ): 205 heavy-atom pairs under 5 A and
# a closest approach of 3.28 A -- a real interface, and no clash. dx=8.0 gives
# only 42 contacts and dx=6.5 gives 319 with a 2.87 A closest approach; 7.0 is
# the middle of that range on purpose.
#
# Mixed topology and a cycling residue name come from the generator, and both
# matter for the same reason they matter to foldseek: a pure helix is one 3Di
# state and poly-alanine is one residue type, and a fixture that degenerate
# fails to match ITSELF -- which reads as a broken tool.
#
# The two chains have the SAME sequence on purpose. That is what makes case 4
# possible: a wrong mapping between two interchangeable chains is exactly the
# case where DockQ cannot detect the error and must return a number instead.
#
# UNCONFIRMED: that DockQ accepts this as an interface. If it reports no
# interfaces, tighten dx below 7.0 -- the contact count climbs steeply.
sh "$M" 40 A > chainA.pdb
sh "$M" 40 B | awk '/^ATOM/ { x = substr($0,31,8) + 7.0
                              printf "%s%8.3f%s\n", substr($0,1,30), x, substr($0,39); next }
                    { print }' > chainB.pdb
{ grep '^ATOM' chainA.pdb; echo TER; grep '^ATOM' chainB.pdb; echo TER; echo END; } > native.pdb

# The decoy: chain B slid 12 A along the interface axis. It still contacts
# (99 pairs under 5 A, measured on the coordinates) but the contacting RESIDUES
# are different, so fnat collapses while the structure stays perfectly
# plausible. That combination is the point -- a decoy that no longer touches
# would be scored badly by anything.
grep '^ATOM' chainB.pdb \
  | awk '{ z = substr($0,47,8) + 12.0
           printf "%s%8.3f%s\n", substr($0,1,46), z, substr($0,55) }' > chainB_slid.pdb
{ grep '^ATOM' chainA.pdb; echo TER; cat chainB_slid.pdb; echo TER; echo END; } > decoy.pdb

# The renamed model: identical coordinates, chains M and N instead of A and B.
# This is the everyday situation -- a predictor names its chains in its own
# order and the native uses whatever the depositor chose.
sed -e 's/^\(.\{21\}\)A/\1M/' -e 's/^\(.\{21\}\)B/\1N/' native.pdb > renamed.pdb

# --- score extraction --------------------------------------------------------
# UNCONFIRMED: the JSON schema. Upstream documents `--json filename.json` but
# the key holding the overall score is not quoted in its README, and the text
# report prints both a per-interface `DockQ:` and a `Total DockQ over N native
# interfaces:` line. So this reads GlobalDockQ if it is there, falls back to a
# top-level DockQ, and otherwise walks the document for the largest value under
# any key named DockQ -- and says what it found if it finds nothing. Fix it to
# the real key the first time this runs, and delete the walk.
cat > dqscore.py <<'PY'
import json, sys

def walk(o):
    found = []
    if isinstance(o, dict):
        for k, v in o.items():
            if k in ("GlobalDockQ", "DockQ") and isinstance(v, (int, float)):
                found.append(float(v))
            else:
                found += walk(v)
    elif isinstance(o, list):
        for v in o:
            found += walk(v)
    return found

d = json.load(open(sys.argv[1]))
if isinstance(d, dict) and isinstance(d.get("GlobalDockQ"), (int, float)):
    print("%.3f" % d["GlobalDockQ"])
    raise SystemExit(0)
vals = walk(d)
if not vals:
    sys.stderr.write("no DockQ value in %s -- top-level keys: %s\n"
                     % (sys.argv[1], list(d) if isinstance(d, dict) else type(d).__name__))
    raise SystemExit(1)
print("%.3f" % max(vals))
PY

# CAPRI category, derived from upstream's documented thresholds rather than
# parsed. The text report prints them as a legend; it was NOT confirmed that it
# prints a category per interface, and deriving is cheaper than depending on a
# line that may not exist.
capri() {
    awk -v s="$1" 'BEGIN { if (s + 0 >= 0.80)      print "High quality"
                           else if (s + 0 >= 0.49) print "Medium"
                           else if (s + 0 >= 0.23) print "Acceptable"
                           else                    print "Incorrect" }'
}

# Run DockQ and echo only the score. Diagnostics go to stderr so that
#   s=$(dq ...)
# cannot capture them and turn an error message into a score.
dq() {
    _m=$1; _n=$2; _lbl=$3; shift 3
    if ! "$CHPC_TOOL" exec dockq -- DockQ "$_m" "$_n" --json "dq_$_lbl.json" "$@" \
            > "dq_$_lbl.log" 2>&1
    then
        echo "DockQ exited non-zero on case '$_lbl' ($*)" >&2
        tail -30 "dq_$_lbl.log" >&2
        return 1
    fi
    if ! "$CHPC_TOOL" exec dockq -- python dqscore.py "dq_$_lbl.json"; then
        echo "could not read a score out of dq_$_lbl.json" >&2
        echo "the JSON key is UNCONFIRMED -- look at the file and fix dqscore.py" >&2
        head -40 "dq_$_lbl.log" >&2
        return 1
    fi
}

# --- case 1: the perfect score ----------------------------------------------
s_self=$(dq native.pdb native.pdb self) || exit 1
awk -v s="$s_self" 'BEGIN { exit !(s + 0 >= 0.99) }' || {
    echo "a structure scored against ITSELF gave DockQ $s_self, not 1.000."
    echo "either the fixture has no interface DockQ will score, or the chain"
    echo "mapping search failed on two identical-sequence chains. Read dq_self.log."
    tail -30 dq_self.log; exit 1; }
echo "ok: self-comparison DockQ $s_self ($(capri "$s_self"))"

# --- case 2: a genuinely different pose -------------------------------------
# This is the half a self-comparison cannot provide: proof that the score
# RESPONDS. A scorer stuck at 1.000 passes case 1 perfectly.
s_decoy=$(dq decoy.pdb native.pdb decoy) || exit 1
awk -v s="$s_decoy" 'BEGIN { exit !(s + 0 < 0.80) }' || {
    echo "a pose with the ligand chain slid 12 A scored DockQ $s_decoy, which is"
    echo "High quality. The score is not responding to the geometry -- that is"
    echo "either a broken install or a fixture whose two chains are too"
    echo "symmetric to tell apart."; exit 1; }
awk -v a="$s_self" -v b="$s_decoy" 'BEGIN { exit !(b + 0 < a + 0) }' || {
    echo "the decoy ($s_decoy) did not score below the self-comparison ($s_self)."; exit 1; }
echo "ok: 12 A-displaced decoy DockQ $s_decoy ($(capri "$s_decoy"))"

# --- case 3: renamed chains, the RIGHT mapping ------------------------------
s_map=$(dq renamed.pdb native.pdb map_right --mapping MN:AB) || exit 1
awk -v s="$s_map" 'BEGIN { exit !(s + 0 >= 0.99) }' || {
    echo "identical coordinates under --mapping MN:AB scored DockQ $s_map, not"
    echo "1.000. Either the mapping syntax is not MODELCHAINS:NATIVECHAINS in"
    echo "this version, or it is being ignored. Read dq_map_right.log."
    tail -30 dq_map_right.log; exit 1; }
echo "ok: renamed chains with --mapping MN:AB DockQ $s_map ($(capri "$s_map"))"

# --- case 4: renamed chains, the WRONG mapping ------------------------------
# The assertion here is deliberately not "it fails". It is that DockQ SUCCEEDS
# and returns a number -- because that is the actual behaviour, and it is the
# reason --mapping has to be passed explicitly by anything scoring in bulk.
#
# MN:AB is correct. NM:AB maps the model's N (which sits where native B sits)
# onto native A. Superposing on that receptor translates the model by -7 A, so
# the remaining chain lands 14 A from where native B is: the right structure,
# read through the wrong correspondence. Nothing about the input is malformed,
# the sequences align perfectly, and DockQ has no way to know.
if ! s_wrong=$(dq renamed.pdb native.pdb map_wrong --mapping NM:AB); then
    echo "DockQ ERRORED on a wrong-but-well-formed --mapping."
    echo "That is better behaviour than this registry documents, and the NOTE"
    echo "in tool.conf should be updated to say so. Read dq_map_wrong.log."
    tail -30 dq_map_wrong.log; exit 1
fi
awk -v s="$s_wrong" 'BEGIN { exit !(s + 0 < 0.80) }' || {
    echo "the WRONG mapping scored DockQ $s_wrong, which is High quality --"
    echo "so this fixture cannot demonstrate the trap. The two chains are"
    echo "related by a translation; if that translation is being absorbed by"
    echo "the superposition, make the chains distinguishable (different"
    echo "lengths) and note that a wrong mapping between DISTINGUISHABLE"
    echo "chains is the easy case, not the dangerous one."; exit 1; }
echo "ok: WRONG mapping --mapping NM:AB returned DockQ $s_wrong ($(capri "$s_wrong")) and exit 0"

echo
echo "ok: DockQ scores a complex against itself at $s_self, a displaced pose at"
echo "    $s_decoy, and the same structure read through a wrong chain mapping at"
echo "    $s_wrong -- with no error. Always pass --mapping."
