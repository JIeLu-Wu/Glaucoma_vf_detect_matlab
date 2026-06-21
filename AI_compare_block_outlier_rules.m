%% AI_compare_block_outlier_rules
% 目的：
%   比较 block 水平离群值剔除前后，point 层级 DCPM 特征的表现是否改善。
%
% 重要原则：避免信息泄露
%   离群值筛查只使用当前测量点内部的 block 特征，例如 rDiff 和 rNorm。
%   不使用 scenario、expectedLabel、pNormal、pLeft、pRight、pDefect 等带有
%   视野状态含义或模型判别结论的字段来决定哪些 block 被剔除。
%
%   在真实应用中，我们不知道测试信号和模板信号代表的视野状态。
%   因此本脚本的离群规则模拟真实使用方式：
%       对每个 subject + 测量配置 + point 内部的多个 block 单独计算 median/MAD，
%       只根据该点内部 block 是否偏离本点自身分布来标记离群。
%
%   scenario/expectedLabel 只在最后评估剔除规则效果时使用，不参与剔除。
%
% 输入：
%   AI_dcpm_raw_feature_analysis_blocklevel.xlsx 中的 block_features
%
% 输出：
%   AI_block_outlier_rule_comparison.xlsx
%   AI_block_outlier_rule_comparison.mat

clear;
clc;

%% 1. 路径和基础参数
scriptDir = fileparts(mfilename('fullpath'));
projectDir = fileparts(scriptDir);
resultDir = fullfile(projectDir, char([32467 26524]));
analysisDir = fullfile(resultDir, 'AI_dcpm_raw_feature_analysis');

inputFile = fullfile(analysisDir, 'AI_dcpm_raw_feature_analysis_blocklevel.xlsx');
outputExcelFile = fullfile(analysisDir, 'AI_block_outlier_rule_comparison.xlsx');
outputMatFile = fullfile(analysisDir, 'AI_block_outlier_rule_comparison.mat');

if ~exist(inputFile, 'file')
    error('Input file not found: %s', inputFile);
end

% 如果某个点剔除后保留 block 数少于 minKeepBlocks，则该点不参与指标评估。
% 这里保守设为 8：原始每点大约 15 个 block，至少保留一半以上才认为稳定。
minKeepBlocks = 8;

% 需要重新计算 point 均值的 block 特征。
metricNames = {'r1', 'r2', 'rMean', 'rDiff', 'rAbsDiff', 'rNorm', ...
    'pNormal', 'pLeft', 'pRight', 'pDefect', 'pMargin', ...
    'cvAccAll', 'cvSeparability', ...
    'erpMeanAbs', 'erpRms', 'erpPeakToPeakAll', ...
    'blockTemplateCorr1', 'blockTemplateCorr2', 'blockTemplateCorrMean', ...
    'blockTemplateCorrDiff', 'blockTemplateCorrAbsDiff', 'blockTemplateCorrNorm'};

% 候选离群规则。
% none:
%   不剔除，用作基线。
%
% rDiff_mad35:
%   在每个测量点内部，仅根据 rDiff 的 robust z 标记离群。
%   rDiff 是最有用的方向特征，但该规则只看本点内部波动，不看真实标签。
%
% rDiff_rNorm_mad35:
%   同时根据 rDiff 和 rNorm 标记离群。
%   rNorm 可反映 DCPM 决策值整体强度异常。
%
% rDiff_rNorm_mad30:
%   更严格的阈值，用于观察剔除更多 block 是否会进一步改善或损害结果。
rules = struct([]);
rules(1).name = 'none';
rules(1).metrics = {};
rules(1).threshold = inf;

rules(2).name = 'rDiff_mad35';
rules(2).metrics = {'rDiff'};
rules(2).threshold = 3.5;

rules(3).name = 'rDiff_rNorm_mad35';
rules(3).metrics = {'rDiff', 'rNorm'};
rules(3).threshold = 3.5;

rules(4).name = 'rDiff_rNorm_mad30';
rules(4).metrics = {'rDiff', 'rNorm'};
rules(4).threshold = 3.0;

fprintf('Reading block features:\n  %s\n', inputFile);
blockTable = readtable(inputFile, 'Sheet', 'block_features');
fprintf('Loaded %d block rows.\n', height(blockTable));

%% 2. 构造“测量点”分组
% 这里刻意不使用 scenario 和 expectedLabel 做离群筛查。
% 分组只使用真实检测时已知的信息：
%   subjectIndex, point, train/test 文件类型, 模板构造方式和模板点位。
%
% 换句话说，规则只知道“这是某个被试某个检测点的一组 block”，
% 不知道它是 normal、left defect 还是 right defect。
measureKeyTable = blockTable(:, {'subjectIndex', 'subjectSet', 'point', ...
    'trainFileType', 'testFileType', 'useMixedTemplate', 'templateSwapped', ...
    'templatePoint1', 'templatePoint2', 'templateSource1', 'templateSource2'});
[measureGroup, ~] = findgroups(measureKeyTable);

%% 3. 对每条规则逐一标记离群 block，并重新计算 point 层级特征
allPointRows = {};
allBlockFlagTables = cell(numel(rules), 1);
ruleSummaryRows = {};

for rule_i = 1:numel(rules)
    rule = rules(rule_i);
    fprintf('\n==== Rule: %s ====\n', rule.name);

    isOutlier = false(height(blockTable), 1);
    maxRobustZ = zeros(height(blockTable), 1);

    if ~strcmp(rule.name, 'none')
        for group_i = 1:max(measureGroup)
            idx = measureGroup == group_i;

            for metric_i = 1:numel(rule.metrics)
                metricName = rule.metrics{metric_i};
                values = blockTable.(metricName)(idx);
                medValue = median(values, 'omitnan');
                madValue = median(abs(values - medValue), 'omitnan');

                robustZ = zeros(size(values));
                if madValue > 0
                    robustZ = abs(values - medValue) ./ (1.4826 * madValue);
                end

                idxNum = find(idx);
                maxRobustZ(idxNum) = max(maxRobustZ(idxNum), robustZ);
                isOutlier(idxNum) = isOutlier(idxNum) | robustZ > rule.threshold;
            end
        end
    end

    keepBlock = ~isOutlier;
    fprintf('Outlier blocks: %d / %d (%.2f%%)\n', ...
        sum(isOutlier), height(blockTable), 100 * mean(isOutlier));

    blockFlagTable = blockTable(:, {'scenario', 'subjectIndex', 'subjectSet', ...
        'point', 'block', 'trainFileType', 'testFileType', 'useMixedTemplate', ...
        'templatePoint1', 'templatePoint2', 'templateSource1', 'templateSource2', ...
        'r1', 'r2', 'rMean', 'rDiff', 'rAbsDiff', 'rNorm', ...
        'pNormal', 'pLeft', 'pRight', 'pDefect'});
    blockFlagTable.rule = repmat({rule.name}, height(blockFlagTable), 1);
    blockFlagTable.ruleMaxRobustZ = maxRobustZ;
    blockFlagTable.ruleIsOutlier = isOutlier;
    blockFlagTable.ruleKeepBlock = keepBlock;
    allBlockFlagTables{rule_i} = blockFlagTable;

    % 重新计算 point 层级均值。
    % 评估时需要知道 scenario，但 scenario 只在这里用于结果标注和最终评估。
    pointKeyTable = blockTable(:, {'scenario', 'subjectIndex', 'subjectSet', 'point'});
    [pointGroup, pointKeys] = findgroups(pointKeyTable);

    for pointGroup_i = 1:max(pointGroup)
        idxAll = pointGroup == pointGroup_i;
        idxKeep = idxAll & keepBlock;
        nAll = sum(idxAll);
        nKeep = sum(idxKeep);
        keepRatio = nKeep / nAll;
        validPoint = nKeep >= minKeepBlocks;

        row = cell(1, 0);
        row{end + 1} = rule.name;
        row{end + 1} = pointKeys.scenario{pointGroup_i};
        row{end + 1} = pointKeys.subjectIndex(pointGroup_i);
        row{end + 1} = pointKeys.subjectSet{pointGroup_i};
        row{end + 1} = pointKeys.point(pointGroup_i);
        row{end + 1} = nAll;
        row{end + 1} = nKeep;
        row{end + 1} = keepRatio;
        row{end + 1} = validPoint;

        for metric_i = 1:numel(metricNames)
            metricName = metricNames{metric_i};
            if validPoint
                values = blockTable.(metricName)(idxKeep);
                row{end + 1} = mean(values, 'omitnan');
                row{end + 1} = std(values, 0, 'omitnan');
            else
                row{end + 1} = nan;
                row{end + 1} = nan;
            end
        end

        allPointRows(end + 1, :) = row; %#ok<SAGROW>
    end

    ruleSummaryRows(end + 1, :) = { ...
        rule.name, height(blockTable), sum(isOutlier), mean(isOutlier), ...
        mean(keepBlock), minKeepBlocks}; %#ok<SAGROW>
end

pointVarNames = {'rule', 'scenario', 'subjectIndex', 'subjectSet', 'point', ...
    'nBlockAll', 'nBlockKeep', 'keepRatio', 'validPoint'};
for metric_i = 1:numel(metricNames)
    metricName = metricNames{metric_i};
    pointVarNames{end + 1} = ['mean_', metricName]; %#ok<SAGROW>
    pointVarNames{end + 1} = ['std_', metricName]; %#ok<SAGROW>
end

pointRuleTable = cell2table(allPointRows, 'VariableNames', pointVarNames);
blockFlagAll = vertcat(allBlockFlagTables{:});
ruleSummaryTable = cell2table(ruleSummaryRows, ...
    'VariableNames', {'rule', 'nBlockTotal', 'nBlockOutlier', ...
    'outlierRate', 'keepRate', 'minKeepBlocks'});

%% 4. 评估：剔除前后 normal-vs-defect 和 left-vs-right 是否改善
% 这里才使用 scenario 标签，但只用于评估，不反过来影响离群剔除。
aucRows = {};
directionRows = {};
retentionRows = {};

aucMetrics = {'mean_pDefect', 'mean_pNormal', 'mean_rAbsDiff', ...
    'mean_rNorm', 'mean_rMean', 'mean_cvAccAll', 'mean_cvSeparability', ...
    'mean_erpRms', 'mean_erpPeakToPeakAll', 'mean_blockTemplateCorrNorm', ...
    'mean_blockTemplateCorrAbsDiff'};

for rule_i = 1:numel(rules)
    ruleName = rules(rule_i).name;
    subTable = pointRuleTable(strcmp(pointRuleTable.rule, ruleName) & ...
        pointRuleTable.validPoint, :);

    yDefect = ~strcmp(subTable.scenario, 'normal');
    for metric_i = 1:numel(aucMetrics)
        metricName = aucMetrics{metric_i};
        score = subTable.(metricName);
        aucHigh = AI_local_auc(yDefect, score);
        aucLow = AI_local_auc(yDefect, -score);

        if aucHigh >= aucLow
            bestAuc = aucHigh;
            direction = 'high_defect';
        else
            bestAuc = aucLow;
            direction = 'low_defect';
        end

        aucRows(end + 1, :) = {ruleName, 'normal_vs_any_defect', ...
            metricName, aucHigh, aucLow, bestAuc, direction, sum(yDefect), sum(~yDefect)}; %#ok<SAGROW>
    end

    lrTable = subTable(~strcmp(subTable.scenario, 'normal'), :);
    isLeft = contains(lrTable.scenario, 'left');

    directionMetrics = {'mean_rDiff', 'mean_blockTemplateCorrDiff'};
    for metric_i = 1:numel(directionMetrics)
        metricName = directionMetrics{metric_i};
        score = lrTable.(metricName);
        aucHighLeft = AI_local_auc(isLeft, score);
        aucHighRight = AI_local_auc(isLeft, -score);
        bestAuc = max(aucHighLeft, aucHighRight);

        predLeft = score >= 0;
        signAcc = mean(predLeft == isLeft, 'omitnan');

        directionRows(end + 1, :) = {ruleName, metricName, ...
            aucHighLeft, aucHighRight, bestAuc, signAcc, height(lrTable)}; %#ok<SAGROW>
    end

    retentionRows(end + 1, :) = {ruleName, height(subTable), ...
        mean(subTable.nBlockKeep), min(subTable.nBlockKeep), ...
        sum(~pointRuleTable.validPoint & strcmp(pointRuleTable.rule, ruleName)), ...
        mean(subTable.keepRatio)}; %#ok<SAGROW>
end

aucTable = cell2table(aucRows, ...
    'VariableNames', {'rule', 'comparison', 'metric', 'aucHigh', ...
    'aucLow', 'bestAuc', 'direction', 'nDefect', 'nNormal'});

directionTable = cell2table(directionRows, ...
    'VariableNames', {'rule', 'metric', 'aucHighLeft', ...
    'aucHighRight', 'bestAuc', 'signAccuracy', 'nPoint'});

retentionTable = cell2table(retentionRows, ...
    'VariableNames', {'rule', 'nValidPoint', 'meanKeepBlock', ...
    'minKeepBlock', 'nInvalidPoint', 'meanKeepRatio'});

%% 5. 输出
writetable(ruleSummaryTable, outputExcelFile, 'Sheet', 'rule_summary');
writetable(retentionTable, outputExcelFile, 'Sheet', 'retention');
writetable(aucTable, outputExcelFile, 'Sheet', 'auc_normal_defect');
writetable(directionTable, outputExcelFile, 'Sheet', 'direction_left_right');
writetable(pointRuleTable, outputExcelFile, 'Sheet', 'point_summary_by_rule');
writetable(blockFlagAll, outputExcelFile, 'Sheet', 'block_flags');

save(outputMatFile, 'blockTable', 'blockFlagAll', 'pointRuleTable', ...
    'ruleSummaryTable', 'retentionTable', 'aucTable', 'directionTable', ...
    'rules', 'metricNames', 'minKeepBlocks', '-v7.3');

fprintf('\nSaved comparison Excel:\n  %s\n', outputExcelFile);
fprintf('Saved comparison MAT:\n  %s\n', outputMatFile);

%% 6. 控制台打印最关键结果
fprintf('\n==== Direction accuracy by rule ====\n');
disp(directionTable);

fprintf('\n==== Best AUC for key metrics ====\n');
keyAuc = aucTable(ismember(aucTable.metric, ...
    {'mean_pDefect', 'mean_rAbsDiff', 'mean_rNorm', 'mean_cvAccAll'}), :);
disp(keyAuc);

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
