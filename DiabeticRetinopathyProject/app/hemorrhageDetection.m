function hemorrhageMask = hemorrhageDetection(I)
%HEMORRHAGEDETECTION Approximate retinal hemorrhage detection.
%
% Prototype image-processing method for visualization.
% Not clinically validated.

    % -----------------------------------------
    % Make sure image is RGB
    % -----------------------------------------
    if size(I,3) == 1
        I = cat(3,I,I,I);
    end

    I = im2uint8(I);

    % -----------------------------------------
    % Extract color channels
    % -----------------------------------------
    R = I(:,:,1);
    G = I(:,:,2);
    B = I(:,:,3);

    % -----------------------------------------
    % Detect dark reddish retinal regions
    % -----------------------------------------
    redDifference = im2double(R) - ...
                    0.7 * im2double(G) - ...
                    0.3 * im2double(B);

    % Normalize
    redDifference = mat2gray(redDifference);

    % -----------------------------------------
    % Improve contrast
    % -----------------------------------------
    redDifference = adapthisteq( ...
        redDifference, ...
        "ClipLimit",0.02);

    % -----------------------------------------
    % Remove small image noise
    % -----------------------------------------
    redDifference = medfilt2( ...
        redDifference,[5 5]);

    % -----------------------------------------
    % Detect darker reddish regions
    % -----------------------------------------
    threshold = graythresh(redDifference);

    hemorrhageMask = ...
        redDifference < threshold * 0.65;

    % -----------------------------------------
    % Remove small objects
    % -----------------------------------------
    hemorrhageMask = bwareaopen( ...
        hemorrhageMask,30);

    % -----------------------------------------
    % Keep reasonable lesion-sized regions
    % -----------------------------------------
    hemorrhageMask = bwareafilt( ...
        hemorrhageMask,[30 2500]);

    % -----------------------------------------
    % Morphological cleanup
    % -----------------------------------------
    hemorrhageMask = imclose( ...
        hemorrhageMask, ...
        strel("disk",2));

    hemorrhageMask = imopen( ...
        hemorrhageMask, ...
        strel("disk",1));

end