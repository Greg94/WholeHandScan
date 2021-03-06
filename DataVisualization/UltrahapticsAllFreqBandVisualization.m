%% Visualize PDV data 
% Created on 01/29/2019 based on 'UltrahapticsVisualization.m'
% -------------------------------------------------------------------------
% clear all
% -------------------------------------------------------------------------
is1ms = 0; % 1: 1m/s, otherwise: 11m/s

if is1ms
    dataName = 'Greg_MovingSpot_1ms_Dir1';
else
    dataName = 'Greg_MovingSpot_11ms_Dir1';
end

% -------------------------------------------------------------------------
MapPath = './UltrahapticsMeasurement/';
DataPath = sprintf('../Data_Ultrahaptics/%s_1.svd',dataName);
OutputPath = './UltrahapticsVideo/';

cleanDataPath1 = sprintf('../Data_Ultrahaptics/%s_1.mat',dataName);
% cleanDataPath1 = sprintf('../Data_Ultrahaptics/%s_2.mat',dataName);
load(cleanDataPath1);

Alpha = 25.5; % (mm)
C = 0.4;
px2mm = 0.289;  % (mm/pixel)
interp_radius = 100;
maskThreshold = 100;

Fs = 125000;
% -------------------------------------------------------------------------
if ~exist('data_info','var')
    [t,y,data_info] = GetPointData(DataPath, 'Time', 'Vib', 'Velocity',...
        'Samples', 0, 0);
    
    [t_ref,ref,~] = GetPointData(DataPath, 'Time', 'Ref1', 'Voltage',...
        'Samples', 0, 0);
end

locator_num = size(y,1);
for i = 1:locator_num
    try
        pt_i = GetIndexOfPoint(DataPath,i);
    catch
        warning(sprintf('Error occurred reading point %d',i));
    end
    
    if (pt_i ~= i)
        warning(sprintf('Measurement point index mismatch! %d ~= %d',...
            pt_i,i));
    end
end

maskImg = imread([MapPath,'Greg_MovingSpot_1ms_Dir1_1_Mask.jpg']);
maskImg = rgb2gray(maskImg);
pointImg = imread([MapPath,'Greg_MovingSpot_1ms_Dir1_1_MP.jpg']);
pointImg = rgb2gray(pointImg); 

% Low pass filter the chosen grid and computable area
lpF = ones(3)/9; % 3-by-3 mean filter
ptImg_PFilter = uint8(filter2(lpF,pointImg));
MP_Posi = findMP(ptImg_PFilter, locator_num, 128);
MP_Posi = round(MP_Posi); % Round the position to get index
xDiff = diff(MP_Posi(:,2));
xDiff(abs(xDiff)<5) = 0;
MP_Score = cumsum([0; xDiff]).*10000 + MP_Posi(:,1);
[~,ind] = sort(MP_Score);
MP_Posi = MP_Posi(ind,:);

%% Configuration
% slow_factor = 25;
slow_factor = 125;
% slow_factor = 250;

% -------------------------------------------------------------------------
% % % Sequence: 20,40,80,120,160,200,240,280,320,360,400,440,480,520,560,600,640 Hz
% -------------------------------------------------------------------------
% freqBand = [20,40,80,160,240,320,400,480,560,640];
freqBand = [40,240];

freqBandNum = length(freqBand)-1;

% truncData = 0.5*y_vib_clean1 + 0.5*y_vib_clean2;

%% Discard ill measurement points
% dataEn = rms(y_vib_sync');
% sorted_En = sort(dataEn);
% threshold = sorted_En(ceil(0.92*length(sorted_En)));
% % threshold = sorted_En(ceil(0.88*length(sorted_En)));
% % threshold = sorted_En(ceil(0.80*length(sorted_En)));
% remain_ind = (dataEn < threshold);

discard_ind = [19, 20, 38, 39, 48, 49, 58, 68, 69, 79, 80, 176, 190, 193, 205, 216,...
    220, 222, 225, 228, 233, 247, 283, 289];

if is1ms
    discard_ind = [discard_ind, 2,26,37,67,74, 144, 219,223, 242, 281];
else
    discard_ind = [discard_ind, 8, 99, 120, 138, 144, 158, 195, 200, 277];
end

remain_ind = true(1,locator_num);
remain_ind(discard_ind) = false;

remainMP_Posi = MP_Posi(remain_ind,:);

%% Display selected measurement points
temp_fig = figure('Position',[60,60,1840,880],'Color','w');
imshow(imread([MapPath,'Greg_MovingSpot_1ms_Dir1_1_MP.jpg']))
hold on;
for i = find(remain_ind > 0)
    text(MP_Posi(i,2),MP_Posi(i,1),num2str(i),'Color','c')
end
for i = find(remain_ind == 0)
    scatter(MP_Posi(i,2),MP_Posi(i,1),18,'r','filled');
    text(MP_Posi(i,2),MP_Posi(i,1),num2str(i),'Color','y')
end
title(sprintf('%d Point Removed',sum(remain_ind == 0)));

% scatter(MP_Posi(remain_ind,2),MP_Posi(remain_ind,1),20,y_avg(1,:),'filled');

hold off;

close(temp_fig);

%% Moving Average Windowing
avgWinLen = 20;
hammWin = repmat(hamming(2*avgWinLen),[1,sum(remain_ind)]);

for f_i = 1:freqBandNum
filteredData = bandpass(y_vib_sync(remain_ind,:)',...
    [freqBand(f_i),freqBand(f_i+1)],Fs);
% filteredData = highpass(y_vib_sync(remain_ind,:)',40,Fs);

% plot(filteredData(1:28000,:));

y_rect = [];
y_avg = [];

if is1ms
    frame_num = 1200;
else
    frame_num = 120;
end

for i = 0:frame_num
    slct_ind = i*avgWinLen+(1:(2*avgWinLen));
    y_rect = [y_rect;rms(hammWin.*filteredData(slct_ind,:))]; % RMS Rectify
    y_avg = [y_avg;mean(hammWin.*filteredData(slct_ind,:))]; % (Bipolar)
end

% y_avg = y_rect;
%% Plot selected frames
if 0 %---------------------------------------------------------------switch

row_num = 3;
% slct_frame = -1+(24:10:104);
slct_frame = 155:50:1250;

frame_num = length(slct_frame);

y_slct = y_avg(slct_frame,:);
colorRange = [min(y_slct(:)),max(y_slct(:))*0.7*17/Alpha];

curr_fig = figure('Position',[60,60,1840,580],'Color','w','Name',...
    sprintf('Bandpass [%d - %d Hz]',freqBand(f_i),freqBand(f_i+1)));
colorRange = [min(y_slct(:)),max(y_slct(:))*0.8*17/Alpha];
colormap(jet(1000));
for i = 1:frame_num
    subplot(row_num,ceil(frame_num/row_num),i)
%     subplot('Position',[0.005+(i-1)*0.11,0.2,0.11,0.6])    
    
    interpImg = interpMP(maskImg, MP_Posi(remain_ind,:),...
      y_slct(i,:),maskThreshold, interp_radius, Alpha, C, px2mm);      
    surf(flipud(interpImg),'EdgeColor','none');
    caxis(colorRange);
    view(2)
    axis equal; axis off;
    title(sprintf('(%d) Time = %.0f ms',slct_frame(i),...
        slct_frame(i)*avgWinLen*1000/Fs))
%     title(sprintf('%.1f ms',...
%         (slct_frame(i)-slct_frame(1))*avgWinLen*1000/Fs));
    drawnow;
    
%     set(gca,'FontSize',16)   
%     if i == round(0.5*frame_num)
%         c_h = colorbar('Location','south','Ticks',[]);
%         c_h.Label.String = sprintf('RMS Velocity %.1f - %.1f (mm/s)\n',...
%             1000*colorRange);
%         disp(c_h.Label.String{1});
%     end
end

end %------------------------------------------------------------switch end 

%% Produce Videos
if 1 %---------------------------------------------------------------switch
    
% Image coordinates
[meshX,meshY] = meshgrid(1:size(maskImg,2),1:size(maskImg,1));
    
frame_rate = Fs/avgWinLen/slow_factor;

v_h = VideoWriter(sprintf('%s%s_slow%dx_%.ffps_%d-%dHz.avi',OutputPath,...
    dataName,slow_factor,frame_rate,freqBand(f_i),freqBand(f_i+1)));
v_h.FrameRate = frame_rate;
open(v_h);

% colorRange = [min(y_avg(:)),max(y_avg(:))*0.8*17/Alpha];

if is1ms
    % colorRange = [0, 0.00065];
    colorRange = [-0.0002, 0.0002];
else
%     colorRange = [0, 0.00022];
    colorRange = [-0.0002, 0.0002];
end

curr_fig = figure('Position',[60,60,1840,880],'Color','w');
colormap(jet(1000));

focus_Posi = NaN(size(y_avg,1),2);
for i = 1:size(y_avg,1)
interpImg = interpMP(maskImg, MP_Posi(remain_ind,:), y_avg(i,:),...
        maskThreshold, interp_radius, Alpha, C, px2mm);      
% surf(flipud(interpImg),'EdgeColor','none');

sc_h = imagesc(interpImg); 
set(sc_h,'AlphaData',~isnan(interpImg));
caxis(colorRange);
view(2)
axis equal; axis off;
title(sprintf('(%d) [%d - %d Hz] Time = %.1f ms',i,...
    freqBand(f_i),freqBand(f_i+1),i*avgWinLen*1000/Fs))

valid_ind = ~isnan(interpImg);
Phi = exp(200000*interpImg(valid_ind))';
Phi = Phi./sum(Phi);
focus_Posi(i,2) = Phi*meshX(valid_ind);
focus_Posi(i,1) = Phi*meshY(valid_ind);

hold on
scatter(focus_Posi(i,2), focus_Posi(i,1),1200,'k','Linewidth',1);
hold off

drawnow;
writeVideo(v_h,getframe(curr_fig));
end
close(v_h);
pause(0.5);
close(curr_fig);
end %------------------------------------------------------------switch end

end 