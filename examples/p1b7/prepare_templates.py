"""Prepare run-local paths for Boltz or Protenix template demonstrations.

Usage: python3 prepare_templates.py boltz|protenix [SHARED_PROTENIX_ROOT]
Only prepared/ in this copied tutorial is written. Shared weights stay read-only.
"""
import gzip
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def main():
    tool = sys.argv[1]
    destination = ROOT / "prepared" / tool
    destination.mkdir(parents=True, exist_ok=True)
    if tool == "boltz":
        reference = destination / "8UDR.cif"
        with gzip.open(ROOT / "reference/8UDR.cif.gz", "rt") as source:
            reference.write_text(source.read())
        # JSON quoting is also valid YAML quoting (including unusual path chars).
        content = (ROOT / "boltz.yaml").read_text()
        content += "templates:\n  - cif: %s\n" % json.dumps(str(reference))
        content += "    chain_id: [A, B, C, D, E]\n    template_id: [A, B, C, D, E]\n"
        (destination / "boltz.yaml").write_text(content)
        print("Prepared 8UDR self-template for five protein chains; this supplies the known answer.")
    elif tool == "protenix":
        shared = Path(sys.argv[2]).resolve()
        if not (shared / "checkpoint").is_dir() or not (shared / "common").is_dir():
            raise SystemExit("Shared Protenix root lacks checkpoint/ or common/: " + str(shared))
        overlay = destination / "root"
        (overlay / "common").mkdir(parents=True, exist_ok=True)
        (overlay / "mmcif").mkdir(exist_ok=True)
        for source in shared.iterdir():
            target = overlay / source.name
            if source.name not in ("common", "mmcif") and not target.exists():
                target.symlink_to(source, target_is_directory=source.is_dir())
        for source in (shared / "common").iterdir():
            target = overlay / "common" / source.name
            if source.name != "release_date_cache.json" and not target.exists():
                target.symlink_to(source, target_is_directory=source.is_dir())
        dates = shared / "common/release_date_cache.json"
        cache = json.loads(dates.read_text()) if dates.exists() else {}
        cache["8vra"] = {"release_date": "2024-09-04"}
        (overlay / "common/release_date_cache.json").write_text(json.dumps(cache, indent=2) + "\n")
        # Only a retired PDB-id mapping; an empty one is valid for these current ids.
        obsolete = overlay / "common/obsolete_to_successor.json"
        if not obsolete.exists():
            obsolete.write_text("{}\n")
        with gzip.open(ROOT / "reference/8VRA.cif.gz", "rt") as source:
            (overlay / "mmcif/8vra.cif").write_text(source.read())
        jobs = json.loads((ROOT / "protenix.json").read_text())
        for chain, index in (("D", 3), ("E", 4)):
            jobs[0]["sequences"][index]["proteinChain"]["templatesPath"] = str(ROOT / "templates" / ("protenix-" + chain + ".a3m"))
        (destination / "protenix.json").write_text(json.dumps(jobs, indent=2) + "\n")
        print("Prepared 8VRA related-antibody templates ONLY: input D <- 8VRA E; input E <- 8VRA D.")
        print("Release-date cache and mmCIF are local; model weights are symlinked from the shared root.")
    else:
        raise SystemExit("choose boltz or protenix")


if __name__ == "__main__":
    main()
