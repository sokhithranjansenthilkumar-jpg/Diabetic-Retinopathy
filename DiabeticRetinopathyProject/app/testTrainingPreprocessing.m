function testTrainingPreprocessing()

clc;
clear;
close all;

% =========================================
% TEST USING EXACT TRAINING PREPROCESSING
% =========================================

appFolder = fileparts(mfilename("fullpath"));
projectFolder = fileparts(appFolder);

datasetFolder = fullfile(projectFolder,"dataset");
modelFile = fullfile(projectFolder, ...
    "models","resnet50_svm_model.mat");

% Load model
disp("Loading model...");

modelData = load(modelFile, ...
    "net","svmModel","classes");

net = modelData.net;
svmModel = modelData.svmModel;

disp("Model loaded.");

% Load dataset
imds = imageDatastore( ...
    datasetFolder, ...
    "IncludeSubfolders",true, ...
    "LabelSource","foldernames");

classNames = categories(imds.Labels);

fprintf("\n=========================================\n");
fprintf("TRAINING PREPROCESSING TEST\n");
fprintf("=========================================\n");

allFeatures = [];

for c = 1:numel(classNames)

    currentClass = classNames{c};

    indexes = find(imds.Labels == currentClass);

    idx = indexes(1);

    I = readimage(imds,idx);

    fprintf("\nActual Class: %s\n",currentClass);

    % EXACT SAME PREPROCESSING AS TRAINING
    if size(I,3) == 1
        I = cat(3,I,I,I);
    end

    if size(I,3) > 3
        I = I(:,:,1:3);
    end

    I = imresize(I,[224 224]);

    % IMPORTANT:
    % Same as training script
    I = im2single(I);

    % Extract features
    features = activations( ...
        net, ...
        I, ...
        "avg_pool", ...
        "OutputAs","rows");

    fprintf("Feature size: ");
    disp(size(features));

    fprintf("First 10 features:\n");
    disp(features(1,1:10));

    allFeatures = [allFeatures; features];

end

% -----------------------------------------
% SVM prediction
% -----------------------------------------

[predictedClass,scores] = ...
    predict(svmModel,allFeatures);

fprintf("\n=========================================\n");
fprintf("PREDICTIONS\n");
fprintf("=========================================\n");

for i = 1:numel(classNames)

    fprintf("\nActual Class: %s\n",classNames{i});

    fprintf("Predicted Class: %s\n", ...
        string(predictedClass(i)));

    fprintf("Scores: ");

    fprintf("%.4f ",scores(i,:));

    fprintf("\n");

end

fprintf("\n=========================================\n");
fprintf("TEST COMPLETED\n");
fprintf("=========================================\n");

end