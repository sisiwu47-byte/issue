function summary = analyze_vy_kkf_v2_1c0_preflight(resultFile)
%ANALYZE_VY_KKF_V2_1C0_PREFLIGHT Read and summarize saved C0 evidence.

if nargin < 1 || isempty(resultFile)
    root = fileparts(fileparts(mfilename('fullpath')));
    resultFile = fullfile(root, 'results', 'vy_kkf_v2_1c0_preflight.mat');
end
assert(isfile(resultFile), 'V2.1-C0 result MAT does not exist.');
saved = load(resultFile, 'report');
assert(isfield(saved, 'report') && isstruct(saved.report), ...
    'V2.1-C0 result MAT does not contain a report struct.');
r = saved.report;

summary = struct();
summary.simulationCompleted = r.simulationCompleted;
summary.runtimeError = r.runtimeError;
summary.timing = r.timing;
summary.reset = r.reset;
summary.sanity = r.sanity;
summary.gates = r.gates;
summary.frozenHashesUnchanged = r.frozenHashesUnchanged;
summary.carSim = r.carSim;

fprintf(['V2_1C0_EVIDENCE|completed=%d|samples=%d|t=[%.17g %.17g]|' ...
    'dt=[%.17g %.17g %.17g]|resetHigh=%d|finite=%d/%d/%d|' ...
    'PAsym=%.17g|minPEig=%.17g|hash=%d\n'], ...
    r.simulationCompleted, r.timing.sampleCount, ...
    r.timing.tStart, r.timing.tEnd, r.timing.dtMin, ...
    r.timing.dtMedian, r.timing.dtMax, r.reset.highCount, ...
    r.sanity.allXFinite, r.sanity.allPFinite, ...
    r.sanity.allDiagFinite, r.sanity.maxPAsymmetry, ...
    r.sanity.minimumPEigenvalue, r.frozenHashesUnchanged);
end
