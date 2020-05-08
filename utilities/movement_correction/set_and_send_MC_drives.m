function status = set_and_send_MC_drives(controller, miniscan_ROI, MC_thr, non_default_resolution, non_default_aa, non_default_dwelltime, non_default_pockel_voltages)  
    %% Set MC drives and send them
    %% Store MC drives for future reload.
    %% MC drives correspond to a miniscan of the ref, so they can be copied into
    %% scan params to scan the ROI with the other FIFO
    %% don't forget to set controller.daq_fpga.use_movement_correction = true if you want to use MC
    if nargin < 1 || isempty(controller)
        controller = get_existing_controller_name(true);
    end 
    
    %qq -  add default values   
    initial_stage_loc = [controller.xyz_stage.z_start,controller.xyz_stage.z_stop,controller.xyz_stage.z_planes];
    controller.scan_params.pockels_raw(:) =  non_default_pockel_voltages;
    initial_scan_params = controller.scan_params;
    cleanupObj = onCleanup(@() cleanMeUp(controller, initial_scan_params, initial_stage_loc)); % Add pockel for miniscan

    if nargin < 4 || isempty(non_default_resolution)
        non_default_resolution = controller.scan_params.mainscan_x_pixel_density;
    end
    if nargin < 5 || isempty(non_default_aa)
        non_default_aa = controller.scan_params.acceptance_angle;
    end
    if nargin < 6 || isempty(non_default_dwelltime)
        non_default_dwelltime = controller.scan_params.voxel_time;
    end
    if nargin < 7 || isempty(non_default_pockel_voltages)
        non_default_pockel_voltages = controller.pockels.on_value;
    end
    
    %% Calculate and set drives
    status = prepare_MC_miniscan(controller, non_default_resolution, non_default_aa, non_default_dwelltime, non_default_pockel_voltages, miniscan_ROI, miniscan_ROI(3));
    if status
        controller.mc_scan_params = controller.scan_params;

        %% Send the MC drives to the controller and the daq
        controller.daq_fpga.safe_stop(true);
        controller.prepare_daq_for_mc(MC_thr(1), MC_thr(2));
        controller.send_mc_drives(non_default_pockel_voltages); %%qq might need a reset viewer feature    
    end
end

function cleanMeUp(controller, initial_scan_params, initial_stage_loc)
    %% Restore initial settings
    controller.scan_params = initial_scan_params;
    controller.send_drives(true);
    
    controller.xyz_stage.z_start = initial_stage_loc(1);
    controller.xyz_stage.z_stop = initial_stage_loc(2);
    controller.xyz_stage.z_planes = initial_stage_loc(3);    
end
