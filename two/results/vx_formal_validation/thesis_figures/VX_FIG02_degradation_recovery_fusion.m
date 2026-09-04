% THESIS_FIGURE_ID: VX-FIG-02
% RECOMMENDED_TITLE: 轮速退化—恢复及自适应融合过程
% SCIENTIFIC_QUESTION: 轮速退化后rho是否下降、WSS是否降权并在恢复后重新启用
% SOURCE_RESULT_FILE: results/vx_formal_validation/VX_D1_formal.mat
% REQUIRED_SIGNALS: time, CarSim Vx, WSS, IMU, Fusion, rho_RL, rho_RR, alpha_W, alpha_I
% SOURCE_RUNTIME_CASE: D1
% GENERATED_FROM_FORMAL_RUNTIME: NO
% STYLE_SOURCE: results/vy_lifesig_v2_8a19_thesis_figures/generate_thesis_figures.js
% STYLE_SOURCE_SHA256: CCBF52A4D6192889E32814B3877947C6DCAF612F3E26AD84C03AC1DFAA069FAB
%
% This standalone script is deliberately paired with VX-FIG-02. It refuses
% to export a figure from historical or provenance-mismatched data.

thisFile = mfilename('fullpath');
projectRoot = fileparts(fileparts(fileparts(fileparts(thisFile))));
sourceFile = fullfile(projectRoot, 'results', 'vx_formal_validation', ...
    'VX_D1_formal.mat');
outputBase = fullfile(fileparts(thisFile), ...
    'VX_FIG02_degradation_recovery_fusion');

S = load(sourceFile, 'R');
assert(isfield(S, 'R') && isscalar(S.R), ...
    'VX:Figure02:MissingResult', 'SOURCE_RESULT_FILE must contain scalar R.');
R = S.R;
assert(isfield(R, 'metadata') && isfield(R.metadata, 'formalRuntime') ...
    && isequal(R.metadata.formalRuntime, true), ...
    'VX:Figure02:NotFormalRuntime', ...
    'Figure export is blocked: result is not a formal runtime.');
assert(strcmp(string(R.metadata.caseId), "D1"), ...
    'VX:Figure02:WrongCase', 'VX-FIG-02 requires formal case D1.');

t = double(R.time(:));
y = double(R.estY);
vxTrue = double(R.vxTrue(:));
assert(size(y, 2) == 38 && numel(t) == size(y, 1), ...
    'VX:Figure02:Interface', 'Expected aligned N-by-38 estY.');
assert(numel(vxTrue) == numel(t), ...
    'VX:Figure02:Alignment', 'time and vxTrue must be aligned.');

% Frozen Vy paper-figure palette and strokes.
C.black = [17 17 17] / 255;
C.blue = [0 114 178] / 255;
C.orange = [213 94 0] / 255;
C.green = [0 158 115] / 255;
C.grid = [216 216 216] / 255;
C.boundary = [168 168 168] / 255;

fig = figure('Color', 'w', 'Units', 'centimeters', ...
    'Position', [2 2 17.5 23.5], 'PaperPositionMode', 'auto');
tl = tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tl, 1);
hold(ax1, 'on');
plot(ax1, t, vxTrue, '-', 'Color', C.black, 'LineWidth', 2.6);
plot(ax1, t, y(:, 3), '-.', 'Color', C.blue, 'LineWidth', 2.0);
plot(ax1, t, y(:, 5), '--', 'Color', C.orange, 'LineWidth', 2.0);
plot(ax1, t, y(:, 1), '--', 'Color', C.green, 'LineWidth', 2.3);
hold(ax1, 'off');
ylabel(ax1, '纵向速度 / (m·s^{-1})');
title(ax1, '(a) 纵向速度估计', 'FontWeight', 'normal');
vx_apply_frozen_vy_axes(ax1, C);
legend(ax1, {'CarSim V_x', 'WSS', 'IMU', 'Fusion'}, ...
    'Location', 'northoutside', 'Orientation', 'horizontal', 'Box', 'off');

ax2 = nexttile(tl, 2);
hold(ax2, 'on');
plot(ax2, t, y(:, 18), '-', 'Color', C.blue, 'LineWidth', 2.0);
plot(ax2, t, y(:, 19), '--', 'Color', C.orange, 'LineWidth', 2.0);
hold(ax2, 'off');
ylabel(ax2, '车轮健康度 \rho_i');
ylim(ax2, [-0.03 1.03]);
title(ax2, '(b) 受影响车轮健康度', 'FontWeight', 'normal');
vx_apply_frozen_vy_axes(ax2, C);
legend(ax2, {'\rho_{RL}', '\rho_{RR}'}, 'Interpreter', 'tex', ...
    'Location', 'northoutside', 'Orientation', 'horizontal', 'Box', 'off');

ax3 = nexttile(tl, 3);
hold(ax3, 'on');
plot(ax3, t, y(:, 30), '-', 'Color', C.blue, 'LineWidth', 2.0);
plot(ax3, t, y(:, 31), '--', 'Color', C.orange, 'LineWidth', 2.0);
hold(ax3, 'off');
xlabel(ax3, '时间 / s');
ylabel(ax3, '融合权重 \alpha_i');
ylim(ax3, [-0.03 1.03]);
title(ax3, '(c) 融合权重', 'FontWeight', 'normal');
vx_apply_frozen_vy_axes(ax3, C);
legend(ax3, {'\alpha_W', '\alpha_I'}, 'Interpreter', 'tex', ...
    'Location', 'northoutside', 'Orientation', 'horizontal', 'Box', 'off');

% Frozen, preregistered D1 phase boundaries; neutral dashed Vy boundary style.
for ax = [ax1 ax2 ax3]
    xline(ax, 3.0, '--', 'Color', C.boundary, 'LineWidth', 1.2, ...
        'HandleVisibility', 'off');
    xline(ax, 8.0, '--', 'Color', C.boundary, 'LineWidth', 1.2, ...
        'HandleVisibility', 'off');
    xline(ax, 12.0, '--', 'Color', C.boundary, 'LineWidth', 1.2, ...
        'HandleVisibility', 'off');
end
linkaxes([ax1 ax2 ax3], 'x');
set([ax1 ax2 ax3], 'XLim', [min(t) max(t)]);

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
