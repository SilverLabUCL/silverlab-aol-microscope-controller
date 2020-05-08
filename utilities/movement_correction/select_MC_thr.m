%% Select movement correction threshold from selected ROI
% -------------------------------------------------------------------------
% Syntax: 
% thresholds = select_MC_thr(cropped)
%
% -------------------------------------------------------------------------
% Inputs: 
%   cropped([N X M] UINT16):
%                                   The frame coming from the selected ROI.
%                                   IF N = M, we assume XY movement only.
%                                   If M > N, the we assume M-N Z lines.
%                                   For now, XY-ref must be square
% -------------------------------------------------------------------------
% Outputs:
%   thresholds([1 X 2] UINT16 OR [NaN, NaN]):
%                                   XY and Z Threshold.
%                                   If there are no Z lines, then 
%                                   Z-threshold == XY-threshold. If
%                                   selection proces is cancelled, we
%                                   return NaNs
%
% -------------------------------------------------------------------------
% Extra Notes:
% * for testing : select_MC_thr(randi(2000,23,18));
%   When changing the XY threshold slider, the Z slider is updated too with
%   a smalled value. The value comes from the lowest 20th percentile from 
%   the thresholded object. You may want the same value than for XY, but 
%   having a lower threshold allow the vertical scan to keep working even
%   when being on the edge of the reference.
% -------------------------------------------------------------------------
% Examples:
% -------------------------------------------------------------------------
%                               Notice
%
% Author(s): Antoine Valera
%
% This function was initially released as part of The SilverLab MatLab
% Imaging Software, an open-source application for controlling an
% Acousto-Optic Lens laser scanning microscope. The software was 
% developed in the laboratory of Prof Robin Angus Silver at University
% College London with funds from the NIH, ERC and Wellcome Trust.
%
% Copyright © 2015-2020 University College London
%
% Licensed under the Apache License, Version 2.0 (the "License");
% you may not use this file except in compliance with the License.
% You may obtain a copy of the License at
% 
%     http://www.apache.org/licenses/LICENSE-2.0
% 
% Unless required by applicable law or agreed to in writing, software
% distributed under the License is distributed on an "AS IS" BASIS,
% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
% See the License for the specific language governing permissions and
% limitations under the License. 
% -------------------------------------------------------------------------
% Revision Date:
%   14-03-2019
%
% See also: prepare_MC_Ref, select_ROI, Controller.prepare_daq_for_mc

function thresholds = select_MC_thr(cropped)
    global I first_run z_lines
    
    %% Generate Figure
    I.fig = figure(1051);
    z_lines = max(size(cropped)) - min(size(cropped));
    first_run = true;
    I.croppedxy = rot90(cropped(1:end-z_lines,:));
    I.croppedz  = cropped(end-z_lines+1:end,:)'; % May be empty if no zlines detected
    I = image_plot(I);
    
    %% Wait until figure is closed
    uiwait();
    
    %% Get thresholds from Global I
    drawnow; pause(0.1);
    if ~z_lines % If no Z line, set Z threshold as XY
       I.thrZ = I.thrXY;
    end
    thresholds = [I.thrXY, I.thrZ]; 
    thresholds(isinf(thresholds)) = 0;
    thresholds = round(thresholds);
    
    clear global
end

function I = image_plot(I)
   global first_run
   
   %% Initialise tool
   if first_run
       %% Create figure
       figure(1051);cla();
       
       %% Prepare X-Y plot
       subplot(1,2,1);
       I.thrXY = max(I.croppedxy(:))/2; % Suggest half max as initial value   
       I.title1 = title(num2str(round(I.thrXY))); hold on;
       I.thrXY_im = I.croppedxy > I.thrXY; % Binarize view
       I.XY = imagesc(I.thrXY_im); axis image       
       max_xy = max(I.croppedxy(:));
       
       %% If any Z-Lines, Prepare Z plot
       if ~isempty(I.croppedz)
           subplot(1,2,2);
           cont = logical(imdilate(I.thrXY_im,strel('disk',1)) - I.thrXY_im);
           I.thrZ = prctile(I.croppedxy(cont),20);
           I.title2 = title(num2str(round(I.thrZ))); hold on;
           I.thrZ_im = I.croppedz > I.thrZ;
           I.Z  = imagesc(I.thrZ_im);axis image   
           max_z = max(I.croppedz(:));
       else
           max_z = [];
       end
       first_run = false;
   end

   %% Add sliders, and set values with auto-detected thresholds
   uicontrol('Style', 'pushbutton', 'String', 'Cancel', 'Position', [500 20 50 30], 'Callback', @(a,b) cancel);
   uicontrol('Style', 'pushbutton', 'String', 'Ok', 'Position', [500 50 50 30], 'Callback', @(a,b) ok);
   I.xy_threshold_slider = uicontrol('style','slide',...
                                     'unit','pix',...
                                     'position',[50 20 260 20],...
                                     'min',0,'max',max_xy,'val',max_xy/2,...
                                     'sliderstep',[0.01 0.01],...
                                     'Value',I.thrXY,...
                                     'callback',{@update,I},...
                                     'String','XY'); 
   if ~isempty(max_z)              
       I.z_threshold_slider = uicontrol( 'style','slide',...
                                         'unit','pix',...
                                         'position',[330 20 160 20],...
                                         'min',0,'max',max_z,'val',max_z/2,...
                                         'sliderstep',[0.01 0.01],...
                                         'Value',I.thrZ,...
                                         'callback',{@update,I},...
                                         'String','Z'); 
   end
                 
end

function update(varargin)
    %% Called when changing any slider value
    [h, ~] = varargin{[1,3]};  % calling handle and data structure.
    global I;
    
    %% Update XY-Z or Z threshold
    if strcmp(varargin{1}.String,'XY') % If changing XY slider       
        %% Get new threshold
        I.thrXY = uint16(h.Value);
        I.title1.String = num2str(round(I.thrXY)); hold on;        
        I.thrXY_im = I.croppedxy > I.thrXY; % thresholded preview
        I.XY.CData = I.thrXY_im;
        
        %% Update Z with a value recovered from the edges of the XY-ROI
        contour = logical(imdilate(I.thrXY_im,strel('disk',1)) - I.thrXY_im);
        I.thrZ = prctile(I.croppedxy(contour),20);   
        I.thrZ_im = I.croppedz > I.thrZ; % thresholded preview
        I.Z.CData = I.thrZ_im;
        I.title2.String = num2str(round(I.thrZ));
    else
        I.thrZ = uint16(h.Value);  
        I.title2.String = num2str(round(I.thrZ));
        I.thrZ_im = I.croppedz > I.thrZ; % thresholded preview
        I.Z.CData = I.thrZ_im;
    end
    %imagesc(I.thrXY_im);axis tight
end

function cancel()
    %% Called when user clicks on cancel. Return NaNs
    
    close(figure(1051));
    global I
    I.thrXY = nan;
    I.thrZ = nan;
end

function ok()
    %% Called when user clicks on cancel. Continue function execution

    close(figure(1051));
end