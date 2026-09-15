function [overallScore, overallStatus] = overallQualityAssessment(I)

% Individual quality assessments
[focusScore, focusStatus] = focusAssessment(I);
[illuminationScore, illuminationStatus] = illuminationAssessment(I);
[fovScore, fovStatus] = fieldOfViewAssessment(I);

% Weighted overall score
overallScore = 0.40 * focusScore + ...
    0.30 * illuminationScore + ...
    0.30 * fovScore;

% Overall classification
if strcmp(focusStatus,"UNGRADEABLE") || ...
        strcmp(illuminationStatus,"UNGRADEABLE") || ...
        strcmp(fovStatus,"UNGRADEABLE")

    overallStatus = "UNGRADEABLE";

elseif strcmp(focusStatus,"BORDERLINE") || ...
        strcmp(illuminationStatus,"BORDERLINE") || ...
        strcmp(fovStatus,"BORDERLINE")

    overallStatus = "BORDERLINE";

elseif overallScore >= 60
    overallStatus = "GOOD";

elseif overallScore >= 30
    overallStatus = "BORDERLINE";

else
    overallStatus = "UNGRADEABLE";
end

end