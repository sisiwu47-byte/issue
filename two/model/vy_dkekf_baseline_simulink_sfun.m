function vy_dkekf_baseline_simulink_sfun(block)
%VY_DKEKF_BASELINE_SIMULINK_SFUN Interpreted numeric Simulink boundary.
% This Level-2 MATLAB S-function owns only the wrapper-equivalent x/P/reset
% interface state. All DK-EKF prediction and measurement mathematics remain
% in the frozen vy_dkekf_baseline_step function.

setup(block);
end

function setup(block)
block.NumDialogPrms = 0;
block.NumInputPorts = 7;
block.NumOutputPorts = 3;
block.SetPreCompInpPortInfoToDynamic;
block.SetPreCompOutPortInfoToDynamic;

inputDimensions = {1, [4 1], 1, 1, 1, 1, 1};
for k = 1:block.NumInputPorts
    block.InputPort(k).Dimensions = inputDimensions{k};
    block.InputPort(k).DatatypeID = 0; % double
    block.InputPort(k).Complexity = 'Real';
    block.InputPort(k).DirectFeedthrough = true;
end

block.OutputPort(1).Dimensions = [3 1];
block.OutputPort(2).Dimensions = [3 3];
block.OutputPort(3).Dimensions = [7 1];
for k = 1:block.NumOutputPorts
    block.OutputPort(k).DatatypeID = 0; % double
    block.OutputPort(k).Complexity = 'Real';
end

block.SampleTimes = [-1 0];
block.SimStateCompliance = 'DefaultSimState';
block.SetAccelRunOnTLC(false);

block.RegBlockMethod('PostPropagationSetup', @post_propagation_setup);
block.RegBlockMethod('InitializeConditions', @initialize_conditions);
block.RegBlockMethod('Outputs', @outputs);
block.RegBlockMethod('Update', @update);
end

function post_propagation_setup(block)
block.NumDworks = 3;

block.Dwork(1).Name = 'xState';
block.Dwork(1).Dimensions = 3;
block.Dwork(1).DatatypeID = 0;
block.Dwork(1).Complexity = 'Real';
block.Dwork(1).UsedAsDiscState = true;

block.Dwork(2).Name = 'PState';
block.Dwork(2).Dimensions = 9;
block.Dwork(2).DatatypeID = 0;
block.Dwork(2).Complexity = 'Real';
block.Dwork(2).UsedAsDiscState = true;

block.Dwork(3).Name = 'initialized';
block.Dwork(3).Dimensions = 1;
block.Dwork(3).DatatypeID = 0;
block.Dwork(3).Complexity = 'Real';
block.Dwork(3).UsedAsDiscState = true;
end

function initialize_conditions(block)
block.Dwork(1).Data = zeros(3,1);
block.Dwork(2).Data = reshape(0.1*eye(3),9,1);
block.Dwork(3).Data = 0;
end

function outputs(block)
Ax_IMU = double(block.InputPort(1).Data);
steering = double(block.InputPort(2).Data);
z_Vx = double(block.InputPort(3).Data);
z_r = double(block.InputPort(4).Data);
z_Ay = double(block.InputPort(5).Data);
doAyUpdate = double(block.InputPort(6).Data);
resetFlag = double(block.InputPort(7).Data);

[par, cfg, Ts, P0] = baseline_configuration();
if block.Dwork(3).Data < 0.5 || resetFlag > 0.5
    xPrior = [z_Vx; 0; 0];
    PPrior = P0;
else
    xPrior = block.Dwork(1).Data;
    PPrior = reshape(block.Dwork(2).Data,3,3);
end

[xNew, PNew, info] = vy_dkekf_baseline_step( ...
    xPrior, PPrior, Ax_IMU, steering, z_Vx, z_r, z_Ay, ...
    doAyUpdate, Ts, par, cfg);

% Fixed diagnostic order:
% [NIS_Vx; NIS_r; NIS_Ay; AyUpdateApplied;
%  innovation_Vx; innovation_r; innovation_Ay].
% A skipped Ay update has NaN NIS in the frozen core; numeric packaging
% maps only that unavailable diagnostic to zero and preserves its explicit
% updateApplied flag.
nisAy = info.Ay.NIS;
if ~info.Ay.updateApplied && isnan(nisAy)
    nisAy = 0;
end
diagNumeric = [info.Vx.NIS; info.r.NIS; nisAy; ...
    double(info.Ay.updateApplied); info.Vx.innovation; ...
    info.r.innovation; info.Ay.innovation];

block.OutputPort(1).Data = xNew;
block.OutputPort(2).Data = PNew;
block.OutputPort(3).Data = diagNumeric;
end

function update(block)
% Commit the already-computed outputs exactly once per major/function-call
% hit. Repeated Outputs evaluations read the same DWork snapshot and cannot
% advance the committed estimator state.
block.Dwork(1).Data = block.OutputPort(1).Data;
block.Dwork(2).Data = reshape(block.OutputPort(2).Data,9,1);
block.Dwork(3).Data = 1;
end

function [par, cfg, Ts, P0] = baseline_configuration()
% Frozen wrapper configuration mapping; no EKF mathematics is implemented
% in this boundary.
par = struct('m',1860,'Iz',2687.1,'a',1.18,'b',1.77, ...
    'track',1.575,'Rw',0.393,'k_f',0.78181,'k_r',1.09186);
Ts = 0.01;
cfg = struct();
cfg.Q_DK = diag([1e-4, 1e-4, 1e-4]);
cfg.R_Vx = 1e-4;
cfg.R_r = 3.365172961808e-4;
cfg.R_Ay = 1e-2;
cfg.jacobianStep = 1e-6;
cfg.denomEps = 1e-12;
cfg.lambda = zeros(4,1);
P0 = diag([0.1, 0.1, 0.1]);
end
