function vy_feedback_propagation_simulink_sfun(block)
%VY_FEEDBACK_PROPAGATION_SIMULINK_SFUN Stateful Simulink boundary.
% The boundary owns only previous output state/covariance and the three
% one-sample feedback memories. Propagation mathematics remains in the
% frozen vy_feedback_propagation_step function.

setup(block);
end

function setup(block)
block.NumDialogPrms = 4; % Ts, Vy_F0, P0_F, Q_F
block.NumInputPorts = 7;
block.NumOutputPorts = 4;
block.SetPreCompInpPortInfoToDynamic;
block.SetPreCompOutPortInfoToDynamic;

for k = 1:7
    block.InputPort(k).Dimensions = 1;
    block.InputPort(k).DatatypeID = 0;
    block.InputPort(k).Complexity = 'Real';
end
block.InputPort(1).DirectFeedthrough = true;  % Ay_IMU
block.InputPort(2).DirectFeedthrough = true;  % AVz_IMU
block.InputPort(3).DirectFeedthrough = true;  % Vx_source
block.InputPort(4).DirectFeedthrough = false; % Vy_feedback_current
block.InputPort(5).DirectFeedthrough = false; % P_feedback_current
block.InputPort(6).DirectFeedthrough = false; % feedback_valid_current
block.InputPort(7).DirectFeedthrough = true;  % reset

block.OutputPort(1).Dimensions = 1;
block.OutputPort(2).Dimensions = 1;
block.OutputPort(3).Dimensions = [3 1];
block.OutputPort(4).Dimensions = [3 1]; % [age_steps; age_valid; reset_valid]
for k = 1:4
    block.OutputPort(k).DatatypeID = 0;
    block.OutputPort(k).Complexity = 'Real';
end

block.SampleTimes = [-1 0];
block.SimStateCompliance = 'DefaultSimState';
block.SetAccelRunOnTLC(false);

block.RegBlockMethod('CheckParameters', @check_parameters);
block.RegBlockMethod('PostPropagationSetup', @post_propagation_setup);
block.RegBlockMethod('InitializeConditions', @initialize_conditions);
block.RegBlockMethod('Outputs', @outputs);
block.RegBlockMethod('Update', @update);
end

function check_parameters(block)
[Ts, Vy_F0, P0_F, Q_F] = parameters(block);
assert(isfinite(Ts) && Ts > 0, ...
    'vy_feedback_propagation_simulink_sfun:InvalidTs', ...
    'Ts must be finite and positive.');
assert(isfinite(Vy_F0), ...
    'vy_feedback_propagation_simulink_sfun:InvalidInitialState', ...
    'Vy_F0 must be finite.');
assert(isfinite(P0_F) && P0_F > 0, ...
    'vy_feedback_propagation_simulink_sfun:InvalidInitialCovariance', ...
    'P0_F must be finite and positive.');
assert(isfinite(Q_F) && Q_F >= 0, ...
    'vy_feedback_propagation_simulink_sfun:InvalidProcessVariance', ...
    'Q_F must be finite and nonnegative.');
end

function post_propagation_setup(block)
block.NumDworks = 6;

block.Dwork(1).Name = 'Vy_prev';
block.Dwork(1).Dimensions = 1;
block.Dwork(1).DatatypeID = 0;
block.Dwork(1).Complexity = 'Real';
block.Dwork(1).UsedAsDiscState = true;

block.Dwork(2).Name = 'P_prev';
block.Dwork(2).Dimensions = 1;
block.Dwork(2).DatatypeID = 0;
block.Dwork(2).Complexity = 'Real';
block.Dwork(2).UsedAsDiscState = true;

block.Dwork(3).Name = 'Vy_feedback_z1';
block.Dwork(3).Dimensions = 1;
block.Dwork(3).DatatypeID = 0;
block.Dwork(3).Complexity = 'Real';
block.Dwork(3).UsedAsDiscState = true;

block.Dwork(4).Name = 'P_feedback_z1';
block.Dwork(4).Dimensions = 1;
block.Dwork(4).DatatypeID = 0;
block.Dwork(4).Complexity = 'Real';
block.Dwork(4).UsedAsDiscState = true;

block.Dwork(5).Name = 'feedback_valid_z1';
block.Dwork(5).Dimensions = 1;
block.Dwork(5).DatatypeID = 0;
block.Dwork(5).Complexity = 'Real';
block.Dwork(5).UsedAsDiscState = true;

block.Dwork(6).Name = 'propagation_age_steps';
block.Dwork(6).Dimensions = 1;
block.Dwork(6).DatatypeID = 0;
block.Dwork(6).Complexity = 'Real';
block.Dwork(6).UsedAsDiscState = true;
end

function initialize_conditions(block)
[~, Vy_F0, P0_F, ~] = parameters(block);
block.Dwork(1).Data = Vy_F0;
block.Dwork(2).Data = P0_F;
block.Dwork(3).Data = Vy_F0;
block.Dwork(4).Data = P0_F;
block.Dwork(5).Data = 0;
block.Dwork(6).Data = 0;
end

function outputs(block)
[Ts, Vy_F0, P0_F, Q_F] = parameters(block);
[Vy_F, P_F, diag_F] = vy_feedback_propagation_step( ...
    block.Dwork(1).Data, block.Dwork(2).Data, ...
    double(block.InputPort(1).Data), ...
    double(block.InputPort(2).Data), ...
    double(block.InputPort(3).Data), ...
    block.Dwork(3).Data, block.Dwork(4).Data, block.Dwork(5).Data, ...
    double(block.InputPort(7).Data), Ts, Vy_F0, P0_F, Q_F);
block.OutputPort(1).Data = Vy_F;
block.OutputPort(2).Data = P_F;
block.OutputPort(3).Data = diag_F;

% Reliability diagnostics are produced at the same hit as the successful
% propagation.  The age is the number of completed increments since the
% most recent accepted reset: reset -> 0, first valid propagation -> 1.
resetRaw = double(block.InputPort(7).Data);
resetValid = isfinite(resetRaw);
resetActive = resetValid && (resetRaw ~= 0);
finiteInputs = all(isfinite([block.Dwork(1).Data; block.Dwork(2).Data; ...
    block.InputPort(1).Data; block.InputPort(2).Data; block.InputPort(3).Data; ...
    block.InputPort(4).Data; block.InputPort(5).Data; block.InputPort(6).Data]));
propagationSucceeded = finiteInputs && isfinite(Vy_F) && isfinite(P_F) && ...
    all(isfinite(diag_F(:))) && P_F >= 0;
if resetActive
    ageOut = 0; ageValid = resetValid && propagationSucceeded;
elseif propagationSucceeded
    ageOut = double(block.Dwork(6).Data) + 1;
    ageValid = true;
else
    ageOut = double(block.Dwork(6).Data);
    ageValid = false;
end
block.OutputPort(4).Data = [ageOut; double(ageValid); double(resetValid)];
end

function update(block)
[~, Vy_F0, P0_F, ~] = parameters(block);
resetActive = double(block.InputPort(7).Data) ~= 0;
resetValid = isfinite(double(block.InputPort(7).Data));
if resetActive && resetValid
    block.Dwork(1).Data = Vy_F0;
    block.Dwork(2).Data = P0_F;
    block.Dwork(3).Data = Vy_F0;
    block.Dwork(4).Data = P0_F;
    block.Dwork(5).Data = 0;
    block.Dwork(6).Data = 0;
    return
end

block.Dwork(1).Data = block.OutputPort(1).Data;
block.Dwork(2).Data = block.OutputPort(2).Data;
block.Dwork(3).Data = double(block.InputPort(4).Data);
block.Dwork(4).Data = double(block.InputPort(5).Data);
block.Dwork(5).Data = double(block.InputPort(6).Data);
rel = block.OutputPort(4).Data;
if rel(2) > 0.5
    block.Dwork(6).Data = rel(1);
end
end

function [Ts, Vy_F0, P0_F, Q_F] = parameters(block)
Ts = double(block.DialogPrm(1).Data);
Vy_F0 = double(block.DialogPrm(2).Data);
P0_F = double(block.DialogPrm(3).Data);
Q_F = double(block.DialogPrm(4).Data);
end
