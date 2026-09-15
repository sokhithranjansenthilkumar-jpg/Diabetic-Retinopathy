function [illuminationScore, illuminationStatus] = illuminationAssessment(I)

    % Convert to grayscale
    if size(I,3) == 3
        Igray = rgb2gray(I);
    else
        Igray = I;
    end

    Igray = im2double(Igray);

    % Average brightness
    meanBrightness = mean(Igray(:));

    % Standard deviation measures illumination variation
    brightnessVariation = std(Igray(:));

    % Brightness score
    if meanBrightness >= 0.25 && meanBrightness <= 0.75
        brightnessScore = 100;
    else
        brightnessScore = max(0, ...
            100 - abs(meanBrightness - 0.50) * 200);
    end

    % Uniformity score
    uniformityScore = max(0, 100 - brightnessVariation * 200);

    % Final illumination score
    illuminationScore = 0.6 * brightnessScore + ...
                        0.4 * uniformityScore;

    % Classification
    if illuminationScore >= 60
        illuminationStatus = "GOOD";
    elseif illuminationScore >= 30
        illuminationStatus = "BORDERLINE";
    else
        illuminationStatus = "UNGRADEABLE";
    end

end