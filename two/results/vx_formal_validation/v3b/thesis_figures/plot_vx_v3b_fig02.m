% THESIS_FIGURE_ID: VX-FIG-02
% RECOMMENDED_TITLE: 轮速退化—恢复及自适应融合过程
% SCIENTIFIC_QUESTION: 同一次低附着加速—减速中，后轮驱动/制动滑移是否触发健康度与融合权重响应并恢复
% SOURCE_RESULT_FILE: results/vx_formal_validation/v3b/runtime/VX_CS_formal_raw.mat
% REQUIRED_SIGNALS: time, CarSim Vx, WSS, IMU, Fusion, rho_RL, rho_RR, alpha_W, alpha_I
% SOURCE_RUNTIME_CASE: VX-CS
% GENERATED_FROM_FORMAL_RUNTIME: YES
% STYLE_SOURCE: D:/UsersData/桌面/two/results/vy_lifesig_v2_8a19_thesis_figures/generate_thesis_figures.js
% STYLE_SOURCE_SHA256: CCBF52A4D6192889E32814B3877947C6DCAF612F3E26AD84C03AC1DFAA069FAB

thisFile=mfilename('fullpath');
projectRoot=fileparts(fileparts(fileparts(fileparts(fileparts(thisFile)))));
sourceFile=fullfile(projectRoot,'results','vx_formal_validation','v3b','runtime','VX_CS_formal_raw.mat');
analysisFile=fullfile(projectRoot,'results','vx_formal_validation','v3b','runtime','VX_CS_analysis.mat');
outputBase=fullfile(fileparts(thisFile),'VX_FIG02_combined_slip_recovery_fusion');
S=load(sourceFile,'R');Q=load(analysisFile,'A');R=S.R;A=Q.A;
assert(R.metadata.formalRuntime&&strcmp(R.metadata.caseId,'VX-CS')&&A.physicalGatePass, ...
    'VX:V3B:Figure02:Evidence','Fresh formal VX-CS with both gates PASS is required.');
t=double(R.time(:));y=double(R.estY);vxTrue=double(R.vxTrue(:));
assert(size(y,2)==38&&numel(t)==size(y,1)&&numel(vxTrue)==numel(t),'VX:V3B:Figure02:Interface');
freeze=jsondecode(fileread(R.configuration.freezeFile));

% Exact frozen Vy palette, line-width hierarchy, grids, typography and geometry.
C.black=[17 17 17]/255;C.blue=[0 114 178]/255;
C.orange=[213 94 0]/255;C.green=[0 158 115]/255;
C.grid=[216 216 216]/255;C.boundary=[168 168 168]/255;
fig=figure('Color','w','Units','centimeters','Position',[2 2 17.5 23.5],'PaperPositionMode','auto');
tl=tiledlayout(fig,3,1,'TileSpacing','compact','Padding','compact');
ax1=nexttile(tl,1);hold(ax1,'on');
plot(ax1,t,vxTrue,'-','Color',C.black,'LineWidth',2.6);
plot(ax1,t,y(:,3),'-.','Color',C.blue,'LineWidth',2.0);
plot(ax1,t,y(:,5),'--','Color',C.orange,'LineWidth',2.0);
plot(ax1,t,y(:,1),'--','Color',C.green,'LineWidth',2.3);hold(ax1,'off');
ylabel(ax1,'Longitudinal speed / (m·s^{-1})');
title(ax1,'(a) Longitudinal speed estimation','FontWeight','normal');
vx_apply_frozen_vy_axes(ax1,C);legend(ax1,{'CarSim V_x','WSS','IMU','Fusion'}, ...
    'Location','northoutside','Orientation','horizontal','Box','off');

ax2=nexttile(tl,2);hold(ax2,'on');
plot(ax2,t,y(:,18),'-','Color',C.blue,'LineWidth',2.0);
plot(ax2,t,y(:,19),'--','Color',C.orange,'LineWidth',2.0);hold(ax2,'off');
ylabel(ax2,'Rear-wheel health \rho_i');ylim(ax2,[-0.03 1.03]);
title(ax2,'(b) Rear-wheel health','FontWeight','normal');vx_apply_frozen_vy_axes(ax2,C);
legend(ax2,{'\rho_{RL}','\rho_{RR}'},'Interpreter','tex','Location','northoutside','Orientation','horizontal','Box','off');

ax3=nexttile(tl,3);hold(ax3,'on');
plot(ax3,t,y(:,30),'-','Color',C.blue,'LineWidth',2.0);
plot(ax3,t,y(:,31),'--','Color',C.orange,'LineWidth',2.0);hold(ax3,'off');
xlabel(ax3,'Time / s');ylabel(ax3,'Fusion weight \alpha_i');ylim(ax3,[-0.03 1.03]);
title(ax3,'(c) Fusion weights','FontWeight','normal');vx_apply_frozen_vy_axes(ax3,C);
legend(ax3,{'\alpha_W','\alpha_I'},'Interpreter','tex','Location','northoutside','Orientation','horizontal','Box','off');

boundaries=[3 7 9 double(freeze.brakeRampEnd_s) double(freeze.brakeAnalysisEnd_s)];
for ax=[ax1 ax2 ax3]
    for boundary=boundaries
        xline(ax,boundary,'--','Color',C.boundary,'LineWidth',1.2,'HandleVisibility','off');
    end
end
linkaxes([ax1 ax2 ax3],'x');set([ax1 ax2 ax3],'XLim',[min(t) max(t)]);
exportgraphics(fig,[outputBase '.png'],'Resolution',600);
exportgraphics(fig,[outputBase '.pdf'],'ContentType','vector');

function vx_apply_frozen_vy_axes(ax,C)
set(ax,'FontName','Times New Roman','FontSize',9.5,'LineWidth',1.2, ...
    'Box','on','TickDir','out','XColor',C.black,'YColor',C.black, ...
    'GridColor',C.grid,'GridAlpha',0.55,'MinorGridColor',C.grid,'MinorGridAlpha',0.0);
grid(ax,'on');ax.XMinorGrid='off';ax.YMinorGrid='off';
end
