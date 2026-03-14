function metrics = test_fir_crossover(cfg)
%TEST_FIR_CROSSOVER Verify FIR crossover magnitude complementarity and delay.

if nargin < 1 || isempty(cfg)
    cfg = cfg_default();
end
if ~isfolder(cfg.paths.figures)
    mkdir(cfg.paths.figures);
end
fir = design_fir_crossover(cfg);

Fs = cfg.Fs;
N  = cfg.fir.N;

% Frequency response
nfft = 8192;
[Hlp, w] = freqz(fir.bLP, 1, nfft);
[Hhp, ~] = freqz(fir.bHP, 1, nfft);

Hsum = Hlp + Hhp;

f = (w/(2*pi))*Fs;

% ---- Plot 1: magnitude responses (dB) ----
fig1 = figure('Visible','off');
plot(f, 20*log10(abs(Hlp)+eps)); hold on;
plot(f, 20*log10(abs(Hhp)+eps));
plot(f, 20*log10(abs(Hsum)+eps));
grid on; xlim([0 Fs/2]);
xlabel("Frequency (Hz)"); ylabel("Magnitude (dB)");
legend("LP","HP","LP+HP (sum)", "Location","best");
title("FIR crossover magnitude responses");

exportgraphics(fig1, fullfile(cfg.paths.figures, "fir_mag.png"));
close(fig1);

% ---- Plot 2: sum error (linear) ----
D = fir.delay;
Htarget = exp(-1j*w*D);
sumErr = abs(Hsum - Htarget);
fig2 = figure('Visible','off');
plot(f, sumErr);
grid on; xlim([0 Fs/2]);
xlabel("Frequency (Hz)"); ylabel("|Hsum - e^{-jωD}|");
title("FIR crossover reconstruction error (frequency domain)");

exportgraphics(fig2, fullfile(cfg.paths.figures, "fir_sum_err.png"));
close(fig2);

% ---- Metric: max error in a practical band (e.g., 20 Hz .. 20 kHz) ----
idx = (f >= 20) & (f <= 20000);
maxErr = max(sumErr(idx));
fprintf("FIR: max |Hsum - e^{-jωD}| in 20 Hz..20 kHz = %.3e\n", maxErr);

% ---- Plot 3: group delay (samples) ----
[gdLP, wgd] = grpdelay(fir.bLP, 1, nfft);
[gdHP, ~]   = grpdelay(fir.bHP, 1, nfft);
fgd = (wgd/(2*pi))*Fs;

fig3 = figure('Visible','off');
plot(fgd, gdLP); hold on;
plot(fgd, gdHP);
yline(fir.delay, "--");
grid on; xlim([0 Fs/2]);
xlabel("Frequency (Hz)"); ylabel("Group delay (samples)");
legend("LP","HP","Expected delay", "Location","best");
title("FIR crossover group delay");

exportgraphics(fig3, fullfile(cfg.paths.figures, "fir_gd.png"));
close(fig3);

fprintf("FIR expected delay = %d samples (%.3f ms)\n", fir.delay, 1000*fir.delay/Fs);

metrics = struct();
metrics.max_sum_error = maxErr;
metrics.delay_samples = fir.delay;
metrics.delay_ms = 1000*fir.delay/Fs;
metrics.figure_dir = cfg.paths.figures;

end
