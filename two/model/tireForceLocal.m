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

% if isFront == 1
%     % 低附着 μ=0.3/0.35 前轴
%     c1_lat = 0.4;
%     c2_lat = 40;
%     c3_lat = 60;
% 
%     c1_long = 0.37;
%     c2_long = 20;
%     c3_long = 0.6;
% else
%     % 低附着 μ=0.3/0.35 后轴
%     c1_lat = 0.47;
%     c2_lat = 40.026;
%     c3_lat = 0.1;
% 
%     c1_long = 0.5;
%     c2_long = 28;
%     c3_long = 1;
% end
s = sqrt(lambda.^2 + tan(alpha).^2);
s = max(s,1e-6);


Ft_lat = fz*c1_lat*(1-exp(-c2_lat*s)) ...
         - c3_lat*s;


Fy = 0.9 * alpha ./ s .* Ft_lat;


Ft_long = fz*c1_long*(1-exp(-c2_long*s)) ...
          - c3_long*s;


Fx = lambda ./ s .* Ft_long;

end
