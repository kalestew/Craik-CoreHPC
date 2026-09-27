"""Scientific input/geometry regressions for the offline P1B7 teaching bundle.

No GPU, Slurm installation, network, or third-party Python packages are needed.
The synthetic coordinate fixtures preserve the deposited sequences and actual
ligand geometry; their protein CA coordinates are only test scaffolding, not
predictions. Negative cases represent plausible numbering, identity, and
covalent-endpoint mistakes that a successful model process would not catch.
"""
from contextlib import redirect_stdout
from copy import deepcopy
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
EXAMPLE = REPO / "examples/p1b7"
AA3 = "ALA ARG ASN ASP CYS GLN GLU GLY HIS ILE LEU LYS MET PHE PRO SER THR TRP TYR VAL".split()
TO_ONE = dict(zip(AA3, "ARNDCQEGHILKMFPSTWYV"))
TO_THREE = {one: three for three, one in TO_ONE.items()}
# Pin the downloaded source snapshots independently of the editable manifest.
REFERENCE_HASHES = {
    "8UDR": "dbde919081cc02a479d360865d6809d8af4266c133aa6498b9a779a8ef9311a7",
    "8VRA": "eb2e88d66f78aa59ff953130e418725e9aa4a776605525fa0f63928d9b0bb318",
}


def load_example_module(name):
    spec = importlib.util.spec_from_file_location("p1b7_test_" + name, EXAMPLE / (name + ".py"))
    module = importlib.util.module_from_spec(spec)
    sys.path.insert(0, str(EXAMPLE))
    try:
        spec.loader.exec_module(module)
    finally:
        sys.path.pop(0)
    return module


STRUCTURE = load_example_module("structure_io")
CHECKER = load_example_module("check_output")


def snapshot(directory):
    """Include new directories as well as changed file contents."""
    return {
        str(path.relative_to(directory)): hashlib.sha256(path.read_bytes()).hexdigest()
        if path.is_file() else None
        for path in directory.rglob("*")
    }


def write_model(path, records):
    if path.suffix == ".pdb":
        lines = []
        for serial, atom in enumerate(records, 1):
            x, y, z = atom["xyz"]
            group = "HETATM" if atom["chain"] == "F" else "ATOM"
            lines.append(
                f'{group:<6}{serial:5d} {atom["name"]:>4} {atom["comp"]:>3} '
                f'{atom["chain"]}{int(atom["residue"]):4d}    '
                f'{x:8.3f}{y:8.3f}{z:8.3f}{1.0:6.2f}{20.0:6.2f}'
                f'          {atom["element"]:>2}\n'
            )
        path.write_text("".join(lines) + "END\n")
    else:
        columns = ("group_PDB", "id", "type_symbol", "label_atom_id", "label_comp_id",
                   "label_asym_id", "label_seq_id", "Cartn_x", "Cartn_y", "Cartn_z",
                   "auth_asym_id", "auth_seq_id", "pdbx_PDB_model_num")
        lines = ["data_geometry_fixture\n#\nloop_\n"]
        lines += ["_atom_site." + column + "\n" for column in columns]
        for serial, atom in enumerate(records, 1):
            # Deliberately reproduce 8UDR's ligand label F / author D distinction.
            author_chain = "D" if atom["chain"] == "F" else atom["chain"]
            author_number = "12" if atom["chain"] == "C" and atom["residue"] == "6" else atom["residue"]
            values = ["HETATM" if atom["chain"] == "F" else "ATOM", str(serial),
                      atom["element"], atom["name"], atom["comp"], atom["chain"], atom["residue"],
                      *[f"{value:.3f}" for value in atom["xyz"]], author_chain, author_number, "1"]
            lines.append(" ".join(values) + "\n")
        path.write_text("".join(lines) + "#\n")


class P1B7ExampleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads((EXAMPLE / "manifest.json").read_text())
        cls.sequences = {chain["chain"]: chain["sequence"] for chain in cls.manifest["chains"]}
        cls.reference_atoms = STRUCTURE.atoms(EXAMPLE / "reference/8UDR.cif.gz")

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="p1b7-test-")
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.work = self.base / "scratch copy with spaces"
        shutil.copytree(EXAMPLE, self.work, ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
        self.env = dict(os.environ)
        for key in tuple(self.env):
            if key.startswith("SLURM_") or key in ("CUDA_VISIBLE_DEVICES", "PYTHONDONTWRITEBYTECODE"):
                self.env.pop(key)

    def command(self, arguments, env=None):
        return subprocess.run(arguments, cwd=self.work, env=env or self.env,
                              text=True, capture_output=True, timeout=30)

    def input_audit(self):
        return self.command([sys.executable, "-B", "check_inputs.py"])

    def geometry_fixture(self, tool="boltz"):
        result = []
        for chain, sequence in self.sequences.items():
            for position, residue in enumerate(sequence, 1):
                result.append(dict(chain=chain, residue=str(position), name="CA", element="C",
                                   comp=TO_THREE[residue], xyz=(100 + position * 3, 100, ord(chain))))
        anchor = next(atom for atom in self.reference_atoms
                      if atom["chain"] == "C" and atom["residue"] == "6" and atom["name"] == "SG")
        result.append(deepcopy(anchor))
        ligand = [deepcopy(atom) for atom in self.reference_atoms if atom["chain"] == "F"]
        for index, atom in enumerate(ligand):
            atom["residue"] = "1"
            if tool == "chai1":
                atom["name"] = "C1_1" if atom["name"] == "C25" else atom["element"] + str(index + 10) + "_1"
        return result + ligand

    def assert_geometry(self, records, tool="boltz", error=None):
        path = self.base / ("model.pdb" if tool == "boltz" else "model.cif")
        write_model(path, records)
        with redirect_stdout(io.StringIO()):
            if error:
                with self.assertRaisesRegex(ValueError, error):
                    CHECKER.check(tool, path)
            else:
                CHECKER.check(tool, path)

    def test_deposited_sequences_and_covalent_numbering_are_the_source(self):
        for pdb, digest in REFERENCE_HASHES.items():
            self.assertEqual(hashlib.sha256((EXAMPLE / "reference" / (pdb + ".cif.gz")).read_bytes()).hexdigest(), digest)
        source = EXAMPLE / "reference/8UDR.cif.gz"
        entities = {}
        for row in STRUCTURE.cif_loop(source, "_entity_poly_seq"):
            entities.setdefault(row["entity_id"], []).append(TO_ONE[row["mon_id"]])
        deposited = {row["id"]: "".join(entities[row["entity_id"]])
                     for row in STRUCTURE.cif_loop(source, "_struct_asym") if row["entity_id"] in entities}
        self.assertEqual(self.sequences, deposited)
        self.assertEqual([len(deposited[chain]) for chain in "ABCDE"], [275, 99, 10, 226, 213])
        self.assertEqual(deposited["C"], "VVVGACGVGK")
        bond, = [row for row in STRUCTURE.cif_loop(source, "_struct_conn") if row["id"] == "covale1"]
        self.assertEqual([bond[key] for key in ("ptnr1_label_asym_id", "ptnr1_label_seq_id", "ptnr1_label_atom_id",
                                              "ptnr2_label_asym_id", "ptnr2_label_comp_id", "ptnr2_label_atom_id")],
                         ["C", "6", "SG", "F", "MOV", "C25"])
        self.assertEqual([bond[key] for key in ("ptnr1_auth_seq_id", "ptnr2_auth_asym_id")], ["12", "D"])
        audit = self.input_audit()
        self.assertEqual(audit.returncode, 0, audit.stdout + audit.stderr)

    def test_input_audit_rejects_same_length_mutation_in_every_predictor(self):
        original = self.sequences["D"]
        changed = "A" + original[1:]
        for filename in ("boltz.yaml", "chai1.fasta", "protenix.json", "manifest.json"):
            with self.subTest(filename=filename):
                path = self.work / filename
                text = path.read_text()
                self.assertIn(original, text)
                path.write_text(text.replace(original, changed, 1))
                audit = self.input_audit()
                self.assertNotEqual(audit.returncode, 0, audit.stdout)
                self.assertIn("FAIL", audit.stdout + audit.stderr)
                path.write_text(text)

    def test_input_audit_rejects_author_numbering_and_wrong_entity(self):
        path = self.work / "boltz.yaml"
        path.write_text(path.read_text().replace("[C, 6, SG]", "[C, 12, SG]"))
        self.assertNotEqual(self.input_audit().returncode, 0)
        shutil.copyfile(EXAMPLE / "boltz.yaml", path)
        path = self.work / "protenix.json"
        data = json.loads(path.read_text())
        data[0]["covalent_bonds"][0]["entity1"] = 4  # antibody instead of the KRAS peptide
        path.write_text(json.dumps(data))
        self.assertNotEqual(self.input_audit().returncode, 0)

    def test_input_audit_rejects_reference_tampering(self):
        path = self.work / "reference/8UDR.cif.gz"
        path.write_bytes(path.read_bytes() + b"changed reference")
        audit = self.input_audit()
        self.assertNotEqual(audit.returncode, 0)
        self.assertIn("checksum", audit.stdout + audit.stderr)

    def test_reference_and_all_predictor_atom_conventions_pass(self):
        with redirect_stdout(io.StringIO()):
            CHECKER.check("reference", EXAMPLE / "reference/8UDR.cif.gz")
        for tool in ("boltz", "chai1", "protenix"):
            with self.subTest(tool=tool):
                self.assert_geometry(self.geometry_fixture(tool), tool)

    def test_reference_missing_residues_do_not_qualify_as_full_prediction(self):
        with self.assertRaisesRegex(ValueError, "CA counts"):
            CHECKER.check("protenix", EXAMPLE / "reference/8UDR.cif.gz")

    def test_wrong_sequence_with_correct_chain_lengths_is_rejected(self):
        model = self.geometry_fixture()
        model[0]["comp"] = "ALA"  # deposited A:1 is GLY; lengths and bond are unchanged
        self.assert_geometry(model, error="identity|sequence")

    def test_missing_renamed_and_extra_chains_are_rejected(self):
        for mutation in ("missing", "renamed", "extra"):
            with self.subTest(mutation=mutation):
                model = self.geometry_fixture()
                if mutation == "missing":
                    model = [atom for atom in model if atom["chain"] != "E"]
                elif mutation == "renamed":
                    for atom in model:
                        if atom["chain"] == "F":
                            atom["chain"] = "G"
                else:
                    model.append({**model[0], "chain": "G"})
                self.assert_geometry(model, error="chains|chain")

    def test_ligand_and_anchor_must_both_be_complete(self):
        for target in ("SG", "ligand"):
            with self.subTest(target=target):
                model = self.geometry_fixture()
                if target == "SG":
                    model = [atom for atom in model if atom["name"] != "SG"]
                else:
                    model.pop()  # retain endpoint but lose one ligand atom
                self.assert_geometry(model, error="expected one|41 ligand")

    def test_wrong_atom_name_or_element_is_rejected(self):
        for field, value in (("name", "X25"), ("element", "O")):
            with self.subTest(field=field):
                model = self.geometry_fixture()
                endpoint = next(atom for atom in model if atom["chain"] == "F" and atom["name"] == "C25")
                endpoint[field] = value
                self.assert_geometry(model, error="C25|carbon")

    def test_too_short_and_nonbonded_distances_are_rejected(self):
        for separation in (0.9, 3.5):
            with self.subTest(separation=separation):
                model = self.geometry_fixture()
                anchor = next(atom for atom in model if atom["name"] == "SG")
                endpoint = next(atom for atom in model if atom["chain"] == "F" and atom["name"] == "C25")
                x, y, z = anchor["xyz"]
                endpoint["xyz"] = (x + separation, y, z)
                self.assert_geometry(model, error="outside")

    def test_another_ligand_atom_cannot_also_contact_sulfur(self):
        model = self.geometry_fixture()
        anchor = next(atom for atom in model if atom["name"] == "SG")
        other = next(atom for atom in model if atom["chain"] == "F" and atom["name"] != "C25")
        x, y, z = anchor["xyz"]
        other["xyz"] = (x, y + 1.8, z)
        self.assert_geometry(model, error="additional|wrong ligand contact")

    def test_nonfinite_coordinates_are_rejected(self):
        model = self.geometry_fixture()
        model[0]["xyz"] = (float("nan"), 0, 0)
        self.assert_geometry(model, error="nonfinite")

    def test_one_bad_sample_fails_directory_check_without_erasing_outputs(self):
        output = self.base / "models"
        output.mkdir()
        valid = self.geometry_fixture()
        write_model(output / "p1b7_model_0.pdb", valid)
        invalid = deepcopy(valid)
        next(atom for atom in invalid if atom["name"] == "SG")["xyz"] = (900, 900, 900)
        write_model(output / "p1b7_model_1.pdb", invalid)
        before = snapshot(output)
        result = self.command([sys.executable, "-B", "check_output.py", "boltz", str(output)])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("p1b7_model_0.pdb", result.stdout)
        self.assertIn("p1b7_model_1.pdb", result.stdout)
        self.assertIn("1/2 models failed", result.stderr)
        self.assertEqual(snapshot(output), before)

    def test_empty_output_directory_is_not_a_success(self):
        output = self.base / "empty"
        output.mkdir()
        result = self.command([sys.executable, "-B", "check_output.py", "boltz", str(output)])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("no predicted model", result.stderr)

    def test_partial_ensemble_cannot_satisfy_five_sample_completion(self):
        output = self.base / "ensemble"
        output.mkdir()
        valid = self.geometry_fixture()
        write_model(output / "p1b7_model_0.pdb", valid)
        arguments = [sys.executable, "-B", "check_output.py", "boltz", str(output), "--expected-samples", "5"]
        partial = self.command(arguments)
        self.assertNotEqual(partial.returncode, 0)
        self.assertIn("expected 5 output models; found 1", partial.stderr)
        for sample in range(1, 5):
            write_model(output / ("p1b7_model_%d.pdb" % sample), valid)
        complete = self.command(arguments)
        self.assertEqual(complete.returncode, 0, complete.stdout + complete.stderr)

    def test_six_dry_runs_need_no_allocation_and_leave_fixture_unchanged(self):
        before = snapshot(self.work)
        for tool in ("boltz", "chai1", "protenix"):
            for mode in ("none", "template"):
                with self.subTest(tool=tool, mode=mode):
                    result = self.command(["bash", "run.sh", tool, mode, "--dry-run"])
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertIn("Dry run complete", result.stdout)
                    self.assertIn("out/" + tool + "-" + mode, result.stdout)
                    self.assertEqual(snapshot(self.work), before)

    def stub(self, name, contents):
        directory = self.base / "bin"
        directory.mkdir(exist_ok=True)
        path = directory / name
        path.write_text("#!/bin/sh\n" + contents)
        path.chmod(0o755)
        self.env["PATH"] = str(directory) + os.pathsep + os.environ["PATH"]

    def test_real_run_without_allocation_cannot_call_predictor(self):
        self.stub("chpc-tool", 'touch "$P1B7_TEST_CALLED"\nexit 99\n')
        marker = self.base / "predictor-called"
        self.env["P1B7_TEST_CALLED"] = str(marker)
        before = snapshot(self.work)
        result = self.command(["bash", "run.sh", "boltz"])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("No Slurm allocation", result.stderr)
        self.assertFalse(marker.exists())
        self.assertEqual(snapshot(self.work), before)

    def test_bare_salloc_or_cpu_job_is_not_a_gpu_allocation(self):
        self.stub("chpc-tool", 'touch "$P1B7_TEST_CALLED"\nexit 99\n')
        marker = self.base / "predictor-called"
        self.env.update(SLURM_JOB_ID="123456", P1B7_TEST_CALLED=str(marker))
        for gpu_result in ("exit 1\n", "exit 0\n"):
            with self.subTest(gpu_result=gpu_result):
                self.stub("nvidia-smi", gpu_result)
                before = snapshot(self.work)
                result = self.command(["bash", "run.sh", "protenix", "template"])
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("No usable GPU", result.stderr)
                self.assertFalse(marker.exists())
                self.assertEqual(snapshot(self.work), before)

    def test_source_checkout_cannot_be_used_as_a_prediction_workdir(self):
        source = self.base / "checkout/examples/p1b7"
        source.parent.mkdir(parents=True)
        shutil.copytree(self.work, source)
        self.env["CHPC_REPO"] = str(source.parents[1].resolve())  # env.sh exports a physical path
        before = snapshot(source)
        result = subprocess.run(["bash", "run.sh", "boltz"], cwd=source, env=self.env,
                                text=True, capture_output=True, timeout=30)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("checked-in example folder", result.stderr)
        self.assertEqual(snapshot(source), before)

    def test_failed_tool_export_cannot_continue_to_prediction(self):
        self.stub("nvidia-smi", "echo 'NVIDIA L40S'\n")
        self.stub("chpc-tool", 'if [ "$1" = export ]; then echo "weights unavailable" >&2; exit 42; fi\n'
                  'touch "$P1B7_TEST_CALLED"\nexit 99\n')
        marker = self.base / "predictor-called"
        self.env.update(SLURM_JOB_ID="123456", P1B7_TEST_CALLED=str(marker))
        # A stale cache value must not conceal the export failure.
        self.env["BOLTZ_CACHE"] = str(self.base / "stale-cache")
        before = snapshot(self.work)
        result = self.command(["bash", "run.sh", "boltz"])
        self.assertEqual(result.returncode, 42, result.stdout + result.stderr)
        self.assertIn("weights unavailable", result.stderr)
        self.assertFalse(marker.exists())
        self.assertEqual(snapshot(self.work), before)

    def test_existing_outputs_are_not_overwritten_or_prepared_again(self):
        self.stub("nvidia-smi", "echo 'NVIDIA L40S'\n")
        self.stub("chpc-tool", 'touch "$P1B7_TEST_CALLED"\nexit 99\n')
        marker = self.base / "predictor-called"
        self.env.update(SLURM_JOB_ID="123456", P1B7_TEST_CALLED=str(marker))
        output = self.work / "out/protenix-template"
        output.mkdir(parents=True)
        (output / "keep.cif").write_text("previous scientific result\n")
        before = snapshot(self.work)
        result = self.command(["bash", "run.sh", "protenix", "template"])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Output already exists", result.stderr)
        self.assertFalse(marker.exists())
        self.assertEqual(snapshot(self.work), before)


if __name__ == "__main__":
    unittest.main()
