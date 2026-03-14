function m = recon_metrics(x, y, maxLag)
%RECON_METRICS Time-domain reconstruction metrics with integer lag alignment.
%   m = recon_metrics(x, y, maxLag)
%   Aligns y to x by maximizing cross-correlation (channel 1) within +/-maxLag.
%   Returns metrics computed on the overlapped region.

if nargin < 3 || isempty(maxLag)
    maxLag = 4096;
end

if size(x,2) ~= size(y,2)
    error('x and y must have the same number of channels.');
end

% Use channel 1 for delay estimate (robust enough for stereo).
xa = x(:,1);
ya = y(:,1);

% Remove DC for correlation stability.
xa = xa - mean(xa);
ya = ya - mean(ya);

[c, lags] = xcorr(ya, xa, maxLag, 'coeff');
[~, iMax] = max(c);
lag = lags(iMax);

% lag > 0  => y occurs AFTER x by lag samples (y is delayed)
% lag < 0  => y occurs BEFORE x by -lag samples
if lag >= 0
    xUse = x(1:end-lag, :);
    yUse = y(1+lag:end, :);
else
    lag2 = -lag;
    xUse = x(1+lag2:end, :);
    yUse = y(1:end-lag2, :);
end

e = yUse - xUse;

rx = rms(xUse(:));
re = rms(e(:));
if re == 0
    snr_db = Inf;
else
    snr_db = 20*log10(rx/re);
end

m = struct();
m.lag_samples   = lag;
m.n_samples     = size(xUse,1);
m.rms_error     = re;
m.max_abs_error = max(abs(e(:)));
m.snr_db        = snr_db;
m.x_aligned     = xUse;
m.y_aligned     = yUse;
m.e             = e;

end
