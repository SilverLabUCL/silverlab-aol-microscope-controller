function msg = status2msg(status)
%STATUS2MSG Convert NI FPGA status to a textual message
%   MSG = STATUS2MSG(STATUS) converts the NI FPGA STATUS to the textual
%   message MSG.
%
% Example
%   status = NiFpga(1);
%   if status < 0
%       disp(status2msg(status));
%   else
%       NiFpga(2);
%   end
%
% See also: NIFPGA_MEX NIFPGA2MATLAB

% Copyright 2010-2010 Peter Fiala

switch(status)
    case 0
        msg = 'Success';
    case -50400
        msg = 'DMA FIFO Timed Out';
    case -52000
        msg = 'Memory full';
    case -52003
        msg = 'Unexpected software fault';
    case -52005
        msg = 'Invalid parameter';
    case -52006
        msg = 'Resource not found';
    case -52010
        msg = 'Resource not initialized';
    case -61003
        msg = 'Already running';
    case -61024
        msg = 'Device type mismath';
    case -61046
        msg = 'Communication timeout';
    case -61060
        msg = 'Timeout while waiting for IRQ';
    case -61070
        msg = 'Corrupt bitfile';
    case -61141
        msg = 'FPGA busy';
    case -61499
        msg = 'Internal error occured';
    case -63001
        msg = 'DMA from host to FPGA target is not supported for this remote system. Use another method for I/O or change the controller associated with the FPGA target.';
    case -63030
        msg = 'Operation failed due to device reconfiguration. Multiple sessions to FPGA devices are not supported. Close the other session and retry this operation. This error code can occur only with LabVIEW 8.2 and earlier versions. The operation could not complete because another session has reconfigured the device.';
    case -63031
        msg = 'The operation could not be completed because another session is accessing the device. Close all other sessions and retry.';
    case -63033
        msg = 'Access to the remote system was denied.';
    case -63040
        msg = 'A connection could not be established to the specified remote device. Ensure that the device is on and accessible over the network, that NI-RIO software is installed, and that the RIO server is running and properly configured.';
    case -63041
        msg = 'The connection to the remote device has been lost due to an error on the remote device. Retry the operation. If the remote device continues to report this error, check its power supply and look for diagnostic messages on the console.';
    case -63042
        msg = 'A fault on the network caused the operation to fail.';
    case -63043
        msg = 'The session is invalid. The target may have reset or been rebooted. Check the network connection and retry the operation.';
    case -63044
        msg = 'The RIO server could not be found on the specified remote device. Ensure that NI-RIO software is installed and that the RIO server is running and properly configured.';
    case -63050
        msg = 'The specified trigger line is already reserved.';
    case -63051
        msg = 'The specified trigger line is not reserved in the current session.';
    case -63052
        msg = 'Trigger lines are not supported or enabled.';
    case -63070
        msg = 'The specified event type is invalid.';
    case -63071
        msg = 'The specified RIO event has already been enabled for this session.';
    case -63072
        msg = 'The specified RIO event has not been enabled for this session. Attempting a Wait on IRQ after an Abort causes this error.';
    case -63073
        msg = 'The specified event did not occur within the specified time period, in milliseconds. Extend the time period, or ignore if the result was expected.';
    case -63080
        msg = 'The allocated buffer is too small.';
    case -63081
        msg = 'The caller did not allocate a memory buffer.';
    case -63082
        msg = 'The operation could not complete because another session is accessing the FIFO. Close the other session and retry.';
    case -63101
        msg = 'Unable to read bitfile';
    case -63106
        msg = 'Signature mismatch';
    case -63150
        msg = 'An unspecified hardware failure has occurred. The operation could not be completed.';
    case -63180
        msg = 'An invalid alias was specified. RIO aliases may contain only alphanumerics, ''-'', and ''_''.';
    case -63181
        msg = 'The supplied alias was not found.';
    case -63182
        msg = 'An invalid device access setting was specified. RIO device access patterns may contain only alphanumerics, ''-'', ''_'', ''.'', and ''*''.';
    case -63183
        msg = 'An invalid port was specified. The RIO server port must be between 0 and 65535, where 0 indicates a dynamically assigned port. Port 3580 is reserved and cannot be used.';
    case -63187
        msg = 'This remote system does not support connections to other remote systems.';
    case -63188
        msg = 'The operation is no longer supported.';
    case -63189
        msg = 'The supplied search pattern is invalid.';
    case -63192
        msg = 'Either the supplied resource name is invalid as a RIO resource name, or the device was not found. Use MAX to find the proper resource name for the intended device.';
    case -63193
        msg = 'The requested feature is not supported';
    case -63194
        msg = 'The NI-RIO software on the remote system is not compatible with the local NI-RIO software. Upgrade the NI-RIO software on the remote system.';
    case -63195
        msg = 'The handle for device communication is invalid or has been closed. Restart the application.';
    case -63196
        msg = 'An invalid attribute has been specified.';
    case -63197
        msg = 'An invalid attribute value has been specified.';
    case -63198
        msg = 'The system has run out of resources. Close a session and retry the operation.';
    otherwise
        msg = 'Unknown error';
end
msg = [msg,' (code: ',num2str(status),').'];
end