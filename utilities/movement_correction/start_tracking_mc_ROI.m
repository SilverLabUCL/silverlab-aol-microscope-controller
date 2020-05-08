function status = start_tracking_mc_ROI(controller, suggested_ROI, abs_z_ref_pos, suggested_thr, MC_rate, preview_ROI, non_default_resolution, non_default_aa, non_default_dwelltime, non_default_pockel_voltages)
    if nargin < 1 || isempty(controller)
        controller = get_existing_controller_name(true);
    end
    if nargin < 2 || isempty(suggested_ROI)
        suggested_ROI = controller.suggested_MC_ROI; %This will work if you properly selected the ROI in prepare_MC_Ref
    end
    if nargin < 3 || isempty(abs_z_ref_pos)
        abs_z_ref_pos = controller.suggested_z_ref; %This will work if you properly selected the ROI in prepare_MC_Ref
        if isnan(abs_z_ref_pos)
            abs_z_ref_pos = controller.xyz_stage.get_position(3);
        end
    end
    if nargin < 4 || isempty(suggested_thr)
        suggested_thr = controller.suggested_thr; %This will work if you properly selected the ROI in prepare_MC_Ref
    end
    if nargin < 5
        MC_rate = 2;
    end
    if nargin < 6
        preview_ROI = true; % used to be false
    end
    if nargin < 7 || isempty(non_default_resolution)
        non_default_resolution = controller.scan_params.mainscan_x_pixel_density;
    end
    if nargin < 8 || isempty(non_default_aa)
        non_default_aa = controller.scan_params.acceptance_angle;
    end
    if nargin < 9 || isempty(non_default_dwelltime)
        non_default_dwelltime = controller.scan_params.voxel_time;
    end
    if nargin < 10 || isempty(non_default_pockel_voltages)
        non_default_pockel_voltages = controller.pockels.on_value;
    end

    controller.stop_image(false, true); %stop any remaining MC

    if ~any(suggested_ROI) %you can do that separately
        prepare_MC_Ref( controller, absolute_z_for_ref, ref_channel, suggested_ROI, non_default_resolution, non_default_aa, non_default_dwelltime, non_default_pockel_voltages);%% qq add non default parameters
    end

    %% set and send ROI drives for the reference miniscans
    suggested_ROI = [suggested_ROI(1); suggested_ROI(2); abs_z_ref_pos; nan; suggested_ROI(5); suggested_ROI(6)]; %[x;y;z;sizex;sizey;sizez]. x and y in pixels, z in um

    controller.daq_fpga.MC_rate = MC_rate;
    status = set_and_send_MC_drives(controller, suggested_ROI, suggested_thr, non_default_resolution, non_default_aa, non_default_dwelltime, non_default_pockel_voltages); %send info to the AOL controller

    %% Send MC info to the daq; previewing MC
    if preview_ROI 
        preview_mc_ROI(controller, true)
    end
end

