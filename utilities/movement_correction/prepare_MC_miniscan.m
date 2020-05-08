%% Generate MC scan params using the provided ROI
%
% -------------------------------------------------------------------------
% Syntax: 
%   status =   
%   prepare_MC_miniscan(controller, non_default_resolution, non_default_aa, 
%                       non_default_dwelltime, non_default_pockel_voltages,
%                       miniscan_ROI, absolute_z_for_ref)
%
% -------------------------------------------------------------------------
% Inputs: 
%   controller(Controller object) - Optional - Default is main Controller:
%                                   Contains information about the
%                                   microscope setup such as FOV, dwell
%                                   time etc...
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
%
%   miniscan_ROI([6 X 1 INT] OR []) - Optional - Default is a 18 X 18 patch
%       around the brightess object in the current FOV
%                                   The coordinates of the selected ROI.
%                                   format is [Xstart, Ystart, Xstop,
%                                   Ystop, Xsize, Ysize]
%
%   absolute_z_for_ref(FLOAT) - Optional - Default is current position:
%                                   The stage absolute plane where the
%                                   reference is (in um).
% -------------------------------------------------------------------------
% Outputs:
%   status(BOOL)
%                                   If selection is aborted, return false.
% -------------------------------------------------------------------------
% Extra Notes:
% * For Z MC, you nned to set up controller.daq_fpga.Z_Lines and
%   controller.daq_fpga.z_pixel_size_um before starting the process.
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

function status = prepare_MC_miniscan(controller, non_default_resolution, non_default_aa, non_default_dwelltime, non_default_pockel_voltages, miniscan_ROI, absolute_z_for_ref)
    if nargin < 1 || isempty(controller)
        controller = get_existing_controller_name(true);
    end
    if nargin < 2 || isempty(non_default_resolution)
        non_default_resolution = controller.scan_params.mainscan_x_pixel_density;
    end
    if nargin < 3 || isempty(non_default_aa)
        non_default_aa = controller.scan_params.acceptance_angle;
    end
    if nargin < 4 || isempty(non_default_dwelltime)
        non_default_dwelltime = controller.scan_params.voxel_time;
    end
    if nargin < 5 || isempty(non_default_pockel_voltages)
        non_default_pockel_voltages = controller.pockels.on_value;
    end
    if nargin < 7 || isempty(absolute_z_for_ref)
        absolute_z_for_ref = controller.xyz_stage.get_position(3);
    end
    
    %% Check if at current stack center (don't move the stage)
    if ~check_if_at_stack_center(controller,'This will also affect the measured threshold as you will be scanning from a different Z distance')
        status = false;
        return
    else
        status = true;
    end
    
    %% If no selected ROI, find one automatically
    if nargin < 6 || isempty(miniscan_ROI)
        ROI_size = 18;
        current_frame = preview_at_any_z(controller, absolute_z_for_ref);
        current_frame = current_frame(:,:,1);
        thr = median(current_frame(:));
        current_frame = current_frame > thr;
        BW = bwareafilt(current_frame ,[ROI_size-10, (ROI_size-3)*(ROI_size-3)]); % we could do without the toolbox, but anyway, you should do a proper selection
        BW = bwareafilt(BW ,1);
        [y, x] = ndgrid(1:size(BW, 1), 1:size(BW, 2));
        centroid = mean([x(logical(BW)), y(logical(BW))]);
        miniscan_ROI = round([centroid(1)-ROI_size/2,centroid(1)-ROI_size/2,centroid(1)+ROI_size/2,centroid(1)+ROI_size/2,ROI_size,ROI_size]);
    end

    %% Prepare frame
    controller.reset_frame_and_send('raster', non_default_resolution, non_default_aa, non_default_dwelltime); %% QQ add pockel value
    controller.daq_fpga.buffer_min = miniscan_ROI(5)*miniscan_ROI(5); %% QQ fix buffer issue

    %% Adjust for current location
    relative_z_distance_um = (absolute_z_for_ref - controller.xyz_stage.get_position(3));       
    
    %% Rescale Z um in XYpixels
    xy_pixel_size = controller.aol_params.get_pixel_size(non_default_aa, non_default_resolution);
    rescaled_z_pixels = relative_z_distance_um / xy_pixel_size;
    
    %% Get XY plane
    planes = controller.scan_params.generate_miniscan_boxes([miniscan_ROI(2)  ;miniscan_ROI(1);rescaled_z_pixels],...
                                                            [miniscan_ROI(5)  ;0              ;0]                 ,... %xsize
                                                            [0                ;miniscan_ROI(6);0]                 ,... %ysize
                                                            [0                ;0              ;0])                ;    %zsize 
    %% Add Z planes
    if controller.daq_fpga.Z_Lines     
        controller.scan_params.fixed_len = false;
        Z_extent_xypixel = double(miniscan_ROI(6) * (controller.daq_fpga.z_pixel_size_um) / xy_pixel_size);% * xy_pixel_size;
        %Z_extent_um      = double(Z_extent_xypixel * xy_pixel_size); % eg. If ROI is 18 pixels long, Z lines are 18 um long!
        half_window      = [miniscan_ROI(5)/2, miniscan_ROI(6)/2];
        zplanes = controller.scan_params.generate_miniscan_boxes([  miniscan_ROI(2) + half_window(1); miniscan_ROI(1)+ half_window(2); rescaled_z_pixels - Z_extent_xypixel/2],...
                                                                    [0;0;+Z_extent_xypixel],...   % v1
                                                                    [0;0;0],...             %v2
                                                                    [0;0;0]);               %v3 
        for z_line = 1:controller.daq_fpga.Z_Lines       
            planes = [planes, zplanes];
        end
    end

    %% Calculate and send drives
    controller.set_miniscans(planes, non_default_pockel_voltages, 0, miniscan_ROI(6)); %% QQ for now, res is passed by hand. To be fixed
    controller.mc_scan_params = controller.scan_params;
end