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
    # IntelliFold takes AlphaFold 3's dialect. entity_id is a chain LABEL; using
    # protenix's 1-based index into the entity list instead would not error and
    # would move the bond somewhere else.
    af3 = json.loads((ROOT / "intellifold.json").read_text())
    require(af3["dialect"] == "alphafold3" and af3["version"] == 1, "IntelliFold dialect/version changed")
    require(len(af3["sequences"]) == 6, "IntelliFold must contain exactly six entities")
    require([(e["protein"]["id"], e["protein"]["sequence"]) for e in af3["sequences"][:5]] == expected,
            "IntelliFold protein order differs from reference")
    require(all(e["protein"]["unpairedMsa"] == "" and e["protein"]["pairedMsa"] == ""
                and e["protein"]["templates"] == [] for e in af3["sequences"][:5]),
            "IntelliFold must stay in single-sequence mode with templates declared empty")
    require(af3["sequences"][5] == {"ligand": {"id": "F", "ccdCodes": ["MOV"]}}, "IntelliFold ligand changed")
    require(af3["bondedAtomPairs"] == [[["C", 6, "SG"], ["F", 1, "C25"]]], "IntelliFold bond changed")

    # OpenFold3 has its own schema: chains (not sequences), chain_ids a LIST,
    # molecule_type an INTEGER enum, queries a DICT keyed by name.
    #
    # covalent_bonds is declared here ON PURPOSE. The field validates and is
    # dropped before the model, so this input reproduces the trap rather than
    # avoiding it, and check_output.py --expect-unbonded asserts that outcome.
    # Its endpoints are typed (chain_id, residue_id, atom_id: INT) with no way to
    # name an atom, and nothing consumes the index, so no experiment can tell you
    # the right value -- which is why the audit below pins the SHAPE and not the
    # integers.
    of3 = json.loads((ROOT / "openfold3.json").read_text())
    query, = of3["queries"].values()
    require(len(of3["queries"]) == 1 and manifest["name"] in of3["queries"], "OpenFold3 query name changed")
    require(len(query["chains"]) == 6, "OpenFold3 must contain exactly six chains")
    require([(c["chain_ids"], c.get("sequence")) for c in query["chains"][:5]]
            == [([c], s) for c, s in expected], "OpenFold3 chain order differs from reference")
    require(all(c["molecule_type"] == 0 for c in query["chains"][:5]), "OpenFold3 protein molecule_type must be 0")
    require(query["chains"][5] == {"molecule_type": 3, "chain_ids": ["F"], "ccd_codes": ["MOV"]},
            "OpenFold3 ligand changed")
    require(not any(query[k] for k in ("use_msas", "use_paired_msas", "use_main_msas")),
            "OpenFold3 MSA flags must stay false; the fetch also needs --use-msa-server=False")
    require(len(query["covalent_bonds"]) == 1
            and [e[:2] for e in query["covalent_bonds"][0]] == [["C", 6], ["F", 1]]
            and all(isinstance(e[2], int) for e in query["covalent_bonds"][0]),
            "OpenFold3 covalent_bonds shape changed -- it is inert, and the demonstration depends on it being declared")

    # RF3 (RoseTTAFold3), the structure predictor inside the same rc-foundry image
    # the rfdiffusion3 entry builds. Unlike its sibling rfd3, which can only infer a
    # bond from the input file, rf3 takes a declared one. Strict JSON with no extra
    # keys: `rf3 fold` reads CIF/PDB/JSON and not YAML, so a comment cannot live in
    # the file, and an unrecognised top-level key is a silent behaviour change.
    rf3 = json.loads((ROOT / "rf3.json").read_text())
    require(len(rf3) == 1, "RF3 input must hold exactly one prediction")
    rf3, = rf3
    require(set(rf3) == {"name", "components", "bonds"}, "RF3 input has unexpected top-level keys")
    require(rf3["name"] == manifest["name"], "RF3 prediction name changed")
    require(len(rf3["components"]) == 6, "RF3 must contain exactly six components")
    require([(c["chain_id"], c["seq"]) for c in rf3["components"][:5]] == expected,
            "RF3 component order differs from reference")
    require(rf3["components"][5] == {"ccd_code": "MOV", "chain_id": "F"}, "RF3 ligand changed")
    # chain_id/res_name/res_id/atom_name. The only dialect here that wants the
    # residue NAME as well as its number, and the chain comes from each component's
    # own chain_id, so list order addresses nothing.
    require(rf3["bonds"] == [["C/CYS/6/SG", "F/MOV/1/C25"]], "RF3 bond changed")

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
    print("PASS dialects: boltz/protenix/chai1/intellifold/rf3 declare the bond; openfold3")
    print("     declares it too and will DROP it -- check with --expect-unbonded")
    print("PASS templates: 8UDR reference plus 8VRA antibody D<-E and E<-D; offline assets intact")
    print("This audit checks input identity and reference geometry, not GPU prediction accuracy.")


if __name__ == "__main__":
    try:
        main()
    except (KeyError, OSError, ValueError) as error:
        raise SystemExit("FAIL inputs: " + str(error))
