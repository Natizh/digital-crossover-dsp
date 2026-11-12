# Running the project

[← Project overview & results](../README.md)

This guide explains the current MATLAB implementation and repository layout. For the filter comparison and its plots, start with the [project overview](../README.md).

## Requirements

- MATLAB with **Signal Processing Toolbox**.
- A working copy of this repository, including `audio_in/bass_pulse.wav`.

The scripts use functions including `fir1`, `butter`, `tf2sos`, `freqz`, `grpdelay`, `pwelch`, `sosfilt`, `resample`, `xcorr`, and `audiowrite`. MATLAB version compatibility has not been independently established for a specific release.

## Quick start

Clone the repository or download its ZIP from GitHub, open MATLAB, and change the Current Folder to the **repository root**. Then run:

```matlab
addpath("code");
summary = run_all();
```

This verifies both filter designs, processes the first configured input WAV, exports the processed audio to `audio_out/`, writes verification plots to `figures/`, and prints reconstruction metrics.

To regenerate the extended comparison figures shown in the README:

```matlab
make_all_figures();
```

To run the configured parameter comparisons and export a result table:

```matlab
[T, meta] = run_experiment_suite();
```

All three entry points use `cfg_default()` unless a function accepts and is explicitly passed an alternative configuration.

> **Output caution:** `cfg.export.cleanOutputDir` is `true` by default. When processing a clip, the code removes that clip's existing subfolder inside `audio_out/` before exporting the new WAV files. Back up outputs you want to keep.

## Configuration

Edit [`code/cfg_default.m`](../code/cfg_default.m) to change the defaults.

| Setting | Default | Meaning |
|---|---|---|
| `cfg.Fs` | `48000` | Processing/sample rate (Hz) |
| `cfg.fc` | `2000` | Crossover frequency (Hz) |
| `cfg.fir.N` | `255` | FIR number of taps; must be odd |
| `cfg.fir.window` | `"hamming"` | FIR window; Hamming, Hann, Blackman, or rectangular |
| `cfg.iir.order` | `4` | Fixed LR4 order; other orders are not implemented |
| `cfg.eq.enable` | `true` | Enable per-band gains in the EQ export |
| `cfg.eq.lowBandGain_dB` | `+5` | Low-band gain in dB |
| `cfg.eq.highBandGain_dB` | `-3` | High-band gain in dB |
| `cfg.audioFiles` | `"bass_pulse.wav"` | Input clip list |

The processing path can resample an input clip to `cfg.Fs` when necessary. Without EQ, the filters' sum can be tested as a reconstruction path; with EQ, the sum is intentionally reshaped.

## What is in each directory?

```text
digital-crossover-dsp/
├── README.md          Visual project overview and results
├── docs/
│   └── USAGE.md       This reproducibility and file guide
├── code/              MATLAB implementation and experiments
├── audio_in/          Input WAV clips (includes bass_pulse.wav)
├── audio_out/         Generated per-clip FIR/IIR WAV exports (gitignored)
├── figures/           Versioned plots and regenerated visualizations
├── paper/             Written report and slide presentation (PDF)
└── results/           Generated experiment CSV/MAT tables (gitignored)
```

The project resolves most file paths relative to its own source directory, not your MATLAB Current Folder. Add `code/` to the MATLAB path before calling the entry-point functions.

## Code map

| File | Responsibility |
|---|---|
| [`cfg_default.m`](../code/cfg_default.m) | Central configuration: sampling, filters, EQ, paths and audio inputs |
| [`run_all.m`](../code/run_all.m) | Main verification → one-clip processing pipeline |
| [`design_fir_crossover.m`](../code/design_fir_crossover.m) | Low-pass FIR and spectrally complementary high-pass |
| [`design_iir_crossover_lr4.m`](../code/design_iir_crossover_lr4.m) | Cascaded Butterworth sections, represented as SOS and gain |
| [`apply_crossover.m`](../code/apply_crossover.m) | Low/high filtering, optional band gains, and summation |
| [`process_one_clip.m`](../code/process_one_clip.m) | Audio read/resampling, both designs, WAV export, and metrics |
| [`test_fir_crossover.m`](../code/test_fir_crossover.m) | FIR magnitude, sum error and delay checks |
| [`test_iir_crossover_lr4.m`](../code/test_iir_crossover_lr4.m) | IIR magnitude sum and group-delay checks |
| [`make_all_figures.m`](../code/make_all_figures.m) | Extended figures: responses, delay, time signals and spectra |
| [`collect_crossover_metrics.m`](../code/collect_crossover_metrics.m) | Comparative metrics for a configuration and audio clip |
| [`run_experiment_suite.m`](../code/run_experiment_suite.m) | Parameter cases and structured CSV/MAT export |
| [`recon_metrics.m`](../code/recon_metrics.m) | Lag-aligned time-domain error and SNR metrics |
| [`iir_sum_tf.m`](../code/iir_sum_tf.m) | Equivalent summed IIR transfer function |

## Output files

For the default clip, `process_one_clip` creates a structure like this:

```text
audio_out/
└── bass_pulse/
    ├── FIR/
    │   ├── low.wav
    │   ├── high.wav
    │   ├── sum.wav
    │   ├── low_EQ.wav
    │   ├── high_EQ.wav
    │   └── sum_EQ.wav
    └── IIR/
        ├── low.wav
        ├── high.wav
        ├── sum.wav
        ├── low_EQ.wav
        ├── high_EQ.wav
        └── sum_EQ.wav
```

The `_EQ` exports include the configured per-band gain if EQ is enabled; when disabled, the code writes corresponding unmodified versions to keep the file set consistent. A **shared scale factor** may be applied across exports to avoid WAV clipping; absolute amplitude comparisons should account for this scale. The MATLAB return value also reports it.

The `figures/` directory contains both compact verification figures (`fir_mag.png`, `iir_gd.png`, etc.) and the extended numbered `Fig*.png` series. The README uses existing versioned extended figures.

The experiment runner writes `results/experiment_summary.csv` and `results/experiment_summary.mat` unless you override export options. Generated audio and experiment summaries are excluded from Git; generated plots are not.

## Run a custom experiment

Change the baseline configuration, or pass custom cases into `run_experiment_suite()`:

```matlab
addpath("code");

cases(1).name = "baseline";
cases(1).overrides = struct();
cases(1).clipIdx = [];

cases(2).name = "fc_1500_long_fir";
cases(2).overrides = struct( ...
    'fc', 1500, ...
    'fir', struct('N', 511, 'window', "blackman"), ...
    'eq', struct('enable', false, ...
                 'lowBandGain_dB', 0, 'highBandGain_dB', 0));
cases(2).clipIdx = [];

[T, meta] = run_experiment_suite(cases);
```

The experiment runner collects frequency-domain reconstruction errors, group-delay metrics, time-domain error/SNR measurements, and configuration parameters. It does not automatically run the main WAV export pipeline for every case.

## Add your own audio

1. Put a WAV file in `audio_in/`.
2. Add its filename to `cfg.audioFiles` in `code/cfg_default.m`.
3. Run `process_one_clip(clipIdx)` for that entry, or `run_all([], clipIdx)` to include verification.
4. Open the corresponding generated folders in `audio_out/`.

## Interpreting the comparison

- **FIR (without EQ):** the complementary sum implements a pure delay; for `N = 255`, that is 127 samples at 48 kHz.
- **IIR (without EQ):** the LR4 low/high branches sum to a response with nearly flat magnitude, but nonconstant phase. Compare the reconstructed signal to the equivalent IIR sum-path reference rather than solely to a shifted input.
- **With per-band EQ:** the low and high branches are independently scaled, so perfect no-EQ complementarity is not the expected result.
- **Timing vs cost:** the FIR length and the IIR section structure support a *qualitative* latency/complexity comparison. This repository does not include measured processor runtime benchmarks or a real-time hardware implementation.

The [written report](../paper/paperCrossover_2456340.pdf) and [presentation](../paper/DSP_Crossover_Presentation.pdf) provide the study's earlier narrative. For exact executable behavior use the current code, since the PDFs predate the repository's refactor.

[← Back to results](../README.md)
