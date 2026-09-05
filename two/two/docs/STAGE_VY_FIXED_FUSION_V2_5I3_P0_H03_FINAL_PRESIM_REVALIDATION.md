# V2.5-I3-P0 H03 Final Pre-Sim Revalidation

## Decision

**V2.5-I3-P0 H03 FINAL PRE-SIM REVALIDATION BLOCKED**

### Exact blocker

The H03 phase lineage is inconsistent:

- R0 status declares `results/vy_fixed_fusion_v2_5i3_H03_exec_r0_phase_markers.csv`, but the actual runner references `results/vy_fixed_fusion_v2_5i3_H03_exec_a3_phase_markers.csv`
- actual analyzer references `results/vy_fixed_fusion_v2_5i3_H03_exec_a3_phase_markers.csv`
- R1 ASCII bootstrap references `results/vy_fixed_fusion_v2_5i3_H03_exec_r0_phase_markers.csv`

The actual bootstrap therefore does not use the same attempt-scoped phase file as the runner/analyzer, and the R0 status does not match the actual runner/analyzer source. This violates the frozen same-phase-lineage gate. No H03 execution is authorized until this is remediated and independently revalidated.

## Verified frozen identity and hashes

- run ID：`FWHOLD_H03`
- execution attempt：`FWHOLD_H03_EXEC_R0`
- condition：`0.030 rad / 0.45 Hz / 16 s / 100 Hz`
- scientific role：`SINGLE_CONDITION_PARTIAL_DIAGNOSTIC_HOLDOUT_EVIDENCE`
- runner：`AB65E8D5DCDEE92EA8AC53AEFE1BFDC97CD4FC7BD8390C17E8656DD90EB631C2`
- analyzer：`B6DE7B43EAEB154BF59EE906F8A08343217AED1CAEB0B5955BBE357D54182823`
- ASCII bootstrap：`43FFD09AD9F5F9E1F421FCA9A786B43A25EA7BE43E4385CC3248256C85B718DE`
- ASCII launcher：`66747BF4EF3E260545369D78FBEF1AFE4B5F40247F586D84A8AABBA29EFEDC29`
- target：`AA1664868ACFB847C5300E293DB2C653E990C1E698EC5AE309C18F1009A17D2B`
- core/wrapper/registry/weights：read-only hashes unchanged

## Pre-sim state

- live MATLAB：`0`
- live CarSim solver：`0`
- `MATLAB_PREFDIR`：`UNSET`
- active SET-2：`ABSENT`
- H03 phase files：both declared/actual candidates `ABSENT`:
  - R0 status/R1 bootstrap path: `results/vy_fixed_fusion_v2_5i3_H03_exec_r0_phase_markers.csv`
  - actual runner/analyzer path: `results/vy_fixed_fusion_v2_5i3_H03_exec_a3_phase_markers.csv`
- H03 commit：`ABSENT`
- H03 formal MAT：`ABSENT`
- new ASCII launcher stdout/stderr/exitcode/status：`ABSENT`
- launcher invocation：`0`
- H03 authorization：`UNCONSUMED`
- H01：permanently closed
- H02：permanently closed; authorization consumed

User-provided CarSim license confirmation (`carsimCN`, Version 2021, Available Yes (1), Take=1) is recorded only; no runtime probe was performed. CarSim Browser-related processes may be present, but no solver process is active.

## Static execution audit

- runner executable `sim()` call sites：`1`
- runner retry/fallback：`0`
- launcher MATLAB launch count：`1`
- commit-before-sim and commit read-back ordering：present in runner
- PARTIAL23 / original three-holdout aggregate / generalization classification / retuning：not enabled

These checks cannot override the phase-lineage mismatch. No phase marker, commit, formal MAT, MATLAB session, Simulink load, CarSim runtime, or H03 launcher execution occurred in P0.

P0 evidence files:

- `results/vy_fixed_fusion_v2_5i3_p0_H03_final_run_card.csv`
- `results/vy_fixed_fusion_v2_5i3_p0_H03_presim_gates.csv`
- `results/vy_fixed_fusion_v2_5i3_p0_H03_runtime_authorization.csv`
