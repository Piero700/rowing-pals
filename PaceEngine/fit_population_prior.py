"""
Fit the cold-start population prior from Concept2 Online Rankings percentiles.

    python3 fit_population_prior.py

Reads data/concept2_2k_rankings_percentiles.csv (read from log.concept2.com on 2026-10-05)
and prints the constants that go into EngineConfig. Re-run when the data file is refreshed,
then paste the printed values into pace_engine.py and regenerate the golden vectors.

Method (SPEC.md §5.12, §7.6):
  * Percentile: the MEDIAN (50th) — "mid-pack" among rowers who log a ranked 2k.
  * Seasons: every season in the file, averaged with equal weight.
  * Baselines: the all-weights 19–29 median for each sex, taken as the reference-age value.
  * Age curve, reference age and up: each 10-year band's median over its sex's 19–29 median,
    averaged across sexes and seasons, placed at the band's midpoint. Below the reference age
    the existing rule stays: ranked juniors are a strongly selected group (12–18 medians are
    as fast as 19–29), so the rankings can't fit young ages.
  * Weight: not fitted. The 19–29 heavyweight/lightweight medians are printed as a check on
    Concept2's own 0.222 exponent, which stays.
"""

from __future__ import annotations

import csv
import os

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "data", "concept2_2k_rankings_percentiles.csv")
REFERENCE_BAND = "19-29"
OLDER_BANDS = ["30-39", "40-49", "50-59", "60-69", "70-79", "80-89"]


def load() -> list[dict]:
    with open(DATA) as fh:
        rows = [line for line in fh if not line.startswith("#")]
    return list(csv.DictReader(rows))


def fit(rows: list[dict]) -> dict:
    medians: dict[tuple, float] = {}
    for r in rows:
        medians[(r["season"], r["gender"], r["age_band"], r["weight"])] = float(r["p50"])
    seasons = sorted({r["season"] for r in rows})

    baseline = {}
    for gender in ("M", "F"):
        values = [medians[(s, gender, REFERENCE_BAND, "")] for s in seasons]
        baseline[gender] = sum(values) / len(values)

    knots = []
    for band in OLDER_BANDS:
        lo, hi = (int(x) for x in band.split("-"))
        ratios = [medians[(s, g, band, "")] / medians[(s, g, REFERENCE_BAND, "")]
                  for s in seasons for g in ("M", "F")]
        knots.append(((lo + hi + 1) / 2.0, sum(ratios) / len(ratios) - 1.0))

    weight_check = {}
    for gender in ("M", "F"):
        heavy = [medians[(s, gender, REFERENCE_BAND, "H")] for s in seasons]
        light = [medians[(s, gender, REFERENCE_BAND, "L")] for s in seasons]
        weight_check[gender] = (sum(light) / len(light)) / (sum(heavy) / len(heavy))

    return {"baseline": baseline, "knots": knots, "weight_check": weight_check,
            "seasons": seasons}


if __name__ == "__main__":
    result = fit(load())
    print(f"seasons: {', '.join(result['seasons'])}")
    print(f"prior_male_2k_seconds   = {round(result['baseline']['M'], 1)}")
    print(f"prior_female_2k_seconds = {round(result['baseline']['F'], 1)}")
    print("age_curve_knots = (")
    for age, fraction in result["knots"]:
        print(f"    ({age}, {round(fraction, 4)}),")
    print(")")
    for gender, ratio in result["weight_check"].items():
        print(f"check: {gender} 19-29 lightweight/heavyweight median ratio {ratio:.4f} "
              f"(Concept2's exponent gives ~1.03-1.05 for typical class weights)")
