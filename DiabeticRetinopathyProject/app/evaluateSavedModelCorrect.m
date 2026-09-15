function evaluateSavedModelCorrect()

clc;
close all;

% =========================================
% CORRECT SAVED MODEL EVALUATION
% Same split + preprocessing as training
% =========================================

appFolder = fileparts(mfilename("fullpath"));
projectFolder = fileparts(appFolder);

datasetFolder = fullfile(projectFolder,"dataset");
modelFile = fullfile(projectFolder, ...
    "models","resnet50_svm_model.mat");

% -----------------------------------------
% Load saved model
% -----------------------------------------

disp("Loading saved model...");

modelData = load(modelFile, ...
    "net","svmModel","classes");

net = modelData.net;
svmModel = modelData.svmModel;

disp("Model loaded.");

% -----------------------------------------
% Load dataset
% -----------------------------------------

imds = imageDatastore( ...
    datasetFolder, ...
    "IncludeSubfolders",true, ...
    "LabelSource","foldernames");

fprintf("\nDataset:\n");
disp(countEachLabel(imds));

% -----------------------------------------
% SAME SPLIT AS TRAINING
% -----------------------------------------

rng(42);

[~, imdsTemp] = splitEachLabel( ...
    imds, 0.70, "randomized");

[~, imdsTest] = splitEachLabel( ...
    imdsTemp, 0.50, "randomized");

fprintf("\n=========================================\n");
fprintf("CORRECT TEST SET EVALUATION\n");
fprintf("=========================================\n");

fprintf("Test images: %d\n", ...
    numel(imdsTest.Files));

YTest = imdsTest.Labels;

% -----------------------------------------
% Feature extraction
% SAME preprocessing as training
% -----------------------------------------

numImages = numel(imdsTest.Files);

predictedLabels = categorical( ...
    strings(numImages,1), ...
    categories(YTest));

fprintf("\nExtracting test features...\n");

for i = 1:numImages

    I = readimage(imdsTest,i);

    % Grayscale → RGB
    if size(I,3) == 1
        I = cat(3,I,I,I);
    end

    % RGBA → RGB
    if size(I,3) > 3
        I = I(:,:,1:3);
    end

    % SAME as training
    I = imresize(I,[224 224]);

    I = im2single(I);

    % ResNet-50 features
    feature = activations( ...
        net, ...
        I, ...
        "avg_pool", ...
        "OutputAs","rows");

    % SVM prediction
    predictedClass = predict( ...
        svmModel,feature);

    predictedLabels(i) = categorical( ...
        string(predictedClass), ...
        categories(YTest));

    if mod(i,50) == 0 || i == numImages
        fprintf( ...
            "Processed %d / %d images (%.1f%%)\n", ...
            i,numImages,(i/numImages)*100);
    end

end

% =========================================
% OVERALL ACCURACY
% =========================================

accuracy = mean( ...
    predictedLabels == YTest) * 100;

fprintf("\n=========================================\n");
fprintf("OVERALL RESULTS\n");
fprintf("=========================================\n");

fprintf("Test Images: %d\n",numImages);
fprintf("Test Accuracy: %.2f%%\n",accuracy);

% =========================================
% CONFUSION MATRIX
% =========================================

figure("Name","Correct Test Confusion Matrix");

confusionchart( ...
    YTest, ...
    predictedLabels);

title(sprintf( ...
    "ResNet-50 + SVM Test Accuracy: %.2f%%", ...
    accuracy));

% =========================================
% CLASS METRICS
% =========================================

classes = categories(YTest);

cm = confusionmat(YTest,predictedLabels);

fprintf("\n=========================================\n");
fprintf("CLASSIFICATION RESULTS\n");
fprintf("=========================================\n");

for i = 1:numel(classes)

    TP = cm(i,i);

    FP = sum(cm(:,i)) - TP;

    FN = sum(cm(i,:)) - TP;

    TN = sum(cm(:)) - TP - FP - FN;

    precision = TP / max(TP + FP,1);

    recall = TP / max(TP + FN,1);

    specificity = TN / max(TN + FP,1);

    f1 = 2 * precision * recall / ...
        max(precision + recall,eps);

    fprintf("\nClass: %s\n",classes{i});

    fprintf("Precision: %.2f%%\n", ...
        precision*100);

    fprintf("Sensitivity/Recall: %.2f%%\n", ...
        recall*100);

    fprintf("Specificity: %.2f%%\n", ...
        specificity*100);

    fprintf("F1 Score: %.2f%%\n", ...
        f1*100);

end

% =========================================
% REFERABLE DR
%
% Level 2+
% Moderate + Severe + Proliferate_DR
% =========================================

referableClasses = categorical( ...
    ["Moderate","Severe","Proliferate_DR"], ...
    categories(YTest));

trueReferable = ismember( ...
    YTest,referableClasses);

predReferable = ismember( ...
    predictedLabels,referableClasses);

TP = sum(trueReferable & predReferable);
TN = sum(~trueReferable & ~predReferable);
FP = sum(~trueReferable & predReferable);
FN = sum(trueReferable & ~predReferable);

referableSensitivity = ...
    TP / max(TP + FN,1);

referableSpecificity = ...
    TN / max(TN + FP,1);

fprintf("\n=========================================\n");
fprintf("REFERABLE DR RESULTS\n");
fprintf("=========================================\n");

fprintf("Referable DR Classes: Level 2+\n");
fprintf("Sensitivity: %.2f%%\n", ...
    referableSensitivity*100);

fprintf("Specificity: %.2f%%\n", ...
    referableSpecificity*100);

% =========================================
% SAVE RESULTS
% =========================================

resultsFolder = fullfile( ...
    projectFolder,"results");

if ~exist(resultsFolder,"dir")
    mkdir(resultsFolder);
end

evaluationFile = fullfile( ...
    resultsFolder, ...
    "correct_evaluation_results.mat");

save( ...
    evaluationFile, ...
    "accuracy", ...
    "cm", ...
    "classes", ...
    "YTest", ...
    "predictedLabels", ...
    "referableSensitivity", ...
    "referableSpecificity");

fprintf("\nResults saved to:\n%s\n", ...
    evaluationFile);

fprintf("\n=========================================\n");
fprintf("EVALUATION COMPLETED\n");
fprintf("=========================================\n");

end