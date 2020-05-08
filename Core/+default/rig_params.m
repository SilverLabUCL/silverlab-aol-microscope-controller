%% Rig specific params load hardware config except for the AOLs hardware
%   Hardware presence/absence, connection ports, etc... are loaded from
%   setup.ini and stored here. The objects are created during the Controller
%   generation. However, each AO, DO or serial object can be created
%   separately using the command listed in the controller.
% -------------------------------------------------------------------------
% Syntax: 
%   rig_parameters = rig_params()
% -------------------------------------------------------------------------
% Inputs: 
% -------------------------------------------------------------------------
% Outputs:
%   rig_parameters(struct) : return a new rig_params object, with the
%               appropriate list of hardware
% -------------------------------------------------------------------------
% Extra Notes:
% * Offline analysis uses a fake nidaq session, located in './testing' 
%   folder.
%   - To have it working offline, you need './testing' in your path.
%   - To have it working online, you need './testing' NOT in your path
%   This is done automatically when the controller is created in matlab
%   
% * 6 AOD or dual scan are not supported yet. setup.ini will need an 
%   upgrade
%
% * Triggers :
%   The number of trigger to used is listed in 'Trigger.AvailableDeviceList'
%   It must be a list seperate by the charcter set as seperator in input 
%   5 of read_ini_value(). by default, this is "|". Alternatively, Trigger 
%   can be 'hardware'. In that case, you must set the encoder trigger to
%   'hardware' too.
%   - If you have one TTL, set "1"
%   - If you have two TTLs, set "1|2"
%   - If you have three, but want a SUBSET, set for example "1|3"
%     For each index, you need a line call Trigger.Devicex, with x being one
%     the listed indexes. 
%    For example :
%
%       'Trigger.AvailableDeviceList' = "1|3"
%       'Trigger.Device1' = "PXI1Slot6/port4/line3"
%       'Trigger.Device2' = "PXI1Slot6/port4/line4"
%       'Trigger.Device3' = "PXI1Slot6/port4/line5"
%
%	would generate a trigger using line 'Trigger.Device1' and line
%   'Trigger.Device3'. 'Trigger.Device2' will be ignored.
%
% * See User Manual for more examples of AO, DO or Serial object generation.
% -------------------------------------------------------------------------
% Examples:
% -------------------------------------------------------------------------
%                               Notice
%
% Author(s): Geoffrey Evans, Antoine Valera
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
%   11-04-2019
%
% See also: Controller, setup.ini

function rig_parameters = rig_params()
    %% load default scan params parameters
    rig_parameters = default_rig();
    
    %% Update rig_specific code using setup.ini
    C = load_ini_file([],'[Main Configuration File]');
    
 %     rig_params.whatever = read_ini_value(C,  'Objective.Strings');
    
    %% General Rig settings
    rig_parameters.microscope_type      = read_ini_value(C,  'Microscope Type', 'AOLM');
    rig_parameters.id                   = read_ini_value(C,  'Microscope ID', 0);
    rig_parameters.axial_mc             = read_ini_value(C,  'Axial MC', false);
    rig_parameters.mc_supported         = read_ini_value(C,  'MC Supported', false);
    rig_parameters.advanced_imaging     = read_ini_value(C,  'Advanced Imaging', false);
    rig_parameters.laser_power_control  = read_ini_value(C,  'Laser Power Control', 'Pockels');
    rig_parameters.laser_pow_mod_ctrl   = read_ini_value(C,  'Laser Power Modulation Control', 'NI');
    rig_parameters.dev_pc               = read_ini_value(C,  'DevPC - No hardware', true);
    rig_parameters.max_trial_length     = read_ini_value(C,  'Max allowed trial length (sec)', 60);
    rig_parameters.max_line_number      = read_ini_value(C,  'Max Line Number', 2047);
    rig_parameters.base_path            = read_ini_value(C,  'Base path', pwd);
    rig_parameters.pockel_cal_zoom      = read_ini_value(C,  'Pockels cal.Zoom', 12);
    rig_parameters.pockel_cal_file      = read_ini_value(C,  'Pockels calibration file');
    rig_parameters.laser_pow_cal_file   = read_ini_value(C,  'Laser power calibration file');

    %% TTL Trigger Settings
    rig_parameters.is_ttl_trigger       = ~isempty(read_ini_value(C, 'Trigger.AvailableDeviceList'));
    if rig_parameters.is_ttl_trigger
        rig_parameters.ttl_trigger_device   = [];
        rig_parameters.ttl_trigger_port     = [];
        % We can have several Software Trigger.
        % See Extra Notes above for more explanation on Triggers 
        % Device1 is typically "PXI1Slot6/port4/line5" or "hardware"
        for device = read_ini_value(C, 'Trigger.AvailableDeviceList')' 
            [dev, port]                         = get_device_and_port(read_ini_value(C, ['Trigger.Device',num2str(device)]));
            rig_parameters.ttl_trigger_device   = [rig_parameters.ttl_trigger_device; dev];
            rig_parameters.ttl_trigger_port     = [rig_parameters.ttl_trigger_port; port];
        end 
    end
    
    %% AnalogOutput settings
    %% Pockels
    rig_parameters.is_pockels           = true; % qq should be a setting
    rig_parameters.pockels_ao           = read_ini_value(C,  'DAQmx Chan.Pockels AO');
    [rig_parameters.pockels_ao_device, rig_parameters.pockels_ao_port] = get_device_and_port(rig_parameters.pockels_ao);

    %% Hardshutter
    rig_parameters.is_hardshutter       = true; % qq should be a setting
    rig_parameters.hardshutter_ao       = read_ini_value(C,  'DAQmx Chan.Hard Shutter AO');
    [rig_parameters.hardshutter_ao_device, rig_parameters.hardshutter_ao_port] = get_device_and_port(rig_parameters.hardshutter_ao);

    %% PMT
    rig_parameters.is_pmt               = false; % qq should be a setting
    rig_parameters.pmt_ao               = read_ini_value(C,  'DAQmx Chan.PMT AOs');
    [rig_parameters.pmt_ao_device, rig_parameters.pmt_ao_port] = get_device_and_port(rig_parameters.pmt_ao);

    %rig_params.whatever                = read_ini_value(C,  'DAQmx Chan.Power meter AI');

    %% Encoder settings
    rig_parameters.is_encoder           = read_ini_value(C,  'Encoder.Available?');
    rig_parameters.encoder_ip           = read_ini_value(C,  'Encoder.IP address');
    rig_parameters.encoder_port         = read_ini_value(C,  'Encoder.Port');
    rig_parameters.encoder_trigger      = read_ini_value(C,  'Encoder.Trigger', 'hardware'); % can be a board (eg. "PXI1Slot6/port4/line1") or hardware
    [rig_parameters.encoder_trigger_device, rig_parameters.encoder_trigger_port] = get_device_and_port(rig_parameters.encoder_trigger);
    rig_parameters.encoder_wheel_radius = 1e-3 * read_ini_value(C,  'Encoder.Wheel radius (cm)');
    rig_parameters.encoder.adapter_name = read_ini_value(C, 'Encoder.Adapter Name');

    %     rig_params.whatever = read_ini_value(C,  'Trigger.AvailableDeviceList');
    %     rig_params.whatever = read_ini_value(C,  'Trigger.Device1');

    %% Stage settings
    rig_parameters.is_xy_stage          = read_ini_value(C,  'XY Stage.Available?');
    rig_parameters.xy_stage_type        = read_ini_value(C,  'XY Stage.Type'); %XY motor brand, e.g 'Scientifica'
    rig_parameters.z_stage_type         = read_ini_value(C,  'Z Stage.Type'); %Z motor brand, e.g 'Scientifica'
    rig_parameters.xy_stage_baudrate    = read_ini_value(C,  'XY Stage.Baudrate', 9600);
    rig_parameters.xy_stage_com_port    = read_ini_value(C,  'XY Stage.COM port');
    rig_parameters.xy_stage_swapped     = read_ini_value(C,  'XY Stage.Swapped', false);
    rig_parameters.z_stage_baudrate     = read_ini_value(C,  'Z Stage.Baudrate', 9600);
    rig_parameters.z_stage_com_port     = read_ini_value(C,  'Z Stage.COM port');

    %% Prechirper settings
    rig_parameters.is_laser             = read_ini_value(C,  'Laser.Available?');
    rig_parameters.laser_type           = read_ini_value(C,  'Laser.Type'); %laser brand, e.g 'Coherent'
    rig_parameters.laser_com_port       = read_ini_value(C,  'Laser.COM port');
    rig_parameters.laser_baudrate       = read_ini_value(C,  'Laser.Baudrate', 19200);

    %% Prechirper settings
    rig_parameters.is_prechirper        = read_ini_value(C,  'Prechirper.Available?');
    rig_parameters.prechirper_type      = read_ini_value(C,  'Prechirper.Type'); %prechirper brand, e.g 'femtocontrol'
    rig_parameters.prechirper_com_port  = read_ini_value(C,  'Prechirper.COM Port');
    rig_parameters.prechirper_baudrate  = read_ini_value(C,  'Prechirper.Baudrate', 115200);
    
    %% Network settings (SynthFpga)
    rig_parameters.adapter_name         = read_ini_value(C,  'Control system.Network adapter name');
    rig_parameters.control_system_mac_adress = read_ini_value(C,  'Control system.MAC address');
    %rig_params.whatever                = read_ini_value(C,  'Control system.Ctrl FPGA available');
    rig_parameters.computer_mac_adress  = read_ini_value(C,  'Computer.MAC address');
    
    %% DaQFPGA settings
    rig_parameters.DAQFPGA_target       = read_ini_value(C,  'DAQ FPGA.Target', 'RIO0');
    rig_parameters.is_AC_DAQFPGA_type   = read_ini_value(C,  'DAQ FPGA.Input type AC/DC');
         
%     elseif rig_id == 5
%         rig_params.create_daq_fpga = @DaqFpgaDcAcc;
%         rig_params.create_synth_fpga = @SynthFpgaSix;
%         rig_params.create_xyz_stage = @(x) [];
%         rig_params.pockels_value = 0.5;
%         rig_params.offline = false;
%     end
end

function rig_params = default_rig()
    rig_params                      = {};
    rig_params.log_bkg_mc           = false;
    rig_params.log_live_image_mc    = false;
    rig_params.bg_mc_monitoring     = [];
    rig_params.create_daq_fpga      = @(x) DaqFpgaDc('RIO0');
    rig_params.create_synth_fpga    = [];
    rig_params.create_encoder       = [];
    rig_params.pockels_value        = 0;
    rig_params.backplane_connected  = 0;
end

function [device, port] = get_device_and_port(input_string)
    if strcmpi(input_string, 'hardware')
        device  = 'hardware';
        port    = [];
    else
        output = char(split(input_string,'/'));
        device = output(1,:);
        if size(output,1) == 3
            port = strcat(output(2,:),'/',output(3,:)); %eg : "PXI1Slot6/port4/line1"
        else
            port = output(2,:); %eg : "PXI1Slot4/ao1"
        end
        if contains(output(2,:),':') %eg : "PXI1Slot4/ao2:3"
            idx             = strfind(output(2,:),':');
            end_of_range    = output(2,idx+1:end);
            start_of_range  = output(2,idx-1);
            basename        = output(2,1:idx-2);
            port            = [];
            for p = str2double(start_of_range):str2double(end_of_range)
                port        = [port;strip([basename,num2str(p)])];
            end
        end
    end
end
