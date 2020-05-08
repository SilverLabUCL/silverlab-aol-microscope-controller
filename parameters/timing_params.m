%% Control acquisition options for timed_image
% This function creates an timing_params object that can be used for 
% to control acquisition options such as duration, number of repetions,
% inter-trial pause etc...
% varargin extra options must be in the format {'Argument',Value} except 
% the very first one which can be a former parameters object.
% Argument is always a string. Value type change depending on the parameter.
%
% -------------------------------------------------------------------------
% Syntax: 
%   parameters = timing_params()
%   parameters = timing_params( 'Argument1', Value1,...
%                               'Argument2', Value2)
%
% Passing a previous set of parameters first will adjust the default.
% Passing any extra {'Argument', Value} pair update the initial parameters
% object set as a first argument.
%
% -------------------------------------------------------------------------
% Inputs:                                
%   varargin({'Argument',Value} pairs) - Optional:  
%                                   Any pair of argument and value pairs
%                                   from the following list
%   ---------
%           
%        {'duration’ OR 'recording_time_sec' (FLOAT)}: Default is 1.
%                            Recording duration in seconds. Important for
%                            figure rendering and data cropping.
%           
%        {'number_of_cycles’ (INT)}: Default is 0.
%                            Define the number of acquisition cycles
%
%        {'repeats’ (INT)}: Default is 1.
%                            Number of trials to record, each one of the 
%                            same duration, seperated by 'pause' seconds
%                            
%        {'pause’ (FLOAT)}: Default is 1.
%                            Pause in second between 2 successive repeats
%   
%        {'reuse_viewer’ (BOOL)}: Default is false.
%                            If true, the DataHolder is not regenerated.
%                            You should do it only if you are sure that
%                            the number of Data points and/or the shape of
%                            the frame to collect remain unchanged (for
%                            example between planes in a Z-stack)
%
%        {'no_interrupt’ (BOOL)}: Default is false.
%                            If true, FIFO won't be flushed and triggers
%                            won't be fired. You should set it to true when
%                            you have to chain very quickly multiple
%                            acquisition (except for the first call). For
%                            example, in a Z stack, set no_interrupt to
%                            false for the first plane, then set it to true
%                            for the following ones. 
%
%        {'dump_data’ (BOOL)}: Default is false.
%                            If true, data is not held i memory, but dumped
%                            on a bi file during timed_image, and recovered
%                            at the end of the recording. Use this option
%                            for long recordings or short intertrial
%                            intervals, if your hard drive is fast enough
%   
%        {'MC’ (BOOL)}: Default is false.
%                            If true, make sure that MC is running when the
%                            recording starts. If MC is true, the overhead
%                            of the MC system is taken into account when 
%                            calculating the numer of cycles required for
%                            recording of a fixed duration.
%
%        {'monitor_MC’ (BOOL)}: Default is false.
%                            If true, a movement correction log is 
%                            collected during data acquisition. 
%
% -------------------------------------------------------------------------
% Outputs:
%
% parameters(timing_params STRUCT) : 
%                                   Struct containing all the acquisition
%                                   options required to for timed_image
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
%   15-04-2020
%
% See also: initialise_timed_image, imaging.timed_image

%% TODO
% - convert to class

function parameters = timing_params(varargin)
    [parameters,varargin,update] = unwrap_parameters(varargin);

    %check validity of the parameter name
    Arguments_list = {'recording_time_sec','duration','repeats','pause','MC','number_of_cycles','reuse_viewer','no_interrupt','dump_data','monitor_MC'}; 

    %% Timing for functional acquisition 
    parameters = update_param_and_check_condition({'recording_time_sec','duration'},'recording_time_sec',1,update,varargin,parameters,'float');
    parameters = update_param_and_check_condition('number_of_cycles','number_of_cycles', 0, update,varargin,parameters, 'int');%if sepcified, will overwrite duration
    parameters = update_param_and_check_condition('repeats','repeats',1,update,varargin,parameters,'int'); %1 means single recording
    parameters = update_param_and_check_condition('pause','pause',1,update,varargin,parameters,'float');
    parameters = update_param_and_check_condition('reuse_viewer','reuse_viewer',0,update,varargin,parameters,'bool');
    parameters = update_param_and_check_condition('no_interrupt','no_interrupt',0,update,varargin,parameters,'bool');
    parameters = update_param_and_check_condition('dump_data','dump_data',false,update,varargin,parameters,'bool');
    parameters = update_param_and_check_condition('monitor_MC','monitor_MC',false,update,varargin,parameters,'bool');

    if ~isfield(parameters,'dump_data')
    	parameters.dump_data = false;
    end
    
    if ~isfield(parameters,'duration')
        parameters.duration = parameters.recording_time_sec; %some code still uses that
    elseif ~isfield(parameters,'recording_time_sec')
    	parameters.recording_time_sec = parameters.duration; %some code still uses that  
    end

    %% Movement correction
    parameters = update_param_and_check_condition('MC','MC',false,update,varargin,parameters,'bool');

    check_names_validity(Arguments_list,varargin);
end    