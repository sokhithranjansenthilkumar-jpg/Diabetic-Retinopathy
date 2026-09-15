function microaneurysmMask = microaneurysmDetection(I)
%MICROANEURYSMDETECTION Approximate microaneurysm detection.
%
% Prototype image-processing method for visualization.
% Not clinically validated.

% Convert to RGB if grayscale
if size(I,3) == 1
    I = cat(3,I,I,I);
end

% Extract green channel
greenChannel = I(:,:,2);

% Convert to uint8
greenChannel = im2uint8(greenChannel);

% Improve local contrast
enhanced = adapthisteq(greenChannel, ...
    "ClipLimit", 0.01);

% Estimate background
background = imgaussfilt(enhanced, 8);

% Detect dark small structures
darkStructures = imsubtract(background, enhanced);

% Normalize
darkStructures = mat2gray(darkStructures);

% Threshold
microaneurysmMask = imbinarize(darkStructures, ...
    "adaptive", ...
    "Sensitivity", 0.45);

% Remove large structures
microaneurysmMask = bwareaopen(microaneurysmMask, 3);

% Remove very large regions
microaneurysmMask = ...
    bwareafilt(microaneurysmMask,[3 150]);

% Remove small isolated noise
microaneurysmMask = bwmorph( ...
    microaneurysmMask,"clean");

end