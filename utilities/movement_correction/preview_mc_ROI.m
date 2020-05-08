function preview_mc_ROI(controller, as_miniscan)
    %% Send MC info to the daq; previewing MC ROI. This will overwrite current drives
    % set controller.daq_fpga.live_rendering_mode = 1 to show the ROI tracking (no correction);
    
    if nargin < 1 || isempty(controller)
        controller = get_existing_controller_name(true);
    end
    if nargin < 2 || isempty(as_miniscan)
        as_miniscan = true;
    end
    
    %% Stop any running imaging
    controller.stop_image(false, false);

    %% Read some initial settings
    try
        bkp_moving_average = controller.viewer.sliding;
    catch
        reset_drives_and_figure(controller.gui_handles, true);
        bkp_moving_average = 0;
    end    
    bkp_average_window = controller.viewer.refresh_limit;
    initial_scan_params = controller.scan_params;

    %% Set cleanup function so we always restore the initial drives
    cleanupObj = onCleanup(@() CleanMEUP(controller, initial_scan_params, bkp_moving_average, bkp_average_window)); % If function is interrupted, the file must be closed 

    %% Prepare rendering for MC
    controller.viewer.sliding = 0;
    controller.viewer.refresh_limit = 0;    
    controller.viewer.red_contrast = 0;
    controller.viewer.green_contrast = 0;
    controller.scan_params = controller.mc_scan_params; % send the miniscan scan params
    controller.send_drives(true, controller.mc_scan_params.pockels_raw); 
    
    % If as_miniscan is true, we read the data from the Channel0/Channel1 FIFO
    % if it is false, we read data from the FIFOREFHOSTFRAME FIFO
    controller.daq_fpga.live_rendering_mode = ~as_miniscan;
    
    %% Start tracking (QQ MAY NOT BE REQUIRED)
    controller.daq_fpga.use_movement_correction   = true;
    controller.daq_fpga.use_z_movement_correction = controller.daq_fpga.use_movement_correction && controller.daq_fpga.Z_Lines;
    
    %% Start imaging
    if controller.gui_handles.is_gui
        update_viewer_params_from_gui(controller);
    end
    controller.viewer.nb_of_gridlines = 1;
    controller.live_image('fast', true);   
end

function CleanMEUP(controller, initial_scan_params, bkp_moving_average, bkp_average_window)
    %% Restore initial drives
    controller.daq_fpga.live_rendering_mode = 0; %disable hostFIFO ROI rendering in blue
    controller.scan_params = initial_scan_params;
    controller.send_drives(true);
    
    %% Restore rendering options
    controller.viewer.nb_of_gridlines = 0;
    controller.viewer.sliding = bkp_moving_average;
    controller.viewer.refresh_limit = bkp_average_window;  
end   
        
