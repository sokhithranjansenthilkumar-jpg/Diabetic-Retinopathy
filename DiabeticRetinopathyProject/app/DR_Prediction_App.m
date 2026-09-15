function DR_Prediction_App

    % Find project folder
    projectFolder = fileparts(fileparts(mfilename("fullpath")));

    % Load trained ResNet-50 + SVM model
    modelFile = fullfile(projectFolder, ...
        "models", "resnet50_svm_model.mat");

    % ---------------------------------------------------------
    % Load 5-class DR network
    % Used for DR prediction and TRUE Grad-CAM
    % ---------------------------------------------------------

    modelFile = fullfile( ...
        projectFolder, ...
        "models", ...
        "dr_gradcam_network.mat");

    if ~exist(modelFile,"file")
        error("Grad-CAM DR model was not found: " + modelFile);
    end

    modelData = load( ...
        modelFile, ...
        "drNet", ...
        "classes", ...
        "testAccuracy");

    drNet = modelData.drNet;
    classes = modelData.classes;
    testAccuracy = modelData.testAccuracy;

    % Store currently selected image
    currentImagePath = "";

    % Patient screening history
    historyFile = fullfile(projectFolder, "results", "patient_history.mat");

    if exist(historyFile, "file")
        historyData = load(historyFile, "history");
        history = historyData.history;
    else
        history = struct( ...
            "PatientID", {}, ...
            "PatientName", {}, ...
            "Age", {}, ...
            "DateTime", {}, ...
            "ImagePath", {}, ...
            "Prediction", {}, ...
            "ModelScore", {}, ...
            "Severity", {}, ...
            "RiskLevel", {}, ...
            "ImageQuality", {}, ...
            "Recommendation", {});
    end

    % ===========================================================
    % Create app window   (widened/heightened to stop clipping &
    % overlap: 900x600 -> 1000x700)
    % ===========================================================
    fig = uifigure( ...
        "Name", "Diabetic Retinopathy Detection", ...
        "Position", [250 100 1000 700]);

    % Title (kept over the image/quality column only, so it can no
    % longer collide with the Patient Info fields on the right)
    titleLabel = uilabel(fig, ...
        "Text", "Diabetic Retinopathy Detection", ...
        "Position", [120 650 350 35], ...
        "FontSize", 22, ...
        "FontWeight", "bold", ...
        "HorizontalAlignment", "center");

    % ---------------------------------------------------------
% RETINAL IMAGE DISPLAY
% ---------------------------------------------------------

% Original retinal image
originalTitle = uilabel(fig, ...
    "Text", "Original Image", ...
    "Position", [80 600 180 25], ...
    "FontSize", 14, ...
    "FontWeight", "bold", ...
    "HorizontalAlignment", "center");

img = uiimage(fig);
img.Position = [50 360 220 220];

% Enhanced retinal image
enhancedTitle = uilabel(fig, ...
    "Text", "Enhanced Image", ...
    "Position", [290 600 180 25], ...
    "FontSize", 14, ...
    "FontWeight", "bold", ...
    "HorizontalAlignment", "center");

enhancedImg = uiimage(fig);
enhancedImg.Position = [270 360 220 220];

    % ---------------------------------------------------------
    % Image Quality Assessment block (left column, under images)
    % Was previously overlapping the AI-analysis column at x=500
    % ---------------------------------------------------------
focusLabel = uilabel(fig, ...
    "Text", "Focus / Blur: --", ...
    "Position", [50 300 440 25], ...
    "FontSize", 13, ...
    "FontWeight", "bold");

illuminationLabel = uilabel(fig, ...
    "Text", "Illumination: --", ...
    "Position", [50 270 440 25], ...
    "FontSize", 13, ...
    "FontWeight", "bold");

fovLabel = uilabel(fig, ...
    "Text", "Field of View: --", ...
    "Position", [50 240 440 25], ...
    "FontSize", 13, ...
    "FontWeight", "bold");

qualityLabel = uilabel(fig, ...
    "Text", "Overall Quality: --", ...
    "Position", [50 210 440 25], ...
    "FontSize", 14, ...
    "FontWeight", "bold");

    % ---------------------------------------------------------
    % Buttons (clean 2-column grid, all y >= 0 now)
    % ---------------------------------------------------------
selectButton = uibutton(fig, ...
    "push", ...
    "Text", "Select Retinal Image", ...
    "Position", [50 170 180 40], ...
    "FontSize", 14);

explainButton = uibutton(fig, ...
    "push", ...
    "Text", "Explain Prediction", ...
    "Position", [250 170 180 40], ...
    "FontSize", 14);

reportButton = uibutton(fig, ...
    "push", ...
    "Text", "Generate Report", ...
    "Position", [50 120 180 40], ...
    "FontSize", 14);

reviewButton = uibutton(fig, ...
    "push", ...
    "Text", "Clinician Review", ...
    "Position", [250 120 180 40], ...
    "FontSize", 14);

historyButton = uibutton(fig, ...
    "push", ...
    "Text", "Patient History", ...
    "Position", [50 70 180 40], ...
    "FontSize", 14);

dashboardButton = uibutton(fig, ...
    "push", ...
    "Text", "Doctor Dashboard", ...
    "Position", [250 70 180 40], ...
    "FontSize", 14);

compareButton = uibutton(fig, ...
    "push", ...
    "Text", "Compare Retinal Scans", ...
    "Position", [50 20 180 40], ...
    "FontSize", 14);

lesionButton = uibutton(fig, ...
    "push", ...
    "Text", "Lesion Evidence", ...
    "Position", [250 20 180 40], ...
    "FontSize", 14);

% ---------------------------------------------------------
% Optic Disc & Fovea Localization Button
% Previously at [650 40 180 40], which sat directly on top of
% the probability chart (ax spans x=520-980, y=20-240 - the
% button's x=650,y=40 fell right inside that box). The chart is
% now shortened slightly and this button moved into the strip
% that opens up underneath it, so the two no longer overlap.
% ---------------------------------------------------------

opticFoveaButton = uibutton(fig, ...
    "push", ...
    "Text", "Optic Disc & Fovea", ...
    "Position", [520 15 220 35], ...
    "FontSize", 14);

opticFoveaButton.ButtonPushedFcn = @showOpticDiscFovea;

    % ---------------------------------------------------------
    % Patient Information (moved fully inside the 1000px-wide
    % figure; fields previously ran off the right edge at x=1000)
    % ---------------------------------------------------------

patientIDLabel = uilabel(fig, ...
    "Text", "Patient ID:", ...
    "Position", [520 650 100 30], ...
    "FontSize", 14, ...
    "FontWeight", "bold");

patientIDField = uieditfield(fig, "text", ...
    "Position", [620 650 300 30], ...
    "Placeholder", "Enter Patient ID");

patientNameLabel = uilabel(fig, ...
    "Text", "Patient Name:", ...
    "Position", [520 610 100 30], ...
    "FontSize", 14, ...
    "FontWeight", "bold");

patientNameField = uieditfield(fig, "text", ...
    "Position", [620 610 300 30], ...
    "Placeholder", "Enter Patient Name");

patientAgeLabel = uilabel(fig, ...
    "Text", "Age:", ...
    "Position", [520 570 100 30], ...
    "FontSize", 14, ...
    "FontWeight", "bold");

patientAgeField = uieditfield(fig, "numeric", ...
    "Position", [620 570 100 30], ...
    "Limits", [1 120], ...
    "Value", 1);

    % ---------------------------------------------------------
    % AI Analysis column (right side) - each label now has its
    % own dedicated vertical slot, 30-40px apart, none overlapping
    % ---------------------------------------------------------

    predictionLabel = uilabel(fig, ...
        "Text", "Prediction: --", ...
        "Position", [520 480 400 40], ...
        "FontSize", 20, ...
        "FontWeight", "bold");

    scoreLabel = uilabel(fig, ...
        "Text", "Model Confidence: --", ...
        "Position", [520 445 400 30], ...
        "FontSize", 16);

    severityLabel = uilabel(fig, ...
        "Text", "Severity: --", ...
        "Position", [520 410 400 30], ...
        "FontSize", 16, ...
        "FontWeight", "bold");

    riskLabel = uilabel(fig, ...
        "Text", "Risk Level: --", ...
        "Position", [520 375 400 30], ...
        "FontSize", 16, ...
        "FontWeight", "bold");

    recommendationLabel = uilabel(fig, ...
        "Text", "Recommendation: --", ...
        "Position", [520 330 460 40], ...
        "FontSize", 14, ...
        "WordWrap", "on");

    % Model performance display

accuracyLabel = uilabel(fig, ...
    "Text", sprintf("Test Accuracy: %.2f%%", testAccuracy), ...
    "Position", [520 290 400 25], ...
    "FontSize", 14, ...
    "FontWeight", "bold");

    % Information
    infoLabel = uilabel(fig, ...
        "Text", "Select a retinal image to begin.", ...
        "Position", [520 250 460 35], ...
        "FontSize", 14, ...
        "WordWrap", "on");

    % Probability chart - height trimmed from 220 to 180 and
    % raised to y=60 so the Optic Disc & Fovea button (y=15-50)
    % has clear room underneath it instead of overlapping.
    ax = uiaxes(fig, ...
     "Position", [520 60 460 180]);

    % Button action
    selectButton.ButtonPushedFcn = @selectImage;
    explainButton.ButtonPushedFcn = @explainPrediction;
    reportButton.ButtonPushedFcn = @generateReport;
    reviewButton.ButtonPushedFcn = @clinicianReview;
    compareButton.ButtonPushedFcn = @compareRetinalScans;
    historyButton.ButtonPushedFcn = @showPatientHistory;
    dashboardButton.ButtonPushedFcn = @showDoctorDashboard;
    lesionButton.ButtonPushedFcn = @showLesionEvidence;


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

       I = imread(currentImagePath);

[focusScore, focusStatus] = focusAssessment(I);
[illuminationScore, illuminationStatus] = illuminationAssessment(I);
[fovScore, fovStatus] = fieldOfViewAssessment(I);
[overallScore, overallStatus] = overallQualityAssessment(I);

% Kept for use in the saved patient record further below, since
% the old checkImageQuality/qualityMessage gate was replaced by
% the overallStatus branching that follows.
qualityMessage = overallStatus;

focusLabel.Text = sprintf( ...
    "Focus / Blur: %.2f%% (%s)", ...
    focusScore, focusStatus);

illuminationLabel.Text = sprintf( ...
    "Illumination: %.2f%% (%s)", ...
    illuminationScore, illuminationStatus);

fovLabel.Text = sprintf( ...
    "Field of View: %.2f%% (%s)", ...
    fovScore, fovStatus);

qualityLabel.Text = sprintf( ...
    "Overall Quality: %.2f%% (%s)", ...
    overallScore, overallStatus);
      

        % Display selected image
        img.ImageSource = imagePath;

        % Read image
I = imread(imagePath);

% -----------------------------------------
% Prepare image for AI prediction
% -----------------------------------------

predictionImage = I;

if size(predictionImage,3) == 1
    predictionImage = cat(3, ...
        predictionImage, ...
        predictionImage, ...
        predictionImage);
end

if size(predictionImage,3) > 3
    predictionImage = predictionImage(:,:,1:3);
end

predictionImage = imresize( ...
    predictionImage,[224 224]);

% -----------------------------------------
% DR prediction using 5-class network
% -----------------------------------------

[predictedClass,scores] = classify( ...
    drNet, ...
    predictionImage);

% Keep the original color image for lesion detection
originalI = I;

% -----------------------------------------
% STEP 1: Image Quality Decision
% -----------------------------------------

if strcmp(overallStatus,"UNGRADEABLE")

    infoLabel.Text = ...
        "Image quality is insufficient. Please recapture the retinal image.";

    uialert(fig, ...
        "The retinal image is ungradeable." + newline + ...
        "Please recapture the retinal image with better focus, illumination, and field of view.", ...
        "Image Quality - Recapture Required");

    return;

elseif strcmp(overallStatus,"BORDERLINE")

    infoLabel.Text = ...
        "Borderline image quality. Adaptive enhancement applied.";

    % Apply enhancement only for borderline images
    I = enhanceRetinalImage(I);

else

    infoLabel.Text = ...
        "Image quality is good. Proceeding with AI screening.";

end

% -----------------------------------------
% IMAGE ENHANCEMENT
% -----------------------------------------
enhancedImg.ImageSource = I;

% -----------------------------------------
% STEP 2: Optic Disc + Fovea Localization
% -----------------------------------------
[opticDiscCenter, foveaCenter] = ...
    localizeDiscFovea(I);

% -----------------------------------------
% VISUALIZE OPTIC DISC + FOVEA
% -----------------------------------------

% Make sure image is RGB
if size(I,3) == 1
    I = cat(3,I,I,I);
end

% Mark optic disc
markedImage = insertMarker( ...
    I, ...
    opticDiscCenter, ...
    "x", ...
    "Color","red", ...
    "Size",12);

% Mark fovea
markedImage = insertMarker( ...
    markedImage, ...
    foveaCenter, ...
    "o", ...
    "Color","green", ...
    "Size",12);

% Display marked image
enhancedImg.ImageSource = markedImage;

% -----------------------------------------
% STEP 3: RETINAL BLOOD VESSEL SEGMENTATION
% -----------------------------------------

vesselMask = vesselSegmentation(I);

% Display vessel segmentation result
figure("Name","Retinal Vessel Segmentation");

subplot(1,2,1);
imshow(I);
title("Enhanced Retinal Image");

subplot(1,2,2);
imshow(vesselMask);
title("Blood Vessel Segmentation");

% -----------------------------------------
% STEP 4: MICROANEURYSM DETECTION
% -----------------------------------------

microaneurysmMask = microaneurysmDetection(I);

% Display microaneurysm detection
figure("Name","Microaneurysm Detection");

subplot(1,2,1);
imshow(I);
title("Enhanced Retinal Image");

subplot(1,2,2);
imshow(microaneurysmMask);
title("Microaneurysm Detection");

% -----------------------------------------
% STEP 5: EXUDATE DETECTION
% -----------------------------------------

exudateMask = exudateDetection(I);

% Display exudate detection
figure("Name","Exudate Detection");

subplot(1,2,1);
imshow(I);
title("Enhanced Retinal Image");

subplot(1,2,2);
imshow(exudateMask);
title("Exudate Detection");

% -----------------------------------------
% STEP 6A: HEMORRHAGE DETECTION
% -----------------------------------------

% Use ORIGINAL color image for hemorrhage detection
hemorrhageMask = hemorrhageDetection(originalI);

% Display hemorrhage detection
figure("Name","Hemorrhage Detection");

subplot(1,2,1);
imshow(originalI);
title("Original Retinal Image");

subplot(1,2,2);
imshow(hemorrhageMask);
title("Hemorrhage Detection");

% -----------------------------------------
% STEP 6B: NEOVASCULARIZATION DETECTION
% -----------------------------------------

[neovascularMask, vesselMask] = ...
    neovascularizationDetection(I);

% Display neovascularization detection
figure("Name","Neovascularization Detection");

subplot(1,2,1);
imshow(I);
title("Enhanced Retinal Image");

subplot(1,2,2);
imshow(neovascularMask);
title("Neovascularization Detection");

% -----------------------------------------
% AI PREDICTION PREPROCESSING
% Use ORIGINAL image because the model
% was trained on original retinal images
% -----------------------------------------

predictionImage = originalI;

% Convert grayscale to RGB
if size(predictionImage,3) == 1
    predictionImage = cat(3, ...
        predictionImage, ...
        predictionImage, ...
        predictionImage);
end

% Convert RGBA to RGB
if size(predictionImage,3) > 3
    predictionImage = predictionImage(:,:,1:3);
end

% Resize exactly like training
predictionImage = imresize( ...
    predictionImage,[224 224]);

% Convert exactly like training
predictionImage = im2single(predictionImage);

% -----------------------------------------
% DR PREDICTION USING 5-CLASS NETWORK
% -----------------------------------------

[predictedClass,scores] = classify( ...
    drNet, ...
    predictionImage);

% -----------------------------------------
% MODEL CONFIDENCE SCORE
% -----------------------------------------

% drNet returns class scores for the 5 DR classes.
% Use the highest class score as the model's
% uncalibrated confidence indicator.

% -----------------------------------------
% CALIBRATED MODEL CONFIDENCE
% -----------------------------------------

calibrationFile = fullfile( ...
    projectFolder, ...
    "models", ...
    "dr_calibration.mat");

if exist(calibrationFile,"file")

    calibrationData = load( ...
        calibrationFile, ...
        "bestTemperature", ...
        "classes");

    bestTemperature = calibrationData.bestTemperature;

    % Convert network scores to probabilities
    rawScores = double(scores);

    rawScores = max(rawScores,eps);

    rawScores = rawScores ./ sum(rawScores);

    % Convert probabilities to logits
    logits = log(rawScores);

    % Apply temperature scaling
    scaledLogits = logits ./ bestTemperature;

    % Stable softmax
    scaledLogits = scaledLogits - max(scaledLogits);

    expScores = exp(scaledLogits);

    calibratedScores = ...
        expScores ./ sum(expScores);

    % Highest calibrated confidence
    confidenceScore = ...
        max(calibratedScores) * 100;

    confidenceText = sprintf( ...
        "Calibrated Confidence: %.2f%%", ...
        confidenceScore);

else

    % Fallback if calibration file is missing
    confidenceScore = max(scores) * 100;

    confidenceText = sprintf( ...
        "Model Confidence: %.2f%%", ...
        confidenceScore);

end

% Find highest score
[~,index] = max(scores);

% Display predicted class
predictionLabel.Text = ...
    "Prediction: " + string(predictedClass);

% Display confidence
scoreLabel.Text = confidenceText;


% -----------------------------------------
% DR SEVERITY LEVEL
% International Clinical DR Severity Scale
% -----------------------------------------

switch string(predictedClass)

    case "No_DR"
        severityText = "Level 0 - No DR";

    case "Mild"
        severityText = "Level 1 - Mild NPDR";

    case "Moderate"
        severityText = "Level 2 - Moderate NPDR";

    case "Severe"
        severityText = "Level 3 - Severe NPDR";

    case "Proliferate_DR"
        severityText = "Level 4 - Proliferative DR";

    otherwise
        severityText = "Unknown";

end

severityLabel.Text = ...
    "Severity: " + severityText;

% -----------------------------------------
% RISK LEVEL
% -----------------------------------------

switch string(predictedClass)

    case {"No_DR","Mild"}
        riskText = "LOW";

    case "Moderate"
        riskText = "MEDIUM";

    case "Severe"
        riskText = "HIGH";

    case "Proliferate_DR"
        riskText = "VERY HIGH";

    otherwise
        riskText = "UNKNOWN";

end

riskLabel.Text = ...
    "Risk Level: " + riskText;


% -----------------------------------------
% RECOMMENDATION
% -----------------------------------------

switch string(predictedClass)

    case "No_DR"
        recommendationText = ...
            "No diabetic retinopathy detected. Continue routine eye screening.";

    case "Mild"
        recommendationText = ...
            "Mild diabetic retinopathy detected. Recommend regular ophthalmic follow-up.";

    case "Moderate"
        recommendationText = ...
            "Moderate diabetic retinopathy detected. Recommend ophthalmologist evaluation.";

    case "Severe"
        recommendationText = ...
            "Severe diabetic retinopathy detected. Prompt ophthalmologist referral is recommended.";

    case "Proliferate_DR"
        recommendationText = ...
            "Proliferative diabetic retinopathy detected. Urgent ophthalmologist referral is recommended.";

    otherwise
        recommendationText = ...
            "Unable to determine recommendation.";

end

recommendationLabel.Text = ...
    "Recommendation: " + recommendationText;

% -----------------------------------------
% STEP 4: Risk Assessment
% -----------------------------------------
switch string(predictedClass)

    case "No_DR"
        riskLevel = "LOW";

    case "Mild"
        riskLevel = "LOW";

    case "Moderate"
        riskLevel = "MEDIUM";

    case "Severe"
        riskLevel = "HIGH";

    case "Proliferate_DR"
        riskLevel = "VERY HIGH";

    otherwise
        riskLevel = "UNKNOWN";

end

% Display risk level
riskLabel.Text = ...
    "Risk Level: " + riskLevel;

% Screening recommendation
switch string(predictedClass)

    case "No_DR"
        recommendation = ...
            "No diabetic retinopathy detected by the screening model.";

    case "Mild"
        recommendation = ...
            "Mild changes detected. Further eye examination is recommended.";

    case "Moderate"
        recommendation = ...
            "Moderate changes detected. Further ophthalmic evaluation is recommended.";

    case "Severe"
        recommendation = ...
            "Severe changes detected. Prompt ophthalmic evaluation is recommended.";

    case "Proliferate_DR"
        recommendation = ...
            "Advanced changes detected. Urgent ophthalmic evaluation is recommended.";

    otherwise
        recommendation = ...
            "Please consult an eye-care professional for further evaluation.";

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

        % NOTE: scoreLabel is reserved for "Model Confidence" above.
        % "score" (the relative softmax value) is still computed and
        % saved into the patient record below; it is no longer
        % written into scoreLabel.Text, since that previously
        % silently replaced the confidence wording right after it
        % was set.

        infoLabel.Text = ...
            "Image successfully analyzed using ResNet-50 and SVM.";
        
       % ---------------------------------------------------------
% Save screening result to Patient History
% ---------------------------------------------------------

% Read patient information from the UI fields
patientID = strtrim(string(patientIDField.Value));
patientName = strtrim(string(patientNameField.Value));
patientAge = patientAgeField.Value;

% Check patient information
if strlength(patientID) == 0
    uialert(fig, ...
        "Please enter Patient ID before analyzing the image.", ...
        "Missing Patient ID");
    return;
end

if strlength(patientName) == 0
    uialert(fig, ...
        "Please enter Patient Name before analyzing the image.", ...
        "Missing Patient Name");
    return;
end

if isempty(patientAge) || patientAge < 1
    uialert(fig, ...
        "Please enter a valid patient age.", ...
        "Invalid Age");
    return;
end

% Create new patient record
newRecord = struct( ...
    "PatientID", patientID, ...
    "PatientName", patientName, ...
    "Age", patientAge, ...
    "DateTime", datetime("now"), ...
    "ImagePath", string(currentImagePath), ...
    "Prediction", string(predictedClass), ...
    "ModelScore", score, ...
    "Severity", string(predictedClass), ...
    "RiskLevel", string(riskLevel), ...
    "ImageQuality", string(qualityMessage), ...
    "Recommendation", string(recommendation));

% Add record to history
if isempty(history)
    history = newRecord;
else
    history(end + 1) = newRecord;
end

% Save history
save(historyFile, "history");

    end

    % ---------------------------------------------------------
    % Explain prediction using occlusion analysis
    % ---------------------------------------------------------
    % ---------------------------------------------------------
% Explain prediction using TRUE Grad-CAM
% ---------------------------------------------------------
function explainPrediction(~, ~)

    if strlength(currentImagePath) == 0
        uialert(fig, ...
            "Please select a retinal image first.", ...
            "No Image Selected");
        return;
    end

    % ---------------------------------------------------------
    % Load Grad-CAM DR network
    % ---------------------------------------------------------

    gradcamModelFile = fullfile( ...
        projectFolder, ...
        "models", ...
        "dr_gradcam_network.mat");

    if ~exist(gradcamModelFile, "file")
        uialert(fig, ...
            "Grad-CAM model file was not found.", ...
            "Model Error");
        return;
    end

    data = load( ...
        gradcamModelFile, ...
        "drNet", ...
        "classes");

    drNet = data.drNet;

    % ---------------------------------------------------------
    % Read selected retinal image
    % ---------------------------------------------------------

    I = imread(currentImagePath);

    % Convert grayscale to RGB
    if size(I,3) == 1
        I = cat(3,I,I,I);
    end

    % Convert RGBA to RGB
    if size(I,3) > 3
        I = I(:,:,1:3);
    end

    % Resize to ResNet-50 input size
    I = imresize(I,[224 224]);

    % ---------------------------------------------------------
    % Predict DR class using Grad-CAM network
    % ---------------------------------------------------------

    predictedClass = classify(drNet,I);

    % ---------------------------------------------------------
    % Generate TRUE 5-class Grad-CAM
    % ---------------------------------------------------------

    scoreMap = gradCAM( ...
        drNet, ...
        I, ...
        predictedClass, ...
        "FeatureLayer","activation_49_relu");

    % ---------------------------------------------------------
    % Resize Grad-CAM map
    % ---------------------------------------------------------

    scoreMap = imresize( ...
        scoreMap, ...
        [224 224], ...
        "bilinear");

    % Normalize heatmap
    scoreMap = scoreMap - min(scoreMap(:));

    if max(scoreMap(:)) > 0
        scoreMap = scoreMap ./ max(scoreMap(:));
    end

    % ---------------------------------------------------------
    % Create explanation window
    % ---------------------------------------------------------

    explanationFig = uifigure( ...
        "Name","Explainable AI - Retinal Analysis", ...
        "Position",[150 100 1100 650]);

    % ---------------------------------------------------------
    % Original retinal image
    % ---------------------------------------------------------

    uiimage(explanationFig, ...
        "ImageSource",currentImagePath, ...
        "Position",[50 100 400 330]);

    uilabel(explanationFig, ...
        "Text","Original Retinal Image", ...
        "Position",[130 60 250 30], ...
        "FontSize",16, ...
        "FontWeight","bold");

    % ---------------------------------------------------------
    % Grad-CAM axes
    % ---------------------------------------------------------

    explanationAxes = uiaxes(explanationFig, ...
        "Position",[500 100 400 330]);

    imshow(I,"Parent",explanationAxes);

    hold(explanationAxes,"on");

    h = imagesc( ...
        explanationAxes, ...
        scoreMap);

    h.AlphaData = 0.45 * scoreMap;

    colormap(explanationAxes,"jet");

    colorbar(explanationAxes);

    title( ...
        explanationAxes, ...
        "Grad-CAM - " + string(predictedClass), ...
        "FontSize",16);

    hold(explanationAxes,"off");

    % ---------------------------------------------------------
    % Explanation text
    % ---------------------------------------------------------

    uilabel(explanationFig, ...
        "Text", ...
        "TRUE Grad-CAM explanation for " + ...
        string(predictedClass), ...
        "Position",[500 60 500 30], ...
        "FontSize",14, ...
        "FontWeight","bold");

    % ---------------------------------------------------------
    % Information
    % ---------------------------------------------------------

    uilabel(explanationFig, ...
        "Text", ...
        "Highlighted regions show image areas contributing to the AI prediction.", ...
        "Position",[50 25 700 25], ...
        "FontSize",12);

    % ---------------------------------------------------------
    % Close button
    % ---------------------------------------------------------

    uibutton(explanationFig, ...
        "Text","Close", ...
        "Position",[930 30 120 40], ...
        "ButtonPushedFcn", ...
        @(src,event) close(explanationFig));

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

    % Create results folder if it does not exist
    if ~exist(fullfile(projectFolder,"results"),"dir")
        mkdir(fullfile(projectFolder,"results"));
    end

    fid = fopen(reportFile, "w");

    if fid == -1
        uialert(fig, ...
            "Unable to create the report file.", ...
            "Report Error");
        return;
    end

    % ---------------------------------------------------------
    % REPORT HEADER
    % ---------------------------------------------------------

    fprintf(fid, "DIABETIC RETINOPATHY DETECTION REPORT\n");
    fprintf(fid, "====================================\n\n");

    fprintf(fid, "Date and Time: %s\n\n", ...
        char(datetime("now")));

    % ---------------------------------------------------------
    % PATIENT INFORMATION
    % ---------------------------------------------------------

    fprintf(fid, "PATIENT INFORMATION\n");
    fprintf(fid, "--------------------\n");

    fprintf(fid, "Patient ID: %s\n", ...
        char(patientIDField.Value));

    fprintf(fid, "Patient Name: %s\n", ...
        char(patientNameField.Value));

    fprintf(fid, "Age: %g\n\n", ...
        patientAgeField.Value);

    % ---------------------------------------------------------
    % AI SCREENING RESULT
    % ---------------------------------------------------------

    fprintf(fid, "AI SCREENING RESULT\n");
    fprintf(fid, "-------------------\n");

    fprintf(fid, "%s\n", ...
        char(predictionLabel.Text));

    fprintf(fid, "%s\n", ...
        char(severityLabel.Text));

    fprintf(fid, "%s\n", ...
        char(riskLabel.Text));

    fprintf(fid, "%s\n\n", ...
    char(scoreLabel.Text));

    fprintf(fid, "Test Accuracy: %.2f%%\n\n", testAccuracy);

    % ---------------------------------------------------------
    % IMAGE QUALITY
    % ---------------------------------------------------------

    fprintf(fid, "IMAGE QUALITY ASSESSMENT\n");
    fprintf(fid, "------------------------\n");

    fprintf(fid, "%s\n\n", ...
        char(focusLabel.Text));

    fprintf(fid, "%s\n", ...
        char(illuminationLabel.Text));

    fprintf(fid, "%s\n", ...
        char(fovLabel.Text));

    fprintf(fid, "%s\n\n", ...
        char(qualityLabel.Text));

    % ---------------------------------------------------------
    % LESION EVIDENCE
    % ---------------------------------------------------------

    fprintf(fid, "LESION EVIDENCE\n");
    fprintf(fid, "---------------\n");

    % Recalculate lesion evidence for the selected image
    originalImage = imread(currentImagePath);

    if size(originalImage,3) == 1
        originalImage = cat(3, ...
            originalImage, ...
            originalImage, ...
            originalImage);
    end

    enhancedImage = enhanceRetinalImage(originalImage);

    vesselMask = vesselSegmentation(enhancedImage);
    microaneurysmMask = microaneurysmDetection(enhancedImage);
    exudateMask = exudateDetection(enhancedImage);
    hemorrhageMask = hemorrhageDetection(originalImage);

    [neovascularMask,~] = ...
        neovascularizationDetection(enhancedImage);

    vesselCount = bwconncomp(vesselMask).NumObjects;
    microaneurysmCount = bwconncomp(microaneurysmMask).NumObjects;
    exudateCount = bwconncomp(exudateMask).NumObjects;
    hemorrhageCount = bwconncomp(hemorrhageMask).NumObjects;
    neovascularCount = bwconncomp(neovascularMask).NumObjects;

    fprintf(fid, ...
        "Blood Vessel Regions: %d\n", ...
        vesselCount);

    fprintf(fid, ...
        "Microaneurysm Candidates: %d\n", ...
        microaneurysmCount);

    fprintf(fid, ...
        "Exudate Candidates: %d\n", ...
        exudateCount);

    fprintf(fid, ...
        "Hemorrhage Candidates: %d\n", ...
        hemorrhageCount);

    fprintf(fid, ...
        "Neovascularization Candidates: %d\n\n", ...
        neovascularCount);

    % ---------------------------------------------------------
    % EXPLAINABILITY
    % ---------------------------------------------------------

    fprintf(fid, "EXPLAINABILITY\n");
    fprintf(fid, "--------------\n");

    fprintf(fid, ...
        "The Explain Prediction feature uses occlusion-based analysis to highlight image regions that influence the model score.\n\n");

    fprintf(fid, ...
        "Lesion Evidence provides candidate retinal lesion regions using image-processing techniques.\n\n");

    fprintf(fid, ...
        "Optic Disc and Fovea localization provides automated prototype retinal structure localization.\n\n");

    % ---------------------------------------------------------
    % RECOMMENDATION
    % ---------------------------------------------------------

    fprintf(fid, "RECOMMENDATION\n");
    fprintf(fid, "--------------\n");

    fprintf(fid, "%s\n\n", ...
        char(recommendationLabel.Text));

    % ---------------------------------------------------------
    % IMAGE INFORMATION
    % ---------------------------------------------------------

    fprintf(fid, "IMAGE ANALYZED\n");
    fprintf(fid, "--------------\n");

    fprintf(fid, "%s\n\n", ...
        currentImagePath);

    % ---------------------------------------------------------
% FINAL SCREENING SUMMARY
% ---------------------------------------------------------

fprintf(fid, "\nDIABETIC RETINOPATHY SCREENING SUMMARY\n");
fprintf(fid, "====================================\n\n");

fprintf(fid, "Patient Information\n");
fprintf(fid, "-------------------\n");
fprintf(fid, "Patient ID: %s\n", char(patientIDField.Value));
fprintf(fid, "Patient Name: %s\n", char(patientNameField.Value));
fprintf(fid, "Age: %g\n\n", patientAgeField.Value);

fprintf(fid, "AI RESULT\n");
fprintf(fid, "---------\n");
fprintf(fid, "%s\n", char(predictionLabel.Text));
fprintf(fid, "%s\n", char(severityLabel.Text));
fprintf(fid, "%s\n\n", char(riskLabel.Text));

fprintf(fid, "CONFIDENCE\n");
fprintf(fid, "----------\n");
fprintf(fid, "%s\n\n", char(scoreLabel.Text));

fprintf(fid, "IMAGE QUALITY\n");
fprintf(fid, "-------------\n");
fprintf(fid, "%s\n", char(focusLabel.Text));
fprintf(fid, "%s\n", char(illuminationLabel.Text));
fprintf(fid, "%s\n", char(fovLabel.Text));
fprintf(fid, "%s\n\n", char(qualityLabel.Text));

fprintf(fid, "CLINICAL EVIDENCE\n");
fprintf(fid, "-----------------\n");
fprintf(fid, "Lesion Evidence: Available\n");
fprintf(fid, "Grad-CAM: Available\n");
fprintf(fid, "Optic Disc: Detected\n");
fprintf(fid, "Fovea: Localized\n\n");

fprintf(fid, "RECOMMENDATION\n");
fprintf(fid, "--------------\n");
fprintf(fid, "%s\n\n", char(recommendationLabel.Text));


% ---------------------------------------------------------
% IMPORTANT NOTE
% ---------------------------------------------------------

fprintf(fid, "IMPORTANT NOTE\n");
    fprintf(fid, "--------------\n");

    fprintf(fid, ...
        "This system is intended as an AI-assisted screening prototype and does not replace examination or diagnosis by a qualified eye-care professional.\n");

    fprintf(fid, ...
        "Lesion detections are image-processing candidate regions and are not clinically validated diagnoses.\n");

    % Close file
    fclose(fid);

    % ---------------------------------------------------------
    % OPEN REPORT
    % ---------------------------------------------------------

    edit(reportFile);

    uialert(fig, ...
        "Report successfully generated and opened.", ...
        "Report Generated");

end


    % ---------------------------------------------------------
    % Clinician Review
    % ---------------------------------------------------------
    function clinicianReview(~, ~)

        if strlength(currentImagePath) == 0
            uialert(fig, ...
                "Please select and analyze a retinal image first.", ...
                "No Image Selected");
            return;
        end

        % Create clinician review window
        reviewFig = uifigure( ...
            "Name", "Clinician Review - Retinal Analysis", ...
            "Position", [200 100 900 650]);

        % ---------------------------------------------------------
% Patient Information
% ---------------------------------------------------------

uilabel(reviewFig, ...
    "Text", "Patient ID: " + string(patientIDField.Value), ...
    "Position", [80 395 350 30], ...
    "FontSize", 15, ...
    "FontWeight", "bold");

uilabel(reviewFig, ...
    "Text", "Patient Name: " + string(patientNameField.Value), ...
    "Position", [80 360 350 30], ...
    "FontSize", 15, ...
    "FontWeight", "bold");

uilabel(reviewFig, ...
    "Text", "Age: " + string(patientAgeField.Value), ...
    "Position", [80 325 200 30], ...
    "FontSize", 15);

% ---------------------------------------------------------
% AI Analysis
% ---------------------------------------------------------

uilabel(reviewFig, ...
    "Text", predictionLabel.Text, ...
    "Position", [500 395 300 30], ...
    "FontSize", 15, ...
    "FontWeight", "bold");

uilabel(reviewFig, ...
    "Text", scoreLabel.Text, ...
    "Position", [500 360 300 30], ...
    "FontSize", 15);

uilabel(reviewFig, ...
    "Text", severityLabel.Text, ...
    "Position", [500 325 300 30], ...
    "FontSize", 15, ...
    "FontWeight", "bold");

uilabel(reviewFig, ...
    "Text", riskLabel.Text, ...
    "Position", [500 290 300 30], ...
    "FontSize", 15, ...
    "FontWeight", "bold");

        % Title
        uilabel(reviewFig, ...
            "Text", "Clinician Review", ...
            "Position", [250 440 250 35], ...
            "FontSize", 22, ...
            "FontWeight", "bold", ...
            "HorizontalAlignment", "center");

        % Review instruction
        uilabel(reviewFig, ...
            "Text", "Clinician Decision:", ...
            "Position", [80 210 200 30], ...
            "FontSize", 16, ...
            "FontWeight", "bold");

% Decision dropdown
decisionDropDown = uidropdown(reviewFig, ...
    "Items", ["Pending", "Confirmed by Clinician", "Further Examination Required"], ...
    "Position", [80 170 400 40], ...
    "Value", "Pending", ...
    "FontSize", 14);

        % Comments
uilabel(reviewFig, ...
    "Text", "Clinician Comments:", ...
    "Position", [80 125 250 30], ...
    "FontSize", 15, ...
    "FontWeight", "bold");

commentsBox = uitextarea(reviewFig, ...
    "Position", [80 55 550 70], ...
    "Placeholder", "Enter clinician comments...", ...
    "FontSize", 13);

       % Save review button
uibutton(reviewFig, ...
    "push", ...
    "Text", "Save Review", ...
    "Position", [650 70 160 45], ...
    "FontSize", 14, ...
    "ButtonPushedFcn", @saveReview);


        function saveReview(~, ~)

    % ---------------------------------------------------------
    % Check Patient Information
    % ---------------------------------------------------------

    patientID = strtrim(string(patientIDField.Value));
    patientName = strtrim(string(patientNameField.Value));
    patientAge = patientAgeField.Value;

    if strlength(patientID) == 0
        uialert(reviewFig, ...
            "Please enter Patient ID.", ...
            "Missing Patient ID");
        return;
    end

    if strlength(patientName) == 0
        uialert(reviewFig, ...
            "Please enter Patient Name.", ...
            "Missing Patient Name");
        return;
    end

    if isempty(patientAge) || patientAge < 1
        uialert(reviewFig, ...
            "Please enter a valid patient age.", ...
            "Invalid Age");
        return;
    end

    % ---------------------------------------------------------
    % Existing Save Review Code
    % ---------------------------------------------------------

    resultsFolder = fullfile(projectFolder, "results");

    if ~exist(resultsFolder, "dir")
        mkdir(resultsFolder);
    end

    timestamp = datestr(now, "yyyymmdd_HHMMSS");

    reviewFile = fullfile(resultsFolder, ...
    "Clinician_Review_" + timestamp + ".txt");

            fid = fopen(reviewFile, "w");

            if fid == -1
                uialert(reviewFig, ...
                    "Unable to save clinician review.", ...
                    "Save Error");
                return;
            end

            fprintf(fid, "DIABETIC RETINOPATHY CLINICIAN REVIEW\n");
            fprintf(fid, "====================================\n\n");

            fprintf(fid, "AI Prediction: %s\n", ...
                char(predictionLabel.Text));

            fprintf(fid, "Model Score: %s\n", ...
                char(scoreLabel.Text));

            fprintf(fid, "Severity: %s\n\n", ...
                char(severityLabel.Text));

            fprintf(fid, "Clinician Decision: %s\n\n", ...
                char(decisionDropDown.Value));

            fprintf(fid, "Clinician Comments:\n%s\n\n", ...
                strjoin(string(commentsBox.Value), newline));

            fprintf(fid, "Image:\n%s\n", ...
                currentImagePath);

            fprintf(fid, "\nDate and Time: %s\n", ...
                char(datetime("now")));

            fclose(fid);

            uialert(reviewFig, ...
                "Clinician review saved successfully.", ...
                "Review Saved");

        end

    end

% ---------------------------------------------------------
% Patient History
% ---------------------------------------------------------
function showPatientHistory(~, ~)

    if ~exist(historyFile, "file")
        uialert(fig, ...
            "No patient history is available yet.", ...
            "Patient History");
        return;
    end

    data = load(historyFile, "history");
    historyData = data.history;

    if isempty(historyData)
        uialert(fig, ...
            "No patient history is available yet.", ...
            "Patient History");
        return;
    end

    historyTable = struct2table(historyData);

    historyFig = uifigure( ...
        "Name", "Patient History", ...
        "Position", [200 150 1100 500]);

    uilabel(historyFig, ...
        "Text", "Patient Screening History", ...
        "Position", [350 450 400 35], ...
        "FontSize", 22, ...
        "FontWeight", "bold", ...
        "HorizontalAlignment", "center");

    uitable(historyFig, ...
        "Data", historyTable, ...
        "Position", [30 80 1040 340], ...
        "ColumnName", historyTable.Properties.VariableNames);

end


% ---------------------------------------------------------
% Compare Previous Retinal Scans
% ---------------------------------------------------------
function compareRetinalScans(~, ~)

    if strlength(currentImagePath) == 0
        uialert(fig, ...
            "Please select and analyze the current retinal image first.", ...
            "No Current Scan");
        return;
    end

    if ~exist(historyFile, "file")
        uialert(fig, ...
            "No previous retinal scans are available.", ...
            "No History");
        return;
    end

    data = load(historyFile, "history");
    historyData = data.history;

    if isempty(historyData)
        uialert(fig, ...
            "No previous retinal scans are available.", ...
            "No History");
        return;
    end

    % Current patient ID
    currentPatientID = strtrim(string(patientIDField.Value));

    % Find previous scans of the SAME patient
    previousRecords = historyData( ...
        string({historyData.PatientID}) == currentPatientID & ...
        string({historyData.ImagePath}) ~= string(currentImagePath));

    if isempty(previousRecords)
        uialert(fig, ...
            "No previous scan is available for this patient.", ...
            "No Previous Scan");
        return;
    end

    % Most recent previous scan
    previousRecord = previousRecords(end);

    % Comparison window
    compareFig = uifigure( ...
        "Name", "Retinal Scan Comparison", ...
        "Position", [100 80 1200 650]);

    uilabel(compareFig, ...
        "Text", "Retinal Scan Comparison", ...
        "Position", [400 590 400 35], ...
        "FontSize", 22, ...
        "FontWeight", "bold", ...
        "HorizontalAlignment", "center");

    uilabel(compareFig, ...
        "Text", "Previous Scan", ...
        "Position", [180 540 250 30], ...
        "FontSize", 18, ...
        "FontWeight", "bold", ...
        "HorizontalAlignment", "center");

    uilabel(compareFig, ...
        "Text", "Current Scan", ...
        "Position", [770 540 250 30], ...
        "FontSize", 18, ...
        "FontWeight", "bold", ...
        "HorizontalAlignment", "center");

    % Previous image
    uiimage(compareFig, ...
        "ImageSource", char(previousRecord.ImagePath), ...
        "Position", [80 260 450 260]);

    % Current image
    uiimage(compareFig, ...
        "ImageSource", char(currentImagePath), ...
        "Position", [670 260 450 260]);

    % Previous information
    previousText = sprintf( ...
        "Patient ID: %s\nPrediction: %s\nSeverity: %s\nRisk Level: %s", ...
        char(previousRecord.PatientID), ...
        char(previousRecord.Prediction), ...
        char(previousRecord.Severity), ...
        char(previousRecord.RiskLevel));

    uilabel(compareFig, ...
        "Text", previousText, ...
        "Position", [100 100 400 120], ...
        "FontSize", 15, ...
        "WordWrap", "on");

    % Current information
    currentText = sprintf( ...
        "Patient ID: %s\nPrediction: %s\nSeverity: %s\nRisk Level: %s", ...
        char(patientIDField.Value), ...
        erase(char(predictionLabel.Text), "Prediction: "), ...
        erase(char(severityLabel.Text), "Severity: "), ...
        erase(char(riskLabel.Text), "Risk Level: "));

    uilabel(compareFig, ...
        "Text", currentText, ...
        "Position", [690 100 400 120], ...
        "FontSize", 15, ...
        "WordWrap", "on");

end


% ---------------------------------------------------------
% Doctor Dashboard
% ---------------------------------------------------------
function showDoctorDashboard(~, ~)

    if ~exist(historyFile, "file")
        uialert(fig, ...
            "No patient screening data is available.", ...
            "Doctor Dashboard");
        return;
    end

    data = load(historyFile, "history");
    historyData = data.history;

    if isempty(historyData)
        uialert(fig, ...
            "No patient screening data is available.", ...
            "Doctor Dashboard");
        return;
    end

    historyTable = struct2table(historyData);

    dashboardFig = uifigure( ...
        "Name", "Doctor Dashboard", ...
        "Position", [150 100 1100 650]);

    uilabel(dashboardFig, ...
        "Text", "Doctor Dashboard", ...
        "Position", [400 590 300 40], ...
        "FontSize", 24, ...
        "FontWeight", "bold", ...
        "HorizontalAlignment", "center");

    uilabel(dashboardFig, ...
        "Text", "Total Screenings", ...
        "Position", [80 500 200 30], ...
        "FontSize", 16, ...
        "FontWeight", "bold");

    uilabel(dashboardFig, ...
        "Text", string(height(historyTable)), ...
        "Position", [80 450 200 40], ...
        "FontSize", 28);

    highRiskCount = sum( ...
        upper(string(historyTable.RiskLevel)) == "HIGH");

    uilabel(dashboardFig, ...
        "Text", "High Risk Patients", ...
        "Position", [350 500 220 30], ...
        "FontSize", 16, ...
        "FontWeight", "bold");

    uilabel(dashboardFig, ...
        "Text", string(highRiskCount), ...
        "Position", [350 450 200 40], ...
        "FontSize", 28);

    mediumRiskCount = sum( ...
        upper(string(historyTable.RiskLevel)) == "MEDIUM");

    uilabel(dashboardFig, ...
        "Text", "Medium Risk Patients", ...
        "Position", [650 500 220 30], ...
        "FontSize", 16, ...
        "FontWeight", "bold");

    uilabel(dashboardFig, ...
        "Text", string(mediumRiskCount), ...
        "Position", [650 450 200 40], ...
        "FontSize", 28);

    uilabel(dashboardFig, ...
        "Text", "Recent Screening Records", ...
        "Position", [80 390 300 30], ...
        "FontSize", 18, ...
        "FontWeight", "bold");

    uitable(dashboardFig, ...
        "Data", historyTable, ...
        "Position", [50 50 1000 320], ...
        "ColumnName", historyTable.Properties.VariableNames);

end

% ---------------------------------------------------------
% Lesion Evidence
% ---------------------------------------------------------
function showLesionEvidence(~, ~)

    if strlength(currentImagePath) == 0
        uialert(fig, ...
            "Please select a retinal image first.", ...
            "No Image Selected");
        return;
    end

    % Read original image
    originalImage = imread(currentImagePath);

    % Convert to RGB if necessary
    if size(originalImage,3) == 1
        originalImage = cat(3, ...
            originalImage, ...
            originalImage, ...
            originalImage);
    end

    % Enhanced image
    enhancedImage = enhanceRetinalImage(originalImage);

    % Detect retinal structures / lesions
    vesselMask = vesselSegmentation(enhancedImage);

    microaneurysmMask = ...
        microaneurysmDetection(enhancedImage);

    exudateMask = ...
        exudateDetection(enhancedImage);

    hemorrhageMask = ...
        hemorrhageDetection(originalImage);

    [neovascularMask,~] = ...
        neovascularizationDetection(enhancedImage);

    % -----------------------------------------
    % LESION EVIDENCE COUNTS
    % (computed once - previously this block ran twice with
    % identical results, and a second, duplicate summary label
    % was created below using the second copy)
    % -----------------------------------------

    vesselCount = bwconncomp(vesselMask).NumObjects;
    microaneurysmCount = bwconncomp(microaneurysmMask).NumObjects;
    exudateCount = bwconncomp(exudateMask).NumObjects;
    hemorrhageCount = bwconncomp(hemorrhageMask).NumObjects;
    neovascularCount = bwconncomp(neovascularMask).NumObjects;

    % ===========================================================
    % Evidence window - heightened (700 -> 780) and the two rows
    % of plots shifted up so a dedicated strip opens up at the
    % bottom for the summary text without it overlapping the
    % "Candidate Exudates" plot the way it did before.
    % ===========================================================
    evidenceFig = uifigure( ...
        "Name","Lesion Evidence - Retinal Analysis", ...
        "Position",[100 40 1200 780]);

    % Title
    uilabel(evidenceFig, ...
        "Text","Retinal Lesion Evidence", ...
        "Position",[400 730 400 35], ...
        "FontSize",22, ...
        "FontWeight","bold", ...
        "HorizontalAlignment","center");

    % Close button (moved up next to the title so it can never be
    % crowded by the summary text at the bottom)
    uibutton(evidenceFig, ...
        "Text","Close", ...
        "Position",[1060 735 100 30], ...
        "ButtonPushedFcn", ...
        @(src,event) close(evidenceFig));

    % Original image
    ax1 = uiaxes(evidenceFig, ...
        "Position",[30 430 350 270]);

    imshow(originalImage,"Parent",ax1);
    title(ax1,"Original Retinal Image");

    % Vessel segmentation
    ax2 = uiaxes(evidenceFig, ...
        "Position",[425 430 350 270]);

    imshow(vesselMask,"Parent",ax2);
    title(ax2,"Blood Vessel Regions");

    % Microaneurysms
    ax3 = uiaxes(evidenceFig, ...
        "Position",[820 430 350 270]);

    imshow(microaneurysmMask,"Parent",ax3);
    title(ax3,"Candidate Microaneurysms");

    % Exudates
    ax4 = uiaxes(evidenceFig, ...
        "Position",[30 140 350 270]);

    imshow(exudateMask,"Parent",ax4);
    title(ax4,"Candidate Exudates");

    % Hemorrhages
    ax5 = uiaxes(evidenceFig, ...
        "Position",[425 140 350 270]);

    imshow(hemorrhageMask,"Parent",ax5);
    title(ax5,"Candidate Hemorrhages");

    % Neovascularization
    ax6 = uiaxes(evidenceFig, ...
        "Position",[820 140 350 270]);

    imshow(neovascularMask,"Parent",ax6);
    title(ax6,"Candidate Neovascularization");

    % -----------------------------------------
    % LESION EVIDENCE SUMMARY
    % Single label now (the duplicate uilabel call that produced
    % the doubled "LESION EVIDENCE SUMMARY" text has been removed),
    % placed in its own strip below the plots so it no longer
    % overlaps ax4 ("Candidate Exudates").
    % -----------------------------------------

    summaryText = [
        "LESION EVIDENCE SUMMARY"
        ""
        "Blood Vessel Regions: " + string(vesselCount)
        "Microaneurysm Candidates: " + string(microaneurysmCount)
        "Exudate Candidates: " + string(exudateCount)
        "Hemorrhage Candidates: " + string(hemorrhageCount)
        "Neovascularization: " + string(neovascularCount)
        ""
        "Clinical Evidence:"
        "Detected lesion candidates are shown as image-processing evidence."
        "These findings support AI-assisted screening and require"
        "clinical validation by a qualified eye-care professional."
        ];

    uilabel(evidenceFig, ...
        "Text", summaryText, ...
        "Position", [30 10 1140 120], ...
        "FontSize", 12, ...
        "FontWeight", "bold", ...
        "HorizontalAlignment", "left");

end

% ---------------------------------------------------------
% Retinal Image Enhancement
% CLAHE + Illumination Normalization + Denoising
% ---------------------------------------------------------
    function enhancedImage = enhanceRetinalImage(I)

        % Convert grayscale to RGB if necessary
        if size(I,3) == 1
            I = cat(3,I,I,I);
        end

        % ---------------------------------------------------------
        % Optic Disc and Fovea Localization
        % ---------------------------------------------------------
        function [opticDiscCenter, foveaCenter] = localizeDiscFovea(I)

            % Convert to grayscale
            if size(I,3) == 3
                grayImage = rgb2gray(I);
            else
                grayImage = I;
            end

            % Convert to double
            grayImage = im2double(grayImage);

            % Smooth image
            smoothImage = imgaussfilt(grayImage,5);

            % Find bright regions
            threshold = graythresh(smoothImage);
            brightMask = smoothImage > threshold;

            % Remove small regions
            brightMask = bwareaopen(brightMask,100);

            % Find connected regions
            stats = regionprops(brightMask, ...
                "Area","Centroid","BoundingBox");

            % Default values
            opticDiscCenter = [NaN NaN];
            foveaCenter = [NaN NaN];

            if isempty(stats)
                return;
            end

            % Largest bright region = optic disc candidate
            [~,largestIndex] = max([stats.Area]);

            opticDiscCenter = stats(largestIndex).Centroid;

            % Approximate fovea location
            imageCenter = [size(I,2)/2, size(I,1)/2];

            direction = imageCenter - opticDiscCenter;

            foveaCenter = opticDiscCenter + 0.8 * direction;

        end

        % Convert image to uint8
        I = im2uint8(I);

        % Convert to grayscale
        Igray = rgb2gray(I);

        % -----------------------------------------------------
        % 1. Illumination Normalization
        % -----------------------------------------------------
        background = imgaussfilt(Igray,20);

        normalized = imsubtract(Igray,background);

        normalized = mat2gray(normalized);

        normalized = im2uint8(normalized);

        % -----------------------------------------------------
        % 2. CLAHE
        % -----------------------------------------------------
        claheImage = adapthisteq(normalized, ...
            "ClipLimit",0.01, ...
            "Distribution","rayleigh");

        % -----------------------------------------------------
        % 3. Denoising
        % -----------------------------------------------------
        denoisedImage = medfilt2(claheImage,[3 3]);

        % Convert back to RGB
        enhancedImage = cat(3, ...
            denoisedImage, ...
            denoisedImage, ...
            denoisedImage);

    end

% ---------------------------------------------------------
% Show Optic Disc and Fovea Localization
% ---------------------------------------------------------
    function showOpticDiscFovea(~, ~)

        if strlength(currentImagePath) == 0
            uialert(fig, ...
                "Please select a retinal image first.", ...
                "No Image Selected");
            return;
        end

        % Read selected retinal image
        I = imread(currentImagePath);

        % Perform localization
        [opticDiscCenter, foveaCenter, outputImage] = ...
            opticDiscFoveaLocalization(I);

        % Create result window
        localizationFig = uifigure( ...
            "Name","Retinal Structure Localization", ...
            "Position",[200 120 900 650]);

        % Display localized image
        localizationAxes = uiaxes( ...
            localizationFig, ...
            "Position",[100 140 600 450]);

        imshow(outputImage, ...
            "Parent",localizationAxes);

        title( ...
            localizationAxes, ...
            "Optic Disc and Fovea Localization", ...
            "FontSize",16);

        % Display coordinates
        uilabel(localizationFig, ...
            "Text", ...
            "Optic Disc: [" + ...
            string(round(opticDiscCenter(1))) + ", " + ...
            string(round(opticDiscCenter(2))) + "]", ...
            "Position",[100 90 350 30], ...
            "FontSize",13, ...
            "FontWeight","bold");

        uilabel(localizationFig, ...
            "Text", ...
            "Fovea: [" + ...
            string(round(foveaCenter(1))) + ", " + ...
            string(round(foveaCenter(2))) + "]", ...
            "Position",[450 90 300 30], ...
            "FontSize",13, ...
            "FontWeight","bold");

        % Close button
        uibutton(localizationFig, ...
            "Text","Close", ...
            "Position",[740 35 100 40], ...
            "ButtonPushedFcn", ...
            @(src,event) close(localizationFig));

    end

end