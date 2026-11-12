% ============================================
% EEG SIGNAL PROCESSING — MAIN SCRIPT
% Subject S001, Run R01 — Single recording
% ============================================

%% 1. LOAD DATA
filename = 'S001R01.edf';
info     = edfinfo(filename);
fs       = info.NumSamples(1) / seconds(info.DataRecordDuration);
data_table = edfread(filename);

clean_data = []; clean_labels = {}; col_idx = 1;
for i = 1:width(data_table)
    colData = data_table{:,i};
    if iscell(colData)
        if isnumeric(colData{1})
            clean_data(:,col_idx) = vertcat(colData{:});
            clean_labels{col_idx} = data_table.Properties.VariableNames{i};
            col_idx = col_idx+1;
        end
    elseif isnumeric(colData)
        clean_data(:,col_idx) = colData;
        clean_labels{col_idx} = data_table.Properties.VariableNames{i};
        col_idx = col_idx+1;
    end
end

n_samples = size(clean_data,1);
t = (0:n_samples-1) / fs;

fprintf('=== EEG File Info ===\n')
fprintf('Sampling frequency: %.2f Hz\n', fs)
fprintf('Duration: %.2f seconds\n', t(end))
fprintf('Channels: %d\n', size(clean_data,2))

%% 2. VISUALIZE RAW SIGNAL
figure('Name','EEG Stacked View');
n_display = min(8, size(clean_data,2));
offset = 150;
hold on;
for i = 1:n_display
    signal = clean_data(:,i) - mean(clean_data(:,i));
    plot(t, signal + (i-1)*offset);
end
hold off;
title('Stacked EEG Signals (DC Offset Removed)');
xlabel('Time (seconds)'); ylabel('Channels');
yticks((0:n_display-1)*offset);
yticklabels(clean_labels(1:n_display));
grid on; axis tight;

%% 3. SIGNAL CHARACTERISTICS
fprintf('\n=== Signal Characteristics ===\n')
fprintf('%-10s %-10s %-10s %-10s %-10s\n','Channel','Mean','Std','Max','Min');
fprintf('%s\n', repmat('-',1,55));
for i = 1:size(clean_data,2)
    sig = clean_data(:,i);
    fprintf('%-10s %-10.2f %-10.2f %-10.2f %-10.2f\n', ...
        clean_labels{i}, mean(sig), std(sig), max(sig), min(sig));
end

%% 4. FFT SPECTRUM
sig_cz = clean_data(:, find(strcmp(clean_labels,'Cz__'))) - ...
         mean(clean_data(:, find(strcmp(clean_labels,'Cz__'))));

N = length(sig_cz);
f_axis = (0:N-1) * (fs/N);
Y = abs(fft(sig_cz)) / N;
idx_60 = f_axis <= 60;

figure('Name','FFT Spectrum');
plot(f_axis(idx_60), Y(idx_60));
xlabel('Frequency (Hz)'); ylabel('Amplitude');
title('FFT Spectrum — Channel Cz', 'Interpreter','none');
xline(4,'--b','Theta','Interpreter','none');
xline(8,'--g','Alpha','Interpreter','none');
xline(13,'--r','Beta','Interpreter','none');
xline(30,'--m','Gamma','Interpreter','none');
grid on;

%% 5. BAND FILTERING
bands = {0.5,4,'Delta'; 4,8,'Theta'; 8,13,'Alpha'; 13,30,'Beta'; 30,45,'Gamma'};
filtered = cell(5,1);
band_powers = zeros(1,5);

for b = 1:5
    Wn = [bands{b,1}, bands{b,2}] / (fs/2);
    [B,A] = butter(4, Wn, 'bandpass');
    filtered{b} = filtfilt(B, A, sig_cz);
    band_powers(b) = mean(filtered{b}.^2);
end

% Band decomposition plot (first 5 seconds)
idx5 = t <= 5;
figure('Name','Band Decomposition');
subplot(6,1,1); plot(t(idx5), sig_cz(idx5));
title('Original — Cz','Interpreter','none'); ylabel('µV'); grid on;
colors = {'b','c','g','r','m'};
for b = 1:5
    subplot(6,1,b+1);
    plot(t(idx5), filtered{b}(idx5), colors{b});
    title([bands{b,3},' (',num2str(bands{b,1}),'–',num2str(bands{b,2}),' Hz)']);
    ylabel('µV'); grid on;
end
xlabel('Time (s)');
sgtitle('EEG Band Decomposition — Channel Cz','Interpreter','none');

% Band power bar chart
fprintf('\n=== Band Power (Cz) ===\n')
for b = 1:5
    fprintf('%-10s %.4f µV²\n', bands{b,3}, band_powers(b));
end

figure('Name','Band Power');
bar(band_powers);
xticks(1:5); xticklabels({bands{:,3}});
ylabel('Mean Power (µV²)');
title('Band Power — Channel Cz','Interpreter','none');
grid on;

%% 6. SPECTROGRAM
window  = round(1*fs);
overlap = round(window*0.75);
nfft    = 1024;

ch_fp1 = find(strcmp(clean_labels,'Fp1_'));
sig_fp1 = clean_data(:,ch_fp1) - mean(clean_data(:,ch_fp1));

figure('Name','Spectrogram Comparison');
subplot(2,1,1);
spectrogram(sig_fp1, window, overlap, nfft, fs, 'yaxis');
ylim([0 50]); colormap('jet');
title('Fp1 — Frontal (artifact-heavy)','Interpreter','none');

subplot(2,1,2);
spectrogram(sig_cz, window, overlap, nfft, fs, 'yaxis');
ylim([0 50]); colormap('jet');
title('Cz — Central (clean)','Interpreter','none');
xlabel('Time (seconds)');
%% 7. ARTIFACT REMOVAL
threshold = 100;
sig_fp1_clean = sig_fp1;
artifact_idx = abs(sig_fp1) > threshold;

sig_fp1_clean(artifact_idx) = NaN;
t_vec = 1:length(sig_fp1_clean);
valid = ~isnan(sig_fp1_clean);
sig_fp1_clean = interp1(t_vec(valid), sig_fp1_clean(valid), t_vec, 'linear','extrap');

fprintf('\n=== Artifact Removal (Fp1) ===\n')
fprintf('Artifacts detected: %d / %d (%.1f%%)\n', ...
    sum(artifact_idx), length(sig_fp1), 100*sum(artifact_idx)/length(sig_fp1));
fprintf('Std before: %.2f µV  →  after: %.2f µV\n', std(sig_fp1), std(sig_fp1_clean));

t_zoom = t <= 10;
figure('Name','Artifact Removal');
subplot(2,1,1); plot(t(t_zoom), sig_fp1(t_zoom));
yline(threshold,'--r'); yline(-threshold,'--r');
title('Fp1 — Before Cleaning','Interpreter','none');
ylabel('Amplitude (µV)'); grid on;

subplot(2,1,2); plot(t(t_zoom), sig_fp1_clean(t_zoom),'b');
title('Fp1 — After Cleaning','Interpreter','none');
ylabel('Amplitude (µV)'); xlabel('Time (s)'); grid on;
%% 8. TOPOGRAPHIC MAPS (5 bands)
coord_map = {
    'Fp1_',-0.308,0.950; 'Fpz_',0.000,0.990; 'Fp2_',0.308,0.950;
    'Af7_',-0.594,0.804; 'Af3_',-0.281,0.770; 'Afz_',0.000,0.760;
    'Af4_',0.281,0.770;  'Af8_',0.594,0.804;
    'F7__',-0.808,0.588; 'F5__',-0.587,0.587; 'F3__',-0.354,0.612;
    'F1__',-0.176,0.628; 'Fz__',0.000,0.640;  'F2__',0.176,0.628;
    'F4__',0.354,0.612;  'F6__',0.587,0.587;  'F8__',0.808,0.588;
    'Ft7_',-0.890,0.375; 'Fc5_',-0.661,0.368; 'Fc3_',-0.414,0.378;
    'Fc1_',-0.198,0.385; 'Fcz_',0.000,0.390;  'Fc2_',0.198,0.385;
    'Fc4_',0.414,0.378;  'Fc6_',0.661,0.368;  'Ft8_',0.890,0.375;
    'T9__',-1.000,0.000; 'T7__',-0.950,0.000; 'C5__',-0.670,0.000;
    'C3__',-0.430,0.000; 'C1__',-0.210,0.000; 'Cz__',0.000,0.000;
    'C2__',0.210,0.000;  'C4__',0.430,0.000;  'C6__',0.670,0.000;
    'T8__',0.950,0.000;  'T10_',1.000,0.000;  'Tp7_',-0.890,-0.375;
    'Cp5_',-0.661,-0.368;'Cp3_',-0.414,-0.378;'Cp1_',-0.198,-0.385;
    'Cpz_',0.000,-0.390; 'Cp2_',0.198,-0.385; 'Cp4_',0.414,-0.378;
    'Cp6_',0.661,-0.368; 'Tp8_',0.890,-0.375;
    'P7__',-0.808,-0.588;'P5__',-0.587,-0.587;'P3__',-0.354,-0.612;
    'P1__',-0.176,-0.628;'Pz__',0.000,-0.640; 'P2__',0.176,-0.628;
    'P4__',0.354,-0.612; 'P6__',0.587,-0.587; 'P8__',0.808,-0.588;
    'Po7_',-0.594,-0.804;'Po3_',-0.281,-0.770;'Poz_',0.000,-0.760;
    'Po4_',0.281,-0.770; 'Po8_',0.594,-0.804;
    'O1__',-0.308,-0.950;'Oz__',0.000,-0.990; 'O2__',0.308,-0.950;
    'Iz__',0.000,-1.000;
};

n_coords = size(coord_map,1);
n_chans  = size(clean_data,2);
elec_x   = zeros(n_coords,1);
elec_y   = zeros(n_coords,1);
elec_pow = zeros(n_coords,5);

for k = 1:n_coords
    elec_x(k) = coord_map{k,2};
    elec_y(k) = coord_map{k,3};
    idx = find(strcmp(clean_labels, coord_map{k,1}));
    if ~isempty(idx)
        elec_pow(k,:) = band_powers;   % reuse from section 5
        % recompute per channel
        for b = 1:5
            Wn = [bands{b,1},bands{b,2}]/(fs/2);
            [B,A] = butter(4,Wn,'bandpass');
            sf = filtfilt(B,A, clean_data(:,idx)-mean(clean_data(:,idx)));
            elec_pow(k,b) = mean(sf.^2);
        end
    end
end

[gx,gy] = meshgrid(linspace(-1.1,1.1,300), linspace(-1.1,1.1,300));
hmask   = sqrt(gx.^2+gy.^2) > 1.0;
theta_h = linspace(0,2*pi,200);

figure('Name','Topographic Maps','Position',[100 100 1200 280]);
for b = 1:5
    subplot(1,5,b);
    gp = griddata(elec_x, elec_y, elec_pow(:,b), gx, gy, 'v4');
    gp(hmask) = NaN;
    imagesc(linspace(-1.1,1.1,300), linspace(-1.1,1.1,300), gp);
    set(gca,'YDir','normal'); colormap(jet); colorbar;
    axis equal tight off; hold on;
    plot(cos(theta_h), sin(theta_h), 'k-','LineWidth',1.5);
    plot([-.1 0 .1],[1.0 1.12 1.0],'k-','LineWidth',1.5);
    plot([-1.08 -1.12 -1.08],[-0.07 0 0.07],'k-','LineWidth',1.5);
    plot([ 1.08  1.12  1.08],[-0.07 0 0.07],'k-','LineWidth',1.5);
    scatter(elec_x, elec_y, 8,'k','filled');
    title([bands{b,3},' (',num2str(bands{b,1}),'–',num2str(bands{b,2}),' Hz)'], ...
        'Interpreter','none'); hold off;
end
sgtitle('EEG Topographic Maps — Band Power','Interpreter','none');

%% 9. BRAIN CONNECTIVITY (Alpha coherence)
fprintf('\nComputing Alpha coherence matrix...\n');
Wn = [8 13]/(fs/2);
[Bf,Af] = butter(4,Wn,'bandpass');
coh_matrix = zeros(n_chans,n_chans);

for i = 1:n_chans
    for j = i+1:n_chans
        Si = fft(filtfilt(Bf,Af, clean_data(:,i)-mean(clean_data(:,i))));
        Sj = fft(filtfilt(Bf,Af, clean_data(:,j)-mean(clean_data(:,j))));
        coh = abs(sum(Si.*conj(Sj)))^2 / (sum(abs(Si).^2)*sum(abs(Sj).^2));
        coh_matrix(i,j) = coh;
        coh_matrix(j,i) = coh;
    end
end

% Connectivity map
cx = zeros(n_chans,1); cy = zeros(n_chans,1);
for k = 1:n_chans
    idx = find(strcmp(coord_map(:,1), clean_labels{k}));
    if ~isempty(idx)
        cx(k) = coord_map{idx,2};
        cy(k) = coord_map{idx,3};
    end
end

threshold_coh = 0.92;
figure('Name','Brain Connectivity','Position',[100 100 700 750]);
hold on;
plot(cos(theta_h), sin(theta_h),'k-','LineWidth',2);
plot([-.1 0 .1],[1.0 1.13 1.0],'k-','LineWidth',2);
plot([-1.08 -1.12 -1.08],[-0.07 0 0.07],'k-','LineWidth',2);
plot([ 1.08  1.12  1.08],[-0.07 0 0.07],'k-','LineWidth',2);
max_coh = max(coh_matrix(:));
for i = 1:n_chans
    for j = i+1:n_chans
        if coh_matrix(i,j) >= threshold_coh
            lw = 1 + 4*(coh_matrix(i,j)-threshold_coh)/(max_coh-threshold_coh);
            al = 0.3 + 0.7*(coh_matrix(i,j)-threshold_coh)/(max_coh-threshold_coh);
            line([cx(i) cx(j)],[cy(i) cy(j)],'Color',[1 0.2 0.2 al],'LineWidth',lw);
        end
    end
end
scatter(cx, cy, 40,'k','filled');
axis equal off;
title('Alpha Connectivity (coherence > 0.92)','Interpreter','none');
hold off;

%% 10. BRAIN STATE CLASSIFIER
epoch_sec  = 1;
epoch_samp = round(epoch_sec*fs);
n_epochs   = floor(n_samples/epoch_samp);
epoch_power = zeros(n_epochs,5);

for b = 1:5
    Wn = [bands{b,1},bands{b,2}]/(fs/2);
    [B,A] = butter(4,Wn,'bandpass');
    sf = filtfilt(B,A,sig_cz);
    for e = 1:n_epochs
        idx = (e-1)*epoch_samp+1 : e*epoch_samp;
        epoch_power(e,b) = mean(sf(idx).^2);
    end
end

states = cell(n_epochs,1);
state_color = zeros(n_epochs,3);
for e = 1:n_epochs
    rel = epoch_power(e,:) / sum(epoch_power(e,:));
    if     rel(1) > 0.60,                              states{e}='Deep Rest';      state_color(e,:)=[0.2 0.2 0.8];
    elseif rel(3) > 0.20 && rel(3) > rel(4)*1.5,      states{e}='Relaxed';        state_color(e,:)=[0.2 0.7 0.2];
    elseif rel(4) > 0.20 && rel(4) > rel(3),          states{e}='Alert';          state_color(e,:)=[0.9 0.5 0.1];
    elseif rel(2) > 0.25,                              states{e}='Drowsy';         state_color(e,:)=[0.6 0.2 0.8];
    else                                               states{e}='Mixed';          state_color(e,:)=[0.5 0.5 0.5];
    end
end

t_ep = (0:n_epochs-1)*epoch_sec;
figure('Name','Brain State Classifier','Position',[100 100 1100 500]);
subplot(2,1,1);
area(t_ep, epoch_power./sum(epoch_power,2),'LineWidth',0.5);
legend({bands{:,3}},'Location','eastoutside','Interpreter','none');
ylabel('Relative Power');
title('Band Power per Epoch (Cz)','Interpreter','none');
grid on; xlim([0 t_ep(end)]);

subplot(2,1,2); hold on;
for e = 1:n_epochs
    fill([t_ep(e) t_ep(e)+1 t_ep(e)+1 t_ep(e)],[0 0 1 1], ...
        state_color(e,:),'EdgeColor','none','FaceAlpha',0.85);
end
hold off;
xlim([0 t_ep(end)]); ylim([0 1]);
xlabel('Time (seconds)'); yticks([]);
title('Classified Brain States','Interpreter','none');

fprintf('\n=== Brain State Summary ===\n')
for s = 1:length(unique(states))
    u = unique(states); st = u{s};
    fprintf('%-15s %d seconds\n', st, sum(strcmp(states,st)));
end

%% 11. INTERACTIVE VIEWER
eeg_viewer(clean_data, clean_labels, fs);