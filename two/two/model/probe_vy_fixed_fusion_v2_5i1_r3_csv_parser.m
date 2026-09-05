% V2.5-I1-R3 self-reporting CSV parser probe. No model/runtime access.
root=fileparts(fileparts(mfilename('fullpath')));
reportPath=fullfile(root,'results','vy_fixed_fusion_v2_5i1_r3_matlab_probe_result.csv');
csvPath=fullfile(root,'results','vy_fixed_fusion_v2_5i_holdout_preexecution_registry.csv');
state=struct('status','FAIL','probe_entered',false,'readtable_attempted',false,'readtable_completed',false, ...
    'parsed_width',NaN,'formal_names_preserved',false,'required_fields_pass',false,'selected_row_count',NaN, ...
    'selected_run_id','','selected_role','','selected_amplitude',NaN,'selected_frequency',NaN, ...
    'selected_duration',NaN,'selected_rate',NaN,'sim_called',false,'formal_target_loaded',false, ...
    'CarSim_started',false,'holdout_runtime_data_read',false,'failure_stage','','exception_identifier','','exception_message','');
try
    state.probe_entered=true; disp('R3_PROBE_ENTERED');
    assert(isfile(csvPath),'R3:MissingRegistry','Immutable preregistry CSV is missing.');
    state.readtable_attempted=true; disp('R3_READTABLE_ATTEMPT');
    T=readtable(csvPath,'Delimiter',',','VariableNamingRule','preserve','TextType','string');
    state.readtable_completed=true; state.parsed_width=width(T); disp('R3_READTABLE_COMPLETED');
    names=T.Properties.VariableNames; state.formal_names_preserved=~any(startsWith(string(names),'Var'));
    required={'run_id','role','execution_order','original_status','runtime_authorization','steering_amplitude', ...
        'steering_frequency','duration','estimator_rate','waveform','speed_scope','truth_alignment_rule', ...
        'evaluation_window_rule','formal_result_path','data_viewed','weight_set_id','runtime_alpha_D', ...
        'runtime_alpha_K','runtime_alpha_F','target_path','target_sha256'};
    state.required_fields_pass=all(ismember(required,names));
    assert(state.parsed_width==32,'R3:Schema','Expected 32 columns, got %d.',state.parsed_width);
    assert(state.formal_names_preserved,'R3:VarNFallback','VarN schema detected.');
    assert(state.required_fields_pass,'R3:RequiredFields','Required named fields are missing.');
    h01=T(T.execution_order==1,:); state.selected_row_count=height(h01);
    assert(state.selected_row_count==1,'R3:H01Row','Expected exactly one H01 row.');
    state.selected_run_id=char(h01.run_id); state.selected_role=char(h01.role);
    state.selected_amplitude=double(h01.steering_amplitude); state.selected_frequency=double(h01.steering_frequency);
    state.selected_duration=double(h01.duration); state.selected_rate=double(h01.estimator_rate);
    assert(h01.run_id=="FWHOLD_H01"&&h01.role=="HOLDOUT_VALIDATION",'R3:H01Identity','H01 identity mismatch.');
    assert(double(h01.original_registry_row)==7&&state.selected_amplitude==0.025&& ...
        state.selected_frequency==0.35&&state.selected_duration==16&&state.selected_rate==100, ...
        'R3:H01Condition','Frozen H01 condition mismatch.');
    assert(h01.waveform=="SINE_FRONT_EQUAL_REAR_ZERO",'R3:H01Waveform','Frozen H01 waveform mismatch.');
    state.status='PASS'; state.failure_stage=''; disp('R3_PARSER_PROBE_OK');
catch ME
    state.failure_stage=stage_for_error(state); state.exception_identifier=ME.identifier; state.exception_message=ME.message;
    state.status='FAIL';
end
write_report(reportPath,state);
if strcmp(state.status,'PASS'), exit(0); else, rethrow(MException(state.exception_identifier,state.exception_message)); end

function s=stage_for_error(st)
if ~st.probe_entered,s='probe_entry';elseif ~st.readtable_attempted,s='pre_readtable';elseif ~st.readtable_completed,s='readtable';elseif ~st.formal_names_preserved||~st.required_fields_pass||st.parsed_width~=32,s='schema_assertion';else,s='H01_row_or_condition_assertion';end
end
function write_report(file,s)
fid=fopen(file,'w'); assert(fid>=0,'R3:EvidenceWrite','Cannot create self-report CSV.'); c=onCleanup(@()fclose(fid));
fprintf(fid,'status,probe_entered,readtable_attempted,readtable_completed,parsed_width,formal_names_preserved,required_fields_pass,selected_row_count,selected_run_id,selected_role,selected_amplitude,selected_frequency,selected_duration,selected_rate,sim_called,formal_target_loaded,CarSim_started,holdout_runtime_data_read,failure_stage,exception_identifier,exception_message\n');
fprintf(fid,'%s,%s,%s,%s,%.17g,%s,%s,%.17g,%s,%s,%.17g,%.17g,%.17g,%.17g,%s,%s,%s,%s,%s,%s,%s\n', ...
    s.status,tf(s.probe_entered),tf(s.readtable_attempted),tf(s.readtable_completed),s.parsed_width,tf(s.formal_names_preserved),tf(s.required_fields_pass),s.selected_row_count, ...
    csvq(s.selected_run_id),csvq(s.selected_role),s.selected_amplitude,s.selected_frequency,s.selected_duration,s.selected_rate,tf(s.sim_called),tf(s.formal_target_loaded),tf(s.CarSim_started),tf(s.holdout_runtime_data_read), ...
    csvq(s.failure_stage),csvq(s.exception_identifier),csvq(s.exception_message));
end
function v=tf(x),if x,v='TRUE';else,v='FALSE';end,end
function v=csvq(x),x=char(x);x=strrep(x,'"','""');v=['"' x '"'];end
