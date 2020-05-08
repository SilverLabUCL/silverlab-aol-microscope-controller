classdef CTargetToHostFifo < CNiFpgaFifo
    %CTARGETTOHOSTFIFO NiFpga Class for TargetToHost Fifo operations

    % Copyright 2010-2010 Peter Fiala
    properties
        funselect % uint32 function selector
    end

    methods
        function obj = CTargetToHostFifo(Address, funselect)
            obj = obj@CNiFpgaFifo(Address);
            obj.funselect = funselect;
        end

        function [status, data, numElemsRead] = read(obj, fast_read, numElemsToRead, timeOut, daq)
            %% Read FIFO use NI CAPI call.
            % -------------------------------------------------------------
            % Syntax: 
            % [status, data, numElemsRead] = 
            %   CNiFpgaFifo.read(fast_read, numElemsToRead, timeOut, daq)
            % -------------------------------------------------------------
            % Inputs: 
            %   fast_read (BOOL)
            %       If true, reads data on the C++ pipe instead on the FIFO
            %
            %   numElemsToRead (INT)
            %       The number of elements to read from FIFO. Use 0 to Poll
            %       FIFO.
            %
            %   timeOut (INT)
            %       In ms, the time before returning an error
            %
            %   daq (DaqFpga handle)
            %       handle used to access daq or capi settings
            % -------------------------------------------------------------
            % Outputs: 
            %   status (INT)
            %       NiFPGA satus code
            %
            %   data ([1 X N UINT16])
            %       Data from the selected channel.
            %
            %   numElemsRead (INT)
            %       The number of points in data if numElemsToRead > 0 or
            %       the number of data in the FIFO if numElemsToRead == 0
            % -------------------------------------------------------------
            % Extra Notes:
            % - if ~obj.Session, you are in simulation mode. The code will
            % return numElemsToRead random values.
            %
            %  - Using fast_read will use the C++ pipe. To do so, you must
            %  have called obj.start_pipes first, and must call
            %  obj.stop_pipe at the end. Failing to do so will certainly
            %  crash your computer...(cf NiFpga code 5060 - 5065)
            %
            %  - If the FIFOs memory addresses change, you have to modify 
            % the c++ code too (see comments in the code) to match the new
            % adresses. see NiFpga_mex.cpp
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera, Boris Marin, Geoffrey Evans
            %---------------------------------------------
            % Revision Date:
            %   14-03-2019
            %
            % See also: NiFpga_mex.cpp
            
            if ~daq.capi.live_scan
                pause(0)
            end
            
            %% Check type of reading mode and adjust call accordingly
            if isempty(obj.Session)
                %% Unopend session. Should not happen
                error('CTargetToHostFifo:Read', 'Unopened session');
            elseif ~obj.Session %&& obj.is_imaging 
                %% Offline / simulation
                data = uint16(randi(2^16,daq.points_to_read(1),1)); %% qq not fully simulating variable number of datapoints per channel
                status = 1;
                numElemsRead = numElemsToRead; % Always return as many points as asked
            elseif ~daq.capi.flag1_read
                %% Happens when pipe is interrupted between channel 1 and channel 2 read, and with Poll FIFOs
                [status, data, numElemsRead] = return_empty_data(obj, numElemsToRead);
            elseif fast_read && ~daq.dump_data
                %% Normal read, using C pipe
                [status, data, numElemsRead] = NiFpga(uint32(5061), obj.Session, obj.Address, uint32(numElemsToRead), uint32(timeOut));
            elseif fast_read && daq.dump_data
                %% Normal read, using C pipe, but dumping data
                [status, data, numElemsRead] = NiFpga(uint32(5064), obj.Session, obj.Address, uint32(numElemsToRead), uint32(timeOut));
            elseif ~fast_read
                %% Normal read, using direct call (No Pipe)
                % To prevent calling the function too often, we wait until
                % there is enough data
                wait_until_FIFO_has_enough_data(obj, numElemsToRead, timeOut);

                %% Now read numElemsToRead
                [status, data, available] = NiFpga(obj.funselect, obj.Session, obj.Address, uint32(numElemsToRead), uint32(timeOut));
                if ~numElemsToRead % numElemsToRead is 0 when using poll_FIFO.
                    numElemsRead = available;
                    % numElemsRead is what is available in FIFO
                else
                    numElemsRead = numel(data);
                end
            end
        end
        
        function [status, data, numElemsRead] = return_empty_data(~, numElemsToRead)
            %% Called when the DaqFpga.read function is interrupted
            % -------------------------------------------------------------
            % Syntax: 
            % [status, data, numElemsRead] = 
            %       CNiFpgaFifo.return_empty_data(numElemsToRead)
            % -------------------------------------------------------------
            % Inputs: 
            %   numElemsToRead (INT)
            %       The number of elements to read from FIFO. Use 0 to Poll
            %       FIFO.
            % -------------------------------------------------------------
            % Outputs: 
            %   status (0)
            %       Returned status is false as we have to detect the issue
            %
            %   data ([1 X N UINT16 ONES])
            %       Ones of the required length
            %
            %   numElemsRead (INT)
            %       The number of points in data
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   14-03-2019

            %% Generate sham data
            data = uint16(ones(numElemsToRead,1));
            numElemsRead = numElemsToRead;
            status = false;
        end
        
        function wait_until_FIFO_has_enough_data(obj, numElemsToRead, timeOut)
            %% Wait until there is enough data in FIFO (or did 10 iterations)
            % -------------------------------------------------------------
            % Syntax: 
            % CNiFpgaFifo.wait_until_FIFO_has_enough_data(min_num_elem, timeOut)
            % -------------------------------------------------------------
            % Inputs: 
            %   numElemsToRead (INT)
            %       The number of elements to wait for before reading from
            %       FIFO.
            %
            %   timeOut (INT)
            %       In ms, the time before returning an error
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            % -------------------------------------------------------------
            % Author(s):
            %   Antoine Valera
            %---------------------------------------------
            % Revision Date:
            %   14-03-2019

            numElemsRead = -1;
            counter = 0;
            while numElemsRead < numElemsToRead && counter < 10
                [~, ~, numElemsRead] = NiFpga(obj.funselect, obj.Session, obj.Address, uint32(0), uint32(timeOut)); % Basically a poll_FIFO in a while loop
                counter = counter + 1;
            end
        end
        
        function start_pipes(obj, numElemsToRead, timeOut, dump_data, capi, verbose) 
            %% Start Pipe using code 5060 or 5060 (data dump)
            % -------------------------------------------------------------
            % Syntax: 
            % CNiFpgaFifo.start_pipes(numElemPipeRead, timeOut, dump_data, capi)
            % -------------------------------------------------------------
            % Inputs: 
            %   numElemsToRead (INT)
            %       The number of elements to wait for before reading from
            %       FIFO.
            %
            %   timeOut (INT)
            %       In ms, the time before returning an error
            %
            %   dump_data (BOOL)
            %       If true, we will data will be written in a bin file
            %       instead of beaing returned
            %
            %   capi (CNiFpgaBitfile object)
            %       A NiFpga CAPI object. This is typically located in
            %       Controller.daq_fpga.capi
            %
            %   verbose (BOOL) 
            %       If true, we indicate the start of recording
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            %  WARNING : pipe size fixed in mex. DO NOT MESS UP WITH THE
            %  MAX BUFFER BECAUSE THAT WILL JUST IMMEDIATELY CRASH THE PC.
            %  
            %  capi.flag2_read    is a hardware flag that can be shared
            %  between the matlab and C pipe code to know what is the
            %  current status of the pipe. If true, pipe were started and
            %  won't be restarted
            % -------------------------------------------------------------
            % Author(s):
            %   Boris Marin, Geoffrey Evans, Antoine Valera 
            %---------------------------------------------
            % Revision Date:
            %   14-03-2019
            
            %% QQ THAT IS A HACK. IT SHOULD NOT BE HERE BUT MAY SAVE YOUR LIFE
            if numElemsToRead > 32768
                numElemsToRead = 32768;
            end
            
            %% If not already started, start pipe
            if ~isempty(obj.Session) && ~dump_data && ~capi.flag2_read
                if verbose
                    fprintf("        ...C PIPE : Starting pipes thread...\n");
                end
                capi.flag2_write = 1; %% qq that would be better if set in the pipe call
                NiFpga(uint32(5060), obj.Session, obj.Address, uint32(max(numElemsToRead)), uint32(timeOut));
            elseif ~isempty(obj.Session) && dump_data && ~capi.flag2_read
                if verbose
                    fprintf("        ...C PIPE : Starting pipes thread. Writing data on HD...\n");
                end
                capi.flag2_write = 1; %% qq that would be better if set in the pipe call
                NiFpga(uint32(5063), obj.Session, obj.Address, uint32(max(numElemsToRead)), uint32(timeOut));
            elseif isempty(obj.Session)
                error('CTargetToHostFifo:StartPipe', 'Unopened session');
            end
        end
        
        function stop_pipes(obj, dump_data, capi, verbose)
            %% Stop Pipe using code 5062 or 5065 (data dump)
            % -------------------------------------------------------------
            % Syntax: 
            % CNiFpgaFifo.stop_pipes(dump_data, capi)
            % -------------------------------------------------------------
            % Inputs: 
            %   dump_data (BOOL)
            %       If true, we will data will be written in a bin file
            %       instead of beaing returned
            %
            %   capi (CNiFpgaBitfile object)
            %       A NiFpga CAPI object. This is typically located in
            %       Controller.daq_fpga.capi
            %
            %   verbose (BOOL) 
            %       If true, we indicate the start of recording
            % -------------------------------------------------------------
            % Outputs: 
            % -------------------------------------------------------------
            % Extra Notes:
            %  capi.flag2_read is a hardware flag that can be shared
            %  between the matlab and C pipe code to know what is the
            %  current status of the pipe. If false, pipes are not running
            %  and won't be stopped again.
            % -------------------------------------------------------------
            % Author(s):
            %   Boris Marin, Geoffrey Evans, Antoine Valera 
            %---------------------------------------------
            % Revision Date:
            %   14-03-2019
            
            if ~isempty(obj.Session) && ~dump_data && capi.flag2_read                   
            	NiFpga(uint32(5062), obj.Session, obj.Address);
                capi.flag2_write = 0; %% qq that would be better if set in the pipe call
                if verbose
                    fprintf("        ...C PIPE : pipes thread stopped...\n");
                end
            elseif ~isempty(obj.Session) && dump_data && capi.flag2_read
            	NiFpga(uint32(5065), obj.Session, obj.Address);
                capi.flag2_write = 0; %% qq that would be better if set in the pipe call
                if verbose
                    fprintf("        ...C PIPE : pipes thread stopped. Finished writing data on HD...\n");
                end
            elseif isempty(obj.Session) 
                error('CTargetToHostFifo:StopPipes', 'Unopened session');
            end
        end
    end
end