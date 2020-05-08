classdef SynthComs < uint8
   enumeration
      load_plane_records (1)
      load_plane_size (2)
      load_points_repeat (5)
      load_points (6)
      load_single_frequency (7)
      live_image (8)
      stop_single_frequency (10)
      run_planes (11)
   end
   
   methods
       function val = v(this)
           val = uint8(this);
       end
   end
end

