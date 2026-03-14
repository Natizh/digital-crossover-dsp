function make_all_figures(cfg, clipIdx)
%MAKE_ALL_FIGURES Generate all publication-ready plots into cfg.paths.figures.
%
% Outputs (PNG, 300 dpi) in cfg.paths.figures:
%   Fig01_FIR_mag.png
%   Fig02_IIR_mag.png
%   Fig03_IIR_sum_mag_err.png
%   Fig04_branch_gd.png
%   Fig05_sum_gd.png
%   Fig06_time_noEQ.png
%   Fig07_err_noEQ.png   (2 panels: error vs x, and IIR error vs its all-pass reference)
%   Fig10/11_*_spectra_noEQ_<clip>.png
%   Fig12/13_*_spectra_EQ_<clip>.png (only if cfg.eq.enable = true)
%   Fig14_IIR_bands_time_EQ_<clip>.png (only if cfg.eq.enable = true)
%   Fig15_FIR_bands_time_EQ_<clip>.png (only if cfg.eq.enable = true)

if nargin < 1 || isempty(cfg)
    cfg = cfg_default();
end
if nargin < 2 || isempty(clipIdx)
    clipIdx = 1;
end

%% User knobs
stopbandMask_dB   = -40;   % group-delay is only shown where |H| > this threshold (dB)
timeSnippet_s     = 0.05;  % snippet length for sum/error plots
bandSnippet_s     = 0.02;  % snippet length for low/high band time plots

spec = struct();
spec.winLen  = 4096;
spec.overlap = 2048;
spec.nfft    = 16384;
spec.fMin    = 20;
spec.fMax    = 20000;

%% Setup: resolve paths relative to this script
codeDir = fileparts(mfilename('fullpath'));

audioInDir = resolve_dir(codeDir, cfg.paths.audio_in);
figDir     = resolve_dir(codeDir, cfg.paths.figures);

if ~isfolder(figDir), mkdir(figDir); end

%% Design filters
fir = design_fir_crossover(cfg);
iir = design_iir_crossover_lr4(cfg);

%% =========================
%  Frequency-domain figures
% ==========================
nfft = 16384;
w = linspace(0, pi, nfft).';
f = (w/(2*pi))*cfg.Fs;

% FIR
Hf_LP = freqz(fir.bLP, 1, w);
Hf_HP = freqz(fir.bHP, 1, w);
Hf_S  = Hf_LP + Hf_HP;

% IIR
Hi_LP = freqz(iir.sosLP, w) * iir.gLP;
Hi_HP = freqz(iir.sosHP, w) * iir.gHP;
Hi_S  = Hi_LP + Hi_HP;

% ---- Fig01: FIR magnitude ----
fig = figure('Visible','off');
plot(f, mag_db(Hf_LP)); hold on;
plot(f, mag_db(Hf_HP));
plot(f, mag_db(Hf_S));
grid on; xlim([spec.fMin spec.fMax]); set(gca,'XScale','log');
xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)');
legend('LP','HP','LP+HP','Location','best');
title('FIR crossover magnitude');
exportgraphics(fig, fullfile(figDir,"Fig01_FIR_mag.png"), 'Resolution', 300);
close(fig);

% ---- Fig02: IIR magnitude ----
fig = figure('Visible','off');
plot(f, mag_db(Hi_LP)); hold on;
plot(f, mag_db(Hi_HP));
plot(f, mag_db(Hi_S));
grid on; xlim([spec.fMin spec.fMax]); set(gca,'XScale','log');
xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)');
legend('LP','HP','LP+HP','Location','best');
title('IIR LR4 crossover magnitude');
exportgraphics(fig, fullfile(figDir,"Fig02_IIR_mag.png"), 'Resolution', 300);
close(fig);

% ---- Fig03: IIR | |Hsum| - 1 | ----
fig = figure('Visible','off');
plot(f, abs(abs(Hi_S)-1));
grid on; xlim([spec.fMin spec.fMax]); set(gca,'XScale','log');
xlabel('Frequency (Hz)'); ylabel('| |H_{sum}| - 1 |');
title('IIR LR4 magnitude complementarity error');
exportgraphics(fig, fullfile(figDir,"Fig03_IIR_sum_mag_err.png"), 'Resolution', 300);
close(fig);

% Group delays (stopband-masked)
gd_fir_LP = grpdelay(fir.bLP, 1, w);
gd_fir_HP = grpdelay(fir.bHP, 1, w);

gd_iir_LP = grpdelay(iir.bLP, iir.aLP, w);
gd_iir_HP = grpdelay(iir.bHP, iir.aHP, w);

gd_fir_LP = mask_gd(gd_fir_LP, Hf_LP, stopbandMask_dB);
gd_fir_HP = mask_gd(gd_fir_HP, Hf_HP, stopbandMask_dB);
gd_iir_LP = mask_gd(gd_iir_LP, Hi_LP, stopbandMask_dB);
gd_iir_HP = mask_gd(gd_iir_HP, Hi_HP, stopbandMask_dB);

% ---- Fig04: Branch group delays ----
fig = figure('Visible','off');
plot(f, gd_fir_LP); hold on;
plot(f, gd_fir_HP);
plot(f, gd_iir_LP);
plot(f, gd_iir_HP);
grid on; xlim([spec.fMin spec.fMax]); set(gca,'XScale','log');
xlabel('Frequency (Hz)'); ylabel('Group delay (samples)');
legend('FIR LP','FIR HP','IIR LP','IIR HP','Location','best');
title(sprintf('Branch group delays (masked below %d dB)', stopbandMask_dB));
exportgraphics(fig, fullfile(figDir,"Fig04_branch_gd.png"), 'Resolution', 300);
close(fig);

% Sum-path group delay
bSum_fir = fir.bLP + fir.bHP;
gd_fir_S = grpdelay(bSum_fir, 1, w);

[Bsum_iir, Asum_iir] = iir_sum_tf(iir);  % Hsum(z)=Hlp+Hhp
gd_iir_S = grpdelay(Bsum_iir, Asum_iir, w);

% ---- Fig05: Sum-path group delays ----
fig = figure('Visible','off');
plot(f, gd_fir_S); hold on;
plot(f, gd_iir_S);
grid on; xlim([spec.fMin spec.fMax]); set(gca,'XScale','log');
xlabel('Frequency (Hz)'); ylabel('Group delay (samples)');
legend('FIR sum','IIR sum','Location','best');
title('Overall sum-path group delay (H_{LP}+H_{HP})');
exportgraphics(fig, fullfile(figDir,"Fig05_sum_gd.png"), 'Resolution', 300);
close(fig);

%% =========================
%  Time-domain demo figures
% ==========================
% EQ structs
eqOff = struct('enable', false, 'lowBandGain_dB', 0, 'highBandGain_dB', 0);
eqOn  = get_eq_cfg(cfg);

% Load clip
if clipIdx < 1 || clipIdx > numel(cfg.audioFiles)
    error('clipIdx=%d out of range (cfg.audioFiles has %d entries).', clipIdx, numel(cfg.audioFiles));
end

inFile = fullfile(audioInDir, cfg.audioFiles(clipIdx));
[x, Fs_in] = audioread(inFile);
if Fs_in ~= cfg.Fs
    x = resample(x, cfg.Fs, Fs_in);
end
base = erase(cfg.audioFiles(clipIdx), ".wav");
if isstring(base), base = char(base); end

% Process no EQ
[~, ~, ySum_fir] = apply_crossover(x, "FIR", fir, iir, eqOff);
[~, ~, ySum_iir] = apply_crossover(x, "IIR", fir, iir, eqOff);

maxLag = max(4096, 2*fir.delay + 64);

mFir_x = recon_metrics(x, ySum_fir, maxLag); % FIR should match x up to integer delay
mIir_x = recon_metrics(x, ySum_iir, maxLag); % IIR sum is typically an all-pass vs x

% IIR "true" reference: x passed through Hsum(z)=Hlp(z)+Hhp(z) (all-pass magnitude ~1)
x_ap   = filter(Bsum_iir, Asum_iir, x);
mIir_ap = recon_metrics(x_ap, ySum_iir, maxLag);

L = min([size(mFir_x.x_aligned,1), size(mIir_x.y_aligned,1), round(timeSnippet_s*cfg.Fs)]);
t = (0:L-1).'/cfg.Fs;

% ---- Fig06: time overlay (no EQ) ----
fig = figure('Visible','off');
plot(t, mFir_x.x_aligned(1:L,1)); hold on;
plot(t, mFir_x.y_aligned(1:L,1));
plot(t, mIir_x.y_aligned(1:L,1));
grid on; xlabel('Time (s)'); ylabel('Amplitude');
legend('x (aligned)','FIR sum (aligned)','IIR sum (aligned)','Location','best');
title(sprintf('Time-domain sum outputs (no EQ) — %s', base));
exportgraphics(fig, fullfile(figDir,"Fig06_time_noEQ.png"), 'Resolution', 300);
close(fig);

% ---- Fig07: reconstruction error (no EQ), explained ----
fig = figure('Visible','off');
tiledlayout(2,1,'TileSpacing','compact','Padding','compact');

nexttile;
plot(t, mFir_x.e(1:L,1)); hold on;
plot(t, mIir_x.e(1:L,1));
grid on; ylabel('Error');
legend('FIR: (y_{sum}-x)','IIR: (y_{sum}-x)','Location','best');
title(sprintf('Reconstruction error vs x (no EQ) — %s', base));

nexttile;
plot(t, mFir_x.e(1:L,1)); hold on;
plot(t, mIir_ap.e(1:L,1));
grid on; xlabel('Time (s)'); ylabel('Error');
legend('FIR: (y_{sum}-x)','IIR: (y_{sum}-x_{ap})','Location','best');
title('IIR error vs equivalent sum-path reference x_{ap}=H_{sum}*x');

exportgraphics(fig, fullfile(figDir,"Fig07_err_noEQ.png"), 'Resolution', 300);
close(fig);

%% =========================
%  Spectra triplets (sum / low / high)
% ==========================
xM = to_mono(x);

% No EQ spectra
[yL_fir, yH_fir, ySum_fir] = apply_crossover(x, "FIR", fir, iir, eqOff);
[yL_iir, yH_iir, ySum_iir] = apply_crossover(x, "IIR", fir, iir, eqOff);

plot_triplet_spectra(xM, to_mono(ySum_fir), to_mono(yL_fir), to_mono(yH_fir), cfg.Fs, cfg.fc, ...
    sprintf('FIR — Spectra (no EQ) — %s', base), fullfile(figDir, sprintf('Fig10_FIR_spectra_noEQ_%s.png', base)), spec);

plot_triplet_spectra(xM, to_mono(ySum_iir), to_mono(yL_iir), to_mono(yH_iir), cfg.Fs, cfg.fc, ...
    sprintf('IIR LR4 — Spectra (no EQ) — %s', base), fullfile(figDir, sprintf('Fig11_IIR_spectra_noEQ_%s.png', base)), spec);

% EQ spectra + band time (optional)
if eqOn.enable
    [yL_fir_eq, yH_fir_eq, ~] = apply_crossover(x, "FIR", fir, iir, eqOn);
    [yL_iir_eq, yH_iir_eq, ~] = apply_crossover(x, "IIR", fir, iir, eqOn);

    [~, ~, ySum_fir_eq] = apply_crossover(x, "FIR", fir, iir, eqOn);
    [~, ~, ySum_iir_eq] = apply_crossover(x, "IIR", fir, iir, eqOn);

    ttl = sprintf('EQ on: L=%+0.1f dB, H=%+0.1f dB', eqOn.lowBandGain_dB, eqOn.highBandGain_dB);

    plot_triplet_spectra(xM, to_mono(ySum_fir_eq), to_mono(yL_fir_eq), to_mono(yH_fir_eq), cfg.Fs, cfg.fc, ...
        sprintf('FIR — Spectra (EQ) — %s — %s', base, ttl), fullfile(figDir, sprintf('Fig12_FIR_spectra_EQ_%s.png', base)), spec);

    plot_triplet_spectra(xM, to_mono(ySum_iir_eq), to_mono(yL_iir_eq), to_mono(yH_iir_eq), cfg.Fs, cfg.fc, ...
        sprintf('IIR LR4 — Spectra (EQ) — %s — %s', base, ttl), fullfile(figDir, sprintf('Fig13_IIR_spectra_EQ_%s.png', base)), spec);

    % Time snippet: show band signals (normalized for readability)
    plot_band_time_norm(to_mono(yL_iir_eq), to_mono(yH_iir_eq), cfg.Fs, bandSnippet_s, ...
        sprintf('IIR LR4 — Band signals (EQ, normalized) — %s', base), fullfile(figDir, sprintf('Fig14_IIR_bands_time_EQ_%s.png', base)));

    plot_band_time_norm(to_mono(yL_fir_eq), to_mono(yH_fir_eq), cfg.Fs, bandSnippet_s, ...
        sprintf('FIR — Band signals (EQ, normalized) — %s', base), fullfile(figDir, sprintf('Fig15_FIR_bands_time_EQ_%s.png', base)));
end

fprintf('\nAll figures saved to: %s\n', figDir);

end

%% =========================
% Local helpers
% =========================

function pAbs = resolve_dir(codeDir, p)
% Resolve a (possibly relative) directory path against the code folder.
    if isstring(p), p = char(p); end
    if isempty(p), pAbs = codeDir; return; end
    isAbs = startsWith(p, filesep) || (~isempty(regexp(p,'^[A-Za-z]:', 'once'))); % unix or Windows drive
    if isAbs
        pAbs = p;
    else
        pAbs = fullfile(codeDir, p);
    end
end

function db = mag_db(H)
    db = 20*log10(abs(H) + eps);
end

function gdM = mask_gd(gd, H, thr_dB)
% Mask group delay where the corresponding magnitude is far into stopband.
    m = mag_db(H);
    gdM = gd;
    gdM(m < thr_dB) = NaN;
end

function xM = to_mono(x)
% Convert stereo->mono for plotting, return column vector
    if size(x,2) > 1
        xM = mean(x, 2);
    else
        xM = x;
    end
    xM = xM(:);
end

function eqOn = get_eq_cfg(cfg)
% Get a robust EQ struct
    if isfield(cfg,'eq') && isstruct(cfg.eq)
        eqOn = cfg.eq;
    else
        eqOn = struct();
    end
    if ~isfield(eqOn,'enable'),          eqOn.enable = false; end
    if ~isfield(eqOn,'lowBandGain_dB'),  eqOn.lowBandGain_dB  = 0; end
    if ~isfield(eqOn,'highBandGain_dB'), eqOn.highBandGain_dB = 0; end
end

function [Sdb, f] = welch_db(x, Fs, winLen, overlap, nfft)
% Smooth PSD in dB/Hz (Welch). Great for paper-friendly spectra.
    x = x(:);
    w = hann(winLen, 'periodic');
    [Pxx, f] = pwelch(x, w, overlap, nfft, Fs);
    Sdb = 10*log10(Pxx + eps);
end

function plot_triplet_spectra(x, ySum, yL, yH, Fs, fc, figTitle, outPng, spec)
% 3 stacked plots: Sum, Low, High. Each overlays input spectrum for reference.

    [Xdb, f] = welch_db(x, Fs, spec.winLen, spec.overlap, spec.nfft);
    [Sdb, ~] = welch_db(ySum, Fs, spec.winLen, spec.overlap, spec.nfft);
    [Ldb, ~] = welch_db(yL,   Fs, spec.winLen, spec.overlap, spec.nfft);
    [Hdb, ~] = welch_db(yH,   Fs, spec.winLen, spec.overlap, spec.nfft);

    idx = (f >= spec.fMin) & (f <= spec.fMax);
    f   = f(idx);
    Xdb = Xdb(idx); Sdb = Sdb(idx); Ldb = Ldb(idx); Hdb = Hdb(idx);

    yMin = min([Xdb; Sdb; Ldb; Hdb]);
    yMax = max([Xdb; Sdb; Ldb; Hdb]);
    pad  = 3;

    fig = figure('Visible','off');
    tiledlayout(3,1,'TileSpacing','compact','Padding','compact');

    nexttile;
    plot(f, Xdb); hold on; plot(f, Sdb);
    xline(fc, '--');
    grid on; set(gca,'XScale','log'); xlim([spec.fMin spec.fMax]);
    ylim([yMin-pad yMax+pad]);
    ylabel('PSD (dB/Hz)');
    title(figTitle);
    legend('Input x','Sum y_L+y_H','Location','best');

    nexttile;
    plot(f, Xdb); hold on; plot(f, Ldb);
    xline(fc, '--');
    grid on; set(gca,'XScale','log'); xlim([spec.fMin spec.fMax]);
    ylim([yMin-pad yMax+pad]);
    ylabel('PSD (dB/Hz)');
    legend('Input x','Low band y_L','Location','best');

    nexttile;
    plot(f, Xdb); hold on; plot(f, Hdb);
    xline(fc, '--');
    grid on; set(gca,'XScale','log'); xlim([spec.fMin spec.fMax]);
    ylim([yMin-pad yMax+pad]);
    xlabel('Frequency (Hz)'); ylabel('PSD (dB/Hz)');
    legend('Input x','High band y_H','Location','best');

    exportgraphics(fig, outPng, 'Resolution', 300);
    close(fig);
end

function plot_band_time_norm(yL, yH, Fs, snippet_s, figTitle, outPng)
% Short time snippet to show separated band signals.
% For readability, each band is normalized to its own peak 

    yL = yL(:); yH = yH(:);
    L = min([length(yL), length(yH), round(snippet_s*Fs)]);
    t = (0:L-1).' / Fs;

    yL_plot = yL(1:L) / (max(abs(yL(1:L))) + eps);
    yH_plot = yH(1:L) / (max(abs(yH(1:L))) + eps);

    fig = figure('Visible','off');
    tiledlayout(2,1,'TileSpacing','compact','Padding','compact');

    nexttile;
    plot(t, yL_plot); grid on;
    xlabel('Time (s)'); ylabel('Amplitude (norm.)');
    title(figTitle);
    legend('Low band (normalized)','Location','best');

    nexttile;
    plot(t, yH_plot); grid on;
    xlabel('Time (s)'); ylabel('Amplitude (norm.)');
    legend('High band (normalized)','Location','best');

    exportgraphics(fig, outPng, 'Resolution', 300);
    close(fig);
end
