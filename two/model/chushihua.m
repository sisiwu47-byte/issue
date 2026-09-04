par_vy = struct();

% vehicle parameters
par_vy.m = 1860;
par_vy.Iz = 2687.1;

par_vy.a = 1.18;
par_vy.b = 1.77;
par_vy.track = 1.575;

par_vy.Rw = 0.393;


% vertical load
g = 9.81;

Fzf = par_vy.m*g*par_vy.b/(par_vy.a+par_vy.b);
Fzr = par_vy.m*g*par_vy.a/(par_vy.a+par_vy.b);

par_vy.fz = [
Fzf/2;
Fzf/2;
Fzr/2;
Fzr/2
];


cfg_vy = struct();


cfg_vy.dt = 0.01;


% EKF process noise
cfg_vy.Q = diag([
1e-4;
1e-3
]);


% measurement noise

% Ay
% yaw rate

cfg_vy.R = diag([
1e-2;
1e-3
]);


% numerical Jacobian
cfg_vy.epsDiff = 1e-6;


% no longitudinal slip initially

cfg_vy.lambda=zeros(4,1);
