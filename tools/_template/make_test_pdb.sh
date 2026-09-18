#!/bin/sh
# Write a small protein backbone as a PDB, for tool self-tests.
#
#   sh _template/make_test_pdb.sh [n_residues] [chain] [mixed|helix] > t.pdb
#
# Why this exists rather than a checked-in structure: the registry's .gitignore
# is an allow-list that keeps payloads out of git, so no .pdb can live in a tool
# directory -- and a test must not reach into whichever project happens to be
# checked out beside it. Generating the structure keeps every entry's test.sh
# self-contained and identical on any cluster.
#
# Two things here are not decoration, and both cost a debugging round.
#
# `mixed` is the default because a pure ideal alpha-helix is maximally LOW
# COMPLEXITY in structure space: foldseek reduces it to the 3Di string
# DVVVV...VVVD, one repeated state, and its prefilter discards that. Alternating
# helix and extended segments gives a varied 3Di string.
#
# The residue names CYCLE rather than being poly-alanine, because foldseek's
# prefilter k-mers combine the 3Di state with the AMINO ACID, and a poly-ALA
# sequence is just as degenerate in that half -- the run prints `AAAAAA 0` over
# and over and reports "0 sequences passed prefiltering". Between them these two
# make a structure fail to match ITSELF, which reads as a broken tool and is a
# broken test fixture. Only backbone atoms are written, and every residue type
# has N/CA/C/O, so varying the name costs nothing geometrically.
#
# Geometry is idealised, not minimised: CA on a cylinder, with N, C and O on
# offset radii and phases. Good enough to parse, number, render and search;
# not a structure to do science on.
set -eu
n=${1:-40}
chain=${2:-A}
mode=${3:-mixed}

awk -v n="$n" -v ch="$chain" -v mode="$mode" 'BEGIN {
    pi = 3.14159265358979
    serial = 0
    phi = 0.0
    z = 0.0
    rr["N"]  = 1.5; pp["N"]  = -0.50; zz["N"]  = -0.60
    rr["CA"] = 2.3; pp["CA"] =  0.00; zz["CA"] =  0.00
    rr["C"]  = 1.9; pp["C"]  =  0.55; zz["C"]  =  0.55
    rr["O"]  = 2.1; pp["O"]  =  0.85; zz["O"]  =  1.30
    split("N CA C O", nm, " ")
    # A non-repeating residue cycle; see the header on why poly-ALA fails.
    nres = split("ALA GLU LEU LYS ILE ARG VAL THR TRP ASP PHE SER TYR ASN MET GLN HIS PRO GLY CYS", aa, " ")

    for (i = 1; i <= n; i++) {
        # Segment: thirds -- helix, extended, helix -- unless asked for pure helix.
        seg = "H"
        if (mode == "mixed") {
            third = int((i - 1) * 3 / n)
            if (third == 1) seg = "E"
        }
        if (seg == "H") { dphi = 100.0 * pi / 180.0; rise = 1.50; rad = 1.0 }
        else            { dphi = 180.0 * pi / 180.0; rise = 3.30; rad = 0.45 }

        for (k = 1; k <= 4; k++) {
            a  = nm[k]
            x  = rad * rr[a] * cos(phi + pp[a])
            y  = rad * rr[a] * sin(phi + pp[a])
            zc = z + zz[a]
            serial++
            printf "ATOM  %5d  %-3s %s %s%4d    %8.3f%8.3f%8.3f  1.00  0.00          %2s\n", \
                   serial, a, aa[((i - 1) % nres) + 1], ch, i, x, y, zc, substr(a, 1, 1)
        }
        phi += dphi
        z   += rise
    }
    printf "TER\nEND\n"
}'
