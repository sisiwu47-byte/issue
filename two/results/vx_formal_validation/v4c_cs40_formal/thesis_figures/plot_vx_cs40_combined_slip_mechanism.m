function files = plot_vx_cs40_combined_slip_mechanism()
% THESIS_FIGURE_ID: VX-FIG-CS40-MECHANISM
% RECOMMENDED_TITLE: 后轮驱动/制动滑移与自适应融合机理
% SCIENTIFIC_QUESTION: 后轮物理滑移是否伴随wheel-health下降及WSS/IMU融合权重响应
% SOURCE_RESULT_FILE: results/vx_formal_validation/v4c_cs40_formal/runtime/VX_CS40_formal_raw.mat
% REQUIRED_SIGNALS: time, Vx truth, rear omega, rho_RL, rho_RR, alpha_W, alpha_I
% SOURCE_RUNTIME_CASE: VX-CS40 (frozen A1)
% GENERATED_FROM_FORMAL_RUNTIME: YES
% STYLE_SOURCE: D:/UsersData/桌面/two/results/vy_lifesig_v2_8a19_thesis_figures/generate_thesis_figures.js
% STYLE_SOURCE_SHA256: CCBF52A4D6192889E32814B3877947C6DCAF612F3E26AD84C03AC1DFAA069FAB

thisFile=mfilename('fullpath');figDir=fileparts(thisFile);
root=fileparts(fileparts(fileparts(fileparts(figDir))));
rawFile=fullfile(root,'results','vx_formal_validation','v4c_cs40_formal','runtime','VX_CS40_formal_raw.mat');
S=load(rawFile,'R');R=S.R;
assert(R.metadata.formalRuntime&&strcmp(R.metadata.verdict,'VX_CS40_V4C_FORMAL_PASS')&& ...
    R.metadata.driveGatePass&&R.metadata.brakeGatePass,'VX:V4C:FigureMechanismEvidence');
t=double(R.time(:));vxTrue=double(R.vxTrue(:));U=double(R.estU);Y=double(R.estY);
assert(size(U,2)==18&&size(Y,2)==38&&size(U,1)==numel(t)&&size(Y,1)==numel(t), ...
    'VX:V4C:FigureMechanismInterface');
kappa=(0.393.*U(:,1:4)-vxTrue)./max(abs(vxTrue),1);kappaRear=kappa(:,3:4);

% Frozen Vy palette, hierarchy, axes, grid, typography, spacing and 175 mm width.
C.black=[17 17 17]/255;C.blue=[0 114 178]/255;C.orange=[213 94 0]/255;
C.green=[0 158 115]/255;C.grid=[216 216 216]/255;C.boundary=[168 168 168]/255;
C.threshold=[163 58 43]/255;
fig=figure('Color','w','Units','centimeters','Position',[2 2 17.5 23.5],'PaperPositionMode','auto');
tl=tiledlayout(fig,3,1,'TileSpacing','compact','Padding','compact');
ax1=nexttile(tl,1);hold(ax1,'on');
plot(ax1,t,kappaRear(:,1),'-','Color',C.blue,'LineWidth',2.0);
plot(ax1,t,kappaRear(:,2),'--','Color',C.orange,'LineWidth',2.0);
yline(ax1,0.10,'--','Color',C.threshold,'LineWidth',1.5,'HandleVisibility','off');
yline(ax1,-0.10,'--','Color',C.threshold,'LineWidth',1.5,'HandleVisibility','off');hold(ax1,'off');
ylabel(ax1,'Rear slip ratio \kappa_i');title(ax1,'(a) Rear physical slip ratio','FontWeight','normal');
apply_frozen_vy_axes(ax1,C);legend(ax1,{'\kappa_{RL}','\kappa_{RR}'},'Interpreter','tex', ...
    'Location','northoutside','Orientation','horizontal','Box','off');
ax2=nexttile(tl,2);hold(ax2,'on');
plot(ax2,t,Y(:,18),'-','Color',C.blue,'LineWidth',2.0);
plot(ax2,t,Y(:,19),'--','Color',C.orange,'LineWidth',2.0);hold(ax2,'off');
ylabel(ax2,'Rear-wheel health \rho_i');ylim(ax2,[-0.03 1.03]);
title(ax2,'(b) Rear-wheel health','FontWeight','normal');apply_frozen_vy_axes(ax2,C);
legend(ax2,{'\rho_{RL}','\rho_{RR}'},'Interpreter','tex','Location','northoutside', ...
    'Orientation','horizontal','Box','off');
ax3=nexttile(tl,3);hold(ax3,'on');
plot(ax3,t,Y(:,30),'-','Color',C.blue,'LineWidth',2.0);
plot(ax3,t,Y(:,31),'--','Color',C.orange,'LineWidth',2.0);hold(ax3,'off');
xlabel(ax3,'Time / s');ylabel(ax3,'Fusion weight \alpha_i');ylim(ax3,[-0.03 1.03]);
title(ax3,'(c) Fusion weights','FontWeight','normal');apply_frozen_vy_axes(ax3,C);
legend(ax3,{'\alpha_W','\alpha_I'},'Interpreter','tex','Location','northoutside', ...
    'Orientation','horizontal','Box','off');
for ax=[ax1 ax2 ax3]
    for boundary=[3 6 7 9 11.5 12]
        xline(ax,boundary,'--','Color',C.boundary,'LineWidth',1.2,'HandleVisibility','off');
    end
end
linkaxes([ax1 ax2 ax3],'x');set([ax1 ax2 ax3],'XLim',[0 16]);
base=fullfile(figDir,'VX_FIG_CS40_combined_slip_mechanism');
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
