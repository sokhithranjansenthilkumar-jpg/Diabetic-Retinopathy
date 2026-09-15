function evaluateModel()

% =========================================
% STEP 7: PROPER MODEL EVALUATION
% =========================================

clc;
close all;

% -----------------------------------------
% Project folders
% -----------------------------------------

appFolder = fileparts(mfilename("fullpath"));
projectFolder = fileparts(appFolder);

datasetFolder = fullfile(projectFolder,"dataset");
modelFile = fullfile(projectFolder, ...
    "models","resnet50_svm_model.mat");

% -----------------------------------------
% Load trained model
% -----------------------------------------

disp("Loading trained ResNet-50 + SVM model...");

modelData = load(modelFile, ...
    "net","svmModel","classes");

net = modelData.net;
svmModel = modelData.svmModel;
classes = modelData.classes;

% -----------------------------------------
% Load dataset
% -----------------------------------------

disp("Loading dataset...");

imds = imageDatastore( ...
    datasetFolder, ...
    "IncludeSubfolders",true, ...
    "LabelSource","foldernames");

disp("Dataset information:");
disp(countEachLabel(imds));

% -----------------------------------------
% Number of images
% -----------------------------------------

numImages = numel(imds.Files);

trueLabels = imds.Labels;

predictedLabels = categorical( ...
    strings(numImages,1));

% -----------------------------------------
% Process images
% -----------------------------------------

disp("Starting ResNet-50 feature extraction...");
disp("Please wait...");

tic;

for i = 1:numImages

    % Show progress every 50 images
    if mod(i,50) == 0 || i == 1
        fprintf("Processing image %d / %d...\n", ...
            i,numImages);
    end

    % Read image
    I = readimage(imds,i);

    % Convert grayscale to RGB
    if size(I,3) == 1
        I = cat(3,I,I,I);
    end

    % Resize for ResNet-50
    I = imresize(I,[224 224]);

    % Extract ResNet-50 features
    features = activations( ...
        net, ...
        I, ...
        "avg_pool", ...
        "OutputAs","rows");

    % SVM prediction
    predictedClass = predict( ...
        svmModel, ...
        features);

    predictedLabels(i) = categorical( ...
        string(predictedClass));

end

elapsedTime = toc;

fprintf("\nFeature extraction completed.\n");
fprintf("Processing time: %.2f minutes\n", ...
    elapsedTime/60);

% -----------------------------------------
% Overall Accuracy
% -----------------------------------------

accuracy = mean( ...
    predictedLabels == trueLabels) * 100;

fprintf("\n=========================================\n");
fprintf("MODEL EVALUATION RESULTS\n");
fprintf("=========================================\n");

fprintf("Total Images: %d\n",numImages);
fprintf("Accuracy: %.2f%%\n",accuracy);

% -----------------------------------------
% Confusion Matrix
% -----------------------------------------

figure("Name","DR Confusion Matrix");

confusionchart( ...
    trueLabels, ...
    predictedLabels);

title(sprintf( ...
    "Diabetic Retinopathy Confusion Matrix - Accuracy %.2f%%", ...
    accuracy));

% -----------------------------------------
% Classification Report
% -----------------------------------------

classList = categories(trueLabels);

fprintf("\n=========================================\n");
fprintf("CLASSIFICATION RESULTS\n");
fprintf("=========================================\n");

for i = 1:numel(classList)

    currentClass = categorical( ...
        classList(i));

    TP = sum( ...
        trueLabels == currentClass & ...
        predictedLabels == currentClass);

    FP = sum( ...
        trueLabels ~= currentClass & ...
        predictedLabels == currentClass);

    FN = sum( ...
        trueLabels == currentClass & ...
        predictedLabels ~= currentClass);

    TN = sum( ...
        trueLabels ~= currentClass & ...
        predictedLabels ~= currentClass);

    precision = TP / max(TP + FP,1);

    recall = TP / max(TP + FN,1);

    specificity = TN / max(TN + FP,1);

    f1 = 2 * ...
        (precision * recall) / ...
        max(precision + recall,eps);

    fprintf("\nClass: %s\n",classList{i});

    fprintf("Precision: %.2f%%\n", ...
        precision*100);

    fprintf("Sensitivity/Recall: %.2f%%\n", ...
        recall*100);

    fprintf("Specificity: %.2f%%\n", ...
        specificity*100);

    fprintf("F1 Score: %.2f%%\n", ...
        f1*100);

end

% -----------------------------------------
% Evaluation completed
% -----------------------------------------

fprintf("\n=========================================\n");
fprintf("Evaluation completed.\n");
fprintf("=========================================\n");

end