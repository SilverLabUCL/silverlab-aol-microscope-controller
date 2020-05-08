%% Generate a stack_params object for stack and tiles
% The stack_params object generated here can be used to control the limits
% of stacks, number of planes and/or spacing between planes. It can also
% control the averaging process (number and type of averages), the pockel
% cell Z-relation and some settings related to the tiling process
%
% -------------------------------------------------------------------------
% Syntax: 
%   stack_parameters = stack_params() 
%   stack_parameters = stack_params(controller)
%   stack_parameters = stack_params(controller,preset_setting,varargin)
%   stack_parameters = stack_params(controller,'',varargin)
%
%   See extra_notes for examples
% -------------------------------------------------------------------------
% Inputs: 
%   controller(Controller object) - Optional - Default ignores Controller:
%                                   Contains information about the
%                                   microscope setup such as FOV, dwell
%                                   time etc...
%
%   preset_setting(INT) - Optional - Default is 0:  
%                                   A stack preset that can be stored in
%                                   the code. Default is 0 which creates a
%                                   3 plane stack from +1 to -1µm with no
%                                   averages and the current pockel cell
%                                   values.
%                                   
%   varargin({'Argument',Value} pairs) - Optional:  
%                                   Any pair of argument and value pairs
%                                   from the following list
%   ---------
%           
%       {'init' (BOOL)} : Default is true
%                           If true, c.initialise() will be called at the
%                           beginning of the stack and c.finalise() in the 
%                           end. If false, the shutter is expected to be
%                           open beforehand.
% 
%       {'silent' (BOOL)} : Default is false.
%                           If false, the z position of each plane is 
%                           printed during the stack. Printing planes slow
%                           down Z-stacks
%
%       {'direction' (STR)} : Default is 'z' - any in {'x','y','z'}
%                           Defines the axis of the scan ('z' for Z-stacks)
%
%       {'tracking_selection' (Cell array of BOOL)} : Default is {true}
%                           This is only relevant when 'tracking_threshold'
%                           is > 0 or -1
%                           Defines which references are selected for the
%                           dynamic stack
%
%       {'tracking_threshold' (Cell array of INT)} : Default is {}
%                           If not empty, we use a dynamic scan system where we
%                           collect frames only when the cell fires.
%                           If -1, an input menu appears and ask for other
%                           values.
%                           If the cell fires above that threshold, we
%                           collect data during tracking_duration frames.
%
%       {'tracking_channel' (INT)} : Default is 1
%                           This is only relevant when 'tracking_threshold'
%                           is > 0 or -1
%                           Defines the channel to use for the cell activity
%                           tracking.
%
%       {'tracking_FOV' (Cell array of INT)} : Default is {}
%                           This is only relevant when 'tracking_threshold'
%                           is > 0 or -1
%                           Defines the FOV to use for each cell activity
%                           tracking.
%
%       {'tracking_soma_XYZ_loc' (Cell array of INT)} : Default is {}
%                           This is only relevant when 'tracking_threshold'
%                           is > 0 or -1
%                           Defines the location of each cell to track in
%                           X-Y-Z stage coordinates. A miniscan of size
%                           'tracking_FOV' is created around that point. 
%
%       {'tracking_duration' (INT)} : Default is 0
%                           This is only relevant when 'tracking_threshold'
%                           is > 0 or -1
%                           Defines the number of frames to collect every
%                           time the cell fires above 'tracking_threshold' 
%
%       {'tracking_batch_size' (INT)} : Default is 10
%                           This is only relevant when 'tracking_threshold'
%                           is > 0 or -1
%                           Defines the number of frames to collect every
%                           time the cell fires above 'tracking_threshold' 
%
%       {'tracking_standby_mode' (BOOL)} : Default is true
%                           This is only relevant when 'tracking_threshold'
%                           is > 0 or -1
%                           If true, then imaging will proceed only when
%                           threshold is passed. If false, a "negative
%                           stack" will be created with all the time period
%                           when the cell was < threshold. This can be used
%                           to substract background.
%
%       {'tracking_res' (INT} : Default is 50
%       `                   This is only relevant when 'tracking_threshold'
%                           is > 0 or -1
%                           The resolution of the tracking window for all 
%                           tracked cell. The smallest, the fastest.
%
%       {'tracking_rendering' (BOOL)} : Default is false
%                           If true, the ROI monitored is displayed,
%                           otherwise, only the current thr is displayed.
%                           Rendering = true slows down significantly the
%                           calculations.
% 
%       {'save_ref_traces' (BOOL)} : Default is false
%                           If true and you do an attentional stack, the
%                           raw trace of every references is saved in the
%                           experiment folder as a 'ref_traces.mat file 
%                           containing a [(n_ref+1) * n_timepoints] INT
%                           array. The first line is the timepoints.
%
%       {‘pockels_start', (FLOAT)} : Default is current pockel value;
%                           Determines the pockel value at the beginning 
%                           of the stack   
%  
%       {'pockels_stop' (FLOAT)} : Default is current pockel value;
%                           Determines the pockel value at the end of the 
%                           stack   
% 
%       {'interpolation_mode' (STR)} : Default is 'linear' - any in 
%           {'linear','exponential'}
%                           Determines the interpoaltion function for
%                           pockel values between the uppermost and
%                           lowermost points.
% 
%       {'dual_stack_aa' (FLOAT)} : Default 0.009 (9 mrad)
%                           Determines the acceptance angle of the dual 
%                           stack if limits are non defaults
%
%       {'dual_stack_dt' (FLOAT)} : Default 5e-8 (50 ns)
%                           Determines the dwell time of the dual stack if
%                           limits are non defaults
% 
%       {'dual_stack_res' (INT)} : Default 400
%                           Determines the resolution of the dual stack if
%                           limits are non defaults
%
%       {'use_default_stack_limits' (BOOL)} : Default is true
%                           If true, the stack will be acquired between 
%                           controller.xyz_stage.z_start and c
%                           controller.xyz_stage.z_stop. 
%                           If false, between params.stack_start and
%                           params.stack_stop
% 
%       {‘move_to_stack_center' (BOOL)} : Default is true
%                           If true, the stage will move in the middle of 
%                           the AOL z stack before starting. This is
%                           recommended for optimal image quality
% 
%       {'num_planes', (INT)} : Default is 1
%                           If use_default_stack_limits = false, this value
%                           is ignored.
%                           If use_default_stack_limits = true, then this 
%                           controls the number of planes of the Z-stack
%
%       {'stack_start' (FLOAT)} : Default is 0
%                           If use_default_stack_limits = false, this value
%                           is ignored.
%                           If use_default_stack_limits = true, then stack 
%                           starts here.
%  
%       {'stack_stop' (FLOAT)} : Default is 0
%                           If use_default_stack_limits = false, this value
%                           is ignored.
%                           If use_default_stack_limits = true, then stack 
%                           stops here.
%
%  
%       {'random_plane_order' (BOOL)} : Default is false
%                           If true, the order of the planes is randomised
%                           at each repeat
% 
%       {'averages', (INT)} : Default is 0
%                           Controls the number of extra frame per plane. 
%                           If > 0, then averages_method is used
%                           to post_process the multiple stacks
% 
%       {'averages_method', (STR)} : Default is 'mean'
%                           When doing frame averages, each frame
%                           is processed using that method. 
%                           options are 'mean', 'max', 'min', 'var',
%                           'median' or a function handle
%
%       {'repeats', (INT)} : Default is 1
%                           Controls the number of time the stack is
%                           acquired. If > 1, then averages_method is used
%                           to post_process the multiple stacks
% 
%       {'repeats_method', (STR)} : Default is 'mean'
%                           When doing stack repeats, the stack is 
%                           post-processed using that method. 
%                           options are 'mean', 'max', 'min', 'var',
%                           'median','special','equalize'
%
%       {'final_filter', (1X1 or 1X3 ODD INT)} : Default is 0. can
%                           If true, a median filter is applied to the
%                           final stack. It's a median filter so positive
%                           odd integers are expected. You can use a single
%                           Integer os specify the filtering box for each
%                           direction.
% 
%       {'flatten_fov' (BOOL)} : Default is false
%                           post_process the stack to flatten the fov,
%                           loading aom_calibration.mat file.
%
%       {'recast', (STR)} :  default is 'none', any in {'none','norm','pct',
%                           	'pct_per_channel','max_per_channel'}
%                           Method used to renormalize z stack. depending
%                           on the method, a value is expected for 
%                           'recast_value'. 
%                               'norm' divide by the brightest pixel
%                               'pct' saturate values to the upper and lower 
%                               percentile value specified
%                               'pct_per_channel' process each channel
%                               independently as for 'pct'
%                               'max_per_channel' process each channel
%                               independently as for 'norm'
%
%       {'recast_value', (1X1 or 1X3 ODD INT)} : Default is 1.  
%                           The value is ignored if 'recast' is 'none'
%                           otherwise, the value is used for the
%                           corresponding filter. 
%
%       {'channel', (1XN INT)} : Default is [1,2].  
%                           The index of the channels to keep. for example,
%                           [2] would only keep channel 2.
%
%       {'overlap_prct' (FLOAT)} : Default is 0 , in percent
%                           Between 0 and 100. This define the percentage
%                           of overlap between neigbouring tiles.
%
%       {'scan_mode' (INT)} : Default is 1
%                           This define the type of scan used for tiling. 1
%                           corresponds to the classical stack-by-stack
%                           tiling. 2 enables band scan tiling (vertical 
%                           scan and continuous motor movement)
%
%       {'show_preview' (INT)} : Default is 0
%                           If > 0, display a realtime preview of the
%                           defined channel
%
%       {'plot' (BOOL)} : Default is true
%                           Display a quick matlab preview of the acquired
%                           stack
%
%       {'save_name' (BOOL)} : Default is ''
%                           If not empty, then the stack will be save using
%                           the provided name. 
% -------------------------------------------------------------------------
% Outputs:
%
% stack_parameters(stack_params STRUCT) : 
%                                   Struct containing all the stack
%                                   options required to do stacks and tiles
%
% -------------------------------------------------------------------------
% Extra Notes:
% -------------------------------------------------------------------------
% Examples:
%
% * Generate a default stack_params object
%   stack_parameters = stack_params();
%
% * Generate a default stack_params object, updated with preset values
%   stack_parameters = stack_params('',preset);
%
% * Generate a default stack_params object, updated with preset values,
%   further updated with extra varargin
%   stack_parameters = stack_params('',preset,varargin);
%
% * Generate a stack_params object based on controller.stack_params
%   stack_parameters = stack_params(c);
%
% * Generate a stack_params object based on controller.stack_params,
%   updated with preset values
%   stack_parameters = stack_params(c,preset);
%
% * Generate a stack_params object based on controller.stack_params,
%   updated with preset values, further updated with extra varargin
%   stack_parameters = stack_params(c,preset,varargin);
%
% In any case, if varargin{1} is already a stack_params object, it will
% be used instead of the controller one
%
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
%   18-03-2019
%
% See also: unwrap_parameters, update_param_and_check_condition, 
% check_names_validity, update_gui_from_stack_params,
% update_stack_params_from_gui, StackAndTiles, XyzStage

%% TODO : Band scan related option must be verified
% - qq scan_mode(FLOAT). For band scan. to be checked
% - We could have a 'calibration' preset
% - Need a set method for default limit, so that when we set it to 1, it
% erases the stck_start and stack_stop linits.
% - convert to class

function stack_parameters = stack_params(controller, preset_setting, varargin)
    if nargin < 2 || isempty(preset_setting) 
        preset_setting = '';
    end
    if nargin < 3 || isempty(varargin)
        varargin = {};
    end

    %% Check if the stack params is based on the current controller.stack_params
    if ~isempty(varargin) && ~isempty(varargin{1}) && isstruct(varargin{1}) % If first varargin contains a stack_params, use it instead of current controller
        % Carry on
    elseif nargin >= 1 && ~isempty(controller)
        if ~isa(controller, 'Controller')
            error('first argument must be a Controller handle')
        end
        varargin = {controller.stack_params, varargin{:}};
    else
        controller = '';
    end
    
    %% Update with a preset setting for the relevant fields
    if ~isempty(preset_setting) && isnumeric(preset_setting)
        %% Create a default stack params
        stack_parameters = default_stack(controller, varargin);
        
        if preset_setting == 1
            stack_parameters = default_stack(controller,stack_parameters,'repeats',1,'averages',8,'pockels_start',0.5,'pockels_stop',0.5);
        end

        if preset_setting == 2
            stack_parameters = default_stack(controller,stack_parameters,'repeats',8,'averages',1,'pockels_start',1,'pockels_stop',1);
        end   

        if preset_setting == 3
            stack_parameters = default_stack(controller,stack_parameters,'use_default_stack_limits',false,'stack_start',-5,'stack_stop',5);
        end 

        if preset_setting == 4
            stack_parameters = default_stack(controller,stack_parameters,'overlap_prct',20,'averages',4);
        end 

        if preset_setting == 5 %skeleton scan
            stack_parameters = default_stack(controller,stack_parameters,'averages',8,'plot',false);
        end
        
        if ~isempty(varargin) && ~isempty(varargin{1}) && isstruct(varargin{1}) % If first varargin contains a stack_params, replace it with the newly generated one
            varargin{1} = stack_parameters;
        else
            varargin = {stack_parameters, varargin{:}};
        end
    end
    
    %% Now updated with any additional input
    stack_parameters = default_stack(controller, varargin);
end

function parameters = default_stack(controller, varargin)

        [parameters, varargin, update] = unwrap_parameters(varargin);

        %% Check validity of the parameter names
        Arguments_list = {  'init','silent','direction',... 
                            'tracking_selection','tracking_threshold','tracking_channel','tracking_FOV','tracking_soma_XYZ_loc','tracking_rate','tracking_batch_size','tracking_standby_mode','tracking_res','tracking_rendering', 'save_ref_traces'...
                            'pockels_start','pockels_stop','interpolation_mode',... 
                            'dual_stack_aa','dual_stack_dt','dual_stack_fov',...
                            'use_default_stack_limits','move_to_stack_center','num_planes','stack_start','stack_stop',... 
                            'averages','averages_method','repeats','repeats_method','final_filter', 'flatten_fov',...
                            'recast','recast_value','channel',... 
                            'overlap_prct','scan_mode',... 
                            'show_preview','plot','save_name'}; 

        if isempty(controller) || isempty(controller.pockels)
            default_pockels = 0;  
        else
            default_pockels = controller.pockels.on_value;  
        end

        %% General scan options 
        parameters = update_param_and_check_condition('init','init',true,update,varargin,parameters,'bool');
        parameters = update_param_and_check_condition('silent','silent',false,update,varargin,parameters,'bool');
        parameters = update_param_and_check_condition('direction','direction','z',update,varargin,parameters,{'x','y','z'});        
                
        %% Special features
        parameters = update_param_and_check_condition('tracking_selection','tracking_selection',{1},update,varargin,parameters, 'cell');  
        parameters = update_param_and_check_condition('tracking_threshold','tracking_threshold',{},update,varargin,parameters,'cell');  
        parameters = update_param_and_check_condition('tracking_channel','tracking_channel',1,update,varargin,parameters,'int');  
        parameters = update_param_and_check_condition('tracking_FOV','tracking_FOV',{},update,varargin,parameters,'cell');  
        parameters = update_param_and_check_condition('tracking_soma_XYZ_loc','tracking_soma_XYZ_loc',{},update,varargin,parameters,'cell');  
        parameters = update_param_and_check_condition('tracking_rate','tracking_duration',0,update,varargin,parameters,'int');  
        parameters = update_param_and_check_condition('tracking_batch_size','tracking_batch_size',10,update,varargin,parameters,'int');  
        parameters = update_param_and_check_condition('tracking_standby_mode','tracking_standby_mode',true,update,varargin,parameters,'bool');  
        parameters = update_param_and_check_condition('tracking_res','tracking_res',50,update,varargin,parameters,'int');  
        parameters = update_param_and_check_condition('tracking_rendering','tracking_rendering',false,update,varargin,parameters,'bool');  
        parameters = update_param_and_check_condition('save_ref_traces','save_ref_traces',false,update,varargin,parameters,'bool');  

        %% Pockel related options
        parameters = update_param_and_check_condition('pockels_start','pockels_start',default_pockels,update,varargin,parameters,'float');
        parameters = update_param_and_check_condition('pockels_stop','pockels_stop',default_pockels,update,varargin,parameters,'float');
        parameters = update_param_and_check_condition('interpolation_mode','interpolation_mode','linear',update,varargin,parameters,{'linear','exponential'}); %1 for linear, 2 for exponential

        %% Dual stack related options
        % default values are here to maximise FOV, to see big features (eg. soma)
        parameters = update_param_and_check_condition('dual_stack_aa','dual_stack_aa',0.008,update,varargin,parameters,'float'); % default is 9mrad
        parameters = update_param_and_check_condition('dual_stack_dt','dual_stack_dt',1e-7,update,varargin,parameters,'float'); % default is 50ns
        parameters = update_param_and_check_condition('dual_stack_res','dual_stack_res',512,update,varargin,parameters,'int'); % default is 400pxl

        %% Stage & stack limits related options
        % optional values, used if parameters.use_default_stack_limits == false
        parameters = update_param_and_check_condition('use_default_stack_limits','use_default_stack_limits',true,update,varargin,parameters,'bool');
        parameters = update_param_and_check_condition('move_to_stack_center','move_to_stack_center',true,update,varargin,parameters,'bool');
        parameters = update_param_and_check_condition('num_planes','num_planes',1,update,varargin,parameters,'int');
        parameters = update_param_and_check_condition('stack_start','stack_start',0,update,varargin,parameters,'float');
        parameters = update_param_and_check_condition('stack_stop','stack_stop',0,update,varargin,parameters,'float');
        parameters = update_param_and_check_condition('random_plane_order','random_plane_order',false,update,varargin,parameters,'bool');

        %% Stack and plane averaging options
        parameters = update_param_and_check_condition('averages','averages',0,update,varargin,parameters,'int');
        parameters = update_param_and_check_condition('averages_method','averages_method','mean',update,varargin,parameters,{'mean','max','min','median','var','@'});
        parameters = update_param_and_check_condition('repeats','repeats',1,update,varargin,parameters,'int');
        parameters = update_param_and_check_condition('repeats_method','repeats_method','mean',update,varargin,parameters,{'mean','max','min','median','var','special','equalize'});
        parameters = update_param_and_check_condition('final_filter','final_filter',false,update,varargin,parameters,'bool');
        parameters = update_param_and_check_condition('flatten_fov','flatten_fov',false,update,varargin,parameters,'bool');

        %% Post processing recasting options
        parameters = update_param_and_check_condition('recast','recast','none',update,varargin,parameters,{'none','norm','pct','pct_per_channel','max_per_channel'});
        parameters = update_param_and_check_condition('recast_value','recast_value',1,update,varargin,parameters,'float');
        parameters = update_param_and_check_condition('channel','channel',[1,2],update,varargin,parameters,'int');

        %% Tiling options
        parameters = update_param_and_check_condition('overlap_prct','overlap_prct',0,update,varargin,parameters,'float');
        parameters = update_param_and_check_condition('scan_mode','scan_mode',1,update,varargin,parameters,'int'); %1for tiles, 2 for bands with motor drift
        
        %% Rendering options
        parameters = update_param_and_check_condition('show_preview','show_preview',0,update,varargin,parameters,'int'); %0 for no preview, 1 or 2 to see channel 1 or 2
        parameters = update_param_and_check_condition('plot','plot',true,update,varargin,parameters,'bool');
        parameters = update_param_and_check_condition('save_name','save_name','',update,varargin,parameters,'str');

        if any([parameters.stack_start,parameters.stack_stop])
            parameters.use_default_stack_limits = false;
        end

        if parameters.overlap_prct < 0 || parameters.overlap_prct >=100
            error('overlap must be between 0% and 100% (excluded)')
        end    

        check_names_validity(Arguments_list,varargin);
end 