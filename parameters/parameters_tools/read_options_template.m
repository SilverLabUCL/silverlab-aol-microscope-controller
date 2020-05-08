%% Whatever options it controls
% This function creates an XXX object that can be used for 
% to XXX.
% varargin extra options must be in the format {'Argument',Value} except 
% the very first one which can be a former parameters object.
% Argument is always a string. Value type change depending on the parameter.
%
% -------------------------------------------------------------------------
% Syntax: 
%   parameters = read_options_template()
%   parameters = read_options_template( 'Argument1', Value1,...
%                                       'Argument2', Value2)
%   parameters = read_options_template( previous_parameters,...
%                                       'Argument1', Value1,...
%                                       'Argument2', Value2)
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
%        {'param1' (any type)}: Default is 0.
%                            blablabla
%   
%        {'param2' (ROUND VALUE (LOGICAL or INT or FLOAT))}: Default is 8
%                            blablabla
% 
%        {'param3' (ANY NUMERICAL)}: Default is '1.6'
%                            blablabla
%
%        {'param4' (ANY LOGICAL)}: Default is 'true'.
%                            blablabla
%
%        {'param5' (STR or CHAR)}: Default is ''text''.
%                            blablabla
%
%        {'param6' (ANY EVALUABLE)}: Default is ''[1,2,3]''.
%                            blablabla
%
%        {'param7' (ANY STR IN THE LIST)}: Default is '{'any','series','of','str'}'.
%                            blablabla
% -------------------------------------------------------------------------
% Outputs:
%
% parameters(file_params STRUCT) : 
%                                   Struct containing all the file
%                                   options required to do a skeleton scan
%                                   or a skeleton scan modelling task
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
%   done on 13-03-2018 
%
% See also: unwrap_parameters, update_param_and_check_condition, 
% check_names_validity
%

% TODO :


function parameters = read_options_template( varargin )

%% always start with that line
[parameters,varargin,update] = unwrap_parameters(varargin);
%--------------------------------------------------------------------------
% Do not edit above that line



%% set your argument names here. They must match the first argument of the following lines
Arguments_list = {'param1','param2','param3','param4','param5','param6','param7'};

%% add you options here
parameters = update_param_and_check_condition('param1','free_param',0,update,varargin,parameters);
parameters = update_param_and_check_condition('param2','int_param',8,update,varargin,parameters,'int');
parameters = update_param_and_check_condition('param3','float_param',1.6,update,varargin,parameters,'float');
parameters = update_param_and_check_condition('param4','bool_param',1,update,varargin,parameters,'bool');
parameters = update_param_and_check_condition('param5','str_param','text',update,varargin,parameters,'str');
parameters = update_param_and_check_condition('param6','evaluable_object','[1,2,3]',update,varargin,parameters,'obj');
parameters = update_param_and_check_condition('param7','cell_array_param',{'any','series','of','str'},update,varargin,parameters,{'any','series','of','str'});

%% add extra rules here
%
%


% Do not edit below that line
%--------------------------------------------------------------------------
%% finish with that line
check_names_validity(Arguments_list,varargin)

end

