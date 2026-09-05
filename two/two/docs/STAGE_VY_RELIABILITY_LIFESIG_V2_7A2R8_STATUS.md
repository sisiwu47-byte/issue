# V2.7-A2R8 RELIABILITY DIAGNOSTIC CALIBRATION CAPTURE

## Verdict

All five captures completed successfully and are eligible for the reliability
adequacy re-audit.

```text
role = NON_HOLDOUT_RELIABILITY_CALIBRATION
window = [0,16] s
rate = 100 Hz
front steering = sine, FL/FR same phase
rear steering = zero
runtime cwd = D:\UsersData\桌面\two\model
CarSim lineage = validated D: installation and dataset
```

These files do not overwrite or replace the original FWCAL artifacts. They
reuse only the frozen maneuver identities and conditions; they are not H01,
H02, or H03.

## Capture results

| Run | Condition | Result | SHA-256 | Samples/integrity |
|---|---|---|---|---|
| FWCAL_C01R1 | 0.020 rad / 0.30 Hz | `results/vy_reliability_diagnostic_v2_7_fwcal_c01r1.mat` | `BA2546C4FB18810197B0ED721B9D83E1C14CB1354B75B64FF6E960A226B70864` | 1601 / PASS |
| FWCAL_C02 | 0.020 rad / 0.50 Hz | `results/vy_reliability_diagnostic_v2_7_fwcal_c02.mat` | `7942F1612A055B906DD9012E3D5A2F53314FB5E2560370CCD0BF901243AD589B` | 1601 / PASS |
| FWCAL_C03 | 0.030 rad / 0.40 Hz | `results/vy_reliability_diagnostic_v2_7_fwcal_c03.mat` | `30C12ED01DC1C1E044D4154E7476794306F3231DE414F7E4CFBA3E88D450400A` | 1601 / PASS |
| FWCAL_C04 | 0.040 rad / 0.30 Hz | `results/vy_reliability_diagnostic_v2_7_fwcal_c04.mat` | `2E003C60081F959FFD36B317A94D1AD9CE9DF8FECE9CB63794B298A37B4F01A5` | 1601 / PASS |
| FWCAL_C05 | 0.040 rad / 0.40 Hz | `results/vy_reliability_diagnostic_v2_7_fwcal_c05.mat` | `2BA043D6536816A5DCE77831D3A34D0CF952FCD145377512CADAB584047F5C6F` | 1601 / PASS |

Suite evidence:
`results/vy_reliability_diagnostic_v2_7a2r8_capture_suite.mat`, SHA-256
`E7785DE397BB90604CDF7931D836D4315318B195C1679792A7639B4E0D6050D1`.

## Logged contract and integrity

Every MAT contains the maneuver identity and condition plus synchronized raw
records for:

- common 100-Hz time and offline-only `Vy_true`;
- D: `Vy_D`, `P_D11`, `NIS_D`, measurement dimension, `useAy_D`,
  `update_valid_D`, `nis_valid_D`;
- K: `Vy_K`, `P_K22`, `NIS_K`, `abs(r)`, `update_valid_K`,
  `nis_valid_K`;
- F: `Vy_F`, `P_F`, propagation age, `age_valid`, `reset_valid`.

For each run, all logs are finite and aligned to 1601 samples from 0 through
16 seconds. D/K invalid-zero validity checks passed. F age is initialized at
zero, becomes one at the first valid propagation, increments by one per hit,
and retains valid reset-input/age evidence.

## Integrity and exclusions

The diagnostic target SHA-256 remained
`2D68C7A4AC40354A300FC2F72C7838C8863E9ACBCAB9908F8985125B362E5F7F`.
Frozen fixed-fusion and D/K/F sources remained unchanged. Current executable F
test parameters were retained; the separate `P0_F=0` core-contract blocker was
not addressed. No LifeSig parameter fitting, epsilon/r0/tau_F selection, Q/R
tuning, fusion tuning, or holdout execution occurred.

READY FOR V2.7-A2R9 RELIABILITY ADEQUACY RE-AUDIT
