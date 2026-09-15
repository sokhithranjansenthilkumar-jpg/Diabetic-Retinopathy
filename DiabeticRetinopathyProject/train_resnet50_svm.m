%% train_resnet50_svm.m
% Diabetic Retinopathy Detection
% ResNet-50 Feature Extraction + SVM Classification

clc;
clear;
close all;

%% 1. Project Paths

projectFolder = fileparts(mfilename("fullpath"));

datasetFolder = fullfile(projectFolder, "dataset");
modelsFolder  = fullfile(projectFolder, "models");
resultsFolder = fullfile(projectFolder, "results");

if ~exist(modelsFolder, "dir")
    mkdir(modelsFolder);
end

if ~exist(resultsFolder, "dir")
    mkdir(resultsFolder);
end

fprintf("Project Folder:\n%s\n\n", projectFolder);

%% 2. Load Dataset

imds = imageDatastore( ...
    datasetFolder, ...
    "IncludeSubfolders", true, ...
    "LabelSource", "foldernames");

fprintf("Total images: %d\n", numel(imds.Files));

disp("Class distribution:");
countEachLabel(imds)

%% 3. Split Dataset
% 70% Training
% 15% Validation
% 15% Testing

rng(42);

[imdsTrain, imdsTemp] = splitEachLabel( ...
    imds, 0.70, "randomized");

[imdsValidation, imdsTest] = splitEachLabel( ...
    imdsTemp, 0.50, "randomized");

fprintf("\nDataset Split:\n");
fprintf("Training   : %d images\n", numel(imdsTrain.Files));
fprintf("Validation : %d images\n", numel(imdsValidation.Files));
fprintf("Testing    : %d images\n\n", numel(imdsTest.Files));

%% 4. Load Pretrained ResNet-50

fprintf("Loading ResNet-50...\n");

net = resnet50;

inputSize = net.Layers(1).InputSize;

fprintf("ResNet-50 Input Size: %d x %d x %d\n", ...
    inputSize(1), inputSize(2), inputSize(3));

%% 5. Extract ResNet-50 Features

fprintf("\nExtracting Training Features...\n");

XTrain = extractResNetFeatures( ...
    net, imdsTrain, inputSize);

YTrain = imdsTrain.Labels;

fprintf("Training feature size: %d x %d\n", ...
    size(XTrain,1), size(XTrain,2));

fprintf("\nExtracting Validation Features...\n");

XValidation = extractResNetFeatures( ...
    net, imdsValidation, inputSize);

YValidation = imdsValidation.Labels;

fprintf("Validation feature size: %d x %d\n", ...
    size(XValidation,1), size(XValidation,2));

fprintf("\nExtracting Test Features...\n");

XTest = extractResNetFeatures( ...
    net, imdsTest, inputSize);

YTest = imdsTest.Labels;

fprintf("Test feature size: %d x %d\n", ...
    size(XTest,1), size(XTest,2));

%% 6. Train SVM Classifier

fprintf("\nTraining SVM classifier...\n");

svmTemplate = templateSVM( ...
    "KernelFunction", "rbf", ...
    "KernelScale", "auto", ...
    "Standardize", true);

svmModel = fitcecoc( ...
    XTrain, ...
    YTrain, ...
    "Learners", svmTemplate, ...
    "Coding", "onevsone");

fprintf("SVM training completed.\n");



%% 7. Validation Prediction

fprintf("\nEvaluating Validation Dataset...\n");

[validationPred, ~] = predict( ...
    svmModel, XValidation);

validationAccuracy = mean( ...
    validationPred == YValidation) * 100;

fprintf("Validation Accuracy: %.2f%%\n", ...
    validationAccuracy);

%% 8. Test Prediction

fprintf("\nEvaluating Test Dataset...\n");

[testPred, testScores] = predict( ...
    svmModel, XTest);

testAccuracy = mean( ...
    testPred == YTest) * 100;

fprintf("Test Accuracy: %.2f%%\n", ...
    testAccuracy);

%% 9. Display Confusion Matrix

figure("Name", "Test Confusion Matrix");

confusionchart( ...
    YTest, ...
    testPred);

title(sprintf( ...
    "Diabetic Retinopathy - Test Confusion Matrix (%.2f%% Accuracy)", ...
    testAccuracy));

%% 10. Class Names

classes = categories(YTrain);

fprintf("\nClasses:\n");

disp(classes);

%% 11. Calculate Class Metrics

cm = confusionmat(YTest, testPred);

numClasses = numel(classes);

precision = zeros(numClasses,1);
recall = zeros(numClasses,1);
specificity = zeros(numClasses,1);
f1Score = zeros(numClasses,1);

for i = 1:numClasses

    TP = cm(i,i);

    FP = sum(cm(:,i)) - TP;

    FN = sum(cm(i,:)) - TP;

    TN = sum(cm(:)) - TP - FP - FN;

    precision(i) = TP / max(TP + FP, eps);

    recall(i) = TP / max(TP + FN, eps);

    specificity(i) = TN / max(TN + FP, eps);

    f1Score(i) = ...
        2 * precision(i) * recall(i) / ...
        max(precision(i) + recall(i), eps);

end

%% 12. Results Table

classes = classes(:);
precision = precision(:);
recall = recall(:);
specificity = specificity(:);
f1Score = f1Score(:);

resultsTable = table( ...
    classes, ...
    precision, ...
    recall, ...
    specificity, ...
    f1Score, ...
    'VariableNames', { ...
    'Class', ...
    'Precision', ...
    'Recall', ...
    'Specificity', ...
    'F1Score'});

fprintf("\nClass-wise Performance:\n");

disp(resultsTable);

%% 12B. Referable DR Performance

% Referable DR = Moderate + Severe + Proliferate_DR
referableActual = ...
    YTest == "Moderate" | ...
    YTest == "Severe" | ...
    YTest == "Proliferate_DR";

referablePredicted = ...
    testPred == "Moderate" | ...
    testPred == "Severe" | ...
    testPred == "Proliferate_DR";

TP = sum(referableActual & referablePredicted);
TN = sum(~referableActual & ~referablePredicted);
FP = sum(~referableActual & referablePredicted);
FN = sum(referableActual & ~referablePredicted);

referableSensitivity = TP / max(TP + FN, eps);
referableSpecificity = TN / max(TN + FP, eps);

fprintf("\n========================================\n");
fprintf("REFERABLE DR PERFORMANCE\n");
fprintf("========================================\n");

fprintf("Sensitivity: %.2f%%\n", ...
    referableSensitivity * 100);

fprintf("Specificity: %.2f%%\n", ...
    referableSpecificity * 100);

%% 13. Save Evaluation Results

evaluationFile = fullfile( ...
    resultsFolder, ...
    "evaluation_results.mat");

save( ...
    evaluationFile, ...
    "cm", ...
    "resultsTable", ...
    "testAccuracy", ...
    "validationAccuracy", ...
    "classes", ...
    "referableSensitivity", ...
    "referableSpecificity");

fprintf("\nEvaluation results saved to:\n%s\n", ...
    evaluationFile);

%% 14. Save Trained Model

modelFile = fullfile( ...
    modelsFolder, ...
    "resnet50_svm_model.mat");

save( ...
    modelFile, ...
    "net", ...
    "svmModel", ...
    "classes", ...
    "testAccuracy", ...
    "-v7.3");

fprintf("\n========================================\n");
fprintf("MODEL TRAINING COMPLETED SUCCESSFULLY\n");
fprintf("========================================\n");

fprintf("\nTest Accuracy: %.2f%%\n", testAccuracy);

fprintf("\nModel saved to:\n%s\n", modelFile);

%% 15. Verify Saved Model

if exist(modelFile, "file")

    fprintf("\nSUCCESS: Model file exists.\n");

else

    fprintf("\nERROR: Model file was not created.\n");

end


%% Local Function
function features = extractResNetFeatures( ...
    net, imds, inputSize)

    numImages = numel(imds.Files);

    fprintf("Processing %d images...\n", numImages);

    features = [];

    for i = 1:numImages

        % Read image
        I = readimage(imds, i);

        % Convert grayscale to RGB
        if size(I,3) == 1
            I = cat(3, I, I, I);
        end

        % Convert RGBA to RGB
        if size(I,3) > 3
            I = I(:,:,1:3);
        end

        % Resize image
        I = imresize( ...
            I, ...
            inputSize(1:2));

        % Convert to single
        I = im2single(I);

        % Extract ResNet-50 average pooling features
        % Extract spatial ResNet-50 features
featureMap = activations( ...
    net, ...
    I, ...
    "activation_49_relu");

feature = reshape(featureMap, 1, []);

        features = [features; feature];

        % Progress
        if mod(i,50) == 0 || i == numImages
            fprintf( ...
                "Processed %d / %d images\n", ...
                i, numImages);
        end

    end

end