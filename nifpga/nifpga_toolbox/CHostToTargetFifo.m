classdef CHostToTargetFifo < CNiFpgaFifo
    %CHOSTTOTARGETFIFO NiFpga Class for HostToTarget Fifo operations

    % Copyright 2010-2010 Peter Fiala
    
    properties
        funselect % uint32 function selector
    end

    methods
        function obj = CHostToTargetFifo(Address, funselect)
            obj = obj@CNiFpgaFifo(Address);
            obj.funselect = funselect;
        end

        function [status, emptyElemRemaining] = write(obj, data, timeOut)
            if ~isempty(obj.Session)
	            [status, emptyElemRemaining] = NiFpga(obj.funselect, obj.Session, obj.Address, data, uint32(length(data)), uint32(timeOut));
                %[status, data, numElemsRead] = NiFpga(uint32(604),obj.Session, obj.Address, uint32(nElem), uint32(0)); %604
                %is write16
            else
                error('CHostToTargetFifo:Read', 'Unopened session');
            end
        end
    end
end