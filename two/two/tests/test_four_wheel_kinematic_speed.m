function tests = test_four_wheel_kinematic_speed
%TEST_FOUR_WHEEL_KINEMATIC_SPEED Unit tests for 4WIS geometry inversion.

tests = functiontests(localfunctions);

end


function testStraightLine(testCase)

tol = 1e-8;
p = estimator_default_params();

deltaWheel = zeros(4,1);
yawRate = 0;
vyPrior = 0;
v_target = 10;

omegaWheel = repmat(v_target / p.Rw,4,1);

[vxWheel, validGeom] = four_wheel_kinematic_speed( ...
    omegaWheel, deltaWheel, yawRate, vyPrior, p);

verifyLessThan(testCase, abs(vxWheel-v_target), ...
    tol*ones(4,1));

verifyTrue(testCase, all(validGeom));

end


function testDifferentWheelSpeeds(testCase)

tol = 1e-8;
p = estimator_default_params();

v_target = [10;11;12;13];
omegaWheel = v_target / p.Rw;

deltaWheel = zeros(4,1);
yawRate = 0;
vyPrior = 0;

[vxWheel, validGeom] = four_wheel_kinematic_speed( ...
    omegaWheel, deltaWheel, yawRate, vyPrior, p);

verifyLessThan(testCase, abs(vxWheel-v_target), ...
    tol*ones(4,1));

verifyEqual(testCase, validGeom, ...
    [true;true;true;true]);

end


function testYawRateGeometry(testCase)

tol = 1e-8;
p = estimator_default_params();

xWheel = [p.a; p.a; -p.b; -p.b];
yWheel = [p.d/2; -p.d/2; p.d/2; -p.d/2];

yawRate = 0.20;
v_target = 12;

omegaWheel = repmat(v_target/p.Rw,4,1);
deltaWheel = repmat(0.12,4,1);
vyPrior = 0;

vxExpected = zeros(4,1);

for i = 1:4
    vxExpected(i) = yawRate*yWheel(i) + ...
        (v_target - ...
        (vyPrior + yawRate*xWheel(i))*sin(deltaWheel(i))) ...
        / cos(deltaWheel(i));
end

[vxWheel, validGeom] = four_wheel_kinematic_speed( ...
    omegaWheel, deltaWheel, yawRate, vyPrior, p);

verifyLessThan(testCase, abs(vxWheel-vxExpected), ...
    tol*ones(4,1));

verifyTrue(testCase, all(validGeom));

verifyGreaterThan(testCase, ...
    abs(vxWheel(1)-vxWheel(3)), 1e-3);

end


function testIndependentSteering(testCase)

tol = 1e-8;
p = estimator_default_params();

xWheel = [p.a; p.a; -p.b; -p.b];
yWheel = [p.d/2; -p.d/2; p.d/2; -p.d/2];

omegaWheel = repmat(9/p.Rw,4,1);

yawRate = 0.10;
vyPrior = 0.2;

deltaWheel = [0.05;-0.07;0.13;-0.11];

vxExpected = zeros(4,1);

for i = 1:4

    v_t_i = p.Rw*omegaWheel(i);

    vxExpected(i) = yawRate*yWheel(i) + ...
        (v_t_i - ...
        (vyPrior+yawRate*xWheel(i))*sin(deltaWheel(i))) ...
        /cos(deltaWheel(i));

end

[vxWheel, validGeom] = four_wheel_kinematic_speed( ...
    omegaWheel, deltaWheel, yawRate, vyPrior, p);

verifyLessThan(testCase, abs(vxWheel-vxExpected), ...
    tol*ones(4,1));

verifyTrue(testCase, all(validGeom));

end


function testCosDeltaGuard(testCase)

p = estimator_default_params();

omegaWheel = repmat(10/p.Rw,4,1);

yawRate = 0;
vyPrior = 0;

deltaWheel = ...
    [0;0;0;acos(p.cos_delta_min)+1e-6];

[vxWheel, validGeom] = four_wheel_kinematic_speed( ...
    omegaWheel, deltaWheel, yawRate, vyPrior, p);

verifyFalse(testCase, validGeom(4));
verifyTrue(testCase, isnan(vxWheel(4)));

verifyTrue(testCase, all(validGeom(1:3)));
verifyTrue(testCase, all(isfinite(vxWheel(1:3))));

end


function testNaNWheelSpeed(testCase)

p = estimator_default_params();

omegaWheel = ...
    [10/p.Rw;NaN;10/p.Rw;10/p.Rw];

deltaWheel = zeros(4,1);
yawRate = 0;
vyPrior = 0;

[vxWheel, validGeom] = four_wheel_kinematic_speed( ...
    omegaWheel, deltaWheel, yawRate, vyPrior, p);

verifyFalse(testCase,validGeom(2));
verifyTrue(testCase,isnan(vxWheel(2)));

idxGood = [1 3 4];

verifyTrue(testCase,all(validGeom(idxGood)));
verifyTrue(testCase,all(isfinite(vxWheel(idxGood))));

end


function testInfSteering(testCase)

p = estimator_default_params();

omegaWheel = repmat(10/p.Rw,4,1);

deltaWheel = [0;0;Inf;0];

yawRate = 0;
vyPrior = 0;

[vxWheel, validGeom] = four_wheel_kinematic_speed( ...
    omegaWheel, deltaWheel, yawRate, vyPrior, p);

verifyFalse(testCase,validGeom(3));
verifyTrue(testCase,isnan(vxWheel(3)));

idxGood = [1 2 4];

verifyTrue(testCase,all(validGeom(idxGood)));
verifyTrue(testCase,all(isfinite(vxWheel(idxGood))));

end


function testZeroSpeed(testCase)

p = estimator_default_params();

omegaWheel = zeros(4,1);
deltaWheel = zeros(4,1);

yawRate = 0;
vyPrior = 0;

[vxWheel, validGeom] = four_wheel_kinematic_speed( ...
    omegaWheel, deltaWheel, yawRate, vyPrior, p);

verifyEqual(testCase,vxWheel,zeros(4,1));
verifyTrue(testCase,all(validGeom));

end