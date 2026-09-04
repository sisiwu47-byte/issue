function vy_lifesig_fusion_simulink_sfun(block)
%VY_LIFESIG_FUSION_SIMULINK_SFUN Stateful Simulink boundary.
% The wrapper owns only last-valid memory.  All fusion and health values are
% delegated to vy_lifesig_fusion_step.

setup(block);
end

function setup(block)
block.NumDialogPrms = 0;
block.NumInputPorts = 8;
block.NumOutputPorts = 9;

for k=1:8
    block.InputPort(k).Dimensions = 1;
    block.InputPort(k).DatatypeID = 0;
    block.InputPort(k).Complexity = 'Real';
    block.InputPort(k).DirectFeedthrough = true;
end
for k=1:9
    block.OutputPort(k).Dimensions = 1;
    block.OutputPort(k).DatatypeID = 0;
    block.OutputPort(k).Complexity = 'Real';
end

block.SampleTimes = [0.01 0];
block.SimStateCompliance = 'DefaultSimState';
block.SetAccelRunOnTLC(false);

block.RegBlockMethod('PostPropagationSetup',@post_propagation_setup);
block.RegBlockMethod('InitializeConditions',@initialize_conditions);
block.RegBlockMethod('Outputs',@outputs);
block.RegBlockMethod('Update',@update);
end

function post_propagation_setup(block)
block.NumDworks = 2;

block.Dwork(1).Name = 'last_valid_Vy_LS';
block.Dwork(1).Dimensions = 1;
block.Dwork(1).DatatypeID = 0;
block.Dwork(1).Complexity = 'Real';
block.Dwork(1).UsedAsDiscState = true;

block.Dwork(2).Name = 'has_last_valid';
block.Dwork(2).Dimensions = 1;
block.Dwork(2).DatatypeID = 0;
block.Dwork(2).Complexity = 'Real';
block.Dwork(2).UsedAsDiscState = true;
end

function initialize_conditions(block)
block.Dwork(1).Data = 0;
block.Dwork(2).Data = 0;
end

function outputs(block)
[Vy_LS,alpha_D,alpha_K,alpha_F,fusion_valid,fallback_active,~,~, ...
    H_D,H_K,H_F] = evaluate_core(block);
block.OutputPort(1).Data = Vy_LS;
block.OutputPort(2).Data = alpha_D;
block.OutputPort(3).Data = alpha_K;
block.OutputPort(4).Data = alpha_F;
block.OutputPort(5).Data = H_D;
block.OutputPort(6).Data = H_K;
block.OutputPort(7).Data = H_F;
block.OutputPort(8).Data = fusion_valid;
block.OutputPort(9).Data = fallback_active;
end

function update(block)
[~,~,~,~,~,~,lastNext,hasNext] = evaluate_core(block);
block.Dwork(1).Data = lastNext;
block.Dwork(2).Data = hasNext;
end

function [Vy_LS,alpha_D,alpha_K,alpha_F,fusion_valid,fallback_active, ...
    lastNext,hasNext,H_D,H_K,H_F] = evaluate_core(block)
[Vy_LS,alpha_D,alpha_K,alpha_F,fusion_valid,fallback_active, ...
    lastNext,hasNext,H_D,H_K,H_F] = vy_lifesig_fusion_step( ...
    double(block.InputPort(1).Data),double(block.InputPort(2).Data), ...
    double(block.InputPort(3).Data),double(block.InputPort(4).Data), ...
    double(block.InputPort(5).Data),double(block.InputPort(6).Data), ...
    double(block.InputPort(7).Data),double(block.InputPort(8).Data), ...
    block.Dwork(1).Data,block.Dwork(2).Data);
end
