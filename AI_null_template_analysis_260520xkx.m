function result = AI_null_template_analysis_260520xkx()
%AI_NULL_TEMPLATE_ANALYSIS_260520XKX Analyze null-test matching cases.
%
% Case 1: test = group7 null/Bilateral defect, template = null + RE.
% Case 2: test = group7 null/Bilateral defect, template = null + null.
%
% Outputs keep the original test decision values RR_fold (N x 2) and
% probability-like normalized likelihood scores Prob_dv (3 x N).

    settings = AI_settings();
    if ~exist(settings.outputDir, 'dir')
        mkdir(settings.outputDir);
    end

    fprintf('Loading clinical CNT data...\n');
    nullTrain = AI_load_cnt(fullfile(settings.dataDir, 'train7.cnt'), settings, settings.trainTrialTotal);
    nullTest = AI_load_cnt(fullfile(settings.dataDir, 'test7.cnt'), settings, settings.testTrialTotal);
    reTrain = AI_load_cnt(fullfile(settings.dataDir, 'train3.cnt'), settings, settings.trainTrialTotal);

    caseList = AI_case_list();
    result = struct();
    result.settings = settings;
    result.case = cell(numel(caseList), 1);

    longRows = {};

    for case_i = 1:numel(caseList)
        caseCfg = caseList(case_i);
        fprintf('\n==== Running %s ====\n', caseCfg.name);

        caseResult = AI_run_one_case(caseCfg, settings, nullTrain, reTrain, nullTest);
        result.case{case_i} = caseResult;
        longRows = [longRows; caseResult.longRows]; %#ok<AGROW>
    end

    result.longTable = cell2table(longRows, 'VariableNames', AI_long_table_names());

    save(settings.matFile, 'result', '-v7.3');
    writetable(result.longTable, settings.excelFile, 'Sheet', 'RR_and_Prob');

    fprintf('\nSaved MAT result: %s\n', settings.matFile);
    fprintf('Saved Excel long table: %s\n', settings.excelFile);

    % 画图
    figure(1)
    for i = 1:4
        ax = subplot(2,2,i);
        ax = connected_dot_plot(result.case{1,1}.RR_fold{i},['Stim',num2str(i)], ax);
    end
    subtitle("模板2为右眼")

    figure(2)
    for i = 1:4
        ax = subplot(2,2,i);
        ax = connected_dot_plot(result.case{2,1}.RR_fold{i},['Stim',num2str(i)], ax);
    end
    subtitle("模板均为缺损")
end

function settings = AI_settings()
    settings.fs = 250;
    settings.tStart = 0;
    settings.tEnd = 0.45;
    settings.WnPara = [0.5, 2, 20, 30];
    settings.chanList = 44:64;

    settings.trainTrialTotal = 480;
    settings.testTrialTotal = 360;
    settings.trainTrialNum = 80;
    settings.testTrialNum = 60;
    settings.foldNum = 4;
    settings.tempType = [1,2; 2,1; 3,4; 4,3];

    settings.dataDir = char([68 58 92 48 35838 39064 92 38738 20809 30524 ...
        92 100 97 116 97 92 20020 24202 23454 39564 92 50 54 48 53 50 48 120 107 120]);
    resultDir = char([68 58 92 48 35838 39064 92 38738 20809 30524 92 32467 26524]);
    settings.outputDir = fullfile(resultDir, 'AI_null_template_analysis_260520xkx');
    settings.matFile = fullfile(settings.outputDir, 'AI_null_template_analysis_260520xkx.mat');
    settings.excelFile = fullfile(settings.outputDir, 'AI_null_template_analysis_260520xkx.xlsx');
end

function caseList = AI_case_list()
    caseList(1) = struct( ...
        'name', 'null_RE', ...
        'description', 'Class1=null template from group7, Class2=RE template from group3', ...
        'class1Source', 'null', ...
        'class2Source', 'RE');

    caseList(2) = struct( ...
        'name', 'null_null', ...
        'description', 'Class1=null template from group7, Class2=null template from group7', ...
        'class1Source', 'null', ...
        'class2Source', 'null');
end

function caseResult = AI_run_one_case(caseCfg, settings, nullTrain, reTrain, nullTest)
    pointNum = size(settings.tempType, 1);
    RR_fold_all = cell(1, pointNum);
    Prob_dv_all = cell(1, pointNum);
    templateSource = cell(pointNum, 2);
    longRows = {};

    for point_i = 1:pointNum
        pair = settings.tempType(point_i, :);
        template1 = AI_select_template_source(caseCfg.class1Source, nullTrain, reTrain, settings, pair(1));
        template2 = AI_select_template_source(caseCfg.class2Source, nullTrain, reTrain, settings, pair(2));
        template = cat(4, template1, template2);
        testTrials = nullTest(settings.chanList, :, 1:settings.testTrialNum, point_i);

        [RR_fold, Prob_dv] = glc_detection_prob(template, testTrials, settings.foldNum);

        RR_fold_all{point_i} = RR_fold;
        Prob_dv_all{point_i} = Prob_dv;
        templateSource{point_i, 1} = caseCfg.class1Source;
        templateSource{point_i, 2} = caseCfg.class2Source;

        for block_i = 1:size(RR_fold, 1)
            longRows(end + 1, :) = { ...
                caseCfg.name, caseCfg.description, point_i, block_i, ...
                pair(1), pair(2), caseCfg.class1Source, caseCfg.class2Source, ...
                RR_fold(block_i, 1), RR_fold(block_i, 2), ...
                Prob_dv(1, block_i), Prob_dv(2, block_i), Prob_dv(3, block_i)}; %#ok<AGROW>
        end

        fprintf('Point %d done: RR_fold %d x %d, Prob_dv %d x %d\n', ...
            point_i, size(RR_fold, 1), size(RR_fold, 2), size(Prob_dv, 1), size(Prob_dv, 2));
    end

    caseResult = struct();
    caseResult.name = caseCfg.name;
    caseResult.description = caseCfg.description;
    caseResult.RR_fold = RR_fold_all;
    caseResult.Prob_dv = Prob_dv_all;
    caseResult.templateSource = templateSource;
    caseResult.longRows = longRows;
end

function templateData = AI_select_template_source(sourceName, nullTrain, reTrain, settings, pointIndex)
    switch sourceName
        case 'null'
            data = nullTrain;
        case 'RE'
            data = reTrain;
        otherwise
            error('Unknown template source: %s', sourceName);
    end
    templateData = data(settings.chanList, :, 1:settings.trainTrialNum, pointIndex);
end

function dataAll = AI_load_cnt(fileName, settings, trialTotal)
    if ~exist(fileName, 'file')
        error('Missing CNT file: %s', fileName);
    end
    [~, dataSeg, ~] = EEGRead5(fileName, 1000, settings.fs, ...
        [settings.tStart, settings.tEnd], settings.WnPara, trialTotal);
    dataAll = dataSeg(1:64, :, :, :);
end

function names = AI_long_table_names()
    names = {'caseName', 'caseDescription', 'point', 'block', ...
        'class1Point', 'class2Point', 'class1Source', 'class2Source', ...
        'RR1', 'RR2', 'Prob1', 'Prob2', 'Prob3'};
end
