# V2.7-A2R6 CARSIM PATH-LINEAGE MINIMAL REMEDIATION

Status: PASS (working-directory remediation only)

## Finding and minimal remediation

The diagnostic target's CarSim block retains `SIMFILE = simfile.sim`. A run from the project root selected the root `simfile.sim`, whose macros point to the unavailable `G:\carsim` lineage. The existing validated `model/simfile.sim` points to the D: installation. A2R6 therefore changed only the compile validation working directory to `D:\UsersData\桌面\two\model`; no shared simfile, target model, reliability interface, or algorithm was modified.

## Static/path evidence

- Active working directory: `D:\UsersData\桌面\two\model`
- Active relative simfile: `D:\UsersData\桌面\two\model\simfile.sim`
- Active simfile SHA-256: `C12B21288F9C0D907BB5D6C9D789691F6B0EF101A48F87BAB20B006FD8C690E6`
- `PROGDIR`: `D:\carsim\CarSim2021.0_Prog\`
- `DATADIR`: `D:\carsim\CarSim2021.0_Data\`
- Solver DLL, `vs_sf.mexw64`, and `Matlab84+\Solver_SF.slx`: present.
- Target `model/vx_vy_reliability_diagnostic_v2_7.slx` SHA-256 before/after: `2D68C7A4AC40354A300FC2F72C7838C8863E9ACBCAB9908F8985125B362E5F7F` (unchanged).
- Shared project-root `simfile.sim` SHA-256: `95EBBB022B0F4A4019ECE96353B38C586D8616E914FA9736044D57EEF0E2F9BD` (unchanged).

## Single compile-level recheck

Healthy MATLAB `-batch` was launched once from the model directory. `load_system=PASS`, compile=`PASS`, compiled evidence=`PASS`, termination=`PASS`. D/K/F contract, scheduler, logging, and Demux-width gates passed. `simCalled=0`; no formal CarSim runtime was run. The solver's initialization text reported termination at simulation time 0 as part of compile-level initialization, not a `sim()` invocation.

Result MAT: `results/vy_reliability_diagnostic_v2_7a2r6_path_compile.mat`.

## Frozen integrity

The frozen fixed-fusion target, D/K/F sources, and feedback propagation source retained their recorded hashes; no frozen baseline was written. A2R6 created only the path-compile result, this evidence CSV, and this status file (the MATLAB runner was a one-time external temporary script).

## Decision

The G-drive blocker is removed for the diagnostic compile path by selecting the already validated D-lineage `model` working directory. No model or shared configuration change was required.

READY FOR V2.7 RELIABILITY DIAGNOSTIC SMOKE RUNTIME
