function result = AI_generate_sap_like_clinical_report(dataDir, varargin)
%AI_GENERATE_SAP_LIKE_CLINICAL_REPORT Generate a SAP-like clinical report.
% 生成类似SAP视野检查的客观视野报告。
%
% Example:
%   result = AI_generate_sap_like_clinical_report( ...
%       'D:\0课题\青光眼\data\临床实验\260520xkx');

    settings = AI_report_settings();
    if nargin >= 1 && ~isempty(dataDir)
        settings.dataDir = char(dataDir);
    end
    settings = AI_parse_inputs(settings, varargin{:});
    settings = AI_refresh_output_paths(settings);

    if ~exist(settings.outputDir, 'dir')
        mkdir(settings.outputDir);
    end

    patientInfo = AI_load_or_create_patient_info(settings.patientInfoFile);

    if settings.useExistingClinicalResult && exist(settings.existingClinicalMat, 'file')
        clinicalResult = AI_load_existing_clinical_result(settings.existingClinicalMat);
    else
        clinicalResult = AI_process_clinical_folder(settings);
    end

    eyeResult = AI_compute_eye_indices(clinicalResult.pointTable);
    mapResult = AI_plot_sap_like_vf_report(eyeResult.sensitivity, ...
        'outputDir', settings.mapDir, ...
        'filePrefix', settings.filePrefix, ...
        'leftTitle', '左眼视野灰阶图', ...
        'rightTitle', '右眼视野灰阶图', ...
        'xLabel', '视野 X (deg)', ...
        'yLabel', '视野 Y (deg)', ...
        'colorbarLabel', '敏感度样指标', ...
        'drawColorbar', false, ...
        'showFigure', false, ...
        'fontName', settings.fontName);

    reportFiles = AI_write_report_figure(patientInfo, clinicalResult, ...
        eyeResult, mapResult, settings);

    AI_write_report_tables(clinicalResult, eyeResult, settings);

    result = struct();
    result.settings = settings;
    result.patientInfo = patientInfo;
    result.clinicalResult = clinicalResult;
    result.eyeResult = eyeResult;
    result.mapResult = mapResult;
    result.reportFiles = reportFiles;

    save(settings.matFile, 'result', '-v7.3');

    fprintf('\nSaved SAP-like report PNG: %s\n', reportFiles.png);
    fprintf('Saved SAP-like report PDF: %s\n', reportFiles.pdf);
    fprintf('Saved report tables: %s\n', settings.excelFile);
    fprintf('Saved MAT result: %s\n', settings.matFile);
end

function settings = AI_report_settings()
    % 基础分析参数
    settings.fs = 250;
    settings.tStart = 0;
    settings.tEnd = 0.45;
    settings.WnPara = [0.5, 2, 20, 30];
    settings.chanList = 44:64;
    settings.trainTrialTotal = 480;
    settings.testTrialTotal = 360;
    settings.trainTrialNum = 120;
    settings.testTrialNum = 60;
    settings.foldNum = 4;
    settings.probMeanBlockSize = 5;
    settings.tempType = [1,2; 2,1; 3,4; 4,3];

    % 默认数据路径和结果路径
    settings.dataDir = char([68 58 92 48 35838 39064 92 38738 20809 30524 ...
        92 100 97 116 97 92 20020 24202 23454 39564 92 50 54 48 53 50 48 120 107 120]);
    settings.resultDir = char([68 58 92 48 35838 39064 92 38738 20809 30524 ...
        92 32467 26524]);

    stamp = datestr(now, 'yyyymmdd_HHMMSS');
    settings.filePrefix = ['AI_SAP_like_report_', stamp];
    settings.outputDir = fullfile(settings.resultDir, 'AI_SAP_like_clinical_report', settings.filePrefix);
    settings.mapDir = fullfile(settings.outputDir, 'vf_maps');
    settings.patientInfoFile = fullfile(settings.outputDir, 'AI_patient_info_template.xlsx');
    settings.excelFile = fullfile(settings.outputDir, 'AI_report_tables.xlsx');
    settings.matFile = fullfile(settings.outputDir, 'AI_report_result.mat');
    settings.reportPng = fullfile(settings.outputDir, 'AI_SAP_like_report.png');
    settings.reportPdf = fullfile(settings.outputDir, 'AI_SAP_like_report.pdf');

    settings.useExistingClinicalResult = false;
    settings.existingClinicalMat = fullfile(settings.resultDir, ...
        'AI_clinical_260520xkx', 'AI_clinical_260520xkx_result.mat');

    % 报告判读阈值：第一版以形式输出为主，后续可继续优化
    settings.normalSensitivity = 80;
    settings.suspectSensitivity = 50;
    settings.severeSensitivity = 20;
    settings.fontName = '宋体';
end

function settings = AI_refresh_output_paths(settings)
    settings.mapDir = fullfile(settings.outputDir, 'vf_maps');
    settings.patientInfoFile = fullfile(settings.outputDir, 'AI_patient_info_template.xlsx');
    settings.excelFile = fullfile(settings.outputDir, 'AI_report_tables.xlsx');
    settings.matFile = fullfile(settings.outputDir, 'AI_report_result.mat');
    settings.reportPng = fullfile(settings.outputDir, 'AI_SAP_like_report.png');
    settings.reportPdf = fullfile(settings.outputDir, 'AI_SAP_like_report.pdf');
end

function settings = AI_parse_inputs(settings, varargin)
    if mod(numel(varargin), 2) ~= 0
        error('Optional inputs must be name-value pairs.');
    end
    for i = 1:2:numel(varargin)
        name = char(varargin{i});
        value = varargin{i + 1};
        if ~isfield(settings, name)
            error('Unknown setting: %s', name);
        end
        settings.(name) = value;
    end
end

function patientInfo = AI_load_or_create_patient_info(infoFile)
    % 生成患者基本信息模板；报告中的普通信息用中文显示
    infoDir = fileparts(infoFile);
    if ~exist(infoDir, 'dir')
        mkdir(infoDir);
    end

    if ~exist(infoFile, 'file')
        fieldKey = {'patientId'; 'name'; 'sex'; 'age'; 'examDate'; ...
            'diagnosis'; 'operator'; 'dataFolder'; 'notes'};
        fieldName = {'患者编号'; '姓名'; '性别'; '年龄'; '检查日期'; ...
            '临床诊断'; '检查人员'; '数据文件夹'; '备注'};
        fieldValue = repmat({'None'}, numel(fieldKey), 1);
        infoTable = table(fieldKey, fieldName, fieldValue);
        writetable(infoTable, infoFile, 'Sheet', 'PatientInfo');
    end

    infoTable = readtable(infoFile, 'Sheet', 'PatientInfo', 'TextType', 'string');
    patientInfo = struct();
    for i = 1:height(infoTable)
        key = char(infoTable.fieldKey(i));
        patientInfo.(key) = char(infoTable.fieldValue(i));
    end
    patientInfo.table = infoTable;
end

function clinicalResult = AI_load_existing_clinical_result(matFile)
    loaded = load(matFile, 'result');
    if ~isfield(loaded, 'result')
        error('MAT file does not contain variable result: %s', matFile);
    end
    clinicalResult = loaded.result;
end

function clinicalResult = AI_process_clinical_folder(settings)
    trainFiles = dir(fullfile(settings.dataDir, 'train*.cnt'));
    trainNums = AI_file_numbers({trainFiles.name}, 'train');
    [trainNums, order] = sort(trainNums);
    trainFiles = trainFiles(order);
    groupNum = numel(trainFiles);
    if groupNum == 0
        error('No train*.cnt files found in: %s', settings.dataDir);
    end

    pointRows = {};
    groupRows = {};
    clinicalResult.group = cell(groupNum, 1);

    for group_i = 1:groupNum
        trainFile = fullfile(settings.dataDir, sprintf('train%d.cnt', trainNums(group_i)));
        testFile = fullfile(settings.dataDir, sprintf('test%d.cnt', trainNums(group_i)));
        fprintf('\n==== SAP-like report group %d/%d ====\n', group_i, groupNum);
        groupResult = AI_process_one_group(group_i, trainFile, testFile, settings);
        clinicalResult.group{group_i} = groupResult;
        pointRows = [pointRows; groupResult.pointRows]; %#ok<AGROW>
        groupRows = [groupRows; groupResult.groupRows]; %#ok<AGROW>
    end

    clinicalResult.pointTable = cell2table(pointRows, 'VariableNames', AI_point_table_names());
    clinicalResult.groupTable = cell2table(groupRows, 'VariableNames', AI_group_table_names());
    clinicalResult.overallTable = AI_build_overall_table(clinicalResult.groupTable);
    clinicalResult.settings = settings;
end

function nums = AI_file_numbers(fileNames, prefix)
    nums = nan(numel(fileNames), 1);
    for i = 1:numel(fileNames)
        token = regexp(fileNames{i}, [prefix, '(\d+)\.cnt'], 'tokens', 'once');
        if isempty(token)
            nums(i) = i;
        else
            nums(i) = str2double(token{1});
        end
    end
end

function groupResult = AI_process_one_group(group_i, trainFile, testFile, settings)
    if ~exist(testFile, 'file')
        error('Missing paired test file: %s', testFile);
    end

    [trainData, typeAllTrain] = AI_load_cnt(trainFile, settings, settings.trainTrialTotal);
    [testData, typeAllTest] = AI_load_cnt(testFile, settings, settings.testTrialTotal);

    pointNum = min([numel(typeAllTrain), numel(typeAllTest), size(settings.tempType, 1)]);
    probDvAll = nan(3, settings.testTrialNum / settings.foldNum, pointNum);
    blockProbAll = nan(3, settings.testTrialNum / settings.foldNum / settings.probMeanBlockSize, pointNum);
    pointProb = nan(3, pointNum);
    pointLabel = nan(1, pointNum);

    for point_i = 1:pointNum
        pair = settings.tempType(point_i, :);
        template = trainData(settings.chanList, :, 1:settings.trainTrialNum, pair);
        testTrials = testData(settings.chanList, :, 1:settings.testTrialNum, point_i);

        [~, probDv] = glc_detection_prob(template, testTrials, settings.foldNum);
        probDvAll(:, :, point_i) = probDv;
        blockProbAll(:, :, point_i) = AI_block_average_prob(probDv, settings.probMeanBlockSize);
        pointProb(:, point_i) = mean(blockProbAll(:, :, point_i), 2);
        pointProb(:, point_i) = pointProb(:, point_i) ./ sum(pointProb(:, point_i));
        [~, pointLabel(point_i)] = max(pointProb(:, point_i));
    end

    vfIndex = AI_three_class_indices(pointProb);
    pointRows = cell(pointNum, numel(AI_point_table_names()));
    for point_i = 1:pointNum
        globalPoint = (group_i - 1) * pointNum + point_i;
        pointRows(point_i, :) = { ...
            group_i, point_i, globalPoint, typeAllTrain(point_i), typeAllTest(point_i), ...
            pointLabel(point_i), AI_label_name(pointLabel(point_i)), ...
            AI_round4(pointProb(1, point_i)), AI_round4(pointProb(2, point_i)), ...
            AI_round4(pointProb(3, point_i)), AI_round4(1 - pointProb(1, point_i))};
    end

    groupRows = { ...
        group_i, trainFile, testFile, settings.trainTrialNum, settings.testTrialNum, ...
        AI_pattern_string(pointLabel), ...
        AI_round4(vfIndex.VFI), AI_round4(100 - vfIndex.VFI), ...
        AI_round4(vfIndex.MD_loss), AI_round4(vfIndex.PSD), ...
        AI_round4(vfIndex.LEI), AI_round4(vfIndex.REI), ...
        AI_round4(vfIndex.defectBurden)};

    groupResult = struct();
    groupResult.group = group_i;
    groupResult.trainFile = trainFile;
    groupResult.testFile = testFile;
    groupResult.probDvAll = probDvAll;
    groupResult.blockProbAll = blockProbAll;
    groupResult.pointProb = pointProb;
    groupResult.pointLabel = pointLabel;
    groupResult.vfIndex = vfIndex;
    groupResult.pointRows = pointRows;
    groupResult.groupRows = groupRows;
end

function [dataAll, typeAll] = AI_load_cnt(fileName, settings, trialTotal)
    if ~exist(fileName, 'file')
        error('Missing CNT file: %s', fileName);
    end
    [~, dataSeg, typeAll] = EEGRead5(fileName, 1000, settings.fs, ...
        [settings.tStart, settings.tEnd], settings.WnPara, trialTotal);
    dataAll = dataSeg(1:64, :, :, :);
end

function blockProb = AI_block_average_prob(probDv, blockSize)
    [stateNum, foldNum] = size(probDv);
    if mod(foldNum, blockSize) ~= 0
        error('Number of Prob_dv columns must be divisible by blockSize.');
    end

    blockNum = foldNum / blockSize;
    blockProb = nan(stateNum, blockNum);
    for block_i = 1:blockNum
        idx = (block_i - 1) * blockSize + 1:block_i * blockSize;
        blockProb(:, block_i) = mean(probDv(:, idx), 2);
        blockProb(:, block_i) = blockProb(:, block_i) ./ sum(blockProb(:, block_i));
    end
end

function eyeResult = AI_compute_eye_indices(pointTable)
    if height(pointTable) ~= 28
        warning('Expected 28 points, but got %d points.', height(pointTable));
    end
    if ~ismember('globalPoint', pointTable.Properties.VariableNames)
        pointTable.globalPoint = (1:height(pointTable))';
    end

    pNormal = pointTable.pNormal;
    pLeft = pointTable.pLeftAbnormal;
    pRight = pointTable.pRightAbnormal;
    pointProb = [pNormal, pLeft, pRight];
    defectScore = AI_defect_score_from_prob(pointProb);

    leftSensitivity = 100 * (pNormal + pRight);
    rightSensitivity = 100 * (pNormal + pLeft);
    sensitivity = max(0, min(100, [leftSensitivity, rightSensitivity]));

    leftMetrics = AI_one_eye_metrics(sensitivity(:, 1), defectScore(:, 1), '左眼');
    rightMetrics = AI_one_eye_metrics(sensitivity(:, 2), defectScore(:, 2), '右眼');

    eyeResult = struct();
    eyeResult.sensitivity = sensitivity;
    eyeResult.defectScore = defectScore;
    eyeResult.pointTable = pointTable;
    eyeResult.leftMetrics = leftMetrics;
    eyeResult.rightMetrics = rightMetrics;
    eyeResult.eyeMetricTable = struct2table([leftMetrics; rightMetrics]);
    eyeResult.pointSensitivityTable = table(pointTable.globalPoint, pointTable.group, ...
        pointTable.point, sensitivity(:, 1), sensitivity(:, 2), ...
        defectScore(:, 1), defectScore(:, 2), ...
        'VariableNames', {'globalPoint', 'group', 'point', ...
        'leftSensitivity', 'rightSensitivity', ...
        'leftDefectScore', 'rightDefectScore'});
    eyeResult.overallJudgement = AI_overall_judgement(leftMetrics, rightMetrics);
end

function defectScore = AI_defect_score_from_prob(pointProb)
    pointProb = max(pointProb, 0);
    pointProb = pointProb ./ sum(pointProb, 2);
    pNormal = pointProb(:, 1);
    pLeft = pointProb(:, 2);
    pRight = pointProb(:, 3);
    defectScore = [(1 - pNormal) .* pLeft, (1 - pNormal) .* pRight];
end

function metrics = AI_one_eye_metrics(sensitivity, defectScore, eyeName)
    epsVal = 1e-3;
    pointDb = 10 * log10(max(sensitivity, epsVal) ./ 100);

    metrics = struct();
    metrics.eye = eyeName;
    metrics.VFI = AI_round4(mean(sensitivity, 'omitnan'));
    metrics.MD = AI_round4(mean(pointDb, 'omitnan'));
    metrics.PSD = AI_round4(std(pointDb, 1, 'omitnan'));
    metrics.nNormal = sum(defectScore < 0.15);
    metrics.nSuspect = sum(defectScore >= 0.15 & defectScore < 0.25);
    metrics.nDefect = sum(defectScore >= 0.25);
    metrics.judgement = AI_eye_judgement(metrics);
end

function judgement = AI_eye_judgement(metrics)
    if metrics.VFI > 95
        judgement = '视野正常';
    elseif metrics.VFI >= 70
        judgement = '可疑异常';
    else
        judgement = '视野异常';
    end
end

function judgement = AI_overall_judgement(leftMetrics, rightMetrics)
    leftAbnormal = strcmp(leftMetrics.judgement, '视野异常');
    rightAbnormal = strcmp(rightMetrics.judgement, '视野异常');
    leftSuspect = strcmp(leftMetrics.judgement, '可疑异常');
    rightSuspect = strcmp(rightMetrics.judgement, '可疑异常');

    if leftAbnormal || rightAbnormal
        judgement = '视野异常';
    elseif leftSuspect || rightSuspect
        judgement = '可疑异常';
    else
        judgement = '视野正常';
    end
end

function reportFiles = AI_write_report_figure(patientInfo, clinicalResult, eyeResult, mapResult, settings)
    fig = figure('Color', 'w', 'Position', [80, 60, 1650, 1120], ...
        'Visible', 'off');
    fontName = settings.fontName;

    AI_add_textbox(fig, [0.035, 0.925, 0.45, 0.05], ...
        'DCPM客观视野检测报告', 22, 'bold', fontName);
    AI_add_textbox(fig, [0.64, 0.925, 0.32, 0.04], ...
        ['报告生成时间：', datestr(now, 'yyyy-mm-dd HH:MM')], 10, 'normal', fontName);

    infoText = AI_patient_info_text(patientInfo, settings);
    AI_add_textbox(fig, [0.035, 0.825, 0.93, 0.095], infoText, 10.5, 'normal', fontName);

    imgW = 0.245;
    imgH = 0.320;
    imgX = [0.010, 0.255, 0.500];
    leftY = 0.495;
    rightY = 0.185;

    AI_add_report_image(fig, mapResult.leftDensityPng, [imgX(1), leftY, imgW, imgH]);
    AI_add_report_image(fig, mapResult.leftValuePng, [imgX(2), leftY, imgW, imgH]);
    AI_add_report_image(fig, mapResult.leftPng, [imgX(3), leftY, imgW, imgH]);
    AI_add_report_image(fig, mapResult.rightDensityPng, [imgX(1), rightY, imgW, imgH]);
    AI_add_report_image(fig, mapResult.rightValuePng, [imgX(2), rightY, imgW, imgH]);
    AI_add_report_image(fig, mapResult.rightPng, [imgX(3), rightY, imgW, imgH]);

    leftMetricText = AI_metric_text('左眼指标', eyeResult.leftMetrics);
    rightMetricText = AI_metric_text('右眼指标', eyeResult.rightMetrics);
    AI_add_textbox(fig, [0.765, 0.565, 0.20, 0.20], leftMetricText, 10.5, 'normal', fontName);
    AI_add_textbox(fig, [0.765, 0.335, 0.20, 0.20], rightMetricText, 10.5, 'normal', fontName);

    conclusionText = AI_conclusion_text(clinicalResult, eyeResult);
    AI_add_textbox(fig, [0.035, 0.055, 0.93, 0.105], conclusionText, 10.5, 'normal', fontName);

    annotation(fig, 'line', [0.035, 0.965], [0.815, 0.815], 'Color', [0.35, 0.35, 0.35]);
    annotation(fig, 'line', [0.755, 0.755], [0.17, 0.805], 'Color', [0.35, 0.35, 0.35]);
    annotation(fig, 'line', [0.035, 0.965], [0.17, 0.17], 'Color', [0.35, 0.35, 0.35]);

    exportgraphics(fig, settings.reportPng, 'Resolution', 300);
    exportgraphics(fig, settings.reportPdf, 'ContentType', 'vector');
    close(fig);

    reportFiles = struct('png', settings.reportPng, 'pdf', settings.reportPdf);
end

function AI_add_report_image(fig, imageFile, pos)
    ax = axes(fig, 'Position', pos);
    img = imread(imageFile);
    image(ax, img);
    axis(ax, 'image');
    axis(ax, 'off');
end

function AI_add_textbox(fig, pos, txt, fontSize, fontWeight, fontName)
    annotation(fig, 'textbox', pos, ...
        'String', txt, ...
        'FitBoxToText', 'off', ...
        'EdgeColor', 'none', ...
        'Interpreter', 'none', ...
        'FontName', fontName, ...
        'FontSize', fontSize, ...
        'FontWeight', fontWeight, ...
        'VerticalAlignment', 'top');
end

function txt = AI_patient_info_text(patientInfo, settings)
    txt = sprintf(['患者编号：%s    姓名：%s    性别：%s    年龄：%s\n', ...
        '检查日期：%s    临床诊断：%s    检查人员：%s\n', ...
        '数据文件夹：%s\n备注：%s'], ...
        AI_get_info(patientInfo, 'patientId'), AI_get_info(patientInfo, 'name'), ...
        AI_get_info(patientInfo, 'sex'), AI_get_info(patientInfo, 'age'), ...
        AI_get_info(patientInfo, 'examDate'), AI_get_info(patientInfo, 'diagnosis'), ...
        AI_get_info(patientInfo, 'operator'), settings.dataDir, ...
        AI_get_info(patientInfo, 'notes'));
end

function value = AI_get_info(patientInfo, key)
    if isfield(patientInfo, key)
        value = patientInfo.(key);
    else
        value = 'None';
    end
end

function txt = AI_metric_text(titleText, metrics)
    txt = sprintf(['%s\n', ...
        '判断：%s\n', ...
        'VFI：%.4f %%\n', ...
        'MD：%.4f    PSD：%.4f\n', ...
        '正常点：%d    可疑点：%d    缺损点：%d'], ...
        titleText, metrics.judgement, metrics.VFI, metrics.MD, metrics.PSD, ...
        metrics.nNormal, metrics.nSuspect, metrics.nDefect);
end

function txt = AI_conclusion_text(clinicalResult, eyeResult)
    overall = AI_overall_values(clinicalResult.overallTable);
    txt = sprintf(['结构化结论\n', ...
        '总体判断：%s    左眼判断：%s    右眼判断：%s\n', ...
        '说明：本报告基于个体校准DCPM模板匹配方法生成，VFI/MD/PSD为SAP-like客观视野指标，不等同于Humphrey SAP的dB阈值。'], ...
        eyeResult.overallJudgement, eyeResult.leftMetrics.judgement, ...
        eyeResult.rightMetrics.judgement);
        
        
     % '判断标准：VFI > 95 为视野正常，70 <= VFI <= 95 为可疑异常，VFI < 70 为视野异常。\n', ...
        % 'OverallReport：meanVFI=%.4f, meanVFI_loss=%.4f, meanMD_loss=%.4f, meanPSD=%.4f, meanDefectBurden=%.4f\n', ...
end

function values = AI_overall_values(overallTable)
    values = struct('meanVFI', nan, 'meanVFI_loss', nan, ...
        'meanMD_loss', nan, 'meanPSD', nan, 'meanDefectBurden', nan);
    for i = 1:height(overallTable)
        key = char(overallTable.overallMetric(i));
        if isfield(values, key)
            values.(key) = overallTable.overallValue(i);
        end
    end
end

function AI_write_report_tables(clinicalResult, eyeResult, settings)
    writetable(clinicalResult.pointTable, settings.excelFile, 'Sheet', 'PointResults');
    writetable(clinicalResult.groupTable, settings.excelFile, 'Sheet', 'GroupSummary');
    writetable(clinicalResult.overallTable, settings.excelFile, 'Sheet', 'OverallReport');
    writetable(eyeResult.eyeMetricTable, settings.excelFile, 'Sheet', 'EyeMetrics');
    writetable(eyeResult.pointSensitivityTable, settings.excelFile, 'Sheet', 'PointSensitivity');
end

function result = AI_three_class_indices(pointProb)
    [~, pointNum] = size(pointProb);
    epsVal = 1e-12;
    pointProb = max(pointProb, epsVal);
    pointProb = pointProb ./ sum(pointProb, 1);

    pointWeights = ones(1, pointNum) ./ pointNum;
    pNormal = pointProb(1, :);
    pLeft = pointProb(2, :);
    pRight = pointProb(3, :);
    pDefect = pLeft + pRight;
    pointMDValue = log((pNormal + epsVal) ./ (pDefect + epsVal));
    MD = sum(pointWeights .* pointMDValue);

    result = struct();
    result.VFI = 100 * sum(pointWeights .* pNormal);
    result.MD = MD;
    result.MD_loss = -MD;
    result.PSD = sqrt(sum(pointWeights .* (pointMDValue - MD).^2));
    result.LEI = 100 * sum(pointWeights .* pLeft);
    result.REI = 100 * sum(pointWeights .* pRight);
    result.defectBurden = 100 * sum(pointWeights .* pDefect);
end

function names = AI_point_table_names()
    names = {'group', 'point', 'globalPoint', 'trainEventType', 'testEventType', ...
        'predictedLabel', 'predictedState', 'pNormal', 'pLeftAbnormal', ...
        'pRightAbnormal', 'pDefect'};
end

function names = AI_group_table_names()
    names = {'group', 'trainFile', 'testFile', 'trainTrials', 'testTrials', ...
        'predictedPattern', 'VFI', 'VFI_loss', 'MD_loss', 'PSD', ...
        'LEI', 'REI', 'defectBurden'};
end

function overallTable = AI_build_overall_table(groupTable)
    overallMetric = { ...
        'meanVFI'; ...
        'meanVFI_loss'; ...
        'meanMD_loss'; ...
        'meanPSD'; ...
        'meanLEI'; ...
        'meanREI'; ...
        'meanDefectBurden'};
    overallValue = [ ...
        mean(groupTable.VFI, 'omitnan'); ...
        mean(groupTable.VFI_loss, 'omitnan'); ...
        mean(groupTable.MD_loss, 'omitnan'); ...
        mean(groupTable.PSD, 'omitnan'); ...
        mean(groupTable.LEI, 'omitnan'); ...
        mean(groupTable.REI, 'omitnan'); ...
        mean(groupTable.defectBurden, 'omitnan')];
    overallValue = arrayfun(@AI_round4, overallValue);
    overallTable = table(overallMetric, overallValue);
end

function labelName = AI_label_name(labelValue)
    switch labelValue
        case 1
            labelName = 'normal';
        case 2
            labelName = 'left_abnormal';
        case 3
            labelName = 'right_abnormal';
        otherwise
            labelName = 'unknown';
    end
end

function patternText = AI_pattern_string(labelVec)
    parts = cell(1, numel(labelVec));
    for i = 1:numel(labelVec)
        parts{i} = sprintf('P%d=%s', i, AI_label_name(labelVec(i)));
    end
    patternText = strjoin(parts, '; ');
end

function value = AI_round4(value)
    value = round(value .* 10000) ./ 10000;
end
