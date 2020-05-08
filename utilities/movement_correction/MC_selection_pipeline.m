%% MC selection full pipeline. Call this function when using command line
% This function will handle ref slection, start tracking and preview MC.
% -------------------------------------------------------------------------
% Syntax: 
% [selection_status, tracking_status] =
%           MC_selection_pipeline(controller, preview, image_with_mc, finalise_mc,
%                     reset_drives,  suggested_ROI, ref_channel, 
%                     absolute_z_for_ref, MC_rate, non_default_resolution,
%                     non_default_aa, non_default_dwelltime, 
%                     non_default_pockel_voltages)
%
% -------------------------------------------------------------------------
% Inputs: 
%   controller(Controller object) - Optional - Default is main Controller:
%                                   Contains information about the
%                                   microscope setup such as FOV, dwell
%                                   time etc...
%
%   preview(BOOL) - Optional - Default is true:
%                                   If true, once the MC selected, the
%                                   reference is displayed using the
%                                   regular imagin FIFOs (use this to check
%                                   for quality without thresholding). see
%                                   preview_mc_ROI.m for more details
%
%   image_with_mc(BOOL) - Optional - Default is true:
%                                   If true, the system will start imaging
%                                   in full frame until stopped
%
%   finalise_mc(BOOL) - Optional - Default is false:
%                                   If true. MC is auto-stopped once your
%                                   testing is done
%
%   reset_drives(BOOL) - Optional - Default is false:
%                                   Stop MC automatically at the end, and
%                                   reset mainscan drives.
%
%   suggested_ROI([3 X 1 INT] OR []) - Optional - Default is [0, 0, 0]:
%                                   The coordinates where the ROI will
%                                   appear on the preview. If value is [0,
%                                   0, 0], then the coordinates will be set
%                                   at the center of the FOV. Value is in
%                                   pixels
%
%   ref_channel(INT) - Optional - Default is 1:
%                                   The channel to use for the reference (1
%                                   or 2)
%
%   absolute_z_for_ref(FLOAT) - Optional - Default is current position:
%                                   The stage absolute plane where the
%                                   reference is (in um).
%
%   MC_rate(FLOAT) - Optional - Default is 2:
%                                   In ms, the time between 2 MC
%                                   corrections.
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
%   selection_status(BOOL):
%                                   True if you completed the selection
%                                   process, false otherwise
%
%   tracking_status(BOOL) :
%                                   True if you started tracking the ref,
%                                   false otherwise
%
% -------------------------------------------------------------------------
% Extra Notes:
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
%   prepare_MC_Ref, select_MC_thr, start_tracking_mc_ROI, MC_off
%

% TODO : check the stop MC function.
% Add background MC plot

function [selection_status, tracking_status] = MC_selection_pipeline(controller, preview, image_with_mc, finalise_mc, reset_drives, suggested_ROI, ref_channel, absolute_z_for_ref, MC_rate, non_default_resolution, non_default_aa, non_default_dwelltime, non_default_pockel_voltages)
    if nargin < 1 || isempty(controller)
        controller = get_existing_controller_name(true);
    end
    if nargin < 2 || isempty(preview)
        preview = true;
    end
    if nargin < 3 || isempty(image_with_mc)
        image_with_mc = false;
    end
    if nargin < 4 || isempty(finalise_mc)
        finalise_mc = false;
    end
    if nargin < 5 || isempty(reset_drives)
        reset_drives = false;     
    end
    if nargin < 6 || all(isempty(suggested_ROI)) || all(suggested_ROI == 1)
        suggested_ROI = [0;0;0];
    end
    if nargin < 7 || isempty(ref_channel)
        ref_channel = 1;
    end
    if nargin < 8 || isempty(absolute_z_for_ref)
        absolute_z_for_ref = controller.xyz_stage.get_position(3);
    end
    if nargin < 9 || isempty(MC_rate)
        MC_rate = 2;   
    end
    if nargin < 10 || isempty(non_default_resolution)
        non_default_resolution = controller.scan_params.mainscan_x_pixel_density;
    end
    if nargin < 11 || isempty(non_default_aa)
        non_default_aa = controller.scan_params.acceptance_angle;
    end
    if nargin < 12 || isempty(non_default_dwelltime)
        non_default_dwelltime = controller.scan_params.voxel_time;
    end
    if nargin < 13 || isempty(non_default_pockel_voltages)
        non_default_pockel_voltages = controller.pockels.on_value;
    end

    %% In a first time, you must select the ROI and the threshold
    [selection_status, suggested_ROI, suggested_thr, absolute_z_for_ref, ~] = prepare_MC_Ref(controller, absolute_z_for_ref, ref_channel, suggested_ROI, non_default_resolution, non_default_aa, non_default_dwelltime, non_default_pockel_voltages);
    if ~selection_status || any(isnan(suggested_ROI(1))) || any(isnan(suggested_thr)) % if cancelled, abort
        fprintf('MC selection or ROI threshold selection aborted\n')
        return
    end
    
    %% Now, you send these new drives, and you can preview your ROI
    tracking_status = start_tracking_mc_ROI(controller, suggested_ROI, absolute_z_for_ref, suggested_thr, MC_rate, preview, non_default_resolution, non_default_aa, non_default_dwelltime, non_default_pockel_voltages);
    if ~tracking_status % if failed, abort
        fprintf('MC tracking aborted\n')
        return
    else
        fprintf('MC running in the background\n')
    end

    %% Example of new drives with a different resolution
    if image_with_mc
        controller.viewer.preset_mode = 1;
        controller.live_image('fast');
    end 
    
    %% Stopping MC, or stopping and reseting initial drives or keeping MC in background
    % qq some confustion here
    if finalise_mc && ~reset_drives
        controller.stop_MC(); % Stop MC, but can still be restarted
    elseif finalise_mc && reset_drives
        MC_off(controller); % Full stop
    else
        % switch to background MC
    end
end
