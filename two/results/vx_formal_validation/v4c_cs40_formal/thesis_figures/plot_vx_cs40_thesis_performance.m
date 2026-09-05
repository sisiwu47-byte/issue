function files = plot_vx_cs40_thesis_performance()
% THESIS_FIGURE_ID: VX-FIG-CS40-PERFORMANCE
% RECOMMENDED_TITLE: 低附着加减速工况下纵向速度估计结果
% SCIENTIFIC_QUESTION: 正确初始状态下，Fusion相对Traditional WSS能否降低低附着加减速误差
% SOURCE_RESULT_FILE: results/vx_formal_validation/v4c_cs40_formal/runtime/VX_CS40_formal_raw.mat
% REQUIRED_SIGNALS: time, CarSim Vx, Traditional WSS, Fusion
% SOURCE_RUNTIME_CASE: VX-CS40 (frozen A1)
% GENERATED_FROM_FORMAL_RUNTIME: YES
% STYLE_SOURCE: D:/UsersData/桌面/two/results/vy_lifesig_v2_8a19_thesis_figures/generate_thesis_figures.js
% STYLE_SOURCE_SHA256: CCBF52A4D6192889E32814B3877947C6DCAF612F3E26AD84C03AC1DFAA069FAB

thisFile=mfilename('fullpath');figDir=fileparts(thisFile);
root=fileparts(fileparts(fileparts(fileparts(figDir))));
rawFile=fullfile(root,'results','vx_formal_validation','v4c_cs40_formal','runtime','VX_CS40_formal_raw.mat');
derivedFile=fullfile(root,'results','vx_formal_validation','v4c_cs40_formal','VX_CS40_traditional_wss.mat');
S=load(rawFile,'R');Q=load(derivedFile,'D');R=S.R;D=Q.D;
assert(R.metadata.formalRuntime&&strcmp(R.metadata.verdict,'VX_CS40_V4C_FORMAL_PASS'), ...
    'VX:V4C:FigurePerformanceEvidence');
t=double(R.time(:));vxTrue=double(R.vxTrue(:));vxTraditional=double(D.vxTraditional(:));
vxFusion=double(R.estY(:,1));assert(numel(t)==numel(vxTraditional),'VX:V4C:FigurePerformanceInterface');
eFusion=vxFusion-vxTrue;

% Frozen Vy palette, hierarchy, axes, grid, typography, spacing and 175 mm width.
C.black=[17 17 17]/255;C.blue=[0 114 178]/255;C.green=[0 158 115]/255;
C.grid=[216 216 216]/255;C.boundary=[168 168 168]/255;
fig=figure('Color','w','Units','centimeters','Position',[2 2 17.5 15.0],'PaperPositionMode','auto');
tl=tiledlayout(fig,2,1,'TileSpacing','compact','Padding','compact');
ax1=nexttile(tl,1);hold(ax1,'on');
plot(ax1,t,vxTrue,'-','Color',C.black,'LineWidth',2.6);
plot(ax1,t,vxTraditional,'-.','Color',C.blue,'LineWidth',2.0);
plot(ax1,t,vxFusion,'--','Color',C.green,'LineWidth',2.3);hold(ax1,'off');
ylabel(ax1,'Longitudinal speed / (m·s^{-1})');
title(ax1,'(a) Longitudinal speed estimation','FontWeight','normal');apply_frozen_vy_axes(ax1,C);
legend(ax1,{'CarSim V_x','Traditional WSS','Fusion'},'Location','northoutside', ...
    'Orientation','horizontal','Box','off');
ax2=nexttile(tl,2);hold(ax2,'on');
plot(ax2,t,eFusion,'--','Color',C.green,'LineWidth',2.3);
yline(ax2,0,'-','Color',C.black,'LineWidth',1.0,'HandleVisibility','off');hold(ax2,'off');
xlabel(ax2,'Time / s');ylabel(ax2,'Fusion estimation error / (m·s^{-1})');
title(ax2,'(b) Fusion estimation error','FontWeight','normal');apply_frozen_vy_axes(ax2,C);
finiteFusionError=eFusion(isfinite(eFusion));assert(~isempty(finiteFusionError),'VX:V4C:FigureFusionError');
eMax=max(abs(finiteFusionError));eLimit=max(1.15*eMax,0.05);ylim(ax2,[-eLimit eLimit]);
legend(ax2,{'Fusion error'},'Location','northoutside', ...
    'Orientation','horizontal','Box','off');
for ax=[ax1 ax2]
    for boundary=[3 6 9 11.5]
        xline(ax,boundary,'--','Color',C.boundary,'LineWidth',1.2,'HandleVisibility','off');
    end
end
linkaxes([ax1 ax2],'x');set([ax1 ax2],'XLim',[0 16]);
base=fullfile(figDir,'VX_FIG_CS40_longitudinal_speed_performance');
exportgraphics(fig,[base '.png'],'Resolution',600);exportgraphics(fig,[base '.pdf'],'ContentType','vector');
print(fig,[base '.svg'],'-dsvg');close(fig);
files=struct('png',[base '.png'],'pdf',[base '.pdf'],'svg',[base '.svg'],'plottingCode',thisFile);
end

function apply_frozen_vy_axes(ax,C)
set(ax,'FontName','Times New Roman','FontSize',9.5,'LineWidth',1.2, ...
    'Box','on','TickDir','out','XColor',C.black,'YColor',C.black, ...
    'GridColor',C.grid,'GridAlpha',0.55,'MinorGridColor',C.grid,'MinorGridAlpha',0.0);
grid(ax,'on');ax.XMinorGrid='off';ax.YMinorGrid='off';
end
