% THESIS_FIGURE_ID: VX-FIG-01
% RECOMMENDED_TITLE: 正常动态工况下纵向速度估计结果
% SCIENTIFIC_QUESTION: 正常纵向动态条件下，两局部轨迹和融合估计是否保持有效
% SOURCE_RESULT_FILE: results/vx_formal_validation/VX_N2_formal.mat
% REQUIRED_SIGNALS: time, Ax, CarSim Vx, WSS, IMU, Fusion
% SOURCE_RUNTIME_CASE: N2
% GENERATED_FROM_FORMAL_RUNTIME: NO
% STYLE_SOURCE: results/vy_lifesig_v2_8a19_thesis_figures/generate_thesis_figures.js
% STYLE_SOURCE_SHA256: CCBF52A4D6192889E32814B3877947C6DCAF612F3E26AD84C03AC1DFAA069FAB
%
% This standalone script is deliberately paired with VX-FIG-01. It refuses
% to export a figure from historical or provenance-mismatched data.

thisFile = mfilename('fullpath');
projectRoot = fileparts(fileparts(fileparts(fileparts(thisFile))));
sourceFile = fullfile(projectRoot, 'results', 'vx_formal_validation', ...
    'VX_N2_formal.mat');
outputBase = fullfile(fileparts(thisFile), ...
    'VX_FIG01_normal_dynamic_estimation');

S = load(sourceFile, 'R');
assert(isfield(S, 'R') && isscalar(S.R), ...
    'VX:Figure01:MissingResult', 'SOURCE_RESULT_FILE must contain scalar R.');
R = S.R;
assert(isfield(R, 'metadata') && isfield(R.metadata, 'formalRuntime') ...
    && isequal(R.metadata.formalRuntime, true), ...
    'VX:Figure01:NotFormalRuntime', ...
    'Figure export is blocked: result is not a formal runtime.');
assert(strcmp(string(R.metadata.caseId), "N2"), ...
    'VX:Figure01:WrongCase', 'VX-FIG-01 requires formal case N2.');

t = double(R.time(:));
y = double(R.estY);
vxTrue = double(R.vxTrue(:));
ax = double(R.Ax(:));
assert(size(y, 2) == 38 && numel(t) == size(y, 1), ...
    'VX:Figure01:Interface', 'Expected aligned N-by-38 estY.');
assert(numel(vxTrue) == numel(t) && numel(ax) == numel(t), ...
    'VX:Figure01:Alignment', 'time, vxTrue and Ax must be aligned.');

% Frozen Vy paper-figure palette and strokes.
C.black = [17 17 17] / 255;
C.blue = [0 114 178] / 255;
C.orange = [213 94 0] / 255;
C.green = [0 158 115] / 255;
C.grid = [216 216 216] / 255;

fig = figure('Color', 'w', 'Units', 'centimeters', ...
    'Position', [2 2 17.5 15.0], 'PaperPositionMode', 'auto');
tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tl, 1);
plot(ax1, t, ax, '-', 'Color', C.black, 'LineWidth', 2.6);
ylabel(ax1, 'A_x / (m·s^{-2})');
title(ax1, '(a) 纵向动态输入', 'FontWeight', 'normal');
vx_apply_frozen_vy_axes(ax1, C);
legend(ax1, {'A_x'}, 'Location', 'northoutside', ...
    'Orientation', 'horizontal', 'Box', 'off');

ax2 = nexttile(tl, 2);
hold(ax2, 'on');
plot(ax2, t, vxTrue, '-', 'Color', C.black, 'LineWidth', 2.6);
plot(ax2, t, y(:, 3), '-.', 'Color', C.blue, 'LineWidth', 2.0);
plot(ax2, t, y(:, 5), '--', 'Color', C.orange, 'LineWidth', 2.0);
plot(ax2, t, y(:, 1), '--', 'Color', C.green, 'LineWidth', 2.3);
hold(ax2, 'off');
xlabel(ax2, '时间 / s');
ylabel(ax2, '纵向速度 / (m·s^{-1})');
title(ax2, '(b) 纵向速度估计', 'FontWeight', 'normal');
vx_apply_frozen_vy_axes(ax2, C);
legend(ax2, {'CarSim V_x', 'WSS', 'IMU', 'Fusion'}, ...
    'Location', 'northoutside', 'Orientation', 'horizontal', 'Box', 'off');
linkaxes([ax1 ax2], 'x');
set([ax1 ax2], 'XLim', [min(t) max(t)]);

exportgraphics(fig, [outputBase '.png'], 'Resolution', 600);
exportgraphics(fig, [outputBase '.pdf'], 'ContentType', 'vector');
exportgraphics(fig, [outputBase '.svg'], 'ContentType', 'vector');

function vx_apply_frozen_vy_axes(ax, C)
% MATLAB rendering of the frozen Vy thesis style. MATLAB exposes named
% dash styles rather than arbitrary SVG dash arrays; '-.' and '--' are the
% closest native equivalents to Vy's 11-4-2-4 and 7-4/12-3 patterns.
set(ax, 'FontName', 'Times New Roman', 'FontSize', 9.5, ...
    'LineWidth', 1.2, 'Box', 'on', 'TickDir', 'out', ...
    'XColor', C.black, 'YColor', C.black, ...
    'GridColor', C.grid, 'GridAlpha', 0.55, ...
    'MinorGridColor', C.grid, 'MinorGridAlpha', 0.0);
grid(ax, 'on');
ax.XMinorGrid = 'off';
ax.YMinorGrid = 'off';
end
