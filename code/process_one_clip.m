function result = process_one_clip(clipIdx, cfg)
%PROCESS_ONE_CLIP Process one clip, export bands/sums, and report metrics.

if nargin < 1 || isempty(clipIdx)
    clipIdx = 1;
end
if nargin < 2 || isempty(cfg)
    cfg = cfg_default();
end
if clipIdx < 1 || clipIdx > numel(cfg.audioFiles)
    error("clipIdx=%d out of range (cfg.audioFiles has %d entries).", clipIdx, numel(cfg.audioFiles));
end
if ~isfield(cfg, "export") || ~isfield(cfg.export, "cleanOutputDir")
    cfg.export.cleanOutputDir = true;
end

% ---------- Read input ----------
inFile = fullfile(cfg.paths.audio_in, cfg.audioFiles(clipIdx));
[x, Fs_in] = audioread(inFile);

% Resample to cfg.Fs if needed (keeps filter design consistent)
if Fs_in ~= cfg.Fs
    x = resample(x, cfg.Fs, Fs_in);  
end

% Base name for exports (requested form)
base = erase(cfg.audioFiles(clipIdx), ".wav");
if isstring(base), base = char(base); end

% ---------- Prepare output folder (overwrite) ----------
outRoot = fullfile(cfg.paths.audio_out, base);
if isfolder(outRoot) && cfg.export.cleanOutputDir
    rmdir(outRoot, "s");
end
if ~isfolder(outRoot)
    mkdir(outRoot);
end

outFIR = fullfile(outRoot, "FIR");
outIIR = fullfile(outRoot, "IIR");
if ~isfolder(outFIR), mkdir(outFIR); end
if ~isfolder(outIIR), mkdir(outIIR); end

% ---------- Design filters ----------
fir = design_fir_crossover(cfg);
iir = design_iir_crossover_lr4(cfg);

% ---------- EQ configs ----------
eqOff = struct('enable', false, 'lowBandGain_dB', 0, 'highBandGain_dB', 0);

eqOn = struct();
if isfield(cfg,'eq') && isstruct(cfg.eq)
    eqOn = cfg.eq;
end
if ~isfield(eqOn,'enable'),          eqOn.enable = false; end
if ~isfield(eqOn,'lowBandGain_dB'),  eqOn.lowBandGain_dB  = 0; end
if ~isfield(eqOn,'highBandGain_dB'), eqOn.highBandGain_dB = 0; end

% ---------- Process: no EQ ----------
[yL_fir, yH_fir, ySum_fir] = apply_crossover(x, "FIR", fir, iir, eqOff);
[yL_iir, yH_iir, ySum_iir] = apply_crossover(x, "IIR", fir, iir, eqOff);

% ---------- Process: EQ (bands + sum) ----------
if eqOn.enable
    [yL_fir_eq, yH_fir_eq, ySum_fir_eq] = apply_crossover(x, "FIR", fir, iir, eqOn);
    [yL_iir_eq, yH_iir_eq, ySum_iir_eq] = apply_crossover(x, "IIR", fir, iir, eqOn);
else
    % Keep outputs consistent even if EQ is disabled
    yL_fir_eq   = yL_fir;   yH_fir_eq   = yH_fir;   ySum_fir_eq   = ySum_fir;
    yL_iir_eq   = yL_iir;   yH_iir_eq   = yH_iir;   ySum_iir_eq   = ySum_iir;
end

% ---------- Prevent clipping on export (single scale for ALL files) ----------
mx = max(abs([ ...
    yL_fir(:);    yH_fir(:);    ySum_fir(:); ...
    yL_fir_eq(:); yH_fir_eq(:); ySum_fir_eq(:); ...
    yL_iir(:);    yH_iir(:);    ySum_iir(:); ...
    yL_iir_eq(:); yH_iir_eq(:); ySum_iir_eq(:) ]));

scale = 1;
if mx > 0.999
    scale = 0.999 / mx;
end

% ---------- Reconstruction metrics ----------
maxLag = max(4096, 2*fir.delay + 64);
[Bsum_iir, Asum_iir] = iir_sum_tf(iir);
x_ap = filter(Bsum_iir, Asum_iir, x);

mFir_x = recon_metrics(x, ySum_fir, maxLag);
mIir_x = recon_metrics(x, ySum_iir, maxLag);
mIir_ap = recon_metrics(x_ap, ySum_iir, maxLag);

% ---------- Export WAVs (no EQ + EQ) ----------
% FIR
audiowrite(fullfile(outFIR, "low.wav"),      scale*yL_fir,     cfg.Fs);
audiowrite(fullfile(outFIR, "high.wav"),     scale*yH_fir,     cfg.Fs);
audiowrite(fullfile(outFIR, "sum.wav"),      scale*ySum_fir,   cfg.Fs);

audiowrite(fullfile(outFIR, "low_EQ.wav"),   scale*yL_fir_eq,  cfg.Fs);
audiowrite(fullfile(outFIR, "high_EQ.wav"),  scale*yH_fir_eq,  cfg.Fs);
audiowrite(fullfile(outFIR, "sum_EQ.wav"),   scale*ySum_fir_eq,cfg.Fs);

% IIR
audiowrite(fullfile(outIIR, "low.wav"),      scale*yL_iir,     cfg.Fs);
audiowrite(fullfile(outIIR, "high.wav"),     scale*yH_iir,     cfg.Fs);
audiowrite(fullfile(outIIR, "sum.wav"),      scale*ySum_iir,   cfg.Fs);

audiowrite(fullfile(outIIR, "low_EQ.wav"),   scale*yL_iir_eq,  cfg.Fs);
audiowrite(fullfile(outIIR, "high_EQ.wav"),  scale*yH_iir_eq,  cfg.Fs);
audiowrite(fullfile(outIIR, "sum_EQ.wav"),   scale*ySum_iir_eq,cfg.Fs);

fprintf("Exported to: %s\n", outRoot);
fprintf("EQ: enable=%d, low=%+0.1f dB, high=%+0.1f dB\n", ...
    eqOn.enable, eqOn.lowBandGain_dB, eqOn.highBandGain_dB);
fprintf("FIR sum vs x: lag=%d samples, SNR=%.2f dB, max|e|=%.3e\n", ...
    mFir_x.lag_samples, mFir_x.snr_db, mFir_x.max_abs_error);
fprintf("IIR sum vs x: lag=%d samples, SNR=%.2f dB, max|e|=%.3e\n", ...
    mIir_x.lag_samples, mIir_x.snr_db, mIir_x.max_abs_error);
fprintf("IIR sum vs x_ap: lag=%d samples, SNR=%.2f dB, max|e|=%.3e\n", ...
    mIir_ap.lag_samples, mIir_ap.snr_db, mIir_ap.max_abs_error);

result = struct();
result.input_file = inFile;
result.output_root = outRoot;
result.scale = scale;
result.fir_vs_input = mFir_x;
result.iir_vs_input = mIir_x;
result.iir_vs_allpass_reference = mIir_ap;

end
