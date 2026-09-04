function [x_new,P_new,info]=vy_dynamic_ekf_step_v13(x,P,u,z,par,cfg)
%VY_DYNAMIC_EKF_STEP_V13 Formal online axle-scaled D-EKF core.
% Only the lateral forces are scaled after tireForceLocal:
% front by par.k_f and rear by par.k_r. Prediction, measurement and their
% numerical Jacobians all use the same corrected forces.
narginchk(6,6);
x=safe_vector(x,2,[0;0]); if isempty(P),P=eye(2);end;P=safe_posdef(P);P_prior=P;
u=safe_vector(u,5,zeros(5,1));z=safe_vector(z,2,[0;0]);
vx=u(1);d=u(2:5);
m=scalar_field(par,'m',1860);Iz=scalar_field(par,'Iz',2687.1);
a=scalar_field(par,'a',1.18);b=scalar_field(par,'b',1.77);
track=scalar_field(par,'track',1.575);
kf=scalar_field(par,'k_f',1);kr=scalar_field(par,'k_r',1);
if kf<=0||~isfinite(kf),kf=1;end;if kr<=0||~isfinite(kr),kr=1;end
dt=scalar_field(cfg,'dt',0.01);
if dt<=0,dt=scalar_field(cfg,'Ts',scalar_field(cfg,'Ts_est',0.01));end
if ~isfinite(dt)||dt<=0,dt=0.01;end
Q=matrix2(cfg,'Q',1e-6*eye(2));R=matrix2(cfg,'R',diag([1e-2;1e-2]));
epsDiff=scalar_field(cfg,'epsDiff',sqrt(eps));if epsDiff<=0||~isfinite(epsDiff),epsDiff=sqrt(eps);end
denomEps=scalar_field(cfg,'denomEps',1e-12);lambda=vector4_field(cfg,'lambda',zeros(4,1));
if isstruct(par)&&isfield(par,'fz')&&numel(par.fz)>=4,fz=par.fz(:);fz=fz(1:4);
else,g=9.81;ff=m*g*b/max(a+b,eps);fr=m*g*a/max(a+b,eps);fz=[ff;ff;fr;fr]/2;end

[f,~,~,~,~]=dynamics(x,vx,d,m,Iz,a,b,track,fz,lambda,kf,kr);
x_pred=x+dt*f;if any(~isfinite(x_pred)),x_pred=x;end
gfun=@(xl) transition(xl,vx,d,m,Iz,a,b,track,fz,lambda,kf,kr,dt);
F=jacobian(gfun,x,epsDiff);P_noQ=F*P_prior*F';P_pred=enforce_psd(P_noQ+Q);

[h_pred,alpha,FyCorrected,Fx,FyRaw]=measurement(x_pred,vx,d,m,a,b,track,fz,lambda,kf,kr);
hfun=@(xl) measurement(xl,vx,d,m,a,b,track,fz,lambda,kf,kr);
H=jacobian(hfun,x_pred,epsDiff);
innovation=z-h_pred;K=zeros(2);S=H*P_pred*H'+R;S=0.5*(S+S');P_new=P_pred;NIS=0;updateValid=false;
valid=all(isfinite(innovation))&&all(isfinite(S(:)))&&finite_det2(S,denomEps);
if valid
    try
        Sinv=inv(S);K=(P_pred*H')*Sinv;x_new=x_pred+K*innovation;I=eye(2);
        P_new=(I-K*H)*P_pred*(I-K*H)'+K*R*K';P_new=enforce_psd(P_new);
        NIS=innovation'*Sinv*innovation;
        updateValid=isfinite(NIS)&&all(isfinite(x_new))&&all(isfinite(P_new(:)));
        if ~updateValid,NIS=0;end
    catch,x_new=x_pred;P_new=P_pred;K=zeros(2);NIS=0;end
else,x_new=x_pred;end
if any(~isfinite(x_new)),x_new=x_pred;end;if any(~isfinite(P_new(:))),P_new=P_pred;end

frontFy=FyCorrected(1)*cos(d(1))+FyCorrected(2)*cos(d(2));
rearFy=FyCorrected(3)+FyCorrected(4);
info=struct('innovation',innovation,'x_pred',x_pred,'F',F,'H',H, ...
    'P_prior',P_prior,'P_noQ',P_noQ,'P_pred',P_pred,'S',S,'K',K,'NIS',NIS, ...
    'updateValid',updateValid, ...
    'alpha',alpha,'Fy',FyCorrected,'Fx',Fx,'Fy_raw',FyRaw, ...
    'Fy_corrected',FyCorrected,'h_pred',h_pred,'frontFy',frontFy, ...
    'rearFy',rearFy,'k_f',kf,'k_r',kr);
info.alpha_FL=alpha(1);info.alpha_FR=alpha(2);info.alpha_RL=alpha(3);info.alpha_RR=alpha(4);
info.Fy_FL=FyCorrected(1);info.Fy_FR=FyCorrected(2);info.Fy_RL=FyCorrected(3);info.Fy_RR=FyCorrected(4);
info.Fx_FL=Fx(1);info.Fx_FR=Fx(2);info.Fx_RL=Fx(3);info.Fx_RR=Fx(4);
end

function [f,alpha,Fy,Fx,FyRaw]=dynamics(x,vx,d,m,Iz,a,b,track,fz,lambda,kf,kr)
[alpha,Fy,Fx,FyRaw]=forces(x,vx,d,a,b,track,fz,lambda,kf,kr);
% Preserve the formal core's operation order exactly for the unity-gain
% equivalence gate (finite-difference Jacobians amplify rounding changes).
vyDot=(Fy(1)*cos(d(1))+Fy(2)*cos(d(2))+Fy(3)+Fy(4))/m-vx*x(2);
rDot=(a*(Fy(1)*cos(d(1))+Fy(2)*cos(d(2)))-b*(Fy(3)+Fy(4)))/Iz;
f=[vyDot;rDot];if ~all(isfinite(f)),f=[0;0];end
end
function g=transition(x,vx,d,m,Iz,a,b,track,fz,lambda,kf,kr,dt)
[f,~,~,~,~]=dynamics(x,vx,d,m,Iz,a,b,track,fz,lambda,kf,kr);g=x+dt*f;if any(~isfinite(g)),g=x;end
end
function [h,alpha,Fy,Fx,FyRaw]=measurement(x,vx,d,m,a,b,track,fz,lambda,kf,kr)
[alpha,Fy,Fx,FyRaw]=forces(x,vx,d,a,b,track,fz,lambda,kf,kr);
h=[(Fy(1)*cos(d(1))+Fy(2)*cos(d(2))+Fy(3)+Fy(4))/m;x(2)];if ~all(isfinite(h)),h=[0;0];end
end
function [alpha,Fy,Fx,FyRaw]=forces(x,vx,d,a,b,track,fz,lambda,kf,kr)
r=x(2);vy=x(1);den=[vx-r*track/2;vx+r*track/2;vx-r*track/2;vx+r*track/2];
alpha=[d(1)-atan2(vy+a*r,den(1));d(2)-atan2(vy+a*r,den(2)); ...
    d(3)-atan2(vy-b*r,den(3));d(4)-atan2(vy-b*r,den(4))];
if any(~isfinite(alpha)),alpha=zeros(4,1);end
FyRaw=zeros(4,1);Fx=zeros(4,1);
for i=1:4,[FyRaw(i),Fx(i)]=tire_call(alpha(i),lambda(i),fz(i),i<=2);end
FyRaw(~isfinite(FyRaw))=0;Fx(~isfinite(Fx))=0;FyRaw=real(FyRaw);Fx=real(Fx);
Fy=FyRaw.*[kf;kf;kr;kr];
end
function [Fy,Fx]=tire_call(alpha,lambda,fz,isFront)
if ~isfinite(fz),fz=1;end;if ~isfinite(alpha),alpha=0;end;if ~isfinite(lambda),lambda=0;end
if exist('tireForceLocal','file')==2
    try,[Fy,Fx]=tireForceLocal(alpha,lambda,fz,isFront);if isfinite(Fy)&&isfinite(Fx),return;end;catch,end
end
if isFront,C=4.2e4;else,C=4.8e4;end;Fy=-C*alpha*min(max(fz,1),1e4)/1000;Fx=0;
end
function J=jacobian(fun,x0,e)
f0=fun(x0);J=zeros(numel(f0),numel(x0));
for i=1:numel(x0),step=e*max(1,abs(x0(i)));if step==0||~isfinite(step),step=e;end
    xp=x0;xm=x0;xp(i)=xp(i)+step;xm(i)=xm(i)-step;fp=fun(xp);fm=fun(xm);
    if any(~isfinite(fp))||any(~isfinite(fm)),J(:,i)=0;else,J(:,i)=(fp-fm)/(2*step);end
end
end
function y=safe_vector(v,n,default)
if isempty(v),y=default(:);return;end;v=v(:);if numel(v)<n,y=default(:);else,y=v(1:n);end;y(~isfinite(y))=0;
end
function y=vector4_field(s,name,default)
if isstruct(s)&&isfield(s,name),v=s.(name);else,v=default;end;v=v(:);if numel(v)<4,y=default(:);else,y=v(1:4);end;y(~isfinite(y))=0;
end
function v=scalar_field(s,name,default)
if isstruct(s)&&isfield(s,name),v=s.(name);if isscalar(v)&&isfinite(v),return;end;end;v=default;
end
function M=matrix2(s,name,default)
if isstruct(s)&&isfield(s,name),M=s.(name);else,M=default;end
if isscalar(M),M=abs(M)*eye(2);else,M=M(1:2,1:2);end
if any(size(M)~=[2,2])||any(~isfinite(M(:))),M=default;end
M=0.5*(M+M');M=max(M,0);if any(diag(M)<=0),M(logical(eye(2)))=max(diag(M),1e-12);end
end
function P=safe_posdef(P)
P=P(1:2,1:2);if any(~isfinite(P(:))),P=eye(2);return;end;P=0.5*(P+P');
if abs(det(P))<1e-16,P=P+1e-9*eye(2);end;[V,D]=eig(P);dd=max(0,real(diag(D)));
if all(dd>=0),P=V*diag(dd)*V';else,P=eye(2);end;P=0.5*(P+P');
end
function P=enforce_psd(P)
if any(~isfinite(P(:))),P=eye(2);end;P=0.5*(P+P');[V,D]=eig(P);d=real(diag(D));d(d<0)=0;P=V*diag(d)*V';P=0.5*(P+P');
end
function ok=finite_det2(M,e),ok=all(isfinite(M(:)))&&all(isfinite(eig(M)))&&(det(M)>e);end
