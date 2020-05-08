%% Capture reference plane image, select ROI location and ROI threshold.
% If succeed, returns the ROI limits and threshold, but do not send any
% drives. You must still generate a miniscan from these values.
% If the process is not complete, returns status = false;
%
% -------------------------------------------------------------------------
% Syntax: 
%   [status, suggested_ROI, suggested_thr, absolute_z_for_ref, ref_channel] =
%           prepare_MC_Ref( controller, absolute_z_for_ref, ref_channel,
%                           suggested_ROI, non_default_resolution,
%                           non_default_aa, non_default_dwelltime,
%                           non_default_pockel_voltages)
%
% -------------------------------------------------------------------------
% Inputs: 
%   controller(Controller object) - Optional - Default is main Controller:
%                                   Contains information about the
%                                   microscope setup such as FOV, dwell
%                                   time etc...
%
%   absolute_z_for_ref(FLOAT) - Optional - Default is current position:
%                                   The stage absolute plane where the
%                                   reference is (in um).
%
%   ref_channel(INT) - Optional - Default is 1:
%                                   The channel to use for the reference (1
%                                   or 2)
%
%   suggested_ROI([3 X 1 INT] OR []) - Optional - Default is [0, 0, 0]:
%                                   The coordinates where the ROI will
%                                   appear on the preview. If value is [0,
%                                   0, 0], then the coordinates will be set
%                                   at the center of the FOV. Value is in
%                                   pixels
%
%   non_default_resolution(INT) - Optional - Default is current main frame
%           resolution
%                                   In pixels, the resolution of the frame
%                                   preview
%
%   non_default_aa(FLOAT) - Optional - Default is current main frame
%           acceptance angle
%                                   In radians, the accpetance angle of the
%                                   frame preview
%
%   non_default_dwelltime(FLOAT) - Optional - Default is current main frame
%           voxel_time
%                                   In seconds, the dwell time to use for
%                                   the reference (please note that the
%                                   full frame preview always uses 50ns to
%                                   maximise the FOV
%
%   non_default_pockel_voltages(FLOAT) - Optional - Default is current main
%           frame pockel value
%                                   In V, the pockel value to use for both
%                                   the full frame preview and the miniscan
%                                   THR selection.
% -------------------------------------------------------------------------
% Outputs:
%   status(BOOL):
%                                   True if you completed the selection
%                                   process, false otherwise
%
%   miniscan_ROI([6 X 1 INT] OR []) :
%                                   The coordinates of the selected ROI. If
%                                   you cancelled the process, we return
%                                   [].
%                                   If a ROI was selected, format is
%                                   [Xstart, Ystart, Xstop, Ystop, Xsize,
%                                   Ysize]
%
%   suggested_thr([2 X 1] INT) :
%                                   The XY and Z threshold selected by the
%                                   user
%
%   absolute_z_for_ref(FLOAT):
%                                   The stage absolute plane where the
%                                   reference is was selected. The value
%                                   can differ from the input if you
%                                   changed it in the frame selection menu.
%
%   ref_channel(INT):
%                                   The channel to use for the reference (1
%                                   or 2). The value can differ from the 
%                                   input if you changed it in the frame
%                                   selection menu.
% -------------------------------------------------------------------------
% Extra Notes:
% * Full frame uses a 50ns dwell time to maximise the FOV at remote Z. The
%   purpose of that step is to find the location of the ROI, which is 
%   better done a short dwell time. The Miniscan preview, for threshold
%    selection is done at the desired dwell time.
% -------------------------------------------------------------------------
% Examples:
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
%   14-03-2019
%
% See also: preview_at_any_z, select_ROI, prepare_MC_miniscan,
%   get_averaged_data, select_MC_thr 
%

function [status, miniscan_ROI, suggested_thr, absolute_z_for_ref, ref_channel] = prepare_MC_Ref(controller, absolute_z_for_ref, ref_channel, suggested_ROI, non_default_resolution, non_default_aa, non_default_dwelltime, non_default_pockel_voltages)
    if nargin < 1 || isempty(controller)
        controller = get_existing_controller_name(true);
    end
    if nargin < 2 || isempty(absolute_z_for_ref)
        absolute_z_for_ref = controller.xyz_stage.get_position(3);
    end
    if nargin < 3 || isempty(ref_channel)
        ref_channel = 1;
    end
    if nargin < 4 || isempty(suggested_ROI)
        suggested_ROI = [0;0;0];
    end
    if nargin < 5 || isempty(non_default_resolution)
        non_default_resolution = controller.scan_params.mainscan_x_pixel_density;
    end
    if nargin < 6 || isempty(non_default_aa)
        non_default_aa = controller.scan_params.acceptance_angle;
    end
    if nargin < 7 || isempty(non_default_dwelltime)
        non_default_dwelltime = controller.scan_params.voxel_time;
    end
    if nargin < 8 || isempty(non_default_pockel_voltages)
        non_default_pockel_voltages = controller.pockels.on_value;
    end
    
    %% Store initial scan_params
    controller.reset_frame_and_send();
    initial_scan_params = controller.scan_params;
    cleanupObj = onCleanup(@() cleanMeUp(controller, initial_scan_params));
    
    %% Set some other default settings
    ROI_size = 18;
    n_averages = 4;   
    
    %% Set default output values
    status = false; 
    suggested_thr = [];

    %% Capture reference
    reference_frame = preview_at_any_z(controller, absolute_z_for_ref, non_default_resolution, non_default_aa, 5e-8, non_default_pockel_voltages);
    
    %% Get a suggestion for ROI size and location
    if all(size(suggested_ROI) == [1 3]) && ~all(suggested_ROI == 0) && ~any((suggested_ROI(1:3)+round(ROI_size/2)) > non_default_resolution) % if miniscan coordinates are valid manual input (not out of frame)
        % Then use that
    else % if miniscan coordinates are not set manually or are invalid, then set ROI to the center
        suggested_ROI = [round(non_default_resolution/2 - ROI_size/2), round(non_default_resolution/2 - ROI_size/2), 0];
    end

    %% Open GUI to adjust ROI size and location
    fprintf('ctrl-c to cancel ROI location selection...\n')
    input_params    = {};
    input_params{1} = absolute_z_for_ref;
    input_params{2} = non_default_resolution;
    input_params{3} = non_default_aa;
    input_params{4} = 5e-8; % for maximal FOV
    input_params{5} = non_default_pockel_voltages;
    [miniscan_ROI, ref_channel, absolute_z_for_ref] = select_ROI(controller, suggested_ROI, ROI_size, ref_channel, reference_frame, input_params);
    
    %% If completed, get a miniscan of the region, and open a GUI to select threshold
    if ~isempty(miniscan_ROI) && ~isnan(miniscan_ROI(1))
        %% Calculate and set drives
        prepare_MC_miniscan(controller, non_default_resolution, non_default_aa, non_default_dwelltime, non_default_pockel_voltages, miniscan_ROI, absolute_z_for_ref);
        
        %% Get miniscan frame
        controller.initialise();  
        reference_frame = get_averaged_data(controller, n_averages, false, false);
        suggested_thr = select_MC_thr(permute(reference_frame(:,:,ref_channel),[2,1,3])); %% qq not sure if the rotation comes from XYswapped
        
        %% If completed, set ref_channel and some other variables 
        if ~isnan(suggested_thr)
            controller.host_channel     = ref_channel; % QQ could be a problem if mc is already running and you reselect some stuff but then want to abort
            controller.suggested_MC_ROI = miniscan_ROI;
            controller.suggested_z_ref  = absolute_z_for_ref;
            controller.suggested_thr    = suggested_thr;
            status                      = true; % success            
        end
    end
end

function cleanMeUp(controller, initial_scan_params)
    %% Restore initial settings
    controller.scan_params = initial_scan_params;
    controller.send_drives(true);
end

