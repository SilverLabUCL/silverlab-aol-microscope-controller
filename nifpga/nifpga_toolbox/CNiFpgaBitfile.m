classdef CNiFpgaBitfile < handle
    %CNIFPGABITFILE NiFpga class for general bitfile operation

    % Copyright 2010-2010 Peter Fiala and Peter Rucz
    properties
		Bitfile, Signature
		Target, Session, Status
    end
    
    methods
        function obj = CNiFpgaBitfile(Bitfile, Signature, Target)
			obj.Bitfile = Bitfile;
			obj.Signature = Signature;
            obj.Target = Target;
        end
        
        function r = Copy(obj)
            f = fieldnames(obj);
            for i = 1 : length(f)
                r.(f{i}) = obj.(f{i});
            end
        end
        
        function delete(obj)
            if ~isempty(obj.Session) &&  ~check_caller({'uiimport','uiopen','load','rescale_tree'}) 
                obj.close;
                display('session closed with NI FPGA')
            end
        end
        
        function status = open(obj, attribute)
            if isempty(obj.Session)
                switch lower(attribute)
                    case 'run'
                        attribute = uint32(0);
                    case 'norun'
                        attribute = uint32(1);
                    otherwise
                        error('unknown open attribute %s', attribute);
                end
                [status, session] = NiFpga(uint32(2), obj.Bitfile, obj.Signature, obj.Target, attribute);
                obj.Status = status;
                if ~status
                    obj.Session = session;
                end
            else
                warning('NiFpga:Open', 'Session already opened');
                status = obj.Status;
            end
        end
        
        function status = close(obj)
            if ~isempty(obj.Session)
                status = NiFpga(uint32(3), obj.Session, uint32(0));
                obj.Status = status;
                if ~status
                    obj.Session = [];
                end
            else
                warning('NiFpga:Close', 'Closing an unopened session');
                status = obj.Status;
            end
        end
        
        function status = run(obj, attribute)
            if ~isempty(obj.Session)
                switch lower(attribute)
                    case 'wait'
                        attribute = uint32(1);
                    case 'nowait'
                        attribute = uint32(0);
                    otherwise
                        error('unknown open attribute %s', attribute);
                end
                status = NiFpga(uint32(4), obj.Session, attribute);
                obj.Status = status;
            else
                error('NiFpga:Run', 'Unopened session');
            end
        end
        
        function status = abort(obj)
            if ~isempty(obj.Session)
                status = NiFpga(uint32(5), obj.Session);
                obj.Status = status;
            else
                error('NiFpga:Abort', 'Unopened session');
            end
        end
        
        function status = reset(obj)
            if ~isempty(obj.Session)
                status = NiFpga(uint32(6), obj.Session);
                obj.Status = status;
            else
                error('NiFpga:Reset', 'Unopened session');
            end
        end
        
        function status = download(obj)
            if ~isempty(obj.Session)
                status = NiFpga(uint32(7), obj.Session);
                obj.Status = status;
            else
                error('NiFpga:Download', 'Unopened session');
            end
        end
        
        function [status, context] = reserveIrq(obj)
            if ~isempty(obj.Session)
                [status, context] = NiFpga(uint32(8), obj.Session);
                obj.Status = status;
            else
                error('NiFpga:ReserveIrq', 'Unopened session');
            end
        end
        
        function status = unreserveIrq(obj, context)
            if ~isempty(obj.Session)
                status = NiFpga(uint32(9), obj.Session, context);
                obj.Status = status;
            else
                error('NiFpga:UnreserveIrq', 'Unopened session');
            end
        end
        
        function [status, asserted, timedOut] = waitOnIrq(obj, context, irqs, timeOut)
            if ~isempty(obj.Session)
                irqs = uint32(sum(2.^irqs));
                [status, asserted, timedOut] = NiFpga(uint32(10), obj.Session, context, irqs, uint32(timeOut));
                asserted = find(bitget(asserted, 1:32))-1;
                obj.Status = status;
            else
                error('NiFpga:WaitOnIrq', 'Unopened session');
            end
        end
        
        function status = ackIrq(obj, irqs)
            if ~isempty(obj.Session)
                irqs = uint32(sum(2.^irqs));
                status = NiFpga(uint32(11), obj.Session, irqs);
                obj.Status = status;
            else
                error('NiFpga:AcqIrq', 'Unopened session');
            end
        end
	end
end