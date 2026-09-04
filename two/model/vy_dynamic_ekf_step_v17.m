function [x_new,P_new,info]=vy_dynamic_ekf_step_v17(x,P,u,z,par,cfg,useAy)
%VY_DYNAMIC_EKF_STEP_V17 V1.13 prediction with scheduled Ay assimilation.
% Prediction and the yaw-rate update always execute at 100 Hz.  When
% useAy is false, a genuine one-dimensional yaw-rate Joseph update is used.
narginchk(7,7);
useAy=logical(useAy);
[x_full,P_full,base]=vy_dynamic_ekf_step_v13(x,P,u,z,par,cfg);
if useAy
    x_new=x_full;P_new=P_full;info=base;
    info.measurementDimension=2;info.useAy=true;
    info.NIS_2D=base.NIS;info.NIS_r_only=NaN;
    return
end

R=cfg.R;if isscalar(R),R=R*eye(2);end;Rr=R(2,2);
Hr=base.H(2,:);innovationR=z(2)-base.h_pred(2);
S=Hr*base.P_pred*Hr'+Rr;K=zeros(2,1);x_new=base.x_pred;P_new=base.P_pred;NIS=0;updateValid=false;
if isfinite(S)&&S>1e-12&&isfinite(innovationR)
    K=(base.P_pred*Hr')/S;
    x_new=base.x_pred+K*innovationR;
    I=eye(2);P_new=(I-K*Hr)*base.P_pred*(I-K*Hr)'+K*Rr*K';
    P_new=local_psd(P_new);NIS=innovationR^2/S;
    updateValid=isfinite(NIS)&&all(isfinite(x_new))&&all(isfinite(P_new(:)));
    if ~updateValid,NIS=0;end
end
if any(~isfinite(x_new)),x_new=base.x_pred;end
if any(~isfinite(P_new(:))),P_new=base.P_pred;end
info=base;info.innovation=[base.innovation(1);innovationR];
info.S=S;info.K=K;info.NIS=NIS;info.updateValid=updateValid;info.measurementDimension=1;
info.useAy=false;info.NIS_2D=NaN;info.NIS_r_only=NIS;
end

function P=local_psd(P)
P=.5*(P+P');[V,D]=eig(P);d=real(diag(D));d(d<0)=0;
P=V*diag(d)*V';P=.5*(P+P');
end
