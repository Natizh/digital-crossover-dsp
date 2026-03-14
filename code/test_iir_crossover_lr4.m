function metrics = test_iir_crossover_lr4(cfg)
%TEST_IIR_CROSSOVER_LR4 Verify IIR LR4 crossover magnitude and delay matching.

if nargin < 1 || isempty(cfg)
    cfg = cfg_default();
end
if ~isfolder(cfg.paths.figures)
    mkdir(cfg.paths.figures);
end
iir = design_iir_crossover_lr4(cfg);

Fs = cfg.Fs;
nfft = 8192;

% Frequency grid
w = linspace(0, pi, nfft).';
f = (w/(2*pi))*Fs;

% Frequency responses from SOS
Hlp = freqz(iir.sosLP, nfft) * iir.gLP;
Hhp = freqz(iir.sosHP, nfft) * iir.gHP;
Hsum = Hlp + Hhp;

% ---- Plot 1: magnitude responses (dB) ----
fig1 = figure('Visible','off');
plot(f, 20*log10(abs(Hlp)+eps)); hold on;
plot(f, 20*log10(abs(Hhp)+eps));
plot(f, 20*log10(abs(Hsum)+eps));
grid on; xlim([0 Fs/2]);
xlabel("Frequency (Hz)"); ylabel("Magnitude (dB)");
legend("LP","HP","LP+HP (sum)", "Location","best");
title("IIR LR4 crossover magnitude responses");

exportgraphics(fig1, fullfile(cfg.paths.figures, "iir_mag.png"));
close(fig1);

% ---- Metric: sum magnitude deviation from unity ----
idx = (f >= 20) & (f <= 20000);
magErr = abs(abs(Hsum) - 1);
fprintf("IIR LR4: max ||Hsum|-1| in 20 Hz..20 kHz = %.3e\n", max(magErr(idx)));

% ---- Plot 2: group delay (samples) ----
[gdLP, wgd] = grpdelay(iir.bLP, iir.aLP, nfft);
[gdHP, ~]   = grpdelay(iir.bHP, iir.aHP, nfft);

fgd = (wgd/(2*pi))*Fs;

fig2 = figure('Visible','off');
plot(fgd, gdLP); hold on;
plot(fgd, gdHP);
grid on; xlim([0 Fs/2]);
xlabel("Frequency (Hz)"); ylabel("Group delay (samples)");
legend("LP","HP", "Location","best");
title("IIR LR4 crossover group delay");

exportgraphics(fig2, fullfile(cfg.paths.figures, "iir_gd.png"));
close(fig2);
maxGdDiff = max(abs(gdLP(idx)-gdHP(idx)));
fprintf("max |gdLP-gdHP| (20..20k) = %.3e samples\n", maxGdDiff);

metrics = struct();
metrics.max_mag_error = max(magErr(idx));
metrics.max_group_delay_diff = maxGdDiff;
metrics.figure_dir = cfg.paths.figures;

end
