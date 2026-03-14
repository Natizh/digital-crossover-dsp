function [yL, yH, ySum] = apply_crossover(x, mode, fir, iir, eq)
%APPLY_CROSSOVER Apply FIR or IIR crossover to x (mono or stereo).
% mode: "FIR" or "IIR"


if nargin < 5 || isempty(eq)
    eq.enable = false;  % Allow calls that do not pass an EQ struct.
end

if ~isfield(eq,'enable'), eq.enable = false; end
if ~isfield(eq,'lowBandGain_dB'),  eq.lowBandGain_dB  = 0; end
if ~isfield(eq,'highBandGain_dB'), eq.highBandGain_dB = 0; end

switch mode
    case "FIR"
        yL = filter(fir.bLP, 1, x);
        yH = filter(fir.bHP, 1, x);

    case "IIR"
        yL = sosfilt(iir.sosLP, x) * iir.gLP;
        yH = sosfilt(iir.sosHP, x) * iir.gHP;

    otherwise
        error("mode must be 'FIR' or 'IIR'");
end

if eq.enable
    gL = 10^(eq.lowBandGain_dB/20);
    gH = 10^(eq.highBandGain_dB/20);
    yL = yL .* gL;
    yH = yH .* gH;
end

ySum = yL + yH;

end
