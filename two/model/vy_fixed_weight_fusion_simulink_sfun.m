function vy_fixed_weight_fusion_simulink_sfun(block)
%VY_FIXED_WEIGHT_FUSION_SIMULINK_SFUN Stateless three-track fusion boundary.
% The wrapper contains no fusion equation and delegates every evaluation to
% the frozen vy_fixed_weight_fusion_step core.

setup(block);
end

function setup(block)
block.NumDialogPrms = 3;
block.NumInputPorts = 3;
block.NumOutputPorts = 1;

for k = 1:3
    block.InputPort(k).Dimensions = 1;
    block.InputPort(k).DatatypeID = 0;
    block.InputPort(k).Complexity = 'Real';
    block.InputPort(k).DirectFeedthrough = true;
end

block.OutputPort(1).Dimensions = 1;
block.OutputPort(1).DatatypeID = 0;
block.OutputPort(1).Complexity = 'Real';

% The block is a stateless 100-Hz algebraic combiner. It registers no DWork,
% persistent/global storage, or Update method.
block.SampleTimes = [0.01 0];
block.SimStateCompliance = 'DefaultSimState';
block.SetAccelRunOnTLC(false);

block.RegBlockMethod('CheckParameters', @check_parameters);
block.RegBlockMethod('Outputs', @outputs);
end

function check_parameters(block)
% Delegate legal-weight checking to the single frozen mathematical core.
vy_fixed_weight_fusion_step(0, 0, 0, ...
    block.DialogPrm(1).Data, block.DialogPrm(2).Data, ...
    block.DialogPrm(3).Data);
end

function outputs(block)
block.OutputPort(1).Data = vy_fixed_weight_fusion_step( ...
    block.InputPort(1).Data, block.InputPort(2).Data, ...
    block.InputPort(3).Data, block.DialogPrm(1).Data, ...
    block.DialogPrm(2).Data, block.DialogPrm(3).Data);
end
