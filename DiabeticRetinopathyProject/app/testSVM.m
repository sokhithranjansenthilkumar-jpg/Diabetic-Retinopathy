function testSVM()

clc;
clear;
close all;

% =========================================
% TEST SAVED SVM MODEL
% =========================================

appFolder = fileparts(mfilename("fullpath"));
projectFolder = fileparts(appFolder);

modelFile = fullfile(projectFolder, ...
    "models","resnet50_svm_model.mat");

% -----------------------------------------
% Load SVM
% -----------------------------------------

disp("Loading saved SVM...");

modelData = load(modelFile, ...
    "svmModel","classes");

svmModel = modelData.svmModel;
classes = modelData.classes;

disp("SVM loaded.");

fprintf("\n=========================================\n");
fprintf("SVM MODEL INFORMATION\n");
fprintf("=========================================\n");

disp(svmModel);

fprintf("\nClasses stored in model:\n");
disp(classes);

% -----------------------------------------
% Load dataset
% -----------------------------------------

datasetFolder = fullfile(projectFolder,"dataset");

imds = imageDatastore( ...
    datasetFolder, ...
    "IncludeSubfolders",true, ...
    "LabelSource","foldernames");

classNames = categories(imds.Labels);

% -----------------------------------------
% Extract features from one image
% from every class
% -----------------------------------------

netData = load(modelFile,"net");
net = netData.net;

allFeatures = [];

fprintf("\n=========================================\n");
fprintf("SVM PREDICTION TEST\n");
fprintf("=========================================\n");

for c = 1:numel(classNames)

    currentClass = classNames{c};

    indexes = find(imds.Labels == currentClass);

    idx = indexes(1);

    I = readimage(imds,idx);

    if size(I,3) == 1
        I = cat(3,I,I,I);
    end

    I = im2uint8(I);
    I = imresize(I,[224 224]);

    % ResNet features
    features = activations( ...
        net, ...
        I, ...
        "avg_pool", ...
        "OutputAs","rows");

    allFeatures = [allFeatures; features];

end

% -----------------------------------------
% Predict all 5 feature vectors together
% -----------------------------------------

[predictedClass,scores] = ...
    predict(svmModel,allFeatures);

fprintf("\nPredicted Classes:\n");
disp(predictedClass);

fprintf("\nScores:\n");
disp(scores);

fprintf("\n=========================================\n");
fprintf("INDIVIDUAL RESULTS\n");
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