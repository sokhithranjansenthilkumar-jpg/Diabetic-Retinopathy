function exudateMask = exudateDetection(I)
%EXUDATEDETECTION Approximate exudate detection.
%
% Prototype image-processing method for visualization.
% Not clinically validated.

% Convert grayscale to RGB
if size(I,3) == 1
    I = cat(3,I,I,I);
end

% Use green channel
greenChannel = I(:,:,2);

% Convert to uint8
greenChannel = im2uint8(greenChannel);

% Improve contrast
enhanced = adapthisteq(greenChannel, ...
    "ClipLimit", 0.01);

% Smooth image
smoothImage = imgaussfilt(enhanced, 2);

% Detect bright structures
threshold = graythresh(smoothImage);

exudateMask = smoothImage > ...
    uint8(threshold * 255);

% Remove small objects
exudateMask = bwareaopen(exudateMask, 30);

% Fill small holes
exudateMask = imfill(exudateMask, "holes");

% Remove very large regions
exudateMask = bwareafilt(exudateMask, [30 2000]);

% Morphological cleanup
exudateMask = imopen(exudateMask, ...
    strel("disk",2));

end