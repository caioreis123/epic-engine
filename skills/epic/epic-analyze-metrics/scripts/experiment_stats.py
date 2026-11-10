#!/usr/bin/env python3
"""Two-proportion statistical analysis for an A/B(/C) experiment.

Input JSON on stdin or as a file path:
{
  "control": {"name": "control", "participants": 1000, "conversions": 100, "weight": 0.5},
  "variants": [{"name": "variant B", "participants": 1000, "conversions": 120, "weight": 0.5}],
  "start_date": "2026-10-01",
  "end_date": "2026-10-15",
  "decision_type": "superiority" | "noninferiority",
  "mde_relative": null,
  "noninferiority_margin_abs": null
}
"""
import json
import sys
from datetime import date, timedelta
from math import sqrt
from statistics import NormalDist

ALPHA = 0.05
POWER = 0.80
Z_POWER = NormalDist().inv_cdf(POWER)
BAYES_SAMPLES = 200_000
BAYES_SEED = 1
SRM_CHI2_CRITICAL_P001 = {1: 10.83, 2: 13.82, 3: 16.27}
REFERENCE_MARGIN_ABS = 0.01
REFERENCE_MARGIN_RELATIVE = 0.10
NORMAL = NormalDist()


def z_two_sided(alpha):
    return NORMAL.inv_cdf(1 - alpha / 2)


def z_one_sided(alpha):
    return NORMAL.inv_cdf(1 - alpha)


def rates(control, variant):
    rate_control = control["conversions"] / control["participants"]
    rate_variant = variant["conversions"] / variant["participants"]
    se_unpooled = sqrt(
        rate_control * (1 - rate_control) / control["participants"]
        + rate_variant * (1 - rate_variant) / variant["participants"]
    )
    return rate_control, rate_variant, se_unpooled


def superiority_test(control, variant, alpha):
    rate_control, rate_variant, se_unpooled = rates(control, variant)
    pooled = (control["conversions"] + variant["conversions"]) / (
        control["participants"] + variant["participants"]
    )
    se_pooled = sqrt(
        pooled * (1 - pooled) * (1 / control["participants"] + 1 / variant["participants"])
    )
    diff = rate_variant - rate_control
    z_score = diff / se_pooled if se_pooled else 0.0
    p_value = 2 * (1 - NORMAL.cdf(abs(z_score)))
    z_crit = z_two_sided(alpha)
    return {
        "rate_control": rate_control,
        "rate_variant": rate_variant,
        "diff_abs": diff,
        "diff_rel": diff / rate_control if rate_control else None,
        "z": z_score,
        "p_value": p_value,
        "ci_low": diff - z_crit * se_unpooled,
        "ci_high": diff + z_crit * se_unpooled,
        "significant": p_value < alpha,
    }


def sample_per_arm_estimate(rate_control, rate_target):
    delta = rate_target - rate_control
    if delta == 0:
        return None
    mean_rate = (rate_control + rate_target) / 2
    return 16 * mean_rate * (1 - mean_rate) / delta**2


def noninferiority_sample_per_arm(rate_control, rate_variant, margin_abs, alpha):
    distance = (rate_variant - rate_control) + margin_abs
    if distance <= 0:
        return None
    variance = rate_control * (1 - rate_control) + rate_variant * (1 - rate_variant)
    return (z_one_sided(alpha) + Z_POWER) ** 2 * variance / distance**2


def noninferiority_test(control, variant, margin_abs, alpha):
    rate_control, rate_variant, se_unpooled = rates(control, variant)
    diff = rate_variant - rate_control
    lower_bound = diff - z_one_sided(alpha) * se_unpooled
    return {
        "margin_abs": margin_abs,
        "lower_bound_one_sided": lower_bound,
        "noninferior": lower_bound > -margin_abs,
        "sample_per_arm": noninferiority_sample_per_arm(
            rate_control, rate_variant, margin_abs, alpha
        ),
    }


def bayes_chance_to_beat(control, variant):
    import random

    rng = random.Random(BAYES_SEED)
    wins = 0
    for _ in range(BAYES_SAMPLES):
        draw_variant = rng.betavariate(
            variant["conversions"] + 1, variant["participants"] - variant["conversions"] + 1
        )
        draw_control = rng.betavariate(
            control["conversions"] + 1, control["participants"] - control["conversions"] + 1
        )
        wins += draw_variant > draw_control
    return wins / BAYES_SAMPLES


def srm_check(arms):
    total = sum(arm["participants"] for arm in arms)
    default_weight = 1 / len(arms)
    chi2 = 0.0
    for arm in arms:
        expected = total * arm.get("weight", default_weight)
        chi2 += (arm["participants"] - expected) ** 2 / expected
    critical = SRM_CHI2_CRITICAL_P001[len(arms) - 1]
    return {"chi2": chi2, "critical_p001": critical, "srm_detected": chi2 > critical}


def eta(needed_total, total_participants, daily_rate, end):
    if needed_total is None:
        return {"participants_missing": None, "days_missing": None, "eta_date": None}
    missing = max(needed_total - total_participants, 0)
    days_missing = missing / daily_rate if daily_rate else None
    return {
        "participants_missing": missing,
        "days_missing": days_missing,
        "eta_date": (end + timedelta(days=days_missing)).isoformat()
        if days_missing is not None
        else None,
    }


def analyze(payload):
    control = payload["control"]
    variants = payload["variants"]
    decision_type = payload.get("decision_type", "superiority")
    alpha = ALPHA / len(variants)
    start = date.fromisoformat(payload["start_date"])
    end = date.fromisoformat(payload["end_date"])
    days_elapsed = (end - start).days + 1
    total_participants = control["participants"] + sum(v["participants"] for v in variants)
    daily_rate = total_participants / days_elapsed
    arms = 1 + len(variants)
    results = []
    for variant in variants:
        test = superiority_test(control, variant, alpha)
        lift = payload.get("mde_relative")
        rate_target = (
            test["rate_control"] * (1 + lift) if lift is not None else test["rate_variant"]
        )
        per_arm = sample_per_arm_estimate(test["rate_control"], rate_target)
        superiority = {
            "mde_rate_target": rate_target,
            "sample_per_arm": per_arm,
            "sample_total": per_arm * arms if per_arm else None,
            **eta(per_arm * arms if per_arm else None, total_participants, daily_rate, end),
        }
        margin = payload.get("noninferiority_margin_abs")
        margins = (
            {"owner": margin}
            if margin is not None
            else {
                "reference_1pp_abs": REFERENCE_MARGIN_ABS,
                "reference_10pct_rel": test["rate_control"] * REFERENCE_MARGIN_RELATIVE,
            }
        )
        noninferiority = {}
        for label, margin_abs in margins.items():
            ni = noninferiority_test(control, variant, margin_abs, alpha)
            per_arm_ni = ni["sample_per_arm"]
            noninferiority[label] = {
                **ni,
                "sample_total": per_arm_ni * arms if per_arm_ni else None,
                **eta(per_arm_ni * arms if per_arm_ni else None, total_participants, daily_rate, end),
            }
        results.append(
            {
                "variant": variant["name"],
                **test,
                "alpha_used": alpha,
                "bayes_chance_to_beat_control": bayes_chance_to_beat(control, variant),
                "superiority": superiority,
                "noninferiority": noninferiority,
            }
        )
    significant_winners = [r for r in results if r["significant"] and r["diff_abs"] > 0]
    winner = None
    if significant_winners:
        winner = max(significant_winners, key=lambda r: r["rate_variant"])["variant"]
    elif results and all(r["significant"] and r["diff_abs"] < 0 for r in results):
        winner = control["name"]
    return {
        "decision_type": decision_type,
        "days_elapsed": days_elapsed,
        "total_participants": total_participants,
        "daily_rate": daily_rate,
        "arms": arms,
        "alpha_used": alpha,
        "power": POWER,
        "srm": srm_check([control, *variants]),
        "decision_ready": winner is not None,
        "winner": winner,
        "comparisons": results,
    }


def main():
    raw = open(sys.argv[1]).read() if len(sys.argv) > 1 else sys.stdin.read()
    print(json.dumps(analyze(json.loads(raw)), indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
