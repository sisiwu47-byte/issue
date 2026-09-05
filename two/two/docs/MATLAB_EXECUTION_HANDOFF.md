# MATLAB 执行交接（用于MATLAB/Simulink/CarSim电脑）

## 项目路径准备
1. 在 MATLAB 中定位到本仓库根目录：`D:\UsersData\桌面\two`。
2. 建议先验证当前目录：

```matlab
pwd
ls
```

3. 建立执行环境（首次执行可建目录）：

```matlab
projectRoot = pwd;
if ~exist(fullfile(projectRoot,'results'),'dir')
    mkdir(fullfile(projectRoot,'results'));
end
```

## addpath 命令

```matlab
projectRoot = pwd;
addpath(fullfile(projectRoot, 'matlab'));
addpath(fullfile(projectRoot, 'tests'));
```

## MATLAB测试执行顺序

全部测试默认使用 `runtests`。`results` 保存到 `results/`。

```matlab
projectRoot = pwd;
addpath(fullfile(projectRoot, 'matlab'));
addpath(fullfile(projectRoot, 'tests'));
if ~exist(fullfile(projectRoot,'results'),'dir')
    mkdir(fullfile(projectRoot,'results'));
end

% 第一组
results_g1a = runtests(fullfile(projectRoot,'tests','test_estimator_default_params.m'));
results_g1b = runtests(fullfile(projectRoot,'tests','test_four_wheel_kinematic_speed.m'));

% 第二组：Stage 3B窗口/FIFO测试
gr2a = runtests(fullfile(projectRoot,'tests','test_stage2_wss_candidate_and_window.m'));
gr2b = runtests(fullfile(projectRoot,'tests','test_stage2_imu_track_and_fifo.m'));

% 第三组
gr3 = runtests(fullfile(projectRoot,'tests','test_slip_confidence_mapping.m'));
g3b = runtests(fullfile(projectRoot,'tests','test_wss_track_builder.m'));

% 第四组
g4a = runtests(fullfile(projectRoot,'tests','test_stage3d1_local_scalar_kf.m'));
g4b = runtests(fullfile(projectRoot,'tests','test_correlated_two_track_fusion.m'));

% 第五组
g5 = runtests(fullfile(projectRoot,'tests','test_longitudinal_velocity_estimator.m'));

allTests = [results_g1a; results_g1b; gr2a; gr2b; gr3; g3b; g4a; g4b; g5];

disp(allTests);
```

## 推荐默认总执行命令

```matlab
results = runtests('tests');
disp(results);
```

## 哪些测试属于纯函数
- `test_estimator_default_params.m`
- `test_four_wheel_kinematic_speed.m`
- `test_stage2_wss_candidate_and_window.m`
- `test_stage2_imu_track_and_fifo.m`
- `test_slip_confidence_mapping.m`
- `test_wss_track_builder.m`
- `test_stage3d1_local_scalar_kf.m`
- `test_correlated_two_track_fusion.m`

## 哪些测试属于顶层集成
- `test_longitudinal_velocity_estimator.m`

## 如何保存测试结果

```matlab
% 全部用例一次性落盘
if ~exist(fullfile(projectRoot,'results'),'dir')
    mkdir(fullfile(projectRoot,'results'));
end
save(fullfile(projectRoot,'results','matlab_test_results.mat'), 'allTests');

% 生成汇总文本
fid = fopen(fullfile(projectRoot,'results','matlab_test_summary.txt'),'w');
fprintf(fid, 'MATLAB test count: %d\\n', numel(allTests));
passed = sum([allTests.Passed]);
fprintf(fid, 'Passed: %d\\n', passed);
failed = sum([allTests.Failed]);
fprintf(fid, 'Failed: %d\\n', failed);
blocked = sum([allTests.Incomplete]);
fprintf(fid, 'Incomplete: %d\\n\\n', blocked);
for i = 1:numel(allTests)
    fprintf(fid, '%s | Passed=%d Failed=%d Incomplete=%d Details=%s\\n', ...
        allTests(i).Name, allTests(i).Passed, allTests(i).Failed, allTests(i).Incomplete, allTests(i).DiagnosedByName);
end
fclose(fid);
```

## 测试失败时需要保存哪些错误信息
- 直接保存完整 `result` 结构（含失败堆栈）到 `matlab_test_results.mat`。
- 生成 `matlab_error.txt`，记录每个失败用例名、消息、栈文件/行号。

```matlab
failed = allTests(~[allTests.Passed]);
fid = fopen(fullfile(projectRoot,'results','matlab_error.txt'),'w');
for i = 1:numel(failed)
    fprintf(fid, '=== %s ===\\n', failed(i).Name);
    fprintf(fid, 'Details: %s\\n', failed(i).Message);
    diag = failed(i).Exception;
    if ~isempty(diag)
        fprintf(fid, 'Class: %s\\n', class(diag));
        fprintf(fid, 'Stack: %s\\n', diag.getReport);
    end
    fprintf(fid, '\\n');
end
if isempty(failed)
    fprintf(fid, 'No test failures.\\n');
end
fclose(fid);
```

## 全部MATLAB测试通过后才能进行Simulink接线
- 不得一开始就执行 Simulink。
- Simulink 手工接线与闭环验证必须等到本文件所有测试通过后再进行。

## 当前测试状态
- 现阶段所有测试标识均为：`PENDING MATLAB VALIDATION`。

## 故障定位的单文件测试命令

```matlab
runtests(fullfile(projectRoot,'tests','test_estimator_default_params.m'));
runtests(fullfile(projectRoot,'tests','test_four_wheel_kinematic_speed.m'));
runtests(fullfile(projectRoot,'tests','test_stage2_wss_candidate_and_window.m'));
runtests(fullfile(projectRoot,'tests','test_stage2_imu_track_and_fifo.m'));
runtests(fullfile(projectRoot,'tests','test_slip_confidence_mapping.m'));
runtests(fullfile(projectRoot,'tests','test_wss_track_builder.m'));
runtests(fullfile(projectRoot,'tests','test_stage3d1_local_scalar_kf.m'));
runtests(fullfile(projectRoot,'tests','test_correlated_two_track_fusion.m'));
runtests(fullfile(projectRoot,'tests','test_longitudinal_velocity_estimator.m'));
```

## 优先排查顺序（失败时）
1. MATLAB语法/版本问题
2. 输入输出尺寸
3. 函数接口
4. persistent/reset
5. FIFO索引
6. NaN/Inf处理
7. KF公式
8. PWI/相关融合
9. 顶层时序
10. 最后才考虑临时标定参数（如e_low/e_high）

## MATLAB_PASS_CRITERIA
- 所有基础单元测试通过。
- 所有 Stage 3B/C/D 测试通过。
- 顶层集成测试通过。
- 不允许失败测试被忽略。
- 不允许控制输出 `vx_hat` 出现非预期 NaN/Inf。

## NEXT_AFTER_PASS
- 仅当纯MATLAB测试全部通过后：
  1. 进入Simulink/CarSim手工接线与闭环验证（由用户手工完成接线）。
  2. 生成并提交人工接线说明与闭环验证记录。
