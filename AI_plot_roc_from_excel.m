function AI_plot_roc_from_excel()
%AI_PLOT_ROC_FROM_EXCEL Plot ROC curves from saved AI_qikan_acc Excel files.
% 绘制ROC曲线图
    resultDir = fullfile('D:\0课题\青光眼', char([32467 26524]));
    outputDir = fullfile(resultDir, char([27169 25311 35270 37326 26816 27979 82 79 67]));
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    excelFiles = { ...
        fullfile(resultDir, 'AI_qikan_acc_indices.xlsx'), ...
        fullfile(resultDir, 'AI_qikan_acc_indices_probmean.xlsx') ...
        };
    methodNames = {'geomean_logscore', 'probmean_block'};

    for file_i = 1:numel(excelFiles)
        if ~exist(excelFiles{file_i}, 'file')
            fprintf('Skip missing file: %s\n', excelFiles{file_i});
            continue;
        end

        sheetList = sheetnames(excelFiles{file_i});
        if ~any(strcmp(sheetList, 'ROC_AUC')) || ~any(strcmp(sheetList, 'ROC_points'))
            fprintf('Skip file without ROC sheets: %s\n', excelFiles{file_i});
            fprintf('Please rerun the corresponding AI_qikan_acc script first.\n');
            continue;
        end

        rocAucTable = readtable(excelFiles{file_i}, 'Sheet', 'ROC_AUC');
        rocPointTable = readtable(excelFiles{file_i}, 'Sheet', 'ROC_points');
        AI_plot_one_method(rocAucTable, rocPointTable, methodNames{file_i}, outputDir);
        thresholdTable = AI_select_thresholds(rocAucTable, rocPointTable, methodNames{file_i}, 0.90);
        AI_print_threshold_table(thresholdTable);
        writetable(thresholdTable, fullfile(outputDir, 'AI_ROC_thresholds.xlsx'), ...
            'Sheet', methodNames{file_i});

        [loocvSummaryTable, loocvPredictionTable] = AI_loocv_thresholds_from_excel( ...
            excelFiles{file_i}, methodNames{file_i}, 0.90);
        AI_print_loocv_summary(loocvSummaryTable);
        writetable(loocvSummaryTable, fullfile(outputDir, 'AI_ROC_thresholds.xlsx'), ...
            'Sheet', [methodNames{file_i}, '_LOOCV_sum']);
        writetable(loocvPredictionTable, fullfile(outputDir, 'AI_ROC_thresholds.xlsx'), ...
            'Sheet', [methodNames{file_i}, '_LOOCV_pred']);
    end
end

function AI_plot_one_method(rocAucTable, rocPointTable, methodName, outputDir)
    comparisons = unique(rocAucTable.comparisonAuc, 'stable');

    for cmp_i = 1:numel(comparisons)
        comparisonName = comparisons{cmp_i};
        idxCmp = strcmp(rocAucTable.comparisonAuc, comparisonName);
        metrics = unique(rocAucTable.metricAuc(idxCmp), 'stable');

        fig = figure('Visible', 'off', 'Position', [100, 100, 760, 620]);
        hold on;

        for metric_i = 1:numel(metrics)
            metricName = metrics{metric_i};
            idxPoint = strcmp(rocPointTable.pointComparison, comparisonName) & ...
                strcmp(rocPointTable.pointMetric, metricName);
            idxAuc = idxCmp & strcmp(rocAucTable.metricAuc, metricName);

            if ~any(idxPoint) || ~any(idxAuc)
                continue;
            end

            fpr = rocPointTable.pointFPR(idxPoint);
            tpr = rocPointTable.pointTPR(idxPoint);
            [fpr, order] = sort(fpr);
            tpr = tpr(order);

            aucValue = rocAucTable.aucValue(find(idxAuc, 1));
            plot(fpr, tpr, 'LineWidth', 2, ...
                'DisplayName', sprintf('%s AUC=%.4f', metricName, aucValue));
        end

        plot([0, 1], [0, 1], 'k--', 'LineWidth', 1, 'DisplayName', 'Chance');
        hold off;

        xlim([0, 1]);
        ylim([0, 1]);
        grid on;
        axis square;
        xlabel('False Positive Rate');
        ylabel('True Positive Rate');
        title(strrep([methodName, '  ', comparisonName], '_', '\_'));
        legend('Location', 'southeast', 'Interpreter', 'none');

        fileBase = [methodName, '_', comparisonName];
        saveas(fig, fullfile(outputDir, [fileBase, '.png']));
        saveas(fig, fullfile(outputDir, [fileBase, '.fig']));
        close(fig);
    end
end

function thresholdTable = AI_select_thresholds(rocAucTable, rocPointTable, methodName, minSpecificity)
    targetComparisons = {'normal_vs_single', 'normal_vs_multi'};
    maxRows = height(rocAucTable);
    row_i = 0;

    method = cell(maxRows, 1);
    comparison = cell(maxRows, 1);
    metric = cell(maxRows, 1);
    threshold = nan(maxRows, 1);
    sensitivity = nan(maxRows, 1);
    specificity = nan(maxRows, 1);
    fpr = nan(maxRows, 1);
    aucValue = nan(maxRows, 1);
    nNormal = nan(maxRows, 1);
    nDefect = nan(maxRows, 1);

    for cmp_i = 1:numel(targetComparisons)
        comparisonName = targetComparisons{cmp_i};
        idxCmpAuc = strcmp(rocAucTable.comparisonAuc, comparisonName);
        metrics = unique(rocAucTable.metricAuc(idxCmpAuc), 'stable');

        for metric_i = 1:numel(metrics)
            metricName = metrics{metric_i};
            idxPoint = strcmp(rocPointTable.pointComparison, comparisonName) & ...
                strcmp(rocPointTable.pointMetric, metricName);
            idxAuc = idxCmpAuc & strcmp(rocAucTable.metricAuc, metricName);

            if ~any(idxPoint) || ~any(idxAuc)
                continue;
            end

            pointSub = rocPointTable(idxPoint, :);
            pointSpecificity = 1 - pointSub.pointFPR;
            candidateIdx = find(pointSpecificity >= minSpecificity);
            if isempty(candidateIdx)
                continue;
            end

            candidateTPR = pointSub.pointTPR(candidateIdx);
            candidateSpecificity = pointSpecificity(candidateIdx);
            candidateFPR = pointSub.pointFPR(candidateIdx);

            [~, order] = sortrows([-candidateTPR, -candidateSpecificity, candidateFPR]);
            bestLocalIdx = candidateIdx(order(1));
            aucRow = find(idxAuc, 1);

            row_i = row_i + 1;
            method{row_i} = methodName;
            comparison{row_i} = comparisonName;
            metric{row_i} = metricName;
            threshold(row_i) = AI_round4(pointSub.pointThreshold(bestLocalIdx));
            sensitivity(row_i) = AI_round4(pointSub.pointTPR(bestLocalIdx));
            specificity(row_i) = AI_round4(1 - pointSub.pointFPR(bestLocalIdx));
            fpr(row_i) = AI_round4(pointSub.pointFPR(bestLocalIdx));
            aucValue(row_i) = AI_round4(rocAucTable.aucValue(aucRow));
            nNormal(row_i) = rocAucTable.nNormal(aucRow);
            nDefect(row_i) = rocAucTable.nDefect(aucRow);
        end
    end

    thresholdTable = table(method(1:row_i), comparison(1:row_i), metric(1:row_i), ...
        threshold(1:row_i), sensitivity(1:row_i), specificity(1:row_i), ...
        fpr(1:row_i), aucValue(1:row_i), nNormal(1:row_i), nDefect(1:row_i), ...
        'VariableNames', {'method', 'comparison', 'metric', 'threshold', ...
        'sensitivity', 'specificity', 'fpr', 'aucValue', 'nNormal', 'nDefect'});
end

function AI_print_threshold_table(thresholdTable)
    fprintf('\n==== ROC threshold selection: specificity >= 0.90 ====\n');
    disp(thresholdTable);
end

function [summaryTable, predictionTable] = AI_loocv_thresholds_from_excel(excelFile, methodName, minSpecificity)
    scenarioNames = {'normal', 'left_single', 'right_single', 'left_multi', 'right_multi'};
    for scenario_i = 1:numel(scenarioNames)
        scenarioData.(scenarioNames{scenario_i}) = readtable(excelFile, 'Sheet', scenarioNames{scenario_i});
    end

    comparisons(1) = struct('name', 'normal_vs_single', ...
        'defectScenarios', {{'left_single', 'right_single'}});
    comparisons(2) = struct('name', 'normal_vs_multi', ...
        'defectScenarios', {{'left_multi', 'right_multi'}});
    metricList = {'VFI_loss', 'MD_loss', 'EyeMax', 'ExpectedEye'};

    normalTable = scenarioData.normal;
    trainTrialList = unique(normalTable.trainTrials, 'stable');
    testTrialList = unique(normalTable.testTrials, 'stable');
    foldNumList = unique(normalTable.foldNum, 'stable');

    predRow = 0;
    methodPred = {};
    comparisonPred = {};
    metricPred = {};
    heldSubject = [];
    sampleScenario = {};
    trueLabel = [];
    score = [];
    threshold = [];
    predictPositive = [];
    correct = [];
    trainSensitivity = [];
    trainSpecificity = [];
    trainAuc = [];

    sumRow = 0;
    methodSum = {};
    comparisonSum = {};
    metricSum = {};
    trainTrialsSum = [];
    testTrialsSum = [];
    foldNumSum = [];
    thresholdMean = [];
    thresholdStd = [];
    testSensitivity = [];
    testSpecificity = [];
    testAccuracy = [];
    testBalancedAcc = [];
    trainSensitivityMean = [];
    trainSpecificityMean = [];
    trainAucMean = [];
    nTestNormal = [];
    nTestDefect = [];

    for train_i = 1:numel(trainTrialList)
        for test_i = 1:numel(testTrialList)
            for fold_i = 1:numel(foldNumList)
                trainTrials = trainTrialList(train_i);
                testTrials = testTrialList(test_i);
                foldNum = foldNumList(fold_i);

                normalSub = AI_filter_rows(normalTable, trainTrials, testTrials, foldNum);
                subjectList = unique(normalSub.subjectIndex, 'stable');

                for cmp_i = 1:numel(comparisons)
                    cmp = comparisons(cmp_i);
                    for metric_i = 1:numel(metricList)
                        metricName = metricList{metric_i};

                        predStart = predRow + 1;
                        thresholdList = [];
                        trainSensList = [];
                        trainSpecList = [];
                        trainAucList = [];

                        for held_i = 1:numel(subjectList)
                            heldSub = subjectList(held_i);
                            [trainLabels, trainScores] = AI_collect_training_samples( ...
                                scenarioData, cmp, metricName, trainTrials, testTrials, foldNum, heldSub);
                            [bestThreshold, trainSens, trainSpec, aucValue] = ...
                                AI_select_threshold_from_scores(trainLabels, trainScores, minSpecificity);

                            if isnan(bestThreshold)
                                continue;
                            end

                            thresholdList(end + 1, 1) = bestThreshold;
                            trainSensList(end + 1, 1) = trainSens;
                            trainSpecList(end + 1, 1) = trainSpec;
                            trainAucList(end + 1, 1) = aucValue;

                            [testLabels, testScores, testScenarios] = AI_collect_test_samples( ...
                                scenarioData, cmp, metricName, trainTrials, testTrials, foldNum, heldSub);
                            for sample_i = 1:numel(testLabels)
                                predRow = predRow + 1;
                                methodPred{predRow, 1} = methodName;
                                comparisonPred{predRow, 1} = cmp.name;
                                metricPred{predRow, 1} = metricName;
                                heldSubject(predRow, 1) = heldSub;
                                sampleScenario{predRow, 1} = testScenarios{sample_i};
                                trueLabel(predRow, 1) = testLabels(sample_i);
                                score(predRow, 1) = AI_round4(testScores(sample_i));
                                threshold(predRow, 1) = AI_round4(bestThreshold);
                                predictPositive(predRow, 1) = testScores(sample_i) >= bestThreshold;
                                correct(predRow, 1) = predictPositive(predRow, 1) == trueLabel(predRow, 1);
                                trainSensitivity(predRow, 1) = AI_round4(trainSens);
                                trainSpecificity(predRow, 1) = AI_round4(trainSpec);
                                trainAuc(predRow, 1) = AI_round4(aucValue);
                            end
                        end

                        predEnd = predRow;
                        if predEnd < predStart
                            continue;
                        end

                        labelsNow = trueLabel(predStart:predEnd);
                        predNow = predictPositive(predStart:predEnd);
                        posIdx = labelsNow == 1;
                        negIdx = labelsNow == 0;

                        sumRow = sumRow + 1;
                        methodSum{sumRow, 1} = methodName;
                        comparisonSum{sumRow, 1} = cmp.name;
                        metricSum{sumRow, 1} = metricName;
                        trainTrialsSum(sumRow, 1) = trainTrials;
                        testTrialsSum(sumRow, 1) = testTrials;
                        foldNumSum(sumRow, 1) = foldNum;
                        thresholdMean(sumRow, 1) = AI_round4(mean(thresholdList, 'omitnan'));
                        thresholdStd(sumRow, 1) = AI_round4(std(thresholdList, 'omitnan'));
                        testSensitivity(sumRow, 1) = AI_round4(mean(predNow(posIdx) == 1));
                        testSpecificity(sumRow, 1) = AI_round4(mean(predNow(negIdx) == 0));
                        testAccuracy(sumRow, 1) = AI_round4(mean(predNow == labelsNow));
                        testBalancedAcc(sumRow, 1) = AI_round4((testSensitivity(sumRow) + testSpecificity(sumRow)) / 2);
                        trainSensitivityMean(sumRow, 1) = AI_round4(mean(trainSensList, 'omitnan'));
                        trainSpecificityMean(sumRow, 1) = AI_round4(mean(trainSpecList, 'omitnan'));
                        trainAucMean(sumRow, 1) = AI_round4(mean(trainAucList, 'omitnan'));
                        nTestNormal(sumRow, 1) = sum(negIdx);
                        nTestDefect(sumRow, 1) = sum(posIdx);
                    end
                end
            end
        end
    end

    summaryTable = table(methodSum, comparisonSum, metricSum, trainTrialsSum, ...
        testTrialsSum, foldNumSum, thresholdMean, thresholdStd, ...
        testSensitivity, testSpecificity, testAccuracy, testBalancedAcc, ...
        trainSensitivityMean, trainSpecificityMean, trainAucMean, ...
        nTestNormal, nTestDefect, ...
        'VariableNames', {'method', 'comparison', 'metric', 'trainTrials', ...
        'testTrials', 'foldNum', 'thresholdMean', 'thresholdStd', ...
        'testSensitivity', 'testSpecificity', 'testAccuracy', ...
        'testBalancedAcc', 'trainSensitivityMean', 'trainSpecificityMean', ...
        'trainAucMean', 'nTestNormal', 'nTestDefect'});

    predictionTable = table(methodPred, comparisonPred, metricPred, heldSubject, ...
        sampleScenario, trueLabel, score, threshold, predictPositive, correct, ...
        trainSensitivity, trainSpecificity, trainAuc, ...
        'VariableNames', {'method', 'comparison', 'metric', 'heldSubject', ...
        'sampleScenario', 'trueLabel', 'score', 'threshold', ...
        'predictPositive', 'correct', 'trainSensitivity', ...
        'trainSpecificity', 'trainAuc'});
end

function rowSub = AI_filter_rows(dataTable, trainTrials, testTrials, foldNum)
    rowSub = dataTable(dataTable.trainTrials == trainTrials & ...
        dataTable.testTrials == testTrials & dataTable.foldNum == foldNum, :);
end

function [labels, scores] = AI_collect_training_samples(scenarioData, cmp, metricName, trainTrials, testTrials, foldNum, heldSub)
    labels = [];
    scores = [];

    normalRows = AI_filter_rows(scenarioData.normal, trainTrials, testTrials, foldNum);
    normalRows = normalRows(normalRows.subjectIndex ~= heldSub, :);
    labels = [labels; zeros(height(normalRows), 1)];
    scores = [scores; AI_metric_scores_from_table(normalRows, metricName, 'normal')];

    for scenario_i = 1:numel(cmp.defectScenarios)
        scenarioName = cmp.defectScenarios{scenario_i};
        defectRows = AI_filter_rows(scenarioData.(scenarioName), trainTrials, testTrials, foldNum);
        defectRows = defectRows(defectRows.subjectIndex ~= heldSub, :);
        labels = [labels; ones(height(defectRows), 1)];
        scores = [scores; AI_metric_scores_from_table(defectRows, metricName, scenarioName)];
    end
end

function [labels, scores, sampleScenarios] = AI_collect_test_samples(scenarioData, cmp, metricName, trainTrials, testTrials, foldNum, heldSub)
    labels = [];
    scores = [];
    sampleScenarios = {};

    normalRows = AI_filter_rows(scenarioData.normal, trainTrials, testTrials, foldNum);
    normalRows = normalRows(normalRows.subjectIndex == heldSub, :);
    labels = [labels; zeros(height(normalRows), 1)];
    scores = [scores; AI_metric_scores_from_table(normalRows, metricName, 'normal')];
    sampleScenarios = [sampleScenarios; repmat({'normal'}, height(normalRows), 1)];

    for scenario_i = 1:numel(cmp.defectScenarios)
        scenarioName = cmp.defectScenarios{scenario_i};
        defectRows = AI_filter_rows(scenarioData.(scenarioName), trainTrials, testTrials, foldNum);
        defectRows = defectRows(defectRows.subjectIndex == heldSub, :);
        labels = [labels; ones(height(defectRows), 1)];
        scores = [scores; AI_metric_scores_from_table(defectRows, metricName, scenarioName)];
        sampleScenarios = [sampleScenarios; repmat({scenarioName}, height(defectRows), 1)];
    end
end

function scores = AI_metric_scores_from_table(dataTable, metricName, scenarioName)
    switch metricName
        case 'VFI_loss'
            scores = 100 - dataTable.VFI;
        case 'MD_loss'
            scores = dataTable.MD_loss;
        case 'EyeMax'
            scores = max(dataTable.LEI, dataTable.REI);
        case 'ExpectedEye'
            if contains(scenarioName, 'left')
                scores = dataTable.LEI;
            elseif contains(scenarioName, 'right')
                scores = dataTable.REI;
            else
                scores = max(dataTable.LEI, dataTable.REI);
            end
        otherwise
            error('Unsupported LOOCV metric: %s', metricName);
    end
end

function [bestThreshold, bestSensitivity, bestSpecificity, aucValue] = AI_select_threshold_from_scores(labels, scores, minSpecificity)
    [aucValue, fpr, tpr, thresholds] = AI_roc_from_scores(labels, scores);
    specificity = 1 - fpr;
    candidateIdx = find(specificity >= minSpecificity);

    if isempty(candidateIdx)
        bestThreshold = nan;
        bestSensitivity = nan;
        bestSpecificity = nan;
        return;
    end

    [~, order] = sortrows([-tpr(candidateIdx), -specificity(candidateIdx), fpr(candidateIdx)]);
    bestIdx = candidateIdx(order(1));
    bestThreshold = thresholds(bestIdx);
    bestSensitivity = tpr(bestIdx);
    bestSpecificity = specificity(bestIdx);
end

function [aucValue, fpr, tpr, thresholds] = AI_roc_from_scores(labels, scores)
    labels = labels(:);
    scores = scores(:);
    validIdx = ~isnan(labels) & ~isnan(scores);
    labels = labels(validIdx);
    scores = scores(validIdx);

    posNum = sum(labels == 1);
    negNum = sum(labels == 0);
    if posNum == 0 || negNum == 0
        aucValue = nan;
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
    aucValue = trapz(fpr, tpr);
end

function AI_print_loocv_summary(summaryTable)
    fprintf('\n==== Leave-one-subject-out threshold validation ====\n');
    disp(summaryTable);
end

function value = AI_round4(value)
    value = round(value * 10000) / 10000;
end
