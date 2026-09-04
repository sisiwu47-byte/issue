# STAGE VY DK-EKF V2.2-D1 STATUS

## 结论

**V2.2-D1 GENUINE NOMINAL STEERING GATE PASSED**

唯一一次授权的 2 s Simulink/CarSim runtime 已完成。真实 0.02 rad、
0.4 Hz 前轮 steering 已进入 CarSim，产生明确 yaw 响应；DK-EKF 100 Hz、
reset、Ay 20 Hz、数值、协方差、exact replay、公平性和 hash 门禁全部通过。

## 执行纪律

- `sim()` 实际调用次数：1
- StopTime：2 s
- 16 s runtime：未运行
- runtime runner 未调用 builder，也未调用 `save_system`
- CarSim solver：`D:\carsim\CarSim2021.0_Prog\Programs\solvers\carsim_64.dll`
- 历史 `G:\carsim` request：NO
- simulation completed：YES
- CarSim ran：YES

既有 Derivative block 警告未导致仿真失败，也未触发模型修改。

## Steering runtime evidence

```text
steer_cmd_rad min/max/maxAbs = -0.02 / 0.02 / 0.02 rad
converted min/max/maxAbs     = -1.1459155902616465 /
                               1.1459155902616465 /
                               1.1459155902616465 deg
deg/rad median               = 57.295779513082323
ratio max error              = 7.105427357601002e-15
frequency                    = 0.3999937516696907 Hz

FL maxAbs                    = 1.1459155902616465 deg
FR maxAbs                    = 1.1459155902616465 deg
RL maxAbs                    = 0 deg
RR maxAbs                    = 0 deg
FL/FR maxAbsDiff             = 0
front vs converted maxAbsDiff= 0
frontCommandApplied          = 1
```

实际单位链只有一次转换：

```text
D1 Steer Cmd Rad
-> Gain22 = 180/pi
-> Mux8 ports 2/4
-> Manual Switch1 input 2, CurrentSetting=0
-> Mux7
-> CarSim IMP_STEER_L1/R1
```

Mux8 ports 6/8 保持 `Constant10=0`。

## AVz physical response

```text
new 2 s AVz maxAbs           = 0.13405077464578671 rad/s
new 2 s AVz RMS              = 0.086513947811608871 rad/s

common 0--0.20 s new maxAbs  = 0.034148644584404843 rad/s
common 0--0.20 s C2 maxAbs   = 0.0093692098551406301 rad/s
maxAbsDiff                   = 0.028367678388251421 rad/s
RMSDiff                      = 0.012530935173067687 rad/s
exactEqual                   = NO
```

变化明显高于 `1e-8`/浮点噪声量级，真实物理 yaw response 已确认。

## 100 Hz / reset / Ay

```text
x/P/diag samples             = 201 / 201 / 201
raw u-log samples            = 2003
t start/end                  = 0 / 2 s
dt min/mean/max              = 0.0099999999999997868 / 0.01 /
                               0.010000000000000009 s
duplicate timestamp count    = 0
missing-hit count            = 0
input hits resolved          = 201/201
timestamp shift              = NO

reset high count             = 1
reset timestamp              = 0
initial x prior              = [20; 0; 0]
initial P0                   = diag([0.1 0.1 0.1])
TRUE Vy initialization       = NO

doAyUpdate high count        = 41
AyUpdateApplied count        = 41
sequence exact               = YES
timestamps                   = 0:0.05:2 s
```

## Numeric / covariance / replay

```text
x dimension                  = 3
P dimension                  = 3x3
diag dimension               = 7
x/P/diag all finite          = YES / YES / YES
max covariance asymmetry     = 0
minimum covariance eigenvalue= 6.1802046313273477e-05
P11 min/max                  = [6.1803059517488585e-05,
                                9.9900199600724325e-05]
P22 min/max                  = [1.0668231451703208e-04,
                                4.8703098934750394e-04]
P33 min/max                  = [1.2151314812419751e-04,
                                3.3496808177292447e-04]

maxAbsXDiff                  = 0
maxAbsPDiff                  = 0
maxAbsDiagDiff               = 0
shift applied                = NO
ONE 100-HZ FUNCTION-CALL HIT
= ONE COMMITTED DK-EKF STATE ADVANCE: PASS
```

## 公平性

```text
TRUE Vy online               = NO
true Vx                      = measurement only
Ax_IMU                       = prediction input only
AVz_IMU                      = measurement only
Ay_IMU                       = measurement only
shared x/P                   = YES
output fusion                = NO
LifeSig                      = NO
adaptive fusion              = NO
```

## Hash integrity

```text
accepted target before/after:
E768FB2AD33A6EEAABDE2FB7C40BE660B78F350A90C752327DC9B423F50F2E15

validation model before/after:
A17E7609D2248C832A80F773660941B68025E3A38CFC1F3938CBCA2BD0165E5B

core:
6475B9DBC93EB6E25C2BB9FAD81CA11B2E08C26E7F2AE6A33C50E35B2790B457

wrapper:
7E731D7DF0BB2CA4455E3AA16E7513114E04472D38C62F1F453B631056306973

adapter:
12F0D82643D65AA5098ED20C0655234F3A2E7EF6D6F5E7DEE5B80BC1A201BDA1
```

D-EKF 和 K-KF frozen hashes 同样保持不变。

结果文件：`results/vy_dkekf_v2_2d1_steer_smoke.mat`

## 下一状态

READY FOR V2.2-D2 16-S DK-EKF NOMINAL VALIDATION

本阶段未执行 Q/R tuning、online bias correction、fusion、LifeSig 或
V2.2-D2 runtime。
