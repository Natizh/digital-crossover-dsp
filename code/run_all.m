function summary = run_all(cfg, clipIdx)
%RUN_ALL pipeline for verification and audio export.

if nargin < 1 || isempty(cfg)
    cfg = cfg_default();
end
if nargin < 2 || isempty(clipIdx)
    clipIdx = 1;
end

% ---- Ensure folders exist ----
if ~isfolder(cfg.paths.audio_in)
    error("Missing folder: %s", cfg.paths.audio_in);
end
if ~isfolder(cfg.paths.audio_out) 
    mkdir(cfg.paths.audio_out); 
end
if ~isfolder(cfg.paths.figures)   
    mkdir(cfg.paths.figures);   
end

% ---- Check audio files exist ----
for i = 1:numel(cfg.audioFiles)
    f = fullfile(cfg.paths.audio_in, cfg.audioFiles(i));
    if ~isfile(f)
        error("Audio file not found: %s (edit cfg_default.m -> cfg.audioFiles)", f);
    end
end

fprintf("OK: Fs=%d Hz, fc=%d Hz.\n", cfg.Fs, cfg.fc);

firMetrics = test_fir_crossover(cfg);
iirMetrics = test_iir_crossover_lr4(cfg);
clipResult = process_one_clip(clipIdx, cfg);

fprintf("\nDone. Figures -> %s, WAVs -> %s\n", cfg.paths.figures, cfg.paths.audio_out);
fprintf("Summary: FIR max sum error=%.3e, IIR max magnitude error=%.3e\n", ...
    firMetrics.max_sum_error, iirMetrics.max_mag_error);

summary = struct();
summary.fir = firMetrics;
summary.iir = iirMetrics;
summary.clip = clipResult;

end
