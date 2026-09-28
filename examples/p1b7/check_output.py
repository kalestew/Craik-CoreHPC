"""Check this six-chain tutorial's bond: python3 check_output.py TOOL MODEL.

TOOL is boltz, protenix, chai1, intellifold, openfold3, rf3, or reference. For a
directory, every predicted sample is checked. This checks chain composition and
local bond geometry; it does not establish that the antibody dock or the whole
structure is right.

`--expect-unbonded` INVERTS the bond test: it passes when no ligand heavy atom is
within bonding distance of the anchor. That is not a way to excuse a failure. It
is for openfold3, whose `covalent_bonds` field validates and is then dropped
before the model sees it, so the apo outcome is the DOCUMENTED behaviour and
worth asserting -- a tripwire that fires the day upstream wires the field up.
See tools/openfold3/README.md, "Covalent support".
"""
import argparse
import json
import math
from pathlib import Path

from structure_io import atoms, distance

AA = dict(zip("ALA ARG ASN ASP CYS GLN GLU GLY HIS ILE LEU LYS MET PHE PRO SER THR TRP TYR VAL".split(),
              "ARNDCQEGHILKMFPSTWYV"))


def check(tool, path, expect_bond=True):
    records = atoms(path)
    if not records or any(not math.isfinite(v) for a in records for v in a["xyz"]):
        raise ValueError("missing atoms or nonfinite coordinates")
    if {a["chain"] for a in records} != set("ABCDEF"):
        raise ValueError("expected exactly chains A/B/C/D/E/F")
    manifest = json.loads((Path(__file__).resolve().parent / "manifest.json").read_text())
    sequences = {c["chain"]: c["sequence"] for c in manifest["chains"]}
    for atom in records:
        if atom["chain"] in sequences:
            sequence = sequences[atom["chain"]]
            position = int(atom["residue"])
            if not 1 <= position <= len(sequence) or AA.get(atom["comp"]) != sequence[position - 1]:
                raise ValueError("residue identity/number mismatch at %s:%s (%s)" %
                                 (atom["chain"], atom["residue"], atom["comp"]))
    lengths = {chain: len({a["residue"] for a in records
                          if a["chain"] == chain and a["name"] == "CA"})
               for chain in "ABCDE"}
    expected = dict(zip("ABCDE", [275, 99, 10, 226, 213]))
    if tool == "reference":
        expected["D"] = 217  # nine declared heavy-chain residues have no coordinates
    if lengths != expected:
        raise ValueError("CA counts %s; expected %s (check chain order/numbering)" % (lengths, expected))
    anchors = [a for a in records if a["chain"] == "C" and
               a["residue"] == "6" and a["name"] == "SG" and a["comp"] == "CYS"]
    ligand = [a for a in records if a["chain"] == "F" and a["element"] not in ("H", "D")]
    if len(anchors) != 1 or len(ligand) != 41:
        raise ValueError("expected one C:Cys6:SG and 41 ligand heavy atoms; got %d and %d" % (len(anchors), len(ligand)))
    # Chai appends an entity-copy suffix, and names a SMILES ligand's atoms by
    # element plus per-element ordinal, so its warhead carbon is C1. Everything
    # else here takes the CCD component, where it is C25.
    name = "C1" if tool == "chai1" else "C25"
    endpoints = [a for a in ligand if a["name"] in (name, name + "_1")]
    if len(endpoints) != 1:
        raise ValueError("expected exactly one ligand atom %s; got %d" % (name, len(endpoints)))
    endpoint, anchor = endpoints[0], anchors[0]
    if endpoint["element"] != "C":
        raise ValueError("attachment atom %s must be carbon, found %s" % (name, endpoint["element"]))
    separation = distance(anchor, endpoint)
    close = [a for a in ligand if distance(anchor, a) <= 2.10]
    nearest = min(ligand, key=lambda a: distance(anchor, a))

    if not expect_bond:
        # The inverted test. Anything in bonding range means the declaration was
        # honoured after all, which is good news and makes this call wrong.
        if close:
            raise ValueError(
                "expected NO bond and found %d ligand atom(s) within 2.10 A of SG "
                "(nearest %s at %.3f A). If this is openfold3, covalent_bonds has "
                "started working: drop --expect-unbonded here, in test.sh phase 2a "
                "and in tools/openfold3/README.md."
                % (len(close), nearest["name"], distance(anchor, nearest)))
        print("PASS %s: 5 protein chains + 41 ligand atoms; bond DROPPED as documented "
              "-- C:Cys6:SG-F:%s = %.3f A, nearest ligand atom %s at %.3f A"
              % (path, name, separation, nearest["name"], distance(anchor, nearest)))
        return

    if not 1.40 <= separation <= 2.10:
        raise ValueError("SG-%s %.3f A is outside the tutorial's 1.40-2.10 A screening range" % (name, separation))
    if len(close) != 1 or close[0] is not endpoint:
        raise ValueError("unexpected additional/wrong ligand contact within 2.10 A of SG")
    neighbors = [a for a in ligand if a is not endpoint and distance(a, endpoint) <= 1.85]
    if len(neighbors) != 1 or neighbors[0]["element"] != "C":
        raise ValueError("attachment atom does not have exactly one carbon heavy-atom neighbor")
    print("PASS %s: 5 protein chains + 41 ligand atoms; C:Cys6:SG-F:%s = %.3f A" % (path, name, separation))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tool", choices=("boltz", "protenix", "chai1", "intellifold",
                                        "openfold3", "rf3", "reference"))
    parser.add_argument("path", type=Path)
    parser.add_argument("--expected-samples", type=int,
                        help="require this many output models (the runner requires all five)")
    parser.add_argument("--expect-unbonded", action="store_true",
                        help="pass when NO ligand atom is within bonding distance of the "
                             "anchor. For openfold3, whose covalent_bonds field is inert; "
                             "see the module docstring.")
    args = parser.parse_args()
    patterns = {"boltz": "*_model_*.pdb", "protenix": "*_sample_*.cif",
                "chai1": "pred.model_idx_*.cif",
                # intellifold also writes a top-level copy of the draw it ranked
                # first; "sample-" keeps that copy from being counted twice.
                "intellifold": "*sample-*_model.cif",
                "openfold3": "*_sample_*_model.cif",
                # rf3 writes gzipped mmCIF and needs one_model_per_file=true: its
                # default packs every draw into one file as separate models, and
                # structure_io reads model 1 only, so four of five would go
                # unchecked while still reporting PASS.
                "rf3": "*.cif.gz"}
    files = sorted(args.path.rglob(patterns[args.tool])) if args.path.is_dir() and args.tool in patterns else [args.path]
    if not files:
        parser.exit(1, "FAIL: no predicted model files found\n")
    if args.expected_samples is not None and len(files) != args.expected_samples:
        parser.exit(1, "FAIL: expected %d output models; found %d\n" % (args.expected_samples, len(files)))
    failed = 0
    for path in files:
        try:
            check(args.tool, path, expect_bond=not args.expect_unbonded)
        except (KeyError, OSError, ValueError) as error:
            failed += 1
            print("FAIL %s: %s" % (path, error))
    if failed:
        parser.exit(1, "%d/%d models failed; outputs are retained for inspection.\n" % (failed, len(files)))


if __name__ == "__main__":
    main()
