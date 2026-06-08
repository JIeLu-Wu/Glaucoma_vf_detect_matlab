function result = AI_clinical_260520xkx_report()
% 临床数据分析脚本
%AI_CLINICAL_260520XKX_REPORT Process clinical train/test CNT pairs.
%
% The script follows the current probmean_block logic:
%   1) DCPM matching for each point.
%   2) 4-trial averaging inside glc_detection_prob.
%   3) 5-column block averaging of Prob_dv.
%   4) point-level state = max(mean(blockProb, 2)).
%   5) VFI/MD_loss/PSD/LEI/REI from point-level probabilities.

    settings = AI_clinical_settings();
    if ~exist(settings.outputDir, 'dir')
        mkdir(settings.outputDir);
    end

    pointRows = {};
    groupRows = {};
    result.group = cell(settings.groupNum, 1);

    thresholds = AI_load_probmean_thresholds(settings.thresholdFile);

    for group_i = 1:settings.groupNum
        fprintf('\n==== Clinical group %d/%d ====\n', group_i, settings.groupNum);
        groupResult = AI_process_one_group(group_i, settings, thresholds);
        result.group{group_i} = groupResult;

        pointRows = [pointRows; groupResult.pointRows]; %#ok<AGROW>
        groupRows = [groupRows; groupResult.groupRows]; %#ok<AGROW>
    end

    pointTable = cell2table(pointRows, 'VariableNames', AI_point_table_names());
    groupTable = cell2table(groupRows, 'VariableNames', AI_group_table_names());
    overallTable = AI_build_overall_table(groupTable);

    writetable(pointTable, settings.excelFile, 'Sheet', 'PointResults');
    writetable(groupTable, settings.excelFile, 'Sheet', 'GroupSummary');
    writetable(overallTable, settings.excelFile, 'Sheet', 'OverallReport');

    AI_write_text_report(settings.textFile, groupTable, overallTable);

    result.pointTable = pointTable;
    result.groupTable = groupTable;
    result.overallTable = overallTable;
    result.settings = settings;
    result.thresholds = thresholds;

    save(settings.matFile, 'result', '-v7.3');

    fprintf('\nSaved clinical Excel report: %s\n', settings.excelFile);
    fprintf('Saved clinical text report: %s\n', settings.textFile);
    fprintf('Saved clinical MAT result: %s\n', settings.matFile);
end

function settings = AI_clinical_settings()
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
    settings.groupNum = 7;

    settings.tempType = [1,2; 2,1; 3,4; 4,3];
    settings.expectedLabel = [ ...
        1,1,1,1; ...
        1,1,1,1; ...
        2,2,2,2; ...
        1,2,2,1; ...
        2,2,2,1; ...
        1,1,1,1; ...
        0,0,0,0];

    settings.dataDir = char([68 58 92 48 35838 39064 92 38738 20809 30524 ...
        92 100 97 116 97 92 20020 24202 23454 39564 92 50 54 48 53 50 48 120 107 120]);
    settings.resultDir = char([68 58 92 48 35838 39064 92 38738 20809 30524 ...
        92 32467 26524]);
    settings.outputDir = fullfile(settings.resultDir, 'AI_clinical_260520xkx');
    settings.excelFile = fullfile(settings.outputDir, 'AI_clinical_260520xkx_report.xlsx');
    settings.textFile = fullfile(settings.outputDir, 'AI_clinical_260520xkx_report.txt');
    settings.matFile = fullfile(settings.outputDir, 'AI_clinical_260520xkx_result.mat');
    settings.thresholdFile = fullfile(settings.resultDir, ...
        char([27169 25311 35270 37326 26816 27979 82 79 67]), ...
        'AI_ROC_thresholds.xlsx');
end

function groupResult = AI_process_one_group(group_i, settings, thresholds)
    trainFile = fullfile(settings.dataDir, ['train', num2str(group_i), '.cnt']);
    testFile = fullfile(settings.dataDir, ['test', num2str(group_i), '.cnt']);

    [trainData, typeAllTrain] = AI_load_cnt(trainFile, settings, settings.trainTrialTotal);
    [testData, typeAllTest] = AI_load_cnt(testFile, settings, settings.testTrialTotal);

    pointNum = numel(typeAllTrain);
    if pointNum ~= 4 || numel(typeAllTest) ~= 4
        warning('Group %d has %d train types and %d test types.', ...
            group_i, pointNum, numel(typeAllTest));
    end

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

    vfIndex = AI_dcpm_vf_indices_from_point_prob(pointProb);
    expected = settings.expectedLabel(group_i, 1:pointNum);

    knownIdx = expected > 0;
    if any(knownIdx)
        accKnown3Class = mean(pointLabel(knownIdx) == expected(knownIdx));
    else
        accKnown3Class = nan;
    end
    accAllIncludingZero = mean(pointLabel == expected);

    vfiLoss = 100 - vfIndex.VFI;
    singleVfiPositive = AI_threshold_positive(vfiLoss, thresholds.singleVfiLoss);
    multiVfiPositive = AI_threshold_positive(vfiLoss, thresholds.multiVfiLoss);
    singleMdPositive = AI_threshold_positive(vfIndex.MD_loss, thresholds.singleMdLoss);
    multiMdPositive = AI_threshold_positive(vfIndex.MD_loss, thresholds.multiMdLoss);

    pointRows = cell(pointNum, numel(AI_point_table_names()));
    for point_i = 1:pointNum
        pointRows(point_i, :) = { ...
            group_i, point_i, typeAllTrain(point_i), typeAllTest(point_i), ...
            expected(point_i), AI_label_name(expected(point_i)), ...
            pointLabel(point_i), AI_label_name(pointLabel(point_i)), ...
            AI_round4(pointProb(1, point_i)), AI_round4(pointProb(2, point_i)), ...
            AI_round4(pointProb(3, point_i)), AI_round4(1 - pointProb(1, point_i)), ...
            AI_point_correct(pointLabel(point_i), expected(point_i))};
    end

    groupRows = { ...
        group_i, trainFile, testFile, settings.trainTrialNum, settings.testTrialNum, ...
        AI_pattern_string(expected), AI_pattern_string(pointLabel), ...
        AI_round4(accKnown3Class), AI_round4(accAllIncludingZero), sum(knownIdx), pointNum, ...
        AI_round4(vfIndex.VFI), AI_round4(vfiLoss), AI_round4(vfIndex.MD_loss), ...
        AI_round4(vfIndex.PSD), AI_round4(vfIndex.LEI), AI_round4(vfIndex.REI), ...
        AI_round4(vfIndex.defectBurden), ...
        AI_round4(thresholds.singleVfiLoss), singleVfiPositive, ...
        AI_round4(thresholds.multiVfiLoss), multiVfiPositive, ...
        AI_round4(thresholds.singleMdLoss), singleMdPositive, ...
        AI_round4(thresholds.multiMdLoss), multiMdPositive};

    groupResult = struct();
    groupResult.group = group_i;
    groupResult.trainFile = trainFile;
    groupResult.testFile = testFile;
    groupResult.probDvAll = probDvAll;
    groupResult.blockProbAll = blockProbAll;
    groupResult.pointProb = pointProb;
    groupResult.pointLabel = pointLabel;
    groupResult.expectedLabel = expected;
    groupResult.vfIndex = vfIndex;
    groupResult.accKnown3Class = accKnown3Class;
    groupResult.accAllIncludingZero = accAllIncludingZero;
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

function result = AI_dcpm_vf_indices_from_point_prob(pointProb)
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
    result.pointProb = pointProb;
    [~, result.pointLabel] = max(pointProb, [], 1);
    result.pointNormal = pNormal;
    result.pointLeft = pLeft;
    result.pointRight = pRight;
    result.pointDefect = pDefect;
    result.pointMDValue = pointMDValue;
    result.VFI = 100 * sum(pointWeights .* pNormal);
    result.MD = MD;
    result.MD_loss = -MD;
    result.PSD = sqrt(sum(pointWeights .* (pointMDValue - MD).^2));
    result.LEI = 100 * sum(pointWeights .* pLeft);
    result.REI = 100 * sum(pointWeights .* pRight);
    result.defectBurden = 100 * sum(pointWeights .* pDefect);
end

function thresholds = AI_load_probmean_thresholds(thresholdFile)
    thresholds = struct('singleVfiLoss', nan, 'multiVfiLoss', nan, ...
        'singleMdLoss', nan, 'multiMdLoss', nan);
    if ~exist(thresholdFile, 'file')
        warning('Threshold file not found: %s', thresholdFile);
        return;
    end

    try
        thresholdTable = readtable(thresholdFile, 'Sheet', 'probmean_block');
    catch
        warning('Could not read probmean_block threshold sheet: %s', thresholdFile);
        return;
    end

    thresholds.singleVfiLoss = AI_find_threshold(thresholdTable, 'normal_vs_single', 'VFI_loss');
    thresholds.multiVfiLoss = AI_find_threshold(thresholdTable, 'normal_vs_multi', 'VFI_loss');
    thresholds.singleMdLoss = AI_find_threshold(thresholdTable, 'normal_vs_single', 'MD_loss');
    thresholds.multiMdLoss = AI_find_threshold(thresholdTable, 'normal_vs_multi', 'MD_loss');
end

function threshold = AI_find_threshold(thresholdTable, comparisonName, metricName)
    idx = strcmp(thresholdTable.comparison, comparisonName) & strcmp(thresholdTable.metric, metricName);
    if any(idx)
        threshold = thresholdTable.threshold(find(idx, 1));
    else
        threshold = nan;
    end
end

function isPositive = AI_threshold_positive(scoreValue, threshold)
    if isnan(threshold)
        isPositive = nan;
    else
        isPositive = scoreValue >= threshold;
    end
end

function names = AI_point_table_names()
    names = {'group', 'point', 'trainEventType', 'testEventType', ...
        'expectedLabel', 'expectedState', 'predictedLabel', 'predictedState', ...
        'pNormal', 'pLeftAbnormal', 'pRightAbnormal', 'pDefect', 'correctKnown'};
end

function names = AI_group_table_names()
    names = {'group', 'trainFile', 'testFile', 'trainTrials', 'testTrials', ...
        'expectedPattern', 'predictedPattern', 'accKnown3Class', ...
        'accAllIncludingZero', 'nKnownPoints', 'nTotalPoints', ...
        'VFI', 'VFI_loss', 'MD_loss', 'PSD', 'LEI', 'REI', 'defectBurden', ...
        'singleVfiThreshold', 'singleVfiPositive', ...
        'multiVfiThreshold', 'multiVfiPositive', ...
        'singleMdThreshold', 'singleMdPositive', ...
        'multiMdThreshold', 'multiMdPositive'};
end

function overallTable = AI_build_overall_table(groupTable)
    accKnown = groupTable.accKnown3Class;
    overallMetric = { ...
        'meanAccKnown3Class'; ...
        'meanAccAllIncludingZero'; ...
        'meanVFI'; ...
        'meanVFI_loss'; ...
        'meanMD_loss'; ...
        'meanPSD'; ...
        'meanLEI'; ...
        'meanREI'; ...
        'meanDefectBurden'};
    overallValue = [ ...
        mean(accKnown(~isnan(accKnown)), 'omitnan'); ...
        mean(groupTable.accAllIncludingZero, 'omitnan'); ...
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

function AI_write_text_report(textFile, groupTable, overallTable)
    fid = fopen(textFile, 'w');
    if fid < 0
        warning('Could not write text report: %s', textFile);
        return;
    end

    fprintf(fid, 'AI clinical visual-field report: 260520xkx\n');
    fprintf(fid, 'Generated by AI_clinical_260520xkx_report.m\n\n');
    fprintf(fid, 'Overall summary\n');
    for i = 1:height(overallTable)
        fprintf(fid, '  %s: %.4f\n', overallTable.overallMetric{i}, overallTable.overallValue(i));
    end
    fprintf(fid, '\nGroup summary\n');
    for i = 1:height(groupTable)
        fprintf(fid, 'Group %d\n', groupTable.group(i));
        fprintf(fid, '  expected:  %s\n', groupTable.expectedPattern{i});
        fprintf(fid, '  predicted: %s\n', groupTable.predictedPattern{i});
        fprintf(fid, '  accKnown3Class: %.4f, VFI: %.4f, MD_loss: %.4f, PSD: %.4f\n', ...
            groupTable.accKnown3Class(i), groupTable.VFI(i), groupTable.MD_loss(i), groupTable.PSD(i));
        fprintf(fid, '  LEI: %.4f, REI: %.4f, defectBurden: %.4f\n', ...
            groupTable.LEI(i), groupTable.REI(i), groupTable.defectBurden(i));
        fprintf(fid, '  VFI threshold flags: single=%s, multi=%s\n\n', ...
            AI_flag_string(groupTable.singleVfiPositive(i)), AI_flag_string(groupTable.multiVfiPositive(i)));
    end
    fclose(fid);
end

function labelName = AI_label_name(labelValue)
    switch labelValue
        case 0
            labelName = 'outside_model';
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

function pattern = AI_pattern_string(labels)
    parts = cell(1, numel(labels));
    for i = 1:numel(labels)
        parts{i} = sprintf('P%d=%s', i, AI_label_name(labels(i)));
    end
    pattern = strjoin(parts, '; ');
end

function correctValue = AI_point_correct(predictedLabel, expectedLabel)
    if expectedLabel <= 0
        correctValue = nan;
    else
        correctValue = predictedLabel == expectedLabel;
    end
end

function flag = AI_flag_string(value)
    if isnan(value)
        flag = 'NA';
    elseif value
        flag = 'positive';
    else
        flag = 'negative';
    end
end

function value = AI_round4(value)
    value = round(value * 10000) / 10000;
end
