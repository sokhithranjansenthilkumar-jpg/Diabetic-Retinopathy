clc;
clear;

% Dataset path
datasetFolder = fullfile(pwd,"dataset");

% Load dataset
imds = imageDatastore(datasetFolder, ...
    "IncludeSubfolders",true, ...
    "LabelSource","foldernames");

% Display class distribution
classCount = countEachLabel(imds);

disp("======================================");
disp("DIABETIC RETINOPATHY CLASS DISTRIBUTION");
disp("======================================");

disp(classCount);

% Total images
fprintf("\nTotal Images: %d\n",numel(imds.Files));

% Percentage of each class
for i = 1:height(classCount)

    percentage = ...
        (classCount.Count(i) / numel(imds.Files)) * 100;

    fprintf("%s : %d images (%.2f%%)\n", ...
        string(classCount.Label(i)), ...
        classCount.Count(i), ...
        percentage);
end