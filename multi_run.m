% ============================================
% MULTI-RUN EEG LOADER
% ============================================

% --- Settings ---
subject    = 'S001';
n_runs     = 14;
data_folder = '';   % Change to your folder path

% --- Channels we care about ---
target_channels = {'C3__', 'Cz__', 'C4__', 'O1__', 'Oz__', 'O2__', 'Fp1_'};

% --- Run labels ---
run_labels = {
    'R01 - Baseline Eyes Open',
    'R02 - Baseline Eyes Closed',
    'R03 - Task1: Real Left/Right Fist',
    'R04 - Task2: Imagined Left/Right Fist',
    'R05 - Task3: Real Both Fists/Feet',
    'R06 - Task4: Imagined Both Fists/Feet',
    'R07 - Task1: Real Left/Right Fist',
    'R08 - Task2: Imagined Left/Right Fist',
    'R09 - Task3: Real Both Fists/Feet',
    'R10 - Task4: Imagined Both Fists/Feet',
    'R11 - Task1: Real Left/Right Fist',
    'R12 - Task2: Imagined Left/Right Fist',
    'R13 - Task3: Real Both Fists/Feet',
    'R14 - Task4: Imagined Both Fists/Feet',
};

% --- Storage ---
all_runs   = struct();   % Will hold data for all runs

fprintf('=== Loading %d EEG runs for subject %s ===\n', n_runs, subject);

for r = 1:n_runs
    % Build filename
    filename = sprintf('%s%sR%02d.edf', data_folder, subject, r);
    fprintf('Loading Run %02d: %s ... ', r, run_labels{r});

    % Load header and data
    info       = edfinfo(filename);
    data_table = edfread(filename);
    fs         = info.NumSamples(1) / seconds(info.DataRecordDuration);

    % Unpack channels (same method as your working code)
    clean_data   = [];
    clean_labels = {};
    col_idx      = 1;

    for i = 1:width(data_table)
        colData = data_table{:, i};
        if iscell(colData)
            if isnumeric(colData{1})
                clean_data(:, col_idx) = vertcat(colData{:});
                clean_labels{col_idx}  = data_table.Properties.VariableNames{i};
                col_idx = col_idx + 1;
            end
        elseif isnumeric(colData)
            clean_data(:, col_idx) = colData;
            clean_labels{col_idx}  = data_table.Properties.VariableNames{i};
            col_idx = col_idx + 1;
        end
    end

    % Extract only our target channels
    run_data = zeros(size(clean_data, 1), length(target_channels));
    for c = 1:length(target_channels)
        idx = find(strcmp(clean_labels, target_channels{c}));
        if ~isempty(idx)
            run_data(:, c) = clean_data(:, idx) - mean(clean_data(:, idx));
        end
    end

    % Store in struct
    all_runs(r).label    = run_labels{r};
    all_runs(r).data     = run_data;      % samples x 7 channels
    all_runs(r).fs       = fs;
    all_runs(r).duration = size(run_data,1) / fs;
    all_runs(r).n_samp   = size(run_data, 1);

    fprintf('OK (%.1f sec, %.0f Hz)\n', all_runs(r).duration, fs);
end

fprintf('\n=== All runs loaded successfully! ===\n');
fprintf('Channels tracked: ');
fprintf('%s  ', target_channels{:});
fprintf('\n');

% ============================================
% COMPARISON 1: Eyes Open vs Eyes Closed
% Focus: Alpha band in occipital channels (O1, Oz, O2)
% ============================================

fs = all_runs(1).fs;
ch_names = target_channels;

% Band definitions
bands = {0.5,4,'Delta'; 4,8,'Theta'; 8,13,'Alpha'; 13,30,'Beta'; 30,45,'Gamma'};

% Compute band power for runs 1 and 2
function pow = band_power(sig, fs, fl, fh)
    Wn = [fl fh] / (fs/2);
    [B,A] = butter(4, Wn, 'bandpass');
    f = filtfilt(B, A, sig);
    pow = mean(f.^2);
end

% Occipital channels indices (O1=4, Oz=5, O2=6)
occ_idx = [4, 5, 6];
occ_names = {'O1__', 'Oz__', 'O2__'};

fprintf('\n=== Comparison 1: Eyes Open vs Closed ===\n');
fprintf('%-8s %-12s %-12s %-12s\n', 'Channel','Eyes Open','Eyes Closed','Change');
fprintf('%s\n', repmat('-',1,48));

pow_open   = zeros(3, 5);
pow_closed = zeros(3, 5);

for c = 1:3
    sig_open   = all_runs(1).data(:, occ_idx(c));
    sig_closed = all_runs(2).data(:, occ_idx(c));
    for b = 1:5
        pow_open(c,b)   = band_power(sig_open,   fs, bands{b,1}, bands{b,2});
        pow_closed(c,b) = band_power(sig_closed,  fs, bands{b,1}, bands{b,2});
    end
end

% Print Alpha power comparison
alpha_b = 3;
for c = 1:3
    change = ((pow_closed(c,alpha_b) - pow_open(c,alpha_b)) / pow_open(c,alpha_b)) * 100;
    fprintf('%-8s %-12.2f %-12.2f %+.1f%%\n', ...
        occ_names{c}, pow_open(c,alpha_b), pow_closed(c,alpha_b), change);
end
% --- Plot: Band power comparison (all bands, channel Oz) ---
oz = 5;   % Oz index
figure('Name','Comparison 1: Eyes Open vs Closed','Position',[100 100 900 420]);

x    = 1:5;
w    = 0.35;
cols_open   = [0.2 0.5 0.9];
cols_closed = [0.9 0.3 0.2];

subplot(1,2,1);
b1 = bar(x - w/2, pow_open(oz-3,:),  w, 'FaceColor', cols_open);
hold on;
b2 = bar(x + w/2, pow_closed(oz-3,:), w, 'FaceColor', cols_closed);
hold off;
xticks(x); xticklabels({bands{:,3}}); xtickangle(30);
ylabel('Mean Power (µV²)');
title('Oz — All Bands: Open vs Closed','Interpreter','none');
legend({'Eyes Open','Eyes Closed'},'Location','northwest');
grid on;

% Alpha-only across all 3 occipital channels
subplot(1,2,2);
open_alpha   = pow_open(:, alpha_b);
closed_alpha = pow_closed(:, alpha_b);
b3 = bar([open_alpha, closed_alpha]);
b3(1).FaceColor = cols_open;
b3(2).FaceColor = cols_closed;
xticklabels(occ_names); xtickangle(30);
ylabel('Alpha Power (µV²)');
title('Alpha Power: Open vs Closed (Occipital)','Interpreter','none');
legend({'Eyes Open','Eyes Closed'},'Location','northwest');
grid on;
% ============================================
% COMPARISON 2: Rest vs Real vs Imagined Movement
% Focus: Beta band in motor channels (C3, Cz, C4)
% ============================================

% Motor channel indices
mot_idx   = [1, 2, 3];   % C3, Cz, C4
mot_names = {'C3__','Cz__','C4__'};

% Average across repeated runs:
% Real movement    = runs 3, 7, 11  (Task 1)
% Imagined movement= runs 4, 8, 12  (Task 2)
% Baseline (rest)  = run 1

real_runs  = [3, 7, 11];
imag_runs  = [4, 8, 12];

fprintf('\n=== Comparison 2: Rest vs Real vs Imagined ===\n');
fprintf('%-8s %-12s %-12s %-12s\n','Channel','Rest','Real','Imagined');
fprintf('%s\n', repmat('-',1,48));

beta_b = 4;
pow_rest = zeros(3,1);
pow_real = zeros(3,1);
pow_imag = zeros(3,1);

for c = 1:3
    pow_rest(c) = band_power(all_runs(1).data(:,mot_idx(c)), fs, bands{beta_b,1}, bands{beta_b,2});

    % Average across 3 repetitions of real movement
    tmp = zeros(3,1);
    for r = 1:3
        tmp(r) = band_power(all_runs(real_runs(r)).data(:,mot_idx(c)), fs, bands{beta_b,1}, bands{beta_b,2});
    end
    pow_real(c) = mean(tmp);

    % Average across 3 repetitions of imagined movement
    for r = 1:3
        tmp(r) = band_power(all_runs(imag_runs(r)).data(:,mot_idx(c)), fs, bands{beta_b,1}, bands{beta_b,2});
    end
    pow_imag(c) = mean(tmp);

    fprintf('%-8s %-12.2f %-12.2f %-12.2f\n', ...
        mot_names{c}, pow_rest(c), pow_real(c), pow_imag(c));
end
% --- Plot ---
figure('Name','Comparison 2: Rest vs Real vs Imagined','Position',[100 100 700 480]);

data_c2  = [pow_rest, pow_real, pow_imag];
b = bar(data_c2, 'grouped');
b(1).FaceColor = [0.4 0.7 0.4];   % Rest = green
b(2).FaceColor = [0.2 0.4 0.8];   % Real = blue
b(3).FaceColor = [0.9 0.4 0.1];   % Imagined = orange

xticks(1:3); xticklabels(mot_names); xtickangle(30);
ylabel('Beta Power (µV²)');
title('Beta Power: Rest vs Real vs Imagined Movement','Interpreter','none');
legend({'Rest (R01)','Real Movement (avg R03,07,11)', ...
        'Imagined Movement (avg R04,08,12)'},'Location','best');
grid on;
% ============================================
% COMPARISON 3: Left vs Right Fist
% The key insight: C3 controls RIGHT hand, C4 controls LEFT
% When you move LEFT fist → C4 activates (Beta suppresses on C4)
% When you move RIGHT fist → C3 activates (Beta suppresses on C3)
% ============================================

% We need to extract T1 (left fist) and T2 (right fist) epochs
% from runs 3, 7, 11 using annotations

fprintf('\n=== Comparison 3: Left vs Right Fist ===\n');

% Extract epochs by re-reading annotations from run 3
filename_r3 = sprintf('%sS001R03.edf', data_folder);
[~, annotations] = edfread(filename_r3);

% Get event times and labels
evt_times  = annotations.Onset;
evt_labels = annotations.Annotations;

t1_epochs = [];   % Left fist epochs
t2_epochs = [];   % Right fist epochs
epoch_len  = round(4 * fs);   % 4-second epochs

sig_c3 = all_runs(3).data(:, 1);   % C3
sig_c4 = all_runs(3).data(:, 3);   % C4

for e = 1:length(evt_labels)
    label = evt_labels{e};
    if iscell(label), label = label{1}; end

    onset_samp = round(seconds(evt_times(e)) * fs) + 1;
    end_samp   = onset_samp + epoch_len - 1;

    if end_samp > length(sig_c3), continue; end

    if strcmp(label, 'T1')   % Left fist onset
        t1_epochs(end+1,:) = sig_c3(onset_samp:end_samp)';
    elseif strcmp(label, 'T2')   % Right fist onset
        t2_epochs(end+1,:) = sig_c3(onset_samp:end_samp)';
    end
end

fprintf('T1 (Left fist) epochs found:  %d\n', size(t1_epochs,1));
fprintf('T2 (Right fist) epochs found: %d\n', size(t2_epochs,1));
% --- Plot: Average epoch waveform C3 ---
t_ep = (0:epoch_len-1) / fs;

figure('Name','Comparison 3: Left vs Right Fist','Position',[100 100 1000 450]);

subplot(1,2,1);
plot(t_ep, mean(t1_epochs), 'b', 'LineWidth', 1.5); hold on;
plot(t_ep, mean(t2_epochs), 'r', 'LineWidth', 1.5);
xline(0, '--k', 'Movement onset','Interpreter','none');
hold off;
xlabel('Time (seconds)');
ylabel('Amplitude (µV)');
title('C3 — Average Epoch: Left vs Right Fist','Interpreter','none');
legend({'T1: Left Fist','T2: Right Fist'});
grid on;

% Beta power per condition
beta_t1 = zeros(size(t1_epochs,1),1);
beta_t2 = zeros(size(t2_epochs,1),1);
Wn = [13 30]/(fs/2);
[Bf,Af] = butter(4, Wn, 'bandpass');

for i = 1:size(t1_epochs,1)
    f = filtfilt(Bf,Af, t1_epochs(i,:)');
    beta_t1(i) = mean(f.^2);
end
for i = 1:size(t2_epochs,1)
    f = filtfilt(Bf,Af, t2_epochs(i,:)');
    beta_t2(i) = mean(f.^2);
end

subplot(1,2,2);
bar([mean(beta_t1), mean(beta_t2)], 'FaceColor', 'flat', ...
    'CData', [0.2 0.4 0.8; 0.9 0.3 0.2]);
xticks([1 2]);
xticklabels({'T1: Left Fist','T2: Right Fist'});
ylabel('Beta Power (µV²)');
title('C3 Beta Power per Condition','Interpreter','none');
grid on;

% ============================================
% STEP 1: Reload key runs with ALL 64 channels
% ============================================

runs_to_load = [1, 2, 3, 4, 5, 6];   % Baseline + first of each task
run_labels_short = {
    'Eyes Open',
    'Eyes Closed',
    'Real L/R Fist',
    'Imagined L/R Fist',
    'Real Both Fists',
    'Imagined Both Fists'
};

full_runs = struct();

fprintf('Reloading runs with all 64 channels...\n');
for ri = 1:length(runs_to_load)
    r = runs_to_load(ri);
    filename = sprintf('%sS001R%02d.edf', data_folder, r);

    info       = edfinfo(filename);
    data_table = edfread(filename);
    fs         = info.NumSamples(1) / seconds(info.DataRecordDuration);

    % Unpack all numeric channels
    clean_data   = [];
    clean_labels = {};
    col_idx      = 1;
    for i = 1:width(data_table)
        colData = data_table{:, i};
        if iscell(colData)
            if isnumeric(colData{1})
                clean_data(:, col_idx) = vertcat(colData{:});
                clean_labels{col_idx}  = data_table.Properties.VariableNames{i};
                col_idx = col_idx + 1;
            end
        elseif isnumeric(colData)
            clean_data(:, col_idx) = colData;
            clean_labels{col_idx}  = data_table.Properties.VariableNames{i};
            col_idx = col_idx + 1;
        end
    end

    % Remove DC offset
    for c = 1:size(clean_data, 2)
        clean_data(:,c) = clean_data(:,c) - mean(clean_data(:,c));
    end

    full_runs(ri).data   = clean_data;
    full_runs(ri).labels = clean_labels;
    full_runs(ri).fs     = fs;
    full_runs(ri).label  = run_labels_short{ri};
    fprintf('  Run R%02d loaded: %d channels, %.0f sec\n', r, size(clean_data,2), size(clean_data,1)/fs);
end
fprintf('Done!\n');
% ============================================
% STEP 2: Electrode coordinates (all 64)
% ============================================

coord_map = {
    'Fp1_', -0.308,  0.950;  'Fpz_',  0.000,  0.990;
    'Fp2_',  0.308,  0.950;  'Af7_', -0.594,  0.804;
    'Af3_', -0.281,  0.770;  'Afz_',  0.000,  0.760;
    'Af4_',  0.281,  0.770;  'Af8_',  0.594,  0.804;
    'F7__', -0.808,  0.588;  'F5__', -0.587,  0.587;
    'F3__', -0.354,  0.612;  'F1__', -0.176,  0.628;
    'Fz__',  0.000,  0.640;  'F2__',  0.176,  0.628;
    'F4__',  0.354,  0.612;  'F6__',  0.587,  0.587;
    'F8__',  0.808,  0.588;  'Ft7_', -0.890,  0.375;
    'Fc5_', -0.661,  0.368;  'Fc3_', -0.414,  0.378;
    'Fc1_', -0.198,  0.385;  'Fcz_',  0.000,  0.390;
    'Fc2_',  0.198,  0.385;  'Fc4_',  0.414,  0.378;
    'Fc6_',  0.661,  0.368;  'Ft8_',  0.890,  0.375;
    'T9__', -1.000,  0.000;  'T7__', -0.950,  0.000;
    'C5__', -0.670,  0.000;  'C3__', -0.430,  0.000;
    'C1__', -0.210,  0.000;  'Cz__',  0.000,  0.000;
    'C2__',  0.210,  0.000;  'C4__',  0.430,  0.000;
    'C6__',  0.670,  0.000;  'T8__',  0.950,  0.000;
    'T10_',  1.000,  0.000;  'Tp7_', -0.890, -0.375;
    'Cp5_', -0.661, -0.368;  'Cp3_', -0.414, -0.378;
    'Cp1_', -0.198, -0.385;  'Cpz_',  0.000, -0.390;
    'Cp2_',  0.198, -0.385;  'Cp4_',  0.414, -0.378;
    'Cp6_',  0.661, -0.368;  'Tp8_',  0.890, -0.375;
    'P7__', -0.808, -0.588;  'P5__', -0.587, -0.587;
    'P3__', -0.354, -0.612;  'P1__', -0.176, -0.628;
    'Pz__',  0.000, -0.640;  'P2__',  0.176, -0.628;
    'P4__',  0.354, -0.612;  'P6__',  0.587, -0.587;
    'P8__',  0.808, -0.588;  'Po7_', -0.594, -0.804;
    'Po3_', -0.281, -0.770;  'Poz_',  0.000, -0.760;
    'Po4_',  0.281, -0.770;  'Po8_',  0.594, -0.804;
    'O1__', -0.308, -0.950;  'Oz__',  0.000, -0.990;
    'O2__',  0.308, -0.950;  'Iz__',  0.000, -1.000;
};
% ============================================
% STEP 3: Compute band power per channel per run
% (with artifact channels excluded)
% ============================================

n_runs_plot = length(runs_to_load);
n_coords    = size(coord_map, 1);

% Artifact channels to exclude from Beta maps
artifact_channels = {'T9__','T10_','Tp7_','Tp8_','T7__','T8__'};

% Storage: [n_coords x n_runs x 2 bands]
% Band 1 = Alpha, Band 2 = Beta
topo_power = nan(n_coords, n_runs_plot, 2);

band_defs = {8, 13; 13, 30};   % Alpha, Beta

fprintf('Computing band power for all runs...\n');
for ri = 1:n_runs_plot
    labels = full_runs(ri).labels;
    data   = full_runs(ri).data;
    fs_r   = full_runs(ri).fs;

    for b = 1:2
        Wn = [band_defs{b,1}, band_defs{b,2}] / (fs_r/2);
        [Bf, Af] = butter(4, Wn, 'bandpass');

        for k = 1:n_coords
            ch_name = coord_map{k,1};

            % Skip artifact channels
            if any(strcmp(artifact_channels, ch_name))
                topo_power(k, ri, b) = NaN;
                continue;
            end

            idx = find(strcmp(labels, ch_name));
            if ~isempty(idx)
                sig   = data(:, idx);
                sig_f = filtfilt(Bf, Af, sig);
                topo_power(k, ri, b) = mean(sig_f.^2);
            end
        end
    end
    fprintf('  Run %d/%d done: %s\n', ri, n_runs_plot, full_runs(ri).label);
end
fprintf('All power computed!\n');

% Quick sanity check
cz_idx = find(strcmp(coord_map(:,1), 'Cz__'));
fprintf('\nSanity check — Beta power at Cz:\n');
for ri = 1:n_runs_plot
    fprintf('  Run %d (%s): %.2f uV2\n', ri, full_runs(ri).label, topo_power(cz_idx,ri,2));
end
% ============================================
% STEP 4 UPDATED: Plot 4 x 6 topomap grid
% Delta, Theta, Alpha, Beta — all 6 conditions
% ============================================

band_defs  = {0.5, 4; 4, 8; 8, 13; 13, 30};
band_names = {'Delta (0.5-4 Hz)', 'Theta (4-8 Hz)', ...
              'Alpha (8-13 Hz)',   'Beta (13-30 Hz)'};
n_bands    = 4;

% ---- Recompute topo_power for 4 bands ----
artifact_channels = {'T9__','T10_','Tp7_','Tp8_','T7__','T8__'};
topo_power = nan(n_coords, n_runs_plot, n_bands);

fprintf('Computing 4-band power for all runs...\n');
for ri = 1:n_runs_plot
    labels = full_runs(ri).labels;
    data   = full_runs(ri).data;
    fs_r   = full_runs(ri).fs;

    for b = 1:n_bands
        Wn = [band_defs{b,1}, band_defs{b,2}] / (fs_r/2);
        [Bf, Af] = butter(4, Wn, 'bandpass');

        for k = 1:n_coords
            ch_name = coord_map{k,1};
            if any(strcmp(artifact_channels, ch_name))
                topo_power(k, ri, b) = NaN;
                continue;
            end
            idx = find(strcmp(labels, ch_name));
            if ~isempty(idx)
                sig_f = filtfilt(Bf, Af, data(:, idx));
                topo_power(k, ri, b) = mean(sig_f.^2);
            end
        end
    end
    fprintf('  Run %d/%d done: %s\n', ri, n_runs_plot, full_runs(ri).label);
end
fprintf('All 4 bands computed!\n');
% ---- Color limits per band (percentile-based) ----
clims = cell(n_bands, 1);
for b = 1:n_bands
    vals = topo_power(:,:,b);
    vals = vals(~isnan(vals));
    if b == 1   % Delta — tighten more, it dominates
        clims{b} = [prctile(vals, 20), prctile(vals, 80)];
    elseif b == 2  % Theta
        clims{b} = [prctile(vals, 10), prctile(vals, 90)];
    elseif b == 3  % Alpha
        clims{b} = [prctile(vals,  5), prctile(vals, 95)];
    else           % Beta
        clims{b} = [prctile(vals, 10), prctile(vals, 90)];
    end
    fprintf('Band %-20s color scale: [%.1f  %.1f] uV2\n', ...
        band_names{b}, clims{b}(1), clims{b}(2));
end
% ---- Interpolation setup ----
[gx, gy]  = meshgrid(linspace(-1.1,1.1,300), linspace(-1.1,1.1,300));
head_mask = sqrt(gx.^2 + gy.^2) > 1.0;
theta_h   = linspace(0, 2*pi, 200);
cx        = cell2mat(coord_map(:,2));
cy        = cell2mat(coord_map(:,3));

% Key electrodes to label
key_ch  = {'Cz__','O1__','O2__','C3__','C4__','Oz__','Fz__'};
key_lbl = {'Cz',  'O1',  'O2',  'C3',  'C4',  'Oz',  'Fz'};
% ---- Plot 4 x 6 grid ----
figure('Name','4-Band Topomap Comparison', ...
       'Position',[30 30 1400 880]);

for b = 1:n_bands
    for ri = 1:n_runs_plot

        subplot(n_bands, n_runs_plot, (b-1)*n_runs_plot + ri);

        % Valid channels only
        valid    = ~isnan(topo_power(:, ri, b));
        pow_vals = topo_power(valid, ri, b);
        cx_v     = cx(valid);
        cy_v     = cy(valid);

        % Interpolate
        grid_pow = griddata(cx_v, cy_v, pow_vals, gx, gy, 'v4');
        grid_pow(head_mask) = NaN;

        % Draw map
        imagesc(linspace(-1.1,1.1,300), linspace(-1.1,1.1,300), grid_pow);
        set(gca, 'YDir', 'normal');
        colormap(gca, 'jet');
        clim(clims{b});
        axis equal tight off;

        hold on;

        % Head outline
        plot(cos(theta_h), sin(theta_h), 'k-', 'LineWidth', 1.5);
        % Nose
        plot([-.08 0 .08], [1.0 1.10 1.0], 'k-', 'LineWidth', 1.5);
        % Left ear
        plot([-1.08 -1.13 -1.08], [-.05 0 .05], 'k-', 'LineWidth', 1.5);
        % Right ear
        plot([ 1.08  1.13  1.08], [-.05 0 .05], 'k-', 'LineWidth', 1.5);

        % Electrode dots
        scatter(cx_v, cy_v, 6, 'k', 'filled');

        % Key electrode labels
        for kk = 1:length(key_ch)
            kidx = find(strcmp(coord_map(:,1), key_ch{kk}));
            if ~isempty(kidx) && valid(kidx)
                text(cx(kidx)+0.05, cy(kidx), key_lbl{kk}, ...
                    'FontSize', 6, 'FontWeight', 'bold', ...
                    'Color', 'k', 'Interpreter', 'none');
            end
        end

        hold off;

        % Column title — top row only
        if b == 1
            title(full_runs(ri).label, 'FontSize', 7, ...
                'FontWeight', 'bold', 'Interpreter', 'none');
        end

        % Row label — first column only
        if ri == 1
            ylabel(band_names{b}, 'FontSize', 8, ...
                'FontWeight', 'bold', 'Interpreter', 'none');
        end

        % Colorbar — last column only
        if ri == n_runs_plot
            cb = colorbar;
            cb.Label.String = 'µV²';
            cb.FontSize = 7;
        end
    end
end

sgtitle('EEG Topographic Comparison — 4 Bands × 6 Conditions , delta thetha alpha beta', ...
    'FontSize', 13, 'FontWeight', 'bold', 'Interpreter', 'none');

% ============================================
% MOTOR IMAGERY CLASSIFIER
% Goal: classify Left fist (T1) vs Right fist (T2)
% Features: Beta power at C3 and C4
% Method: Linear Discriminant Analysis (LDA)
% ============================================

% --- Step 1: Extract epochs from runs 3, 7, 11 (real movement) ---
% These runs contain T1 (left fist) and T2 (right fist) events

real_runs_idx = [3, 7, 11];
epoch_sec     = 3;       % 3-second epochs after event onset
epoch_samp    = round(epoch_sec * fs);
prestim_sec   = 0.5;     % 0.5s before onset to stabilize filter
prestim_samp  = round(prestim_sec * fs);

% Channel indices in target_channels
c3_idx = find(strcmp(target_channels, 'C3__'));
c4_idx = find(strcmp(target_channels, 'C4__'));

% Storage
features = [];   % [n_trials x 2] — C3 beta, C4 beta
labels   = [];   % [n_trials x 1] — 1=left, 2=right

% Beta filter
Wn_beta = [13 30] / (fs/2);
[Bf, Af] = butter(4, Wn_beta, 'bandpass');

fprintf('=== Extracting epochs from motor runs ===\n');

for ri = 1:length(real_runs_idx)
    r        = real_runs_idx(ri);
    run_data = all_runs(r).data;   % samples x 7 channels

    % Re-read annotations for this run
    filename_r = sprintf('%sS001R%02d.edf', data_folder, r);
    [~, annot] = edfread(filename_r);

    evt_times  = annot.Onset;
    evt_labels = annot.Annotations;

    n_samples = size(run_data, 1);

    for e = 1:length(evt_labels)
        label_str = evt_labels{e};
        if iscell(label_str), label_str = label_str{1}; end

        % Only take T1 and T2 events
        if ~ismember(label_str, {'T1','T2'}), continue; end

        onset = round(seconds(evt_times(e)) * fs) + 1;
        start_idx = onset - prestim_samp;
        end_idx   = onset + epoch_samp - 1;

        % Skip if epoch goes out of bounds
        if start_idx < 1 || end_idx > n_samples, continue; end

        % Extract and filter C3, C4
        sig_c3 = run_data(start_idx:end_idx, c3_idx);
        sig_c4 = run_data(start_idx:end_idx, c4_idx);

        sig_c3_f = filtfilt(Bf, Af, sig_c3);
        sig_c4_f = filtfilt(Bf, Af, sig_c4);

        % Use only post-stimulus part for features
        post = prestim_samp+1 : length(sig_c3_f);
        feat_c3 = mean(sig_c3_f(post).^2);   % Beta power C3
        feat_c4 = mean(sig_c4_f(post).^2);   % Beta power C4

        features(end+1, :) = [feat_c3, feat_c4];

        if strcmp(label_str, 'T1')
            labels(end+1) = 1;   % Left fist
        else
            labels(end+1) = 2;   % Right fist
        end
    end

    fprintf('  Run R%02d: %d epochs extracted\n', r, ...
        sum(labels == 1) + sum(labels == 2));
end

labels = labels';
fprintf('\nTotal: %d left fist, %d right fist epochs\n', ...
    sum(labels==1), sum(labels==2));
% --- Step 2: Add ratio feature (C3/C4 lateralization) ---
% This is the most discriminative feature for left vs right hand

features(:,3) = log(features(:,1) ./ features(:,2));   % Log ratio

feature_names = {'C3 Beta Power', 'C4 Beta Power', 'C3/C4 Log Ratio'};

fprintf('\n=== Feature Summary ===\n');
fprintf('%-20s %-12s %-12s\n','Feature','Left fist','Right fist');
fprintf('%s\n', repmat('-',1,46));
for f = 1:3
    fprintf('%-20s %-12.2f %-12.2f\n', feature_names{f}, ...
        mean(features(labels==1, f)), ...
        mean(features(labels==2, f)));
end
% --- Step 3: Train LDA classifier with cross-validation ---
% Use Leave-One-Out Cross-Validation (LOOCV) for small datasets

n_trials  = length(labels);
predicted = zeros(n_trials, 1);

fprintf('\n=== Training LDA Classifier (LOOCV) ===\n');

for i = 1:n_trials
    % Split: leave trial i out for testing
    train_idx = setdiff(1:n_trials, i);
    test_idx  = i;

    X_train = features(train_idx, :);
    y_train = labels(train_idx);
    X_test  = features(test_idx, :);

    % Train LDA
    mdl = fitcdiscr(X_train, y_train, 'DiscrimType', 'linear');

    % Predict
    predicted(i) = predict(mdl, X_test);
end

% --- Results ---
accuracy = sum(predicted == labels) / n_trials * 100;
chance   = 50.0;   % Binary classification baseline

fprintf('\n=== Classification Results ===\n');
fprintf('Total trials:     %d\n', n_trials);
fprintf('Correct:          %d\n', sum(predicted == labels));
fprintf('Wrong:            %d\n', sum(predicted ~= labels));
fprintf('Accuracy:         %.1f%%\n', accuracy);
fprintf('Chance level:     %.1f%%\n', chance);
fprintf('Above chance:     %+.1f%%\n', accuracy - chance);

% Confusion matrix
fprintf('\n=== Confusion Matrix ===\n');
fprintf('%-15s %-15s %-15s\n','','Pred: Left','Pred: Right');
fprintf('%-15s %-15d %-15d\n','True: Left', ...
    sum(predicted==1 & labels==1), sum(predicted==2 & labels==1));
fprintf('%-15s %-15d %-15d\n','True: Right', ...
    sum(predicted==1 & labels==2), sum(predicted==2 & labels==2));
% --- Step 4: Visualize everything ---

figure('Name','Motor Imagery BCI Classifier','Position',[50 50 1200 500]);

% --- Plot 1: Feature scatter plot ---
subplot(1,3,1);
left_idx  = labels == 1;
right_idx = labels == 2;

scatter(features(left_idx,1),  features(left_idx,2),  60, ...
    'b', 'filled', 'MarkerFaceAlpha', 0.6); hold on;
scatter(features(right_idx,1), features(right_idx,2), 60, ...
    'r', 'filled', 'MarkerFaceAlpha', 0.6);

% Plot class means
plot(mean(features(left_idx,1)),  mean(features(left_idx,2)), ...
    'bx', 'MarkerSize', 14, 'LineWidth', 3);
plot(mean(features(right_idx,1)), mean(features(right_idx,2)), ...
    'rx', 'MarkerSize', 14, 'LineWidth', 3);

legend({'Left fist','Right fist','Left mean','Right mean'}, ...
    'Location','best');
xlabel('C3 Beta Power (µV²)');
ylabel('C4 Beta Power (µV²)');
title('Feature Space: C3 vs C4','Interpreter','none');
grid on; hold off;

% --- Plot 2: Log ratio distribution ---
subplot(1,3,2);
left_ratio  = features(left_idx,  3);
right_ratio = features(right_idx, 3);

edges = linspace(min(features(:,3))-0.5, max(features(:,3))+0.5, 20);
histogram(left_ratio,  edges, 'FaceColor','b','FaceAlpha',0.5); hold on;
histogram(right_ratio, edges, 'FaceColor','r','FaceAlpha',0.5);

xline(mean(left_ratio),  '--b', 'Left mean',  'Interpreter','none','LineWidth',2);
xline(mean(right_ratio), '--r', 'Right mean', 'Interpreter','none','LineWidth',2);
xline(0, '-k', 'Decision boundary', 'Interpreter','none');

legend({'Left fist','Right fist'},'Location','best');
xlabel('log(C3/C4 Beta Power)');
ylabel('Count');
title('Lateralization Index','Interpreter','none');
grid on; hold off;

% --- Plot 3: Accuracy summary ---
subplot(1,3,3);
bar_data = [chance, accuracy];
b = bar(bar_data, 0.5);
b.FaceColor = 'flat';
b.CData = [0.7 0.7 0.7; 0.2 0.7 0.3];

xticklabels({'Chance (50%)','Our Classifier'});
ylabel('Accuracy (%)');
ylim([0 100]);
yline(50,'--k','Chance','Interpreter','none');
title('Classification Accuracy','Interpreter','none');

% Add accuracy label on bar
text(2, accuracy+3, sprintf('%.1f%%', accuracy), ...
    'HorizontalAlignment','center','FontSize',14,'FontWeight','bold');

grid on;

sgtitle(sprintf('BCI Motor Imagery Classifier — Left vs Right Fist (N=%d trials)', ...
    n_trials), 'Interpreter','none');
