function fir = design_fir_crossover(cfg)
%DESIGN_FIR_CROSSOVER
% Linear-phase FIR 2-way crossover (LP + HP, complementary)

Fs = cfg.Fs;
fc = cfg.fc;

N = cfg.fir.N;                  % FIR length (must be odd)
Wn = fc / (Fs/2);               % normalized cutoff (0..1)

if mod(N,2) == 0
    error("FIR length N must be odd for linear-phase symmetry.");
end
if Wn <= 0 || Wn >= 1
    error("cfg.fc must satisfy 0 < fc < Fs/2.");
end

% --- Low-pass FIR (linear phase) ---
win = make_window(N, cfg.fir.window);
bLP = fir1(N-1, Wn, 'low', win, 'scale');

% --- High-pass FIR: spectral complement ---
bHP = -bLP;
bHP((N+1)/2) = bHP((N+1)/2) + 1;

% --- FIR group delay (samples) ---
delay = (N-1)/2;

% output struct
fir = struct();
fir.bLP = bLP;
fir.bHP = bHP;
fir.delay = delay;
fir.window = string(cfg.fir.window);

end

function win = make_window(N, windowName)
% Keep window selection configurable from cfg_default().

name = lower(string(windowName));

switch name
    case "hamming"
        win = hamming(N);
    case "hann"
        win = hann(N);
    case "blackman"
        win = blackman(N);
    case {"rect", "rectangular", "boxcar"}
        win = rectwin(N);
    otherwise
        error("Unsupported FIR window '%s'.", name);
end

end
