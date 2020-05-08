%% Run that script if everything went wrong with MC. If you are using a gui,
% you must first set c.gui = false;

if ~c.gui_handles.is_gui
    rig_id = 4;

    %% try to stop everything, delete all trace of controller
    if exist('c') == 1 && isvalid(c)
        c.reset;
        c.delete;
        delete(c);
        clear('c');

        uiwait(msgbox('Now, reboot the box','Reboot','modal'))
        drawnow; pause(0.1);
        pause(1);
    end

    close all;

    %% Recreate controller
    c = Controller(rig_id,false);

    %% This controller is supposedly working, now reset everything again
    pause(2) %crash if no pause!
    c.reset;
    pause(2) %crash if no pause!
    c.daq_fpga.live_rendering_mode = 0;

    %% start new image
    c.reset_frame_and_send('raster');
    c.daq_fpga.use_movement_correction      = false;
    c.daq_fpga.use_z_movement_correction    = false;
    
    %delete('rig_id');delete('GUI');
    c.live_image('safe', true);
else
    fprintf('\n This will delete the controller. If you really want it, send c.gui_handles.is_gui = 0, and try again')
end

