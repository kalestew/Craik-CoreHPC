"""Check this six-chain tutorial's bond: python3 check_output.py TOOL MODEL.

TOOL is boltz, protenix, chai1, or reference. For a directory, every predicted
sample is checked. This checks chain composition and local bond geometry;
it does not establish that the antibody dock or the whole structure is right.
"""
import argparse
import json
import math
from pathlib import Path

from structure_io import atoms, distance

AA = dict(zip("ALA ARG ASN ASP CYS GLN GLU GLY HIS ILE LEU LYS MET PHE PRO SER THR TRP TYR VAL".split(),
              "ARNDCQEGHILKMFPSTWYV"))


def check(tool, path):
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
    # Chai appends an entity-copy suffix; the chemical atom name is C1.
    name = "C1" if tool == "chai1" else "C25"
    endpoints = [a for a in ligand if a["name"] in (name, name + "_1")]
    if len(endpoints) != 1:
        raise ValueError("expected exactly one ligand atom %s; got %d" % (name, len(endpoints)))
    endpoint, anchor = endpoints[0], anchors[0]
    if endpoint["element"] != "C":
        raise ValueError("attachment atom %s must be carbon, found %s" % (name, endpoint["element"]))
    separation = distance(anchor, endpoint)
    if not 1.40 <= separation <= 2.10:
        raise ValueError("SG-%s %.3f A is outside the tutorial's 1.40-2.10 A screening range" % (name, separation))
    close = [a for a in ligand if distance(anchor, a) <= 2.10]
    if len(close) != 1 or close[0] is not endpoint:
        raise ValueError("unexpected additional/wrong ligand contact within 2.10 A of SG")
    neighbors = [a for a in ligand if a is not endpoint and distance(a, endpoint) <= 1.85]
    if len(neighbors) != 1 or neighbors[0]["element"] != "C":
        raise ValueError("attachment atom does not have exactly one carbon heavy-atom neighbor")
    print("PASS %s: 5 protein chains + 41 ligand atoms; C:Cys6:SG-F:%s = %.3f A" % (path, name, separation))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tool", choices=("boltz", "protenix", "chai1", "reference"))
    parser.add_argument("path", type=Path)
    parser.add_argument("--expected-samples", type=int,
                        help="require this many output models (the runner requires all five)")
    args = parser.parse_args()
    patterns = {"boltz": "*_model_*.pdb", "protenix": "*_sample_*.cif", "chai1": "pred.model_idx_*.cif"}
    files = sorted(args.path.rglob(patterns[args.tool])) if args.path.is_dir() and args.tool in patterns else [args.path]
    if not files:
        parser.exit(1, "FAIL: no predicted model files found\n")
    if args.expected_samples is not None and len(files) != args.expected_samples:
        parser.exit(1, "FAIL: expected %d output models; found %d\n" % (args.expected_samples, len(files)))
    failed = 0
    for path in files:
        try:
            check(args.tool, path)
        except (KeyError, OSError, ValueError) as error:
            failed += 1
            print("FAIL %s: %s" % (path, error))
    if failed:
        parser.exit(1, "%d/%d models failed; outputs are retained for inspection.\n" % (failed, len(files)))


if __name__ == "__main__":
    main()
