function testSavedModel()

clc;
clear;
close all;

% =========================================
% TEST SAVED RESNET-50 + SVM MODEL
% =========================================

appFolder = fileparts(mfilename("fullpath"));
projectFolder = fileparts(appFolder);

datasetFolder = fullfile(projectFolder,"dataset");
modelFile = fullfile(projectFolder, ...
    "models","resnet50_svm_model.mat");

% -----------------------------------------
% Load model
% -----------------------------------------

disp("Loading saved model...");

modelData = load(modelFile, ...
    "net","svmModel","classes");

net = modelData.net;
svmModel = modelData.svmModel;
classes = modelData.classes;

disp("Model loaded.");
disp("Model classes:");

disp(classes);

% -----------------------------------------
% Load dataset
% -----------------------------------------

imds = imageDatastore( ...
    datasetFolder, ...
    "IncludeSubfolders",true, ...
    "LabelSource","foldernames");

disp("Dataset loaded.");

% -----------------------------------------
% Test one image from each class
% -----------------------------------------

classNames = categories(imds.Labels);

fprintf("\n=========================================\n");
fprintf("SAVED MODEL TEST\n");
fprintf("=========================================\n");

for c = 1:numel(classNames)

    currentClass = classNames{c};

    % Find images belonging to this class
    indexes = find(imds.Labels == currentClass);

    % Test first image from this class
    idx = indexes(1);

    I = readimage(imds,idx);

    % Convert grayscale to RGB
    if size(I,3) == 1
        I = cat(3,I,I,I);
    end

    % Convert to uint8
    I = im2uint8(I);

    % Resize
    I = imresize(I,[224 224]);

    % Extract ResNet-50 features
    features = activations( ...
        net, ...
        I, ...
        "avg_pool", ...
        "OutputAs","rows");

    % SVM prediction
    [predictedClass,scores] = ...
        predict(svmModel,features);

    fprintf("\nActual Class: %s\n",currentClass);
    fprintf("Predicted Class: %s\n",string(predictedClass));

    fprintf("Scores:\n");
    disp(scores);

end

fprintf("\n=========================================\n");
fprintf("TEST COMPLETED\n");
fprintf("=========================================\n");

end