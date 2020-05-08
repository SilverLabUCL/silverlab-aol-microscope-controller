function varargout = typecon(nicast)
%TYPECON Convert NI FPGA data class to C and Matlab types
%   [CCAST, MEXCAST, MATCAST] = TYPECON(NICAST) converts the LabView NICAST
%   to C and Matlan types.
%
% Example
%   [ccast, mexcast, matcast] = typecon('Bool');
%
% See also: NIFPGA2MATLAB

% Copyright 2010-2013 Peter Fiala

data = {
    'Bool', 'NiFpga_Bool', 'mxUINT8_CLASS',  'uint8'
    'I8',   'int8_t',      'mxINT8_CLASS',   'int8'
    'U8',   'uint8_t',     'mxUINT8_CLASS',  'uint8'
    'I16',  'int16_t',     'mxINT16_CLASS',  'int16'
    'U16',  'uint16_t',    'mxUINT16_CLASS', 'uint16'
    'I32',  'int32_t',     'mxINT32_CLASS',  'int32'
    'U32',  'uint32_t',    'mxUINT32_CLASS', 'uint32'
    'I64',  'int64_t',     'mxINT64_CLASS',  'int64'
    'U64',  'uint64_t',    'mxUINT64_CLASS', 'uint64'
    };

[isinside, where] = ismember(nicast, data(:,1));
if isinside
    varargout = data(where,2:end);
else
    error('NiFpga:badarg', 'Invalid input argument %s', nicast);
end

end
