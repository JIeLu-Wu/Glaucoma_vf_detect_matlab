%% AI_dcpm_raw_feature_analysis
% 目的：
%   分析当前个体模板 DCPM 检测流程中，原始决策值和基础信号特征在不同
%   模拟视野缺损条件下的分布。
%
% 使用方式：
%   直接在 MATLAB 当前路径运行：
%       AI_dcpm_raw_feature_analysis
%
% 输出：
%   1) 每个 scenario / subject / point / block 的特征表
%   2) 每个 scenario / subject / point 的点位均值表
%   3) 若干分布图，用于观察 r1/r2/r_diff/r_norm/ERP 强度等特征是否可用
%
% 说明：
%   这个脚本不修改现有主流程，不写入原始数据目录。
%   这里只讨论单眼缺损相关的模拟条件；双眼缺损/无响应情况暂不建模。

clear;
clc;

%% 1. 基本参数
% 这些参数与当前 AI_qikan_acc_all_probmean.m 保持一致，方便和已有结果对照。
settings = struct();
settings.fs = 250;
settings.tStart = 0;
settings.tEnd = 0.45;
settings.WnPara = [0.5, 2, 20, 30];
settings.chanList = 44:64;

settings.trainTrialNum = 80;
settings.testTrialNum = 60;
settings.foldNum = 4;              % 每 4 个测试试次叠加成一个 DCPM 决策值 block
settings.crossNum = 10;            % 模板内部 10 折交叉验证
settings.dcpmComponent = 8;

% 离群点标记规则：在每个 scenario-subject-point 内，对部分特征做 robust z。
% 这里只做标记，不自动删除；画图时可选择是否排除。
settings.outlierMadThreshold = 3.5;
settings.excludeOutliersInPlots = true;

% 路径设置。脚本默认放在 data_processing-20 文件夹内。
settings.scriptDir = fileparts(mfilename('fullpath'));
settings.projectDir = fileparts(settings.scriptDir);
settings.dataRoot = fullfile(settings.projectDir, 'data', char([23567 35770 25991 25968 25454]));
settings.resultDir = fullfile(settings.projectDir, char([32467 26524]));
settings.outputDir = fullfile(settings.resultDir, 'AI_dcpm_raw_feature_analysis');
settings.excelFile = fullfile(settings.outputDir, 'AI_dcpm_raw_feature_analysis_blocklevel.xlsx');
settings.matFile = fullfile(settings.outputDir, 'AI_dcpm_raw_feature_analysis_blocklevel.mat');

if ~exist(settings.outputDir, 'dir')
    mkdir(settings.outputDir);
end

fprintf('Output folder:\n  %s\n', settings.outputDir);

%% 2. 五种模拟条件配置
% tempType 每一行对应一个检测点，两个数表示用于构造二分类模板的两个事件类型。
% 例如第 3 行 [3,4] 表示当前检测点 P3 使用 P3/P4 作为一对模板。
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
% 默认读取：
%   D:\0课题\青光眼\data\小论文数据\sub*
%   D:\0课题\青光眼\data\小论文数据\250ms\sub*
% 如果后续路径变化，只需要改 settings.dataRoot。
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

%% 4. 主循环：读取数据、构造模板、提取 DCPM 决策值和信号特征
% 每个 row 对应一个测试 block：
%   scenario-subject-point-block
%
% 主要特征：
%   r1/r2              : DCPM 原始模板相关系数
%   rMean/rDiff/rNorm : 决策值强度和方向特征
%   pNormal/pLeft/pRight: 当前概率归一化评分，用于和原方法对照
%   cv*               : 模板内部交叉验证质量
%   erp*              : 测试 block 叠加 ERP 的基础强度特征
%   blockTemplate*    : 测试 block 叠加 ERP 与模板平均 ERP 的相关性

featureRows = struct([]);
row_i = 0;

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
                % 兼容旧脚本中的写法：如果文件夹末尾附近带有 R，则交换模板。
                % 当前自动搜索到的 sub1/sub2/... 通常不会触发该规则。
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
            templateErp1 = mean(template(:, :, :, 1), 3);
            templateErp2 = mean(template(:, :, :, 2), 3);

            % 4.1 模板内部交叉验证：用于评价模板质量和可分性。
            % ------------------------------------------------------------
            % 这里不是在检测测试数据，而是只用训练模板自身做交叉验证：
            %   class1 模板留出一部分作为测试，剩余 class1/class2 构建 DCPM；
            %   class2 同理。
            %
            % 这样可以得到四类模板内部决策值：
            %   R11：class1 测试样本与 class1 模板的匹配值，理想情况下应较高；
            %   R12：class1 测试样本与 class2 模板的匹配值，理想情况下应较低；
            %   R21：class2 测试样本与 class1 模板的匹配值，理想情况下应较低；
            %   R22：class2 测试样本与 class2 模板的匹配值，理想情况下应较高。
            %
            % 后续的 cvAccAll / cvSeparability 可以理解为“这个点的模板质量”：
            % 如果模板自身都难以区分，那么测试阶段即使输出了方向性结果，
            % 也应该降低该点结论的可靠性。
            RR_cross = DCPM_cross_valid(template, settings.dcpmComponent, settings.crossNum);
            cvBlockNum = floor(size(RR_cross, 1) / settings.foldNum);
            RR_cross_fold = nan(cvBlockNum, size(RR_cross, 2), size(RR_cross, 3));
            for block_i = 1:cvBlockNum
                idx = (block_i - 1) * settings.foldNum + 1:block_i * settings.foldNum;
                RR_cross_fold(block_i, :, :) = mean(RR_cross(idx, :, :), 1);
            end
            [~, rouCross] = max(RR_cross_fold, [], 2);
            rouCross = squeeze(rouCross);

            if size(rouCross, 2) < 2
                cvAccClass1 = nan;
                cvAccClass2 = nan;
            else
                cvAccClass1 = mean(rouCross(:, 1) == 1, 'omitnan');
                cvAccClass2 = mean(rouCross(:, 2) == 2, 'omitnan');
            end
            cvAccAll = mean([cvAccClass1, cvAccClass2], 'omitnan');

            R11 = RR_cross_fold(:, 1, 1);
            R12 = RR_cross_fold(:, 2, 1);
            R21 = RR_cross_fold(:, 1, 2);
            R22 = RR_cross_fold(:, 2, 2);

            % class1 / class2 的模板间隔。
            %   cvMarginClass1 = mean(R11 - R12)
            %   cvMarginClass2 = mean(R22 - R21)
            % 如果该值越大，说明正确模板相似度比错误模板相似度高得越明显。
            % cvSeparability 是两类 margin 的总体平均，可作为模板可分性的粗指标。
            cvMarginClass1 = mean(R11 - R12, 'omitnan');
            cvMarginClass2 = mean(R22 - R21, 'omitnan');
            cvSeparability = mean([R11 - R12; R22 - R21], 'omitnan');

            % 与 glc_detection_prob.m 保持一致：
            % 概率模型只使用交叉验证中正确分类的 class1/class2 block。
            TP_index = rouCross(:, 1) == 1;
            TN_index = rouCross(:, 2) == 2;
            TP_value = RR_cross_fold(TP_index, :, 1);
            TN_value = RR_cross_fold(TN_index, :, 2);
            all_ave = cat(1, mean(TP_value, 1), mean(TN_value, 1));
            all_std = cat(1, std(TP_value, [], 1), std(TN_value, [], 1));

            % 4.2 测试数据 DCPM 决策值。
            % ------------------------------------------------------------
            % RR 是单试次层面的 DCPM 模板相关性：
            %   RR(trial, 1) = 当前测试试次与模板1的相关性 r1
            %   RR(trial, 2) = 当前测试试次与模板2的相关性 r2
            %
            % 因为单试次信噪比低，这里保持你现有方法，每 settings.foldNum 个试次
            % 先平均一次，得到 RR_fold。后面的所有 block 特征都基于 RR_fold。
            RR = Multi_DSPm(settings.dcpmComponent, template, testTrials);
            testBlockNum = floor(size(RR, 1) / settings.foldNum);
            RR_fold = nan(testBlockNum, size(RR, 2));
            for block_i = 1:testBlockNum
                idx = (block_i - 1) * settings.foldNum + 1:block_i * settings.foldNum;
                RR_fold(block_i, :) = mean(RR(idx, :), 1);
            end

            Prob_dv = Prob_calculate(RR_fold, all_ave, all_std);

            % 4.3 每个测试 block 提取 DCPM 和叠加 ERP 特征。
            % ------------------------------------------------------------
            % 这一部分是本脚本最重要的分析单元：
            %   一个 row = 一个 scenario + 一个被试 + 一个点位 + 一个叠加 block。
            %
            % 注意：
            %   这里不再计算固定 P1/N1 时间窗特征，因为 P1/N1 潜伏期存在
            %   明显个体差异和点位差异，固定窗口可能导致指标不稳定。
            %
            %   这里也不再计算 block 内单试次一致性特征。单试次信噪比低，
            %   若要分析试次层级，也应先把 block 内试次叠加成一个“叠加试次”
            %   后再计算特征。因此本节只使用 blockErp 这个叠加后的波形。
            %
            % 后续先看这些 row 的分布，而不是急着建立新 VFI/MD。
            for block_i = 1:testBlockNum
                trialIdx = (block_i - 1) * settings.foldNum + 1:block_i * settings.foldNum;
                blockTrials = testTrials(:, :, trialIdx);
                blockErp = mean(blockTrials, 3);

                r1 = RR_fold(block_i, 1);
                r2 = RR_fold(block_i, 2);

                % DCPM 原始决策值特征：
                %   r1/r2:
                %       测试 block 与两个模板的原始相关性。
                %
                %   rMean = mean([r1, r2]):
                %       整体正相关水平。强正常响应常表现为 r1、r2 都大于 0，
                %       因而 rMean 偏高；远偏心弱响应或低质量数据可能 rMean 偏低。
                %
                %   rDiff = r1 - r2:
                %       模板偏向方向。它是识别左/右单眼缺损最直接的方向性特征。
                %       具体正负号含义取决于当前点位模板1/模板2对应关系。
                %
                %   rAbsDiff = abs(rDiff):
                %       不考虑方向，只看偏向强度。正常 BM 响应理论上更接近平衡，
                %       单眼缺损时通常更偏向某一个模板。
                %
                %   rNorm = sqrt(r1^2 + r2^2):
                %       DCPM 决策值向量长度，可理解为“整体匹配强度”。
                %       与 rMean 不同，rNorm 不区分正负，只看离原点远近。
                rMean = mean([r1, r2], 'omitnan');
                rDiff = r1 - r2;
                rAbsDiff = abs(rDiff);
                rNorm = sqrt(r1 .^ 2 + r2 .^ 2);
                rSum = r1 + r2;

                % 原方法的三类概率评分。
                % 这里保留下来主要用于对照：
                %   pNormal:      归一化后“正常”的相对评分
                %   pLeft/pRight: 归一化后“左/右眼缺损”的相对评分
                %   pDefect:      pLeft + pRight
                %   pMargin:      最大概率与第二大概率的差，表示分类信心
                %   pEntropy:     概率分布熵，越大表示三类越不确定
                %
                % 注意：这些概率是相对归一化评分，不等价于真实临床功能保留程度。
                % 这也是本脚本需要进一步分析原始特征的原因。
                probNow = Prob_dv(:, block_i);
                probNow = probNow ./ sum(probNow);
                pNormal = probNow(1);
                pLeft = probNow(2);
                pRight = probNow(3);
                pDefect = pLeft + pRight;
                [pMax, labelProb] = max(probNow);
                probSorted = sort(probNow, 'descend');
                pMargin = probSorted(1) - probSorted(2);
                pEntropy = -sum(probNow .* log(probNow + eps));

                % ERP 整体强度特征。
                %   erpMeanAbs:
                %       叠加 ERP 全通道全时间点的平均绝对幅值。
                %
                %   erpRms:
                %       叠加 ERP 的均方根幅值，对大幅度响应更敏感。
                %
                %   erpPeakToPeakAll:
                %       每个通道刺激后波形最大值-最小值，再对通道平均。
                %       可以粗略反映 ERP 波形起伏强度。
                %
                % 这些指标不直接判断左右缺损方向，主要用于判断“这个点有没有
                % 足够强的诱发响应”，后续可作为 response strength。
                erpMeanAbs = mean(abs(blockErp(:)), 'omitnan');
                erpRms = sqrt(mean(blockErp(:) .^ 2, 'omitnan'));
                erpPeakToPeakAll = mean(max(blockErp, [], 2) - min(blockErp, [], 2), 'omitnan');

                % 叠加 ERP 与模板平均 ERP 的原始波形相关性。
                %   blockTemplateCorr1/2:
                %       blockErp 与两个模板平均波形的相关性，不经过 DCPM 空间滤波。
                %       它仍然是在叠加试次层级计算，不使用单试次。
                %
                %   blockTemplateCorrDiff:
                %       原始波形层面的模板偏向，作为 rDiff 的补充参考。
                %
                %   blockTemplateCorrNorm:
                %       原始波形层面的整体模板匹配强度。
                blockTemplateCorr1 = nan;
                blockTemplateCorr2 = nan;
                blockVec = blockErp(:);
                templateVec1 = templateErp1(:);
                templateVec2 = templateErp2(:);
                if std(blockVec) > 0 && std(templateVec1) > 0
                    c = corrcoef(blockVec, templateVec1);
                    blockTemplateCorr1 = c(1, 2);
                end
                if std(blockVec) > 0 && std(templateVec2) > 0
                    c = corrcoef(blockVec, templateVec2);
                    blockTemplateCorr2 = c(1, 2);
                end
                blockTemplateCorrMean = mean([blockTemplateCorr1, blockTemplateCorr2], 'omitnan');
                blockTemplateCorrDiff = blockTemplateCorr1 - blockTemplateCorr2;
                blockTemplateCorrAbsDiff = abs(blockTemplateCorrDiff);
                blockTemplateCorrNorm = sqrt(blockTemplateCorr1 .^ 2 + blockTemplateCorr2 .^ 2);

                row_i = row_i + 1;
                featureRows(row_i).scenario = cfg.name;
                featureRows(row_i).subjectIndex = sub_i;
                featureRows(row_i).subjectSet = subjectSet{sub_i};
                featureRows(row_i).subjectDir = subDir;
                featureRows(row_i).point = point_i;
                featureRows(row_i).block = block_i;
                featureRows(row_i).expectedLabel = cfg.expectedLabel;
                featureRows(row_i).trainFileType = cfg.trainFileType;
                featureRows(row_i).testFileType = cfg.testFileType;
                featureRows(row_i).useMixedTemplate = cfg.useMixedTemplate;
                featureRows(row_i).templateSwapped = needSwap;
                featureRows(row_i).templatePoint1 = templatePoint(1);
                featureRows(row_i).templatePoint2 = templatePoint(2);
                featureRows(row_i).templateSource1 = templateSource{1};
                featureRows(row_i).templateSource2 = templateSource{2};
                featureRows(row_i).trainEventType = typeAllTrain(point_i);
                featureRows(row_i).testEventType = typeAllTest(point_i);

                featureRows(row_i).r1 = r1;
                featureRows(row_i).r2 = r2;
                featureRows(row_i).rMean = rMean;
                featureRows(row_i).rDiff = rDiff;
                featureRows(row_i).rAbsDiff = rAbsDiff;
                featureRows(row_i).rNorm = rNorm;
                featureRows(row_i).rSum = rSum;

                featureRows(row_i).pNormal = pNormal;
                featureRows(row_i).pLeft = pLeft;
                featureRows(row_i).pRight = pRight;
                featureRows(row_i).pDefect = pDefect;
                featureRows(row_i).pMax = pMax;
                featureRows(row_i).pMargin = pMargin;
                featureRows(row_i).pEntropy = pEntropy;
                featureRows(row_i).labelProb = labelProb;

                featureRows(row_i).cvAccAll = cvAccAll;
                featureRows(row_i).cvAccClass1 = cvAccClass1;
                featureRows(row_i).cvAccClass2 = cvAccClass2;
                featureRows(row_i).cvR11Mean = mean(R11, 'omitnan');
                featureRows(row_i).cvR12Mean = mean(R12, 'omitnan');
                featureRows(row_i).cvR21Mean = mean(R21, 'omitnan');
                featureRows(row_i).cvR22Mean = mean(R22, 'omitnan');
                featureRows(row_i).cvR11Std = std(R11, 0, 'omitnan');
                featureRows(row_i).cvR12Std = std(R12, 0, 'omitnan');
                featureRows(row_i).cvR21Std = std(R21, 0, 'omitnan');
                featureRows(row_i).cvR22Std = std(R22, 0, 'omitnan');
                featureRows(row_i).cvMarginClass1 = cvMarginClass1;
                featureRows(row_i).cvMarginClass2 = cvMarginClass2;
                featureRows(row_i).cvSeparability = cvSeparability;

                featureRows(row_i).erpMeanAbs = erpMeanAbs;
                featureRows(row_i).erpRms = erpRms;
                featureRows(row_i).erpPeakToPeakAll = erpPeakToPeakAll;
                featureRows(row_i).blockTemplateCorr1 = blockTemplateCorr1;
                featureRows(row_i).blockTemplateCorr2 = blockTemplateCorr2;
                featureRows(row_i).blockTemplateCorrMean = blockTemplateCorrMean;
                featureRows(row_i).blockTemplateCorrDiff = blockTemplateCorrDiff;
                featureRows(row_i).blockTemplateCorrAbsDiff = blockTemplateCorrAbsDiff;
                featureRows(row_i).blockTemplateCorrNorm = blockTemplateCorrNorm;
            end
        end
    end
end

if isempty(featureRows)
    error('No feature rows were generated. Please check data paths and CNT files.');
end

featureTable = struct2table(featureRows);

%% 5. 离群 block 标记
% 在每个 scenario-subject-point 内，分别对 rDiff、rNorm、ERP 峰峰值做 robust z。
% 当前只做标记，不直接删除，方便比较“保留全部”和“排除离群”的结果。
%
% 为什么用 median/MAD 而不是均值/标准差：
%   block 数量不多，且 EEG 里偶发伪迹可能很大；
%   median 和 MAD 对极端值不敏感，更适合初步标记异常 block。
%
% isOutlier = true 只表示“这个 block 在本点位内部看起来异常”，不等于坏数据。
% 后续如果发现剔除后分布更清楚，可以再考虑正式制定剔除规则。
featureTable.rDiffRobustZ = nan(height(featureTable), 1);
featureTable.rNormRobustZ = nan(height(featureTable), 1);
featureTable.erpPeakToPeakRobustZ = nan(height(featureTable), 1);
featureTable.isOutlier = false(height(featureTable), 1);

[G, ~] = findgroups(featureTable.scenario, featureTable.subjectIndex, featureTable.point);
for group_i = 1:max(G)
    idx = G == group_i;

    values = featureTable.rDiff(idx);
    medValue = median(values, 'omitnan');
    madValue = median(abs(values - medValue), 'omitnan');
    if madValue > 0
        featureTable.rDiffRobustZ(idx) = abs(values - medValue) ./ (1.4826 * madValue);
    end

    values = featureTable.rNorm(idx);
    medValue = median(values, 'omitnan');
    madValue = median(abs(values - medValue), 'omitnan');
    if madValue > 0
        featureTable.rNormRobustZ(idx) = abs(values - medValue) ./ (1.4826 * madValue);
    end

    values = featureTable.erpPeakToPeakAll(idx);
    medValue = median(values, 'omitnan');
    madValue = median(abs(values - medValue), 'omitnan');
    if madValue > 0
        featureTable.erpPeakToPeakRobustZ(idx) = abs(values - medValue) ./ (1.4826 * madValue);
    end
end

featureTable.isOutlier = featureTable.rDiffRobustZ > settings.outlierMadThreshold | ...
    featureTable.rNormRobustZ > settings.outlierMadThreshold | ...
    featureTable.erpPeakToPeakRobustZ > settings.outlierMadThreshold;

fprintf('\nGenerated %d feature rows. Outlier blocks: %d\n', ...
    height(featureTable), sum(featureTable.isOutlier));

%% 6. 点位级和场景级汇总
% 点位级汇总用于看“某个被试某个点”的平均特征。
% 场景级汇总用于看五种模拟条件的总体分布趋势。
%
% block_features:
%   最细粒度结果，适合画分布、看离群点、做 block 级模型。
%
% point_summary:
%   把同一个 subject-point 的多个 block 平均，适合看点位级结果。
%
% scenario_summary:
%   按 scenario-point 汇总，适合快速观察不同模拟缺损条件的总体趋势。
metricNames = {'r1', 'r2', 'rMean', 'rDiff', 'rAbsDiff', 'rNorm', ...
    'pNormal', 'pLeft', 'pRight', 'pDefect', 'pMargin', ...
    'cvAccAll', 'cvSeparability', ...
    'erpMeanAbs', 'erpRms', 'erpPeakToPeakAll', ...
    'blockTemplateCorr1', 'blockTemplateCorr2', 'blockTemplateCorrMean', ...
    'blockTemplateCorrDiff', 'blockTemplateCorrAbsDiff', 'blockTemplateCorrNorm'};

summaryInput = featureTable;
if settings.excludeOutliersInPlots
    summaryInput = featureTable(~featureTable.isOutlier, :);
end

pointSummaryTable = groupsummary(summaryInput, ...
    {'scenario', 'subjectIndex', 'subjectSet', 'point'}, ...
    {'mean', 'std'}, metricNames);

scenarioSummaryTable = groupsummary(summaryInput, ...
    {'scenario', 'point'}, {'mean', 'std'}, metricNames);

%% 7. 导出 Excel 和 MAT
writetable(featureTable, settings.excelFile, 'Sheet', 'block_features');
writetable(pointSummaryTable, settings.excelFile, 'Sheet', 'point_summary');
writetable(scenarioSummaryTable, settings.excelFile, 'Sheet', 'scenario_summary');
save(settings.matFile, 'featureTable', 'pointSummaryTable', ...
    'scenarioSummaryTable', 'settings', 'scenarios', '-v7.3');

fprintf('Saved Excel:\n  %s\n', settings.excelFile);
fprintf('Saved MAT:\n  %s\n', settings.matFile);

%% 8. 图 1：r1-r2 决策值散点图
% 观察不同模拟条件在 DCPM 决策值平面中的分布：
%   正常强响应：理论上 r1 和 r2 都大于 0，且接近 y=x
%   单眼缺损：理论上一个模板相关性高，另一个低，偏离 y=x
%   低响应点：可能靠近原点，即使没有缺损也不一定 r1/r2 明显大于 0
%
% 读图重点：
%   1) normal 是否主要沿 y=x 分布；
%   2) left/right defect 是否分别偏向 y=x 的两侧；
%   3) 是否存在大量靠近原点的点，这些点后续可能需要 reliability 标记。
plotTable = featureTable;
if settings.excludeOutliersInPlots
    plotTable = plotTable(~plotTable.isOutlier, :);
end

fig = figure('Visible', 'off', 'Position', [100, 100, 1300, 760], 'Color', 'w');
tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
allR = [plotTable.r1; plotTable.r2];
axisMin = min(allR, [], 'omitnan');
axisMax = max(allR, [], 'omitnan');
axisPad = 0.05 * max(axisMax - axisMin, eps);
axisRange = [axisMin - axisPad, axisMax + axisPad];

for scenario_i = 1:numel(scenarios)
    nexttile;
    cfg = scenarios(scenario_i);
    idx = strcmp(plotTable.scenario, cfg.name);
    scatter(plotTable.r1(idx), plotTable.r2(idx), 18, 'filled');
    hold on;
    plot(axisRange, axisRange, 'k--', 'LineWidth', 1);
    plot([0, 0], axisRange, ':', 'Color', [0.4, 0.4, 0.4]);
    plot(axisRange, [0, 0], ':', 'Color', [0.4, 0.4, 0.4]);
    hold off;
    xlim(axisRange);
    ylim(axisRange);
    axis square;
    grid on;
    xlabel('r1');
    ylabel('r2');
    title(strrep(cfg.name, '_', '\_'));
end

nexttile;
scatter(plotTable.r1, plotTable.r2, 12, 'filled');
hold on;
plot(axisRange, axisRange, 'k--', 'LineWidth', 1);
plot([0, 0], axisRange, ':', 'Color', [0.4, 0.4, 0.4]);
plot(axisRange, [0, 0], ':', 'Color', [0.4, 0.4, 0.4]);
hold off;
xlim(axisRange);
ylim(axisRange);
axis square;
grid on;
xlabel('r1');
ylabel('r2');
title('all scenarios');

saveas(fig, fullfile(settings.outputDir, 'scatter_r1_r2.png'));
saveas(fig, fullfile(settings.outputDir, 'scatter_r1_r2.fig'));
close(fig);

%% 9. 图 2：核心 DCPM 特征箱线图
% rDiff 看方向，rAbsDiff 看偏向强度，rNorm/rMean 看整体响应强度。
%
% 建议优先观察：
%   rDiff:
%       left defect 和 right defect 的方向是否相反。
%   rAbsDiff:
%       缺损条件是否比 normal 更大。
%   rMean/rNorm:
%       是否能反映弱响应点或远偏心点。
boxMetrics = {'rMean', 'rDiff', 'rAbsDiff', 'rNorm'};
fig = figure('Visible', 'off', 'Position', [100, 100, 1300, 760], 'Color', 'w');
tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
scenarioCat = categorical(plotTable.scenario, scenarioOrder, scenarioOrder);

for metric_i = 1:numel(boxMetrics)
    nexttile;
    metricName = boxMetrics{metric_i};
    boxplot(plotTable.(metricName), scenarioCat);
    grid on;
    ylabel(metricName);
    title(metricName);
    set(gca, 'XTickLabelRotation', 25);
end

saveas(fig, fullfile(settings.outputDir, 'box_dcpm_features.png'));
saveas(fig, fullfile(settings.outputDir, 'box_dcpm_features.fig'));
close(fig);

%% 10. 图 3：叠加 ERP 和模板匹配特征箱线图
% 这些特征全部在 block 叠加后的波形层级计算：
%   erpMeanAbs / erpRms / erpPeakToPeakAll:
%       反映叠加 ERP 的整体响应强度，不依赖固定 P1/N1 时间窗。
%
%   blockTemplateCorrNorm:
%       反映叠加 ERP 与两个个体模板平均波形的总体匹配强度。
%
% 如果某些点 DCPM 判别差，同时 ERP 整体强度和模板匹配强度都低，
% 后续可考虑把它标记为低响应/低可靠点，而不是直接解释为缺损。
boxMetrics = {'erpMeanAbs', 'erpRms', 'erpPeakToPeakAll', 'blockTemplateCorrNorm'};
fig = figure('Visible', 'off', 'Position', [100, 100, 1300, 760], 'Color', 'w');
tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

for metric_i = 1:numel(boxMetrics)
    nexttile;
    metricName = boxMetrics{metric_i};
    boxplot(plotTable.(metricName), scenarioCat);
    grid on;
    ylabel(metricName);
    title(metricName);
    set(gca, 'XTickLabelRotation', 25);
end

saveas(fig, fullfile(settings.outputDir, 'box_block_erp_template_features.png'));
saveas(fig, fullfile(settings.outputDir, 'box_block_erp_template_features.fig'));
close(fig);

%% 11. 图 4：方向特征与响应强度特征的关系
% 横轴 rDiff 表示模板偏向，纵轴 rNorm 表示整体匹配强度。
% 这个图可以帮助区分：
%   高强度且接近平衡：可能正常强响应
%   高强度且明显偏向：可能单眼缺损
%   低强度且接近平衡：可能弱响应点，不应直接用概率评分解释为缺损
%
% 这张图对应后续“方向-强度-可靠性”框架中的前两维：
%   rDiff -> direction score
%   rNorm -> response strength
% 之后可把叠加 ERP 强度、模板匹配强度、模板交叉验证质量叠加进
% 第三维 reliability score。
fig = figure('Visible', 'off', 'Position', [100, 100, 900, 760], 'Color', 'w');
hold on;
colors = lines(numel(scenarios));
for scenario_i = 1:numel(scenarios)
    idx = strcmp(plotTable.scenario, scenarios(scenario_i).name);
    scatter(plotTable.rDiff(idx), plotTable.rNorm(idx), 18, colors(scenario_i, :), ...
        'filled', 'DisplayName', scenarios(scenario_i).name);
end
yLimits = ylim;
plot([0, 0], yLimits, 'k--', 'LineWidth', 1);
hold off;
grid on;
xlabel('rDiff = r1 - r2');
ylabel('rNorm = sqrt(r1^2 + r2^2)');
legend('Location', 'best', 'Interpreter', 'none');
title('DCPM direction vs response strength');

saveas(fig, fullfile(settings.outputDir, 'scatter_rDiff_rNorm.png'));
saveas(fig, fullfile(settings.outputDir, 'scatter_rDiff_rNorm.fig'));
close(fig);

fprintf('\nDone. Please inspect the Excel tables and figures in:\n  %s\n', settings.outputDir);
