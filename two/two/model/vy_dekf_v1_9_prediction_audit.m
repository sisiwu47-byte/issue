function audit = vy_dekf_v1_9_prediction_audit(x,u,par,cfg)
%VY_DEKF_V1_9_PREDICTION_AUDIT Diagnostic-only exact prediction audit.
% This helper reproduces the nominal prediction mathematics in
% vy_dynamic_ekf_step_v15_debug and exposes its force/moment terms. It does
% not perform a measurement update and is not an online estimator.

x=x(:); u=u(:);
assert(numel(x)>=2 && numel(u)>=5);
x=x(1:2); u=u(1:5);
m=field_or(par,'m',1860); Iz=field_or(par,'Iz',2687.1);
a=field_or(par,'a',1.18); b=field_or(par,'b',1.77);
track=field_or(par,'track',1.575); dt=field_or(cfg,'dt',0.01);
if isfield(cfg,'lambda'),lambda=cfg.lambda(:);else,lambda=zeros(4,1);end
lambda=lambda(1:4);
if isfield(par,'fz') && numel(par.fz)>=4
    fz=par.fz(:);fz=fz(1:4);
else
    g=9.81;fzFrontVehicle=m*g*b/(a+b);fzRearVehicle=m*g*a/(a+b);
    fz=[fzFrontVehicle;fzFrontVehicle;fzRearVehicle;fzRearVehicle]/2;
end

vx=u(1);delta=u(2:5);r=x(2);vy=x(1);
den=[vx-r*track/2;vx+r*track/2;vx-r*track/2;vx+r*track/2];
alpha=[delta(1)-atan2(vy+a*r,den(1)); ...
    delta(2)-atan2(vy+a*r,den(2)); ...
    delta(3)-atan2(vy-b*r,den(3)); ...
    delta(4)-atan2(vy-b*r,den(4))];
Fy=zeros(4,1);Fx=zeros(4,1);
for i=1:4
    [Fy(i),Fx(i)]=tireForceLocal(alpha(i),lambda(i),fz(i),i<=2);
end

% Exact current prediction definitions.
FybCurrent=[Fy(1)*cos(delta(1));Fy(2)*cos(delta(2));Fy(3);Fy(4)];
FyTotalCurrent=sum(FybCurrent);
MzCurrent=a*(FybCurrent(1)+FybCurrent(2))-b*(FybCurrent(3)+FybCurrent(4));
vyDotCurrent=FyTotalCurrent/m-vx*r;
rDotCurrent=MzCurrent/Iz;
xPredCurrent=x+dt*[vyDotCurrent;rDotCurrent];

% Offline full body-coordinate geometry candidate with unchanged tire law.
FxbFull=Fx.*cos(delta)-Fy.*sin(delta);
FybFull=Fx.*sin(delta)+Fy.*cos(delta);
positionX=[a;a;-b;-b]; positionY=[track/2;-track/2;track/2;-track/2];
FyTotalFull=sum(FybFull);
MzFull=sum(positionX.*FybFull-positionY.*FxbFull);
vyDotFull=FyTotalFull/m-vx*r;
rDotFull=MzFull/Iz;
xPredFull=x+dt*[vyDotFull;rDotFull];

% Isolated additions relative to the current equations.
rearCosForce=sum(Fy(3:4).*(cos(delta(3:4))-1));
fxSinForce=sum(Fx.*sin(delta));
otherForce=FyTotalFull-FyTotalCurrent-rearCosForce-fxSinForce;
rearCosMoment=-b*sum(Fy(3:4).*(cos(delta(3:4))-1));
fxSinMoment=sum(positionX.*Fx.*sin(delta));
trackMoment=sum(-positionY.*FxbFull);
otherMoment=MzFull-MzCurrent-rearCosMoment-fxSinMoment-trackMoment;

audit=struct();
audit.alpha=alpha;audit.Fy=Fy;audit.Fx=Fx;audit.fz=fz;audit.delta=delta;
audit.FybCurrent=FybCurrent;audit.FyTotalCurrent=FyTotalCurrent;
audit.MzCurrent=MzCurrent;audit.vyDotCurrent=vyDotCurrent;
audit.rDotCurrent=rDotCurrent;audit.xPredCurrent=xPredCurrent;
audit.FxbFull=FxbFull;audit.FybFull=FybFull;
audit.FyTotalFull=FyTotalFull;audit.MzFull=MzFull;
audit.vyDotFull=vyDotFull;audit.rDotFull=rDotFull;audit.xPredFull=xPredFull;
audit.positionX=positionX;audit.positionY=positionY;
audit.rearCosForce=rearCosForce;audit.fxSinForce=fxSinForce;
audit.otherForce=otherForce;audit.rearCosMoment=rearCosMoment;
audit.fxSinMoment=fxSinMoment;audit.trackMoment=trackMoment;
audit.otherMoment=otherMoment;
end

function value=field_or(s,name,defaultValue)
if isstruct(s)&&isfield(s,name)&&isscalar(s.(name))&&isfinite(s.(name))
    value=s.(name);
else
    value=defaultValue;
end
end
