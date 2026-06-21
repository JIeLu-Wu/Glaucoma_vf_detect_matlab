%% AI_compare_foldnum_accumulation
% 目的：
%   比较不同测试试次叠加数量 foldNum 对当前 DCPM 概率判别结果的影响。
%
% 核心问题：
%   如果只看 mean(rDiff)，改变叠加数量通常不会改变最终均值；
%   但叠加数量会改变：
%       1) block 层级 rDiff/rNorm 的稳定性；
%       2) 模板交叉验证得到的 R11/R12/R21/R22 先验分布；
%       3) Prob_calculate 的非线性概率输出 Prob_dv；
%       4) 基于 Prob_dv 的三分类视野判别准确率。
%
% 重点输出：
%   1) block 层级结果：每个 foldNum 下每个 block 的 r1/r2/Prob_dv；
%   2) point 层级结果：每个 subject-point 的均值、方差、三分类标签；
%   3) scenario / upper-lower 层级汇总：
%       - Prob_dv 三分类准确率；
%       - normal vs defect AUC；
%       - left vs right 方向准确率；
%       - rDiff/rNorm 稳定性；
%       - 模板 cvAccAll/cvSeparability。
%
% 说明：
%   本脚本按照顺序式流程书写，不把主流程拆成多层函数。
%   末尾只有一个 AUC 计算小工具函数，用于避免依赖额外工具箱。

clear;
clc;

%% 1. 基本参数
settings = struct();
settings.fs = 250;
settings.tStart = 0;
settings.tEnd = 0.45;
settings.WnPara = [0.5, 2, 20, 30];
settings.chanList = 44:64;

settings.trainTrialNum = 80;
settings.testTrialNum = 60;
settings.crossNum = 10;
settings.dcpmComponent = 8;

% 只选择同时整除 80 个训练交叉验证试次和 60 个测试试次的叠加数。
% 2 -> 30 个测试 block
% 4 -> 15 个测试 block，当前主流程常用设置
% 5 -> 12 个测试 block
% 10 -> 6 个测试 block
settings.foldNumList = [2, 4, 5, 10];

settings.scriptDir = fileparts(mfilename('fullpath'));
settings.projectDir = fileparts(settings.scriptDir);
settings.dataRoot = fullfile(settings.projectDir, 'data', char([23567 35770 25991 25968 25454]));
settings.resultDir = fullfile(settings.projectDir, char([32467 26524]));
settings.outputDir = fullfile(settings.resultDir, 'AI_foldnum_accumulation_analysis');
settings.excelFile = fullfile(settings.outputDir, 'AI_foldnum_accumulation_analysis.xlsx');
settings.matFile = fullfile(settings.outputDir, 'AI_foldnum_accumulation_analysis.mat');

if ~exist(settings.outputDir, 'dir')
    mkdir(settings.outputDir);
end

fprintf('Output folder:\n  %s\n', settings.outputDir);

%% 2. 五种模拟条件配置
baseTempType = [1,2; 2,1; 3,4; 4,3];

scenarios = struct([]);
scenarios(1).name = 'normal';
scenarios(1).trainFileType = '3-1';
scenarios(1).testFileType = '4-1';
scenarios(1).bsFileType = '';
scenarios(1).useMixedTemplate = false;
scenarios(1).swapMode = 'if_subject_R';
scenarios(1).expectedLabel = 1;
scenarios(1).tempType = baseTempType;

scenarios(2).name = 'left_single';
scenarios(2).trainFileType = '1-1';
scenarios(2).testFileType = '1-2';
scenarios(2).bsFileType = '3-1';
scenarios(2).useMixedTemplate = true;
scenarios(2).swapMode = 'if_subject_R';
scenarios(2).expectedLabel = 2;
scenarios(2).tempType = baseTempType;

scenarios(3).name = 'left_multi';
scenarios(3).trainFileType = '1-1';
scenarios(3).testFileType = '1-2';
scenarios(3).bsFileType = '';
scenarios(3).useMixedTemplate = false;
scenarios(3).swapMode = 'if_subject_R';
scenarios(3).expectedLabel = 2;
scenarios(3).tempType = baseTempType;

scenarios(4).name = 'right_single';
scenarios(4).trainFileType = '2-1';
scenarios(4).testFileType = '2-2';
scenarios(4).bsFileType = '3-1';
scenarios(4).useMixedTemplate = true;
scenarios(4).swapMode = 'always';
scenarios(4).expectedLabel = 3;
scenarios(4).tempType = baseTempType;

scenarios(5).name = 'right_multi';
scenarios(5).trainFileType = '2-1';
scenarios(5).testFileType = '2-2';
scenarios(5).bsFileType = '';
scenarios(5).useMixedTemplate = false;
scenarios(5).swapMode = 'always';
scenarios(5).expectedLabel = 3;
scenarios(5).tempType = baseTempType;

scenarioOrder = {scenarios.name};

%% 3. 自动寻找被试文件夹
subjectDirs = {};
subjectSet = {};

subjectRoots = {settings.dataRoot, fullfile(settings.dataRoot, '250ms')};
subjectRootNames = {'main', '250ms'};

for root_i = 1:numel(subjectRoots)
    thisRoot = subjectRoots{root_i};
    if ~exist(thisRoot, 'dir')
        fprintf('Skip missing subject root: %s\n', thisRoot);
        continue;
    end

    dirInfo = dir(fullfile(thisRoot, 'sub*'));
    dirInfo = dirInfo([dirInfo.isdir]);

    subNum = nan(numel(dirInfo), 1);
    for i = 1:numel(dirInfo)
        token = regexp(dirInfo(i).name, '^sub(\d+)$', 'tokens', 'once');
        if ~isempty(token)
            subNum(i) = str2double(token{1});
        else
            subNum(i) = inf;
        end
    end
    [~, order] = sort(subNum);
    dirInfo = dirInfo(order);

    for i = 1:numel(dirInfo)
        subjectDirs{end + 1, 1} = fullfile(thisRoot, dirInfo(i).name); %#ok<SAGROW>
        subjectSet{end + 1, 1} = subjectRootNames{root_i}; %#ok<SAGROW>
    end
end

if isempty(subjectDirs)
    error('No subject folders were found under: %s', settings.dataRoot);
end

fprintf('Found %d subject folders.\n', numel(subjectDirs));

%% 4. 主循环：先计算单试次 DCPM，再按不同 foldNum 叠加
blockRows = struct([]);
pointRows = struct([]);
blockRow_i = 0;
pointRow_i = 0;

for scenario_i = 1:numel(scenarios)
    cfg = scenarios(scenario_i);
    fprintf('\n==== Scenario: %s ====\n', cfg.name);

    for sub_i = 1:numel(subjectDirs)
        subDir = subjectDirs{sub_i};
        fprintf('Subject %d/%d: %s\n', sub_i, numel(subjectDirs), subDir);

        trainFile = fullfile(subDir, [cfg.trainFileType, '.cnt']);
        testFile = fullfile(subDir, [cfg.testFileType, '.cnt']);
        if cfg.useMixedTemplate
            bsFile = fullfile(subDir, [cfg.bsFileType, '.cnt']);
        else
            bsFile = '';
        end

        if ~exist(trainFile, 'file') || ~exist(testFile, 'file') || ...
                (cfg.useMixedTemplate && ~exist(bsFile, 'file'))
            fprintf('  Skip missing files.\n');
            continue;
        end

        try
            [~, trainSeg, typeAllTrain] = EEGRead5(trainFile, 1000, settings.fs, ...
                [settings.tStart, settings.tEnd], settings.WnPara, 400);
            trainDataAll = trainSeg(1:64, :, :, :);

            if cfg.useMixedTemplate
                [~, bsSeg, ~] = EEGRead5(bsFile, 1000, settings.fs, ...
                    [settings.tStart, settings.tEnd], settings.WnPara, 400);
                bsDataAll = bsSeg(1:64, :, :, :);
            else
                bsDataAll = [];
            end

            [~, testSeg, typeAllTest] = EEGRead5(testFile, 1000, settings.fs, ...
                [settings.tStart, settings.tEnd], settings.WnPara, 400);
            testDataAll = testSeg(1:64, :, :, :);
        catch ME
            fprintf('  Skip because data loading failed: %s\n', ME.message);
            continue;
        end

        if size(trainDataAll, 3) < settings.trainTrialNum || ...
                size(testDataAll, 3) < settings.testTrialNum || ...
                (cfg.useMixedTemplate && size(bsDataAll, 3) < settings.trainTrialNum)
            fprintf('  Skip because available trial number is smaller than requested.\n');
            continue;
        end

        pointNum = min([numel(typeAllTrain), numel(typeAllTest), size(cfg.tempType, 1)]);
        trainData = trainDataAll(:, :, 1:settings.trainTrialNum, :);
        testData = testDataAll(:, :, 1:settings.testTrialNum, :);
        if cfg.useMixedTemplate
            bsData = bsDataAll(:, :, 1:settings.trainTrialNum, :);
        else
            bsData = [];
        end

        for point_i = 1:pointNum
            pair = cfg.tempType(point_i, :);
            templatePoint = pair;
            templateSource = {'train', 'train'};

            if cfg.useMixedTemplate
                temp1 = trainData(settings.chanList, :, :, pair(1));
                temp2 = bsData(settings.chanList, :, :, pair(2));
                template = cat(4, temp1, temp2);
                templateSource = {'train', 'bs'};
            else
                template = trainData(settings.chanList, :, :, pair);
            end

            needSwap = false;
            if strcmp(cfg.swapMode, 'always')
                needSwap = true;
            elseif strcmp(cfg.swapMode, 'if_subject_R')
                if numel(subDir) >= 4 && strcmp(subDir(end - 3), 'R')
                    needSwap = true;
                end
            end

            if needSwap
                template = template(:, :, :, [2, 1]);
                templatePoint = fliplr(templatePoint);
                templateSource = fliplr(templateSource);
            end

            testTrials = testData(settings.chanList, :, :, point_i);

            % 4.1 只计算一次单试次层面的模板交叉验证和测试 DCPM 决策值。
            % 后续不同 foldNum 都从这两个单试次结果进行叠加。
            RR_cross = DCPM_cross_valid(template, settings.dcpmComponent, settings.crossNum);
            RR_test = Multi_DSPm(settings.dcpmComponent, template, testTrials);

            for fold_i = 1:numel(settings.foldNumList)
                foldNum = settings.foldNumList(fold_i);

                if mod(size(RR_cross, 1), foldNum) ~= 0 || ...
                        mod(size(RR_test, 1), foldNum) ~= 0
                    fprintf('  Skip foldNum=%d because trial numbers are not divisible.\n', foldNum);
                    continue;
                end

                % 4.2 模板交叉验证决策值叠加。
                % 叠加数量会影响 R11/R12/R21/R22 的均值、方差和 cvAccAll，
                % 进而改变 Prob_calculate 使用的先验分布。
                cvBlockNum = size(RR_cross, 1) / foldNum;
                RR_cross_fold = nan(cvBlockNum, size(RR_cross, 2), size(RR_cross, 3));
                for cvBlock_i = 1:cvBlockNum
                    idx = (cvBlock_i - 1) * foldNum + 1:cvBlock_i * foldNum;
                    RR_cross_fold(cvBlock_i, :, :) = mean(RR_cross(idx, :, :), 1);
                end

                [~, rouCross] = max(RR_cross_fold, [], 2);
                rouCross = squeeze(rouCross);
                cvAccClass1 = mean(rouCross(:, 1) == 1, 'omitnan');
                cvAccClass2 = mean(rouCross(:, 2) == 2, 'omitnan');
                cvAccAll = mean([cvAccClass1, cvAccClass2], 'omitnan');

                R11 = RR_cross_fold(:, 1, 1);
                R12 = RR_cross_fold(:, 2, 1);
                R21 = RR_cross_fold(:, 1, 2);
                R22 = RR_cross_fold(:, 2, 2);

                dClass1 = R11 - R12;
                dClass2 = R22 - R21;
                cvMarginClass1 = mean(dClass1, 'omitnan');
                cvMarginClass2 = mean(dClass2, 'omitnan');
                cvSeparability = mean([dClass1; dClass2], 'omitnan');
                cvDiffStd = std([dClass1; dClass2], 0, 'omitnan');

                % 与 glc_detection_prob.m 保持一致：
                % 概率模型的 all_ave/all_std 使用模板交叉验证中正确分类的 block。
                TP_index = rouCross(:, 1) == 1;
                TN_index = rouCross(:, 2) == 2;
                TP_value = RR_cross_fold(TP_index, :, 1);
                TN_value = RR_cross_fold(TN_index, :, 2);

                % 如果某个点模板质量很差，可能出现没有正确分类 block。
                % 为避免概率计算中断，这里退回到所有 class1/class2 block 估计先验；
                % 同时用 priorFallback 记录该情况，后续可作为低可靠标记。
                priorFallback = false;
                if isempty(TP_value)
                    TP_value = RR_cross_fold(:, :, 1);
                    priorFallback = true;
                end
                if isempty(TN_value)
                    TN_value = RR_cross_fold(:, :, 2);
                    priorFallback = true;
                end

                all_ave = cat(1, mean(TP_value, 1), mean(TN_value, 1));
                all_std = cat(1, std(TP_value, 0, 1), std(TN_value, 0, 1));
                all_std = max(all_std, 1e-6);

                % 4.3 测试决策值叠加，并计算 Prob_dv。
                testBlockNum = size(RR_test, 1) / foldNum;
                RR_fold = nan(testBlockNum, size(RR_test, 2));
                for testBlock_i = 1:testBlockNum
                    idx = (testBlock_i - 1) * foldNum + 1:testBlock_i * foldNum;
                    RR_fold(testBlock_i, :) = mean(RR_test(idx, :), 1);
                end

                Prob_dv = Prob_calculate(RR_fold, all_ave, all_std);

                % 4.4 block 层级结果。
                for block_i = 1:testBlockNum
                    r1 = RR_fold(block_i, 1);
                    r2 = RR_fold(block_i, 2);
                    rMean = mean([r1, r2], 'omitnan');
                    rDiff = r1 - r2;
                    rAbsDiff = abs(rDiff);
                    rNorm = sqrt(r1 .^ 2 + r2 .^ 2);

                    probNow = Prob_dv(:, block_i);
                    probNow = probNow ./ sum(probNow);
                    pNormal = probNow(1);
                    pLeft = probNow(2);
                    pRight = probNow(3);
                    pDefect = pLeft + pRight;
                    [pMax, labelBlock] = max(probNow);
                    probSorted = sort(probNow, 'descend');
                    pMargin = probSorted(1) - probSorted(2);
                    pEntropy = -sum(probNow .* log(probNow + eps));

                    blockRow_i = blockRow_i + 1;
                    blockRows(blockRow_i).scenario = cfg.name;
                    blockRows(blockRow_i).subjectIndex = sub_i;
                    blockRows(blockRow_i).subjectSet = subjectSet{sub_i};
                    blockRows(blockRow_i).subjectDir = subDir;
                    blockRows(blockRow_i).point = point_i;
                    if point_i <= 2
                        blockRows(blockRow_i).pointGroup = 'upper';
                    else
                        blockRows(blockRow_i).pointGroup = 'lower';
                    end
                    blockRows(blockRow_i).foldNum = foldNum;
                    blockRows(blockRow_i).block = block_i;
                    blockRows(blockRow_i).blockNum = testBlockNum;
                    blockRows(blockRow_i).expectedLabel = cfg.expectedLabel;
                    blockRows(blockRow_i).trainFileType = cfg.trainFileType;
                    blockRows(blockRow_i).testFileType = cfg.testFileType;
                    blockRows(blockRow_i).useMixedTemplate = cfg.useMixedTemplate;
                    blockRows(blockRow_i).templateSwapped = needSwap;
                    blockRows(blockRow_i).templatePoint1 = templatePoint(1);
                    blockRows(blockRow_i).templatePoint2 = templatePoint(2);
                    blockRows(blockRow_i).templateSource1 = templateSource{1};
                    blockRows(blockRow_i).templateSource2 = templateSource{2};
                    blockRows(blockRow_i).trainEventType = typeAllTrain(point_i);
                    blockRows(blockRow_i).testEventType = typeAllTest(point_i);

                    blockRows(blockRow_i).r1 = r1;
                    blockRows(blockRow_i).r2 = r2;
                    blockRows(blockRow_i).rMean = rMean;
                    blockRows(blockRow_i).rDiff = rDiff;
                    blockRows(blockRow_i).rAbsDiff = rAbsDiff;
                    blockRows(blockRow_i).rNorm = rNorm;

                    blockRows(blockRow_i).pNormal = pNormal;
                    blockRows(blockRow_i).pLeft = pLeft;
                    blockRows(blockRow_i).pRight = pRight;
                    blockRows(blockRow_i).pDefect = pDefect;
                    blockRows(blockRow_i).pMax = pMax;
                    blockRows(blockRow_i).pMargin = pMargin;
                    blockRows(blockRow_i).pEntropy = pEntropy;
                    blockRows(blockRow_i).labelBlock = labelBlock;
                    blockRows(blockRow_i).blockCorrect = labelBlock == cfg.expectedLabel;

                    blockRows(blockRow_i).cvAccAll = cvAccAll;
                    blockRows(blockRow_i).cvAccClass1 = cvAccClass1;
                    blockRows(blockRow_i).cvAccClass2 = cvAccClass2;
                    blockRows(blockRow_i).cvSeparability = cvSeparability;
                    blockRows(blockRow_i).cvMarginClass1 = cvMarginClass1;
                    blockRows(blockRow_i).cvMarginClass2 = cvMarginClass2;
                    blockRows(blockRow_i).cvDiffStd = cvDiffStd;
                    blockRows(blockRow_i).priorFallback = priorFallback;
                end

                % 4.5 point 层级结果。
                % 这是后续判断视野点状态的主要层级。
                % Prob_dv 三分类准确率采用 pointProb = mean(Prob_dv, 2)，
                % 再取最大概率对应标签，与 expectedLabel 比较。
                pointProb = mean(Prob_dv, 2);
                pointProb = pointProb ./ sum(pointProb);
                [~, labelPointProb] = max(pointProb);

                pointRow_i = pointRow_i + 1;
                pointRows(pointRow_i).scenario = cfg.name;
                pointRows(pointRow_i).subjectIndex = sub_i;
                pointRows(pointRow_i).subjectSet = subjectSet{sub_i};
                pointRows(pointRow_i).subjectDir = subDir;
                pointRows(pointRow_i).point = point_i;
                if point_i <= 2
                    pointRows(pointRow_i).pointGroup = 'upper';
                else
                    pointRows(pointRow_i).pointGroup = 'lower';
                end
                pointRows(pointRow_i).foldNum = foldNum;
                pointRows(pointRow_i).blockNum = testBlockNum;
                pointRows(pointRow_i).expectedLabel = cfg.expectedLabel;
                pointRows(pointRow_i).trainFileType = cfg.trainFileType;
                pointRows(pointRow_i).testFileType = cfg.testFileType;
                pointRows(pointRow_i).useMixedTemplate = cfg.useMixedTemplate;
                pointRows(pointRow_i).templateSwapped = needSwap;
                pointRows(pointRow_i).templatePoint1 = templatePoint(1);
                pointRows(pointRow_i).templatePoint2 = templatePoint(2);
                pointRows(pointRow_i).templateSource1 = templateSource{1};
                pointRows(pointRow_i).templateSource2 = templateSource{2};

                pointRows(pointRow_i).mean_r1 = mean(RR_fold(:, 1), 'omitnan');
                pointRows(pointRow_i).std_r1 = std(RR_fold(:, 1), 0, 'omitnan');
                pointRows(pointRow_i).mean_r2 = mean(RR_fold(:, 2), 'omitnan');
                pointRows(pointRow_i).std_r2 = std(RR_fold(:, 2), 0, 'omitnan');
                pointRows(pointRow_i).mean_rMean = mean(mean(RR_fold, 2), 'omitnan');
                pointRows(pointRow_i).std_rMean = std(mean(RR_fold, 2), 0, 'omitnan');

                rDiffAll = RR_fold(:, 1) - RR_fold(:, 2);
                rAbsDiffAll = abs(rDiffAll);
                rNormAll = sqrt(RR_fold(:, 1) .^ 2 + RR_fold(:, 2) .^ 2);
                pointRows(pointRow_i).mean_rDiff = mean(rDiffAll, 'omitnan');
                pointRows(pointRow_i).std_rDiff = std(rDiffAll, 0, 'omitnan');
                pointRows(pointRow_i).mean_rAbsDiff = mean(rAbsDiffAll, 'omitnan');
                pointRows(pointRow_i).std_rAbsDiff = std(rAbsDiffAll, 0, 'omitnan');
                pointRows(pointRow_i).mean_rNorm = mean(rNormAll, 'omitnan');
                pointRows(pointRow_i).std_rNorm = std(rNormAll, 0, 'omitnan');

                pointRows(pointRow_i).mean_pNormal = pointProb(1);
                pointRows(pointRow_i).mean_pLeft = pointProb(2);
                pointRows(pointRow_i).mean_pRight = pointProb(3);
                pointRows(pointRow_i).mean_pDefect = pointProb(2) + pointProb(3);
                currentBlockRange = blockRow_i - testBlockNum + 1:blockRow_i;
                pointRows(pointRow_i).mean_pMargin = mean([blockRows(currentBlockRange).pMargin], 'omitnan');
                pointRows(pointRow_i).mean_pEntropy = mean([blockRows(currentBlockRange).pEntropy], 'omitnan');
                pointRows(pointRow_i).std_pNormal = std(Prob_dv(1, :), 0, 'omitnan');
                pointRows(pointRow_i).std_pLeft = std(Prob_dv(2, :), 0, 'omitnan');
                pointRows(pointRow_i).std_pRight = std(Prob_dv(3, :), 0, 'omitnan');
                pointRows(pointRow_i).std_pDefect = std(Prob_dv(2, :) + Prob_dv(3, :), 0, 'omitnan');

                pointRows(pointRow_i).labelPointProb = labelPointProb;
                pointRows(pointRow_i).pointCorrect = labelPointProb == cfg.expectedLabel;

                pointRows(pointRow_i).cvAccAll = cvAccAll;
                pointRows(pointRow_i).cvAccClass1 = cvAccClass1;
                pointRows(pointRow_i).cvAccClass2 = cvAccClass2;
                pointRows(pointRow_i).cvSeparability = cvSeparability;
                pointRows(pointRow_i).cvMarginClass1 = cvMarginClass1;
                pointRows(pointRow_i).cvMarginClass2 = cvMarginClass2;
                pointRows(pointRow_i).cvDiffStd = cvDiffStd;
                pointRows(pointRow_i).priorFallback = priorFallback;
            end
        end
    end
end

blockTable = struct2table(blockRows);
pointTable = struct2table(pointRows);

%% 5. 汇总：三分类准确率、方向准确率、稳定性和 AUC
% 5.1 Prob_dv 点位三分类准确率。
% 这里的 pointCorrect 就是之前主脚本里的视野判别准确率：
%   pointProb = mean(Prob_dv, 2)
%   label = argmax(pointProb)
%   correct = label == expectedLabel
accByScenario = groupsummary(pointTable, ...
    {'foldNum', 'scenario', 'pointGroup'}, {'mean'}, ...
    {'pointCorrect', 'mean_pMargin', 'mean_pEntropy', ...
    'std_rDiff', 'std_rNorm', 'cvAccAll', 'cvSeparability'});

accBySubject = groupsummary(pointTable, ...
    {'foldNum', 'scenario', 'subjectIndex'}, {'mean'}, ...
    {'pointCorrect', 'mean_pMargin', 'mean_pEntropy', ...
    'std_rDiff', 'std_rNorm', 'cvAccAll', 'cvSeparability'});

% 5.2 normal vs defect AUC。
aucRows = {};
aucMetrics = {'mean_pDefect', 'mean_pNormal', 'mean_pMargin', ...
    'mean_pEntropy', 'mean_rAbsDiff', 'mean_rNorm', ...
    'std_rDiff', 'std_rNorm', 'cvAccAll', 'cvSeparability'};

pointGroupList = {'all', 'upper', 'lower'};
for fold_i = 1:numel(settings.foldNumList)
    foldNum = settings.foldNumList(fold_i);

    for group_i = 1:numel(pointGroupList)
        groupName = pointGroupList{group_i};
        if strcmp(groupName, 'all')
            subPoint = pointTable(pointTable.foldNum == foldNum, :);
        else
            subPoint = pointTable(pointTable.foldNum == foldNum & ...
                strcmp(pointTable.pointGroup, groupName), :);
        end

        defectLabel = ~strcmp(subPoint.scenario, 'normal');

        for metric_i = 1:numel(aucMetrics)
            metricName = aucMetrics{metric_i};
            score = subPoint.(metricName);
            aucHigh = AI_local_auc(defectLabel, score);
            aucLow = AI_local_auc(defectLabel, -score);

            if aucHigh >= aucLow
                bestAuc = aucHigh;
                direction = 'high_defect';
            else
                bestAuc = aucLow;
                direction = 'low_defect';
            end

            aucRows(end + 1, :) = {foldNum, groupName, ...
                'normal_vs_any_defect', metricName, aucHigh, aucLow, ...
                bestAuc, direction, sum(defectLabel), sum(~defectLabel)}; %#ok<SAGROW>
        end
    end
end

aucTable = cell2table(aucRows, 'VariableNames', ...
    {'foldNum', 'pointGroup', 'comparison', 'metric', 'aucHigh', ...
    'aucLow', 'bestAuc', 'direction', 'nDefect', 'nNormal'});

% 5.3 left vs right 方向判断。
directionRows = {};
directionMetrics = {'mean_rDiff'};
for fold_i = 1:numel(settings.foldNumList)
    foldNum = settings.foldNumList(fold_i);

    for group_i = 1:numel(pointGroupList)
        groupName = pointGroupList{group_i};
        if strcmp(groupName, 'all')
            lrPoint = pointTable(pointTable.foldNum == foldNum & ...
                ~strcmp(pointTable.scenario, 'normal'), :);
        else
            lrPoint = pointTable(pointTable.foldNum == foldNum & ...
                ~strcmp(pointTable.scenario, 'normal') & ...
                strcmp(pointTable.pointGroup, groupName), :);
        end

        isLeft = contains(lrPoint.scenario, 'left');

        for metric_i = 1:numel(directionMetrics)
            metricName = directionMetrics{metric_i};
            score = lrPoint.(metricName);
            aucHighLeft = AI_local_auc(isLeft, score);
            aucHighRight = AI_local_auc(isLeft, -score);
            bestAuc = max(aucHighLeft, aucHighRight);
            predLeft = score >= 0;
            signAccuracy = mean(predLeft == isLeft, 'omitnan');

            directionRows(end + 1, :) = {foldNum, groupName, metricName, ...
                aucHighLeft, aucHighRight, bestAuc, signAccuracy, height(lrPoint)}; %#ok<SAGROW>
        end
    end
end

directionTable = cell2table(directionRows, 'VariableNames', ...
    {'foldNum', 'pointGroup', 'metric', 'aucHighLeft', ...
    'aucHighRight', 'bestAuc', 'signAccuracy', 'nPoint'});

%% 6. 输出 Excel 和 MAT
writetable(blockTable, settings.excelFile, 'Sheet', 'block_by_fold');
writetable(pointTable, settings.excelFile, 'Sheet', 'point_by_fold');
writetable(accByScenario, settings.excelFile, 'Sheet', 'acc_by_scenario');
writetable(accBySubject, settings.excelFile, 'Sheet', 'acc_by_subject');
writetable(aucTable, settings.excelFile, 'Sheet', 'auc_normal_defect');
writetable(directionTable, settings.excelFile, 'Sheet', 'direction_left_right');

save(settings.matFile, 'blockTable', 'pointTable', 'accByScenario', ...
    'accBySubject', 'aucTable', 'directionTable', ...
    'settings', 'scenarios', '-v7.3');

fprintf('\nSaved Excel:\n  %s\n', settings.excelFile);
fprintf('Saved MAT:\n  %s\n', settings.matFile);

%% 7. 绘图：上侧点/下侧点随 foldNum 变化
% 图 1：Prob_dv 点位三分类准确率
fig = figure('Visible', 'off', 'Position', [100, 100, 1200, 760], 'Color', 'w');
tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

for group_i = 1:2
    nexttile;
    if group_i == 1
        groupName = 'upper';
    else
        groupName = 'lower';
    end

    hold on;
    colors = lines(numel(scenarios));
    for scenario_i = 1:numel(scenarios)
        scenarioName = scenarios(scenario_i).name;
        y = nan(size(settings.foldNumList));
        for fold_i = 1:numel(settings.foldNumList)
            foldNum = settings.foldNumList(fold_i);
            idx = pointTable.foldNum == foldNum & ...
                strcmp(pointTable.pointGroup, groupName) & ...
                strcmp(pointTable.scenario, scenarioName);
            y(fold_i) = mean(pointTable.pointCorrect(idx), 'omitnan');
        end
        plot(settings.foldNumList, y, '-o', 'LineWidth', 1.5, ...
            'Color', colors(scenario_i, :), 'DisplayName', scenarioName);
    end
    hold off;
    ylim([0, 1.05]);
    grid on;
    xlabel('foldNum: trials per block');
    ylabel('Prob-dv 3-class accuracy');
    title(['Point-level Prob-dv accuracy: ', groupName]);
    legend('Location', 'best', 'Interpreter', 'none');
end

saveas(fig, fullfile(settings.outputDir, 'foldnum_prob_accuracy_upper_lower.png'));
saveas(fig, fullfile(settings.outputDir, 'foldnum_prob_accuracy_upper_lower.fig'));
close(fig);

% 图 2：normal vs defect AUC，重点看 pDefect 和 rAbsDiff。
fig = figure('Visible', 'off', 'Position', [100, 100, 1200, 760], 'Color', 'w');
tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
plotMetrics = {'mean_pDefect', 'mean_rAbsDiff', 'mean_pMargin', 'mean_pEntropy'};

for group_i = 1:2
    nexttile;
    if group_i == 1
        groupName = 'upper';
    else
        groupName = 'lower';
    end

    hold on;
    colors = lines(numel(plotMetrics));
    for metric_i = 1:numel(plotMetrics)
        metricName = plotMetrics{metric_i};
        y = nan(size(settings.foldNumList));
        for fold_i = 1:numel(settings.foldNumList)
            foldNum = settings.foldNumList(fold_i);
            idx = aucTable.foldNum == foldNum & ...
                strcmp(aucTable.pointGroup, groupName) & ...
                strcmp(aucTable.metric, metricName);
            y(fold_i) = aucTable.bestAuc(idx);
        end
        plot(settings.foldNumList, y, '-o', 'LineWidth', 1.5, ...
            'Color', colors(metric_i, :), 'DisplayName', metricName);
    end
    hold off;
    ylim([0.4, 1.0]);
    grid on;
    xlabel('foldNum: trials per block');
    ylabel('normal-vs-defect best AUC');
    title(['AUC by foldNum: ', groupName]);
    legend('Location', 'best', 'Interpreter', 'none');
end

saveas(fig, fullfile(settings.outputDir, 'foldnum_auc_upper_lower.png'));
saveas(fig, fullfile(settings.outputDir, 'foldnum_auc_upper_lower.fig'));
close(fig);

% 图 3：rDiff 稳定性和 pEntropy。
fig = figure('Visible', 'off', 'Position', [100, 100, 1200, 760], 'Color', 'w');
tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

plotVars = {'std_rDiff', 'std_rNorm', 'mean_pMargin', 'mean_pEntropy'};
for var_i = 1:numel(plotVars)
    nexttile;
    varName = plotVars{var_i};
    hold on;
    colors = lines(2);
    for group_i = 1:2
        if group_i == 1
            groupName = 'upper';
        else
            groupName = 'lower';
        end
        y = nan(size(settings.foldNumList));
        for fold_i = 1:numel(settings.foldNumList)
            foldNum = settings.foldNumList(fold_i);
            idx = pointTable.foldNum == foldNum & ...
                strcmp(pointTable.pointGroup, groupName);
            y(fold_i) = mean(pointTable.(varName)(idx), 'omitnan');
        end
        plot(settings.foldNumList, y, '-o', 'LineWidth', 1.5, ...
            'Color', colors(group_i, :), 'DisplayName', groupName);
    end
    hold off;
    grid on;
    xlabel('foldNum: trials per block');
    ylabel(varName);
    title(varName);
    legend('Location', 'best', 'Interpreter', 'none');
end

saveas(fig, fullfile(settings.outputDir, 'foldnum_stability_probability.png'));
saveas(fig, fullfile(settings.outputDir, 'foldnum_stability_probability.fig'));
close(fig);

fprintf('\nDone. Please inspect results in:\n  %s\n', settings.outputDir);

%% Local helper: AUC without toolbox dependency
function aucValue = AI_local_auc(labels, scores)
    labels = labels(:);
    scores = scores(:);
    validIdx = ~isnan(scores) & ~isnan(labels);
    labels = labels(validIdx);
    scores = scores(validIdx);

    posNum = sum(labels == 1);
    negNum = sum(labels == 0);
    if posNum == 0 || negNum == 0
        aucValue = nan;
        return;
    end

    [sortedScores, order] = sort(scores);
    ranks = nan(size(scores));
    i = 1;
    while i <= numel(scores)
        j = i;
        while j < numel(scores) && sortedScores(j + 1) == sortedScores(i)
            j = j + 1;
        end
        ranks(order(i:j)) = mean(i:j);
        i = j + 1;
    end

    rankSumPos = sum(ranks(labels == 1));
    aucValue = (rankSumPos - posNum * (posNum + 1) / 2) / (posNum * negNum);
end
