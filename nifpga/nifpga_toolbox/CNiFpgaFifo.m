classdef CNiFpgaFifo < handle
    %CNIFPGAFIFO NiFpga Class for Fifo operations

    % Copyright 2010-2010 Peter Fiala
    properties
        Address % uint32 address of FIFO in the FPGA hardware
        Session % uint32 session handle
    end
    
    methods
        function obj = CNiFpgaFifo(Address)
            obj.Address = uint32(Address);
        end
        
        function status = configure(obj, size)
            if ~isempty(obj.Session)
                status = NiFpga(uint32(12), obj.Session, obj.Address, uint32(size));
            else
                error('NiFpga:ConfigureFifo', 'Unopened session');
            end
        end
        
        function status = start(obj)
            if ~isempty(obj.Session)
                status = NiFpga(uint32(13), obj.Session, obj.Address);
            else
                error('NiFpga:StartFifo', 'Unopened session');
            end
        end
        
        function status = stop(obj)
            if ~isempty(obj.Session)
                status = NiFpga(uint32(14), obj.Session, obj.Address);
            else
                error('NiFpga:StopFifo', 'Unopened session');
            end
        end
    end
end
