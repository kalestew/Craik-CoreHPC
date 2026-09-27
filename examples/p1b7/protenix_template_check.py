"""Require one real accepted related-antibody template for each Fab chain.

Run inside protenix_2.sif with the run-local PROTENIX_ROOT_DIR, as run.sh does.
No GPU inference or downloads occur here. APIs were inspected in the pinned
installed image, not inferred from another Protenix release.
"""
import json
import os
from pathlib import Path

from protenix.data.template.template_parser import HmmsearchA3MParser
from protenix.data.template.template_utils import TemplateHitFeaturizer

ROOT = Path(__file__).resolve().parent


def main():
    overlay = Path(os.environ["PROTENIX_ROOT_DIR"])
    featurizer = TemplateHitFeaturizer(
        mmcif_dir=str(overlay / "mmcif"), max_hits=4,
        kalign_binary_path="/usr/bin/kalign", max_template_date="3000-01-01",
        release_dates_path=str(overlay / "common/release_date_cache.json"),
        obsolete_pdbs_path=str(overlay / "common/obsolete_to_successor.json"),
        strict_error_check=True, fetch_remote=False,
    )
    job, = json.loads((ROOT / "prepared/protenix/protenix.json").read_text())
    report = {}
    for chain, index in (("D", 3), ("E", 4)):
        protein = job["sequences"][index]["proteinChain"]
        sequence = protein["sequence"]
        a3m = Path(protein["templatesPath"]).read_text()
        hits = HmmsearchA3MParser.parse(sequence, a3m, skip_first=False)
        if len(hits) != 1:
            raise RuntimeError("expected exactly one parsed hit for chain " + chain)
        result, _ = featurizer.get_templates(chain, sequence, hits)
        errors = getattr(result, "errors", [])
        warnings = getattr(result, "warnings", [])
        if len(result.features) != 1 or errors or warnings:
            raise RuntimeError("chain %s: expected one accepted template without warnings; features=%d, errors=%s, warnings=%s" %
                               (chain, len(result.features), errors, warnings))
        report[chain] = {"template": "8vra_" + ("E" if chain == "D" else "D"), "features": len(result.features)}
        print("PASS template: query chain %s has one accepted 8VRA antibody template" % chain, flush=True)
    (ROOT / "prepared/protenix/template-check.json").write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
