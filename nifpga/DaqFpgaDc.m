%% DaqFpgaAc/DaqFpgaDc/DaqFpgaAcc subclass for the Acquisition system
%	The class allow data acqusition, and hardware communication. It uses a
%   NI CAPI to communicate with the hardware.
%
%   Type doc function_name or help function_name to get more details about
%   the function inputs and outputs
%
% -------------------------------------------------------------------------
% Syntax: 
% daq_fpga = DaqFpga()
%       Object contructor
%
% DaqFpga.delete();
%       Object destructor
% -------------------------------------------------------------------------
% Extra Notes:
% * To get detailled information about a function, use the matlab doc or 
%   help function.
% -------------------------------------------------------------------------
% Examples:
% -------------------------------------------------------------------------
%                               Notice
%
% Author(s): Antoine Valera, Boris Marin, Geoffrey Evans, Vicky Griffiths, 
%            Srinivas Nadella, Sameer Punde
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
%   16-03-2019
%
% See also: DaqFpga, NiFpga2Matlab

classdef DaqFpgaDc < DaqFpga
    methods
        function obj = DaqFpgaDc(target)
            obj.capi = CFPGADAQ_variable_length_matlab_v13(target);
            obj.capi.open('norun');
            obj.capi.run('nowait');
        end
    end
end