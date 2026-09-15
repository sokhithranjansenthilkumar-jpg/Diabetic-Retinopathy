function vesselMask = vesselSegmentation(I)
%VESSELSEGMENTATION Approximate retinal blood vessel segmentation.
%
% Prototype visualization method. Not clinically validated.

    % Convert to grayscale
    if size(I,3) == 3
        Igray = rgb2gray(I);
    else
        Igray = I;
    end

    % Convert to uint8
    Igray = im2uint8(Igray);

    % Improve contrast
    Igray = adapthisteq(Igray, ...
        "ClipLimit", 0.01, ...
        "Distribution", "rayleigh");

    % Enhance dark vessel structures
    background = imgaussfilt(Igray, 12);
    vesselEnhanced = imsubtract(background, Igray);

    % Normalize
    vesselEnhanced = mat2gray(vesselEnhanced);

    % Smooth small noise
    vesselEnhanced = medfilt2(vesselEnhanced, [3 3]);

    % Threshold
    vesselMask = imbinarize(vesselEnhanced, ...
        "adaptive", ...
        "Sensitivity", 0.40);

    % Remove very small objects
    vesselMask = bwareaopen(vesselMask, 40);

    % Remove isolated pixels
    vesselMask = bwmorph(vesselMask, "clean");

    % Connect small vessel gaps
    vesselMask = bwmorph(vesselMask, "bridge");

end