%% Main Controller Class. Links modules for data acquisition and Analysis
% This is the main Class for both data acquisition or analysis. The
% SilvrLab compact AOL microscope Controller can be used for data analysis 
% and/or data acquisition. A GUI was developped to improve the experience 
% and help with the complex combinations of options and settings that may
% be required to run experiments smoothly. However, almost all function 
% can be called directly in command line or in scripts. 
% 
% Documentation can be found in function, and in the toolbox documentation,
% available both Online on GitHub and in the ./docs folder
%
% Before first use, you may have to configure computer specific paths
% ./Core/configuration_file_path.ini
% ./Core/+default/setup.ini
% ./Core/+default/calibration.ini
% This is particularly critical for data acquisition
%
% Type doc Controller or help Controller to get more details about
% the function inputs outputs, methods, properties and fields.
% -------------------------------------------------------------------------
% Syntax: 
%   this = Controller(online, varargin)
% -------------------------------------------------------------------------
% Class Generation Inputs: 
%
%   online (BOOL) - Optional - Default is false :
%       Define if you want to run the controller in acquisition and 
%       analysis mode (online) or just in analysis mode (offline). Online 
%       mode require setup.ini to be configured correctly, and the com ports
%       to be available. If one of the com port does not repond, the 
%       Controller generation will fail and you may have to restart Matlab.
%
%   varargin (BOOL) 
%       nothing yet
% -------------------------------------------------------------------------
% Outputs: 
%   this (Controller object)
%       The object containing all the acquisition environnement
%       Do NOT, EVER, overwrite this variable, or you will delete the
%       Controller
% -------------------------------------------------------------------------
% Class Methods: 
%
% * Fix Matlab paths to have all the folder and subfolders
%   adjust_paths(this)
%
% * Update current_expe_folder. Critical for Skeleton scan tools
%   set_expe_folder(this, expe_folder)
%
% * Class destructor. 
%   delete(this)
% -------------------------------------------------------------------------
% Extra Notes:
%
% * The function will create a Controller object if it doesn't exist. It 
%   will create the required daq sessions (based on setup.ini values and 
%   online/offline flag). 
%
% * Your Matlab paths will be updated to make sure that all functions and 
%   folders are accessible. If a controller already exist you can start the
% 	GUI without having to restart everything.
%
% * Configuration is based on Setup.ini so make sure that paths, connection
%   ports, mac and ip addresses are correct. If a hardware is not required,
%   set its AVAILABLE? value to FALSE
% -------------------------------------------------------------------------
% Examples:
%
% * Start the Controller for data acquisition, with the GUI
%   c = Controller(true, true); 
%
% * Start the Controller for data analysis, with the GUI
%   c = Controller(false, true); 
%
% * Start the Controller for data acquisition, without any GUI
%   c = Controller(true, false); 
%
% * Start the Controller for data analysis, without any GUI
%   c = Controller(false, false); 
% -------------------------------------------------------------------------
%                               Notice
%
% Author(s): Antoine Valera, Geoffrey Evans, Boris Marin. 
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
%   24-03-2018
%            
% See also: imaging, movement_correction, drives, stage_control, 
%   DaqFpgaDc, SynthFpga, ScanParams, AolParams, StackParams,
%   Base, viewer_params, rig_params, XyzStage, StackAndTiles, Prechirper,
%   Laser, WheelLog, PockelsCell, Pmt, HardShutter, Trigger

classdef Controller < handle & imaging & drives & movement_correction & stage_control
    properties
        online = false      ; % Boolean for online/offline mode
        
        %% Hardware classes
        rig_params          ; % Hardware settings and info from setup.ini
        daq_fpga            ; % NI interface for data acqusition and MC
        synth_fpga          ; % Ethernet session and DaQ controller com
        red_pmt             ; % DaQ session and methods for red PMT
        green_pmt           ; % DaQ session and methods for green PMT
        pockels             ; % DaQ session and methods for pockel control
        shutter             ; % DaQ session and methods for hard shutter
        xyz_stage           ; % Serial session and methods for stage contol
        prechirper          ; % Serial session and methods for prechirper contol
        laser               ; % Serial session and methods for laser contol
        encoder             ; % Java and DaQ session and methods for encoder
        ttl_trigger         ; % DaQ session and methods for TTL
        
        %% Core classes for controlling scan properties
        aol_params          ; % AolParams class related to AOL config
        scan_params         ; % ScanParams class related to scanning settings
        stack_params        ; % StackAndTile class related to stacks and tiling
        
        %% Movement correction settings
        mc_scan_params      ; % ScanParams class related to Movement correction
        
        %% Viewer settings
        viewer              ; % BaseViewer class related to Display settings and Triggering
        
        %% Current working folder
        current_expe_folder = ''; % STR path for current zorking folder
        
        gui_handles = {}    ;
    end
    
    methods
        function this = Controller(online, varargin) 
            if nargin < 1 || isempty(online)
                this.online = false;
            else 
                this.online = online;
            end

            %% Check Matlab version
            if verLessThan('matlab', '9.3.0') && gui
                error_box('You need Matlab 2017b or + to run the GUI', 0)
            end
            
            %% Make sure paths are correct
            adjust_paths(this)
            
            %% Initialise the main fields of the controller
            this.rig_params = default.rig_params(); % if you have the error Undefined variable "default" or class "default.rig_params", just change the current folder in matlab to microscope_controller
            
            %% Prepare gui handle
            this.gui_handles.is_gui         = false;
            this.gui_handles.viewer_mode    = 0;
            this.gui_handles.frame_averages = 0;
            set_up_image_viewer(this);

            %% Add all Triggers/NI connections/Analog Connections,
            %% Generate Hardware and main Classes 
            % Daq Com for data acquisition and MC communication
            % If you have an error message here with offline analysis, check if the 'testing' folder is IN you path, in FIRST position
            try
                if this.rig_params.is_AC_DAQFPGA_type == 0 %% Handles for DaQFPGA
                    this.daq_fpga = DaqFpgaAc(this.rig_params.DAQFPGA_target);    
                elseif this.rig_params.is_AC_DAQFPGA_type == 1
                    this.daq_fpga = DaqFpgaDc(this.rig_params.DAQFPGA_target);
                elseif rig_params.is_AC_DAQFPGA_type == 2
                    this.daq_fpga = DaqFpgaDcAcc(this.rig_params.DAQFPGA_target);
                end
            catch %this is if you ask for online when there is no HW
                error_box('Unable to establish HW connection with DaqFpga. Starting in simulation mode instead. If you use the GUI, you need to activate simulation mode',1)  
                this.online = false;
                this.adjust_paths();
                this.daq_fpga = DaqFpgaDc(this.rig_params.DAQFPGA_target); %default
            end

            this.synth_fpga = SynthFpga(this.rig_params.adapter_name,this.online,this.rig_params.control_system_mac_adress); %%Ethernet Com for sending drives ; 
            this.xyz_stage  = XyzStage(this.rig_params.is_xy_stage && this.online, this.rig_params.xy_stage_com_port, this.rig_params.xy_stage_baudrate, this.rig_params.xy_stage_swapped); %Stage control and stack/tiles limits
            this.prechirper = Prechirper(this.rig_params.is_prechirper && this.online, this.rig_params.prechirper_com_port, this.rig_params.prechirper_baudrate); %Prechirper Control
            this.laser      = Laser(false && this.online, this.rig_params.laser_com_port, this.rig_params.laser_baudrate); %Laser Control (wavelength and shutters)
            %this.encoder    = WheelLog(false, this.rig_params.encoder_trigger_device,this.rig_params.encoder_trigger_port,this.rig_params.encoder_ip,this.rig_params.encoder_port,this.rig_params.encoder.adapter_name);%this.rig_params.create_encoder(); %Encoder for mice speed logging. Contains a Trigger() and controls a separated java process 
            this.pockels    = PockelsCell(this.rig_params.is_pockels, this.rig_params.pockels_ao_device, this.rig_params.pockels_ao_port); %Pockel cell control
            %this.red_pmt    = Pmt(false, this.rig_params.pmt_ao_device,this.rig_params.pmt_ao_port(1,:)); %PMT1 control ; not used yet
            %this.green_pmt  = Pmt(false, this.rig_params.pmt_ao_device,this.rig_params.pmt_ao_port(2,:)); %PMT2 control ; not used yet
            this.shutter    = HardShutter(this.rig_params.is_hardshutter, this.rig_params.hardshutter_ao_device, this.rig_params.hardshutter_ao_port); %Hard shutter Control
            %this.ttl_trigger= Trigger(this.online, this.rig_params.ttl_trigger_device, this.rig_params.ttl_trigger_port); % One or multiple TTl fired on trial start
            if this.online
                this.rig_params.backplane_connected = connect_backplane('', '', strcmpi(this.rig_params.encoder_trigger_device,"hardware"), strcmpi(this.rig_params.ttl_trigger_device,"hardware")); % any hardware triggers
            end

            %% Software
            this.aol_params         = default.aol_params('', this.laser.get_laser_wavelength * 1e-9); %AOL related info + AOL computations + calibration
            this.scan_params        = default.scan_params('','','','',this.aol_params); %current scan params (frame size - res etc...)
            this.stack_params       = stack_params(this, 0);
            if ~isempty(this.prechirper)
                this.prechirper.update_prechirper_postion(round(this.aol_params.current_wavelength * 1e9));
            end

            %% Now that the controller was (re)created, we reset it
            this.reset();

            create_viewer(this);

            %% Final viewer reset, so everything is ready for a scan
            this.reset_frame_and_send('raster'); 
        end

        function adjust_paths(this)
            %% Fix Matlab paths to have all the folder and subfolders
            % -------------------------------------------------------------
            % Syntax: 
            %   Controller.adjust_paths()
            % -------------------------------------------------------------
            % Inputs:      
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            % If you are offline, then the ./testing folder is added to the
            % path, otherwise it has to be removed.
            % The code will find automatically the peths, provinding that
            % you are in the microscope_controller folder or any of its
            % subfolder, or if you had it added to the matlab default paths
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   24-03-2018
            
            warning('off','MATLAB:rmpath:DirNotFound');
            warning('off','MATLAB:dispatcher:pathWarning');

            %% Go to mini-controller folder
            cd(fileparts(mfilename('fullpath')));
            cd('../');
            current_folder = strrep(pwd,'\','/');

            %% Now, we add all subfolder, except testing if online == true
            addpath(genpath(current_folder));
            rmpath(genpath([current_folder,'/.git/']))
            if ~this.online
            	addpath(genpath([current_folder,'/testing/']));
            else
            	rmpath(genpath([current_folder,'/testing/']));
            end
            
            %% Java conflicts
            %javaaddpath([pwd, '/mini-controller/java/Encoder/WheelLogger.class']);
            %javaaddpath([pwd, '/mini-controller/java/ParForMon/']);           
            %documents = winqueryreg('HKEY_CURRENT_USER', 'Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders', 'Personal');
            %javaaddpath([pwd, '/mini-controller/external_hardware/Java_subclasses/java/Miji/mij.jar']);
            %javaaddpath([pwd, '/mini-controller/external_hardware/Java_subclasses/java/Miji/ij-1.52d.jar']);
            
            warning('on','MATLAB:rmpath:DirNotFound');
            warning('on','MATLAB:dispatcher:pathWarning');
        end
 
        function set_expe_folder(this, expe_folder)
            %% Update current_expe_folder. Critical for Skeleton scan tools
            % -------------------------------------------------------------
            % Syntax: 
            %   Controller.set_expe_folder(expe_folder)
            % -------------------------------------------------------------
            % Inputs:  
            %   expe_folder (STR or INT) - Optional - if '' a UI box opens:
            %       The full path of your current experiment_folder. IF you
            %       pass an integer, a new experiment folder with that
            %       number is created
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   24-03-2018
            
            if nargin < 2
                expe_folder = uigetdir();
            elseif isnumeric(expe_folder)
                f = folder_params(expe_folder);
                expe_folder = f.expe_folder;
            end
            
            %% Correct for typo
            [~,this.current_expe_folder,~,~,~] = adjust_pathnames(expe_folder);
            
            %% Create folder if doesn't exist
            if ~exist(expe_folder, 'dir')
                mkdir(this.current_expe_folder);
            end
        end
 
        
        function delete(this)
            %% Class destructor. 
            % -------------------------------------------------------------
            % Syntax: 
            %   Controller.delete()
            % -------------------------------------------------------------
            % Inputs:
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   24-03-2018
            
            %last_session = get_key_session_params(this);
            %save('session_backup.mat','last_session');
            
            fprintf('hold on... closing the controller\n')
            delete(timerfindall);
            if ~isempty(this.gui_handles) 
                % Is empty when you regenerate a controller while there was
                % a preexisting one. In that case, we don't want to close
                % the gui or clear the variable!
                while ~isempty(get_existing_controller_name())
                    close_gui(true);
                    if this.rig_params.backplane_connected && this.online
                        disconnect_backplane();
                    end
                    name = get_existing_controller_name();
                    evalin('base',['clear ',name]);
                end
            end
            fprintf('done...\n')
        end  
    end  
end

