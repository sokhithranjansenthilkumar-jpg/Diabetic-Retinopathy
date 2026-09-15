function testGradCAM()

clc;
close all;

projectFolder = fileparts(fileparts(mfilename("fullpath")));

modelFile = fullfile(projectFolder, ...
    "models", "resnet50_svm_model.mat");

load(modelFile, "net");

[fileName,filePath] = uigetfile( ...
    {'*.jpg;*.jpeg;*.png;*.bmp','Retinal Images'}, ...
    'Select a Retinal Image');

if isequal(fileName,0)
    disp("No image selected.");
    return;
end

imagePath = fullfile(filePath,fileName);

I = imread(imagePath);

% Convert to RGB
if size(I,3) == 1
    I = cat(3,I,I,I);
end

if size(I,3) > 3
    I = I(:,:,1:3);
end

% Resize exactly like the trained model
I = imresize(I,[224 224]);

% Same preprocessing used during training
I = im2single(I);

% Convert network to dlnetwork
dlnet = dag2dlnetwork(net);

% ResNet-50 final convolution/ReLU feature layer
featureLayer = "activation_49_relu";

% Show selected image
figure("Name","DR Grad-CAM Test");

subplot(1,2,1);
imshow(I);
title("Retinal Image");

% Generate Grad-CAM
scoreMap = gradCAM( ...
    dlnet, ...
    I, ...
    1, ...
    "FeatureLayer",featureLayer);

% Show Grad-CAM
subplot(1,2,2);
imshow(I);
hold on;

imagesc(scoreMap);
axis image;
colormap jet;
colorbar;
alpha(0.45);

title("Grad-CAM Attention Map");

hold off;

disp("Grad-CAM generated successfully.");

end