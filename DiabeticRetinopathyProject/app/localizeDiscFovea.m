function [opticDiscCenter, foveaCenter] = localizeDiscFovea(I)
%LOCALIZEDISCFOVEA Approximate optic disc and fovea localization.
%
% This function provides approximate anatomical locations for
% visualization/evidence generation. It is not a clinically
% validated anatomical detector.

% Convert to grayscale
if size(I,3) == 3
    Igray = rgb2gray(I);
else
    Igray = I;
end

% Convert to uint8
Igray = im2uint8(Igray);

% Smooth image
smoothImage = imgaussfilt(Igray, 10);

% Threshold bright regions
threshold = graythresh(smoothImage);

binaryImage = imbinarize(smoothImage, threshold);

% Remove small regions
binaryImage = bwareaopen(binaryImage, 100);

% Find connected components
stats = regionprops( ...
    binaryImage, ...
    "Area", ...
    "Centroid", ...
    "BoundingBox");

% Default center
imageCenter = [size(I,2)/2, size(I,1)/2];

% If no bright region is found
if isempty(stats)

    opticDiscCenter = imageCenter;
    foveaCenter = imageCenter;

    return;
end

% Find largest bright region
areas = [stats.Area];

[~, idx] = max(areas);

opticDiscCenter = stats(idx).Centroid;

% Approximate fovea location relative to optic disc
direction = imageCenter - opticDiscCenter;

foveaCenter = opticDiscCenter + 0.8 * direction;

end