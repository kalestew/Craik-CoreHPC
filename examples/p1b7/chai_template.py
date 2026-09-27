"""Run Chai's reference-template demonstration using staged mmCIFs only.

Run INSIDE chai1_2.sif through run.sh; requires that image's kalign and API.
Derive hit ranges with Chai's real parser instead of guessing over missing
residues. Keep the output empty until run_inference checks it; then intercept
template downloads and copy the bundled snapshot into the requested cache.
"""
import json
import shutil
import sys
from pathlib import Path

import gemmi
from chai_lab.data.io import rcsb
from chai_lab.data.parsing.templates.m8 import parse_m8_to_template_hits
from chai_lab.tools.kalign import kalign_query_to_reference

ROOT = Path(__file__).resolve().parent


def staged_template(pdb_id, directory):
    source = ROOT / "reference" / (pdb_id.upper() + ".cif.gz")
    if not source.is_file():
        raise FileNotFoundError("template not bundled: " + str(source))
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    target = directory / source.name
    if source.resolve() != target.resolve():
        shutil.copyfile(source, target)
    return target


def row(chain, start, end, query_length):
    return "\t".join([chain, "8udr_" + chain, "100.0", str(end - start), "0", "0",
                      "1", str(query_length), str(start + 1), str(end), "1e-9", "0", "reference-demo"]) + "\n"


def prepare_hits(work):
    manifest = json.loads((ROOT / "manifest.json").read_text())
    reference = gemmi.read_structure(str(ROOT / "reference/8UDR.cif.gz"))
    probe = work / "probe.m8"
    rows = []
    for entity in manifest["chains"]:
        chain, query = entity["chain"], entity["sequence"]
        modelled = reference[0][chain].get_polymer().make_one_letter_sequence().replace("-", "")
        alignment = kalign_query_to_reference(ref=modelled, query=query)
        if alignment is None:
            raise RuntimeError("kalign failed for chain " + chain)
        first, last = alignment.reference_span
        candidates = sorted((abs(ds) + abs(de), ds, de) for ds in range(-6, 7) for de in range(-6, 7))
        for _, ds, de in candidates:
            start, end = first + ds, last + 1 + de
            if not 0 <= start < end <= len(modelled):
                continue
            text = row(chain, start, end, len(query))
            probe.write_text(text)
            hits = list(parse_m8_to_template_hits(chain, query, probe, template_cif_folder=work / "cif"))
            if len(hits) == 1 and hits[0].hit_start == start and hits[0].hit_end == end:
                rows.append(text)
                print("Template accepted: input %s <- 8UDR %s; modelled positions %d-%d; query %d aa" %
                      (chain, chain, start + 1, end, len(query)), flush=True)
                break
        else:
            raise RuntimeError("No Chai-compatible template span for chain " + chain)
    table = work / "chai1.m8"
    table.write_text("".join(rows))
    return table


def main():
    rcsb.download_cif_file = staged_template
    work = ROOT / "prepared/chai1"
    work.mkdir(parents=True, exist_ok=True)
    hits = prepare_hits(work)
    if sys.argv[1:] == ["--prepare-only"]:
        print("Prepared and parsed all five hits without GPU inference: " + str(hits))
        return
    from chai_lab.chai1 import run_inference
    run_inference(fasta_file=ROOT / "chai1.fasta", output_dir=Path(sys.argv[1]),
                  constraint_path=ROOT / "chai1.restraints", template_hits_path=hits,
                  use_msa_server=False, use_templates_server=False,
                  use_esm_embeddings=True, num_trunk_recycles=3,
                  num_diffn_timesteps=200, num_diffn_samples=5,
                  num_trunk_samples=1, seed=1, device=None, low_memory=True)


if __name__ == "__main__":
    main()
