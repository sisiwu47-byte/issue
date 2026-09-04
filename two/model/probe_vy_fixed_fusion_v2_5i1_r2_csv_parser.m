% V2.5-I1-R2 parser-only probe. No model, Simulink, CarSim, or runtime access.
root=fileparts(fileparts(mfilename('fullpath')));
csvPath=fullfile(root,'results','vy_fixed_fusion_v2_5i_holdout_preexecution_registry.csv');
assert(isfile(csvPath),'R2:MissingRegistry','Immutable H01 preregistry CSV is missing.');
T=readtable(csvPath,'Delimiter',',','VariableNamingRule','preserve','TextType','string');
fprintf('R2_PARSED_WIDTH=%d\n',width(T));
disp(T.Properties.VariableNames');
assert(width(T)==32,'R2:Schema','Expected 32 preregistry columns, got %d.',width(T));
names=T.Properties.VariableNames;
assert(~any(startsWith(string(names),'Var')),'R2:VarNFallback','Positional VarN schema detected.');
required={...
    'run_id','role','execution_order','original_status','runtime_authorization',...
    'steering_amplitude','steering_frequency','duration','estimator_rate','waveform',...
    'speed_scope','truth_alignment_rule','evaluation_window_rule','formal_result_path',...
    'data_viewed','weight_set_id','runtime_alpha_D','runtime_alpha_K','runtime_alpha_F',...
    'target_path','target_sha256'};
assert(all(ismember(required,names)),'R2:RequiredFields','Required named fields are missing.');
h01=T(T.execution_order==1,:);
assert(height(h01)==1,'R2:H01Row','Expected exactly one execution_order==1 row.');
assert(h01.run_id=="FWHOLD_H01"&&h01.role=="HOLDOUT_VALIDATION",'R2:H01Identity','H01 identity mismatch.');
assert(double(h01.original_registry_row)==7,'R2:H01RegistryRow','Original registry row mismatch.');
assert(double(h01.steering_amplitude)==0.025&&double(h01.steering_frequency)==0.35&& ...
    double(h01.duration)==16&&double(h01.estimator_rate)==100,'R2:H01Condition','Frozen H01 condition mismatch.');
assert(h01.waveform=="SINE_FRONT_EQUAL_REAR_ZERO",'R2:H01Waveform','Frozen waveform mismatch.');
fprintf('R2_H01|run_id=%s|role=%s|amplitude=%.17g|frequency=%.17g|duration=%.17g|rate=%.17g\n', ...
    string(h01.run_id),string(h01.role),double(h01.steering_amplitude),double(h01.steering_frequency), ...
    double(h01.duration),double(h01.estimator_rate));
disp('R2_PARSER_PROBE_OK');
exit(0);
