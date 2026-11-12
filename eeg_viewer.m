% ============================================
% INTERACTIVE EEG VIEWER
% ============================================

function eeg_viewer(clean_data, clean_labels, fs)
% Usage: eeg_viewer(clean_data, clean_labels, fs)

    % --- Settings ---
    n_channels  = size(clean_data, 2);
    n_samples   = size(clean_data, 1);
    t           = (0:n_samples-1) / fs;

    win_sec     = 10;        % seconds visible at once
    win_samp    = round(win_sec * fs);
    n_display   = 8;         % channels visible at once
    offset      = 150;       % µV spacing
    ch_start    = 1;         % first channel shown
    t_start     = 1;         % first sample shown

    % --- Build figure ---
    fig = figure('Name', 'Interactive EEG Viewer', ...
                 'Position', [50 50 1100 650], ...
                 'KeyPressFcn', @key_handler);

    % --- Draw initial plot ---
    ax = axes('Parent', fig, 'Position', [0.08 0.18 0.88 0.76]);
    draw_eeg();

    % --- Scrollbar (time) ---
    uicontrol('Style', 'slider', ...
        'Units', 'normalized', ...
        'Position', [0.08 0.07 0.88 0.04], ...
        'Min', 1, 'Max', n_samples - win_samp, ...
        'Value', 1, 'SliderStep', [win_samp/(n_samples-win_samp), ...
                                    win_samp*5/(n_samples-win_samp)], ...
        'Callback', @time_slider);

    % --- Channel scroll buttons ---
    uicontrol('Style', 'pushbutton', 'String', '▲ Channels', ...
        'Units', 'normalized', 'Position', [0.08 0.01 0.12 0.05], ...
        'Callback', @(~,~) ch_scroll(-1));

    uicontrol('Style', 'pushbutton', 'String', '▼ Channels', ...
        'Units', 'normalized', 'Position', [0.21 0.01 0.12 0.05], ...
        'Callback', @(~,~) ch_scroll(1));

    % --- Zoom buttons ---
    uicontrol('Style', 'pushbutton', 'String', '+ Zoom', ...
        'Units', 'normalized', 'Position', [0.40 0.01 0.10 0.05], ...
        'Callback', @(~,~) zoom_time(-5));

    uicontrol('Style', 'pushbutton', 'String', '- Zoom', ...
        'Units', 'normalized', 'Position', [0.51 0.01 0.10 0.05], ...
        'Callback', @(~,~) zoom_time(5));

    % --- Amplitude buttons ---
    uicontrol('Style', 'pushbutton', 'String', '↑ Amp', ...
        'Units', 'normalized', 'Position', [0.68 0.01 0.09 0.05], ...
        'Callback', @(~,~) amp_scale(-30));

    uicontrol('Style', 'pushbutton', 'String', '↓ Amp', ...
        'Units', 'normalized', 'Position', [0.78 0.01 0.09 0.05], ...
        'Callback', @(~,~) amp_scale(30));

    % ---- Nested Functions ----

    function draw_eeg()
        cla(ax); hold(ax, 'on');
        idx = t_start : min(t_start + win_samp - 1, n_samples);
        t_win = t(idx);
        ch_end = min(ch_start + n_display - 1, n_channels);
        colors = lines(n_display);
        for i = 1:(ch_end - ch_start + 1)
            ch = ch_start + i - 1;
            sig = clean_data(idx, ch) - mean(clean_data(idx, ch));
            plot(ax, t_win, sig + (i-1)*offset, ...
                'Color', colors(i,:), 'LineWidth', 0.6);
        end
        yticks(ax, (0:n_display-1)*offset);
        yticklabels(ax, clean_labels(ch_start:ch_end));
        xlim(ax, [t_win(1) t_win(end)]);
        ylim(ax, [-offset, n_display*offset]);
        xlabel(ax, 'Time (s)');
        title(ax, sprintf('EEG Viewer — %.1f to %.1f s | Channels %d–%d', ...
            t_win(1), t_win(end), ch_start, ch_end), ...
            'Interpreter', 'none');
        grid(ax, 'on'); hold(ax, 'off');
    end

    function time_slider(src, ~)
        t_start = round(src.Value);
        draw_eeg();
    end

    function ch_scroll(dir)
        ch_start = max(1, min(ch_start + dir*n_display, ...
                              n_channels - n_display + 1));
        draw_eeg();
    end

    function zoom_time(delta)
        win_sec  = max(5, min(win_sec + delta, 60));
        win_samp = round(win_sec * fs);
        draw_eeg();
    end

    function amp_scale(delta)
        offset = max(50, offset + delta);
        draw_eeg();
    end

    function key_handler(~, e)
        switch e.Key
            case 'rightarrow', t_start = min(t_start + win_samp, ...
                                   n_samples - win_samp); draw_eeg();
            case 'leftarrow',  t_start = max(1, t_start - win_samp); draw_eeg();
            case 'uparrow',    ch_scroll(-1);
            case 'downarrow',  ch_scroll(1);
        end
    end

end