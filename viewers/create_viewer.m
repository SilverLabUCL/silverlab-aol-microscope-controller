%% Generate the live imaging viewer with the right resolution
% -------------------------------------------------------------------------
% Syntax: 
%   create_viewer(controller)
% -------------------------------------------------------------------------
% Inputs: 
%   controller (Controller object) - Optional - Default is main Controller: 
%                                   The current controller
% -------------------------------------------------------------------------
% Outputs: 
% -------------------------------------------------------------------------
% Extra Notes:
% * This function must be called every time you change the resolution of 
%   your image, after updating the scan params.
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
% Partial Revision Date:
%   06-11-2018
%
% See also: controller, LiveViewer, set_up_image_viewer, ScanParams

% TODO : we could allow non square ROIs and variable size miniscans here

function create_viewer(controller)
    if nargin < 1 || isempty(controller)
        controller = get_existing_controller_name(true);
    end

    %% Save any preexisting LiveViewer settings
    if ~isempty(controller.viewer) && strcmp(controller.viewer.type, 'live_image')
        bkp = controller.viewer.get_current_parameters_set();
        controller.gui_handles.viewer_mode = controller.viewer.preset_mode;
    else
        bkp = [];
    end

    %% Create the GUI if required
    set_up_image_viewer(controller);

    %% Prepare Viewer Settings depending on the scan mode
    if controller.scan_params.imaging_mode == ImagingMode.Pointing 
        viewer_resolution_x = sqrt(controller.scan_params.num_drives);
        viewer_resolution_y = sqrt(controller.scan_params.num_drives);
    elseif controller.scan_params.imaging_mode == ImagingMode.Functional
        viewer_resolution_x = 1;
        viewer_resolution_y = controller.scan_params.num_drives;   
    elseif isnan(controller.aol_params.xy_z_norm_ratio) || numel(unique(controller.scan_params.voxels_for_ramp)) == 1  % NaN for startup, square for default Raster Mode or Pointing
        viewer_resolution_x = unique(controller.scan_params.voxels_for_ramp);
        viewer_resolution_y = controller.scan_params.num_drives;
    else
        error('Unable to generate a frame. Number of voxels varies from ramp to ramp')
    end
    
    %% QQ - Auto-ADD POINT VIEWER HERE

    %% Now, Create the viewer
    controller.viewer = LiveViewer( viewer_resolution_x,...
                                    viewer_resolution_y,...
                                    controller.daq_fpga.points_to_read,...
                                    controller.gui_handles.viewer_mode,...
                                    ~controller.gui_handles.is_gui,...
                                    controller.gui_handles.is_gui,...
                                    controller.gui_handles.frame_averages);


    %% Restore pre-existing LiveViewer settings
    if ~isempty(bkp)
        controller.viewer.set_new_parameters_set(bkp);
    end

   %% Add um scal for conveniency                             
%    figure(1000); hold on;
%    ylabel('pixels');
%    yyaxis right; hold on;
%    ylabel('um');
%    ylim([0,controller.aol_params.fov_um()]); hold on;
%    axis ij; %invert axis
end