function [neovascularMask, vesselMask] = neovascularizationDetection(I)
%NEOVASCULARIZATIONDETECTION
% Approximate detection of dense/abnormal vessel regions.
%
% Prototype visualization method.
% Not clinically validated.

    % -----------------------------------------
    % STEP 1: Segment retinal vessels
    % -----------------------------------------
    vesselMask = vesselSegmentation(I);
    vesselMask = logical(vesselMask);

    % -----------------------------------------
    % STEP 2: Remove small noise
    % -----------------------------------------
    vesselMask = bwareaopen(vesselMask, 50);

    % -----------------------------------------
    % STEP 3: Calculate local vessel density
    % -----------------------------------------
    vesselDensity = imboxfilt( ...
        double(vesselMask), ...
        [41 41]);

    vesselDensity = mat2gray(vesselDensity);

    % -----------------------------------------
    % STEP 4: Detect only very dense regions
    % -----------------------------------------
    neovascularMask = vesselDensity > 0.60;

    % -----------------------------------------
    % STEP 5: Remove small regions
    % -----------------------------------------
    neovascularMask = bwareaopen( ...
        neovascularMask, 200);

    % -----------------------------------------
    % STEP 6: Remove very large regions
    % -----------------------------------------
    components = bwconncomp(neovascularMask);

    if components.NumObjects > 0

        areas = cellfun(@numel, components.PixelIdxList);

        imageArea = numel(neovascularMask);

        keep = areas < 0.15 * imageArea;

        newMask = false(size(neovascularMask));

        for k = 1:components.NumObjects
            if keep(k)
                newMask(components.PixelIdxList{k}) = true;
            end
        end

        neovascularMask = newMask;
    end

    % -----------------------------------------
    % STEP 7: Morphological cleanup
    % -----------------------------------------
    neovascularMask = imopen( ...
        neovascularMask, ...
        strel("disk",2));

    neovascularMask = imclose( ...
        neovascularMask, ...
        strel("disk",3));

end