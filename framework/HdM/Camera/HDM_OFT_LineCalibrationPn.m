function out=HDM_OFT_LineCalibrationPn...
    (i_SpectrometerMeasurement, i_CameraMeasurement, i_PreLinearisationCurve, i_maskImage)

OFT_Env=HDM_OFT_InitEnvironment();

HDM_OFT_Utils.OFT_DispTitle('start line calibration');

if(exist('i_SpectrometerMeasurement','var')==0)
    disp('using reference patch mesurements');
    i_SpectrometerMeasurement=strcat(OFT_IDTProcessorPath,'/cameraLineCalibrationReference/LineCali15042014.xls');
else
    disp(i_SpectrometerMeasurement);
end

if(exist('i_CameraMeasurement','var')==0)
    disp('using reference camera mesurements');
    i_CameraMeasurement=strcat(OFT_IDTProcessorPath,'/cameraLineCalibrationReference/Take021_Img0000050.TIF');
end

if(exist('i_PreLinearisationCurve','var')==0)
    disp('using no linearization');
    i_PreLinearisationCurve='';
end

%% read spectrometer data
HDM_OFT_Utils.OFT_DispSubTitle('read spectrometer data');

l_IntenityAgainstWavelength = HDM_OFT_SpectrumExportImport.ImportSpectrum(i_SpectrometerMeasurement);


%% find peaks
[peak_valueMat, peak_locationMat] = findpeaks(l_IntenityAgainstWavelength(2,:),...
    'minpeakheight',0.5*max(l_IntenityAgainstWavelength(2,:)),...
    'SORTSTR','descend');

[peak_value, peak_location] = HDM_OFT_findpeaks(l_IntenityAgainstWavelength(2,:),...
    6,1,100,...
    0.1*max(l_IntenityAgainstWavelength(2,:)),...
    false);
    
peak_location=int16(peak_location);

OFT_ReferencePeaksWaveLengths=zeros(1,size(peak_value,2));
for peakIndex=1:size(peak_value,2)
    
    if l_IntenityAgainstWavelength(1,peak_location(peakIndex))==min(l_IntenityAgainstWavelength(1,:))
        continue;
    end
    
    if l_IntenityAgainstWavelength(1,peak_location(peakIndex))==max(l_IntenityAgainstWavelength(1,:))
        break;
    end
    
    peakEnv=[l_IntenityAgainstWavelength(1,peak_location(peakIndex)-1),l_IntenityAgainstWavelength(1,peak_location(peakIndex)),l_IntenityAgainstWavelength(1,peak_location(peakIndex)+1);...
        l_IntenityAgainstWavelength(2,peak_location(peakIndex)-1),peak_value(peakIndex),l_IntenityAgainstWavelength(2,peak_location(peakIndex)+1)];
    
    a=polyfit(peakEnv(1,:),peakEnv(2,:),2);    
    k = polyder(a);    
    r=roots(k);
    
    OFT_ReferencePeaksWaveLengths(1,peakIndex)=r;    
    polyval(a,r);
    
end

%pos=get(gcf,'Position');pos(1)=pos(1)+15;pos(2)=pos(2)-15;
%figure('Position',pos,'Name','Line Calibration')
figure('Name','Line Calibration Input')
subplot(2,2,1)
plot(l_IntenityAgainstWavelength(1,:),l_IntenityAgainstWavelength(2,:))
%//!!!hx = graph2d.constantline(OFT_ReferencePeaksWaveLengths(1,:), 'LineStyle',':', 'Color',[.7 .7 .7]);
%//!!!changedependvar(hx,'x');

for cur = 1 : size(OFT_ReferencePeaksWaveLengths, 2)
    
    hold on
    
    plot([OFT_ReferencePeaksWaveLengths(1, cur) OFT_ReferencePeaksWaveLengths(1, cur)],ylim)
    
end

xlabel('wavelength in nm')
ylabel('intensity in W/(nm * m^2)')
title('line spectrum measured by spectrometer');


%% read camera line spectrum image
HDM_OFT_Utils.OFT_DispSubTitle('read camera line spectrum image');

%not aequidistant

%% find rect mask for spectrum region
l_maskImage = medfilt2(rgb2gray(HDM_OFT_ImageExportImport.ImportImage(i_maskImage)));
l_maskImage1 = im2bw(l_maskImage, 0.05);

if usejava('Desktop')
	subplot(2,2,2),imshow(l_maskImage1);
end

%Find Plate
[lab, n] = bwlabel(l_maskImage1);

regions = regionprops(lab, 'All');
regionsCount = size(regions, 1) ;

l_area = 0;
l_boundingBox4MaxArea = [];

for i = 1:regionsCount
    
    region = regions(i);
    
    if(l_area < region.Area)
        
        l_boundingBox4MaxArea = region.BoundingBox;
        l_area = region.Area;
        
    end

end

% l_boundingBox4MaxArea(2) = l_boundingBox4MaxArea(2) + 0.25 * l_boundingBox4MaxArea(4);
% l_boundingBox4MaxArea(4) = 0.5 * l_boundingBox4MaxArea(4);

%% read sopectrum image and masking

OFT_SpectrumImageFromFile=HDM_OFT_ImageExportImport.ImportImage(i_CameraMeasurement, i_PreLinearisationCurve);
[OFT_SpectrumImageFromFileHeight, OFT_SpectrumImageFromFileWidth,OFT_SpectrumImageFromFilefChannels]=size(OFT_SpectrumImageFromFile);

OFT_SpectrumImageFromFile(1:round(l_boundingBox4MaxArea(2)), :, :) = 0;
OFT_SpectrumImageFromFile(round(l_boundingBox4MaxArea(2) + l_boundingBox4MaxArea(4)) : size(OFT_SpectrumImageFromFile, 1), :, :) = 0;

OFT_SpectrumImageFromFile(:, 1:round(l_boundingBox4MaxArea(1)), :) = 0;
OFT_SpectrumImageFromFile(:, round(l_boundingBox4MaxArea(1) + l_boundingBox4MaxArea(3)) : size(OFT_SpectrumImageFromFile, 2), :) = 0;

l_subImage = imcrop(OFT_SpectrumImageFromFile, l_boundingBox4MaxArea);

if usejava('Desktop')

	subplot(2,2,2),imshow(l_subImage);

	subplot(2,2,3),imshow(OFT_SpectrumImageFromFile);

end


% obsolete
% OFT_VCenterPos=0;
% OFT_ValidCnt=0;
% OFT_GlobalMax=max(OFT_SpectrumImageFromFile(:));
% for R=1:OFT_SpectrumImageFromFileHeight 
%     [GMax,GMaxInd]=max(OFT_SpectrumImageFromFile(R,:,2));
%     if GMax(1)>0.5*OFT_GlobalMax
%         OFT_VCenterPos=OFT_VCenterPos+R;
%         OFT_ValidCnt=OFT_ValidCnt+1;
%     end
% end
% OFT_VCenterPos=int32(OFT_VCenterPos/OFT_ValidCnt);
% end obsolete

OFT_VCenterPos = round(l_boundingBox4MaxArea(1,2) + (l_boundingBox4MaxArea(1, 4)/2));

[RMax,RMaxInd]=max(OFT_SpectrumImageFromFile(OFT_VCenterPos,:,1));
[GMax,GMaxInd]=max(OFT_SpectrumImageFromFile(OFT_VCenterPos,:,2));

%if required rotate so that blue is always left
if(RMaxInd(1)<GMaxInd(1))
    OFT_SpectrumImage=flipdim(OFT_SpectrumImageFromFile,2);
else
    OFT_SpectrumImage=OFT_SpectrumImageFromFile;
end

OFT_SpectrumImageGray = medfilt2(rgb2gray(OFT_SpectrumImage));

% obsolete
% subplot(2,2,2),imshow(OFT_SpectrumImage);
% 
% [OFT_SpectrumImageHeight, OFT_SpectrumImageWidth,OFT_SpectrumImageNofChannels]=size(OFT_SpectrumImage);
% %OFT_SpectrumImageGray = rgb2gray(OFT_SpectrumImage);
% %//!!!
% %  OFT_SpectrumImage(:,:,1) = 0.1140/0.2989*OFT_SpectrumImage(:,:,1);
% %  OFT_SpectrumImage(:,:,2) = 0.1140/0.5870*OFT_SpectrumImage(:,:,2);
% %  OFT_SpectrumImage(:,:,3) = OFT_SpectrumImage(:,:,3);
%  
%  %0.2989 * R + 0.5870 * G + 0.1140 * B 
%  OFT_SpectrumImageGray = rgb2gray(OFT_SpectrumImage);
% 
% oft_threshold=0.1;
% if(isa(OFT_SpectrumImage,'uint16'))%//!!!
%     oft_threshold=0.01;
%     oft_maxInGrayImage=max(OFT_SpectrumImageGray(:));
%     if(oft_maxInGrayImage<0.8*2^16)
%         OFT_SpectrumImageGray=(0.8*((2^16)-1)/oft_maxInGrayImage)*OFT_SpectrumImageGray;
%     end
% end
%     
% %//!!!OFT_SpectrumImageIntensity=im2bw(rgb2gray(OFT_SpectrumImage),oft_threshold);
% 
% bwimg=zeros(size(OFT_SpectrumImage,1),size(OFT_SpectrumImage,2));
% 
% for l=1:size(OFT_SpectrumImage,1)
% 
%     for m=1:size(OFT_SpectrumImage,2)
% 
%         if(sum(OFT_SpectrumImage(l,m,:))>oft_threshold*3)
% 
%             bwimg(l,m)=1;
% 
%         end
% 
%     end
% 
% end
% 
% OFT_SpectrumImageIntensity=bwimg;
% 
% 
% %OFT_SpectrumImageGray=(OFT_R+OFT_G+OFT_B)/3;
% 
% [OFT_SpectrumImageIntensityHeight, OFT_SpectrumImageIntensityWidth,OFT_SpectrumImageIntensityNofChannels]=size(OFT_SpectrumImageIntensity);
% 
% subplot(2,2,3),imshow(OFT_SpectrumImageGray);
% subplot(2,2,3),imshow(OFT_SpectrumImageIntensity);
% %improfile
% OFT_SpectrumROI_Top=0;
% OFT_SpectrumROI_Bottom=OFT_SpectrumImageIntensityHeight;
% 
% [WMax,WMaxInd]=max(OFT_SpectrumImageIntensity(OFT_VCenterPos,:));
% 
% for R=1:OFT_SpectrumImageIntensityHeight
%     
%     [WMaxCur,WMaxIndCur]=max(OFT_SpectrumImageIntensity(R,:));
%     if (WMaxCur(1)>0 && abs(WMaxIndCur(1)-WMaxInd(1))<=3)
%         OFT_SpectrumROI_Top=R;
%         break;
%     end
% end
% 
% for R=OFT_SpectrumImageIntensityHeight:-1:1
%     
%     [WMaxCur,WMaxIndCur]=max(OFT_SpectrumImageIntensity(R,:));
%     if (WMaxCur(1)>0 && abs(WMaxIndCur(1)-WMaxInd(1))<=3)
%         OFT_SpectrumROI_Bottom=R;
%         break;
%     end
% end
% obsolete end

OFT_SpectrumROI_Top = round(l_boundingBox4MaxArea(2));
OFT_SpectrumROI_Bottom = round(l_boundingBox4MaxArea(2) + l_boundingBox4MaxArea(4));
% OFT_CenterDistance = 1;

% OFT_Center = OFT_SpectrumROI_Top+(OFT_SpectrumROI_Bottom-OFT_SpectrumROI_Top)*0.5;

OFT_Spectrum_MeanOfRows = zeros(1, size(OFT_SpectrumImageGray, 2));
OFT_Spectrum_TopRow = double(OFT_SpectrumImageGray(OFT_SpectrumROI_Top, :));
OFT_Spectrum_BottomRow = double(OFT_SpectrumImageGray(OFT_SpectrumROI_Bottom, :));
    
% norm
s1 = (OFT_Spectrum_TopRow - mean(OFT_Spectrum_TopRow)) / std(OFT_Spectrum_TopRow);
s2 = (OFT_Spectrum_BottomRow - mean(OFT_Spectrum_BottomRow)) / std(OFT_Spectrum_BottomRow);

% phase shift
%//!!! c = xcorr(s1, s2);                       %// Cross correlation
% lag = mod(find(c == max(c)), length(s2)); %// Find the position of the peak
% 
% %OFT_LineCaliTilt=(OFT_SpectrumImageWidth-lag)/(100)*360/(2*pi)/(OFT_SpectrumROI_Top-OFT_SpectrumROI_Bottom)
% OFT_LineCaliTilt=(lag/double((OFT_SpectrumROI_Bottom-OFT_SpectrumROI_Top)))*360.0/(2.0*pi);
% OFT_LineCaliTilt=0;%//!!!
% OFT_SpectrumImageGray=imrotate(OFT_SpectrumImageGray,OFT_LineCaliTilt,'crop');

% subplot(2,2,2),imshow(OFT_SpectrumImageIntensity);
%//!!!subplot(2,2,3),imshow(imcomplement(imrotate(OFT_SpectrumImageIntensity,OFT_LineCaliTilt)));

for R=OFT_SpectrumROI_Top:OFT_SpectrumROI_Bottom
    cur=OFT_SpectrumImageGray(R,:);
    add=OFT_Spectrum_MeanOfRows(1,:);
    OFT_Spectrum_MeanOfRows=(double(add)+double(cur));
end

OFT_Spectrum_MeanOfRows=OFT_Spectrum_MeanOfRows/cast((OFT_SpectrumROI_Bottom-OFT_SpectrumROI_Top),'like',OFT_Spectrum_MeanOfRows);
OFT_Spectrum_MeanOfRows=OFT_Spectrum_MeanOfRows/max(OFT_Spectrum_MeanOfRows(1,:));
% OFT_Spectrum_MeanOfRows=medfilt1(OFT_Spectrum_MeanOfRows,10);
OFT_Spectrum_MeanOfRowsFlipped=fliplr(OFT_Spectrum_MeanOfRows);


threshold=0.1;%//!!! 0.2 for BL75 0.12 for zup 40
%[OFT_SpectrumImage_peak_valueMat, OFT_SpectrumImage_peak_locationMat] = ...
%    findpeaks(OFT_Spectrum_MeanOfRows,'MINPEAKHEIGHT',threshold * max(OFT_Spectrum_MeanOfRows),...
%    'SORTSTR','descend');%...
%    %,'THRESHOLD',0.01*(min(OFT_Spectrum_MeanOfRows)+1))
    
% [OFT_SpectrumImage_peak_valueFlippedMat, OFT_SpectrumImage_peak_locationFlippedMat] = ...
%     findpeaks(OFT_Spectrum_MeanOfRowsFlipped,'MINPEAKHEIGHT',threshold * max(OFT_Spectrum_MeanOfRowsFlipped),...
%     'SORTSTR','descend');%...
%     %,'THRESHOLD',0.01*(min(OFT_Spectrum_MeanOfRows)+1))
    
    
[OFT_SpectrumImage_peak_value, OFT_SpectrumImage_peak_location] = HDM_OFT_findpeaks(OFT_Spectrum_MeanOfRows,...
    6,1,100,...
    threshold * max(OFT_Spectrum_MeanOfRows),...
    false);

[OFT_SpectrumImage_peak_valueFlipped, OFT_SpectrumImage_peak_locationFlipped] = HDM_OFT_findpeaks(OFT_Spectrum_MeanOfRowsFlipped,...
    6,1,100,...
    threshold * max(OFT_Spectrum_MeanOfRowsFlipped),...
    false);
    
width=size(OFT_SpectrumImageGray,2);    
OFT_SpectrumImage_peak_locationFlipped=(-1*OFT_SpectrumImage_peak_locationFlipped)+width;

shiftC=0;%//!!!18 f?r BL75 und 5 fuer ZP40
OFT_SpectrumImage_peak_location=0.5*(OFT_SpectrumImage_peak_location+OFT_SpectrumImage_peak_locationFlipped)+shiftC;%+5/2;%//!!!

x=OFT_SpectrumImage_peak_location(1,:)
if OFT_SpectrumImage_peak_location(1,1)>OFT_SpectrumImage_peak_location(1,2)
    x=fliplr(x);
end 
v=OFT_ReferencePeaksWaveLengths(1,1:size(x,2))
if OFT_ReferencePeaksWaveLengths(1,1)>OFT_ReferencePeaksWaveLengths(1,2)
    v=fliplr(v);
    %//!!!sort
    v=sort(v);
end 

%//!!!sort
x=sort(x);
%//!!!sort
v=sort(v);

OFT_SpectrumImagePixelColumnIndex=interp1(x,v,1 : 1 : size(OFT_SpectrumImageGray, 2),'linear','extrap');%//!!!'linear',
% AAZUP40 empiric correction OFT_SpectrumImagePixelColumnIndex=OFT_SpectrumImagePixelColumnIndex-5;

l_WaveLengthOfHorizontalPixelCoordinatePolynomial = polyfit(x,v,2);

l_WaveLengthOfHorizontalPixelCoordinate = zeros(size(OFT_SpectrumImageGray, 2), 1)';

for cur = 1 : size(OFT_SpectrumImageGray, 2)
   
    l_WaveLengthOfHorizontalPixelCoordinate(cur) = l_WaveLengthOfHorizontalPixelCoordinatePolynomial(1) * cur * cur ...
                                                   + l_WaveLengthOfHorizontalPixelCoordinatePolynomial(2) * cur ...
                                                   + l_WaveLengthOfHorizontalPixelCoordinatePolynomial(3);
    
end

OFT_SpectrumImagePixelColumnIndex = l_WaveLengthOfHorizontalPixelCoordinate;

subplot(2,2,4)
plot(s1,'g');
hold on
plot(s2,'b');
hold on
plot(OFT_Spectrum_MeanOfRows(1,:)/max(OFT_Spectrum_MeanOfRows(1,:)),'r');
%//!!!hx = graph2d.constantline(OFT_SpectrumImage_peak_location(1,:), 'LineStyle',':', 'Color',[.7 .7 .7]);
%//!!!changedependvar(hx,'x');
legend({'Top Row:(i-mean(I))/\sigma (I)','Bottom Row:(i-mean(I))/\sigma (I)','All Rows: normalized mean value'})
xlabel('horicontal pixel index')
ylabel('pixel value')
title('detected lines (vertical gray bars)');

% OFT_start=find(OFT_SpectrumImagePixelColumnIndex>300);
% OFT_end=find(OFT_SpectrumImagePixelColumnIndex>900);
% 
% OFT_first=OFT_start(1);
% OFT_last=OFT_end(1);

%OFT_SpectrumImagePixelColumnIndex=OFT_SpectrumImagePixelColumnIndex(OFT_first:OFT_last)
%OFT_Spectrum_MeanOfRows=OFT_Spectrum_MeanOfRows(1,OFT_first:OFT_last)

figure('Name','Line Calibration Result')
plot(l_IntenityAgainstWavelength(1,:),l_IntenityAgainstWavelength(2,:)/max(l_IntenityAgainstWavelength(2,:)))
hold on
plot(OFT_SpectrumImagePixelColumnIndex,OFT_Spectrum_MeanOfRows(1,:)/max(OFT_Spectrum_MeanOfRows(1,:)),'r');
%//!!!hx = graph2d.constantline(OFT_ReferencePeaksWaveLengths(1,:), 'LineStyle',':', 'Color',[.7 .7 .7]);
%//!!!changedependvar(hx,'x');

for cur = 1 : size(OFT_ReferencePeaksWaveLengths, 2)
    
    hold on
    
    plot([OFT_ReferencePeaksWaveLengths(1, cur) OFT_ReferencePeaksWaveLengths(1, cur)],ylim)
    
end

xlim([350 850])

legend({'normalized reference spectrometer data','normalized mean value of camera spectrum'})
xlabel('mapped hypothetical wavelength in nm')
ylabel('relative intensity')
title('found and mapped two dominant lines (vertical gray bars)');

out=OFT_SpectrumImagePixelColumnIndex;

HDM_OFT_Utils.OFT_DispTitle('line calibration succesfully finished');

end



%//!!!
%MEDFILT1       One-dimensional median filter
%
%       y = MEDFILT(x)
%       y = MEDFILT(x, w)
%
%       median filter the signal with window of width W (default is 5).

% Copyright (C) 1995-2009, by Peter I. Corke
%
% This file is part of The Machine Vision Toolbox for Matlab (MVTB).
% 
% MVTB is free software: you can redistribute it and/or modify
% it under the terms of the GNU Lesser General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
% 
% MVTB is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU Lesser General Public License for more details.
% 
% You should have received a copy of the GNU Leser General Public License
% along with MVTB.  If not, see <http://www.gnu.org/licenses/>.
function m = medfilt1(s, w)
        if nargin == 1,
                w = 5;
        end
        
        s = s(:)';
        w2 = floor(w/2);
        w = 2*w2 + 1;

        n = length(s);
        m = zeros(w,n+w-1);
        s0 = s(1); sl = s(n);

        for i=0:(w-1),
                m(i+1,:) = [s0*ones(1,i) s sl*ones(1,w-i-1)];
        end
        m = median(m);
        m = m(w2+1:w2+n);
end