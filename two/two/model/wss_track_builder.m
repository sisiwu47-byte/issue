function [vxWssTrack, RwssEquivalent, alphaWheel, wssValid] = wss_track_builder(vxWheel, Rwheel, validWheel)
%WSS_TRACK_BUILDER Fuse valid WSS wheel measurements using inverse-variance weights.
%   [vxWssTrack, RwssEquivalent, alphaWheel, wssValid] =
%   wss_track_builder(vxWheel, Rwheel, validWheel)
%   implements Stage 2 C-map WSS internal fusion:
%     - q_i = 1 / R_i
%     - alpha_i = q_i / sum(q_valid)
%     - vxWssTrack = sum(alpha_i * vxWheel_i)
%     - RwssEquivalent = 1 / sum(q_valid)
%   Only wheels with validWheel=true are considered.

if nargin ~= 3
    error('wss_track_builder:InvalidInputCount', ...
          'Expected 3 input arguments: vxWheel, Rwheel, validWheel.');
end

vxWheel = vxWheel(:);
Rwheel = Rwheel(:);
validWheel = logical(validWheel(:));

if numel(vxWheel) ~= 4 || numel(Rwheel) ~= 4 || numel(validWheel) ~= 4
    error('wss_track_builder:InvalidWheelSize', ...
          'vxWheel, Rwheel, validWheel must be 4x1 vectors in order [FL, FR, RL, RR].');
end

alphaWheel = zeros(4, 1);
vxWssTrack = NaN;
RwssEquivalent = NaN;
wssValid = false;

% A wheel is valid for fusion only if it passes validWheel and data is finite-positive.
fusionMask = validWheel & isfinite(vxWheel) & isfinite(Rwheel) & (Rwheel > 0);

if ~any(fusionMask)
    wssValid = false;
    finiteRwheel = Rwheel(isfinite(Rwheel));
    if isempty(finiteRwheel)
        RwssEquivalent = 1;
    else
        RwssEquivalent = max(finiteRwheel);
    end
    return;
end

q = zeros(4, 1);
q(fusionMask) = 1 ./ Rwheel(fusionMask);

sumQ = sum(q(fusionMask));
if ~isfinite(sumQ) || sumQ <= 0
    wssValid = false;
    finiteRwheel = Rwheel(fusionMask & isfinite(Rwheel));
    if isempty(finiteRwheel)
        RwssEquivalent = 1;
    else
        RwssEquivalent = max(finiteRwheel);
    end
    return;
end

alphaWheel(fusionMask) = q(fusionMask) / sumQ;
vxWssTrack = sum(alphaWheel(fusionMask) .* vxWheel(fusionMask), 1);
RwssEquivalent = 1 / sumQ;
wssValid = true;
