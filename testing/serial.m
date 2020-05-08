classdef serial
    properties
        BytesAvailable
    end
    
    methods
        function s = serial(varargin)
            s.BytesAvailable = 4;
        end
        function s = fopen(varargin)
            s = 1;
        end
        function x = fprintf(varargin)
            x = 2;
        end
        function s = fscanf(varargin)
            s = ['[0 0 0]' sprintf('\r')];
        end
        function s = fclose(varargin)
            s = 1;
        end
    end
    
end

