clc;
clear;
close all;

% Load the complete dataset
dataFolder = fullfile(pwd, "dataset");

imds = imageDatastore(dataFolder, ...
    IncludeSubfolders=true, ...
    LabelSource="foldernames");

% Display original dataset
disp("Original dataset:");
disp(countEachLabel(imds));

% Split into 70% training and 30% temporary data
[imdsTrain, imdsTemp] = splitEachLabel(imds, 0.70, "randomized");

% Split the temporary data into 50% validation and 50% testing
[imdsValidation, imdsTest] = splitEachLabel(imdsTemp, 0.50, "randomized");

% Display the number of images
disp("Training dataset:");
disp(countEachLabel(imdsTrain));

disp("Validation dataset:");
disp(countEachLabel(imdsValidation));

disp("Testing dataset:");
disp(countEachLabel(imdsTest));

% Display total numbers
fprintf("Training images: %d\n", numel(imdsTrain.Files));
fprintf("Validation images: %d\n", numel(imdsValidation.Files));
fprintf("Testing images: %d\n", numel(imdsTest.Files));