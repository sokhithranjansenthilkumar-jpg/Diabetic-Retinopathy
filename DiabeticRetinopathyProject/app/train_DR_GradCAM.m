function train_DR_GradCAM()

clc;
close all;

fprintf("============================================\n");
fprintf("FAST DR-SPECIFIC GRAD-CAM MODEL\n");
fprintf("============================================\n\n");

projectFolder = fileparts(fileparts(mfilename("fullpath")));

datasetFolder = fullfile(projectFolder,"dataset");
modelsFolder = fullfile(projectFolder,"models");

if ~exist(modelsFolder,"dir")
    mkdir(modelsFolder);
end

%% Load dataset
imds = imageDatastore(datasetFolder, ...
    "IncludeSubfolders",true, ...
    "LabelSource","foldernames");

fprintf("Total images: %d\n\n",numel(imds.Files));

%% Split dataset
rng(42);

[imdsTrain,imdsTemp] = splitEachLabel(imds,0.70,"randomized");
[imdsValidation,imdsTest] = splitEachLabel( ...
    imdsTemp,0.50,"randomized");

fprintf("Training images: %d\n",numel(imdsTrain.Files));
fprintf("Validation images: %d\n",numel(imdsValidation.Files));
fprintf("Test images: %d\n\n",numel(imdsTest.Files));

%% Load ResNet-50
fprintf("Loading ResNet-50...\n");

net = resnet50;

inputSize = net.Layers(1).InputSize;

%% Replace final classification layers
lgraph = layerGraph(net);

numClasses = numel(categories(imdsTrain.Labels));

newFC = fullyConnectedLayer( ...
    numClasses, ...
    "Name","dr_fc", ...
    "WeightLearnRateFactor",10, ...
    "BiasLearnRateFactor",10);

lgraph = replaceLayer( ...
    lgraph, ...
    "fc1000", ...
    newFC);

newClassLayer = classificationLayer( ...
    "Name","dr_classoutput");

lgraph = replaceLayer( ...
    lgraph, ...
    "ClassificationLayer_fc1000", ...
    newClassLayer);

%% Image augmentation
imageAugmenter = imageDataAugmenter( ...
    "RandRotation",[-5 5], ...
    "RandXReflection",true);

augimdsTrain = augmentedImageDatastore( ...
    inputSize(1:2), ...
    imdsTrain, ...
    "DataAugmentation",imageAugmenter);

augimdsValidation = augmentedImageDatastore( ...
    inputSize(1:2), ...
    imdsValidation);

augimdsTest = augmentedImageDatastore( ...
    inputSize(1:2), ...
    imdsTest);

%% Training options
options = trainingOptions("sgdm", ...
    "MiniBatchSize",32, ...
    "MaxEpochs",2, ...
    "InitialLearnRate",1e-4, ...
    "ValidationData",augimdsValidation, ...
    "ValidationFrequency",100, ...
    "Verbose",true, ...
    "Plots","none", ...
    "ExecutionEnvironment","auto");

fprintf("\nStarting FAST training...\n");
fprintf("Only 2 epochs. Training progress graphics disabled.\n\n");

%% Train
drNet = trainNetwork( ...
    augimdsTrain, ...
    lgraph, ...
    options);

%% Test
fprintf("\n============================================\n");
fprintf("Testing model...\n");
fprintf("============================================\n");

YPred = classify(drNet,augimdsTest);
YTest = imdsTest.Labels;

testAccuracy = mean(YPred == YTest);

fprintf("\nDR Grad-CAM Test Accuracy: %.2f%%\n", ...
    testAccuracy*100);

%% Save model
modelFile = fullfile( ...
    modelsFolder, ...
    "dr_resnet50_gradcam.mat");

save(modelFile, ...
    "drNet", ...
    "testAccuracy", ...
    "-v7.3");

fprintf("\nModel saved successfully:\n");
fprintf("%s\n",modelFile);

fprintf("\n============================================\n");
fprintf("TRAINING COMPLETE\n");
fprintf("============================================\n");

end