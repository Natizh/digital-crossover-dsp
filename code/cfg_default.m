function cfg = cfg_default()
%CFG_DEFAULT Configuration for the FIR vs IIR crossover project.
% All global choices are defined here.

cfg = struct();
codeDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(codeDir);

% =========================
% Fixed global parameters
% =========================
cfg.Fs = 48000;        % Sampling rate [Hz]
cfg.fc = 2000;         % Crossover frequency [Hz]

% FIR baseline
cfg.fir = struct();
cfg.fir.N = 255;                % FIR length (odd)
cfg.fir.window = "hamming";     % "hamming", "hann", "blackman", "rectangular"

% IIR baseline
cfg.iir = struct();
cfg.iir.order = 4;     % Fixed to LR4 (cascade of two 2nd-order Butterworth sections)

% =========================
% EQ settings
% =========================

cfg.eq.enable = true;           % Turn on/off EQ
% simple per-band gain
cfg.eq.lowBandGain_dB  = +5;
cfg.eq.highBandGain_dB = -3;


% =========================
% I/O folders (relative to project root)
% =========================
cfg.paths = struct();
cfg.paths.project_root = projectRoot;
cfg.paths.code = codeDir;
cfg.paths.audio_in = fullfile(projectRoot, "audio_in");
cfg.paths.audio_out = fullfile(projectRoot, "audio_out");
cfg.paths.figures = fullfile(projectRoot, "figures");

% =========================
% Export behavior
% =========================
cfg.export = struct();
cfg.export.cleanOutputDir = true;

% =========================
% Analysis settings
% =========================
cfg.analysis = struct();
cfg.analysis.nfft = 8192;
cfg.analysis.metricBandHz = [20 20000];
cfg.analysis.maxLag = 4096;

% =========================
% Results folder
% =========================
cfg.paths.results = fullfile(projectRoot, "results");

% =========================
% Audio input list
% =========================
% Add WAV files in /audio_in and list them here.

cfg.audioFiles = string([
    "bass_pulse.wav"
]);

end
