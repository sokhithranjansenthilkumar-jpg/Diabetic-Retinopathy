clc;
clear;
close all;

dataFolder = fullfile(pwd, "dataset");

imds = imageDatastore(dataFolder, ...
    IncludeSubfolders=true, ...
    LabelSource="foldernames");

disp("Total number of images:");
disp(numel(imds.Files));

disp("Images in each class:");
disp(countEachLabel(imds));