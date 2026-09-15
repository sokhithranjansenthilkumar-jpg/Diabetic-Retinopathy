function [focusScore, focusStatus] = focusAssessment(I)

    % Convert to grayscale
    if size(I,3) == 3
        Igray = rgb2gray(I);
    else
        Igray = I;
    end

    % Convert to double
    Igray = im2double(Igray);

    % Laplacian-based focus measurement
    laplacianKernel = fspecial("laplacian",0.2);
    laplacianImage = imfilter(Igray,laplacianKernel,"replicate");

    % Variance of Laplacian
    focusValue = var(laplacianImage(:));

    % Convert to 0-100 score
    focusScore = min(100,max(0, ...
        (focusValue - 0.0001) / (0.005 - 0.0001) * 100));

    % Focus classification
    if focusScore >= 60
    focusStatus = "GOOD";

elseif focusScore >= 10
    focusStatus = "BORDERLINE";

else
    focusStatus = "UNGRADEABLE";
end

end