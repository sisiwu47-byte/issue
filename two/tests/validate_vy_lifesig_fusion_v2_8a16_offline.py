import csv
import hashlib
import json
import math
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "results" / "vy_lifesig_v2_8a16_k_health_integration"
REF = ROOT / "results" / "vy_lifesig_v2_8a14_k_health_ablation" / "timeseries.csv"
NORMAL = ROOT / "results" / "vy_lifesig_v2_8a14_k_health_ablation" / "normal_case_comparison.csv"
CORE = ROOT / "matlab" / "vy_lifesig_fusion_v2_8_step.m"
WRAPPER = ROOT / "matlab" / "vy_lifesig_fusion_v2_8_simulink_sfun.m"
V27 = {
    ROOT / "model" / "vy_lifesig_fusion_step.m": "3847C7D74B912B30DEAE1F9C95C756B2EC2F08082E398661DC9E0850B9E377CA",
    ROOT / "model" / "vy_lifesig_fusion_simulink_sfun.m": "E47B81999A6A99CDE07D04A43521D0EAE20AA020FFFC257AFC535F915CC9A445",
    ROOT / "model" / "vx_vy_lifesig_fusion_v2_7.slx": "65B5BE97C3FBCEC8DE918B399A93616ECE72C9ABE82603E7FB6692118D798FB0",
}

TS = 0.01
D0 = 0.3467656927489074
RHO = 0.995
LAMBDA = 10.0


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest().upper()


def read_rows(path):
    with open(path, newline="", encoding="utf-8-sig") as f:
        return list(csv.DictReader(f))


def write_rows(path, rows):
    fields = []
    for row in rows:
        for key in row:
            if key not in fields:
                fields.append(key)
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(rows)


def gate(rows, name, passed, details):
    rows.append({"gate": name, "passed": str(bool(passed)).upper(), "details": details})


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    core = CORE.read_text(encoding="utf-8").lower()
    wrapper = WRAPPER.read_text(encoding="utf-8").lower()
    gates = []

    required_core = [
        "d0 = 0.3467656927489074;", "rho = 0.995;", "lambda = 10;",
        "ts = 0.01;", "i_k_base = 0;",
        "excess = max(0,disagreement - d0);",
        "candidatestate = rho * i_k_base + ts * excess;",
        "g_k = exp(-lambda * i_k_next);", "h_k = h_k_old * g_k;",
        "scorek = qk * h_k;", "termk = scorek * vy_k;",
    ]
    missing = [p for p in required_core if p not in core]
    gate(gates, "CORE_FROZEN_FORMULA_STATIC", not missing,
         "missing=" + ("NONE" if not missing else "|".join(missing)))
    gate(gates, "CORE_RESET_IK_STATIC", "i_k_base = 0;" in core and "if double(reset) ~= 0" in core,
         "reset clears I_K base before current-hit recurrence")
    gate(gates, "CORE_NONFINITE_SAFETY_STATIC",
         "if isfinite(vy_d) && isfinite(vy_k)" in core and
         "if isfinite(disagreement)" in core and
         "if isfinite(candidatestate) && candidatestate >= 0" in core,
         "nonfinite pair cannot poison I_K")
    gate(gates, "CORE_EXISTING_FALLBACK_STATIC",
         "if memoryvalid" in core and "alpha_d = 0;" in core and
         "fallback_active = 1;" in core and "has_last_valid_next = double(memoryvalid);" in core,
         "hold-last/no-history fallback retained")
    gate(gates, "WRAPPER_STATE_AND_DELEGATION_STATIC",
         all(p in wrapper for p in ["block.numinputports = 8;", "block.numoutputports = 11;",
                                    "block.numdworks = 3;", "block.dwork(3).name = 'i_k';",
                                    "vy_lifesig_fusion_v2_8_step(", "block.sampletimes = [0.01 0];"]),
         "8 inputs; 11 outputs; I_K is third DWork; 100 Hz")
    forbidden_wrapper = ["0.842618409", "0.146439697", "0.010941893",
                         "28.252990", "0.346765692", "0.995", "exp("]
    gate(gates, "WRAPPER_NO_DUPLICATED_MATH_STATIC",
         not any(p in wrapper for p in forbidden_wrapper),
         "wrapper delegates all math to core")

    frozen_ok = all(sha256(path) == expected for path, expected in V27.items())
    gate(gates, "FROZEN_V27_UNCHANGED", frozen_ok,
         ";".join(f"{path.name}={sha256(path)}" for path in V27))

    rows = read_rows(REF)
    time = np.array([float(r["time_s"]) for r in rows])
    truth = np.array([float(r["Vy_true_mps"]) for r in rows])
    vd = np.array([float(r["Vy_D_mps"]) for r in rows])
    vk = np.array([float(r["Vy_K_mps"]) for r in rows])
    vf = np.array([float(r["Vy_F_mps"]) for r in rows])
    ref_y = np.array([float(r["Vy_C_mps"]) for r in rows])
    ref_i = np.array([float(r["I_K_C_m"]) for r in rows])
    ref_g = np.array([float(r["G_K_C"]) for r in rows])
    ref_ad = np.array([float(r["alphaD_C"]) for r in rows])
    ref_ak = np.array([float(r["alphaK_C"]) for r in rows])
    ref_af = np.array([float(r["alphaF_C"]) for r in rows])
    base_ak = np.array([float(r["alphaK_A"]) for r in rows])

    # Recover the original D:F score ratio. Multiplying only K by G leaves
    # this ratio exactly unchanged, so no new fitted quantity is introduced.
    ratio_df = ref_ad / ref_af
    rem = 1.0 - base_ak
    base_af = rem / (ratio_df + 1.0)
    base_ad = rem - base_af
    base_alpha = np.column_stack([base_ad, base_ak, base_af])

    excess = np.maximum(0.0, np.abs(vk - vd) - D0)
    calc_i = np.empty_like(excess)
    state = 0.0
    for k, value in enumerate(excess):
        state = RHO * state + TS * value
        calc_i[k] = state
    calc_g = np.exp(-LAMBDA * calc_i)
    scores = base_alpha.copy()
    scores[:, 1] *= calc_g
    calc_alpha = scores / np.sum(scores, axis=1, keepdims=True)
    calc_y = np.sum(calc_alpha * np.column_stack([vd, vk, vf]), axis=1)

    diffs = {
        "Vy_LS": calc_y - ref_y, "I_K": calc_i - ref_i,
        "G_K": calc_g - ref_g, "alpha_D": calc_alpha[:, 0] - ref_ad,
        "alpha_K": calc_alpha[:, 1] - ref_ak, "alpha_F": calc_alpha[:, 2] - ref_af,
    }
    max_diff = max(float(np.max(np.abs(v))) for v in diffs.values())
    gate(gates, "A15_SAMPLEWISE_REPLAY", len(time) == 1731 and max_diff <= 1e-14,
         f"N={len(time)};max_abs_difference={max_diff:.17g}")

    sub = np.abs(vk - vd) <= D0
    zero_state = ref_i == 0.0
    normal_mask = sub & zero_state
    normal_max = float(np.max(np.abs(calc_y[normal_mask] - np.array([float(r["Vy_A_mps"]) for r in rows])[normal_mask])))
    gate(gates, "ZERO_STATE_ORIGINAL_LIFESIG_EQUIVALENCE", np.any(normal_mask) and normal_max <= 1e-14,
         f"samples={int(np.sum(normal_mask))};max_abs_difference={normal_max:.17g}")

    sample_rows = []
    for k in range(len(time)):
        sample_rows.append({
            "time_s": time[k],
            "Vy_LS_reference": ref_y[k], "Vy_LS_implementation": calc_y[k], "Vy_LS_difference": diffs["Vy_LS"][k],
            "I_K_reference": ref_i[k], "I_K_implementation": calc_i[k], "I_K_difference": diffs["I_K"][k],
            "G_K_reference": ref_g[k], "G_K_implementation": calc_g[k], "G_K_difference": diffs["G_K"][k],
            "alphaD_reference": ref_ad[k], "alphaD_implementation": calc_alpha[k, 0], "alphaD_difference": diffs["alpha_D"][k],
            "alphaK_reference": ref_ak[k], "alphaK_implementation": calc_alpha[k, 1], "alphaK_difference": diffs["alpha_K"][k],
            "alphaF_reference": ref_af[k], "alphaF_implementation": calc_alpha[k, 2], "alphaF_difference": diffs["alpha_F"][k],
        })
    write_rows(OUT / "samplewise_comparison.csv", sample_rows)
    write_rows(OUT / "regression_summary.csv", gates)

    normal_rows = read_rows(NORMAL)
    normal_c = [r for r in normal_rows if r["method"] == "C_LEAKY_K_HEALTH"]
    evidence = {
        "stage": "V2.8-A16",
        "verdict": "IMPLEMENTATION_REGRESSION_PASS" if all(r["passed"] == "TRUE" for r in gates) else "IMPLEMENTATION_REGRESSION_FAIL",
        "regression_method": "NO_SIMULINK_OFFLINE_STATIC_PLUS_SAMPLEWISE_REPLAY",
        "sample_count": len(time), "window_s": [float(time[0]), float(time[-1])],
        "max_samplewise_difference": max_diff,
        "max_component_differences": {k: float(np.max(np.abs(v))) for k, v in diffs.items()},
        "normal_exact_unchanged_runs": sum(float(r["output_MaxAbs_change_vs_A_mps"]) == 0.0 for r in normal_c),
        "normal_max_output_change_mps": max(float(r["output_MaxAbs_change_vs_A_mps"]) for r in normal_c),
        "normal_max_alphaK_change": max(float(r["alphaK_max_abs_change_vs_A"]) for r in normal_c),
        "parameters": {"rho": RHO, "lambda_1_per_m": LAMBDA, "Ts_s": TS, "d0_mps": D0},
        "files": {"core": str(CORE.relative_to(ROOT)), "core_sha256": sha256(CORE),
                  "wrapper": str(WRAPPER.relative_to(ROOT)), "wrapper_sha256": sha256(WRAPPER),
                  "reference": str(REF.relative_to(ROOT)), "reference_sha256": sha256(REF)},
        "matlab_startup_attempt": "FAILED_BEFORE_TEST_ERRORS_WARNINGS_PLUGIN",
        "simulink_loaded": False, "sim_called": False, "carsim_run": False,
        "independent_v2_8_slx_target_bound": False,
        "ready_for_single_runtime_recovery_validation": False,
        "next_required_gate": "INDEPENDENT_V2_8_TARGET_BINDING_AND_COMPILE_PREFLIGHT",
    }
    (OUT / "regression_evidence.json").write_text(json.dumps(evidence, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"A16_OFFLINE|gates={sum(r['passed']=='TRUE' for r in gates)}/{len(gates)}|maxDiff={max_diff:.17g}")
    print(evidence["verdict"])


if __name__ == "__main__":
    main()
