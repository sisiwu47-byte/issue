function MPC_output = MPC_Demo3_wuguzhang(u)

%% =========================================================
%  Basic settings
% ====aa======================================================
N  = 10;
Nu = 8;
Nx = 8;
Nw = 8;

% ==========================================================
% 如果你单独跑脚本测试，可以取消下面这段注释
% 注意：不要在 u 里先写 vx/0.393，因为 vx 还没定义
% ==========================================================
% vx0 = 15;
% Rw0 = 0.393;
% u = [ ...
%     0.5, 0.0, 0, 0, ...                         % vy, yawrate, roll, rollrate
%     vx0/Rw0, vx0/Rw0, vx0/Rw0, vx0/Rw0, ...      % wheelrate1~4
%     300, 300, 300, 300, ...                     % Torque1~4 cmd
%     0, 0, 0, 0, ...                             % Steering1~4 cmd
%     0, 0, 0, 0, ...                             % Delta_Torque_last 1~4
%     0, 0, 0, 0, ...                             % Delta_Steering_last 1~4
%     0, 0, 0, 0, 1, 1, 1, 1, ...                 % 25~32
%     vx0, ...                                    % vx
%     0.4, ...                                    % yawrate_ref
%     2.5, 0.2, ...                               % Ay, Ax
%     0.85, 0.85, 0.85, 0.85];                    % mu1~4

%% =========================================================
%  Unpack states and commands
% ==========================================================
vy       = u(1);
yawrate  = u(2);
roll     = u(3);
rollrate = u(4);

wheelrate1 = u(5);
wheelrate2 = u(6);
wheelrate3 = u(7);
wheelrate4 = u(8);

x_abs = [vy; yawrate; roll; rollrate; ...
         wheelrate1; wheelrate2; wheelrate3; wheelrate4];

Torque1 = u(9);
Torque2 = u(10);
Torque3 = u(11);
Torque4 = u(12);

Steering1 = u(13);
Steering2 = u(14);
Steering3 = u(15);
Steering4 = u(16);

w0 = [Torque1; Steering1; ...
      Torque2; Steering2; ...
      Torque3; Steering3; ...
      Torque4; Steering4];

U_Delta_Torque1_last   = u(17);
U_Delta_Torque2_last   = u(18);
U_Delta_Torque3_last   = u(19);
U_Delta_Torque4_last   = u(20);
U_Delta_Steering1_last = u(21);
U_Delta_Steering2_last = u(22);
U_Delta_Steering3_last = u(23);
U_Delta_Steering4_last = u(24);

U_last = [U_Delta_Torque1_last; U_Delta_Steering1_last; ...
          U_Delta_Torque2_last; U_Delta_Steering2_last; ...
          U_Delta_Torque3_last; U_Delta_Steering3_last; ...
          U_Delta_Torque4_last; U_Delta_Steering4_last];

vx          = u(33);
yawrate_ref = u(34);
Ay          = u(35);
Ax          = u(36);
mu1         = u(37);
mu2         = u(38);
mu3         = u(39);
mu4         = u(40);

%% =========================================================
%  Fault factor and stability enable matrix
% ==========================================================
% 通道顺序：
% [T1, delta1, T2, delta2, T3, delta3, T4, delta4]
T_v = diag([1, 1, 1, 1, 1, 1, 1, 1]);% =========================T_v===============================

% 如果你以后想从 Simulink 输入故障因子，建议改成：
% gamma_vec = u(41:48);
% gamma_vec = min(max(gamma_vec,0),1);
% T_v = diag(gamma_vec);

T_w = eye(8);

% 如果你想用 u(25:32) 做 8 个通道使能，可以改成：
% Tw_vec = u(25:32);
% Tw_vec = min(max(Tw_vec,0),1);
% T_w = diag(Tw_vec);

%% =========================================================
%  Vehicle parameters
% ==========================================================
Ts = 0.02;

a = 1.18;
b = 1.77;
L = a + b;
d = 1.575;

g   = 9.8;
m   = 1860;
m_s = 1590;

h_s = 0.5;
h   = 0.72;
R_w = 0.393;

I_x = 894.4;
I_w = 1.5;
I_z = 2687.1;

k_roll = 189506;
c_roll = 6364;

vx_safe = max(abs(vx), 1.0);

%% =========================================================
%  Weights and limits
% ==========================================================
vy_max        = vx * tan(3/180*pi);
yawrate_max   = 0.5;
roll_max      = 0.09;
rollrate_max  = 0.1;
wheelrate_max = 48;

delta_torque_max = 500;
delta_steer_max  = 0.03;

% 状态权重
T_x = repmat([1/vy_max^2, ...
              2/yawrate_max^2, ...
              0, ...
              0, ...
              0.04/wheelrate_max^2, ...
              0.04/wheelrate_max^2, ...
              0.04/wheelrate_max^2, ...
              0.04/wheelrate_max^2], 1, N);

% 输入增量权重
T_u = [0.25/delta_torque_max^2, 0.12/delta_steer_max^2, ...
       0.25/delta_torque_max^2, 0.12/delta_steer_max^2, ...
       0.25/delta_torque_max^2, 0.35/delta_steer_max^2, ...
       0.25/delta_torque_max^2, 0.35/delta_steer_max^2];

%% =========================================================
%  Actual steering at current linearization point
% ==========================================================
% 因为 Steering1~4 是命令角，而 CarSim 实际输入是 gamma*(cmd+delta_cmd)
% 当前线性化点应使用实际角
Steering1_act = T_v(2,2) * Steering1;
Steering2_act = T_v(4,4) * Steering2;
Steering3_act = T_v(6,6) * Steering3;
Steering4_act = T_v(8,8) * Steering4;

%% =========================================================
%  Tire slip angles and slip ratios
% ==========================================================
alpha1 = Steering1_act - atan2((vy + a*yawrate), (vx + yawrate*d/2));
alpha2 = Steering2_act - atan2((vy + a*yawrate), (vx - yawrate*d/2));
alpha3 = Steering3_act - atan2((vy - b*yawrate), (vx + yawrate*d/2));
alpha4 = Steering4_act - atan2((vy - b*yawrate), (vx - yawrate*d/2));

vx_fl = vx - yawrate*d/2;
vx_fr = vx + yawrate*d/2;
vx_rl = vx_fl;
vx_rr = vx_fr;

vy_fl = vy + yawrate*a;
vy_fr = vy_fl;
vy_rl = vy - yawrate*b;
vy_rr = vy_rl;

Vl_fl = vy_fl*sin(Steering1_act) + vx_fl*cos(Steering1_act);
Vl_fr = vy_fr*sin(Steering2_act) + vx_fr*cos(Steering2_act);
Vl_rl = vy_rl*sin(Steering3_act) + vx_rl*cos(Steering3_act);
Vl_rr = vy_rr*sin(Steering4_act) + vx_rr*cos(Steering4_act);

lambda_fl = (R_w*wheelrate1 - Vl_fl) / max(abs(max(Vl_fl, R_w*wheelrate1)), 1e-6);
lambda_fr = (R_w*wheelrate2 - Vl_fr) / max(abs(max(Vl_fr, R_w*wheelrate2)), 1e-6);
lambda_rl = (R_w*wheelrate3 - Vl_rl) / max(abs(max(Vl_rl, R_w*wheelrate3)), 1e-6);
lambda_rr = (R_w*wheelrate4 - Vl_rr) / max(abs(max(Vl_rr, R_w*wheelrate4)), 1e-6);

%% =========================================================
%  Vertical loads
% ==========================================================
f_z1 = m*g*b/2/L - m*h*Ax/2/L - m*Ay*h*b/L/d;
f_z2 = m*g*b/2/L - m*h*Ax/2/L + m*Ay*h*b/L/d;
f_z3 = m*g*a/2/L + m*h*Ax/2/L - m*Ay*h*a/L/d + 350;
f_z4 = m*g*a/2/L + m*h*Ax/2/L + m*Ay*h*a/L/d + 350;

f_z1 = max(f_z1, 100);
f_z2 = max(f_z2, 100);
f_z3 = max(f_z3, 100);
f_z4 = max(f_z4, 100);

%% =========================================================
%  Nonlinear tire forces at current point
% ==========================================================
[f_y1, f_x1] = tireForceLocal(alpha1, lambda_fl, f_z1, 1);
[f_y2, f_x2] = tireForceLocal(alpha2, lambda_fr, f_z2, 1);
[f_y3, f_x3] = tireForceLocal(alpha3, lambda_rl, f_z3, 0);
[f_y4, f_x4] = tireForceLocal(alpha4, lambda_rr, f_z4, 0);

%% =========================================================
%  Effective cornering stiffness by local linearization
% ==========================================================
eps_a = 1e-4;

c_alpha1 = tireCorneringStiffnessLocal(alpha1, lambda_fl, f_z1, 1, eps_a);
c_alpha2 = tireCorneringStiffnessLocal(alpha2, lambda_fr, f_z2, 1, eps_a);
c_alpha3 = tireCorneringStiffnessLocal(alpha3, lambda_rl, f_z3, 0, eps_a);
c_alpha4 = tireCorneringStiffnessLocal(alpha4, lambda_rr, f_z4, 0, eps_a);

% 防止局部斜率太小、负值或异常大破坏 QP
c_alpha1 = min(max(c_alpha1, 50), 80000);
c_alpha2 = min(max(c_alpha2, 50), 80000);
c_alpha3 = min(max(c_alpha3, 50), 80000);
c_alpha4 = min(max(c_alpha4, 50), 80000);

%% =========================================================
%  Control geometry matrices
% ==========================================================
L_c = [1 0 1 0 1 0 1 0;
       0 1 0 1 0 1 0 1;
      -d/2 a d/2 a -d/2 -b d/2 -b];

L_w1 = [cos(Steering1_act), -sin(Steering1_act);
        sin(Steering1_act),  cos(Steering1_act)];

L_w2 = [cos(Steering2_act), -sin(Steering2_act);
        sin(Steering2_act),  cos(Steering2_act)];

L_w3 = [cos(Steering3_act), -sin(Steering3_act);
        sin(Steering3_act),  cos(Steering3_act)];

L_w4 = [cos(Steering4_act), -sin(Steering4_act);
        sin(Steering4_act),  cos(Steering4_act)];

L_w = blkdiag(L_w1, L_w2, L_w3, L_w4);

%% =========================================================
%  Linearized tire model matrices
% ==========================================================
B11 = [0, 0, 0, 0;
      -c_alpha1/vx_safe, -a*c_alpha1/vx_safe, 0, 0];

B12 = [0, 0, 0, 0;
      -c_alpha2/vx_safe, -a*c_alpha2/vx_safe, 0, 0];

B13 = [0, 0, 0, 0;
      -c_alpha3/vx_safe,  b*c_alpha3/vx_safe, 0, 0];

B14 = [0, 0, 0, 0;
      -c_alpha4/vx_safe,  b*c_alpha4/vx_safe, 0, 0];

B1 = [B11', B12', B13', B14']';

B21 = [1/R_w, 0; 0, c_alpha1];
B22 = [1/R_w, 0; 0, c_alpha2];
B23 = [1/R_w, 0; 0, c_alpha3];
B24 = [1/R_w, 0; 0, c_alpha4];

B2 = blkdiag(B21, B22, B23, B24);

D11 = [0, f_y1 - c_alpha1*alpha1]';
D12 = [0, f_y2 - c_alpha2*alpha2]';
D13 = [0, f_y3 - c_alpha3*alpha3]';
D14 = [0, f_y4 - c_alpha4*alpha4]';

D1 = [D11', D12', D13', D14']';

%% =========================================================
%  Vehicle body dynamics matrices
% ==========================================================
den_roll = -m_s*m_s*h_s*h_s + m*I_x;

Af13 = -m_s*h_s*(k_roll - m_s*g*h_s) / den_roll;
Af14 = -m_s*h_s*c_roll / den_roll;
Af43 = -m*(k_roll - m_s*g*h_s) / den_roll;
Af44 = -m*c_roll / den_roll;

Bf12 = I_x / den_roll;
Bf42 = m_s*h_s / den_roll;

A_f = [0, -vx, Af13, Af14;
       0,   0,    0,    0;
       0,   0,    0,    1;
       0,   0, Af43, Af44];

B_f = [0, Bf12, 0;
       0,    0, 1/I_z;
       0,    0, 0;
       0, Bf42, 0];

A_b = A_f + B_f*L_c*L_w*B1;
B_b = B_f*L_c*L_w*B2*T_w*T_v;
C_b = B_f*L_c*L_w*B2*T_v;
D_b = B_f*L_c*L_w*D1;

%% =========================================================
%  Wheel dynamics
% ==========================================================
A_w = zeros(4,4);

M_r = 0.0038 + 9.36e-5*vx + 0.00085;

B_w = 1/I_w * [T_w(1,1)*T_v(1,1), 0, 0, 0, 0, 0, 0, 0;
               0, 0, T_w(3,3)*T_v(3,3), 0, 0, 0, 0, 0;
               0, 0, 0, 0, T_w(5,5)*T_v(5,5), 0, 0, 0;
               0, 0, 0, 0, 0, 0, T_w(7,7)*T_v(7,7), 0];

C_w = 1/I_w * [T_v(1,1), 0, 0, 0, 0, 0, 0, 0;
               0, 0, T_v(3,3), 0, 0, 0, 0, 0;
               0, 0, 0, 0, T_v(5,5), 0, 0, 0;
               0, 0, 0, 0, 0, 0, T_v(7,7), 0];

D_w = 1/I_w * [-R_w*f_x1 - M_r*0.25*m*g*R_w;
               -R_w*f_x2 - M_r*0.25*m*g*R_w;
               -R_w*f_x3 - M_r*0.25*m*g*R_w;
               -R_w*f_x4 - M_r*0.25*m*g*R_w];

%% =========================================================
%  Full continuous and discrete model
% ==========================================================
A = blkdiag(A_b, A_w);
B = [B_b; B_w];
C = [C_b; C_w];
D = [D_b; D_w];

A_d = eye(8) + A*Ts;
B_d = B*Ts;
C_d = C*Ts;
D_d = D*Ts;

%% =========================================================
%  Error state model
% ==========================================================
x_ref0 = [0;
          yawrate_ref;
          0;
          0;
          vx/R_w;
          vx/R_w;
          vx/R_w;
          vx/R_w];

x0 = x_abs - x_ref0;

D_eff = D_d + (A_d - eye(Nx))*x_ref0;
% ===== debug variables for observer test =====
assignin('base','dbg_A',A);
assignin('base','dbg_B',B);
assignin('base','dbg_C',C);
assignin('base','dbg_D',D);
assignin('base','dbg_A_d',A_d);
assignin('base','dbg_B_d',B_d);
assignin('base','dbg_C_d',C_d);
assignin('base','dbg_D_eff',D_eff);
assignin('base','dbg_x0',x0);
assignin('base','dbg_x_ref0',x_ref0);
assignin('base','dbg_w0',w0);
assignin('base','dbg_U_last',U_last);
assignin('base','dbg_Ts',Ts);%============================测观测器========================
%% =========================================================
%  Prediction matrices
% ==========================================================
Sx = zeros(N*Nx, Nx);
Sx(1:Nx,:) = A_d;

for i = 2:N
    Sx((i-1)*Nx+1:i*Nx,:) = A_d^i;
end

Su = zeros(N*Nx, Nu*N);
Su(1:Nx, 1:Nu) = B_d;

for i = 2:N
    Su((i-1)*Nx+1:i*Nx, (i-1)*Nu+1:i*Nu) = B_d;
    for j = 1:i-1
        prev_block = Su((i-2)*Nx+1:(i-1)*Nx, (j-1)*Nu+1:j*Nu);
        Su((i-1)*Nx+1:i*Nx, (j-1)*Nu+1:j*Nu) = A_d * prev_block;
    end
end

Sw = zeros(N*Nx, Nw);
Sd = zeros(N*Nx, 1);

for i = 1:N
    accum_w = zeros(Nx, Nw);
    accum_d = zeros(Nx, 1);

    for j = 1:i
        power = i - j;

        if power == 0
            block_w = C_d;
            block_d = D_eff;
        else
            block_w = A_d^power * C_d;
            block_d = A_d^power * D_eff;
        end

        accum_w = accum_w + block_w;
        accum_d = accum_d + block_d;
    end

    Sw((i-1)*Nx+1:i*Nx,:) = accum_w;
    Sd((i-1)*Nx+1:i*Nx,:) = accum_d;
end

%% =========================================================
%  QP cost
% ==========================================================
Qx = diag(T_x);
R  = kron(eye(N), diag(T_u));

H = 2 * (Su' * Qx * Su + R);
H = (H + H') / 2;

Ep = - (Sx*x0 + Sw*w0 + Sd);
f  = -2 * Su' * Qx * Ep;

%% =========================================================
%  Vy constraints
% ==========================================================
indices = 1:Nx:N*Nx;

Su1 = Su(indices,:);
Sx1 = Sx(indices,:);
Sw1 = Sw(indices,:);
Sd1 = Sd(indices,:);

E = repmat(vy_max, N, 1);
F = repmat(-vy_max, N, 1);

G = [Su1; -Su1];

e = [-Sx1*x0 - Sw1*w0 - Sd1 + E;
      Sx1*x0 + Sw1*w0 + Sd1 - F];

%% =========================================================
%  Friction polygon constraints
% ==========================================================
Hx = [-c_alpha1/vx_safe, -c_alpha1*a/vx_safe, 0, 0, 0, 0, 0, 0;
      -c_alpha2/vx_safe, -c_alpha2*a/vx_safe, 0, 0, 0, 0, 0, 0;
      -c_alpha3/vx_safe,  c_alpha3*b/vx_safe, 0, 0, 0, 0, 0, 0;
      -c_alpha4/vx_safe,  c_alpha4*b/vx_safe, 0, 0, 0, 0, 0, 0;
       0, 0, 0, 0, 0, 0, 0, 0;
       0, 0, 0, 0, 0, 0, 0, 0;
       0, 0, 0, 0, 0, 0, 0, 0;
       0, 0, 0, 0, 0, 0, 0, 0];

Hu = [0, c_alpha1, 0, 0, 0, 0, 0, 0;
      0, 0, 0, c_alpha2, 0, 0, 0, 0;
      0, 0, 0, 0, 0, c_alpha3, 0, 0;
      0, 0, 0, 0, 0, 0, 0, c_alpha4;
      1/R_w, 0, 0, 0, 0, 0, 0, 0;
      0, 0, 1/R_w, 0, 0, 0, 0, 0;
      0, 0, 0, 0, 1/R_w, 0, 0, 0;
      0, 0, 0, 0, 0, 0, 1/R_w, 0];

cf = [f_y1 + c_alpha1*Steering1_act - c_alpha1*alpha1;
      f_y2 + c_alpha2*Steering2_act - c_alpha2*alpha2;
      f_y3 + c_alpha3*Steering3_act - c_alpha3*alpha3;
      f_y4 + c_alpha4*Steering4_act - c_alpha4*alpha4;
      f_x1;
      f_x2;
      f_x3;
      f_x4];

A8 = [ 1  0;
      -1  0;
       0  1;
       0 -1;
       1  1;
       1 -1;
      -1  1;
      -1 -1];

sqrt2 = sqrt(2);

b8_1 = [mu1*f_z1*ones(4,1); sqrt2*mu1*f_z1*ones(4,1)];
b8_2 = [mu2*f_z2*ones(4,1); sqrt2*mu2*f_z2*ones(4,1)];
b8_3 = [mu3*f_z3*ones(4,1); sqrt2*mu3*f_z3*ones(4,1)];
b8_4 = [mu4*f_z4*ones(4,1); sqrt2*mu4*f_z4*ones(4,1)];

b_step = [b8_1; b8_2; b8_3; b8_4];

Ablk = blkdiag(A8, A8, A8, A8);

R_n = [0 0 0 0 1 0 0 0;
       1 0 0 0 0 0 0 0;
       0 0 0 0 0 1 0 0;
       0 1 0 0 0 0 0 0;
       0 0 0 0 0 0 1 0;
       0 0 1 0 0 0 0 0;
       0 0 0 0 0 0 0 1;
       0 0 0 1 0 0 0 0];

Aforce = Ablk * R_n;

A_u = Aforce * Hu * T_v * T_w;
A_x = Aforce * Hx;
c_b = b_step - Aforce * cf;

G_fric = zeros(32*N, Nu*N);
e_fric = zeros(32*N, 1);

X_const_e   = Sx*x0 + Sw*w0 + Sd;
X_const_abs = X_const_e + repmat(x_ref0, N, 1);

soft_ratio = 0.03;

for j = 1:N
    row = (j-1)*32 + (1:32);

    xj_const = X_const_abs((j-1)*Nx+1:j*Nx);
    Su_j     = Su((j-1)*Nx+1:j*Nx, :);

    AxSu_j    = A_x * Su_j;
    AxConst_j = A_x * xj_const;

    AuEj_j = zeros(32, Nu*N);
    AuEj_j(:, (j-1)*Nu+1:j*Nu) = A_u;

    G_fric(row,:) = AuEj_j + AxSu_j;
    e_fric(row)   = c_b - AxConst_j + soft_ratio*abs(c_b);
end

G = [G; G_fric];
e = [e; e_fric];

%% =========================================================
%  Bounds
% ==========================================================
Qmax     = 1600;
thetamax = 40*pi/180;

ub = [Qmax; thetamax; Qmax; thetamax; Qmax; thetamax; Qmax; thetamax] - w0;
lb = -[Qmax; thetamax; Qmax; thetamax; Qmax; thetamax; Qmax; thetamax] - w0;

ub = repmat(ub, N, 1);
lb = repmat(lb, N, 1);

Qmax1     = 120;
thetamax1 = 0.008;

idx_first = 1:Nu;

lb(idx_first) = max(lb(idx_first), ...
    [-Qmax1; -thetamax1; -Qmax1; -thetamax1; -Qmax1; -thetamax1; -Qmax1; -thetamax1]);

ub(idx_first) = min(ub(idx_first), ...
    [ Qmax1;  thetamax1;  Qmax1;  thetamax1;  Qmax1;  thetamax1;  Qmax1;  thetamax1]);

%% =========================================================
%  Solve QP
% ==========================================================
options = optimoptions('quadprog', ...
    'Display', 'off', ...
    'Algorithm', 'active-set', ...
    'MaxIterations', 400, ...
    'ConstraintTolerance', 1e-4, ...
    'OptimalityTolerance', 1e-3);

U0 = repmat(U_last, N, 1);

[U_full, ~, exitflag, output] = quadprog(H, f, G, e, [], [], lb, ub, U0, options);

if ~isempty(U_full)
    max_violation = max(G*U_full - e);
else
    max_violation = NaN;
end

tol_feas = 1e-4;

use_sol = ~isempty(U_full) && ...
          isfinite(max_violation) && ...
          max_violation <= tol_feas && ...
          (exitflag == 1 || exitflag == 0);

if use_sol
    U = U_full(1:Nu);
else
    U = U_last;
    U_full = repmat(U_last, N, 1);
end

%% =========================================================
%  Debug summary after U is selected
% ==========================================================
U_cmd    = U;
U_actual = T_v*T_w*U_cmd;

U_seq = U_full;

X_pred_e = Sx*x0 + Su*U_seq + Sw*w0 + Sd;

x1_pred_e   = X_pred_e(1:Nx);
x1_pred_abs = x1_pred_e + x_ref0;

control_effect = B_d*U_cmd;
base_effect    = C_d*w0;
total_effect   = control_effect + base_effect;

general_force = L_c*L_w*B2*U_actual;

Fx_total = general_force(1);
Fy_total = general_force(2);
Mz_total = general_force(3);

J_state = X_pred_e' * Qx * X_pred_e;
J_input = U_seq' * R * U_seq;
J_total = J_state + J_input;

vio_all = G*U_seq - e;
[maxvio_debug, active_idx] = max(vio_all);

vio_fric = G_fric*U_seq - e_fric;
[maxvio_fric, active_idx_fric] = max(vio_fric);

beta_now    = atan2(vy, max(abs(vx),1e-3));
beta_1_pred = atan2(x1_pred_abs(1), max(abs(vx),1e-3));

Fx_seq = zeros(N,1);
Fy_seq = zeros(N,1);
Mz_seq = zeros(N,1);

for kk = 1:N
    Uk_cmd = U_seq((kk-1)*Nu+1:kk*Nu);
    Uk_act = T_v*T_w*Uk_cmd;
    gf_k   = L_c*L_w*B2*Uk_act;

    Fx_seq(kk) = gf_k(1);
    Fy_seq(kk) = gf_k(2);
    Mz_seq(kk) = gf_k(3);
end

debug_mpc = struct();

debug_mpc.exitflag = exitflag;
debug_mpc.qp_message = output.message;
debug_mpc.max_violation = maxvio_debug;
debug_mpc.active_idx = active_idx;
debug_mpc.maxvio_fric = maxvio_fric;
debug_mpc.active_idx_fric = active_idx_fric;

debug_mpc.T_v = T_v;
debug_mpc.T_w = T_w;

debug_mpc.U_cmd = U_cmd;
debug_mpc.U_actual = U_actual;

debug_mpc.Fx_total = Fx_total;
debug_mpc.Fy_total = Fy_total;
debug_mpc.Mz_total = Mz_total;
debug_mpc.general_force = general_force;

debug_mpc.Fx_seq = Fx_seq;
debug_mpc.Fy_seq = Fy_seq;
debug_mpc.Mz_seq = Mz_seq;

debug_mpc.x_now_abs = x_abs;
debug_mpc.x_ref0 = x_ref0;
debug_mpc.x0_error = x0;
debug_mpc.x1_pred_e = x1_pred_e;
debug_mpc.x1_pred_abs = x1_pred_abs;

debug_mpc.yawrate_now = yawrate;
debug_mpc.yawrate_ref = yawrate_ref;
debug_mpc.yawrate_error_now = yawrate - yawrate_ref;
debug_mpc.yawrate_error_1step = x1_pred_e(2);

debug_mpc.vy_now = vy;
debug_mpc.vy_1step = x1_pred_abs(1);
debug_mpc.beta_now = beta_now;
debug_mpc.beta_1step = beta_1_pred;

debug_mpc.control_effect = control_effect;
debug_mpc.base_effect = base_effect;
debug_mpc.total_effect = total_effect;

debug_mpc.J_state = J_state;
debug_mpc.J_input = J_input;
debug_mpc.J_total = J_total;

debug_mpc.c_alpha_eff = [c_alpha1; c_alpha2; c_alpha3; c_alpha4];

assignin('base', 'debug_mpc', debug_mpc);
assignin('base', 'U_cmd', U_cmd);
assignin('base', 'U_actual', U_actual);

fprintf('\n====== MPC DEBUG ======\n');
fprintf('exitflag        = %d\n', exitflag);
fprintf('max_violation   = %.6e\n', maxvio_debug);
fprintf('active_idx      = %d\n', active_idx);
fprintf('maxvio_fric     = %.6e\n', maxvio_fric);
fprintf('active_idx_fric = %d\n', active_idx_fric);

fprintf('\nEffective cornering stiffness [c1 c2 c3 c4] = \n');
disp([c_alpha1, c_alpha2, c_alpha3, c_alpha4]);

fprintf('\nU_cmd = \n');
disp(U_cmd.');

fprintf('U_actual = \n');
disp(U_actual.');

fprintf('\nGeneral force first step [Fx, Fy, Mz] = [%.6f, %.6f, %.6f]\n', ...
    Fx_total, Fy_total, Mz_total);

fprintf('\nMz_seq = \n');
disp(Mz_seq.');

fprintf('\nyawrate_now/ref/error = %.6f / %.6f / %.6f\n', ...
    yawrate, yawrate_ref, yawrate - yawrate_ref);
fprintf('yawrate_error_1step   = %.6f\n', x1_pred_e(2));

fprintf('vy_now / vy_1step     = %.6f / %.6f\n', ...
    vy, x1_pred_abs(1));
fprintf('beta_now / beta_1step = %.6f / %.6f\n', ...
    beta_now, beta_1_pred);

fprintf('\nJ_state = %.6e\n', J_state);
fprintf('J_input = %.6e\n', J_input);
fprintf('J_total = %.6e\n', J_total);
fprintf('=======================\n');

yaw_err_seq = X_pred_e(2:Nx:end);
yawrate_pred_abs_seq = yaw_err_seq + yawrate_ref;
vy_pred_abs_seq = X_pred_e(1:Nx:end) + x_ref0(1);
beta_pred_seq = atan2(vy_pred_abs_seq, max(abs(vx),1e-3));

debug_mpc.yaw_err_seq = yaw_err_seq;
debug_mpc.yawrate_pred_abs_seq = yawrate_pred_abs_seq;
debug_mpc.vy_pred_abs_seq = vy_pred_abs_seq;
debug_mpc.beta_pred_seq = beta_pred_seq;

fprintf('\nyawrate_error_seq = \n');
disp(yaw_err_seq.');

fprintf('yawrate_pred_abs_seq = \n');
disp(yawrate_pred_abs_seq.');

fprintf('vy_pred_abs_seq = \n');
disp(vy_pred_abs_seq.');

fprintf('beta_pred_seq = \n');
disp(beta_pred_seq.');
%% =========================================================
%  Outputs + model log vector
% ==========================================================

% 先计算一步预测
x_next_e = A_d*x0 + B_d*U + C_d*w0 + D_eff;

% 打包模型日志，顺序必须和 shujj/parse_uc_model_log 完全一致
model_log_vec = [ ...
    A(:);
    B(:);
    C(:);
    A_d(:);
    B_d(:);
    C_d(:);
    D(:);
    D_d(:);
    D_eff(:);
    x_ref0(:);
    w0(:);
    U_cmd(:);
    U_actual(:);
    diag(T_v);
    diag(T_w);
    x0(:);
    x_next_e(:);
    vx;
    yawrate_ref;
    Ay;
    Ax;
    mu1;
    mu2;
    mu3;
    mu4;
    Ts];

if numel(model_log_vec) ~= 481
    error('model_log_vec length should be 481, got %d.', numel(model_log_vec));
end

% 18 + 481 = 499
MPC_output = zeros(499,1);

% 原来的 18 维输出保持不变
MPC_output(1:8)   = U(:);
MPC_output(9:16)  = x_next_e(:);
MPC_output(17)    = exitflag;
MPC_output(18)    = max_violation;

% 新增：系统矩阵和参数日志
MPC_output(19:499) = model_log_vec(:);

end

%% =========================================================
%  Local tire force function
% ==========================================================
function [Fy, Fx] = tireForceLocal(alpha, lambda, fz, isFront)

if isFront == 1
    c1_lat = 0.85;
    c2_lat = 30;
    c3_lat = 0.06;
    
    c1_long = 0.9;
    c2_long = 30;
    c3_long = 0.06;
else
    c1_lat = 0.87;
    c2_lat = 21.026;
    c3_lat = 0.1;

    c1_long = 0.5;
    c2_long = 21.026;
    c3_long = 0.1;
end

s = sqrt(lambda.^2 + tan(alpha).^2);
s = max(s, 1e-6);

Ft_lat = fz*c1_lat*(1-exp(-c2_lat*s)) - c3_lat*s;
Fy = 0.9 * alpha ./ s .* Ft_lat;

Ft_long = fz*c1_long*(1-exp(-c2_long*s)) - c3_long*s;
Fx = lambda ./ s .* Ft_long;

end

%% =========================================================
%  Local equivalent cornering stiffness
% ==========================================================
function c_alpha_eff = tireCorneringStiffnessLocal(alpha, lambda, fz, isFront, eps_a)

[Fy_p, ~] = tireForceLocal(alpha + eps_a, lambda, fz, isFront);
[Fy_m, ~] = tireForceLocal(alpha - eps_a, lambda, fz, isFront);

c_alpha_eff = (Fy_p - Fy_m) / (2*eps_a);

end
% % function MPC_output = MPC_Demo3_wuguzhang(u)
% N=10;
% Nu=8;
% % u = [0, 0, 0, 0, 54, 54, 54, 54, 700,700,700,700,   0,0,0,0,...
% %     1,1,1,1,   1,1,1,1,   0,0,0,0,0,0,0,0,...
% %     10,...
% %     0,0,1,  0.85,0.85,0.85,0.85];
% u = [ ...
%     0.5, 0.0, 0, 0, ...              % vy, yawrate, roll, rollrate
%     vx/0.393, vx/0.393, vx/0.393, vx/0.393, ...  % wheelrate1~4，约等于 vx/Rw
%     300, 300, 300, 300, ...          % Torque1~4，不要太大，避免主要压轮速
%     0, 0, 0, 0, ...                  % Steering1~4
%     0, 0, 0, 0, ...                  % Delta_Torque_last 1~4
%     0, 0, 0, 0, ...                  % Delta_Steering_last 1~4
%     0, 0, 0, 0, 1, 1, 1, 1, ...      % 25~32，暂时不用/扩稳使能
%     15, ...                          % vx
%     0.4, ...                        % yawrate_ref，给横摆角速度目标
%     2.5, 0.2, ...                    % Ay, Ax
%     0.85, 0.85, 0.85, 0.85];         % mu1~4
% T_x=repmat([1 0.5 0.2 0.3 0 0 0 0], 1, N);
% T_u=repmat([0.27 0.1 0.27 0.1 0.27 0.1 0.27 0.1], 1, N);
% vx=u(33);
% vy_max        = vx* tan(3/180*3.14);
% yawrate_max   = 0.5;
% roll_max      = 0.09;
% rollrate_max  = 0.1;
% wheelrate_max = 48;
% 
% delta_torque_max = 500;
% delta_steer_max  = 0.03;
% 
% % 状态权重（保持原样）
% T_x = repmat([1/vy_max^2 2/yawrate_max^2 0 0 ...
%               0.04/wheelrate_max^2 0.04/wheelrate_max^2 ...
%               0.04/wheelrate_max^2 0.04/wheelrate_max^2], 1, N);
% 
% % 输入（增量）基础权重（保持原样）
% T_u = [0.1/delta_torque_max^2 0.02/delta_steer_max^2 ...
%        0.1/delta_torque_max^2 0.02/delta_steer_max^2 ...
%        0.1/delta_torque_max^2 0.2/delta_steer_max^2 ...
%        0.1/delta_torque_max^2 0.2/delta_steer_max^2];
% % 比原来更保守：明显提高 steering 增量惩罚，同时略提高 torque 增量惩罚
% T_u = [0.25/delta_torque_max^2 0.12/delta_steer_max^2 ...
%        0.25/delta_torque_max^2 0.12/delta_steer_max^2 ...
%        0.25/delta_torque_max^2 0.35/delta_steer_max^2 ...
%        0.25/delta_torque_max^2 0.35/delta_steer_max^2];
% % -------------------- unpack --------------------
% vy=u(1);
% yawrate=u(2);
% roll=u(3);
% rollrate=u(4);
% wheelrate1=u(5);
% wheelrate2=u(6);
% wheelrate3=u(7);
% wheelrate4=u(8);
% 
% x_abs=[vy;yawrate;roll;rollrate;wheelrate1;wheelrate2;wheelrate3;wheelrate4]; % 绝对状态
% 
% Torque1=u(9);  Torque2=u(10); Torque3=u(11); Torque4=u(12);
% Steering1=u(13); Steering2=u(14); Steering3=u(15); Steering4=u(16);
% w0=[Torque1;Steering1;Torque2;Steering2;Torque3;Steering3;Torque4;Steering4];
% 
% U_Delta_Torque1_last=u(17);
% U_Delta_Torque2_last=u(18);
% U_Delta_Torque3_last=u(19);
% U_Delta_Torque4_last=u(20);
% U_Delta_Steering1_last=u(21);
% U_Delta_Steering2_last=u(22);
% U_Delta_Steering3_last=u(23);
% U_Delta_Steering4_last=u(24);
% 
% U_last=[U_Delta_Torque1_last;U_Delta_Steering1_last; ...
%         U_Delta_Torque2_last;U_Delta_Steering2_last; ...
%         U_Delta_Torque3_last;U_Delta_Steering3_last; ...
%         U_Delta_Torque4_last;U_Delta_Steering4_last];
% 
% tw1=u(29);
% T_v=diag([1,0.2,1,0.2,1,0.2,1,0.2]);%=======================================================
% 
% 
% yawrate_ref=u(34);
% Ay=u(35);
% Ax=u(36);
% mu1=u(37); mu2=u(38); mu3=u(39); mu4=u(40);
% 
% % -------------------- parameters --------------------
% Ts=0.02;
% 
% a=1.18; b=1.77; L=a+b; d=1.575;
% g=9.8; m=1860; m_s=1590;
% h_s=0.5; h=0.72; R_w= 0.393;
% I_x=894.4; I_w=1.5; I_z=2687.1;
% c_alpha_f=750;
% c_alpha_r=800;
% k_roll=189506;
% c_roll=6364;
% 
% vx_safe = max(abs(vx), 1.0);
% 
% % -------------------- warm start --------------------
% % persistent U_prev_full
% % if isempty(U_prev_full) || numel(U_prev_full) ~= Nu*N
% %     U_prev_full = repmat(U_last, N, 1);
% % end
% Steering1_act = T_v(2,2) * Steering1;
% Steering2_act = T_v(4,4) * Steering2;
% Steering3_act = T_v(6,6) * Steering3;
% Steering4_act = T_v(8,8) * Steering4;
% % -------------------- tire forces (same as your code) --------------------
% alpha1 =  (Steering1_act - atan2((vy + a * yawrate), (vx + yawrate * d / 2)));
% alpha2 =  (Steering2_act - atan2((vy + a * yawrate), (vx - yawrate * d / 2)));
% alpha3 =  (Steering3_act - atan2((vy - b * yawrate), (vx + yawrate * d / 2)));
% alpha4 =  (Steering4_act - atan2((vy - b * yawrate), (vx - yawrate * d / 2)));
% 
% vx_fl=vx-yawrate*d/2; vx_fr=vx+yawrate*d/2;
% vx_rl=vx_fl;          vx_rr=vx_fr;
% vy_fl=vy+yawrate*a;   vy_fr=vy_fl;
% vy_rl=vy-yawrate*b;   vy_rr=vy_rl;
% 
% Vl_fl=vy_fl*sin(Steering1_act)+vx_fl*cos(Steering1_act);
% Vl_fr=vy_fr*sin(Steering2_act)+vx_fr*cos(Steering2_act);
% Vl_rl=vx_rl;
% Vl_rr=vx_rr;
% 
% lambda_fl= (R_w *wheelrate1-Vl_fl) / max(Vl_fl,R_w *wheelrate1);
% lambda_fr= (R_w *wheelrate2-Vl_fr) / max(Vl_fr,R_w *wheelrate2);
% lambda_rl= (R_w *wheelrate3-Vl_rl) / max(Vl_rl,R_w *wheelrate3);
% lambda_rr= (R_w *wheelrate4-Vl_rr) / max(Vl_rr,R_w *wheelrate4);
% 
% f_z1=m*g*b/2/L-m*h*Ax/2/L-m*Ay*h*b/L/d;
% f_z2=m*g*b/2/L-m*h*Ax/2/L+m*Ay*h*b/L/d;
% f_z3=(m*g*a/2/L+m*h*Ax/2/L-m*Ay*h*a/L/d)+350;
% f_z4=(m*g*a/2/L+m*h*Ax/2/L+m*Ay*h*a/L/d)+350;
% c1f = 0.4;
% c1r = 0.47;
% c2f =40;
% c2r =40.026;
% c3f =60;
% c3r =0.1;
% c1f = 0.85; c1r = 0.87; c2f =30; c2r =21.026; c3f =0.06; c3r =0.1;
% 
% s_res_FL = sqrt(lambda_fl.^2 + tan(alpha1).^2);
% Ft_FL = f_z1 * c1f * (1-exp(-c2f*s_res_FL)) - c3f.*s_res_FL;
% f_y1 = 0.9*(alpha1)./s_res_FL.*Ft_FL;
% 
% s_res_FR = sqrt(lambda_fr.^2 + tan(alpha2).^2);
% Ft_FR = f_z2 .* c1f .* (1-exp(-c2f.*s_res_FR)) - c3f.*s_res_FR;
% f_y2 = 0.9*(alpha2)./s_res_FR.*Ft_FR;
% 
% s_res_RL = sqrt(lambda_rl.^2 + tan(alpha3).^2);
% Ft_RL = f_z3 .* c1r.* (1-exp(-c2r.*s_res_RL)) - c3r.*s_res_RL;
% f_y3 = 0.9*(alpha3)./s_res_RL.*Ft_RL;
% 
% s_res_RR = sqrt(lambda_rr.^2 + tan(alpha4).^2);
% Ft_RR = f_z4 .* c1r .* (1-exp(-c2r.*s_res_RR)) - c3r.*s_res_RR;
% f_y4 = 0.9*(alpha4)./s_res_RR.*Ft_RR;
% c1f =0.37;
% c1r = 0.5;
% c2f =20;
% c2r =28;
% c3f =0.6;
% c3r =1;
% c1f =0.9; c1r = 0.5; c2f =30; c2r =21.026; c3f =0.06; c3r =0.1;
% 
% Ft_FL = f_z1 * c1f * (1-exp(-c2f*s_res_FL)) - c3f.*s_res_FL;
% Ft_FR = f_z2 .* c1f .* (1-exp(-c2f.*s_res_FR)) - c3f.*s_res_FR;
% Ft_RL = f_z3 .* c1r.* (1-exp(-c2r.*s_res_RL)) - c3r.*s_res_RL;
% Ft_RR = f_z4 .* c1r .* (1-exp(-c2r.*s_res_RR)) - c3r.*s_res_RR;
% f_x1 = lambda_fl/s_res_FL*Ft_FL;
% f_x2 = lambda_fr/s_res_FR*Ft_FR;
% f_x3 = lambda_rl/s_res_RL*Ft_RL;
% f_x4 = lambda_rr/s_res_RR*Ft_RR;
% 
% T_w=diag([1,1,1,1,1,1,1,1]);
% 
% % -------------------- system matrices (same as your code) --------------------
% L_c=[1 0 1 0 1 0 1 0;
%      0 1 0 1 0 1 0 1;
%      -d/2 a d/2 a -d/2 -b d/2 -b];
% 
% L_w1=[cos(Steering1_act) -sin(Steering1_act);sin(Steering1_act) cos(Steering1_act)];
% L_w2=[cos(Steering2_act) -sin(Steering2_act);sin(Steering2_act) cos(Steering2_act)];
% L_w3=[cos(Steering3_act) -sin(Steering3_act);sin(Steering3_act) cos(Steering3_act)];
% L_w4=[cos(Steering4_act) -sin(Steering4_act);sin(Steering4_act) cos(Steering4_act)];
% L_w=blkdiag(L_w1,L_w2,L_w3,L_w4);
% 
% B11=[0 0 0 0;-c_alpha_f/vx_safe -a*c_alpha_f/vx_safe 0 0];
% B12=[0 0 0 0;-c_alpha_f/vx_safe -a*c_alpha_f/vx_safe 0 0];
% B13=[0 0 0 0;-c_alpha_r/vx_safe  b*c_alpha_r/vx_safe 0 0];
% B14=[0 0 0 0;-c_alpha_r/vx_safe  b*c_alpha_r/vx_safe 0 0];
% B1=[B11' B12' B13' B14']';
% 
% B21=[1/R_w 0;0 c_alpha_f];
% B22=[1/R_w 0;0 c_alpha_f];
% B23=[1/R_w 0;0 c_alpha_r];
% B24=[1/R_w 0;0 c_alpha_r];
% B2=blkdiag(B21,B22,B23,B24);
% 
% D11=[0 f_y1-c_alpha_f*alpha1]';
% D12=[0 f_y2-c_alpha_f*alpha2]';
% D13=[0 f_y3-c_alpha_r*alpha3]';
% D14=[0 f_y4-c_alpha_r*alpha4]';
% D1=[D11' D12' D13' D14']';
% 
% Af13=-m_s*h_s*(k_roll-m_s*g*h_s)/(-m_s*m_s*h_s*h_s+m*I_x);
% Af14=-m_s*h_s*c_roll/(-m_s*m_s*h_s*h_s+m*I_x);
% Af43=-m*(k_roll-m_s*g*h_s)/(-m_s*m_s*h_s*h_s+m*I_x);
% Af44=-m*c_roll/(-m_s*m_s*h_s*h_s+m*I_x);
% Bf12=I_x/(-m_s*m_s*h_s*h_s+m*I_x);
% Bf42=m_s*h_s/(-m_s*m_s*h_s*h_s+m*I_x);
% 
% A_f=[0 -vx Af13 Af14;0 0 0 0;0 0 0 1;0 0 Af43 Af44];
% B_f=[0 Bf12 0;0 0 1/I_z;0 0 0;0 Bf42 0];
% 
% A_b=A_f+B_f*L_c*L_w*B1;
% B_b=B_f*L_c*L_w*B2*T_w*T_v;
% C_b=B_f*L_c*L_w*B2*T_v;
% D_b=B_f*L_c*L_w*D1;
% 
% A_w=zeros(4,4);
% M_r=0.0038+9.36*10^(-5)*vx+0.00085;
% B_w=1/I_w*[T_w(1,1)*T_v(1,1) 0 0 0 0 0 0 0;
%            0 0 T_w(3,3)*T_v(3,3) 0 0 0 0 0;
%            0 0 0 0 T_w(5,5)*T_v(5,5) 0 0 0;
%            0 0 0 0 0 0 T_w(7,7)*T_v(7,7) 0];
% C_w=1/I_w*[T_v(1,1) 0 0 0 0 0 0 0;
%            0 0 T_v(3,3) 0 0 0 0 0;
%            0 0 0 0 T_v(5,5) 0 0 0;
%            0 0 0 0 0 0 T_v(7,7) 0];
% D_w=1/I_w*[-R_w*f_x1-M_r*0.25*m*g*R_w;
%            -R_w*f_x2-M_r*0.25*m*g*R_w;
%            -R_w*f_x3-M_r*0.25*m*g*R_w;
%            -R_w*f_x4-M_r*0.25*m*g*R_w];
% 
% A=blkdiag(A_b,A_w);
% B=[B_b' B_w']';
% C=[C_b' C_w']';
% D=[D_b' D_w']';
% 
% A_d=eye(8)+A*Ts;
% B_d=B*Ts;
% C_d=C*Ts;
% D_d=D*Ts;
% 
% % ==========================================================
% % ==========【新增/修改 1】误差状态 + D_eff 修正 ==========
% % ==========================================================
% Nx = 8;
% x_ref0=[0; yawrate_ref; 0; 0; vx/R_w; vx/R_w; vx/R_w; vx/R_w];  % 当前参考
% x0    = x_abs - x_ref0;                                         % 误差状态
% D_eff = D_d + (A_d - eye(Nx))*x_ref0;                            % 关键：常值项修正
% % ==========================================================
% 
% %% -------- build prediction matrices --------
% N=10;
% Nx=8;
% Nd=1;
% Nw=8;
% Nu=8;
% 
% Sx=zeros(N*Nx,Nx,'double');
% Sx(1:Nx,:)=A_d;
% for i=2:N
%     Sx(1+(i-1)*Nx:i*Nx,:)=A_d^i;
% end
% 
% Su = zeros(N*Nx, Nu*N);
% Su(1:Nx, 1:Nu) = B_d;
% for i = 2:N
%     Su((i-1)*Nx+1:i*Nx, (i-1)*Nu+1:i*Nu) = B_d;
%     for j = 1:i-1
%         prev_block = Su((i-2)*Nx+1:(i-1)*Nx, (j-1)*Nu+1:j*Nu);
%         Su((i-1)*Nx+1:i*Nx, (j-1)*Nu+1:j*Nu) = A_d * prev_block;
%     end
% end
% 
% % 初始化
% Sw = zeros(N*Nx, Nw);
% Sd = zeros(N*Nx, 1);
% 
% % ==========================================================
% % ==========【修改 2】Sd 用 D_eff（不是 D_d） ==========
% % ==========================================================
% for i = 1:N
%     accum = zeros(Nx, Nw);
%     accum_d = zeros(Nx, 1);
%     for j = 1:i
%         power = i - j;
%         if power == 0
%             block = C_d;
%             block_d = D_eff;              % <-- 改这里
%         else
%             block = A_d^power * C_d;
%             block_d = A_d^power * D_eff;  % <-- 改这里
%         end
%         accum = accum + block;
%         accum_d = accum_d + block_d;
%     end
%     Sw((i-1)*Nx+1:i*Nx, :) = accum;
%     Sd((i-1)*Nx+1:i*Nx, :) = accum_d;
% end
% 
% %% -------- QP cost (误差跟踪：ref=0) --------
% Qmax=1600;
% thetamax=40*3.14/180;
% 
% R = kron(eye(N), diag(T_u));
% Qx = diag(T_x);
% 
% H = 2 * (Su' * Qx * Su + R);
% H = (H + H') / 2;
% 
% Ep = - (Sx * x0 + Sw * w0 + Sd);  % 目标：x_e -> 0
% f  = -2 * Su' * Qx * Ep;
% 
% %% -------- vy 约束（对误差坐标同等于绝对，因为 vy_ref=0） --------
% indices = 1:Nx:N*Nx;
% Su1=Su(indices, :);
% Sx1=Sx(indices, :);
% Sw1=Sw(indices, :);
% Sd1=Sd(indices, :);
% 
% E=repmat(vy_max,N,1);
% F=repmat(-vy_max,N,1);
% 
% G=[Su1;-Su1];
% e=[-Sx1*x0-Sw1*w0-Sd1+E; ...
%     Sx1*x0+Sw1*w0+Sd1-F];
% 
% %% -------- friction polygon constraints (hard) --------
% Hx=[-c_alpha_f/vx_safe,-c_alpha_f*a/vx_safe,0,0,0,0,0,0;
%     -c_alpha_f/vx_safe,-c_alpha_f*a/vx_safe,0,0,0,0,0,0;
%     -c_alpha_r/vx_safe, c_alpha_r*b/vx_safe,0,0,0,0,0,0;
%     -c_alpha_r/vx_safe, c_alpha_r*b/vx_safe,0,0,0,0,0,0;
%      0,0,0,0,0,0,0,0;
%      0,0,0,0,0,0,0,0;
%      0,0,0,0,0,0,0,0;
%      0,0,0,0,0,0,0,0];
% 
% Hu=[0,c_alpha_f,0,0,0,0,0,0;
%     0,0,0,c_alpha_f,0,0,0,0;
%     0,0,0,0,0,c_alpha_r,0,0;
%     0,0,0,0,0,0,0,c_alpha_r;
%     1/R_w,0,0,0,0,0,0,0;
%     0,0,1/R_w,0,0,0,0,0;
%     0,0,0,0,1/R_w,0,0,0;
%     0,0,0,0,0,0,1/R_w,0];
% 
% cf=[f_y1+c_alpha_f*Steering1_act-c_alpha_f*alpha1;
%     f_y2+c_alpha_f*Steering2_act-c_alpha_f*alpha2;
%     f_y3+c_alpha_r*Steering3_act-c_alpha_r*alpha3;
%     f_y4+c_alpha_r*Steering4_act-c_alpha_r*alpha4;
%     f_x1; f_x2; f_x3; f_x4];
% 
% A8 = [ 1 0;
%       -1 0;
%        0 1;
%        0 -1;
%        1 1;
%        1 -1;
%       -1 1;
%       -1 -1]; % 8x2
% 
% sqrt2 = sqrt(2);
% b8_1 = [mu1*f_z1*ones(4,1); sqrt2*mu1*f_z1*ones(4,1)];
% b8_2 = [mu2*f_z2*ones(4,1); sqrt2*mu2*f_z2*ones(4,1)];
% b8_3 = [mu3*f_z3*ones(4,1); sqrt2*mu3*f_z3*ones(4,1)];
% b8_4 = [mu4*f_z4*ones(4,1); sqrt2*mu4*f_z4*ones(4,1)];
% b_step = [b8_1; b8_2; b8_3; b8_4]; % 32x1
% 
% Ablk = blkdiag(A8, A8, A8, A8);
% 
% R_n = [0 0 0 0 1 0 0 0;
%        1 0 0 0 0 0 0 0;
%        0 0 0 0 0 1 0 0;
%        0 1 0 0 0 0 0 0;
%        0 0 0 0 0 0 1 0;
%        0 0 1 0 0 0 0 0;
%        0 0 0 0 0 0 0 1;
%        0 0 0 1 0 0 0 0];
% 
% Aforce = Ablk * R_n;
% A_u = Aforce * Hu * T_v * T_w; % 32x8
% A_x = Aforce * Hx; % 32x8
% c_b = b_step - Aforce * cf; % 32x1
% 
% G_fric = zeros(32*N, Nu*N);
% e_fric = zeros(32*N, 1);
% 
% % ==========================================================
% % ==========【修改 4】摩擦约束常数项用绝对状态 ==========
% % ==========================================================
% X_const_e   = (Sx*x0 + Sw*w0 + Sd);            % 误差预测（不含U）
% X_const_abs = X_const_e + repmat(x_ref0,N,1);  % 转绝对用于摩擦约束
% 
% soft_ratio = 0.03;  
% 
% for j = 1:N
%     xj_const = X_const_abs((j-1)*Nx+1:j*Nx);   % <-- 这里改成 abs
%     Su_j = Su((j-1)*Nx+1:j*Nx, :);
% 
%     AxSu_j = A_x * Su_j;       % 32 x (Nu*N)
%     AxConst_j = A_x * xj_const; % 32x1
% 
%     AuEj_j = zeros(32, Nu*N);
%     AuEj_j(:, (j-1)*Nu+1:j*Nu) = A_u;
% 
%     row = (j-1)*32 + (1:32);
%     G_fric(row,:) = AuEj_j + AxSu_j;
%     e_fric(row)   = (c_b - AxConst_j) + soft_ratio*abs(c_b);
% end
% 
% G = [G; G_fric];
% e = [e; e_fric];
% 
% %% -------- bounds --------
% ub=([Qmax,thetamax,Qmax,thetamax,Qmax,thetamax,Qmax,thetamax]'-w0);
% lb=(-[Qmax,thetamax,Qmax,thetamax,Qmax,thetamax,Qmax,thetamax]'-w0);
% ub=repmat(ub,N,1);
% lb=repmat(lb,N,1);
% % ---------- extra tightening for the first move ----------
% Qmax1     = 120;    % 第一拍扭矩增量更紧
% thetamax1 = 0.008;  % 第一拍转角增量更紧
% 
% idx_first = 1:Nu;   % 第一拍 8 个输入
% 
% lb(idx_first) = max(lb(idx_first), ...
%     [-Qmax1; -thetamax1; -Qmax1; -thetamax1; -Qmax1; -thetamax1; -Qmax1; -thetamax1]);
% 
% ub(idx_first) = min(ub(idx_first), ...
%     [ Qmax1;  thetamax1;  Qmax1;  thetamax1;  Qmax1;  thetamax1;  Qmax1;  thetamax1]);
% %% -------- quadprog --------
% options = optimoptions('quadprog', ...
%     'Display','off', ...
%     'Algorithm','active-set', ...
%     'MaxIterations', 400, ...
%     'ConstraintTolerance', 1e-4, ...
%     'OptimalityTolerance', 1e-3);
% 
% U0 = repmat(U_last, N, 1);
% 
% [U_full, ~, exitflag, output] = quadprog(H,f,G,e,[],[],lb,ub,U0,options);
% % 
% % assignin('base','qp_message', output.message);
% % assignin('base','qp_iter', output.iterations);
% %% ===== debug monitor: put after U is selected =====
% 
% % 命令输入与实际执行输入
% U_cmd = U;
% U_actual = T_v * T_w * U_cmd;
% 
% % 如果 U_full 可用，就看完整预测；否则用当前 U 拼一个近似序列
% if exist('U_full','var') && ~isempty(U_full)
%     U_seq = U_full;
% else
%     U_seq = repmat(U_cmd, N, 1);
% end
% 
% % 预测误差状态序列
% X_pred_e = Sx*x0 + Su*U_seq + Sw*w0 + Sd;
% 
% % 第一步预测误差状态与绝对状态
% x1_pred_e   = X_pred_e(1:Nx);
% x1_pred_abs = x1_pred_e + x_ref0;
% 
% % 一步控制贡献
% control_effect = B_d * U_cmd;
% base_effect    = C_d * w0;
% total_effect   = control_effect + base_effect;
% 
% % 第一拍实际控制产生的广义力/力矩
% % general_force = [Fx_total; Fy_total; Mz_total]
% general_force = L_c * L_w * B2 * U_actual;
% 
% Fx_total = general_force(1);
% Fy_total = general_force(2);
% Mz_total = general_force(3);
% 
% % 代价函数分解
% J_state = X_pred_e' * Qx * X_pred_e;
% J_input = U_seq' * R * U_seq;
% J_total = J_state + J_input;
% 
% % 约束违反情况
% if exist('G','var') && exist('e','var') && exist('U_seq','var')
%     vio_all = G*U_seq - e;
%     [maxvio_debug, active_idx] = max(vio_all);
% else
%     maxvio_debug = NaN;
%     active_idx = NaN;
% end
% 
% % 摩擦约束单独看
% if exist('G_fric','var') && exist('e_fric','var')
%     vio_fric = G_fric*U_seq - e_fric;
%     [maxvio_fric, active_idx_fric] = max(vio_fric);
% else
%     maxvio_fric = NaN;
%     active_idx_fric = NaN;
% end
% 
% % 侧偏角 beta
% beta_now = atan2(vy, max(abs(vx),1e-3));
% beta_1_pred = atan2(x1_pred_abs(1), max(abs(vx),1e-3));
% 
% % 汇总成一个结构体，方便工作区查看
% debug_mpc = struct();
% 
% debug_mpc.exitflag = exitflag;
% debug_mpc.max_violation = maxvio_debug;
% debug_mpc.active_idx = active_idx;
% debug_mpc.maxvio_fric = maxvio_fric;
% debug_mpc.active_idx_fric = active_idx_fric;
% 
% debug_mpc.U_cmd = U_cmd;
% debug_mpc.U_actual = U_actual;
% 
% debug_mpc.Fx_total = Fx_total;
% debug_mpc.Fy_total = Fy_total;
% debug_mpc.Mz_total = Mz_total;
% debug_mpc.general_force = general_force;
% 
% debug_mpc.x_now_abs = x_abs;
% debug_mpc.x_ref0 = x_ref0;
% debug_mpc.x0_error = x0;
% debug_mpc.x1_pred_e = x1_pred_e;
% debug_mpc.x1_pred_abs = x1_pred_abs;
% 
% debug_mpc.yawrate_now = yawrate;
% debug_mpc.yawrate_ref = yawrate_ref;
% debug_mpc.yawrate_error_now = yawrate - yawrate_ref;
% debug_mpc.yawrate_error_1step = x1_pred_e(2);
% 
% debug_mpc.vy_now = vy;
% debug_mpc.vy_1step = x1_pred_abs(1);
% debug_mpc.beta_now = beta_now;
% debug_mpc.beta_1step = beta_1_pred;
% 
% debug_mpc.control_effect = control_effect;
% debug_mpc.base_effect = base_effect;
% debug_mpc.total_effect = total_effect;
% 
% debug_mpc.J_state = J_state;
% debug_mpc.J_input = J_input;
% debug_mpc.J_total = J_total;
% 
% assignin('base','debug_mpc',debug_mpc);
% 
% % 命令行集中打印
% fprintf('\n====== MPC DEBUG ======\n');
% fprintf('exitflag        = %d\n', exitflag);
% fprintf('max_violation   = %.6e\n', maxvio_debug);
% fprintf('active_idx      = %d\n', active_idx);
% fprintf('maxvio_fric     = %.6e\n', maxvio_fric);
% fprintf('active_idx_fric = %d\n', active_idx_fric);
% 
% fprintf('\nU_cmd = \n');
% disp(U_cmd.');
% 
% fprintf('U_actual = \n');
% disp(U_actual.');
% 
% fprintf('\nGeneral force [Fx, Fy, Mz] = [%.6f, %.6f, %.6f]\n', ...
%         Fx_total, Fy_total, Mz_total);
% 
% fprintf('\nyawrate_now/ref/error = %.6f / %.6f / %.6f\n', ...
%         yawrate, yawrate_ref, yawrate - yawrate_ref);
% fprintf('yawrate_error_1step   = %.6f\n', x1_pred_e(2));
% 
% fprintf('vy_now / vy_1step     = %.6f / %.6f\n', ...
%         vy, x1_pred_abs(1));
% fprintf('beta_now / beta_1step = %.6f / %.6f\n', ...
%         beta_now, beta_1_pred);
% 
% fprintf('\nJ_state = %.6e\n', J_state);
% fprintf('J_input = %.6e\n', J_input);
% fprintf('J_total = %.6e\n', J_total);
% fprintf('=======================\n');
% if ~isempty(U_full)
%     max_violation = max(G*U_full - e);
% else
%     max_violation = NaN;
% end
% % assignin('base','mpc_exitflag',exitflag);
% % assignin('base','mpc_maxvio',max_violation);
% 
% tol_feas = 1e-6;
% use_sol = ~isempty(U_full) && isfinite(max_violation) && (max_violation <= tol_feas) ...
%           && (exitflag==1 || exitflag==0);
% 
% if use_sol
%     U = U_full(1:Nu);
%     % U_prev_full = [U_full(Nu+1:end); U_full(end-Nu+1:end)];
% else
%     U = U_last;
%     % U_prev_full = repmat(U_last, N, 1);
% end
% 
% 
% %% -------- outputs --------
% %MPC_output = zeros(18,1);
% MPC_output(1:8) = U(:);
% 
% % 一步预测：先算误差，再转回绝对
% x_next_e   = A_d*x0 + B_d*U + C_d*w0 + D_eff;
% % x_next_abs = x_next_e + x_ref0;
% U_cmd = U;
% U_actual = T_v*T_w*U;
% 
% assignin('base','U_cmd',U_cmd);
% assignin('base','U_actual',U_actual);
% MPC_output(9)  = x_next_e(1);
% MPC_output(10) = x_next_e(2);
% MPC_output(11) =x_next_e(3);
% MPC_output(12) = x_next_e(4);
% MPC_output(13) = x_next_e(5);
% MPC_output(14) = x_next_e(6);
% MPC_output(15) = x_next_e(7);
% MPC_output(16) = x_next_e(8);
% MPC_output(17) = exitflag;
% MPC_output(18) = max_violation;
% %end