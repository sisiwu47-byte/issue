# V2.7-ENV-A0 MATLAB Settings Plugin Startup Forensics

**ROOT_CAUSE_CANDIDATE_IDENTIFIED**

## Scope and non-execution statement

This stage was read-only. No MATLAB, Simulink, or CarSim process was
started. The MATLAB installation, default PREFDIR, registry, SET-2
quarantine, project models, algorithms, and historical evidence were not
modified.

## Exact failure carried from A2R4

The latest direct default-PREFDIR startup reached a fatal startup error
before any project or model load:

```text
std::exception::what: failed to load settings errors_warnings plugin
```

The failure persisted after the active SET-2 artifact had been moved to its
append-only quarantine. Therefore another unchanged MATLAB launch would not
provide new decision information and was prohibited in ENV-A0.

## Installation-tree findings

The registered R2024a root is `D:\matlab`. Its bundled component dependency
list explicitly contains:

```text
D:\matlab\bin\uninstaller_comp_deps.txt:147
settings/errors_warnings
```

The dependency file SHA-256 is:

```text
BBB000F4F457C0E45D68C8E7E5EA72D48D47F9BE23B5B54F9AE4A5273EDDCCC3
```

However, all of the following are absent:

- an `errors_warnings` directory anywhere below `D:\matlab`;
- an `errors_warnings` component record below
  `D:\matlab\appdata\components`;
- an `errors_warnings` file manifest below
  `D:\matlab\appdata\files`;
- an `errors_warnings` implementation below
  `D:\matlab\bin\win64\settings_plugins\settings`.

The installed settings-plugin tree contains only:

```text
D:\matlab\bin\win64\settings_plugins\settings\security_impl\mwsecurity_impl.dll
```

That DLL exists, is readable, has a valid MathWorks Authenticode signature,
and has SHA-256:

```text
E50E798D7DBE74A95515D0046BA4F0A87136391B45270E22B62A1297FAA9078B
```

All 11 settings component manifests that do exist were parsed and checked;
their referenced paths have zero missing entries. The inconsistency is thus
not a random missing file among registered settings components. It is the
absence of the complete `errors_warnings` component record/manifest/plugin
despite the bundled dependency list requiring that component.

An adjacent 13,108,873,057-byte sparse file ending in
`.baiduyun.p.downloading` is also present. This is recorded only as
corroborating evidence of non-final installation-media provenance; it is not
used by itself to establish the root-cause candidate.

## PREFDIR and cache findings

The default PREFDIR exists and is readable, and the current user has full
control. `MATLAB_PREFDIR` is unset in process, user, and machine scopes.

The active SET-2 path remains absent. Its append-only quarantine copy remains
present with the preserved SHA-256:

```text
30677E244B75BB3469E1937848E92D4F1C850988B453AFB93F4510DBD59C996E
```

Focused inspection of the current settings/cache files found no
`errors_warnings` reference. The current EP framework cache is 437,372 bytes,
has SHA-256
`7A181D98273DDE89E015EEFC31F4BB85AC92EC42B78DC2CD27C5C666AE0F2A84`,
and contains zero `errors_warnings` matches.

These facts do not support a user-level cache, SET-2, or ordinary PREFDIR
permission problem as the sole cause of the repeated fatal error.

## Environment findings

- No live MATLAB, MathWorks service-host, Java helper, or CarSim runtime was
  present at audit time.
- `JAVA_HOME`, `JRE_HOME`, `_JAVA_OPTIONS`, `JAVA_TOOL_OPTIONS`, and
  `CLASSPATH` were unset in the inspected scopes.
- The process PATH contains the registered installation entries
  `D:\matlab\runtime\win64` and `D:\matlab\bin`; no competing MATLAB or
  external Java path entry was found.
- The Windows MATLAB R2024a registration points to `D:\matlab`.

No environment-level evidence was found that explains the named missing
settings plugin.

## Startup logs, WER, and evidence limit

The A2R4-time MathWorks Service Host logs were found and hashed. They show
shutdown-side `Invalid response received` and `Transport not connected`
messages after the MATLAB connection ended. They do not identify an
`errors_warnings` file, DLL, JAR, or path and therefore do not narrow the
missing component to a particular binary.

No relevant Windows Application or accessible WER report was found in the
2026-08-30 15:10--15:30 local-time window. A vendor-supplied hash for the
missing component was not present locally, so byte-level verification of the
absent component is impossible. Existing `matlab.exe` and `security_impl`
binaries have valid MathWorks signatures.

## Root-cause candidate and classification

```text
classification = INSTALL_LEVEL
candidate = INCOMPLETE_OR_MISSING_MATLAB_R2024A_SETTINGS_ERRORS_WARNINGS_COMPONENT_OR_REGISTRATION
verdict = ROOT_CAUSE_CANDIDATE_IDENTIFIED
```

This is a candidate rather than a claim about a specific absent DLL name:
the local evidence proves a component-catalog/plugin-tree mismatch but does
not expose the vendor's expected binary filename or official component hash.

## Minimal remediation and probe decision

Use a verified complete MathWorks R2024a installer or maintenance repair to
repair/reinstall the MATLAB core/settings components. Do not manually copy a
DLL or JAR, and do not alter the default PREFDIR as a substitute for restoring
the missing installed component. The locally retained installation media
should not be trusted for repair until its completeness is independently
verified.

After that repair creates a material installation-state change, exactly one
startup-only probe is worth authorizing. It should first verify a minimal
MATLAB `-batch` command and normal exit without loading the project; Simulink
and the reliability target should remain separate later gates. Before repair,
another startup probe is not justified because it would repeat the already
reproduced failure without a new hypothesis.

