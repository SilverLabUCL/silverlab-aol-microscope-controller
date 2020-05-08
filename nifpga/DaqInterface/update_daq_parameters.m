%% Superclass for DaqFpga CAPI communications
% DaqFpga class inherits these methods and properties
%
% Type doc function_name or help function_name to get more details about
% the function inputs and outputs
%
% -------------------------------------------------------------------------
% Syntax: N/A
% -------------------------------------------------------------------------
% Class Generation Inputs: N/A 
% -------------------------------------------------------------------------
% Outputs: N/A  
% -------------------------------------------------------------------------
% Class Methods: 
%
% * Set Generic Daq params.
%   DaqFpga.set_fixed_params( aol_params)
%
% * Set variable Daq params (specific to each scan)
%   DaqFpga.set_variable_params(scan_params, aol_params, number_of_cycles)
%
% * Set MC Daq params
%   DaqFpga.set_move_corr_params(aol_params, scan_params)
%
% * Adjust Trigger parameters
%   DaqFpga.setup_general_hardware_triggers()
%
% * Perform the sequence starting MC (if not started)
%   DaqFpga.start_mc(~, ~)
%
% * Reset clock between acquisition and controller side
%   DaqFpga.reset_clock() 
%
% -------------------------------------------------------------------------
% Extra Notes:
% * Functions below communicate with the capi. Some variable names are
%   set automatically in the capi and cannot be changed from here.
%
% * Every time the Acquisition DAQFPGA bitfile is modified, the capi file 
%   must be recompiled. Please follow the instructions in the User Manual,
%   in the Updating Bitfile section. 
%
% * As variables name are set in labview, please please check for any
%   change in name or default value, which will have to be corrected
%   here.
%
% * CAPI variable and DaqFpga are duplicated. Calling the update function 
%   set the CAPI values from the daq Values, which are the one you should 
%   usually change before updating the CAPI. The main reason for this 
%   structure is to smooth communications between the command line and the
%   GUI, and they all have direct access the the DaqFpga values. (while 
%   in command line, accessing directly the GUI is more complex)
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
% See also: DaqFpga, data_acquisition, FIFO_initialisation, 
%   single_record, timed_image

%% TODO : implement get and set methods at the daqFPGA level

classdef update_daq_parameters < handle
    properties
        %% Default fixed and variable params. 
        board_speed         = 200000    ;   % 1000 cycles per s (for a 200MHz board)
        refcountresetenabled= 1         ;   % Elegant solution for an annoying problem. ask Vicky...
        correct             = true      ;   % 

        
        %% X-Y MC stuff
        threshold_xy        = 0         ;   % MC Threshold for XY. Values below threshold are clipped
        Integral_scale      = 400       ;   % Integral value of the PID ; 400 works for 2ms
        proportianal_x10    = 9         ;   % Proportional value of the PID ; oscillate > 18
        scan_int_x1000      = 2         ;   % Interval between the offset and
        diff_thresh_x10     = 0         ;   % Clipping threshold for low level noise. Movement < threshold are zeroed
        average             = 1         ;   % Number of cycles to average ; 1 is -no average-
        sliding_average     = 0         ;   % BOOL - Define if we do a MC sliding average. Sliding averages require to adjust P and I
        bkg_MC_live_MC_offset= 40       ;   % HARDCODED - Corrective offset when switching to background MC
        x_centroid          = []        ;   % Current x_centroid value
        y_centroid          = []        ;   % Current y_centroid value
        
        %% X-Y Recovery Settings
        use_vel_estimate    = false     ;   % BOOL - If true, system tries to anticipate next centroid location
        mc_auto_relock      = true      ;   % BOOL - If true, system tries to restart MC if tracking is lost
        ref_diff_x_y        = 255       ;   % Sudden movement > this threshold are ignored (lost tracking condition)
        downsizing_factor   = 4         ;   % Remove n pixels from the MC ref size for the auto-relock tolerance (NOT A CAPI SETTING)
        Averageoffsets      = 1         ;   % Just use the last N Averageoffsets if you loose tracking
        
        %% Z stuff
        threshold_z         = 0         ;   % MC Threshold for XY. Values below threshold are clipped
        Z_Lines             = 0         ;   % Number of Z lines going through the center of the ref. Small number can cause instability
        z_pixel_size_um     = 1         ;   % Size of Z pixels (can be streteched to accomodate bigger Z-psf)
        ignore_z_lines      = 2         ;   % Number of Z line to ignore 
        Integral_scale_z    = 400       ;   % Integral value of the PID ; 400 works for 2ms. maybe lower values are safer
        proportianal_x10_z  = 9         ;   % Proportional value of the PID ; oscillate ~ 18
        diff_thresh_x10_z   = 0         ;   % Clipping threshold for low level noise. Movement < threshold are zeroed
        swapz               = false     ;   % DEPRECATED ? - Cause Z to be scanned the other way around
        AverageZ            = 1         ;   % INT - Average every N frame (1 for no avearge)
        
        %% Z Recovery Settings
        ref_diff_z          = 255       ;   % Sudden movement > this threshold are ignored (lost tracking condition)
        
        %% Rendering stuff
        ref_framedilute     = 10        ;   % Read FIFO only every ref_framedilute cycles
    end
    
    methods
        function set_fixed_params(obj, aol_params)
            %% Set Generic Daq params.
            % Send generic parameters that has to do with the AOL 
            % technology and the current hardware
            % -------------------------------------------------------------
            % Syntax: 
            %   DaqFpga.set_fixed_params(aol_params)
            % -------------------------------------------------------------
            % Inputs: 
            %   aol_params (AolParams object)
            %       Values about AOL hardware are read in setup.ini and
            %       calibration.ini and stored in aol_params.
            %   
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            % TBH, i'm a bit unclear about the segmentation of variables
            % between the different functions
            % -------------------------------------------------------------
            % Author(s):
            %   Geoffrey Evans, Boris Marin, Antoine Valera, Vicky
            %   Griffiths, Srinivas Nadella
            %---------------------------------------------
            % Revision Date:
            %   13-03-2019
            
            obj.capi.AODfill                    = aol_params.aod_fill                   ; % daq_clock_freq .* aol_params.fill_time; %4895
            obj.capi.sampleswaitaftertrigger    = aol_params.sampleswaitaftertrigger    ;        
            obj.capi.StartUpDelay               = aol_params.startup_delay              ;
            obj.capi.Newlinetriggerenabled      = 0                                     ;
        end  
        
        function set_variable_params(obj, scan_params, aol_params, number_of_cycles)
            %% Set variable Daq params (specific to each scan)
            % Modify the scan mode, the number of sample to collect and the
            % dwell time. Call that every time new drives are sent for 
            % acquisition
            % -------------------------------------------------------------
            % Syntax: 
            %   DaqFpga.set_variable_params(obj, scan_params, aol_params,
            %   number_of_cycles)
            % -------------------------------------------------------------
            % Inputs: 
            %   scan_params (ScanParams object)
            %       Values about the current frame and the number of pixel
            %       and dwell time are stored in scan_params or
            %       mc_scan_params
            %   
            %   aol_params (AolParams object)
            %       Values about AOL hardware are read in setup.ini and
            %       calibration.ini and stored in aol_params.
            %   
            %   number_of_cycles (INT)
            %       The number of cycles for the scan. The value is ignored
            %       if you are in live scan mode
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            % This function is typically called every time you change the
            % amount / profile of data. It is updated automatically in the
            % get_data function. The controller side must mbe updated
            % accordingly, or there will be a mismatch between the scanning
            % and the acqusition side
            % -------------------------------------------------------------
            % Author(s):
            %   Geoffrey Evans, Boris Marin, Antoine Valera, Vicky
            %   Griffiths, Srinivas Nadella
            %---------------------------------------------
            % Revision Date:
            %   13-03-2019
            
            mc_is_ready_and_wanted          = (obj.use_movement_correction && obj.is_ready_to_correct)  ;
            obj.capi.Mode                   = scan_params.imaging_mode.daq_val(mc_is_ready_and_wanted)  ; % Scanning = 0; Pointing = 1; Pointing and MC = 2; Scanning and MC = 3% 
            obj.capi.NumberpixelspointingNp = scan_params.num_voxels                                    ; 
            obj.capi.use_varailble_length   = numel(unique(scan_params.voxels_for_ramp)) > 1            ;   
            if obj.capi.use_varailble_length 
                obj.capi.VARIABLELENGTHFIFO.write(uint16(scan_params.voxels_for_ramp), obj.timeout)     ;              
            else
                obj.capi.xpixelsperlineNpx  = scan_params.voxels_for_ramp(1)                            ;
            end
            
            obj.capi.ypixelsperlineNpy      = scan_params.num_drives                                    ;
            obj.capi.sampsperpixP           = aol_params.daq_clock_freq * aol_params.discretize(scan_params.voxel_time);
            obj.capi.RepeatNumberofCycles   = number_of_cycles                                          ; % Number of cycles to repeat. 
            obj.scan_cycles                 = 2 * scan_params.voxel_time / 1e-8                         ; % For signal normalization
        end
        
        function set_move_corr_params(obj, aol_params, scan_params)
            %% Set MC Daq params
            % Similar to set_variable_params, but for all the settings 
            % specific to the movement correction system. 
            % -------------------------------------------------------------
            % Syntax: 
            %   DaqFpga.set_move_corr_params(aol_params, scan_params)
            % -------------------------------------------------------------
            % Inputs: 
            %   aol_params (AolParams object)
            %       Values about AOL hardware are read in setup.ini and
            %       calibration.ini and stored in aol_params.
            %
            %   scan_params (ScanParams object)
            %       Values about the current frame and the number of pixel
            %       and dwell time are stored in scan_params or
            %       mc_scan_params
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            % from MC params. Send them once, after setting up the reference. 
            % They should not be updated unless the resolution or dwell
            % time of the ref changes.
            % - For now, the xy ref is squared
            % - For now, N voxel for Z lines is equivalent to XY length
            % - For now, Z dwell time is the same than XY dwell time
            % -------------------------------------------------------------
            % Author(s):
            %   Vicky Griffiths, Antoine Valera, Geoffrey Evans
            %---------------------------------------------
            % Revision Date:
            %   13-03-2019
            
            %% That is set to a fixed value for now
            obj.capi.mc_delayprog = ( obj.capi.sampleswaitaftertrigger -...
                                     (obj.capi.AODfill + 200))              ; %qq 200 is the number of cycles the trigger takes to propgate through the controller before we see a signal (V.G.)
            if obj.capi.mc_delayprog < 10
                obj.capi.mc_delayprog       = 10                            ; 
            end
            obj.capi.sampleswaitafterpulse  = obj.capi.sampleswaitaftertrigger + obj.bkg_MC_live_MC_offset; % fix an offset between MC during imaging and background MC
            obj.capi.stop_background        = false                         ;
            obj.capi.suppres_mc             = 1                             ; % Supress MC in the last N lines. Prevent MC to kick in a the end of the frame. best value TBD. 0 crashes in some cases
            obj.capi.Averageoffsets         = obj.Averageoffsets            ;
            
            obj.capi.Average                = obj.average                   ; 
            obj.capi.threshold_xy           = obj.threshold_xy              ;
            obj.capi.threshold_z            = obj.threshold_z               ;
            obj.capi.RefsampsperpixPr       = aol_params.daq_clock_freq * aol_params.discretize(scan_params.voxel_time); % dwell time in cycles
            obj.capi.RefxpixelsperlineNpxr  = scan_params.voxels_for_ramp(1);
            obj.capi.RefypixelsperlineNpyr  = scan_params.voxels_for_ramp(1);
            obj.capi.RefScanCycles          = ceil(obj.board_speed * obj.MC_rate)   ; 
            obj.capi.Refcountresetenabled   = obj.refcountresetenabled      ; 
            obj.capi.Integral_scale         = obj.Integral_scale            ;
            obj.capi.diff_thresh_x10        = obj.diff_thresh_x10           ;
            obj.capi.proportianal_x10       = obj.proportianal_x10          ;
            obj.capi.scan_int_x1000         = obj.MC_rate                   ;
            obj.capi.useslidingaverage      = obj.sliding_average           ;
            obj.capi.ref_diff_x_y           = obj.ref_diff_x_y              ;

            %% Z MC var
            obj.capi.Enable_ZMC             = obj.Z_Lines > 0               ;
            obj.capi.Ref_z_lines            = uint16(obj.Z_Lines)           ;
            obj.capi.ref_z_pixels_per_line  = uint16(obj.capi.RefxpixelsperlineNpxr);
            obj.capi.Refsampsperpix_z       = obj.capi.RefsampsperpixPr     ;
            obj.capi.AverageZ               = obj.AverageZ                  ;            
            obj.capi.Integral_scale_z       = obj.Integral_scale_z          ;
            obj.capi.proportianal_x10_z     = obj.proportianal_x10_z        ;
            obj.capi.diff_thresh_x10_z      = obj.diff_thresh_x10_z         ;
            obj.capi.swapz                  = obj.swapz                     ;
            obj.capi.ignore_z_lines         = obj.ignore_z_lines            ;
            obj.capi.ref_diff_z             = obj.ref_diff_z                ;
        end  
        
        function setup_general_hardware_triggers(obj)
            %% Adjust Trigger parameters
            % Internal function. 
            % -------------------------------------------------------------
            % Syntax: 
            %   obj.start_imaging()
            % -------------------------------------------------------------
            % Inputs: 
            % -------------------------------------------------------------
            % Outputs:
            % -------------------------------------------------------------
            % Extra Notes: 
            % Adjust some extra Trigger settings We currently don't use all
            % the abilities of the system in matlab
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera.
            %---------------------------------------------
            % Revision Date:
            %   23-03-2018
            
            %% At this stage, live_scan is already true
            if obj.capi.live_scan
                obj.capi.ImagingProtocol            = 5                     ;     
            else
                obj.capi.ImagingProtocol            = 2                     ; 
            end
            
            %% Set the type of trail start Trigger (PXI_Trig1)
            % 0 for start trigger, 1 for line trigger, 2 for ref ref frame
            % acknowledgement (MC).
            obj.capi.Trigger1function               = 0                     ; 
            obj.capi.Trigger1selector               = 0                     ;
            
            %% Enabling all triggers
            obj.capi.EnableTrigger1                 = 1                     ; % Encoder trigger/line trigger, PXI_Trig2
            obj.capi.PulsewidthticksLineTrig        = 800                   ;

            obj.capi.EnableTrigger2                 = 1                     ; % Frame trigger, PXI_Trig2
            obj.capi.PulsewidthticksFrameCycleTrig  = 800                   ;

            obj.capi.EnableTrigger3                 = 1                     ; % trial trigger, PXI_Trig3
            obj.capi.PulsewidthticksTrialtrig       = 800                   ;

            %obj.capi.EnableTrigger4 = 1; %% Start of exp trigger, PXI_Trig4 moved in Base.m
            obj.capi.PulsewidthticksStartofExptrig  = 800;

            %% Other trigger stuff that may not be related
            obj.capi.live_scantriggersmodule        = obj.capi.live_scan    ; % --> Check with Vicky/Sameer ; to enable for live_scan trigger
        end
        
        function start_mc(obj, ~, ~)
            %% Perform the sequence starting correction (if not started)
            % This will update the reference too. 
            % -------------------------------------------------------------
            % Syntax: 
            %   DaqFpga.start_mc()
            % -------------------------------------------------------------
            % Inputs: 
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera, Vicky Griffiths, Geoffrey Evans
            %---------------------------------------------
            % Revision Date:
            %   13-03-2019
            %
            % See also: movement_correction
            
           %% To be run once every time you want to reset the MC offset 
           if obj.is_ready_to_correct && obj.use_movement_correction && ~obj.is_correcting
               %% Disable correction (if running - it should not)
               obj.capi.usehostoffset       = ~obj.correct                  ;
               obj.capi.use_host_offset_z   = ~obj.correct                  ;
               
               %% Enter reference mode
               obj.capi.set_reference       = 1                             ;
               pause(obj.MC_rate*5 / 1000 + 0.001)                          ; % wait at least 1 MC frame, + 1 ms just in case 

               %% Quit reference mode. This validates current ROI
               obj.capi.set_reference       = 0                             ;
               
               %% Start correcting
               obj.capi.usehostoffset       = ~obj.correct                  ;
               obj.capi.use_host_offset_z   = ~obj.correct                  ;

               %% Update correction tags
               obj.is_correcting            = true;               
               fprintf('\t MC SETUP : movement correction toggle initiated \n')
           end
        end
        

        function reset_clock(obj) 
            %% Reset clock between acquisition and controller side
            % Run only when you reset the capi.
            % -------------------------------------------------------------
            % Syntax: 
            %   DaqFpga.reset_clock()
            % -------------------------------------------------------------
            % Inputs: 
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            % This function correct for drifts between the scanning and
            %  the acqusition side
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera, Vicky Griffiths, Geoffrey Evans
            %---------------------------------------------
            % Revision Date:
            %   13-03-2019
            
            obj.capi.UserCommand        = 0 ;
            obj.capi.UserData0          = 1 ;
            obj.capi.UserData1          = 1 ;
            while ~obj.capi.UserCommandIdle
                pause(0.001)                ;
            end
            obj.capi.UserCommandCommit  = 0 ;
            pause(0.001);
            obj.capi.UserCommandCommit  = 1 ;
            pause(0.001);
            obj.capi.UserCommandCommit  = 0 ;
            while ~obj.capi.UserCommandIdle
                pause(0.001)                ;
            end
            obj.capi.UserCommandStatus      ;
        end
    end
end