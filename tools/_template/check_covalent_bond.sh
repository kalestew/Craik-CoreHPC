#!/bin/sh
# Print a python program that checks a predicted structure really carries the
# covalent bond it was asked for. Written to stdout, like make_test_pdb.sh
# writes a fixture, and for the same reason: the registry's .gitignore is an
# allow-list over tools/*/ that admits *.sh and not *.py, so a shared helper
# has to arrive as a script that emits one.
#
#   sh _template/check_covalent_bond.sh > check_bond.py
#   chpc-tool exec <tool> -- python check_bond.py model.cif
#
# Why this exists at all, rather than "the run finished, so the bond is there":
#
# HA-ADAPT's entire Chai-1 corpus -- 1,726 results -- is quarantined because
# the free drug was folded while DECLARED bonded, with the peptide cysteine
# bonded to an aromatic ring carbon at 1.68 A instead of to the warhead at
# 13.59 A. Both numbers are bond-plausible to anything that only asks "is
# something near the SG". And the confidence scores did not notice: ipTM moved
# 0.710 -> 0.698 between the wrong attachment and the right one. There is no
# inspection, no metric and no exit status that catches this. Only geometry
# does, and only if the geometry is asserted against the atom you MEANT.
#
# So this checker asserts four things, in increasing order of what they cost
# an attacker:
#   1. the anchor atom exists, exactly once
#   2. exactly ONE ligand heavy atom is within bonding distance of it
#   3. that atom is a CARBON, not the amide N or the carbonyl O
#   4. that carbon's only heavy neighbour inside the ligand is another carbon
# (4) is the one that separates a terminal Michael-acceptor CH2 from every
# other carbon in a small acrylamide: the N-methyl carbon's single neighbour is
# a nitrogen, and every internal carbon has two or more. It is connectivity,
# so it needs no atom names and survives whatever the predictor decides to call
# things.
#
# It is deliberately NOT a general validator. It assumes one polymer chain, one
# non-polymer ligand and one anchor atom, which is the shape of every covalent
# test in this registry.
cat <<'PY'
"""Assert a predicted structure carries the covalent bond that was requested.

usage: check_bond.py STRUCTURE [--anchor SG] [--min 1.2] [--max 2.1]

Reads PDB or mmCIF. Exits 0 and prints one summary line on success; exits 1
with the measurement that failed on anything else.
"""
import math
import sys

STANDARD = set("""ALA ARG ASN ASP CYS GLN GLU GLY HIS ILE LEU LYS MET PHE PRO
SER THR TRP TYR VAL MSE SEC PYL UNK HOH WAT DOD""".split())
# Nucleotides too: a "ligand" must not accidentally be an RNA residue.
STANDARD |= set("A C G U T DA DC DG DT DU N".split())
IONS = set("NA K MG CA ZN MN FE CL BR IOD CU CO NI CD HG SO4 PO4 GOL EDO".split())


def _element(name, declared):
    if declared:
        e = declared.strip().strip('"').strip("'")
        if e and e not in (".", "?"):
            return e.upper()
    # PDB atom names are column-aligned; stripping digits and taking the first
    # alphabetic character is the usual fallback and is right for C/N/O/S.
    s = "".join(ch for ch in name if ch.isalpha())
    return s[:1].upper() if s else "?"


def parse(path):
    """-> list of dicts. Handles PDB ATOM/HETATM and mmCIF _atom_site loops."""
    text = open(path, "r", errors="replace").read().splitlines()
    atoms = []

    # --- mmCIF: find the _atom_site loop and read its column order -----------
    i = 0
    while i < len(text):
        if text[i].strip().startswith("loop_"):
            j, cols = i + 1, []
            while j < len(text) and text[j].strip().startswith("_"):
                cols.append(text[j].strip())
                j += 1
            if any(c.startswith("_atom_site.") for c in cols):
                idx = {c.split(".", 1)[1]: k for k, c in enumerate(cols)}
                while j < len(text):
                    ln = text[j].strip()
                    if not ln or ln.startswith("#") or ln.startswith("loop_") or ln.startswith("_"):
                        break
                    f = ln.split()
                    if len(f) >= len(cols):
                        def g(key, default=""):
                            k = idx.get(key)
                            return f[k] if k is not None and k < len(f) else default
                        try:
                            atoms.append(dict(
                                chain=g("auth_asym_id") or g("label_asym_id"),
                                resseq=g("auth_seq_id") or g("label_seq_id"),
                                resname=(g("auth_comp_id") or g("label_comp_id")).upper(),
                                name=(g("auth_atom_id") or g("label_atom_id")).strip('"'),
                                element=_element(g("label_atom_id"), g("type_symbol")),
                                x=float(g("Cartn_x")), y=float(g("Cartn_y")), z=float(g("Cartn_z")),
                            ))
                        except ValueError:
                            pass
                    j += 1
                i = j
                continue
        i += 1
    if atoms:
        return atoms

    # --- PDB -----------------------------------------------------------------
    for ln in text:
        if ln.startswith("ATOM  ") or ln.startswith("HETATM"):
            try:
                atoms.append(dict(
                    chain=ln[21:22].strip(),
                    resseq=ln[22:26].strip(),
                    resname=ln[17:20].strip().upper(),
                    name=ln[12:16].strip(),
                    element=_element(ln[12:16], ln[76:78] if len(ln) >= 78 else ""),
                    x=float(ln[30:38]), y=float(ln[38:46]), z=float(ln[46:54]),
                ))
            except ValueError:
                pass
    return atoms


def dist(a, b):
    return math.sqrt((a["x"] - b["x"]) ** 2 + (a["y"] - b["y"]) ** 2 + (a["z"] - b["z"]) ** 2)


def die(msg):
    print("FAIL: " + msg)
    raise SystemExit(1)


def main(argv):
    if not argv:
        die("usage: check_bond.py STRUCTURE [--anchor SG] [--min 1.2] [--max 2.1]")
    path = argv[0]
    anchor_name, dmin, dmax = "SG", 1.2, 2.1
    rest = argv[1:]
    while rest:
        k = rest.pop(0)
        if k == "--anchor":
            anchor_name = rest.pop(0)
        elif k == "--min":
            dmin = float(rest.pop(0))
        elif k == "--max":
            dmax = float(rest.pop(0))
        else:
            die("unknown argument %r" % k)

    atoms = parse(path)
    if not atoms:
        die("no atoms parsed from %s -- is it a structure file?" % path)

    for a in atoms:
        for c in "xyz":
            v = a[c]
            if math.isnan(v) or math.isinf(v):
                die("non-finite coordinate on %s/%s %s" % (a["chain"], a["resseq"], a["name"]))

    anchors = [a for a in atoms if a["name"] == anchor_name and a["resname"] in STANDARD]
    if len(anchors) != 1:
        die("expected exactly one %s in the polymer, found %d. A fixture with "
            "two of them cannot prove which one was bonded." % (anchor_name, len(anchors)))
    anchor = anchors[0]

    lig = [a for a in atoms
           if a["resname"] not in STANDARD and a["resname"] not in IONS
           and a["element"] not in ("H", "D")]
    if not lig:
        die("no ligand heavy atoms: the ligand was dropped from the output "
            "entirely, which a run that 'succeeded' will not tell you. "
            "Residue names seen: %s" % sorted({a["resname"] for a in atoms}))

    # key= on the distance only: a bare sort of (float, dict) tuples falls
    # through to comparing the dicts on a tie and dies with a TypeError
    # that names neither the structure nor the bond.
    ds = sorted(((dist(anchor, a), a) for a in lig), key=lambda t: t[0])
    near = [(d, a) for d, a in ds if d <= dmax]
    d0, a0 = ds[0]
    dfar = ds[-1][0]

    if d0 > dmax:
        die("the ligand is NOT bonded: nearest ligand atom %s is %.2f A from "
            "%s (want %.2f-%.2f A), furthest %.2f A. This is the free ligand "
            "docked beside the anchor, which is exactly what HA-ADAPT's "
            "quarantined chai1 corpus contains."
            % (a0["name"], d0, anchor_name, dmin, dmax, dfar))
    if d0 < dmin:
        die("nearest ligand atom %s is %.2f A from %s -- below %.2f A that is a "
            "clash, not a bond." % (a0["name"], d0, anchor_name, dmin))
    if len(near) != 1:
        die("%d ligand atoms within %.2f A of %s (%s) -- a covalent bond is one "
            "atom to one atom; this is a fused or collapsed geometry."
            % (len(near), dmax, anchor_name,
               ", ".join("%s %.2f" % (a["name"], d) for d, a in near)))
    if a0["element"] != "C":
        die("the bond is to %s (%s, %.2f A), not to a carbon. An amide N or a "
            "carbonyl O at bonding distance is the wrong attachment wearing "
            "the right number." % (a0["name"], a0["element"], d0))

    # Connectivity: inside the ligand, a terminal warhead carbon has exactly
    # one heavy neighbour and it is a carbon. An N-methyl carbon has one
    # neighbour too -- a nitrogen. Everything internal has two or more.
    nb = [a for a in lig if a is not a0 and dist(a0, a) <= 1.75]
    if len(nb) != 1:
        die("the bonded carbon %s has %d heavy neighbours inside the ligand "
            "(%s); a terminal warhead carbon has exactly one. The bond landed "
            "on an internal atom." % (a0["name"], len(nb), ", ".join(a["name"] for a in nb)))
    if nb[0]["element"] != "C":
        die("the bonded carbon %s is a %s-methyl carbon, not the warhead: its "
            "only neighbour is %s (%s)."
            % (a0["name"], nb[0]["element"], nb[0]["name"], nb[0]["element"]))

    print("ok: %s-%s %.2f A (one contact within %.2f A; furthest ligand atom "
          "%.2f A; bonded carbon has one neighbour, %s)"
          % (anchor_name, a0["name"], d0, dmax, dfar, nb[0]["name"]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
PY
