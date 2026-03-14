# Digital Audio Crossover: FIR vs IIR

This repository contains a MATLAB project on 2-way digital crossovers for multi-driver audio systems. The goal is to compare two design families under the same conditions:

- `FIR`: complementary linear-phase low-pass/high-pass filters
- `IIR`: 4th-order Linkwitz-Riley crossover built from cascaded Butterworth sections

The project verifies reconstruction, compares delay behavior, processes real audio, exports WAV files, generates figures for the report, and runs small parameter sweeps based on `cfg_default.m`.

## Repository Layout

- [`code`](code): MATLAB source files
- [`audio_in`](audio_in): input WAV clips used for tests and demos
- [`audio_out`](audio_out): generated FIR/IIR band outputs and summed outputs
- [`figures`](figures): generated figures for the report
- [`paper`](paper): written report and presentation PDFs
- [`results`](results): generated CSV/MAT summaries

## Requirements

- MATLAB
- Signal Processing Toolbox

Main toolbox functions used by the code include `fir1`, `butter`, `tf2sos`, `freqz`, `grpdelay`, `pwelch`, `sosfilt`, `resample`, and `audiowrite`.

## Start Here

If you are opening the repository for the first time, use this order:

1. read [`cfg_default.m`](code/cfg_default.m) to understand the default sampling rate, crossover frequency, FIR settings, EQ settings, paths, and audio clips
2. run [`run_all.m`](code/run_all.m) to execute the main pipeline once
3. run [`make_all_figures.m`](code/make_all_figures.m) if you want the full figure set used by the report
4. run [`run_experiment_suite.m`](code/run_experiment_suite.m) if you want a structured comparison across different parameter choices

## Main Pipelines

### 1. Main DSP Pipeline

Use this when you want the shortest complete run from configuration to outputs:

```matlab
addpath("code");
run_all();
```

What it does:

1. loads the default configuration from `cfg_default.m`
2. verifies the FIR crossover and saves FIR verification figures
3. verifies the IIR crossover and saves IIR verification figures
4. processes the selected input clip
5. exports low band, high band, and summed WAV files for FIR and IIR
6. prints reconstruction metrics in the MATLAB console

### 2. Full Figure Generation

Use this when you want the complete set of paper-style figures:

```matlab
addpath("code");
make_all_figures();
```

This produces the figures in `figures/`, including:

- frequency responses
- reconstruction error plots
- branch and sum-path group delay plots
- time-domain comparisons
- spectra before and after crossover
- EQ-on visual comparisons

### 3. Parameter Sweep / Comparison Workflow

Use this when you want to compare different settings from `cfg_default.m` without changing the processing logic:

```matlab
addpath("code");
[T, meta] = run_experiment_suite();
```

This workflow:

1. starts from `cfg_default.m`
2. builds a small list of test cases by overriding only selected fields
3. runs the objective metrics for each case and each selected clip
4. exports `results/experiment_summary.csv`
5. exports `results/experiment_summary.mat`

The resulting table is meant for quick comparison in MATLAB, Excel, Numbers, or any plotting tool.

### Core DSP Logic

- [`cfg_default.m`](code/cfg_default.m): single source of truth for default parameters and paths
- [`design_fir_crossover.m`](code/design_fir_crossover.m): designs the complementary FIR crossover
- [`design_iir_crossover_lr4.m`](code/design_iir_crossover_lr4.m): designs the Linkwitz-Riley IIR crossover
- [`apply_crossover.m`](code/apply_crossover.m): applies FIR or IIR splitting plus optional per-band EQ
- [`process_one_clip.m`](code/process_one_clip.m): processes one audio clip and exports the audio outputs

### Verification and Metrics

- [`test_fir_crossover.m`](code/test_fir_crossover.m): FIR-only verification plots and console metrics
- [`test_iir_crossover_lr4.m`](code/test_iir_crossover_lr4.m): IIR-only verification plots and console metrics
- [`collect_crossover_metrics.m`](code/collect_crossover_metrics.m): compact objective comparison for one configuration/clip pair
- [`recon_metrics.m`](code/recon_metrics.m): aligned time-domain error metrics used by the rest of the project

### Shared Helper

- [`iir_sum_tf.m`](code/iir_sum_tf.m): computes the equivalent transfer function of the summed IIR path; kept as a separate helper to avoid duplicating the same formula in multiple files

## Procedure for Extending the Study

### Add More Audio

1. place new WAV files in `audio_in/`
2. list them in [`cfg_default.m`](code/cfg_default.m)
3. rerun `run_all()`, `make_all_figures()`, or `run_experiment_suite()`

### Study More FIR Cases

Change in [`cfg_default.m`](code/cfg_default.m) or define overrides in `run_experiment_suite()`:

- `cfg.fc`
- `cfg.fir.N`
- `cfg.fir.window`
- `cfg.eq.enable`
- `cfg.eq.lowBandGain_dB`
- `cfg.eq.highBandGain_dB`

### Define Custom Sweep Cases

```matlab
addpath("code");

cases(1).name = "baseline";
cases(1).overrides = struct();
cases(1).clipIdx = [];

cases(2).name = "fc_1500_long_fir";
cases(2).overrides = struct( ...
    'fc', 1500, ...
    'fir', struct('N', 511, 'window', "blackman"), ...
    'eq', struct('enable', false, 'lowBandGain_dB', 0, 'highBandGain_dB', 0));
cases(2).clipIdx = [];

[T, meta] = run_experiment_suite(cases);
```

## What the Current Results Mean

At a high level, the repository shows the expected tradeoff:

- FIR gives near-perfect delayed reconstruction with linear phase
- IIR gives much lower effective latency/cost, but its summed output should be interpreted as an all-pass equivalent path rather than as a delayed copy of the input
- per-band EQ is easy to apply after the split and changes the spectra as expected

## Paper and Presentation Alignment

The repository already contains:

- a written report PDF: [`paperCrossover_2456340.pdf`](paper/paperCrossover_2456340.pdf)
- a presentation PDF: [`DSP_Crossover_Presentation.pdf`](paper/DSP_Crossover_Presentation.pdf)

The report and the presentation should be read as part of the project documentation, but they may not reflect the current codebase with perfect precision. They were prepared from an earlier version of the project, before the repository was cleaned up and reorganized into its current structure, so some implementation details, filenames, or workflow descriptions may differ slightly from what you now find in the MATLAB files. For execution and reproducibility, the code in this repository should be considered the source of truth, while the PDF report and slides should be considered a faithful description of the project goals, methods, and main results, even when they do not match the latest refactor exactly.

## Notes

- output folders are cleaned before export by default; this behavior is controlled in [`cfg_default.m`](code/cfg_default.m)
- paths are resolved from the project itself, so functions can be launched from any working directory once `code/` is on the MATLAB path
- generated WAV exports in `audio_out/` and generated benchmark files in `results/` are ignored by git by default
