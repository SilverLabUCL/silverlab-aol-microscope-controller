%% Read movement correction log
% -------------------------------------------------------------------------
% Syntax: 
%   [mc_log, concatenated_MC_displacement_um, concatenated_Time,
%    mc_pixel_size, failure_suspicion] = 
%           load_mc_log(source, repeats, rendering, remove_inter_trial)
%
% -------------------------------------------------------------------------
% Inputs:
%   source(STR Path or STRUCT):
%                                   The path to a given data folder, or a
%                                   mc_log object
%
%   repeats(1 * N INT): - Optional - Default is all trials:
%                                   If provided, only a subset of the
%                                   encoder data will be returned
%
%   rendering(BOOL): - Optional - Default is true:
%                                   If true, the X-Y-Z correctiosn and
%                                   errors are displayed.
%
%   remove_inter_trial(BOOL): - Optional - Default is true:
%                                   If true, the interval between trials is
%                                   removed, otherwise everything is
%                                   concatenated
% -------------------------------------------------------------------------
% Outputs: 
% mc_log (STRUCT) :
%                                   structure ouptut contains the following
%                                   fields in pixels:
%                                   - X_corr
%                                   - Y_corr
%                                   - Z_corr 
%                                   - X_diff
%                                   - Y_diff
%                                   - Z_diff 
%                                   - timescale
%                                   to contatenate axes :
%                                   log = structfun(@(x) [x{:}], log,...
%                                           'UniformOutput', false)
%
% concatenated_MC_displacement_um(1 * T FLOAT):
%                                   An array of all the total displacement
%                                   in um. The output is only provided if
%                                   the header can be found in the same
%                                   folder. 
%
% concatenated_time(1 * T FLOAT):
%                                   An array of time points using system
%                                   time when reading buffer values.
%
% mc_pixel_size(1 * 2 FLOAT):
%                                   X and Y MC pixel size. Use it to scale
%                                   log into um.
%
% failure_suspicion(INT) :
%                                   Some extra check are done on the data
%                                   structure to detect abnormalities.
%                                   0 for no detected issue
%                                   1 for suspected MC loss
%                                   2 for no data logged
%                                   3 for partially missing data 
% -------------------------------------------------------------------------
% Extra Notes:
% -------------------------------------------------------------------------
% Examples: 
%
% * Display mc log from a given data folder
%   mc_log = load_mc_log('\my\data\folder')
%
% * Display mc log from a given data folder for trial 6
%   mc_log = load_mc_log('\my\data\folder', 6)
% -------------------------------------------------------------------------
%                               Notice
%
% Author(s): Antoine Valera
%
% This function was initially released as part of The SilverLab MatLab
% Imaging Software, an open-source application for controlling an
% Acousto-Optic Lens laser scanning microscope. The software was 
% developed in the laboratory of Prof Robin Angus Silver at University
% College London with funds from the NIH, ERC and Wellcome Trust.
%
% Copyright © 2015-2020 University College London
%
% Licensed under the Apache License, Version 2.0 (the "License");
% you may not use this file except in compliance with the License.
% You may obtain a copy of the License at
% 
%     http://www.apache.org/licenses/LICENSE-2.0
% 
% Unless required by applicable law or agreed to in writing, software
% distributed under the License is distributed on an "AS IS" BASIS,
% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
% See the License for the specific language governing permissions and
% limitations under the License. 
% -------------------------------------------------------------------------
% Revision Date:
%   03-07-2019
%
% See also: get_recordings_info, load_quick_preview, load_generic_scan,
% save_MC_log 

%% TODO : Time cropping not implemented
%% Still need a bit of work

function [mc_log, concatenated_MC_displacement_um, concatenated_Time, mc_pixel_size, failure_suspicion] = load_mc_log(source, repeats, rendering, remove_inter_trial)
    if nargin < 2 || isempty(repeats)
        repeats = '';
    end
    if nargin < 3 || isempty(rendering)
        rendering = true;
    end
    if nargin < 4 || isempty(remove_inter_trial)
        remove_inter_trial = false;
    end
    %remove_inter_trial = true;
    remove_first_point = true;
    fix_log_start_issue = false;
    
    %% Load MC log file  
    if ischar(source) && contains(source,'*MC_log_*.txt') && exist(source, 'file')
        %% Passing file path
            mc_log = save_MC_log(1, false, false);
            n_lines = 2;
    elseif ~isstruct(source)
        if ~strcmp(source(end-10:end),'\mc_log.mat')
            source = [source, '\mc_log.mat'];
        end

        if exist(source, 'file')
            load(source);
            n_lines = 2;
        else
            mc_log = {};
        end

        if ~isempty(mc_log)
            %% When importing MC logs, the cell arrays get mixed. We can rearrange them here.
            mc_log = structfun(@(x) x(~cellfun(@isempty, x)), mc_log,'UniformOutput',false);
            [~, idx] = sort(cellfun(@min, mc_log.Time));
            mc_log = structfun(@(x) x(idx), mc_log, 'UniformOutput', false);
            h = load_header(source(1:end-10));
            initial_repeats = h.repeats;
            if numel(mc_log.X_correction) < initial_repeats
                mc_log = [];
                warning('Some MC log trials seems missing. MC Data will not be displayed')
            else
                mc_log = structfun(@(x) x(end-initial_repeats+1:end),mc_log,'UniformOutput',false);
            end
        end
    else
        %% mc_log passed directly
        mc_log = source;
        n_lines = 2;
    end
   

    %% If log exist, plot data
    if ~isempty(mc_log)        
        if fix_log_start_issue
            for trial = 1:numel(mc_log.Time)
                %% Initial points are 
                %[~, wrong_start] = find(movmean(diff(mc_log.Time{1}), [0, 10]) < 0.004, 1, 'first');
                sm = smoothdata(diff(mc_log.Time{trial}),'movmedian',[50, 0]);
                %figure(trial);plot(diff(mc_log.Time{trial}),'r'); hold on;
                sm = [sm(25:end), NaN(1,25)];
                plot(sm,'k')
                [~, wrong_start] = find(sm < (nanmedian(sm) + 5e-3), 1, 'first');

                if isempty(wrong_start)
                    wrong_start = 1;
                end
                timeoffset = mc_log.Time{trial}(1,wrong_start);
                mc_log.X_correction{trial} = mc_log.X_correction{trial}(1,wrong_start:end);
                mc_log.Y_correction{trial} = mc_log.Y_correction{trial}(1,wrong_start:end);
                mc_log.Z_correction{trial} = mc_log.Z_correction{trial}(1,wrong_start:end);
                mc_log.X_difference{trial} = mc_log.X_difference{trial}(1,wrong_start:end);
                mc_log.Y_difference{trial} = mc_log.Y_difference{trial}(1,wrong_start:end);
                mc_log.Z_difference{trial} = mc_log.Z_difference{trial}(1,wrong_start:end);
                mc_log.Time{trial} = mc_log.Time{trial}(1,wrong_start:end);
                mc_log.Time = cellfun(@(t) t - timeoffset, mc_log.Time, 'UniformOutput', false);
            end
        end
        
        if remove_inter_trial
            starts = cellfun(@(t) t(1), mc_log.Time);
            stops = cellfun(@(t) t(end), mc_log.Time);
            inter_trial = starts(2:end) - stops(1:end-1);
            for trial = 2:numel(mc_log.Time)
                mc_log.Time{trial} = mc_log.Time{trial} - sum(inter_trial(1:trial-1));
            end
            
%             starts = cellfun(@(t) t(1), mc_log.Time);
%             stops = cellfun(@(t) t(2), mc_log.Time);
%             inter_trial = stops - starts;
%             for trial = 1:numel(mc_log.Time)
%                 mc_log.Time{trial} = mc_log.Time{trial} - sum(inter_trial(1:trial));
%             end
        end
        
        if remove_first_point
            mc_log.X_correction = cellfun(@(x) x(2:end), mc_log.X_correction, 'UniformOutput', false);
            mc_log.Y_correction = cellfun(@(x) x(2:end), mc_log.Y_correction, 'UniformOutput', false);
            mc_log.Z_correction = cellfun(@(x) x(2:end), mc_log.Z_correction, 'UniformOutput', false);
            mc_log.X_difference = cellfun(@(x) x(2:end), mc_log.X_difference, 'UniformOutput', false);
            mc_log.Y_difference = cellfun(@(x) x(2:end), mc_log.Y_difference, 'UniformOutput', false);
            mc_log.Z_difference = cellfun(@(x) x(2:end), mc_log.Z_difference, 'UniformOutput', false);
            mc_log.Time         = cellfun(@(x) x(2:end), mc_log.Time, 'UniformOutput', false);
        end
        
        
        if any(cellfun(@isempty,  mc_log.Time))
            mc_log = {};
            concatenated_MC_displacement_um = [];
            concatenated_Time = [];
            mc_pixel_size = [];
            fprintf([strrep(source,'\','/') , ' seems to have some missing data.\n'])
            failure_suspicion = 3;
            return
        end
        
        times = cellfun(@(x) x(end) - x(1), mc_log.Time);
        if numel(times) > 1
            offset = median(times(2:end)) - times(1);
        else 
            offset = 0;
        end
        mc_log.Time = cellfun(@(x) x + offset, mc_log.Time, 'UniformOutput', false);
        
        %% Filter for trials
        if ~isempty(repeats) && any(repeats)
            if max(repeats) > numel(mc_log.X_correction)
                warning('List of trial provided for mc log exceed the number of available trials in the Log. Only the available trials will be used')
                repeats(repeats > numel(mc_log.X_correction)) = [];
            end
            mc_log = structfun(@(x) x(repeats),mc_log,'UniformOutput',false);
        end
       
        %% Now get the output        
        X_corr = [mc_log.X_correction{:}];
        Y_corr = [mc_log.Y_correction{:}];
        Z_corr = [mc_log.Z_correction{:}];
        X_diff = [mc_log.X_difference{:}];            
        Y_diff = [mc_log.Y_difference{:}];            
        Z_diff = [mc_log.Z_difference{:}];            
        timescale = [mc_log.Time{:}];            
        
       
        %% Enable to remove artefacts
%         X_corr = interpolate_to(filloutliers(X_corr,'previous','grubbs'), 10000);
%         Y_corr = interpolate_to(filloutliers(Y_corr,'previous','grubbs'), 10000);
%         Z_corr = interpolate_to(filloutliers(Z_corr,'previous','grubbs'), 10000);
%         X_diff = interpolate_to(filloutliers(X_diff,'previous','grubbs'), 10000);
%         Y_diff = interpolate_to(filloutliers(Y_diff,'previous','grubbs'), 10000);
%         Z_diff = interpolate_to(filloutliers(Z_diff,'previous','grubbs'), 10000);
%         timescale = interpolate_to(timescale, 10000);
 
%         X_corr = interpolate_to(X_corr, 10000);
%         Y_corr = interpolate_to(Y_corr, 10000);
%         Z_corr = interpolate_to(Z_corr, 10000);
%         X_diff = interpolate_to(X_diff, 10000);
%         Y_diff = interpolate_to(Y_diff, 10000);
%         Z_diff = interpolate_to(Z_diff, 10000);
%         timescale = interpolate_to(timescale, 10000);
        
        if fix_log_start_issue || timescale(1) < 0 % Not sure that's the right flag
            mc_log.Time = cellfun(@(x) x - timescale(1) , mc_log.Time, 'UniformOutput', false);
            timescale = timescale - timescale(1);            
        end
        
        XYMC = 1;
        ZMC = 1;
        if ~any(Z_corr)
            ZMC = 0;
        end
        if ~any(X_corr)
            XYMC = 0;
        end
        
        if numel(timescale) > 1 && rendering
            range = [min(timescale), max(timescale)]; 
            f = figure(9875);clf();hold on; 
            xlim(range);hold on; 
            ax1 = subplot(n_lines,3,1); hold on;
            plot(timescale,X_corr,'r');
            xlim(range);hold on; 
            ax2 = subplot(n_lines,3,2); hold on;
            plot(timescale,Y_corr,'b');
            xlim(range);hold on; 
            ax3 = subplot(n_lines,3,3); hold on;
            plot(timescale,Z_corr,'k');
            xlim(range);hold on; 
            ax4 = subplot(n_lines,3,4); hold on;
            plot(timescale,X_diff,'r');
            xlim(range);hold on; 
            ax5 = subplot(n_lines,3,5); hold on;
            plot(timescale,Y_diff,'b');
            xlim(range);hold on; 
            ax6 = subplot(n_lines,3,6); hold on;
            plot(timescale,Z_diff,'k'); 
            xlim(range);hold on; 
            try
                linkaxes([ax1, ax2, ax3, ax4, ax5, ax6], 'x');
            end
            title(f.Children(end), 'MC Logs (values in MC pxls)');
        elseif rendering % when mc log has an issue
            figure(9875);clf();
            mc_log = [];
        elseif numel(timescale) <= 1 % when mc log has an issue
            mc_log = [];
        end
        
        if nargout > 1 && numel(timescale) > 1
            if ~any(X_corr)
            	[concatenated_MC_displacement_um, concatenated_Time, mc_pixel_size] = get_scaled_output(X_diff, Y_diff, Z_diff, timescale, source, 0);
            else
                [concatenated_MC_displacement_um, concatenated_Time, mc_pixel_size] = get_scaled_output(X_corr, Y_corr, Z_corr, timescale, source, 1);
            end 
        elseif nargout > 1 % when mc log has an issue
            concatenated_MC_displacement_um = [];
            concatenated_Time = [];
            mc_pixel_size = [];
        end
        
        failure_suspicion = false;
        if nargout > 4     
            %% Look for continuous zeroes in the correction field
            n_zeroes = sum(diff([1, X_corr]) == 0 & X_corr == 0) + sum(diff([1, Y_corr]) == 0 & Y_corr == 0) + sum(diff([1, Z_corr]) == 0 & Z_corr == 0);
            if XYMC
                %% if XY MC was on, Look for continuous zeroes in the diff field too
                n_zeroes = n_zeroes + sum(diff([1, X_diff]) == 0 & X_diff == 0) + sum(diff([1, Y_diff]) == 0 & Y_diff == 0);
            end
            if ZMC
                %% If Z MC was on, Look for continuous zeroes in the diff field too
                n_zeroes = n_zeroes + sum(diff([1, Z_diff]) == 0 & Z_diff == 0);
            end
            n_too_much = sum(abs(X_corr > 80)) + sum(abs(Y_corr > 80)) + sum(abs(Z_corr > 80 ));
            n_thr = numel(X_corr)/10;
            if (XYMC && (n_zeroes > n_thr || n_too_much > n_thr)) && timescale(end) > 1     
                failure_suspicion = 1;
            end
        end
    else
        concatenated_MC_displacement_um = [];
        concatenated_Time = [];
        mc_pixel_size = [];
        failure_suspicion = 2;
    end
end

 function [concatenated_MC_displacement_um, concatenated_Time, mc_pixel_size] = get_scaled_output(X_corr, Y_corr, Z_corr, timescale, source, MC_status)
    %% Check if we can get the information
    if ischar(source)
        [~, controller] = load_header(source(1:end-10));
    else
        controller = [];
    end

    %% Scale output vectors
    if ~isempty(controller)
        XY_mc_pxl = controller.aol_params.get_pixel_size(controller.mc_scan_params.acceptance_angle, controller.mc_scan_params.mainscan_x_pixel_density);
        Z_mc_pxl  = double(controller.daq_fpga.z_pixel_size_um);
        if isempty(XY_mc_pxl)
            XY_mc_pxl = 1;
        end
        scaling        = Z_mc_pxl / XY_mc_pxl;
        mc_pixel_size  = [XY_mc_pxl, Z_mc_pxl];
        if MC_status
            xy_factor = double(controller.daq_fpga.proportianal_x10) / 10;
            z_factor  = double(controller.daq_fpga.proportianal_x10_z) / 10;
        else
            xy_factor = 1;
            z_factor = 1;
            %% Saturate measures when MC is off and offset is > window
            X_corr(abs(X_corr) > controller.daq_fpga.mc_roi_size(1)) = controller.daq_fpga.mc_roi_size(1);
            Y_corr(abs(Y_corr) > controller.daq_fpga.mc_roi_size(1)) = controller.daq_fpga.mc_roi_size(1);
            Z_corr(abs(Z_corr) > controller.daq_fpga.mc_roi_size(2)) = controller.daq_fpga.mc_roi_size(2);
        end
        Z_corr(isnan(Z_corr)) = 0;
        %mc_pixel_size(1) = mc_pixel_size(1) / xy_factor;
        %mc_pixel_size(2) = mc_pixel_size(2) / z_factor;
        concatenated_MC_displacement_um = (vecnorm([X_corr * mc_pixel_size(1)  ; Y_corr * mc_pixel_size(1)  ; Z_corr * mc_pixel_size(2) ])');
        concatenated_Time               = timescale';
    else
        mc_pixel_size = [];
        concatenated_MC_displacement_um = [];
        concatenated_Time = [];
    end
 end