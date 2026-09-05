function [y,reliability]=vy_dynamic_ekf_v1_17(w,modeCode)
%VY_DYNAMIC_EKF_V1_17 Online multi-rate Ay wrapper for isolated V1.17.
% modeCode is exactly one of 100, 50, or 20. Prediction and r update stay
% at 100 Hz; Ay is assimilated every 1, 2, or 5 EKF calls respectively.
persistent x P counter activeMode
modeCode=normalize_mode(modeCode);
if isempty(x)||isempty(P)||isempty(counter)||isempty(activeMode)||activeMode~=modeCode
    x=[0;0];P=.1*eye(2);counter=0;activeMode=modeCode;
end
stride=100/modeCode;useAy=mod(counter,stride)==0;stepIndex=counter;
w=w(:);u=w(1:5);z=w(6:7);
par=struct('m',1860,'Iz',2687.1,'a',1.18,'b',1.77,'track',1.575, ...
    'Rw',.393,'k_f',.78181,'k_r',1.09186);
cfg=struct('dt',.01,'Q',diag([1e-4,1e-4]), ...
    'R',diag([1e-2,3.365172961808e-4]),'denomEps',1e-12,'lambda',zeros(4,1));
[x,P,info]=vy_dynamic_ekf_step_v17(x,P,u,z,par,cfg,useAy);
Slog=zeros(2);Klog=zeros(2);
if useAy,Slog=info.S;Klog=info.K;else,Slog(2,2)=info.S;Klog(:,2)=info.K;end
y=zeros(69,1);y(1:2)=x;y(3:4)=[P(1,1);P(2,2)];y(5)=info.NIS;
y(6:9)=info.Fy;y(10:13)=info.alpha;y(14:15)=info.innovation;
y(16:17)=info.x_pred;y(18:21)=info.F(:);y(22:25)=info.H(:);
y(26:29)=info.P_prior(:);y(30:33)=info.P_noQ(:);y(34:37)=info.P_pred(:);
y(38:41)=Slog(:);y(42:45)=Klog(:);y(46:49)=P(:);y(50:51)=z;
y(52:55)=info.Fy_raw;y(56:59)=info.Fy_corrected;
y(60)=double(useAy);y(61)=stepIndex;y(62)=modeCode;y(63)=info.measurementDimension;
if useAy,y(64)=info.NIS;else,y(65)=info.NIS;end
y(66:67)=[info.P_pred(1,1);info.P_pred(2,2)];
y(68:69)=[P(1,1)/info.P_pred(1,1);P(2,2)/info.P_pred(2,2)];
if nargout>1
    reliability=struct('update_valid_D',logical(info.updateValid), ...
        'nis_valid_D',logical(info.updateValid), ...
        'measurementDimension_D',double(info.measurementDimension), ...
        'useAy_D',logical(useAy),'NIS_D',double(info.NIS));
end
counter=counter+1;
end

function m=normalize_mode(m)
if isempty(m)||~isscalar(m)||~isfinite(m),m=100;end
m=round(double(m));if ~(m==100||m==50||m==20),m=100;end
end
