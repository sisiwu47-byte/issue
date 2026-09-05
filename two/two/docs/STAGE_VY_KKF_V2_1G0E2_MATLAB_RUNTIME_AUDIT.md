# STAGE VY K-KF V2.1-G0E2 MATLAB RUNTIME AUDIT

- Date: 2026-08-26
- Stage: V2.1-G0E2 MATLAB Installation / Runtime Integrity Audit
- Scope: Windows/process/environment/filesystem/Event Log read-only audit
- Root-cause class: **B — MATLAB INSTALLATION OR APPLICATION SERVICE APPEARS CORRUPTED**
- Final status: **V2.1-G0E2 MATLAB RUNTIME ROOT CAUSE IDENTIFIED**

No MATLAB instance was started in this audit. PID 16192 was neither attached
to nor controlled or terminated.

## 1. PID 16192 actual executable

Read-only CIM evidence:

```text
ProcessId       = 16192
ExecutablePath  = D:\matlab\bin\win64\MATLAB.exe
ParentProcessId = 1264
CreationDate    = 2026-08-25 08:22:08 +08:00
CommandLine     = D:\matlab\bin\win64\MATLAB.exe -desktop -MLAutomation -Embedding
```

Executable metadata:

```text
FullName       = D:\matlab\bin\win64\MATLAB.exe
FileVersion    = 24.1.0.2537033
ProductVersion = 24.1.0.2537033
Size           = 361832 bytes
LastWriteTime  = 2024-02-22 19:18:07 +08:00
Authenticode   = Valid, The MathWorks, Inc.
```

PID 16192 therefore uses the same `D:\matlab` installation that fails under
the new `-batch` and COM probes. There is no second known-good installation
selected by that process.

## 2. Failed installation entry points and command resolution

```text
D:\matlab\bin\matlab.exe
  exists         = YES
  FileVersion    = 24.1.0.2508561
  ProductVersion = 24.1.0.2508561
  size           = 426912 bytes
  LastWriteTime  = 2024-02-23 11:01:24 +08:00
  Authenticode   = Valid, The MathWorks, Inc.

D:\matlab\bin\win64\MATLAB.exe
  exists         = YES
  FileVersion    = 24.1.0.2537033
  ProductVersion = 24.1.0.2537033
  size           = 361832 bytes
  LastWriteTime  = 2024-02-22 19:18:07 +08:00
  Authenticode   = Valid, The MathWorks, Inc.
```

`where.exe matlab` returned exactly:

```text
D:\matlab\bin\matlab.exe
exit code = 0
```

No alternate C:, G:, or other MATLAB entry was resolved.

## 3. Installation metadata and provenance

`D:\matlab\VersionInfo.xml` exists and declares:

```text
release  = R2024a
version  = 24.1.0.2537033
date     = Feb 21 2024
checksum = 1243000788
```

This matches the core `bin\win64\MATLAB.exe` build. The outer launcher has an
earlier 24.1 build number; that difference alone is not sufficient proof of
corruption because both files retain valid MathWorks signatures.

The installation root contains strong evidence of a non-standard copied or
partially downloaded deployment:

```text
D:\matlab\MATLAB R2024a(64bit).zip.baiduyun.p.downloading
  size = 13,108,873,057 bytes
  attributes = Archive, SparseFile

D:\matlab\Matlab R2024a\MATLAB R2024a(64bit)\Setup
D:\matlab\Matlab R2024a\MATLAB R2024a(64bit)\Crack
```

The MATLAB root and most product directories have filesystem creation/update
times from 2026-08-23, whereas signed binaries retain 2024 release timestamps.
This is consistent with archive extraction or migration rather than a clean,
verifiable installer-managed deployment. No package content was modified or
executed during this audit.

## 4. Environment-variable audit

The following variables are unset at Process, User, and Machine scopes:

```text
MATLABPATH
MATLAB_ROOT
MATLAB_PREFDIR
JAVA_HOME
JRE_HOME
QT_PLUGIN_PATH
PYTHONHOME
PYTHONPATH
```

Relevant PATH entries:

```text
Process PATH index 10 = D:\matlab\runtime\win64
Process PATH index 11 = D:\matlab\bin
Machine PATH index 7 = D:\matlab\runtime\win64
Machine PATH index 8 = D:\matlab\bin
```

The user PATH contains no MATLAB-related entry. No Process/User/Machine PATH
entry references G:, another MATLAB/MathWorks installation, MATLAB Runtime
from another root, or an external Java/JRE/Qt path. Therefore there is no
direct evidence for class C environment/PATH contamination.

## 5. Windows Application Event Log

The Application log was queried read-only for:

```text
2026-08-26 17:45:00 through 19:10:00 +08:00
```

Results:

```text
total Application events in window = 10
events matching MATLAB / MathWorks / ApplicationService / client-v1 /
faulting module / DLL / Application Error / Windows Error Reporting = 0
```

There is no Event Log faulting-application, faulting-module, exception-code, or
ApplicationService event to report. The startup failures were emitted only to
the launcher command stream. The absence of an event limits component-level
attribution but does not contradict the repeatable startup failure.

## 6. Directory and critical-file integrity

All requested directories exist, are non-empty, and are ordinary directories
rather than junctions/reparse points:

| Directory | Immediate items | Reparse/junction |
|---|---:|---|
| `D:\matlab\bin` | 20 | No |
| `D:\matlab\bin\win64` | 4227 | No |
| `D:\matlab\sys` | 22 | No |
| `D:\matlab\toolbox` | 178 | No |
| `D:\matlab\resources` | 681 | No |
| `D:\matlab\runtime\win64` | 8 | No |
| `D:\matlab\interprocess` | 1 | No |
| `D:\matlab\bin\win64\app_service_host` | 1 | No |
| `D:\matlab\bin\win64\cppms_cache_manifests` | 2798 | No |

ACL evidence grants Builtin Users read/execute and Authenticated Users modify
rights on the checked installation directories and ApplicationService DLL.
Disk D: had approximately 155.8 GB free, so no disk-full condition exists.

Critical ApplicationService files exist:

```text
D:\matlab\bin\win64\app_service_host\jsd\services_host\mwApplicationService.dll
  size = 561000 bytes
  Authenticode = Valid, The MathWorks, Inc.

D:\matlab\bin\win64\cppms_cache_manifests\mwApplicationService.bpf
  size = 133 bytes
```

This basic existence check cannot validate the completeness or compatibility
of the thousands of supporting components. No full-tree hash or toolbox scan
was performed.

## 7. Root-cause classification

### Selected class

**B — MATLAB INSTALLATION OR APPLICATION SERVICE APPEARS CORRUPTED**

Evidence supporting B:

1. PID 16192 and all failed entry points use the same `D:\matlab` root, so A
   is rejected.
2. `where matlab` resolves only that root.
3. The requested environment variables are unset and PATH contains no other
   MATLAB, Java, Qt, Runtime, G:, or legacy-root contamination, so C lacks
   direct evidence.
4. Default startup fails in the settings `errors_warnings` plugin; a fresh
   `MATLAB_PREFDIR` fails earlier in `ApplicationService client-v1`, even after
   verified old probe processes are removed.
5. The core signed files and basic directories exist, but the root shows a
   copied/partially downloaded distribution layout, including a 13.1 GB
   `.downloading` artifact and `Setup/Crack` package directories. The current
   deployment cannot be treated as a clean installer-verified installation.

The audit does not identify one damaged DLL, and Windows Event Log supplies no
faulting-module record. The precise component defect remains below the level
that can be proven by this bounded read-only audit. The classification is that
the installation/ApplicationService deployment **appears corrupted or
incomplete**, not that a particular signed binary was shown to be altered.

## 8. Recommended next action — not executed

Do not use this `D:\matlab` tree for the G0 runtime gate until it is replaced
or repaired through an official MathWorks installer-managed workflow.

Recommended controlled next step:

1. Gracefully close the existing PID 16192 MATLAB desktop session through the
   user interface after preserving any user work.
2. Use an official R2024a installer to repair the installation, or install a
   clean R2024a copy into a new empty root. Do not copy DLLs manually, reuse the
   partial-download tree, or edit PATH/registry as an ad-hoc fix.
3. Afterward, independently verify `where matlab` and executable versions.
4. Re-run only the G0E base `-batch` marker, then the gated Simulink library
   load, then project `cd/addpath`. Resume G0 steering work only after all three
   exit cleanly without an orphan.

No repair, uninstall, reinstall, registry edit, PATH edit, DLL copy, preference
deletion, or process control was performed in G0E2.

## 9. Final status

**V2.1-G0E2 MATLAB RUNTIME ROOT CAUSE IDENTIFIED**

D-EKF V1 IS FROZEN.

K-KF V2.1 IS AN INDEPENDENT TRACK.

NO MODEL OR ALGORITHM FILE MAY BE MODIFIED.

NO SIMULATION OR CARSIM RUN IS AUTHORIZED.

V2.2 WAS NOT STARTED.
