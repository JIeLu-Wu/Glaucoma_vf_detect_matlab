function results = AI_qikan_acc_all_probmean()
% 跑结果并计算VFI等指标，将所有概率系数叠加
% AI_QIKAN_ACC_ALL_PROBMEAN Run five simulations with block-mean VF indices.
%
% This file does not modify the original qikan_acc_for_*.m files. It keeps
% the original calculation flow, but puts the five conditions into one
% configurable loop.

    settings = AI_default_settings();
    scenarios = AI_scenario_configs();

    results = struct();
    for scenario_i = 1:numel(scenarios)
        cfg = scenarios(scenario_i);
        fprintf('\n==== Running %s ====\n', cfg.name);
        results.(cfg.name) = AI_run_one_scenario(cfg, settings);
    end

    AI_save_outputs(results, settings, scenarios);
end

function settings = AI_default_settings()
    settings.fs = 250;
    settings.tStart = 0;
    settings.tEnd = 0.45;
    settings.WnPara = [0.5, 2, 20, 30];
    settings.chanList = 44:64;

    settings.trainTrialNumList = 80;
    settings.testTrialNumList = 60;
    settings.foldNumList = 4;

    settings.effectiveN = 15;
    settings.probMeanBlockSize = 5;
    settings.topN = 24;
    settings.scriptDir = fileparts(mfilename('fullpath'));
    settings.projectDir = fileparts(settings.scriptDir);
    settings.excelOutputDir = fullfile(settings.projectDir, char([32467 26524]));
    settings.excelOutputFile = fullfile(settings.excelOutputDir, 'AI_qikan_acc_indices_probmean.xlsx');
    settings.matOutputFile = fullfile(settings.scriptDir, 'AI_qikan_acc_all_probmean_results.mat');
    settings.subList = [1,1,1,1,1,2,2,2,2,2,3,3,3,3,3,4,4,4,4,4,5,5,5,5,5];
    settings.subNameList = {...
        'D:\0课题\青光眼\data\小论文数据\sub1\'; ...
        'D:\0课题\青光眼\data\小论文数据\sub2\'; ...
        'D:\0课题\青光眼\data\小论文数据\sub3\'; ...
        'D:\0课题\青光眼\data\小论文数据\sub4\'; ...
        'D:\0课题\青光眼\data\小论文数据\sub5\'; ...
        'D:\0课题\青光眼\data\小论文数据\sub6\'; ...
        'D:\0课题\青光眼\data\小论文数据\sub7\'; ...
        'D:\0课题\青光眼\data\小论文数据\sub8\'; ...
        'D:\0课题\青光眼\data\小论文数据\sub9\'; ...
        'D:\0课题\青光眼\data\小论文数据\sub10\'; ...
        'D:\0课题\青光眼\data\小论文数据\sub11\'; ...
        'D:\0课题\青光眼\data\小论文数据\sub12\'; ...
        'D:\0课题\青光眼\data\小论文数据\sub13\'; ...
        'D:\0课题\青光眼\data\小论文数据\sub14\'; ...
        'D:\0课题\青光眼\data\小论文数据\sub15\'; ...
        'D:\0课题\青光眼\data\小论文数据\sub16\'; ...
        'D:\0课题\青光眼\data\小论文数据\250ms\sub1\'; ...
        'D:\0课题\青光眼\data\小论文数据\250ms\sub2\'; ...
        'D:\0课题\青光眼\data\小论文数据\250ms\sub3\'; ...
        'D:\0课题\青光眼\data\小论文数据\250ms\sub4\'; ...
        'D:\0课题\青光眼\data\小论文数据\250ms\sub5\'; ...
        'D:\0课题\青光眼\data\小论文数据\250ms\sub6\'; ...
        'D:\0课题\青光眼\data\小论文数据\250ms\sub7\'; ...
        'D:\0课题\青光眼\data\小论文数据\250ms\sub8\'; ...
        };
end

function scenarios = AI_scenario_configs()
    baseTempType = [1,2; 2,1; 3,4; 4,3];

    scenarios(1) = struct( ...
        'name', 'normal', ...
        'trainFileType', '3-1', ...
        'testFileType', '4-1', ...
        'bsFileType', '', ...
        'useMixedTemplate', false, ...
        'swapMode', 'if_subject_R', ...
        'expectedLabel', 1, ...
        'subStart', 1, ...
        'tempType', baseTempType);

    scenarios(2) = struct( ...
        'name', 'left_single', ...
        'trainFileType', '1-1', ...
        'testFileType', '1-2', ...
        'bsFileType', '3-1', ...
        'useMixedTemplate', true, ...
        'swapMode', 'if_subject_R', ...
        'expectedLabel', 2, ...
        'subStart', 1, ...
        'tempType', baseTempType);

    scenarios(3) = struct( ...
        'name', 'left_multi', ...
        'trainFileType', '1-1', ...
        'testFileType', '1-2', ...
        'bsFileType', '', ...
        'useMixedTemplate', false, ...
        'swapMode', 'if_subject_R', ...
        'expectedLabel', 2, ...
        'subStart', 1, ...
        'tempType', baseTempType);

    scenarios(4) = struct( ...
        'name', 'right_single', ...
        'trainFileType', '2-1', ...
        'testFileType', '2-2', ...
        'bsFileType', '3-1', ...
        'useMixedTemplate', true, ...
        'swapMode', 'always', ...
        'expectedLabel', 3, ...
        'subStart', 1, ...
        'tempType', baseTempType);

    scenarios(5) = struct( ...
        'name', 'right_multi', ...
        'trainFileType', '2-1', ...
        'testFileType', '2-2', ...
        'bsFileType', '', ...
        'useMixedTemplate', false, ...
        'swapMode', 'always', ...
        'expectedLabel', 3, ...
        'subStart', 1, ...
        'tempType', baseTempType);

    
end

function scenarioResult = AI_run_one_scenario(cfg, settings)
    subNameList = settings.subNameList;
    subCount = numel(subNameList);
    subRange = cfg.subStart:subCount;

    nTrain = numel(settings.trainTrialNumList);
    nTest = numel(settings.testTrialNumList);
    nFold = numel(settings.foldNumList);

    accLegacy = nan(nTrain, nTest, nFold, subCount);
    accBlockMean = nan(nTrain, nTest, nFold, subCount);
    probMeanAll = cell(nTrain, nTest, nFold, subCount);
    probBlockMeanAll = cell(nTrain, nTest, nFold, subCount);
    vfIndexAll = cell(nTrain, nTest, nFold, subCount);

    for sub_i = subRange
        subName = subNameList{sub_i};
        fprintf('Subject %d/%d: %s\n', sub_i, subCount, subName);

        [trainDataAll, typeAllNormal] = AI_load_data(subName, cfg.trainFileType, settings);
        if cfg.useMixedTemplate
            [bsDataAll, ~] = AI_load_data(subName, cfg.bsFileType, settings);
        else
            bsDataAll = [];
        end
        [testDataAll, ~] = AI_load_data(subName, cfg.testFileType, settings);

        for train_i = 1:nTrain
            trainTrialNum = settings.trainTrialNumList(train_i);
            AI_check_trial_num(trainDataAll, trainTrialNum, 'training data');
            if cfg.useMixedTemplate
                AI_check_trial_num(bsDataAll, trainTrialNum, 'BS template data');
            end

            trainData = trainDataAll(:, :, 1:trainTrialNum, :);
            if cfg.useMixedTemplate
                bsData = bsDataAll(:, :, 1:trainTrialNum, :);
            else
                bsData = [];
            end

            for test_i = 1:nTest
                testTrialNum = settings.testTrialNumList(test_i);
                AI_check_trial_num(testDataAll, testTrialNum, 'test data');

                for fold_i = 1:nFold
                    foldNum = settings.foldNumList(fold_i);
                    [probMean, probBlockMean, labelLegacy, labelBlockMean, vfIndex] = ...
                        AI_detect_all_points(cfg, settings, trainData, bsData, ...
                        testDataAll, typeAllNormal, testTrialNum, foldNum, subName);

                    accLegacy(train_i, test_i, fold_i, sub_i) = ...
                        mean(labelLegacy == cfg.expectedLabel);
                    accBlockMean(train_i, test_i, fold_i, sub_i) = ...
                        mean(labelBlockMean == cfg.expectedLabel);

                    probMeanAll{train_i, test_i, fold_i, sub_i} = probMean;
                    probBlockMeanAll{train_i, test_i, fold_i, sub_i} = probBlockMean;
                    vfIndexAll{train_i, test_i, fold_i, sub_i} = vfIndex;

                    fprintf('  train=%d, test=%d, fold=%d, acc_mean=%.3f, acc_block=%.3f\n', ...
                        trainTrialNum, testTrialNum, foldNum, ...
                        accLegacy(train_i, test_i, fold_i, sub_i), ...
                        accBlockMean(train_i, test_i, fold_i, sub_i));
                end
            end
        end
    end

    scenarioResult = struct();
    scenarioResult.config = cfg;
    scenarioResult.accLegacy = accLegacy;
    scenarioResult.accBlockMean = accBlockMean;
    scenarioResult.probMeanAll = probMeanAll;
    scenarioResult.probBlockMeanAll = probBlockMeanAll;
    scenarioResult.vfIndexAll = vfIndexAll;
    scenarioResult.topMeanAccLegacy = AI_top_mean_acc(accLegacy, settings.topN);
    scenarioResult.topMeanAccBlockMean = AI_top_mean_acc(accBlockMean, settings.topN);
end

function AI_save_outputs(results, settings, scenarios)
    if ~exist(settings.excelOutputDir, 'dir')
        mkdir(settings.excelOutputDir);
    end

    for scenario_i = 1:numel(scenarios)
        cfg = scenarios(scenario_i);
        summaryTable = AI_build_summary_table(results, settings, cfg);
        writetable(summaryTable, settings.excelOutputFile, 'Sheet', cfg.name);
    end

    [rocAucTable, rocPointTable] = AI_build_roc_tables(results, settings);
    writetable(rocAucTable, settings.excelOutputFile, 'Sheet', 'ROC_AUC');
    writetable(rocPointTable, settings.excelOutputFile, 'Sheet', 'ROC_points');

    probMeanAll = struct();
    probBlockMeanAll = struct();
    vfIndexAll = struct();

    for scenario_i = 1:numel(scenarios)
        scenarioName = scenarios(scenario_i).name;
        probMeanAll.(scenarioName) = results.(scenarioName).probMeanAll;
        probBlockMeanAll.(scenarioName) = results.(scenarioName).probBlockMeanAll;
        vfIndexAll.(scenarioName) = results.(scenarioName).vfIndexAll;
    end

    save(settings.matOutputFile, 'probMeanAll', 'probBlockMeanAll', ...
        'vfIndexAll', 'rocAucTable', 'rocPointTable', ...
        'results', 'settings', '-v7.3');

    fprintf('\nSaved Excel summary: %s\n', settings.excelOutputFile);
    fprintf('Saved final MAT results: %s\n', settings.matOutputFile);
end

function summaryTable = AI_build_summary_table(results, settings, scenarios)
    maxRowNum = numel(scenarios) * numel(settings.trainTrialNumList) * ...
        numel(settings.testTrialNumList) * numel(settings.foldNumList) * ...
        numel(settings.subNameList);
    row_i = 0;

    subjectIndex = nan(maxRowNum, 1);
    subjectCode = nan(maxRowNum, 1);
    subjectPath = cell(maxRowNum, 1);
    scenarioName = cell(maxRowNum, 1);
    expectedLabel = nan(maxRowNum, 1);
    expectedState = cell(maxRowNum, 1);
    trainTrials = nan(maxRowNum, 1);
    testTrials = nan(maxRowNum, 1);
    foldNum = nan(maxRowNum, 1);
    accLegacy = nan(maxRowNum, 1);
    accBlockMean = nan(maxRowNum, 1);
    VFI = nan(maxRowNum, 1);
    MD_loss = nan(maxRowNum, 1);
    PSD = nan(maxRowNum, 1);
    LEI = nan(maxRowNum, 1);
    REI = nan(maxRowNum, 1);

    for scenario_i = 1:numel(scenarios)
        cfg = scenarios(scenario_i);
        oneResult = results.(cfg.name);
        [nTrain, nTest, nFold, nSub] = size(oneResult.accLegacy);

        for train_i = 1:nTrain
            for test_i = 1:nTest
                for fold_i = 1:nFold
                    for sub_i = 1:nSub
                        vfIndex = oneResult.vfIndexAll{train_i, test_i, fold_i, sub_i};
                        if isempty(vfIndex)
                            continue;
                        end

                        row_i = row_i + 1;
                        subjectIndex(row_i) = sub_i;
                        subjectCode(row_i) = settings.subList(sub_i);
                        subjectPath{row_i} = settings.subNameList{sub_i};
                        scenarioName{row_i} = cfg.name;
                        expectedLabel(row_i) = cfg.expectedLabel;
                        expectedState{row_i} = AI_label_name(cfg.expectedLabel);
                        trainTrials(row_i) = settings.trainTrialNumList(train_i);
                        testTrials(row_i) = settings.testTrialNumList(test_i);
                        foldNum(row_i) = settings.foldNumList(fold_i);

                        accLegacy(row_i) = AI_round4(oneResult.accLegacy(train_i, test_i, fold_i, sub_i));
                        accBlockMean(row_i) = AI_round4(oneResult.accBlockMean(train_i, test_i, fold_i, sub_i));
                        VFI(row_i) = AI_round4(vfIndex.VFI);
                        MD_loss(row_i) = AI_round4(vfIndex.MD_loss);
                        PSD(row_i) = AI_round4(vfIndex.PSD);
                        LEI(row_i) = AI_round4(vfIndex.LEI);
                        REI(row_i) = AI_round4(vfIndex.REI);
                    end
                end
            end
        end
    end

    subjectIndex = subjectIndex(1:row_i);
    subjectCode = subjectCode(1:row_i);
    subjectPath = subjectPath(1:row_i);
    scenarioName = scenarioName(1:row_i);
    expectedLabel = expectedLabel(1:row_i);
    expectedState = expectedState(1:row_i);
    trainTrials = trainTrials(1:row_i);
    testTrials = testTrials(1:row_i);
    foldNum = foldNum(1:row_i);
    accLegacy = accLegacy(1:row_i);
    accBlockMean = accBlockMean(1:row_i);
    VFI = VFI(1:row_i);
    MD_loss = MD_loss(1:row_i);
    PSD = PSD(1:row_i);
    LEI = LEI(1:row_i);
    REI = REI(1:row_i);

    summaryTable = table(subjectIndex, subjectCode, subjectPath, ...
        scenarioName, expectedLabel, expectedState, trainTrials, ...
        testTrials, foldNum, accLegacy, accBlockMean, VFI, MD_loss, PSD, ...
        LEI, REI);
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

function value = AI_round4(value)
    value = round(value * 10000) / 10000;
end

function [probMean, probBlockMean, labelLegacy, labelBlockMean, vfIndex] = ...
    AI_detect_all_points(cfg, settings, trainData, bsData, testDataAll, ...
    typeAllNormal, testTrialNum, foldNum, subName)

    pointNum = length(typeAllNormal);
    probMean = zeros(3, pointNum);
    foldBlockNum = testTrialNum / foldNum;
    if foldBlockNum ~= floor(foldBlockNum)
        error('testTrialNum must be divisible by foldNum.');
    end
    secondBlockSize = settings.probMeanBlockSize;
    if foldBlockNum < secondBlockSize || mod(foldBlockNum, secondBlockSize) ~= 0
        error('testTrialNum / foldNum must be divisible by settings.probMeanBlockSize.');
    end
    secondBlockNum = foldBlockNum / secondBlockSize;
    probBlockMean = nan(3, secondBlockNum, pointNum);

    for point_i = 1:pointNum
        if cfg.tempType(point_i, 1) == 0
            probMean(:, point_i) = [0; 0; 0];
            probBlockMean(:, :, point_i) = 0;
            continue;
        end

        testTrials = testDataAll(settings.chanList, :, 1:testTrialNum, point_i);
        template = AI_make_template(cfg, settings, trainData, bsData, point_i);

        if AI_need_swap_template(cfg, subName)
            template = template(:, :, :, [2, 1]);
        end

        [~, probDv] = glc_detection_prob(template, testTrials, foldNum);
        probMean(:, point_i) = mean(probDv, 2);

        for block_i = 1:secondBlockNum
            blockIndex = (block_i - 1) * secondBlockSize + 1:block_i * secondBlockSize;
            blockProb = mean(probDv(:, blockIndex), 2);
            blockProb = blockProb ./ sum(blockProb);
            probBlockMean(:, block_i, point_i) = blockProb;
        end
    end

    probMean = squeeze(mean(probBlockMean, 2));
    [~, labelLegacy] = max(probMean, [], 1);
    labelBlockMean = labelLegacy;
    vfIndex = AI_dcpm_vf_indices_from_point_prob(probMean);
end

function template = AI_make_template(cfg, settings, trainData, bsData, point_i)
    chanList = settings.chanList;
    pair = cfg.tempType(point_i, :);

    if cfg.useMixedTemplate
        temp1 = trainData(chanList, :, :, pair(1));
        temp2 = bsData(chanList, :, :, pair(2));
        template = cat(4, temp1, temp2);
    else
        template = trainData(chanList, :, :, pair);
    end
end

function needSwap = AI_need_swap_template(cfg, subName)
    if strcmp(cfg.swapMode, 'always')
        needSwap = true;
    elseif strcmp(cfg.swapMode, 'if_subject_R')
        needSwap = AI_is_subject_R(subName);
    else
        needSwap = false;
    end
end

function isR = AI_is_subject_R(subName)
    isR = false;
    if numel(subName) >= 4
        isR = strcmp(subName(end - 3), 'R');
    end
end

function [dataAll, typeAll] = AI_load_data(subName, fileType, settings)
    fileName = [subName, fileType, '.cnt'];
    [~, dataSeg, typeAll] = EEGRead5(fileName, 1000, settings.fs, ...
        [settings.tStart, settings.tEnd], settings.WnPara, 400);
    dataAll = dataSeg(1:64, :, :, :);
end

function AI_check_trial_num(dataAll, trialNum, dataName)
    availableNum = size(dataAll, 3);
    if trialNum > availableNum
        error('%s has only %d trials, but %d trials were requested.', ...
            dataName, availableNum, trialNum);
    end
end

function topMeanAcc = AI_top_mean_acc(accAll, topN)
    [nTrain, nTest, nFold, ~] = size(accAll);
    topMeanAcc = nan(nTrain, nTest, nFold);

    for train_i = 1:nTrain
        for test_i = 1:nTest
            for fold_i = 1:nFold
                accSub = squeeze(accAll(train_i, test_i, fold_i, :));
                validIdx = find(~isnan(accSub));
                if isempty(validIdx)
                    continue;
                end

                [~, order] = sort(accSub(validIdx), 'descend');
                takeNum = min(topN, numel(order));
                topIdx = validIdx(order(1:takeNum));
                topMeanAcc(train_i, test_i, fold_i) = mean(accSub(topIdx), 'omitnan');
            end
        end
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
    result.pointLogScore = [];
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

function [rocAucTable, rocPointTable] = AI_build_roc_tables(results, settings)
    comparisons = AI_roc_comparisons();
    metricList = {'VFI_loss', 'MD_loss', 'EyeMax', 'ExpectedEye', 'LEI', 'REI'};

    maxAucRows = numel(comparisons) * numel(metricList) * ...
        numel(settings.trainTrialNumList) * numel(settings.testTrialNumList) * ...
        numel(settings.foldNumList);
    aucRow = 0;
    pointRow = 0;

    trainTrialsAuc = nan(maxAucRows, 1);
    testTrialsAuc = nan(maxAucRows, 1);
    foldNumAuc = nan(maxAucRows, 1);
    comparisonAuc = cell(maxAucRows, 1);
    metricAuc = cell(maxAucRows, 1);
    aucValue = nan(maxAucRows, 1);
    nNormal = nan(maxAucRows, 1);
    nDefect = nan(maxAucRows, 1);

    pointTrainTrials = [];
    pointTestTrials = [];
    pointFoldNum = [];
    pointComparison = {};
    pointMetric = {};
    pointThreshold = [];
    pointFPR = [];
    pointTPR = [];

    for train_i = 1:numel(settings.trainTrialNumList)
        for test_i = 1:numel(settings.testTrialNumList)
            for fold_i = 1:numel(settings.foldNumList)
                for cmp_i = 1:numel(comparisons)
                    cmp = comparisons(cmp_i);
                    for metric_i = 1:numel(metricList)
                        metricName = metricList{metric_i};
                        if ~AI_metric_allowed_for_comparison(metricName, cmp.name)
                            continue;
                        end

                        [labels, scores] = AI_collect_roc_samples( ...
                            results, cmp, metricName, train_i, test_i, fold_i);
                        if numel(unique(labels)) < 2
                            continue;
                        end

                        [auc, fpr, tpr, thresholds] = AI_roc_auc(labels, scores);
                        aucRow = aucRow + 1;
                        trainTrialsAuc(aucRow) = settings.trainTrialNumList(train_i);
                        testTrialsAuc(aucRow) = settings.testTrialNumList(test_i);
                        foldNumAuc(aucRow) = settings.foldNumList(fold_i);
                        comparisonAuc{aucRow} = cmp.name;
                        metricAuc{aucRow} = metricName;
                        aucValue(aucRow) = AI_round4(auc);
                        nNormal(aucRow) = sum(labels == 0);
                        nDefect(aucRow) = sum(labels == 1);

                        for point_i = 1:numel(fpr)
                            pointRow = pointRow + 1;
                            pointTrainTrials(pointRow, 1) = settings.trainTrialNumList(train_i);
                            pointTestTrials(pointRow, 1) = settings.testTrialNumList(test_i);
                            pointFoldNum(pointRow, 1) = settings.foldNumList(fold_i);
                            pointComparison{pointRow, 1} = cmp.name;
                            pointMetric{pointRow, 1} = metricName;
                            pointThreshold(pointRow, 1) = thresholds(point_i);
                            pointFPR(pointRow, 1) = fpr(point_i);
                            pointTPR(pointRow, 1) = tpr(point_i);
                        end
                    end
                end
            end
        end
    end

    trainTrialsAuc = trainTrialsAuc(1:aucRow);
    testTrialsAuc = testTrialsAuc(1:aucRow);
    foldNumAuc = foldNumAuc(1:aucRow);
    comparisonAuc = comparisonAuc(1:aucRow);
    metricAuc = metricAuc(1:aucRow);
    aucValue = aucValue(1:aucRow);
    nNormal = nNormal(1:aucRow);
    nDefect = nDefect(1:aucRow);

    rocAucTable = table(trainTrialsAuc, testTrialsAuc, foldNumAuc, ...
        comparisonAuc, metricAuc, aucValue, nNormal, nDefect);

    pointThreshold = AI_round4(pointThreshold);
    pointFPR = AI_round4(pointFPR);
    pointTPR = AI_round4(pointTPR);
    rocPointTable = table(pointTrainTrials, pointTestTrials, pointFoldNum, ...
        pointComparison, pointMetric, pointThreshold, pointFPR, pointTPR);
end

function comparisons = AI_roc_comparisons()
    comparisons(1) = struct('name', 'normal_vs_single', ...
        'defectScenarios', {{'left_single', 'right_single'}});
    comparisons(2) = struct('name', 'normal_vs_multi', ...
        'defectScenarios', {{'left_multi', 'right_multi'}});
    comparisons(3) = struct('name', 'normal_vs_left_single', ...
        'defectScenarios', {{'left_single'}});
    comparisons(4) = struct('name', 'normal_vs_right_single', ...
        'defectScenarios', {{'right_single'}});
    comparisons(5) = struct('name', 'normal_vs_left_multi', ...
        'defectScenarios', {{'left_multi'}});
    comparisons(6) = struct('name', 'normal_vs_right_multi', ...
        'defectScenarios', {{'right_multi'}});
end

function allowed = AI_metric_allowed_for_comparison(metricName, comparisonName)
    isLeft = contains(comparisonName, 'left');
    isRight = contains(comparisonName, 'right');
    isCombined = ~(isLeft || isRight);

    allowed = true;
    if strcmp(metricName, 'LEI')
        allowed = isLeft;
    elseif strcmp(metricName, 'REI')
        allowed = isRight;
    elseif strcmp(metricName, 'EyeMax') || strcmp(metricName, 'ExpectedEye')
        allowed = isCombined;
    end
end

function [labels, scores] = AI_collect_roc_samples(results, cmp, metricName, train_i, test_i, fold_i)
    labels = [];
    scores = [];

    [normalScores, normalLabels] = AI_collect_scenario_scores( ...
        results, 'normal', metricName, train_i, test_i, fold_i, 0);
    labels = [labels; normalLabels];
    scores = [scores; normalScores];

    for scenario_i = 1:numel(cmp.defectScenarios)
        scenarioName = cmp.defectScenarios{scenario_i};
        [defectScores, defectLabels] = AI_collect_scenario_scores( ...
            results, scenarioName, metricName, train_i, test_i, fold_i, 1);
        labels = [labels; defectLabels];
        scores = [scores; defectScores];
    end
end

function [scores, labels] = AI_collect_scenario_scores(results, scenarioName, metricName, train_i, test_i, fold_i, labelValue)
    vfIndexAll = results.(scenarioName).vfIndexAll;
    nSub = size(vfIndexAll, 4);
    scores = nan(nSub, 1);
    labels = labelValue * ones(nSub, 1);

    for sub_i = 1:nSub
        vfIndex = vfIndexAll{train_i, test_i, fold_i, sub_i};
        if isempty(vfIndex)
            continue;
        end
        scores(sub_i) = AI_roc_metric_score(vfIndex, metricName, scenarioName);
    end

    validIdx = ~isnan(scores);
    scores = scores(validIdx);
    labels = labels(validIdx);
end

function score = AI_roc_metric_score(vfIndex, metricName, scenarioName)
    switch metricName
        case 'VFI_loss'
            score = 100 - vfIndex.VFI;
        case 'MD_loss'
            score = vfIndex.MD_loss;
        case 'EyeMax'
            score = max(vfIndex.LEI, vfIndex.REI);
        case 'ExpectedEye'
            if contains(scenarioName, 'left')
                score = vfIndex.LEI;
            elseif contains(scenarioName, 'right')
                score = vfIndex.REI;
            else
                score = max(vfIndex.LEI, vfIndex.REI);
            end
        case 'LEI'
            score = vfIndex.LEI;
        case 'REI'
            score = vfIndex.REI;
        otherwise
            error('Unknown ROC metric: %s', metricName);
    end
end

function [auc, fpr, tpr, thresholds] = AI_roc_auc(labels, scores)
    labels = labels(:);
    scores = scores(:);
    validIdx = ~isnan(labels) & ~isnan(scores);
    labels = labels(validIdx);
    scores = scores(validIdx);

    posNum = sum(labels == 1);
    negNum = sum(labels == 0);
    if posNum == 0 || negNum == 0
        auc = nan;
        fpr = nan;
        tpr = nan;
        thresholds = nan;
        return;
    end

    thresholds = unique(scores, 'sorted');
    thresholds = flipud(thresholds(:));
    thresholds = [inf; thresholds; -inf];
    tpr = zeros(numel(thresholds), 1);
    fpr = zeros(numel(thresholds), 1);

    for threshold_i = 1:numel(thresholds)
        predictPositive = scores >= thresholds(threshold_i);
        tpr(threshold_i) = sum(predictPositive & labels == 1) / posNum;
        fpr(threshold_i) = sum(predictPositive & labels == 0) / negNum;
    end

    [fpr, order] = sort(fpr);
    tpr = tpr(order);
    thresholds = thresholds(order);
    auc = trapz(fpr, tpr);
end
