%% Generic stack function. Input handle 'func' defines stack type
% This function is internally used. You should call it through an AOL or
% motor stack function as it requires a function handle.
% -------------------------------------------------------------------------
% Syntax: 
%   stack = stack_generic(controller, func, stack_params, initial_scan_params)
%
% -------------------------------------------------------------------------
% Inputs: 
%   controller(Controller object) - Optional - Default is main Controller:
%                                   Contains information about the
%                                   microscope setup such as FOV, dwell
%                                   time etc...
%
%   func(function handle) 
%                                   The function that will be called
%                                   at each plane. This function is
%                                   expected to control the plane to scan 
%                                   and/or the stage position.
%
%   stack_parameters(stack_params object)
%                                   Define the stack properties.
%
%   initial_scan_params(stack_params object) - Optional - default is
%                                   the initial Controller.scan_params
%                                   You can pass any desired final state of
%                                   the scan. This can be useful
% -------------------------------------------------------------------------
% Outputs:
%
% 	stack(Cell array of {[X * Y * Z * NChannels] DOUBLE}) : 
%                                   - When not using dynamic stack, one 
%                                   cell containing a 4D matrix :
%                                   X = Controller.scan_params.mainscan_x_pixel_density
%                                   Y = Controller.scan_params.num_drives
%                                   Z = stack_parameters.num_planes
%                                   NChannels = number of channel acquired
%                                               by timed_image
%
% -------------------------------------------------------------------------
% Extra Notes:
% * For stack fine control, many options are available. Check stack_params
%   for detailed explanations.
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
%   12-10-2018
%
% See also: aol_stack, motor_stack, test_z_scaling, stack_post_processing
%

% TODO : 
%- not sure about the resolution part. Maybe we should use mainscan values 
%- for y rotation, we can chose between linear and nonlinear drives

function mean_stack = stack_generic(controller, func, stack_params, initial_scan_params)
    if nargin < 1 || isempty(controller)
        controller = get_existing_controller_name(true);
    end
    %% qq Add missing default values
    if nargin < 4 || isempty(initial_scan_params)
        initial_scan_params = controller.scan_params;       
    end
    
    initial_stage_position = controller.xyz_stage.get_position();
    initial_pockel_value = controller.pockels.on_value(); 

    %% Cleanup handle called at the end of the function or if stack is interrupted
    global well_done_stack
    well_done_stack = false;
    cleanupObj = onCleanup(@() cleanMeUp(controller, initial_scan_params, initial_stage_position, initial_pockel_value, stack_params));
    
    %% Initialise controller for first plane of first trial
    controller.initialise();
    
    %% Update stack_params from controller xyz stage limits
    stack_params = get_stack_params_limits_from_controller(controller, stack_params);
    controller.encoder.trigger.use_trigger       = 0;
    controller.ttl_trigger.use_trigger           = 0;
    controller.viewer.plot_background_mc         = 0;
    controller.rig_params.log_bkg_mc             = 0;    
    
    %% Initialise variables
    dynamic_mode    = ~isempty(stack_params.tracking_threshold);
    plane_position  = linspace(stack_params.stack_start, stack_params.stack_stop, stack_params.num_planes); %most likely z_position, but it depends on the input function
    poc_val         = set_pockels_range(controller, stack_params, plane_position); % Get a list of pockel values for each plane
    res_x           = controller.scan_params.mainscan_x_pixel_density; 
    res_y           = size(controller.scan_params.voxels_for_ramp, 2); %Resolution in AOL referentiel
    ncycle          = stack_params.averages+1;
    total_frames    = stack_params.repeats * stack_params.num_planes*ncycle;
    elapsed         = tic;   
    total_counter   = zeros(1,1);
    
    %% Preallocate memory for positive & dynamic stack
    positive_stack               = {zeros(res_x, res_y, stack_params.num_planes, 2, stack_params.repeats, 'single')};
  
    %% Iterate though planes and get data
    for r = 1:stack_params.repeats
        if ~stack_params.silent
            fprintf('########## stack %d/%d ############\n',r , stack_params.repeats)
        end
        plan_completed      = false(1, stack_params.num_planes);
        reuse_viewer        = 0; % we always reuse viewer except for the first scan
        global_counter      = 0;
        counter             = 1; % count the numer of plane that have been done
        plane_order         = 1:stack_params.num_planes;
        if stack_params.random_plane_order % Randomize plane order if required, for each trial
            plane_order     = plane_order(randperm(stack_params.num_planes));
        end
        
        while ~all(plan_completed)
            plane_num = plane_order(counter);
            set_current_stack_plane(controller, poc_val, plane_position, plane_num, plane_order, func);
            positive_stack{1}(:,:,plane_num,:,r) = controller.single_record(stack_params.averages, reuse_viewer, stack_params.averages_method); % First plane create the holder. next ones will just reset it
            plan_completed = (counter == abs(stack_params.num_planes));
            counter = counter + 1;
            status = 1;
            total_counter = total_counter+ncycle;
            print_message(controller, dynamic_mode, status, global_counter, total_counter, total_frames, plane_position, poc_val, plane_num,r, elapsed);

            %% DataHolder should now be fine
            reuse_viewer = 1;
        end
    end

    %% Finalise Scan - Resume MC if required
    cleanMeUp(controller, initial_scan_params, initial_stage_position, initial_pockel_value, stack_params);
    well_done_stack = true; % If the code didn't crash, cleanup handle will be ignored upon exit
    
    %% Do any required computation
    mean_stack = {nanmean(positive_stack{1}, 5)};
    
    %% Show final result once finished.
    if stack_params.plot
        cellfun(@(x) show_stack(x), mean_stack(1), 'UniformOutput', false);
    end
    
    %% Save stack
    if ~isempty(stack_params.save_name)
        fprintf('Saving z stack...Please wait\n');
        name = stack_params.save_name;
        stack = mean_stack{1};
        save_stack(stack, name, controller, 16, 'matlab', {stack_params.recast,stack_params.recast_value}, stack_params);
        fprintf(['Stack saved as ',name,'\n']);
    end
end


%% Subfunctions

function cleanMeUp(controller, initial_scan_params, initial_stage_position, initial_pockel_value, stack_params)
    global well_done_stack
    
    if ~well_done_stack
        % Restore initial angles and offsets. Resume bkg MC
        controller.scan_params = initial_scan_params; % Restore initial Scan params
        controller.send_drives(false, initial_pockel_value); % Send the previous drives

        % Move the stage in the end. Better to do that after resuming bkg MC
        controller.xyz_stage.move_abs(initial_stage_position);

        % Finalise if all stacks are done. Set it to false if MC
        if stack_params.init
            controller.finalise();
        end
    end
end 

function stack_params = get_stack_params_limits_from_controller(controller, stack_params)
    % Use either controller.xyz_stage range or stack_params limits
    if stack_params.use_default_stack_limits == true % if false, z range is read from stack_params
        %stack_params.num_planes = abs(controller.xyz_stage.z_planes);
        if stack_params.num_planes > 1
            stack_params.stack_start = controller.xyz_stage.z_start;
            stack_params.stack_stop  = controller.xyz_stage.z_stop;
        else
            stack_params.stack_start = (controller.xyz_stage.z_start+controller.xyz_stage.z_stop)/2;
            stack_params.stack_stop  = (controller.xyz_stage.z_start+controller.xyz_stage.z_stop)/2;
        end
    else
        % pass - uses stack_params limits
    end
end

function poc_val = set_pockels_range(controller, stack_params, plane_position)
    if stack_params.use_default_stack_limits == true % if false, pockel range is read form stack_params
        poc_val = controller.xyz_stage.get_pockels_vs_Z_values( stack_params.interpolation_mode,...
                                                                stack_params.pockels_start,...
                                                                stack_params.pockels_stop,...
                                                                plane_position); % QQ possibly not ok for non z stacks if stack_params.pockels_start and stack_params.pockels_stop are different
    else
       xyz = StackAndTiles();
       xyz.z_stop = stack_params.stack_stop;
       xyz.z_start = stack_params.stack_start;
       poc_val = xyz.get_pockels_vs_Z_values(   stack_params.interpolation_mode,...
                                                stack_params.pockels_start,...
                                                stack_params.pockels_stop,...
                                                plane_position); % QQ possibly not ok for non z stacks if stack_params.pockels_start and stack_params.pockels_stop are different
    end
end

function set_current_stack_plane(controller, poc_val, plane_position, plane_num, plane_order, func)
    % Update pockel value for the next plane
    controller.pockels.on_value = poc_val(plane_num);            

    % Set imaging plane (aol offset or motor mvt), send new drives
    func(round(plane_position(plane_num)), plane_num == plane_order(1)); % first plane create the dataholder and stop any bkg mc
end

function print_message(controller, dynamic_mode, status, global_counter, total_counter, total_frames, plane_position, poc_val, plane_num,r, elapsed, UItable_lines)
    %% Print message about current plane. Try to estimate remaining stack duration
    if dynamic_mode
        if ~controller.stack_params.silent && ~status && ~mod(global_counter, 30)% ~stack_params.tracking_standby_mode 
            fprintf(sprintf('    - value below threshold at plane position %5.1f. Stack %2.0f/%2.0f - \n',plane_position(plane_num),r,controller.stack_params.repeats));
        elseif status && ~controller.stack_params.silent
            p = floor(min(100, total_counter/total_frames*100));
            remaining = toc(elapsed) * (100/mean(p) - 1); 
            fprintf('Plane position is %5.1f and pockel value is %2.3f. Stack %2.0f/%2.0f. %3.1f%% of the stack done. (%.2fs left)\n',plane_position(plane_num),poc_val(plane_num),r,controller.stack_params.repeats, mean(p), remaining);
            if isvalid(controller.gui_handles)
                controller.gui_handles.UITable2.Data(UItable_lines,8) = cellfun(@(x) strcat(num2str(x),'%'), num2cell(p), 'UniformOutput', false);
            end
        end
    elseif ~controller.stack_params.silent
        remaining = toc(elapsed) * (total_frames/total_counter(1) - 1);
        fprintf('Plane position is %5.1f and pockel value is %2.3f. Stack %2.0f/%2.0f. %3.0f%% of the stack done. (%.2fs left)\n',plane_position(plane_num),poc_val(plane_num),r,controller.stack_params.repeats, total_counter(1)/total_frames * 100, remaining);
    end
end