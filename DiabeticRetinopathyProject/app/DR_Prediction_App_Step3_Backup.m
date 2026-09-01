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

    % Store currently selected image
    currentImagePath = "";

       % Create app window
    fig = uifigure( ...
        "Name", "Diabetic Retinopathy Detection", ...
        "Position", [100 100 1000 650]);

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

    % Explain prediction button
    explainButton = uibutton(fig, ...
        "push", ...
        "Text", "Explain Prediction", ...
        "Position", [180 80 180 40], ...
        "FontSize", 14);

    % Select image button
    selectButton = uibutton(fig, ...
        "push", ...
        "Text", "Select Retinal Image", ...
        "Position", [180 120 180 40], ...
        "FontSize", 14);

    % Generate report button
    reportButton = uibutton(fig, ...
        "push", ...
        "Text", "Generate Report", ...
        "Position", [180 30 180 40], ...
        "FontSize", 14);

    % Probability chart
    ax = uiaxes(fig, ...
         "Position", [500 25 400 150]);

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

    % Severity display
    severityLabel = uilabel(fig, ...
        "Text", "Severity: --", ...
        "Position", [500 300 350 35], ...
        "FontSize", 16, ...
        "FontWeight", "bold");

    % Recommendation display
    recommendationLabel = uilabel(fig, ...
        "Text", "Recommendation: --", ...
       "Position", [500 200 400 50], ...
        "FontSize", 14, ...
        "WordWrap", "on");

    % Model performance display
    accuracyLabel = uilabel(fig, ...
        "Text", "Test Accuracy: 75.55%", ...
        "Position", [500 170 400 30], ...
        "FontSize", 14, ...
        "FontWeight", "bold");

    % Information
    infoLabel = uilabel(fig, ...
        "Text", "Select a retinal image to begin.", ...
        "Position", [500 220 350 60], ...
        "FontSize", 14, ...
        "WordWrap", "on");

    % Button action
    selectButton.ButtonPushedFcn = @selectImage;
    explainButton.ButtonPushedFcn = @explainPrediction;
    reportButton.ButtonPushedFcn = @generateReport;


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
        currentImagePath = imagePath;

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

        % Display severity
        severityLabel.Text = ...
            "Severity: " + string(predictedClass);

        % Screening recommendation
        switch string(predictedClass)
            case "No_DR"
                recommendation = "No diabetic retinopathy detected by the screening model.";

            case "Mild"
                recommendation = "Mild changes detected. Further eye examination is recommended.";

            case "Moderate"
                recommendation = "Moderate changes detected. Further ophthalmic evaluation is recommended.";

            case "Severe"
                recommendation = "Severe changes detected. Prompt ophthalmic evaluation is recommended.";

            case "Proliferate_DR"
                recommendation = "Advanced changes detected. Urgent ophthalmic evaluation is recommended.";

            otherwise
                recommendation = "Please consult an eye-care professional for further evaluation.";
        end

        recommendationLabel.Text = ...
            "Recommendation: " + recommendation;

        % Convert scores to relative model scores
        expScores = exp(scores - max(scores));
        relativeScores = expScores ./ sum(expScores);

        score = relativeScores(index) * 100;

        % Display class probability chart
        bar(ax, relativeScores * 100);
        ax.XTick = 1:numel(classes);
        ax.XTickLabel = classes;
        ax.XTickLabelRotation = 45;
        ax.YLim = [0 100];
        ax.YLabel.String = "Relative Score (%)";
        ax.Title.String = "Prediction Scores";

        scoreLabel.Text = ...
            sprintf("Model Score: %.2f%%",score);

        infoLabel.Text = ...
            "Image successfully analyzed using ResNet-50 and SVM.";

    end

    % ---------------------------------------------------------
    % Explain prediction using occlusion analysis
    % ---------------------------------------------------------
    function explainPrediction(~, ~)

        if strlength(currentImagePath) == 0
            uialert(fig, ...
                "Please select a retinal image first.", ...
                "No Image Selected");
            return;
        end

        % Read selected image
        I = imread(currentImagePath);

        % Convert grayscale to RGB
        if size(I,3) == 1
            I = cat(3,I,I,I);
        end

        % Resize image
        I = imresize(I,[224 224]);

        % Original prediction
        originalFeatures = activations( ...
            net,I,"avg_pool","OutputAs","rows");

        [originalClass,originalScores] = predict( ...
            svmModel,originalFeatures);

        [~,classIndex] = max(originalScores);

        baselineScore = originalScores(classIndex);

        % Create 5 x 5 occlusion grid
        gridSize = 5;
        patchSize = floor(224/gridSize);

        heatmap = zeros(gridSize,gridSize);

        for r = 1:gridSize
            for c = 1:gridSize

                Iocc = I;

                rowStart = (r-1)*patchSize + 1;
                rowEnd = min(r*patchSize,224);

                colStart = (c-1)*patchSize + 1;
                colEnd = min(c*patchSize,224);

                patch = I(rowStart:rowEnd,...
                          colStart:colEnd,:);

                meanValue = mean(patch(:));

                Iocc(rowStart:rowEnd,...
                     colStart:colEnd,:) = meanValue;

                occFeatures = activations( ...
                    net,Iocc,"avg_pool","OutputAs","rows");

                [~,occScores] = predict( ...
                    svmModel,occFeatures);

                heatmap(r,c) = ...
                    baselineScore - occScores(classIndex);

            end
        end

        % Resize and normalize heatmap
        heatmap = imresize(heatmap,[224 224],"bilinear");

        heatmap = heatmap - min(heatmap(:));

        if max(heatmap(:)) > 0
            heatmap = heatmap ./ max(heatmap(:));
        end

        % Explanation window
        explanationFig = uifigure( ...
            "Name","Explainable AI - Retinal Analysis", ...
            "Position",[150 150 1000 500]);

        % Original image
        uiimage(explanationFig, ...
            "ImageSource",currentImagePath, ...
            "Position",[50 100 400 330]);

        uilabel(explanationFig, ...
            "Text","Original Retinal Image", ...
            "Position",[130 60 250 30], ...
            "FontSize",16, ...
            "FontWeight","bold");

        % Heatmap
        explanationAxes = uiaxes(explanationFig, ...
            "Position",[500 100 400 330]);

        imshow(I,"Parent",explanationAxes);
        hold(explanationAxes,"on");

        h = imagesc(explanationAxes,heatmap);
        h.AlphaData = 0.45 * heatmap;

        colormap(explanationAxes,"jet");
        colorbar(explanationAxes);

        title(explanationAxes, ...
            "Important Regions - " + string(originalClass));

        hold(explanationAxes,"off");

        uilabel(explanationFig, ...
            "Text", ...
            "Occlusion-based model explanation for " + ...
            string(originalClass), ...
            "Position",[500 60 450 30], ...
            "FontSize",14);

    end

% ---------------------------------------------------------
% Generate prediction report
% ---------------------------------------------------------
    function generateReport(~, ~)

        if strlength(currentImagePath) == 0
            uialert(fig, ...
                "Please select a retinal image first.", ...
                "No Image Selected");
            return;
        end

        reportFile = fullfile(projectFolder, ...
            "results", ...
            "DR_Prediction_Report.txt");

        fid = fopen(reportFile, "w");

        if fid == -1
            uialert(fig, ...
                "Unable to create the report file.", ...
                "Report Error");
            return;
        end

        fprintf(fid, "DIABETIC RETINOPATHY DETECTION REPORT\n");
        fprintf(fid, "====================================\n\n");

        fprintf(fid, "Date and Time: %s\n\n", ...
            char(datetime("now")));

        fprintf(fid, "Prediction: %s\n", ...
    char(predictionLabel.Text));

        fprintf(fid, "Severity: %s\n", ...
    char(severityLabel.Text));

        fprintf(fid, "%s\n\n", ...
    char(scoreLabel.Text));

        fprintf(fid, "Model: ResNet-50 + SVM\n");

        fprintf(fid, "Test Accuracy: 75.55%%\n\n");

       fprintf(fid, "%s\n\n", ...
    char(recommendationLabel.Text));

        fprintf(fid, "Image analyzed:\n%s\n", ...
            currentImagePath);

        fclose(fid);

% Open the report immediately
edit(reportFile);

uialert(fig, ...
    "Report successfully generated and opened.", ...
    "Report Generated");

    end

end


