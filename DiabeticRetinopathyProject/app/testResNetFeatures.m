function testResNetFeatures()

clc;
clear;
close all;

% =========================================
% TEST RESNET-50 FEATURE EXTRACTION
% =========================================

appFolder = fileparts(mfilename("fullpath"));
projectFolder = fileparts(appFolder);

datasetFolder = fullfile(projectFolder,"dataset");
modelFile = fullfile(projectFolder, ...
    "models","resnet50_svm_model.mat");

% -----------------------------------------
% Load model
% -----------------------------------------

disp("Loading model...");

modelData = load(modelFile,"net");

net = modelData.net;

disp("Model loaded.");

% -----------------------------------------
% Load dataset
% -----------------------------------------

imds = imageDatastore( ...
    datasetFolder, ...
    "IncludeSubfolders",true, ...
    "LabelSource","foldernames");

classNames = categories(imds.Labels);

fprintf("\n=========================================\n");
fprintf("RESNET FEATURE TEST\n");
fprintf("=========================================\n");

% Store features
allFeatures = [];

% -----------------------------------------
% Test one image from each class
% -----------------------------------------

for c = 1:numel(classNames)

    currentClass = classNames{c};

    indexes = find(imds.Labels == currentClass);

    idx = indexes(1);

    I = readimage(imds,idx);

    fprintf("\nActual Class: %s\n",currentClass);
    fprintf("Image: %s\n",imds.Files{idx});

    % Convert grayscale to RGB
    if size(I,3) == 1
        I = cat(3,I,I,I);
    end

    % Convert to uint8
    I = im2uint8(I);

    % Resize
    I = imresize(I,[224 224]);

    % Extract features
    features = activations( ...
        net, ...
        I, ...
        "avg_pool", ...
        "OutputAs","rows");

    % Display feature information
    fprintf("Feature size: ");
    disp(size(features));

    fprintf("First 10 feature values:\n");
    disp(features(1,1:min(10,end)));

    % Store
    allFeatures = [allFeatures; features];

end

% -----------------------------------------
% Compare feature differences
% -----------------------------------------

fprintf("\n=========================================\n");
fprintf("FEATURE DIFFERENCE TEST\n");
fprintf("=========================================\n");

for i = 2:size(allFeatures,1)

    difference = norm( ...
        allFeatures(1,:) - allFeatures(i,:) );

    fprintf( ...
        "Feature difference image 1 vs image %d: %.10f\n", ...
        i, ...
        difference);

end

fprintf("\n=========================================\n");
fprintf("TEST COMPLETED\n");
fprintf("=========================================\n");

end