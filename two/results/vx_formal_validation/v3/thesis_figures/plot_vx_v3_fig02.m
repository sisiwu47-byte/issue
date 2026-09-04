% THESIS_FIGURE_ID: VX-FIG-02
% RECOMMENDED_TITLE: 轮速退化—恢复及自适应融合过程
% SCIENTIFIC_QUESTION: 低附组合加速/制动中，后轮退化是否触发健康度与融合权重响应并恢复
% SOURCE_RESULT_FILE: results/vx_formal_validation/v3/runtime/VX_DR_formal_raw.mat
% REQUIRED_SIGNALS: time, CarSim Vx, WSS, IMU, Fusion, rho_RL, rho_RR, alpha_W, alpha_I
% SOURCE_RUNTIME_CASE: VX-DR
% GENERATED_FROM_FORMAL_RUNTIME: NO
% STYLE_SOURCE: results/vy_lifesig_v2_8a19_thesis_figures/generate_thesis_figures.js
% STYLE_SOURCE_SHA256: CCBF52A4D6192889E32814B3877947C6DCAF612F3E26AD84C03AC1DFAA069FAB

thisFile = mfilename('fullpath');
projectRoot = fileparts(fileparts(fileparts(fileparts(fileparts(thisFile)))));
sourceFile = fullfile(projectRoot, 'results', 'vx_formal_validation', ...
    'v3', 'runtime', 'VX_DR_formal_raw.mat');
outputBase = fullfile(fileparts(thisFile), 'VX_FIG02_degradation_recovery_fusion');

S = load(sourceFile, 'R');
assert(isfield(S,'R') && isscalar(S.R), ...
    'VX:V3:Figure02:MissingResult','Formal source must contain scalar R.');
R = S.R;
assert(isfield(R,'metadata') && isfield(R.metadata,'formalRuntime') ...
    && isequal(R.metadata.formalRuntime,true), ...
    'VX:V3:Figure02:NotFormal','Formal runtime evidence is required.');
assert(strcmp(string(R.metadata.caseId),"VX-DR"), ...
    'VX:V3:Figure02:WrongCase','VX-FIG-02 requires VX-DR.');
assert(isfield(R.metadata,'physicalGatePass') && R.metadata.physicalGatePass, ...
    'VX:V3:Figure02:PhysicalGate','Both VX-DR physical gates must pass.');

t=double(R.time(:)); y=double(R.estY); vxTrue=double(R.vxTrue(:));
assert(size(y,2)==38 && numel(t)==size(y,1) && numel(vxTrue)==numel(t), ...
    'VX:V3:Figure02:Interface','Required aligned signals are missing.');

C.black=[17 17 17]/255; C.blue=[0 114 178]/255;
C.orange=[213 94 0]/255; C.green=[0 158 115]/255;
C.grid=[216 216 216]/255; C.boundary=[168 168 168]/255;

fig=figure('Color','w','Units','centimeters', ...
    'Position',[2 2 17.5 23.5],'PaperPositionMode','auto');
tl=tiledlayout(fig,3,1,'TileSpacing','compact','Padding','compact');
ax1=nexttile(tl,1); hold(ax1,'on');
plot(ax1,t,vxTrue,'-','Color',C.black,'LineWidth',2.6);
plot(ax1,t,y(:,3),'-.','Color',C.blue,'LineWidth',2.0);
plot(ax1,t,y(:,5),'--','Color',C.orange,'LineWidth',2.0);
plot(ax1,t,y(:,1),'--','Color',C.green,'LineWidth',2.3); hold(ax1,'off');
ylabel(ax1,'纵向速度 / (m·s^{-1})');
title(ax1,'(a) 纵向速度估计','FontWeight','normal');
vx_apply_frozen_vy_axes(ax1,C);
legend(ax1,{'CarSim V_x','WSS','IMU','Fusion'}, ...
    'Location','northoutside','Orientation','horizontal','Box','off');

ax2=nexttile(tl,2); hold(ax2,'on');
plot(ax2,t,y(:,18),'-','Color',C.blue,'LineWidth',2.0);
plot(ax2,t,y(:,19),'--','Color',C.orange,'LineWidth',2.0); hold(ax2,'off');
ylabel(ax2,'车轮健康度 \rho_i'); ylim(ax2,[-0.03 1.03]);
title(ax2,'(b) 受影响车轮健康度','FontWeight','normal');
vx_apply_frozen_vy_axes(ax2,C);
legend(ax2,{'\rho_{RL}','\rho_{RR}'},'Interpreter','tex', ...
    'Location','northoutside','Orientation','horizontal','Box','off');

ax3=nexttile(tl,3); hold(ax3,'on');
plot(ax3,t,y(:,30),'-','Color',C.blue,'LineWidth',2.0);
plot(ax3,t,y(:,31),'--','Color',C.orange,'LineWidth',2.0); hold(ax3,'off');
xlabel(ax3,'时间 / s'); ylabel(ax3,'融合权重 \alpha_i'); ylim(ax3,[-0.03 1.03]);
title(ax3,'(c) 融合权重','FontWeight','normal');
vx_apply_frozen_vy_axes(ax3,C);
legend(ax3,{'\alpha_W','\alpha_I'},'Interpreter','tex', ...
    'Location','northoutside','Orientation','horizontal','Box','off');

for ax=[ax1 ax2 ax3]
    for boundary=[3 7 9 13]
        xline(ax,boundary,'--','Color',C.boundary,'LineWidth',1.2, ...
            'HandleVisibility','off');
    end
end
linkaxes([ax1 ax2 ax3],'x'); set([ax1 ax2 ax3],'XLim',[min(t) max(t)]);

exportgraphics(fig,[outputBase '.png'],'Resolution',600);
exportgraphics(fig,[outputBase '.pdf'],'ContentType','vector');
exportgraphics(fig,[outputBase '.svg'],'ContentType','vector');

function vx_apply_frozen_vy_axes(ax,C)
set(ax,'FontName','Times New Roman','FontSize',9.5,'LineWidth',1.2, ...
    'Box','on','TickDir','out','XColor',C.black,'YColor',C.black, ...
    'GridColor',C.grid,'GridAlpha',0.55, ...
    'MinorGridColor',C.grid,'MinorGridAlpha',0.0);
grid(ax,'on'); ax.XMinorGrid='off'; ax.YMinorGrid='off';
end
