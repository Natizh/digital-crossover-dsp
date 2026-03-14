function [resultsTable, meta] = run_experiment_suite(cases, opts)
%RUN_EXPERIMENT_SUITE Run multiple parameterized cases and export a summary table.

baseCfg = cfg_default();

if nargin < 1 || isempty(cases)
    cases = default_cases();
end
if nargin < 2 || isempty(opts)
    opts = struct();
end

if ~isfield(opts, 'outputDir') || isempty(opts.outputDir)
    opts.outputDir = baseCfg.paths.results;
end
if ~isfield(opts, 'csvName') || isempty(opts.csvName)
    opts.csvName = "experiment_summary.csv";
end
if ~isfield(opts, 'matName') || isempty(opts.matName)
    opts.matName = "experiment_summary.mat";
end
if ~isfield(opts, 'writeCsv'), opts.writeCsv = true; end
if ~isfield(opts, 'writeMat'), opts.writeMat = true; end
if ~isfield(opts, 'verbose'), opts.verbose = true; end

if ~isfolder(opts.outputDir)
    mkdir(opts.outputDir);
end

rowCells = cell(0, 1);

for i = 1:numel(cases)
    caseDef = cases(i);
    if ~isfield(caseDef, 'name') || strlength(string(caseDef.name)) == 0
        caseDef.name = "case_" + i;
    end
    if ~isfield(caseDef, 'overrides') || isempty(caseDef.overrides)
        caseDef.overrides = struct();
    end
    cfg = apply_cfg_overrides(baseCfg, caseDef.overrides);

    if ~isfield(caseDef, 'clipIdx') || isempty(caseDef.clipIdx)
        clipIndices = 1:numel(cfg.audioFiles);
    else
        clipIndices = caseDef.clipIdx;
    end

    for clipIdx = clipIndices
        if opts.verbose
            fprintf("Running case '%s' on clip %d/%d...\n", caseDef.name, clipIdx, numel(cfg.audioFiles));
        end

        metrics = collect_crossover_metrics(cfg, clipIdx);
        rowCells{end+1, 1} = flatten_metrics(caseDef.name, metrics); %#ok<AGROW>
    end
end

if isempty(rowCells)
    resultsTable = table();
else
    resultsTable = struct2table(vertcat(rowCells{:}));
end

if opts.writeCsv
    writetable(resultsTable, fullfile(opts.outputDir, opts.csvName));
end
if opts.writeMat
    save(fullfile(opts.outputDir, opts.matName), 'resultsTable', 'cases', 'opts');
end

meta = struct();
meta.output_dir = project_relative_path(opts.outputDir, baseCfg.paths.project_root);
meta.csv_path = project_relative_path(fullfile(opts.outputDir, opts.csvName), baseCfg.paths.project_root);
meta.mat_path = project_relative_path(fullfile(opts.outputDir, opts.matName), baseCfg.paths.project_root);
meta.num_cases = numel(cases);
meta.num_rows = height(resultsTable);

if opts.verbose
    fprintf("Saved experiment summary to %s\n", meta.csv_path);
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

end

function row = flatten_metrics(caseName, metrics)
% Convert per-case metrics into a single flat table row.

row = metrics;
row.case_name = string(caseName);
row = orderfields(row, [{'case_name'}; setdiff(fieldnames(row), {'case_name'}, 'stable')]);

end

function cfg = apply_cfg_overrides(cfg, overrides)
% Recursively apply nested overrides to a cfg struct.

if nargin < 2 || isempty(overrides)
    return;
end

fields = fieldnames(overrides);
for i = 1:numel(fields)
    key = fields{i};
    value = overrides.(key);

    if isstruct(value) && isfield(cfg, key) && isstruct(cfg.(key))
        cfg.(key) = apply_cfg_overrides(cfg.(key), value);
    else
        cfg.(key) = value;
    end
end

end

function cases = default_cases()
% Built-in example parameter sweep based on cfg_default().

cases = struct( ...
    'name', {}, ...
    'overrides', {}, ...
    'clipIdx', {});

cases(1).name = "baseline";
cases(1).overrides = struct();
cases(1).clipIdx = [];

cases(2).name = "fir_short_hamming";
cases(2).overrides = struct('fir', struct('N', 127, 'window', "hamming"));
cases(2).clipIdx = [];

cases(3).name = "fir_long_blackman";
cases(3).overrides = struct('fir', struct('N', 511, 'window', "blackman"));
cases(3).clipIdx = [];

cases(4).name = "low_fc_eq_off";
cases(4).overrides = struct( ...
    'fc', 1200, ...
    'eq', struct('enable', false, 'lowBandGain_dB', 0, 'highBandGain_dB', 0));
cases(4).clipIdx = [];

cases(5).name = "high_fc_eq_on";
cases(5).overrides = struct( ...
    'fc', 3000, ...
    'eq', struct('enable', true, 'lowBandGain_dB', 3, 'highBandGain_dB', -2));
cases(5).clipIdx = [];

end
