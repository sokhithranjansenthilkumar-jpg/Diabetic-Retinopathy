clc;
clear;
close all;

%% Load ResNet-50

fprintf("Loading ResNet-50...\n");

net = resnet50;

inputSize = net.Layers(1).InputSize;

%% Load one retinal image

datasetFolder = fullfile(pwd,"dataset");

imds = imageDatastore( ...
    datasetFolder, ...
    "IncludeSubfolders",true, ...
    "LabelSource","foldernames");

I = readimage(imds,1);

%% Prepare image exactly like training

if size(I,3) == 1
    I = cat(3,I,I,I);
end

if size(I,3) > 3
    I = I(:,:,1:3);
end

I = imresize(I,inputSize(1:2));
I = im2single(I);

%% Extract activation_49_relu features

featureMap = activations( ...
    net, ...
    I, ...
    "activation_49_relu");

%% Display feature size

fprintf("\nFeature layer: activation_49_relu\n");

disp("Feature map size:");

disp(size(featureMap));

fprintf("\nTest completed successfully.\n");