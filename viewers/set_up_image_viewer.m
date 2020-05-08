%% Setup figure 1000 (Live viewer) and create a minimal UI
% -------------------------------------------------------------------------
% Syntax: 
%   set_up_image_viewer(controller)
% -------------------------------------------------------------------------
% Inputs: 
%   controller (Controller object) - Optional - Default is main Controller: 
%                                   The current controller
% -------------------------------------------------------------------------
% Outputs: 
% -------------------------------------------------------------------------
% Extra Notes:
% * Figure 1000 cannot be closed using the general function (it uses a
%   modified closing function). However, if you really need to close it, 
%   call delete(figure(1000)) 
% -------------------------------------------------------------------------
% Examples:
% -------------------------------------------------------------------------
%                               Notice
%
% Author(s): Antoine Valera, Geoffrey Evans
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
%   16-03-2020
%
% See also: Controller, create_viewer, stop_image, Advanced_GUI.mlapp,
%   viewer_params

function set_up_image_viewer(controller)
    if nargin < 1 || isempty(controller)
        controller = get_existing_controller_name(true);
    end
    
    %% Create the live imaging window
    fig = figure(1000); % reserved figure number
    
    %% If there is a preexsiting figure, keep its location
    previous_position = fig.Position; %If already exist, store the current location and size of the figure
    cla(); axis square; % clear figure. pb clf make the preset viwiing params spinner unaccessible

    %% Check if the minimalist GUI already exist or not
    set(fig, 'windowstyle', 'docked')
    set(fig, 'KeyPressFcn', @(~,~) controller.stop_image(true,false));
    set(gcf,'closer','closereq'); %% If you were displaying the gui before, then the function is still ' ' so we set it back to default
    add_buttons(fig, controller); % Minimal control set in offline mode
    
    % %% Small control to prevent hi-res scan to be larger than the screen
    % %set(0,'units','pixels');
    % %screen_res = get(0,'ScreenSize');
    % %screen_res = min([controller.scan_params.mainscan_x_pixel_density, round(screen_res(4)/2)]);
    % %[50 50 screen_res screen_res]
    % 
    % %% Now generate the figure
    % set(fig, 'windowstyle', 'normal','Resize','on','DockControls','off','Position', previous_position,'Toolbar','none','Color','w','MenuBar','none')
    
    %% Prevents figure to be maually closed
    set(gcf,'closer',' ');
end

function add_buttons(fig, controller)
    %% Add essential buttons to minimal display
    status = 'on';
    
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Scan', 'Position', [20 20 100 20], 'Callback', @controller.quick_start, 'Enable', status);
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Stop', 'Position', [20 40 100 20], 'Callback', @(~,~) controller.stop_image(true,false), 'Enable', status); %don't stop mc
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'ScreenShot', 'Position', [20 60 100 20], 'Callback', @(~,~) controller.screen_capture(''), 'Enable', status);
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Get Stage Position', 'Position', [20 90 100 20], 'Callback', @(~,~) controller.xyz_stage.disp_position(), 'Enable', status);
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Zero Stage Position', 'Position', [20 110 100 20], 'Callback', @(~,~) controller.xyz_stage.zero_position(), 'Enable', status);
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Set Start Z', 'Position', [20 130 100 20], 'Callback', @(~,~) controller.set_z_pos(1), 'Enable', status);
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Set Stop Z', 'Position', [20 150 100 20], 'Callback', @(~,~) controller.set_z_pos(2), 'Enable', status);
    uicontrol(fig, 'Style', 'text', 'String', 'Num Z Planes', 'Position', [20 170 100 40], 'Callback', @controller.update_z_planes, 'Enable', status);
    uicontrol(fig, 'Style', 'edit', 'String', '1', 'Position', [20 190 100 20], 'Callback', @controller.update_z_planes, 'Enable', status);

    %% Add a spinner for viewer
    already_there = findobj(fig.Children, 'Tag', 'viewer_settings_spinner'); 
    if isempty(already_there)
        jModel = javax.swing.SpinnerNumberModel(0, 0, 5, 1);
        jSpinner = javax.swing.JSpinner(jModel);
        jhSpinner = javacomponent(jSpinner, [20 380 100 20], fig);
        set(jhSpinner, 'StateChangedCallback', @spinnerCallBack);
        uicontrol(fig, 'Style', 'text', 'String', 'Viewer preset', 'Position', [20 400 100 20], 'Enable', status,'Tag','viewer_settings_spinner');
    end
    
    uicontrol('Style', 'pushbutton', 'String', 'Select MC Ref', 'Position', [20 260 100 20], 'Callback', @(~,~) prepare_MC_Ref(controller), 'Enable', status);
    uicontrol('Style', 'pushbutton', 'String', 'Start Tracking', 'Position', [20 280 100 20], 'Callback', @(~,~) start_tracking_mc_ROI(controller), 'Enable', status);
    uicontrol('Style', 'pushbutton', 'String', 'Stop MC', 'Position', [20 300 100 20], 'Callback', @(~,~) controller.stop_MC(), 'Enable', status);
end

function spinnerCallBack(~, ~)
    [hSpinner, ~] = gcbo; % Get figure handle
    cont = get_existing_controller_name(true);
    was_scanning = cont.stop_image(false, false);
    cont.viewer.preset_mode = hSpinner.getValue;
    if was_scanning
        init = ~cont.shutter.status; %% if the shutter is closed, open it
        cont.live_image('fast', init);
    end
end