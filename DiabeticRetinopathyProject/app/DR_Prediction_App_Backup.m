function DR_Prediction_App

    % Find project folder
    projectFolder = fileparts(fileparts(mfilename("fullpath")));

    % Load trained ResNet-50 + SVM model
    modelFile = fullfile(projectFolder, ...
        "models", "resnet50_svm_model.mat");

    modelData = load(modelFile, "net", "svmModel", "classes");

    net = modelData.net;
    svmModel = modelData.svmModel;
    classes = modelData.classes;

    % Create app window
    fig = uifigure( ...
        "Name", "Diabetic Retinopathy Detection", ...
        "Position", [300 150 900 600]);

    % Title
    titleLabel = uilabel(fig, ...
        "Text", "Diabetic Retinopathy Detection", ...
        "Position", [250 540 400 35], ...
        "FontSize", 22, ...
        "FontWeight", "bold", ...
        "HorizontalAlignment", "center");

    % Image display
    img = uiimage(fig);
    img.Position = [80 180 380 330];

    % Select image button
    selectButton = uibutton(fig, ...
        "push", ...
        "Text", "Select Retinal Image", ...
        "Position", [180 120 180 40], ...
        "FontSize", 14);

    % Prediction display
    predictionLabel = uilabel(fig, ...
        "Text", "Prediction: --", ...
        "Position", [500 400 350 40], ...
        "FontSize", 20, ...
        "FontWeight", "bold");

    % Score display
    scoreLabel = uilabel(fig, ...
        "Text", "Model Score: --", ...
        "Position", [500 350 350 35], ...
        "FontSize", 16);

    % Information
    infoLabel = uilabel(fig, ...
        "Text", "Select a retinal image to begin.", ...
        "Position", [500 280 350 60], ...
        "FontSize", 14, ...
        "WordWrap", "on");

    % Button action
    selectButton.ButtonPushedFcn = @selectImage;


    % ---------------------------------------------------------
    % Image selection and prediction
    % ---------------------------------------------------------
    function selectImage(~, ~)

        [file,path] = uigetfile( ...
            {'*.jpg;*.jpeg;*.png;*.bmp', ...
             'Retinal Images'}, ...
            "Select Retinal Image");

        if isequal(file,0)
            return;
        end

        imagePath = fullfile(path,file);

        % Display selected image
        img.ImageSource = imagePath;

        % Read image
        I = imread(imagePath);

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
        [predictedClass,scores] = predict( ...
            svmModel,features);

        % Find highest score
        [~,index] = max(scores);

        % Display predicted class
        predictionLabel.Text = ...
            "Prediction: " + string(predictedClass);

        % Convert scores to relative model scores
        expScores = exp(scores - max(scores));
        relativeScores = expScores ./ sum(expScores);

        score = relativeScores(index) * 100;

        scoreLabel.Text = ...
            sprintf("Model Score: %.2f%%",score);

        infoLabel.Text = ...
            "Image successfully analyzed using ResNet-50 and SVM.";

    end

end