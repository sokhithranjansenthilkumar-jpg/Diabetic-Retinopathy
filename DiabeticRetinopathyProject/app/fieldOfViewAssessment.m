function [fovScore, fovStatus] = fieldOfViewAssessment(I)

% Convert to grayscale
if size(I,3) == 3
    Igray = rgb2gray(I);
else
    Igray = I;
end

Igray = im2double(Igray);

% Estimate retinal field using brightness threshold
threshold = graythresh(Igray);
retinalMask = Igray > threshold * 0.35;

% Remove small regions
retinalMask = bwareaopen(retinalMask, 500);

% Calculate largest connected retinal region
stats = regionprops(retinalMask, "Area", "BoundingBox");

if isempty(stats)
    fovScore = 0;
    fovStatus = "UNGRADEABLE";
    return;
end

areas = [stats.Area];
[largestArea, idx] = max(areas);

imageArea = size(Igray,1) * size(Igray,2);

% Retinal coverage
coverage = largestArea / imageArea;

% Bounding box coverage
bbox = stats(idx).BoundingBox;
bboxArea = bbox(3) * bbox(4);
bboxCoverage = bboxArea / imageArea;

% Calculate score
fovScore = min(100, ...
    (0.7 * coverage + 0.3 * bboxCoverage) * 150);

% Classification
if fovScore >= 60
    fovStatus = "GOOD";
elseif fovScore >= 30
    fovStatus = "BORDERLINE";
else
    fovStatus = "UNGRADEABLE";
end

end