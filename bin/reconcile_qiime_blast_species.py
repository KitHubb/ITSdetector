#!/usr/bin/env python3
"""
Conservative species-only reconciliation of normalized QIIME and BLAST taxonomy.

Outputs:
  taxonomy_blast.tsv
  taxonomy_blast_qiime.tsv
  taxonomy_blast_evidence.tsv
  taxonomy_blast_changed.tsv
  taxonomy_blast_report.tsv
"""

import argparse
import re
from pathlib import Path

import pandas as pd


RANKS = ["Kingdom", "Phylum", "Class", "Order", "Family", "Genus", "Species"]
PREFIX = {
    "Kingdom": "k__", "Phylum": "p__", "Class": "c__", "Order": "o__",
    "Family": "f__", "Genus": "g__", "Species": "s__"
}
MISSING = {"", ".", "na", "nan", "none", "null", "unassigned", "unclassified", "unknown"}


def clean(x):
    if pd.isna(x):
        return ""
    x = str(x).strip()
    if x.lower() in MISSING:
        return ""
    x = re.sub(r"^[kpcofgs]__", "", x, flags=re.I)
    return "_".join(x.split())


def compare(x):
    return clean(x).replace("_", "").lower()


def genus_resolved(x):
    x = clean(x)
    return bool(x) and not x.lower().endswith(("_k", "_p", "_c", "_o", "_f"))


def species_unresolved(species, genus):
    return not clean(species) or clean(species).lower() == f"{clean(genus).lower()}_g"


def format_taxon(ranks):
    if all(not ranks[r] for r in RANKS):
        return "Unassigned"
    return "; ".join(f"{PREFIX[r]}{ranks[r]}" for r in RANKS)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--qiime-normalized", required=True)
    ap.add_argument("--blast-taxonomy", required=True)
    ap.add_argument("--output-dir", required=True)
    ap.add_argument("--min-qiime-confidence", type=float, default=0.7)
    ap.add_argument("--max-evalue", type=float, default=1e-10)
    ap.add_argument("--min-pident", type=float, default=99.0)
    ap.add_argument("--min-qcovus", type=float, default=80.0)
    args = ap.parse_args()

    out = Path(args.output_dir)
    out.mkdir(parents=True, exist_ok=True)

    q = pd.read_csv(args.qiime_normalized, sep="\t", dtype=str, keep_default_na=False)
    b = pd.read_csv(args.blast_taxonomy, sep="\t", dtype=str, keep_default_na=False)

    if not {"Feature ID", "Taxon", "Confidence", *RANKS}.issubset(q.columns):
        raise ValueError("Normalized QIIME table lacks required columns.")

    required_b = {
        "ASV", "BLAST_Top1_Evalue", "BLAST_Top1_Bitscore",
        "BLAST_Top1_Pident", "BLAST_Top1_Qcovus",
        "BLAST_Top1_Genus", "BLAST_Top1_Species",
        "BLAST_AmbiguousTopHit"
    }
    if not required_b.issubset(b.columns):
        raise ValueError("BLAST taxonomy table lacks required columns.")

    q = q.rename(columns={"Feature ID": "ASV"})
    q["QIIME_ConfidenceNumeric"] = pd.to_numeric(q["Confidence"], errors="coerce")

    for col in ["BLAST_Top1_Evalue", "BLAST_Top1_Bitscore", "BLAST_Top1_Pident", "BLAST_Top1_Qcovus"]:
        b[col] = pd.to_numeric(b[col], errors="coerce")

    b["BLAST_AmbiguousTopHit"] = b["BLAST_AmbiguousTopHit"].astype(str).str.lower().eq("true")
    x = q.merge(b, on="ASV", how="left", validate="one_to_one")

    rows = []

    for _, r in x.iterrows():
        original = {rank: clean(r[rank]) for rank in RANKS}
        final = original.copy()
        blank = all(not original[rank] for rank in RANKS)
        hit = pd.notna(r["BLAST_Top1_Evalue"])

        cutoff = bool(
            hit
            and r["BLAST_Top1_Evalue"] <= args.max_evalue
            and r["BLAST_Top1_Pident"] >= args.min_pident
            and r["BLAST_Top1_Qcovus"] >= args.min_qcovus
        )

        genus_match = bool(
            hit and genus_resolved(original["Genus"])
            and genus_resolved(r["BLAST_Top1_Genus"])
            and compare(original["Genus"]) == compare(r["BLAST_Top1_Genus"])
        )

        if blank:
            final = {rank: "" for rank in RANKS}
            status, reason = "qiime_taxonomy_blank", "QIIME taxonomy was blank or unassigned."
        elif pd.isna(r["QIIME_ConfidenceNumeric"]) or r["QIIME_ConfidenceNumeric"] < args.min_qiime_confidence:
            final = {rank: "" for rank in RANKS}
            status, reason = "qiime_low_confidence", "QIIME confidence was below threshold or missing."
        elif not genus_resolved(original["Genus"]):
            status, reason = "qiime_genus_unresolved", "QIIME genus was unresolved."
        elif not species_unresolved(original["Species"], original["Genus"]):
            status, reason = "qiime_species_retained", "QIIME already had a species-level assignment."
        elif not hit:
            status, reason = "no_eligible_blast_hit", "No strict BLAST candidate was available."
        elif not cutoff:
            status, reason = "blast_cutoff_failed", "Top BLAST hit failed strict species criteria."
        elif bool(r["BLAST_AmbiguousTopHit"]):
            status, reason = "ambiguous_blast_hit", "Top 1 and Top 2 had exact score ties but different species."
        elif not genus_match:
            status, reason = "genus_discordant", "QIIME and BLAST genus did not match."
        elif not clean(r["BLAST_Top1_Species"]):
            status, reason = "blast_species_unresolved", "BLAST lineage lacked species assignment."
        else:
            final["Species"] = clean(r["BLAST_Top1_Species"])
            status, reason = "species_replaced_by_blast", "Strict BLAST evidence supported species-only replacement."

        row = {
            "ASV": r["ASV"],
            "QIIME_Taxon_Original": r.get("Taxon_Original", ""),
            "QIIME_Taxon_Normalized": r["Taxon"],
            "QIIME_Confidence": r["Confidence"],
            "QIIME_ConfidenceNumeric": r["QIIME_ConfidenceNumeric"],
            **{f"QIIME_{rank}": original[rank] for rank in RANKS},
            **{col: r.get(col, "") for col in b.columns if col != "ASV"},
            "BLAST_CutoffPass": cutoff,
            "BLAST_GenusMatch": genus_match,
            **{f"Final_{rank}": final[rank] for rank in RANKS},
            "Final_Taxon": format_taxon(final),
            "Replacement_Status": status,
            "Replacement_Reason": reason,
        }
        rows.append(row)

    evidence = pd.DataFrame(rows)

    final = evidence[
        ["ASV", *[f"Final_{r}" for r in RANKS], "Final_Taxon", "Replacement_Status", "Replacement_Reason"]
    ].rename(columns={f"Final_{r}": r for r in RANKS})

    qiime = evidence[["ASV", "Final_Taxon", "QIIME_Confidence"]].rename(
        columns={"ASV": "Feature ID", "Final_Taxon": "Taxon", "QIIME_Confidence": "Confidence"}
    )

    changed = evidence.loc[evidence["Replacement_Status"] == "species_replaced_by_blast"].copy()
    report = evidence["Replacement_Status"].value_counts().rename_axis("Metric").reset_index(name="Value")
    report = pd.concat(
        [pd.DataFrame([{"Metric": "total_asvs", "Value": len(evidence)}]), report],
        ignore_index=True
    )

    final.to_csv(out / "taxonomy_blast.tsv", sep="\t", index=False)
    qiime.to_csv(out / "taxonomy_blast_qiime.tsv", sep="\t", index=False)
    evidence.to_csv(out / "taxonomy_blast_evidence.tsv", sep="\t", index=False)
    changed.to_csv(out / "taxonomy_blast_changed.tsv", sep="\t", index=False)
    report.to_csv(out / "taxonomy_blast_report.tsv", sep="\t", index=False)

    print(f"[INFO] Total ASVs: {len(evidence)}")
    print(f"[INFO] Species replacements: {(evidence['Replacement_Status'] == 'species_replaced_by_blast').sum()}")


if __name__ == "__main__":
    main()
