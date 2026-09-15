function [opticDiscCenter, foveaCenter, outputImage] = ...
    opticDiscFoveaLocalization(I)

% =========================================================
% OPTIC DISC AND FOVEA LOCALIZATION
% =========================================================

% Convert grayscale to RGB
if size(I,3) == 1
    I = cat(3,I,I,I);
end

% Remove alpha channel if present
if size(I,3) > 3
    I = I(:,:,1:3);
end

% Convert to uint8
if ~isa(I,"uint8")
    I = im2uint8(I);
end

% Resize image
I = imresize(I,[512 512]);

% =========================================================
% GREEN CHANNEL
% =========================================================

greenChannel = I(:,:,2);

% Smooth image
blurredImage = imgaussfilt(greenChannel,15);

% =========================================================
% OPTIC DISC LOCALIZATION
% =========================================================

% Find brightest regions
threshold = prctile(blurredImage(:),99);

brightMask = blurredImage >= threshold;

% Remove small regions
brightMask = bwareaopen(brightMask,100);

% Find connected components
stats = regionprops( ...
    brightMask, ...
    blurredImage, ...
    "Area", ...
    "Centroid", ...
    "MeanIntensity");

if isempty(stats)

    % Fallback: brightest pixel
    [~,maxIndex] = max(blurredImage(:));
    [discY,discX] = ind2sub(size(blurredImage),maxIndex);

else

    % Score candidates using area and brightness
    candidateScores = zeros(numel(stats),1);

    for k = 1:numel(stats)

        candidateScores(k) = ...
            stats(k).Area * ...
            double(stats(k).MeanIntensity);

    end

    [~,bestIndex] = max(candidateScores);

    discX = stats(bestIndex).Centroid(1);
    discY = stats(bestIndex).Centroid(2);

end

opticDiscCenter = [discX discY];

% =========================================================
% FOVEA ESTIMATION
% =========================================================

% The fovea is approximately temporal to the optic disc.
imageWidth = size(I,2);

horizontalDistance = 120;

foveaX = discX + horizontalDistance;

% Keep inside image
foveaX = min(foveaX,imageWidth-20);

foveaY = discY;

foveaCenter = [foveaX foveaY];

% =========================================================
% CREATE OUTPUT IMAGE
% =========================================================

outputImage = I;

% Optic disc marker
outputImage = insertShape( ...
    outputImage, ...
    "Circle", ...
    [opticDiscCenter 25], ...
    "Color","green", ...
    "LineWidth",4);

% Fovea marker
outputImage = insertShape( ...
    outputImage, ...
    "Circle", ...
    [foveaCenter 20], ...
    "Color","blue", ...
    "LineWidth",4);

% Optic disc label
outputImage = insertText( ...
    outputImage, ...
    opticDiscCenter + [30 -20], ...
    "Optic Disc", ...
    "FontSize",18, ...
    "BoxColor","green");

% Fovea label
outputImage = insertText( ...
    outputImage, ...
    foveaCenter + [30 -20], ...
    "Fovea", ...
    "FontSize",18, ...
    "BoxColor","blue");

end