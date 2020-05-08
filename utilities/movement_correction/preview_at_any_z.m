%% Capture an image at a specified absolute Z plane
% Z plane is defined as the motor stage 'Z' value (ignoring any AOL offset)
% -------------------------------------------------------------------------
% Syntax: 
%   reference =
%       preview_at_any_z(controller, absolute_z_for_ref, 
%                        non_default_resolution, non_default_aa,
%                        non_default_dwelltime, non_default_pockel_voltages)
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
%   reference([non_default_resolution X non_default_resolution] UINT16):
%                                   The frame for the selected absolute Z
%                                   plane
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
% See also: controller.single_record, get_averaged_data, prepare_MC_Ref

function reference = preview_at_any_z(controller, absolute_z_for_ref, non_default_resolution, non_default_aa, non_default_dwelltime, non_default_pockel_voltages)
    if nargin < 1 || isempty(controller)
        controller = get_existing_controller_name(true);
    end
    if nargin < 2 || isempty(absolute_z_for_ref)
        absolute_z_for_ref = controller.xyz_stage.get_position(3);
    end
    if nargin < 3 || isempty(non_default_resolution)
        non_default_resolution = controller.scan_params.mainscan_x_pixel_density;
    end
    if nargin < 4 || isempty(non_default_aa)
        non_default_aa = controller.scan_params.acceptance_angle;
    end
    if nargin < 5 || isempty(non_default_dwelltime)
        non_default_dwelltime = controller.scan_params.voxel_time;
    end
    if nargin < 6 || isempty(non_default_pockel_voltages)
        non_default_pockel_voltages = controller.pockels.on_value;
    end
    
    controller.initialise(); % Only usefull when used as standalone
    controller.daq_fpga.safe_stop(true);
    
    % QQ We may need an extra or something if you send MC drives, and then
    % resend them, or start from a funny set of drives. This is expecially
    % true if you had some offset or whatever
    % controller.reset_frame_and_send('raster', somevalues);

    %% Check if at current stack center (don't move the stage)
    if ~check_if_at_stack_center(controller,'This may affect the shape of the object you are selecting, and its precise location if the rig is not fully calibrated')
        return
    end
    
    %% Store initial scan_params
    initial_scan_params = controller.scan_params;
    cleanupObj = onCleanup(@() cleanMeUp(controller, initial_scan_params));

    %% We estimate and apply offset to znorm, and adjust res and aa
    controller.scan_params.mainscan_x_pixel_density = non_default_resolution;
    controller.scan_params.acceptance_angle = non_default_aa;
    controller.scan_params.voxel_time = non_default_dwelltime;
    z_norm = controller.aol_params.convert_z_um_to_norm(absolute_z_for_ref, controller.scan_params.acceptance_angle, controller.xyz_stage.get_position(3));
    controller.scan_params.start_norm_raw(3) = z_norm;
    controller.send_drives(true, non_default_pockel_voltages); %since cropped data is taken from the viewer using coordinates, we have to change it
    
    %% We get the reference image
    controller.initialise();  
    reference = get_averaged_data(controller,8,false,false);
    reference = uint16(cat(3,reference,zeros(size(reference,1),size(reference,2))));
end

function cleanMeUp(controller, initial_scan_params)
    %% Restore initial settings
    controller.scan_params = initial_scan_params;
    controller.send_drives(true);
end
