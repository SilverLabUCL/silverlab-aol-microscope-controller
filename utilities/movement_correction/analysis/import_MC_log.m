
% Example 1 : simple loading of MC log and Encoder
% import_MC_log("D:\2018-09-12\2018-09-12\experiment_4\19-07-21\2018_9_12-19_9_47_MC_log_timed_image_repeat_10.txt","D:\2018-09-12\2018-09-12\experiment_4\19-07-21\2018_9_12-19_10_4_wheelspeed_46.txt");
%
% Example 2 : plot all MC log in a folder
% XCorr = {};
% YCorr = {};
% ZCorr = {};
% data_folder = 'D:\2018-09-12\2018-09-12\experiment_4\19-07-21\';
% files = dir([data_folder,'*MC_log_timed_image_repeat_*']);
% for el = 1:numel(files)
%     [XCorr{el},YCorr{el},ZCorr{el}] = import_MC_log([data_folder,files(el).name]);
%     pause(0.5);
%     gcf();cla();
% end
% %then plot XCorr

function [X_corr, Y_corr, Z_corr, X_diff, Y_diff, Z_diff, MCTime, initial_time] = import_MC_log(MC_log_path, initial_time, rendering)
    %% Initialize variables.
    if isempty(MC_log_path)
        MC_log_path = '';
    end
    if nargin < 2 || isempty(initial_time)
        initial_time = [];
    end
    if nargin < 3 || isempty(rendering)
        rendering = true;
    end

    %% MC
    timescale = [];
    if ~isempty(MC_log_path)
    
        delimiter = ' :';
        formatSpec = '%f%f%f%f%f%f%f%f%f%[^\n\r]';
        fileID = fopen(MC_log_path,'r');
        data = textscan(fileID, formatSpec, 'Delimiter', delimiter, 'MultipleDelimsAsOne', false, 'TextType', 'string', 'EmptyValue', NaN,  'ReturnOnError', false);

        %% Close the text file.
        fclose(fileID);

        %% Reformat data, remove duplicated values.
        % Duplicated values happens if you read the capi too fast
        data = cell2mat(data(1:9));
        dataArray_no_duplicates = nan(size(data));
        counter = 1;
        dataArray_no_duplicates(1,:) = data(1,:);
        for line = 2:size(data,1)
            if ~all(dataArray_no_duplicates(counter,4:end) == data(line,4:end))
                counter = counter + 1;
                dataArray_no_duplicates(counter,:) = data(line,:);                
            end
        end
        dataArray_no_duplicates = dataArray_no_duplicates(1:counter,:);

        %% Get the timescale right
        ms = mod(dataArray_no_duplicates(:,3),1);
        dataArray_no_duplicates(:,3) = dataArray_no_duplicates(:,3) - ms;
        time = dataArray_no_duplicates(:,1)*1000*60*60 + dataArray_no_duplicates(:,2)*1000*60 + dataArray_no_duplicates(:,3)*1000 + ms*1000;
        if isempty(initial_time)
            initial_time = time(1);
        end
        timescale = (time-initial_time)/1000; % in seconds

        %% Allocate imported array to column variable names
        if isnan(data(1,8)) %% X Y correction only
            X_corr = dataArray_no_duplicates(:, 4);
            Y_corr = dataArray_no_duplicates(:, 5);
            Z_corr = NaN(size(dataArray_no_duplicates(:, 5)));
            X_diff = dataArray_no_duplicates(:, 6);
            Y_diff = dataArray_no_duplicates(:, 7);
            Z_diff = NaN(size(dataArray_no_duplicates(:, 5)));
            MCTime = timescale;
            
        else %% X Y Z correction
            X_corr = dataArray_no_duplicates(:, 4);
            Y_corr = dataArray_no_duplicates(:, 5);
            Z_corr = dataArray_no_duplicates(:, 6);
            X_diff = dataArray_no_duplicates(:, 7);
            Y_diff = dataArray_no_duplicates(:, 8);
            Z_diff = dataArray_no_duplicates(:, 9);
            MCTime = timescale;
        end
    else
        X_corr = [];
        Y_corr = [];
        Z_corr = [];
        X_diff = [];
        Y_diff = [];
        Z_diff = [];
    end

    if rendering
        figure(1052);clf();whitebg('w')

        if ~isempty(MC_log_path)
            subplot(n_lines,3,1); hold on;
            plot(timescale,X_corr,'r');
            subplot(n_lines,3,2); hold on;
            plot(timescale,Y_corr,'b');
            subplot(n_lines,3,3); hold on;
            plot(timescale,Z_corr,'k');
            subplot(n_lines,3,4); hold on;
            plot(timescale,X_diff,'r');
            subplot(n_lines,3,5); hold on;
            plot(timescale,Y_diff,'b');
            subplot(n_lines,3,6); hold on;
            plot(timescale,Z_diff,'k');
        end
    end
end


