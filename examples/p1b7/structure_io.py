"""Small stdlib reader for tutorial PDB/mmCIF coordinates and simple CIF loops.

This handles the flat loops used by the supplied structures and predictor
outputs. It rejects multiline values in a requested loop instead of guessing.
It is not a general replacement for gemmi or Biopython.
"""
import gzip
import math
import shlex
from pathlib import Path


def read_text(path):
    path = Path(path)
    if path.suffix == ".gz":
        with gzip.open(path, "rt") as handle:
            return handle.read()
    return path.read_text()


def cif_loop(path, category):
    lines = read_text(path).splitlines()
    for start, line in enumerate(lines):
        if line.strip() != "loop_":
            continue
        i, columns = start + 1, []
        while i < len(lines) and lines[i].strip().startswith("_"):
            columns.append(lines[i].strip())
            i += 1
        if not columns or not columns[0].startswith(category + "."):
            continue
        columns = [column.split(".", 1)[1] for column in columns]
        values = []
        while i < len(lines):
            line = lines[i].strip()
            if line.startswith(("#", "_", "loop_", "data_", "stop_")):
                break
            if line.startswith(";"):
                raise ValueError("multiline value in %s: use a full CIF reader" % category)
            values.extend(shlex.split(line, comments=False))
            i += 1
        if len(values) % len(columns):
            raise ValueError("incomplete %s row in %s" % (category, path))
        return [dict(zip(columns, values[j:j + len(columns)]))
                for j in range(0, len(values), len(columns))]
    raise ValueError("missing %s loop in %s" % (category, path))


def atoms(path):
    if str(path).lower().endswith((".cif", ".cif.gz", ".mmcif")):
        result = []
        for row in cif_loop(path, "_atom_site"):
            if row.get("pdbx_PDB_model_num", "1") != "1":
                continue
            result.append(dict(chain=row["label_asym_id"], residue=row["label_seq_id"],
                               name=row["label_atom_id"], element=row["type_symbol"],
                               comp=row["label_comp_id"],
                               xyz=tuple(float(row["Cartn_" + axis]) for axis in "xyz")))
        return result
    result = []
    for line in read_text(path).splitlines():
        if line.startswith("ENDMDL"):
            break
        if line.startswith(("ATOM  ", "HETATM")):
            name = line[12:16].strip()
            result.append(dict(chain=line[21], residue=line[22:26].strip(),
                               name=name, comp=line[17:20].strip(),
                               element=line[76:78].strip() or name[0],
                               xyz=tuple(float(line[i:i + 8]) for i in (30, 38, 46))))
    return result


def distance(a, b):
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(a["xyz"], b["xyz"])))
