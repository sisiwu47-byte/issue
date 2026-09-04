function candidate = vy_dekf_v1_10_transient_candidate(process,mechanics,sigmaF,sigmaR,par)
%VY_DEKF_V1_10_TRANSIENT_CANDIDATE Diagnostic-only relaxation candidate.
% The steady-state tire law, Fz, alpha, geometry, and current prediction
% force transformation are unchanged. No online estimator is modified.

n=numel(process.t);dt=0.01;
assert(n==size(mechanics.Fy,1)&&abs(process.dt-dt)<=1e-12);
assert(isscalar(sigmaF)&&sigmaF>=0&&isscalar(sigmaR)&&sigmaR>=0);
FySS=mechanics.Fy;delta=process.u(:,2:5);vx=process.u(:,1);r=process.xInput(:,2);
track=par.track;m=par.m;Iz=par.Iz;a=par.a;b=par.b;
wheelSpeed=[vx-r*track/2 vx+r*track/2 vx-r*track/2 vx+r*track/2];
FyDynState=FySS(1,:);FyUsed=zeros(n,4);beta=zeros(n,4);
sigmas=[sigmaF sigmaF sigmaR sigmaR];
for k=1:n
    for wheel=1:4
        if sigmas(wheel)==0
            FyUsed(k,wheel)=FySS(k,wheel);
            beta(k,wheel)=0;
        else
            FyUsed(k,wheel)=FyDynState(wheel);
            beta(k,wheel)=exp(-abs(wheelSpeed(k,wheel))*dt/sigmas(wheel));
        end
    end
    if k<n
        for wheel=1:4
            if sigmas(wheel)==0
                FyDynState(wheel)=FySS(k+1,wheel);
            else
                FyDynState(wheel)=beta(k,wheel)*FyDynState(wheel)+ ...
                    (1-beta(k,wheel))*FySS(k,wheel);
            end
        end
    end
end

% Keep the Current V1.9 force transformation exactly; no full geometry.
Fyb=[FyUsed(:,1).*cos(delta(:,1)) FyUsed(:,2).*cos(delta(:,2)) ...
    FyUsed(:,3) FyUsed(:,4)];
FyTotal=sum(Fyb,2);
Mz=a*(Fyb(:,1)+Fyb(:,2))-b*(Fyb(:,3)+Fyb(:,4));
vyDot=FyTotal/m-vx.*r;rDot=Mz/Iz;
xPred=process.xInput+dt*[vyDot rDot];
residual=process.xTarget-xPred;

candidate=struct('sigmaF',sigmaF,'sigmaR',sigmaR,'FySS',FySS, ...
    'FyUsed',FyUsed,'Fyb',Fyb,'FyTotal',FyTotal,'Mz',Mz, ...
    'vyDot',vyDot,'rDot',rDot,'xPred',xPred,'residual',residual, ...
    'beta',beta,'wheelSpeed',wheelSpeed);
end
