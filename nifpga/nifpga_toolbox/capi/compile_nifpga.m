%% SCRIPT TO (RE)COMPILE C PIPE IF YOU DO ANY CHANGES IN NiFpga_mex or Pipe.C
% * YOU MUST RUN THIS CODE FROM WITHIN THE CAPI FOLDER to compile it
% * If matlab is installed in another path, correct accordingly
% * If you recompile the NIFPGA toolbox with a new version for example,
%   important cpipe function will be erased (as they are not standard) and
%   will need to be regenerated 

mex('-g', '-output', 'NiFpga', 'NiFpga_mex.cpp', 'NiFpga.c', '-I./', '-L./',...
    '-LC:/Progra~1/MATLAB/R2017b/extern/lib/win64/microsoft/', '-ltestdll', '-lpthreadVC2', '-llibut') % works for 64 bit

%% 32 bits note
% for 32 bit need 32 bit versions of testdll (recompile using mingw32 bit
% compiler, need c99) and pthreadVC2 (download). Change win64 to win32 in
% '\extern\lib\win64\microsoft\libut'

%% Pthread source code is 2.11  There is a v3 available
% https://sourceforge.net/projects/pthreads4w/

%% pipe.c code:
% https://github.com/cgaebel/pipe

%% There is code here to have an asynchronous C interrupt code :
%//https://www.advanpix.com/2016/07/02/devnotes-3-proper-handling-of-ctrl-c-in-mex-module

%% If you recompile the NIFPGA toolbox (NiFPGA_install), the pipe code will be erased
%  This may be necessary if you update the NI CAPI (currently V17.0)

%% From http://zone.ni.com/reference/en-XX/help/372928G-01/capi/overview/
% What You Can Do with the FPGA Interface C API
% The FPGA Interface C API enables C/C++ applications to interact directly 
% with compiled LabVIEW FPGA VIs on RIO devices without using LabVIEW.
% C/C++ applications can download a VI to a RIO target, perform DMA data 
% transfers, wait on and acknowledge interrupts, and read from and write
% to named controls and indicators using C function calls.
% 
% A C/C++ application created with the C API can run on the real-time 
% processor of a CompactRIO or NI Single-Board RIO device, and interact
% with VIs running on the FPGA of the RIO system. Alternatively, a C/C++ 
% application can run on the real-time processor of a PXI system or the 
% processor of a Windows or Linux PC, and interact with VIs running on the
% FPGA of a PXI or PCI RIO device.
% 
% What You Cannot Do with the C API
% The current version of the C API does not support the following features.
% 
% -Scan Interface mode and I/O variables
% -Reading from and writing to controls, indicators, and FIFOs containing the following:
%   Fixed-point types
%   Floating-point types
%   Clusters
%   Arrays containing anything other than supported scalar types
% 
% -The following methods callable from an Invoke Method node:
%   Read TEDS
%   NI 9802 methods
%       Mount SD Card
%       Unmount SD Card
%   NI FlexRIO Adapter Module methods
%       Control IO Module Power
%       IO Module Status
%       Redetect IO Module