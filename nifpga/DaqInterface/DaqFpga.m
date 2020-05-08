%% DaqFpgaAc/DaqFpgaDc/DaqFpgaAcc subclass for the Acquisition system
%   The class allows data acquisition, and hardware communication. It uses
%   a NI CAPI to communicate with the hardware.
%
%   Type doc function_name or help function_name to get more details about
%   the function inputs and outputs
% -------------------------------------------------------------------------
% Syntax: 
%   this = DaqFpga()
% -------------------------------------------------------------------------
% Class Generation Inputs:
% -------------------------------------------------------------------------
% Class Methods:  
% * Object contructor
%   daq_fpga = DaqFpga()
%
% * Object destructor
%   DaqFpga.delete();
% -------------------------------------------------------------------------
% Extra Notes:
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
% See also: data_acquisition, FIFO_initialisation, update_daq_parameters, 
%   DaqFpgaDc

classdef DaqFpga < FIFO_initialisation & update_daq_parameters & data_acquisition

    properties
        %% General NI-DAQ Settings
        status                      = false         ;   % If 1, system is online and connected to Hardware. If 0, you are offline or in demo mode                                 
        capi                        = []            ;   % NI board variables, held in structure. 

        %% MC-related settings
        daq_mc_ready                = false         ;   % Set to true once MC drives were set correctly
        controller_mc_ready         = false         ;   % Set to true once MC drives were sent to the AOL controller correctly
        is_ready_to_correct         = false         ;   % Set to true once the drives for mc were sent to the controller AND the daq. Stays true as long as you do not update mc_drives
        use_movement_correction     = false         ;   % If true, and if is_ready_to_correct is true, then the DAQ will be in MC mode
        use_z_movement_correction   = false         ;   % If true and mc starts, it will use ZMC
        is_correcting               = false         ;   % If the system is correcting, either while imaging or in bkg
        MC_rate                     = 2             ;   % MC refresh rate, in ms (or once per cycle if cycle length is less than MC_rate)
        mc_roi_size                 = []            ;   % MC (Y*X) or (Y*X + Z*X) size in pixel, the number of lines of the hostfifo ref
        
        %% Imaging controls and flags
        live_rendering_mode         = 0             ;   % Define the set of FIFO that are read (among data0, data1 and HOSTFIFO)
        is_imaging                  = false         ;   % If the system is imaging. If obj.capi.background_mc is true, then obj.is_imaging is false
    end
    
    methods
        function obj = DaqFpga()
            %% Object constructor
            % -------------------------------------------------------------
            % Syntax: 
            %   obj.DaqFpga()
            % -------------------------------------------------------------
            % Inputs: 
            % -------------------------------------------------------------
            % Outputs:
            % -------------------------------------------------------------
            % Extra Notes: 
            % -------------------------------------------------------------
            % Author(s):
            %   Geoffrey Evans, Boris Marin, Antoine Valera.
            %---------------------------------------------
            % Revision Date:
            %   23-03-2018
            
            obj.status = NiFpga(uint32(0)); % initialise
            if obj.status < 0 % NI errors have an error code < 0
                return;
            else
                %% Good to go
            end
        end
        
        function delete(obj)
            %% Object destructor
            % -------------------------------------------------------------
            % Syntax: 
            %   DaqFpga.delete()
            % -------------------------------------------------------------
            % Inputs: 
            % -------------------------------------------------------------
            % Outputs:
            % -------------------------------------------------------------
            % Extra Notes: 
            % -------------------------------------------------------------
            % Author(s):
            %   Geoffrey Evans, Boris Marin, Antoine Valera.
            %---------------------------------------------
            % Revision Date:
            %   23-03-2018
            
            if obj.status == 0 && ~check_caller({'uiimport','uiopen','rescale_tree','load'}) % every load function is excluded! (load_previous_session_params, load_header, load_experiment etc...)
                delete(obj.capi);
                NiFpga(uint32(1)); %finalise
            end
        end  
    end
end