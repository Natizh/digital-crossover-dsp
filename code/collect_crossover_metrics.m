function metrics = collect_crossover_metrics(cfg, clipIdx)
%COLLECT_CROSSOVER_METRICS Collect objective FIR vs IIR comparison metrics.

if nargin < 1 || isempty(cfg)
    cfg = cfg_default();
end
if nargin < 2 || isempty(clipIdx)
    clipIdx = 1;
end
if clipIdx < 1 || clipIdx > numel(cfg.audioFiles)
    error("clipIdx=%d out of range (cfg.audioFiles has %d entries).", clipIdx, numel(cfg.audioFiles));
end
if ~isfield(cfg, 'analysis') || ~isstruct(cfg.analysis)
    cfg.analysis = struct();
end
if ~isfield(cfg.analysis, 'metricBandHz'), cfg.analysis.metricBandHz = [20 20000]; end
if ~isfield(cfg.analysis, 'nfft'), cfg.analysis.nfft = 8192; end
if ~isfield(cfg.analysis, 'maxLag'), cfg.analysis.maxLag = 4096; end

metricBand = cfg.analysis.metricBandHz;
nfft = cfg.analysis.nfft;
maxLag = max(cfg.analysis.maxLag, 2*cfg.fir.N + 64);

inFile = fullfile(cfg.paths.audio_in, cfg.audioFiles(clipIdx));
[x, Fs_in] = audioread(inFile);
if Fs_in ~= cfg.Fs
    x = resample(x, cfg.Fs, Fs_in);
end

clipName = erase(cfg.audioFiles(clipIdx), ".wav");
if isstring(clipName)
    clipName = char(clipName);
end

fir = design_fir_crossover(cfg);
iir = design_iir_crossover_lr4(cfg);
[Bsum_iir, Asum_iir] = iir_sum_tf(iir);

w = linspace(0, pi, nfft).';
f = (w/(2*pi))*cfg.Fs;
idx = (f >= metricBand(1)) & (f <= metricBand(2));

HfirLP = freqz(fir.bLP, 1, w);
HfirHP = freqz(fir.bHP, 1, w);
HfirSum = HfirLP + HfirHP;
HfirTarget = exp(-1j*w*fir.delay);
firSumErr = abs(HfirSum - HfirTarget);

HiirLP = freqz(iir.bLP, iir.aLP, w);
HiirHP = freqz(iir.bHP, iir.aHP, w);
HiirSum = HiirLP + HiirHP;
iirMagErr = abs(abs(HiirSum) - 1);

gdFirLP = grpdelay(fir.bLP, 1, w);
gdFirHP = grpdelay(fir.bHP, 1, w);
gdIirLP = grpdelay(iir.bLP, iir.aLP, w);
gdIirHP = grpdelay(iir.bHP, iir.aHP, w);
gdIirSum = grpdelay(Bsum_iir, Asum_iir, w);

eqOff = struct('enable', false, 'lowBandGain_dB', 0, 'highBandGain_dB', 0);
[~, ~, ySumFir] = apply_crossover(x, "FIR", fir, iir, eqOff);
[~, ~, ySumIir] = apply_crossover(x, "IIR", fir, iir, eqOff);
xAp = filter(Bsum_iir, Asum_iir, x);

mFir = recon_metrics(x, ySumFir, maxLag);
mIir = recon_metrics(x, ySumIir, maxLag);
mIirAp = recon_metrics(xAp, ySumIir, maxLag);

if ~isfield(cfg, 'eq') || ~isstruct(cfg.eq)
    cfg.eq = struct();
end
eqCfg = cfg.eq;
if ~isfield(eqCfg, 'enable'), eqCfg.enable = false; end
if ~isfield(eqCfg, 'lowBandGain_dB'), eqCfg.lowBandGain_dB = 0; end
if ~isfield(eqCfg, 'highBandGain_dB'), eqCfg.highBandGain_dB = 0; end

[~, ~, ySumFirEq] = apply_crossover(x, "FIR", fir, iir, eqCfg);
[~, ~, ySumIirEq] = apply_crossover(x, "IIR", fir, iir, eqCfg);

metrics = struct();
metrics.clip_idx = clipIdx;
metrics.clip_name = string(clipName);
metrics.input_file = string(project_relative_path(inFile, cfg.paths.project_root));
metrics.input_num_samples = size(x, 1);
metrics.input_num_channels = size(x, 2);
metrics.input_duration_s = size(x, 1) / cfg.Fs;

metrics.Fs = cfg.Fs;
metrics.fc = cfg.fc;
metrics.fir_N = cfg.fir.N;
metrics.fir_window = string(cfg.fir.window);
metrics.iir_order = cfg.iir.order;
metrics.eq_enable = logical(eqCfg.enable);
metrics.eq_lowBandGain_dB = eqCfg.lowBandGain_dB;
metrics.eq_highBandGain_dB = eqCfg.highBandGain_dB;

metrics.analysis_band_low_hz = metricBand(1);
metrics.analysis_band_high_hz = metricBand(2);
metrics.analysis_nfft = nfft;

metrics.fir_delay_samples = fir.delay;
metrics.fir_delay_ms = 1000 * fir.delay / cfg.Fs;
metrics.fir_max_sum_error = max(firSumErr(idx));
metrics.fir_max_lp_gd_error_samples = max(abs(gdFirLP(idx) - fir.delay));
metrics.fir_max_hp_gd_error_samples = max(abs(gdFirHP(idx) - fir.delay));
metrics.fir_sum_vs_input_lag_samples = mFir.lag_samples;
metrics.fir_sum_vs_input_snr_db = mFir.snr_db;
metrics.fir_sum_vs_input_rms_error = mFir.rms_error;
metrics.fir_sum_vs_input_max_abs_error = mFir.max_abs_error;

metrics.iir_max_sum_mag_error = max(iirMagErr(idx));
metrics.iir_max_branch_gd_diff_samples = max(abs(gdIirLP(idx) - gdIirHP(idx)));
metrics.iir_mean_sum_gd_samples = mean(gdIirSum(idx));
metrics.iir_sum_vs_input_lag_samples = mIir.lag_samples;
metrics.iir_sum_vs_input_snr_db = mIir.snr_db;
metrics.iir_sum_vs_input_rms_error = mIir.rms_error;
metrics.iir_sum_vs_input_max_abs_error = mIir.max_abs_error;
metrics.iir_sum_vs_allpass_lag_samples = mIirAp.lag_samples;
metrics.iir_sum_vs_allpass_snr_db = mIirAp.snr_db;
metrics.iir_sum_vs_allpass_rms_error = mIirAp.rms_error;
metrics.iir_sum_vs_allpass_max_abs_error = mIirAp.max_abs_error;

metrics.input_peak = max(abs(x(:)));
metrics.fir_sum_peak_no_eq = max(abs(ySumFir(:)));
metrics.iir_sum_peak_no_eq = max(abs(ySumIir(:)));
metrics.fir_sum_peak_cfg_eq = max(abs(ySumFirEq(:)));
metrics.iir_sum_peak_cfg_eq = max(abs(ySumIirEq(:)));

metrics.fir_total_coefficients = numel(fir.bLP) + numel(fir.bHP);
metrics.iir_total_biquads = size(iir.sosLP, 1) + size(iir.sosHP, 1);
metrics.iir_total_tf_coefficients = numel(iir.bLP) + numel(iir.aLP) + numel(iir.bHP) + numel(iir.aHP);

end

function relPath = project_relative_path(pathStr, projectRoot)
% Convert an absolute path into a path relative to the project root.

pathStr = char(string(pathStr));
projectRoot = char(string(projectRoot));
prefix = [projectRoot filesep];

if startsWith(pathStr, prefix)
    relPath = extractAfter(string(pathStr), strlength(prefix));
else
    relPath = string(pathStr);
end

end
