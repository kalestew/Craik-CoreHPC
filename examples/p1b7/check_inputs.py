"""Offline audit of the tutorial inputs against the bundled deposited structures.

Run with ordinary Python 3; no pip, conda environment, network or GPU needed.
This deliberately checks this fixed fixture, not arbitrary predictor inputs.
"""
import csv
import hashlib
import json
import re
from pathlib import Path

from check_output import check
from structure_io import cif_loop

ROOT = Path(__file__).resolve().parent
AA = dict(zip("ALA ARG ASN ASP CYS GLN GLU GLY HIS ILE LEU LYS MET PHE PRO SER THR TRP TYR VAL".split(),
              "ARNDCQEGHILKMFPSTWYV"))


def require(condition, message):
    if not condition:
        raise ValueError(message)


def deposited_sequences(path):
    entities = {}
    for row in cif_loop(path, "_entity_poly_seq"):
        entities.setdefault(row["entity_id"], []).append(AA[row["mon_id"]])
    return {row["id"]: "".join(entities[row["entity_id"]])
            for row in cif_loop(path, "_struct_asym") if row["entity_id"] in entities}


def fasta(path):
    records = []
    for line in path.read_text().splitlines():
        if line.startswith(">"):
            records.append([line[1:], ""])
        elif line.strip():
            require(bool(records), "sequence before FASTA header")
            records[-1][1] += line.strip()
    return records


def main():
    manifest = json.loads((ROOT / "manifest.json").read_text())
    for pdb, reference in manifest["references"].items():
        path = ROOT / "reference" / (pdb + ".cif.gz")
        require(hashlib.sha256(path.read_bytes()).hexdigest() == reference["sha256"], pdb + " reference checksum changed")
        initial = [row for row in cif_loop(path, "_pdbx_audit_revision_history")
                   if row["data_content_type"] == "Structure model" and
                   row["major_revision"] == "1" and row["minor_revision"] == "0"]
        require(len(initial) == 1 and initial[0]["revision_date"] == reference["release_date"],
                pdb + " declared release date differs from deposited revision history")
    deposited = deposited_sequences(ROOT / "reference/8UDR.cif.gz")
    expected = [(chain, deposited[chain]) for chain in "ABCDE"]
    require([len(seq) for _, seq in expected] == [275, 99, 10, 226, 213], "unexpected deposited chain lengths")
    require([(c["chain"], c["sequence"]) for c in manifest["chains"]] == expected, "manifest does not match deposited full sequences")
    require(deposited["C"] == "VVVGACGVGK", "peptide sequence changed")
    conn = [r for r in cif_loop(ROOT / "reference/8UDR.cif.gz", "_struct_conn") if r["id"] == "covale1"]
    require(len(conn) == 1, "missing deposited covalent connection")
    row = conn[0]
    require([row[k] for k in ("ptnr1_label_asym_id", "ptnr1_label_seq_id", "ptnr1_label_atom_id",
                             "ptnr2_label_asym_id", "ptnr2_label_comp_id", "ptnr2_label_atom_id")]
            == ["C", "6", "SG", "F", "MOV", "C25"], "deposited bond differs from C:Cys6:SG-F:MOV:C25")
    boltz = (ROOT / "boltz.yaml").read_text()
    require(boltz.count("  - protein:") == 5 and boltz.count("  - ligand:") == 1 and
            boltz.count("  - bond:") == 1, "Boltz must contain exactly five proteins, one ligand and one bond")
    require(re.findall(r"id: ([A-E])\s+sequence: ([A-Z]+)\s+msa: empty", boltz) == expected,
            "Boltz proteins/MSA mode differ from reference")
    require("id: F\n      ccd: MOV" in boltz and "atom1: [C, 6, SG]" in boltz and
            "atom2: [F, 1, C25]" in boltz, "Boltz ligand/bond changed")
    job, = json.loads((ROOT / "protenix.json").read_text())
    require(len(job["sequences"]) == 6, "Protenix must contain exactly six entities")
    require([(e["proteinChain"]["id"][0], e["proteinChain"]["sequence"]) for e in job["sequences"][:5]] == expected,
            "Protenix protein order differs from reference")
    require(all(next(iter(e.values()))["count"] == 1 for e in job["sequences"]), "unexpected entity copy count")
    require(job["sequences"][5] == {"ligand": {"ligand": "CCD_MOV", "count": 1, "id": ["F"]}}, "Protenix ligand changed")
    require(job["covalent_bonds"] == [{"entity1": 3, "copy1": 1, "position1": 6, "atom1": "SG",
                                      "entity2": 6, "copy2": 1, "position2": 1, "atom2": "C25"}], "Protenix bond changed")
    chai = fasta(ROOT / "chai1.fasta")
    require(chai[:5] == [["protein|name=" + c, seq] for c, seq in expected], "Chai FASTA protein order differs")
    require(chai[5:] == [["ligand|name=F", manifest["ligand"]["smiles"]]], "Chai bound-form SMILES differs")
    with (ROOT / "chai1.restraints").open() as handle:
        restraint, = list(csv.DictReader(handle))
    require([restraint[k] for k in ("chainA", "res_idxA", "chainB", "res_idxB", "connection_type")]
            == ["C", "C6@SG", "F", "@C1", "covalent"], "Chai restraint delimiter or endpoints changed")
    related = deposited_sequences(ROOT / "reference/8VRA.cif.gz")
    for query, template in (("D", "E"), ("E", "D")):
        records = fasta(ROOT / "templates" / ("protenix-" + query + ".a3m"))
        sequence = related[template]
        require(records == [["8vra_%s/1-%d protein length:%d mol:protein" % (template, len(sequence), len(sequence)), sequence]],
                "Protenix related antibody template does not match 8VRA")
        require(sequence not in deposited[query], "related template would hit the duplicate gate")
    require(fasta(ROOT / "colabfold-protein-only.fasta")[0][1] == ":".join(seq for _, seq in expected), "protein-only control differs")
    check("reference", ROOT / "reference/8UDR.cif.gz")
    print("PASS inputs: full deposited A/B/C/D/E = 275/99/10/226/213 residues; ligand F = MOV")
    print("PASS bond: peptide sequence Cys6 (KRAS author Cys12) SG -> MOV C25; Chai SMILES C1")
    print("PASS templates: 8UDR reference plus 8VRA antibody D<-E and E<-D; offline assets intact")
    print("This audit checks input identity and reference geometry, not GPU prediction accuracy.")


if __name__ == "__main__":
    try:
        main()
    except (KeyError, OSError, ValueError) as error:
        raise SystemExit("FAIL inputs: " + str(error))
