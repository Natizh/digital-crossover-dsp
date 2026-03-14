function iir = design_iir_crossover_lr4(cfg)
%DESIGN_IIR_CROSSOVER_LR4
% 2-way IIR crossover: LR4 implemented as cascade of two Butterworth 2nd-order sections.
% Output is SOS + gain for numerical stability.

Fs = cfg.Fs;
fc = cfg.fc;
order = cfg.iir.order;
Wn = fc/(Fs/2);              % normalized cutoff (0..1)

if order ~= 4
    error("design_iir_crossover_lr4 supports only cfg.iir.order = 4.");
end
if Wn <= 0 || Wn >= 1
    error("cfg.fc must satisfy 0 < fc < Fs/2.");
end

% 2nd-order Butterworth prototypes
[bLP2, aLP2] = butter(2, Wn, 'low');
[bHP2, aHP2] = butter(2, Wn, 'high');

% Cascade twice => 4th order (LR4-like)
bLP = conv(bLP2, bLP2);
aLP = conv(aLP2, aLP2);

bHP = conv(bHP2, bHP2);
aHP = conv(aHP2, aHP2);

% Convert to SOS form (stable biquads)
[sosLP, gLP] = tf2sos(bLP, aLP);
[sosHP, gHP] = tf2sos(bHP, aHP);

iir = struct();
iir.sosLP = sosLP; iir.gLP = gLP;
iir.sosHP = sosHP; iir.gHP = gHP;

iir.bLP = bLP; iir.aLP = aLP;
iir.bHP = bHP; iir.aHP = aHP;

end
