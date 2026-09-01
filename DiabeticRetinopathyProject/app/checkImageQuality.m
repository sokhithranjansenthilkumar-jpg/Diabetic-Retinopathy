function [isGood, qualityScore, message] = checkImageQuality(img)

% IMAGE QUALITY ASSESSMENT
% Checks brightness, contrast and sharpness
% of a retinal image.

% Convert RGB image to grayscale
if size(img, 3) == 3
    grayImg = rgb2gray(img);
else
    grayImg = img;
end

% Convert image to double
grayImg = im2double(grayImg);

% -------------------------------
% 1. Brightness
% -------------------------------
brightness = mean(grayImg(:));

% -------------------------------
% 2. Contrast
% -------------------------------
contrast = std(grayImg(:));

% -------------------------------
% 3. Sharpness / Blur
% -------------------------------
laplacian = imfilter( ...
    grayImg, ...
    fspecial('laplacian', 0.2), ...
    'replicate');

sharpness = var(laplacian(:));

% -------------------------------
% Quality checks
% -------------------------------
brightnessOK = brightness >= 0.15 && brightness <= 0.85;
contrastOK   = contrast >= 0.08;
sharpnessOK  = sharpness >= 0.0005;

% Count successful checks
qualityPoints = ...
    double(brightnessOK) + ...
    double(contrastOK) + ...
    double(sharpnessOK);

% Calculate quality score
qualityScore = (qualityPoints / 3) * 100;

% -------------------------------
% Final decision
% -------------------------------
if qualityPoints == 3

    isGood = true;
    message = "GOOD IMAGE";

elseif qualityPoints == 2

    isGood = true;
    message = "ACCEPTABLE IMAGE";

else

    isGood = false;
    message = "POOR IMAGE - PLEASE CAPTURE ANOTHER IMAGE";

end

end