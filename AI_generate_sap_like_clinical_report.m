function result = AI_generate_sap_like_clinical_report(dataDir, varargin)
% 生成类似SAP视野检查的客观视野报告。
% 
% 本脚本的主流程：
%   1. 设置分析参数和输出路径；
%   2. 读取患者信息；
%   3. 先跑完全部临床数据，得到28个检测点的概率结果；
%   4. 将28个检测点的概率、敏感度样指标、缺损分数统一整理在一起；
%   5. 基于完整28点结果进行54点插值和VFI/MD等指标计算；
%   6. 绘制视野图，并拼接成PNG/PDF报告；
%   7. 输出Excel表格和MAT结果文件。
%
% Example:
%   普通使用时，可以直接在命令行运行：
%       result = AI_generate_sap_like_clinical_report;
%   如果临时想指定另一个数据文件夹，也可以运行：
%       result = AI_generate_sap_like_clinical_report('D:\0课题\青光眼\data\临床实验\260617丁艳荣');

    % ==================== 0. 常用修改区：一般只改这里 ====================
    % defaultDataDir:
    %   当前要生成报告的患者数据文件夹。
    %   换患者时，通常只需要把这一行改成新的临床实验文件夹。
    defaultDataDir = 'D:\0课题\青光眼\data\临床实验\260629王胜春';

    % defaultResultDir:
    %   所有报告结果的总保存文件夹。
    %   程序会在这个文件夹下自动新建 AI_SAP_like_clinical_report\患者姓名1 这样的子文件夹。
    defaultResultDir = 'D:\0课题\青光眼\结果';

    % existingResultDir:
    %   如果为空字符串''，程序会新建一个患者姓名+版本号的结果文件夹，并重新跑CNT数据。
    %   如果填入已有结果文件夹，程序会优先在该文件夹中寻找AI_report_result.mat：
    %       找到：直接调用已有clinicalResult，重新计算指标、画图并生成报告；
    %       找不到：使用这个文件夹作为输出位置，重新跑CNT数据。
    %   这个设置适合“只改了画图/报告代码，想用旧数据重新生成报告”的情况。
    existingResultDir = '';
    % existingResultDir = 'D:\0课题\青光眼\结果\AI_SAP_like_clinical_report\丁艳荣1';

    % ==================== 1. 实验参数和输出路径 ====================
    % AI_report_settings负责把上面的路径和其他固定参数整理成settings结构体。
    % 如果你通过函数输入参数传入dataDir，会覆盖上面的defaultDataDir。
    settings = AI_report_settings(defaultDataDir, defaultResultDir, existingResultDir);
    if nargin >= 1 && ~isempty(dataDir)
        settings.dataDir = char(dataDir);
    end
    settings = AI_parse_inputs(settings, varargin{:});

    % ==================== 2. 患者基本信息 ====================
    % patientInfo中的字段会显示在最终PNG/PDF报告顶部。
    % 当前逻辑：
    %   1) 优先读取数据文件夹中的患者信息Excel；
    %   2) 如果数据文件夹里没有，就用默认信息新建一个；
    %   3) 根据患者姓名创建/选择结果文件夹；
    %   4) 同步复制一份到结果文件夹，方便报告归档。
    settings = AI_refresh_data_paths(settings);
    patientInfo = AI_load_or_create_patient_info_from_data(settings);
    settings = AI_prepare_output_folder(settings, patientInfo);
    settings = AI_refresh_output_paths(settings);
    if ~exist(settings.outputDir, 'dir')
        mkdir(settings.outputDir);
    end
    AI_sync_patient_info_to_output(patientInfo, settings);

    % ==================== 3. 跑完全部数据，得到28个检测点概率结果 ====================
    % clinicalResult.pointTable保存每个真实检测点的三分类概率：
    %   pNormal:        正常概率样评分；
    %   pLeftAbnormal:  左眼异常概率样评分；
    %   pRightAbnormal: 右眼异常概率样评分。
    % 注意：这里不计算VFI、MD和缺损点数，只负责把所有检测点跑完。
    clinicalResult = AI_get_or_create_clinical_result(settings);

    % ==================== 4. 整理完整28点结果 ====================
    % pointResult28把后续计算会用到的28点变量集中整理好：
    %   probability28:  28 x 3，三分类概率；
    %   sensitivity28: 28 x 2，左右眼敏感度样指标；
    %   defectScore28: 28 x 2，左右眼缺损概率样指标。
    pointResult28 = AI_collect_28_point_results(clinicalResult.pointTable);

    % ==================== 5. 基于完整28点结果计算54点指标 ====================
    % 这里才开始计算VFI、MD、PSD、正常点数、可疑点数和缺损点数。
    % 这些指标均基于插值后的54个SAP 24-2样伪检测点，而不是按每组4点单独计算。
    % ==================== 5. 分别计算28点版本和54点版本的报告指标 ====================
    % 这里统一完成两套结果：
    %   1) 28点版本：直接使用真实采集的28个检测点；
    %   2) 54点版本：先把28点结果插值/平滑到SAP 24-2样式的54个点，再计算指标。
    % 注意：VFI、MD、PSD、正常/可疑/缺损点数，必须和后面画图使用的点数一致。
    eyeResult = AI_compute_eye_indices(pointResult28, settings);

    % ==================== 6. 分别绘制28点版本和54点版本的视野图 ====================
    % AI_plot_sap_like_vf_report.m 现在只负责“输入几个点就画几个点”。
    % 因此28点到54点的转换只在本脚本中完成，不再放到绘图脚本内部。
    mapDir28 = fullfile(settings.mapDir, 'point28');
    mapDir54 = fullfile(settings.mapDir, 'point54');

    mapResult28 = AI_plot_sap_like_vf_report(eyeResult.defectScore28, ...
        'outputDir', mapDir28, ...
        'filePrefix', [settings.filePrefix, '_point28'], ...
        'inputPointMode', 'point28', ...
        'inputValueType', 'defectScore', ...
        'leftTitle', '左眼视野灰阶图（28点）', ...
        'rightTitle', '右眼视野灰阶图（28点）', ...
        'leftDensityTitle', '左眼密度图（28点）', ...
        'rightDensityTitle', '右眼密度图（28点）', ...
        'leftValueTitle', '左眼数值图（28点）', ...
        'rightValueTitle', '右眼数值图（28点）', ...
        'xLabel', '视野 X (deg)', ...
        'yLabel', '视野 Y (deg)', ...
        'colorbarLabel', '缺损概率样指标', ...
        'drawColorbar', false, ...
        'showFigure', false);

    % ==================== 6.2 绘制左右眼54点视野图 ====================
    % 这里仍然传入真实的54点缺损分数，不人为修改任何检测点数值。
    % 生理盲点只在AI_plot_sap_like_vf_report内部作为一簇黑点叠加显示，
    % 因此不会影响VFI、MD、PSD、点数统计，也不会写入Excel/MAT结果。
    mapResult54 = AI_plot_sap_like_vf_report(eyeResult.defectScore54, ...
        'outputDir', mapDir54, ...
        'filePrefix', [settings.filePrefix, '_point54'], ...
        'inputPointMode', 'sap54', ...
        'inputValueType', 'defectScore', ...
        'drawBlindSpotDotCluster', true, ...
        'leftTitle', '左眼视野灰阶图（54点）', ...
        'rightTitle', '右眼视野灰阶图（54点）', ...
        'leftDensityTitle', '左眼密度图（54点）', ...
        'rightDensityTitle', '右眼密度图（54点）', ...
        'leftValueTitle', '左眼数值图（54点）', ...
        'rightValueTitle', '右眼数值图（54点）', ...
        'xLabel', '视野 X (deg)', ...
        'yLabel', '视野 Y (deg)', ...
        'colorbarLabel', '缺损概率样指标', ...
        'drawColorbar', false, ...
        'showFigure', false);

    % ==================== 7. 拼接报告并输出表格 ====================
    % reportEyeResult28/reportEyeResult54只改变报告中采用的指标版本；
    % 原始28点表、插值54点表和总体结果仍统一保存在eyeResult中。
    reportEyeResult28 = AI_select_eye_result_for_report(eyeResult, 'point28');
    reportEyeResult54 = AI_select_eye_result_for_report(eyeResult, 'point54');

    reportFiles28 = AI_write_report_figure(patientInfo, clinicalResult, ...
        reportEyeResult28, mapResult28, settings, 'point28');
    reportFiles54 = AI_write_report_figure(patientInfo, clinicalResult, ...
        reportEyeResult54, mapResult54, settings, 'point54');

    AI_write_report_tables(clinicalResult, eyeResult, settings);

    result = struct();
    result.settings = settings;
    result.patientInfo = patientInfo;
    result.clinicalResult = clinicalResult;
    result.pointResult28 = pointResult28;
    result.eyeResult = eyeResult;
    result.mapResult28 = mapResult28;
    result.mapResult54 = mapResult54;
    result.reportFiles28 = reportFiles28;
    result.reportFiles54 = reportFiles54;
    % 为了兼容旧代码，默认mapResult/reportFiles仍指向54点版本。
    result.mapResult = mapResult54;
    result.reportFiles = reportFiles54;

    save(settings.matFile, 'result', '-v7.3');

    fprintf('\nSaved 28-point SAP-like report PNG: %s\n', reportFiles28.png);
    fprintf('Saved 28-point SAP-like report PDF: %s\n', reportFiles28.pdf);
    fprintf('Saved 54-point SAP-like report PNG: %s\n', reportFiles54.png);
    fprintf('Saved 54-point SAP-like report PDF: %s\n', reportFiles54.pdf);
    fprintf('Saved report tables: %s\n', settings.excelFile);
    fprintf('Saved MAT result: %s\n', settings.matFile);
end

function settings = AI_report_settings(defaultDataDir, defaultResultDir, existingResultDir)
    % 汇总报告生成所需的默认参数。
    %
    % 输入变量说明：
    %   defaultDataDir:
    %       主函数最前面“常用修改区”中设置的患者数据文件夹。
    %   defaultResultDir:
    %       主函数最前面“常用修改区”中设置的总结果文件夹。
    %   existingResultDir:
    %       主函数最前面“常用修改区”中设置的已有结果文件夹。
    %
    % 这里主要放相对固定的分析参数和报告参数。
    % 平时换患者、换输出总目录，优先改主函数最前面的“常用修改区”。
    if nargin < 1 || isempty(defaultDataDir)
        defaultDataDir = 'D:\0课题\青光眼\data\临床实验\260617丁艳荣';
    end
    if nargin < 2 || isempty(defaultResultDir)
        defaultResultDir = 'D:\0课题\青光眼\结果';
    end
    if nargin < 3 || isempty(existingResultDir)
        existingResultDir = '';
    end

    % ==================== 基础分析参数 ====================
    % fs: 脑电重采样频率，单位Hz。
    settings.fs = 250;
    % tStart/tEnd: 截取每个试次的时间窗，单位秒。
    settings.tStart = 0;
    settings.tEnd = 0.45;
    % WnPara: EEGRead5中使用的滤波参数，保持和前面分析脚本一致。
    settings.WnPara = [0.5, 2, 20, 30];
    % chanList: 用于DCPM分析的通道范围。
    settings.chanList = 44:64;
    % trainTrialTotal/testTrialTotal: 原始CNT文件中读取的训练/测试总试次数。
    settings.trainTrialTotal = 480;
    settings.testTrialTotal = 360;
    % trainTrialNum/testTrialNum: 实际用于建模/测试的试次数。
    settings.trainTrialNum = 120;
    settings.testTrialNum = 60;
    % foldNum: glc_detection_prob内部每几个试次叠加一次。
    settings.foldNum = 4;
    % probMeanBlockSize: 对Prob_dv再做一次block平均时，每几个block求一次均值。
    settings.probMeanBlockSize = 5;
    % tempType: 每组train/test中，4个检测点对应的模板事件配对。
    settings.tempType = [1,2; 2,1; 3,4; 4,3];

    % ==================== 默认数据路径和结果路径 ====================
    % dataDir:
    %   当前患者临床实验数据文件夹。它来自主函数最前面的defaultDataDir。
    settings.dataDir = char(defaultDataDir);
    % resultDir:
    %   所有报告结果的总输出文件夹。它来自主函数最前面的defaultResultDir。
    settings.resultDir = char(defaultResultDir);

    % existingResultDir:
    %   如果非空，优先使用这个已有结果文件夹中的AI_report_result.mat。
    settings.existingResultDir = char(existingResultDir);
    % filePrefix:
    %   单独视野图文件名前缀。后面会根据最终结果文件夹名自动刷新。
    settings.filePrefix = 'AI_SAP_like_report';
    % outputDir:
    %   本次报告专用输出文件夹。这里先留空，后面读取患者姓名后再确定。
    settings.outputDir = '';
    % mapDir: 存放单独左右眼视野图的子文件夹。
    settings.mapDir = fullfile(settings.outputDir, 'vf_maps');
    % patientInfoFileName: 患者信息Excel文件名。
    % 程序会优先在dataDir中寻找这个文件，并同步复制到outputDir。
    settings.patientInfoFileName = 'info.xlsx';
    settings.dataPatientInfoFile = fullfile(settings.dataDir, settings.patientInfoFileName);
    settings.patientInfoFile = fullfile(settings.outputDir, settings.patientInfoFileName);
    % excelFile/matFile/reportPng/reportPdf: 总报告输出文件。
    settings.excelFile = fullfile(settings.outputDir, 'AI_report_tables.xlsx');
    settings.matFile = fullfile(settings.outputDir, 'AI_report_result.mat');
    settings.reportPng = fullfile(settings.outputDir, 'AI_SAP_like_report.png');
    settings.reportPdf = fullfile(settings.outputDir, 'AI_SAP_like_report.pdf');

    settings.useExistingClinicalResult = false;
    settings.existingClinicalMat = fullfile(settings.resultDir, ...
        'AI_clinical_260520xkx', 'AI_clinical_260520xkx_result.mat');

    % ==================== 患者信息默认值 ====================
    % 如果dataDir中没有患者信息Excel，就用这些默认值新建一个。
    % 后续建议直接修改dataDir里的info.xlsx，而不是在代码里写死姓名。
    settings.defaultPatientInfo.patientId = '001';
    settings.defaultPatientInfo.name = 'None';
    settings.defaultPatientInfo.sex = 'None';
    settings.defaultPatientInfo.age = 'None';
    settings.defaultPatientInfo.examDate = datestr(now, 'yyyy-mm-dd');
    settings.defaultPatientInfo.operator = 'None';
    settings.defaultPatientInfo.notes = '研究性客观视野检测结果，仅供参考，实际视野状态以临床检查报告为准';

    % ==================== 报告判读阈值 ====================
    % normalSensitivity/suspectSensitivity/severeSensitivity:
    % 目前主要保留为后续扩展用。当前左右眼判断主要由VFI阈值完成。
    settings.normalSensitivity = 90;
    settings.suspectSensitivity = 50;
    settings.severeSensitivity = 0;

    % ==================== 指标点数统计阈值 ====================
    % 每一组阈值都包含normal和defect两个参数：
    %   缺损分数 < normal：统计为正常点；
    %   normal <= 缺损分数 < defect：统计为可疑点；
    %   缺损分数 >= defect：统计为缺损点。
    %
    % 为什么拆成4组：
    %   28点和54点的点位密度不同，左眼和右眼的结果也可能存在系统差异。
    %   后续如果要分别调阈值，可以只改对应版本/对应眼别，不影响其他结果。
    %
    % 目前四组先统一使用原来的阈值：normal=0.10，defect=0.20。
    settings.metricThreshold.point28.left.normal = 0.10;
    settings.metricThreshold.point28.left.defect = 0.20;
    settings.metricThreshold.point28.right.normal = 0.10;
    settings.metricThreshold.point28.right.defect = 0.20;
    settings.metricThreshold.point54.left.normal = 0.10;
    settings.metricThreshold.point54.left.defect = 0.20;
    settings.metricThreshold.point54.right.normal = 0.10;
    settings.metricThreshold.point54.right.defect = 0.20;

    % ==================== 54点插值和平滑参数 ====================
    % metricNormalThreshold/metricDefectThreshold:
    %   保留为兼容参数和空间平滑参数。
    %   点数统计请优先修改上面的settings.metricThreshold四组阈值。
    settings.metricNormalThreshold = 0.10;
    settings.metricDefectThreshold = 0.20;
    % metricNeighborRadiusDeg:
    %   空间邻域修正时，把多少度范围内的点看作邻居。
    %   调大：平滑范围更广，孤立点更容易被修正，但局部细节会变弱。
    %   调小：更保留局部点差异，但孤立异常点更容易保留。
    settings.metricNeighborRadiusDeg = 8.8;
    % metricSmoothBlend:
    %   普通平滑时，当前点向邻域均值靠近的比例。
    %   0表示不平滑，1表示完全替换为邻域均值。
    settings.metricSmoothBlend = 0.25;
    % metricIsolatedDelta:
    %   判断一个点是否为“孤立异常/孤立空洞”的差值阈值。
    %   对缺损分数直接使用该值；对sensitivity会换算为百分制差值。
    %   调大：只有很突兀的点才会被强修正。
    %   调小：更多点会被强修正，图和指标会更平滑。
    settings.metricIsolatedDelta = 0.08;
    % metricInterpPower:
    %   反距离加权插值的距离幂指数，仅在scatteredInterpolant不可用时使用。
    %   调大：更依赖最近的28点；调小：周围更远的点影响更大。
    settings.metricInterpPower = 2.4;
    % metricPseudoSmoothIterations:
    %   54点插值后再次做邻域平滑的次数。
    %   调大：54点结果更连续；调小：更保留插值后的局部差异。
    settings.metricPseudoSmoothIterations = 2;

    % ==================== 总报告拼图参数 ====================
    % reportImageWhiteTolerance:
    %   裁剪PNG白边时的白色判断阈值，范围0-255。
    %   调大：更多接近白色的区域会被裁掉。
    %   调小：裁剪更保守，白边可能更多。
    settings.reportImageWhiteTolerance = 248;
    % reportCropToAxes:
    %   true表示报告中只截取每张视野图的坐标轴主体区域；
    %   false表示只裁剪外侧白边，保留标题、坐标轴标签和色条等。
    settings.reportCropToAxes = true;
    % reportMapAxesPosition:
    %   单独视野图中axes的位置，格式为[left, bottom, width, height]。
    %   这个值要和AI_plot_sap_like_vf_report中的settings.axesPosition保持一致。
    %   如果你修改了单独视野图axes位置，这里也要同步修改，否则裁剪区域会偏。
    settings.reportMapAxesPosition = [0.285, 0.23, 0.43, 0.68];
    % reportAxesCropPadPx:
    %   截取axes主体区域时额外保留的像素边距。
    %   调大：保留更多坐标轴外侧内容；调小：裁剪更紧。
    settings.reportAxesCropPadPx = 0;
end

function settings = AI_refresh_output_paths(settings)
    % 根据当前settings.outputDir和settings.dataDir刷新所有输出路径。
    %
    % 为什么需要这个函数：
    %   用户可以在运行函数时通过'name-value'参数修改outputDir或dataDir。
    %   一旦这两个路径变化，mapDir、Excel输出路径、PDF输出路径、
    %   患者信息文件路径都必须同步更新。
    settings.mapDir = fullfile(settings.outputDir, 'vf_maps');
    settings.dataPatientInfoFile = fullfile(settings.dataDir, settings.patientInfoFileName);
    settings.patientInfoFile = fullfile(settings.outputDir, settings.patientInfoFileName);
    settings.excelFile = fullfile(settings.outputDir, 'AI_report_tables.xlsx');
    settings.matFile = fullfile(settings.outputDir, 'AI_report_result.mat');
    settings.reportPng = fullfile(settings.outputDir, 'AI_SAP_like_report.png');
    settings.reportPdf = fullfile(settings.outputDir, 'AI_SAP_like_report.pdf');
end

function settings = AI_refresh_data_paths(settings)
    % 只刷新和数据文件夹相关的路径。
    %
    % 这一步在确定输出文件夹之前执行，因为患者姓名需要先从dataDir里的info.xlsx读取。
    settings.dataPatientInfoFile = fullfile(settings.dataDir, settings.patientInfoFileName);
end

function settings = AI_parse_inputs(settings, varargin)
    % 读取用户输入的可选参数。
    %
    % 使用方式示例：
    %   AI_generate_sap_like_clinical_report(dataDir, ...
    %       'outputDir', outDir, ...
    %       'useExistingClinicalResult', true)
    %
    % varargin必须成对出现：
    %   第1个是参数名，例如'outputDir'；
    %   第2个是参数值，例如'D:\...\结果文件夹'。
    %
    % 如果输入的参数名不在settings里，程序会报错，避免拼错参数名后悄悄失效。
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

function patientInfo = AI_load_or_create_patient_info_from_data(settings)
    % 从数据文件夹读取或创建患者基本信息。
    %
    % 输入：
    %   settings.dataPatientInfoFile:
    %       数据文件夹中的患者信息Excel。以后建议优先修改这一份。
    %   settings.defaultPatientInfo:
    %       如果数据文件夹中还没有患者信息Excel，就用这里的默认值创建。
    %
    % 输出：
    %   patientInfo:
    %       结构体，包含patientId、name、sex、age、examDate等字段。

    % ==================== 1. 确认数据文件夹存在 ====================
    dataInfoDir = fileparts(settings.dataPatientInfoFile);
    if ~exist(dataInfoDir, 'dir')
        mkdir(dataInfoDir);
    end

    % ==================== 2. 如果数据文件夹中没有患者信息表，就创建默认表 ====================
    if ~exist(settings.dataPatientInfoFile, 'file')
        infoTable = AI_default_patient_info_table(settings);
        writetable(infoTable, settings.dataPatientInfoFile, 'Sheet', 'PatientInfo');
    end

    % ==================== 3. 读取数据文件夹中的患者信息表 ====================
    infoTable = readtable(settings.dataPatientInfoFile, 'Sheet', 'PatientInfo', 'TextType', 'string');

    % ==================== 4. 将表格转成结构体，方便后面写入报告文字 ====================
    patientInfo = struct();
    for i = 1:height(infoTable)
        key = char(infoTable.fieldKey(i));
        patientInfo.(key) = char(infoTable.fieldValue(i));
    end
    patientInfo.table = infoTable;
end

function AI_sync_patient_info_to_output(patientInfo, settings)
    % 将患者信息表同步保存到结果文件夹。
    %
    % 这样即使以后移动结果文件夹，也能知道该报告对应的患者信息。
    resultInfoDir = fileparts(settings.patientInfoFile);
    if ~exist(resultInfoDir, 'dir')
        mkdir(resultInfoDir);
    end
    writetable(patientInfo.table, settings.patientInfoFile, 'Sheet', 'PatientInfo');
end

function settings = AI_prepare_output_folder(settings, patientInfo)
    % 根据用户设置和患者姓名确定本次输出文件夹。
    %
    % 规则：
    %   1) 如果settings.existingResultDir非空，直接使用这个已有结果文件夹。
    %      后面会在这个文件夹中寻找AI_report_result.mat。
    %   2) 如果用户通过'name-value'传入了outputDir，也直接使用该文件夹。
    %   3) 如果两者都没有，就按患者姓名自动新建版本文件夹：
    %      例如：D:\...\AI_SAP_like_clinical_report\丁艳荣1、丁艳荣2、丁艳荣3。
    if ~isempty(strtrim(settings.existingResultDir))
        settings.outputDir = char(settings.existingResultDir);
    elseif ~isempty(strtrim(settings.outputDir))
        settings.outputDir = char(settings.outputDir);
    else
        patientName = AI_get_info(patientInfo, 'name');
        if isempty(strtrim(patientName)) || strcmpi(strtrim(patientName), 'None')
            patientName = AI_get_info(patientInfo, 'patientId');
        end
        if isempty(strtrim(patientName)) || strcmpi(strtrim(patientName), 'None')
            patientName = 'unknown';
        end

        safePatientName = AI_safe_folder_name(patientName);
        reportRootDir = fullfile(settings.resultDir, 'AI_SAP_like_clinical_report');
        settings.outputDir = AI_next_patient_version_folder(reportRootDir, safePatientName);
    end

    [~, outputFolderName] = fileparts(settings.outputDir);
    safeOutputName = AI_safe_folder_name(outputFolderName);
    settings.filePrefix = ['AI_SAP_like_report_', safeOutputName];
end

function folderPath = AI_next_patient_version_folder(reportRootDir, safePatientName)
    % 生成“患者姓名+版本号”的新结果文件夹路径。
    %
    % 如果丁艳荣1已存在，就尝试丁艳荣2；依次类推。
    if ~exist(reportRootDir, 'dir')
        mkdir(reportRootDir);
    end

    version_i = 1;
    while true
        folderName = sprintf('%s%d', safePatientName, version_i);
        folderPath = fullfile(reportRootDir, folderName);
        if ~exist(folderPath, 'dir')
            return;
        end
        version_i = version_i + 1;
    end
end

function safeName = AI_safe_folder_name(rawName)
    % 将患者姓名转换成可以作为Windows文件夹名的字符串。
    %
    % 主要去掉 \ / : * ? " < > | 这些Windows不允许出现在文件名中的字符。
    safeName = char(string(rawName));
    safeName = strtrim(safeName);
    safeName = regexprep(safeName, '[\\/:*?"<>|]', '_');
    safeName = regexprep(safeName, '\s+', '');
    if isempty(safeName)
        safeName = 'unknown';
    end
end

function infoTable = AI_default_patient_info_table(settings)
    % 生成默认患者信息表。
    %
    % fieldKey:
    %   程序内部读取字段时使用的英文变量名，不建议修改。
    % fieldName:
    %   给人看的中文字段名，可以帮助你在Excel里理解每一行是什么。
    % fieldValue:
    %   真正显示在报告中的内容，你后续主要修改这一列。
    fieldKey = {'patientId'; 'name'; 'sex'; 'age'; 'examDate'; ...
        'operator'; 'notes'};
    fieldName = {'患者编号'; '姓名'; '性别'; '年龄'; '检查日期'; ...
        '检查人员'; '备注'};
    fieldValue = { ...
        settings.defaultPatientInfo.patientId; ...
        settings.defaultPatientInfo.name; ...
        settings.defaultPatientInfo.sex; ...
        settings.defaultPatientInfo.age; ...
        settings.defaultPatientInfo.examDate; ...
        settings.defaultPatientInfo.operator; ...
        settings.defaultPatientInfo.notes};
    infoTable = table(fieldKey, fieldName, fieldValue);
end

function clinicalResult = AI_get_or_create_clinical_result(settings)
    % 获取本次报告要使用的clinicalResult。
    %
    % 优先级：
    %   1) 如果settings.outputDir里已有AI_report_result.mat，就从里面读取clinicalResult。
    %      这适合“修改画图代码后，复用旧检测结果重新生成报告”。
    %   2) 如果settings.useExistingClinicalResult为true，并且settings.existingClinicalMat存在，
    %      就读取这个外部临床结果文件。
    %   3) 以上都没有，就重新从CNT数据跑DCPM检测。
    if exist(settings.matFile, 'file')
        clinicalResult = AI_load_clinical_result_from_report_mat(settings.matFile);
        fprintf('\nLoaded existing clinicalResult from: %s\n', settings.matFile);
        return;
    end

    if settings.useExistingClinicalResult && exist(settings.existingClinicalMat, 'file')
        clinicalResult = AI_load_existing_clinical_result(settings.existingClinicalMat);
        fprintf('\nLoaded existing clinicalResult from: %s\n', settings.existingClinicalMat);
        return;
    end

    fprintf('\nNo existing clinicalResult found. Start processing CNT data in: %s\n', settings.dataDir);
    clinicalResult = AI_process_clinical_folder(settings);
end

function clinicalResult = AI_load_clinical_result_from_report_mat(matFile)
    % 从本脚本保存的AI_report_result.mat中读取clinicalResult。
    %
    % AI_report_result.mat里保存的是总result结构体，clinicalResult是其中一个字段。
    loaded = load(matFile, 'result');
    if ~isfield(loaded, 'result') || ~isfield(loaded.result, 'clinicalResult')
        error('MAT file does not contain result.clinicalResult: %s', matFile);
    end
    clinicalResult = loaded.result.clinicalResult;
    clinicalResult = AI_ensure_clinical_result_eye_mapping(clinicalResult);
end

function clinicalResult = AI_load_existing_clinical_result(matFile)
    % 读取外部已有临床检测结果。
    %
    % 兼容两种MAT格式：
    %   1) result本身就是clinicalResult；
    %   2) result.clinicalResult中保存clinicalResult。
    loaded = load(matFile, 'result');
    if ~isfield(loaded, 'result')
        error('MAT file does not contain variable result: %s', matFile);
    end
    if isfield(loaded.result, 'clinicalResult')
        clinicalResult = loaded.result.clinicalResult;
    else
        clinicalResult = loaded.result;
    end
    clinicalResult = AI_ensure_clinical_result_eye_mapping(clinicalResult);
end

function clinicalResult = AI_ensure_clinical_result_eye_mapping(clinicalResult)
    % 兼容旧版本保存的clinicalResult。
    %
    % 旧版本曾经把Prob_calculate第2/第3类直接写成左眼/右眼异常，
    % 但在当前BM双眼对称刺激逻辑下，第2/第3类的实际眼别应当互换。
    % 新版本保存clinicalResult时会带有eyeProbabilityMappingVersion字段。
    % 如果读取到的旧结果没有这个字段，就自动交换pLeftAbnormal和pRightAbnormal。
    targetVersion = 'BM_template_to_eye_v2_normal_left_right';
    if isfield(clinicalResult, 'eyeProbabilityMappingVersion') && ...
            strcmp(clinicalResult.eyeProbabilityMappingVersion, targetVersion)
        return;
    end

    if isfield(clinicalResult, 'pointTable') && ...
            all(ismember({'pLeftAbnormal', 'pRightAbnormal'}, ...
            clinicalResult.pointTable.Properties.VariableNames))
        oldLeft = clinicalResult.pointTable.pLeftAbnormal;
        clinicalResult.pointTable.pLeftAbnormal = clinicalResult.pointTable.pRightAbnormal;
        clinicalResult.pointTable.pRightAbnormal = oldLeft;

        if all(ismember({'pNormal', 'predictedLabel', 'predictedState'}, ...
                clinicalResult.pointTable.Properties.VariableNames))
            probabilityMat = [clinicalResult.pointTable.pNormal, ...
                clinicalResult.pointTable.pLeftAbnormal, ...
                clinicalResult.pointTable.pRightAbnormal];
            [~, predictedLabel] = max(probabilityMat, [], 2);
            clinicalResult.pointTable.predictedLabel = predictedLabel;
            clinicalResult.pointTable.predictedState = arrayfun( ...
                @AI_label_name, predictedLabel, 'UniformOutput', false);
        end

        fprintf('\nConverted old clinicalResult eye probability mapping to: %s\n', targetVersion);
    end

    clinicalResult.eyeProbabilityMappingVersion = targetVersion;
end

function clinicalResult = AI_process_clinical_folder(settings)
    % 跑完整个临床数据文件夹。
    %
    % 输入：
    %   settings: 参数结构体，包含数据路径、试次数、通道范围等。
    %
    % 输出：
    %   clinicalResult.pointTable:
    %       28个真实检测点的结果表，每一行对应一个检测点。
    %   clinicalResult.groupTable:
    %       每组train/test文件的基本信息和该组4个点的预测模式。
    %
    % 重要说明：
    %   这个函数只负责跑数据和保存每个点的概率结果；
    %   不在每组4个点结束后计算VFI、MD等视野指标。

    % ==================== 1. 查找所有训练文件 ====================
    trainFiles = dir(fullfile(settings.dataDir, 'train*.cnt'));
    trainNums = AI_file_numbers({trainFiles.name}, 'train');
    [trainNums, order] = sort(trainNums);
    trainFiles = trainFiles(order);
    groupNum = numel(trainFiles);
    if groupNum == 0
        error('No train*.cnt files found in: %s', settings.dataDir);
    end

    % ==================== 2. 预先建立保存所有点结果的变量 ====================
    % 每组通常包含4个检测点；7组完成后得到28个检测点。
    pointNumPerGroup = size(settings.tempType, 1);
    maxPointNum = groupNum * pointNumPerGroup;

    allGroupIndex = nan(maxPointNum, 1);              % 每个点属于第几组train/test
    allLocalPoint = nan(maxPointNum, 1);              % 每个点在当前组内的序号，通常为1-4
    allGlobalPoint = nan(maxPointNum, 1);             % 全局点序号，通常为1-28
    allTrainEventType = nan(maxPointNum, 1);          % 训练文件中该点对应的事件类型
    allTestEventType = nan(maxPointNum, 1);           % 测试文件中该点对应的事件类型
    allPredictedLabel = nan(maxPointNum, 1);          % 三分类预测标签：1正常，2左眼异常，3右眼异常
    allProbabilityNormal = nan(maxPointNum, 1);       % 正常概率样评分
    allProbabilityLeft = nan(maxPointNum, 1);         % 左眼异常概率样评分
    allProbabilityRight = nan(maxPointNum, 1);        % 右眼异常概率样评分
    allProbabilityDefect = nan(maxPointNum, 1);       % 总异常概率样评分，等于1 - 正常概率

    groupRows = cell(groupNum, numel(AI_group_table_names()));
    clinicalResult.group = cell(groupNum, 1);
    nextPointRow = 1;

    % ==================== 3. 逐组运行DCPM概率检测 ====================
    for group_i = 1:groupNum
        trainFile = fullfile(settings.dataDir, sprintf('train%d.cnt', trainNums(group_i)));
        testFile = fullfile(settings.dataDir, sprintf('test%d.cnt', trainNums(group_i)));
        fprintf('\n==== SAP-like report group %d/%d ====\n', group_i, groupNum);
        groupResult = AI_process_one_group(group_i, trainFile, testFile, settings);
        clinicalResult.group{group_i} = groupResult;

        currentPointNum = numel(groupResult.predictedLabel);
        rowRange = nextPointRow:nextPointRow + currentPointNum - 1;

        allGroupIndex(rowRange) = group_i;
        allLocalPoint(rowRange) = (1:currentPointNum)';
        allGlobalPoint(rowRange) = rowRange(:);
        allTrainEventType(rowRange) = groupResult.trainEventType(:);
        allTestEventType(rowRange) = groupResult.testEventType(:);
        allPredictedLabel(rowRange) = groupResult.predictedLabel(:);
        allProbabilityNormal(rowRange) = groupResult.pointProbability(1, :)';
        allProbabilityLeft(rowRange) = groupResult.pointProbability(2, :)';
        allProbabilityRight(rowRange) = groupResult.pointProbability(3, :)';
        allProbabilityDefect(rowRange) = 1 - groupResult.pointProbability(1, :)';

        groupRows(group_i, :) = { ...
            group_i, trainFile, testFile, settings.trainTrialNum, settings.testTrialNum, ...
            AI_pattern_string(groupResult.predictedLabel)};

        nextPointRow = nextPointRow + currentPointNum;
    end

    % ==================== 4. 删除没有使用到的预留行 ====================
    validRow = 1:nextPointRow - 1;
    allGroupIndex = allGroupIndex(validRow);
    allLocalPoint = allLocalPoint(validRow);
    allGlobalPoint = allGlobalPoint(validRow);
    allTrainEventType = allTrainEventType(validRow);
    allTestEventType = allTestEventType(validRow);
    allPredictedLabel = allPredictedLabel(validRow);
    allProbabilityNormal = allProbabilityNormal(validRow);
    allProbabilityLeft = allProbabilityLeft(validRow);
    allProbabilityRight = allProbabilityRight(validRow);
    allProbabilityDefect = allProbabilityDefect(validRow);

    % ==================== 5. 生成28点结果表和组信息表 ====================
    predictedState = arrayfun(@AI_label_name, allPredictedLabel, 'UniformOutput', false);
    clinicalResult.pointTable = table(allGroupIndex, allLocalPoint, allGlobalPoint, ...
        allTrainEventType, allTestEventType, allPredictedLabel, predictedState(:), ...
        allProbabilityNormal, allProbabilityLeft, allProbabilityRight, allProbabilityDefect, ...
        'VariableNames', AI_point_table_names());
    clinicalResult.groupTable = cell2table(groupRows, 'VariableNames', AI_group_table_names());
    clinicalResult.settings = settings;
    % 标记当前clinicalResult已经使用新的眼别概率顺序：
    %   [正常；左眼异常；右眼异常]。
    clinicalResult.eyeProbabilityMappingVersion = 'BM_template_to_eye_v2_normal_left_right';
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
    % 处理一组train/test文件。
    %
    % 输入：
    %   group_i:  当前是第几组文件；
    %   trainFile: 训练数据文件；
    %   testFile:  测试数据文件；
    %   settings:  分析参数。
    %
    % 输出：
    %   groupResult.pointProbability:
    %       3 x 点数。每一列对应一个检测点，三行分别是正常、左眼异常、右眼异常。
    %   groupResult.predictedLabel:
    %       该组每个检测点的最大概率类别。
    %
    % 注意：
    %   这里不计算VFI、MD、PSD等整体视野指标。
    %   整体指标必须等全部组、全部检测点都跑完以后再计算。

    if ~exist(testFile, 'file')
        error('Missing paired test file: %s', testFile);
    end

    % ==================== 1. 读取训练数据和测试数据 ====================
    [trainData, typeAllTrain] = AI_load_cnt(trainFile, settings, settings.trainTrialTotal);
    [testData, typeAllTest] = AI_load_cnt(testFile, settings, settings.testTrialTotal);

    % ==================== 2. 建立保存当前组点位结果的变量 ====================
    pointNum = min([numel(typeAllTrain), numel(typeAllTest), size(settings.tempType, 1)]);
    probDvAll = nan(3, settings.testTrialNum / settings.foldNum, pointNum);
    blockProbAll = nan(3, settings.testTrialNum / settings.foldNum / settings.probMeanBlockSize, pointNum);
    pointProbability = nan(3, pointNum);
    predictedLabel = nan(1, pointNum);

    % ==================== 3. 逐点进行DCPM概率检测 ====================
    for point_i = 1:pointNum
        templateEventPair = settings.tempType(point_i, :);
        templateData = trainData(settings.chanList, :, ...
            1:settings.trainTrialNum, templateEventPair);
        testDataOnePoint = testData(settings.chanList, :, ...
            1:settings.testTrialNum, point_i);

        [~, templateProbDv] = glc_detection_prob(templateData, testDataOnePoint, settings.foldNum);

        % Prob_calculate原始输出的三行不是直接的“正常/左眼异常/右眼异常”。
        % 它的第2行表示“更像模板1、不像模板2”，第3行表示“不像模板1、更像模板2”。
        % 在当前BM双眼对称刺激中：
        %   模板1 = 当前测试点对应的左眼刺激位置；
        %   模板2 = 当前测试点镜像位置，对应右眼仍能看到的刺激位置。
        % 因此：
        %   第2行实际表示右眼缺损后，只剩左眼模板1成分；
        %   第3行实际表示左眼缺损后，只剩右眼模板2成分。
        % 这里统一转换成报告使用的眼别顺序：[正常；左眼异常；右眼异常]。
        eyeProbDv = AI_template_prob_to_eye_prob(templateProbDv);

        probDvAll(:, :, point_i) = eyeProbDv;
        blockProbAll(:, :, point_i) = AI_block_average_prob(eyeProbDv, settings.probMeanBlockSize);

        % pointProbability是当前检测点的最终三分类概率样评分。
        % 先对若干block求平均，再归一化为三类之和等于1。
        pointProbability(:, point_i) = mean(blockProbAll(:, :, point_i), 2);
        pointProbability(:, point_i) = pointProbability(:, point_i) ./ ...
            sum(pointProbability(:, point_i));
        [~, predictedLabel(point_i)] = max(pointProbability(:, point_i));
    end

    % ==================== 4. 汇总当前组结果 ====================
    groupResult = struct();
    groupResult.group = group_i;
    groupResult.trainFile = trainFile;
    groupResult.testFile = testFile;
    groupResult.trainEventType = typeAllTrain(1:pointNum);
    groupResult.testEventType = typeAllTest(1:pointNum);
    groupResult.probDvAll = probDvAll;
    groupResult.blockProbAll = blockProbAll;
    groupResult.pointProbability = pointProbability;
    groupResult.predictedLabel = predictedLabel;
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
    % 将单次/小折概率按block求平均。
    %
    % 输入：
    %   probDv: 3 x N，每列是一个测试block的三分类概率；
    %   blockSize: 每几个概率block再求一次平均。
    %
    % 输出：
    %   blockProb: 3 x M，平均后的三分类概率。
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

function eyeProb = AI_template_prob_to_eye_prob(templateProb)
    % 将Prob_calculate的模板顺序概率转换为报告使用的眼别顺序概率。
    %
    % templateProb:
    %   3 x N矩阵，来自Prob_calculate。
    %   第1行：正常，即模板1和模板2都存在；
    %   第2行：模板1存在、模板2缺失；
    %   第3行：模板1缺失、模板2存在。
    %
    % 为什么第2/第3行要互换：
    %   当前临床检测使用BM双眼对称刺激。以某个测试点为例：
    %       模板1 = 当前点位置，对应左眼看到的刺激成分；
    %       模板2 = 镜像点位置，对应右眼看到的刺激成分。
    %   如果左眼该点缺损，测试信号会退化为“只剩右眼模板2”，所以对应templateProb第3行。
    %   如果右眼镜像点缺损，测试信号会退化为“只剩左眼模板1”，所以对应templateProb第2行。
    %
    % eyeProb:
    %   3 x N矩阵，统一转换为报告和表格使用的顺序：
    %       第1行：正常概率；
    %       第2行：左眼异常概率；
    %       第3行：右眼异常概率。
    if size(templateProb, 1) ~= 3
        error('templateProb must be a 3 x N matrix.');
    end

    eyeProb = templateProb([1, 3, 2], :);
end

function pointResult28 = AI_collect_28_point_results(pointTable)
    % 整理28个真实检测点的完整结果。
    %
    % 输入：
    %   pointTable: 每个真实检测点的DCPM三分类概率结果表。
    %
    % 输出：
    %   pointResult28: 结构体，里面保存后续计算需要的28点变量。
    %
    % 这里先把所有28个点的概率、敏感度样指标、缺损分数整理好。
    % 后面的VFI、MD、54点插值都基于这些完整28点结果计算。

    if height(pointTable) ~= 28
        warning('Expected 28 points, but got %d points.', height(pointTable));
    end
    if ~ismember('globalPoint', pointTable.Properties.VariableNames)
        pointTable.globalPoint = (1:height(pointTable))';
    end

    % ==================== 1. 读取三分类概率 ====================
    probabilityNormal28 = pointTable.pNormal;                % 正常概率样评分
    probabilityLeft28 = pointTable.pLeftAbnormal;            % 左眼异常概率样评分
    probabilityRight28 = pointTable.pRightAbnormal;          % 右眼异常概率样评分
    probability28 = [probabilityNormal28, probabilityLeft28, probabilityRight28];

    % ==================== 2. 计算左右眼缺损分数 ====================
    % 左眼缺损分数 = (1 - 正常概率) * 左眼异常概率
    % 右眼缺损分数 = (1 - 正常概率) * 右眼异常概率
    defectScore28 = AI_defect_score_from_prob(probability28);

    % ==================== 3. 计算左右眼敏感度样指标 ====================
    % 敏感度样指标表示“该眼越接近正常”的程度，范围0-100。
    %
    % 三分类概率的含义是：
    %   probabilityNormal28: 正常概率；
    %   probabilityLeft28:   左眼异常概率；
    %   probabilityRight28:  右眼异常概率。
    %
    % 因此：
    %   左眼敏感度 = 1 - 左眼异常概率；
    %   右眼敏感度 = 1 - 右眼异常概率。
    %
    % 这和旧写法“左眼=正常概率+右眼异常概率、右眼=正常概率+左眼异常概率”等价，
    % 因为三类概率之和为1。但下面这种写法更直观，不容易误以为左右眼反了。
    leftSensitivity28 = 100 * (1 - probabilityLeft28);
    rightSensitivity28 = 100 * (1 - probabilityRight28);
    sensitivity28 = max(0, min(100, [leftSensitivity28, rightSensitivity28]));

    % ==================== 4. 保存整理后的28点结果 ====================
    pointResult28 = struct();
    pointResult28.pointTable = pointTable;
    pointResult28.globalPoint = pointTable.globalPoint;
    pointResult28.group = pointTable.group;
    pointResult28.localPoint = pointTable.point;
    pointResult28.probability28 = probability28;
    pointResult28.probabilityNormal28 = probabilityNormal28;
    pointResult28.probabilityLeft28 = probabilityLeft28;
    pointResult28.probabilityRight28 = probabilityRight28;
    pointResult28.defectScore28 = defectScore28;
    pointResult28.sensitivity28 = sensitivity28;
end

function eyeResult = AI_compute_eye_indices(pointResult28, settings)
    % 基于完整28点结果，计算54点插值结果和左右眼报告指标。
    %
    % 输入：
    %   pointResult28: AI_collect_28_point_results整理出的28点结果；
    %   settings: 阈值、插值和平滑参数。
    %
    % 输出：
    %   eyeResult: 左右眼54点结果、VFI/MD/PSD、正常/可疑/缺损点数。

    % ==================== 1. 将28点结果扩展为SAP 24-2样54点 ====================
    % 这里的54点不是实际采集点，而是基于28个真实检测点进行邻域修正和二维插值
    % 得到的伪检测点。它使报告指标更接近临床SAP 24-2的点位密度。
    coord28 = AI_get_current_28_visual_coordinates();
    leftCoord54 = AI_get_sap24_2_metric_coordinates('left');
    rightCoord54 = AI_get_sap24_2_metric_coordinates('right');

    [leftSensitivity54, leftDefectScore54] = AI_expand_one_eye_to_54_points( ...
        coord28, leftCoord54, pointResult28.sensitivity28(:, 1), ...
        pointResult28.defectScore28(:, 1), settings);
    [rightSensitivity54, rightDefectScore54] = AI_expand_one_eye_to_54_points( ...
        coord28, rightCoord54, pointResult28.sensitivity28(:, 2), ...
        pointResult28.defectScore28(:, 2), settings);

    sensitivity54 = [leftSensitivity54, rightSensitivity54];
    defectScore54 = [leftDefectScore54, rightDefectScore54];

    % ==================== 2. 基于54点计算报告指标 ====================
    % VFI、MD、PSD和正常/可疑/缺损点数均使用插值后的54点，而不是28点。
    % 28点指标：直接反映当前真实采集点，不经过插值。
    % 54点指标：反映插值到SAP 24-2样式点位后的结果。
    % 后续报告会分别调用这两套指标，保证“图”和“VFI/MD/点数统计”使用同一套点位。
    leftMetrics28 = AI_one_eye_metrics(pointResult28.sensitivity28(:, 1), ...
        pointResult28.defectScore28(:, 1), '左眼', 'point28', settings);
    rightMetrics28 = AI_one_eye_metrics(pointResult28.sensitivity28(:, 2), ...
        pointResult28.defectScore28(:, 2), '右眼', 'point28', settings);
    leftMetrics54 = AI_one_eye_metrics(sensitivity54(:, 1), defectScore54(:, 1), ...
        '左眼', 'point54', settings);
    rightMetrics54 = AI_one_eye_metrics(sensitivity54(:, 2), defectScore54(:, 2), ...
        '右眼', 'point54', settings);

    eyeResult = struct();
    eyeResult.sensitivity28 = pointResult28.sensitivity28;
    eyeResult.defectScore28 = pointResult28.defectScore28;
    % 兼容旧变量名：不带后缀时默认表示真实采集的28点结果。
    eyeResult.sensitivity = pointResult28.sensitivity28;
    eyeResult.defectScore = pointResult28.defectScore28;
    eyeResult.sensitivity54 = sensitivity54;
    eyeResult.defectScore54 = defectScore54;
    eyeResult.pointTable = pointResult28.pointTable;
    eyeResult.leftMetrics28 = leftMetrics28;
    eyeResult.rightMetrics28 = rightMetrics28;
    eyeResult.leftMetrics54 = leftMetrics54;
    eyeResult.rightMetrics54 = rightMetrics54;
    % 兼容旧变量名：默认报告指标指向54点版本。
    eyeResult.leftMetrics = leftMetrics54;
    eyeResult.rightMetrics = rightMetrics54;
    eyeResult.eyeMetricTable = struct2table([leftMetrics28; rightMetrics28; ...
        leftMetrics54; rightMetrics54]);
    eyeResult.pointSensitivityTable = table(pointResult28.globalPoint, pointResult28.group, ...
        pointResult28.localPoint, pointResult28.sensitivity28(:, 1), ...
        pointResult28.sensitivity28(:, 2), pointResult28.defectScore28(:, 1), ...
        pointResult28.defectScore28(:, 2), ...
        'VariableNames', {'globalPoint', 'group', 'point', ...
        'leftSensitivity', 'rightSensitivity', ...
        'leftDefectScore', 'rightDefectScore'});
    eyeResult.pointSensitivity54Table = table((1:54)', ...
        leftCoord54(:, 1), leftCoord54(:, 2), ...
        rightCoord54(:, 1), rightCoord54(:, 2), ...
        sensitivity54(:, 1), sensitivity54(:, 2), ...
        defectScore54(:, 1), defectScore54(:, 2), ...
        'VariableNames', {'pseudoPoint', ...
        'leftXDeg', 'leftYDeg', 'rightXDeg', 'rightYDeg', ...
        'leftSensitivity54', 'rightSensitivity54', ...
        'leftDefectScore54', 'rightDefectScore54'});
    eyeResult.overallJudgement28 = AI_overall_judgement(leftMetrics28, rightMetrics28);
    eyeResult.overallJudgement54 = AI_overall_judgement(leftMetrics54, rightMetrics54);
    % 兼容旧变量名：默认总体判断指向54点版本。
    eyeResult.overallJudgement = eyeResult.overallJudgement54;
end

function defectScore = AI_defect_score_from_prob(pointProb)
    pointProb = max(pointProb, 0);
    pointProb = pointProb ./ sum(pointProb, 2);
    pNormal = pointProb(:, 1);
    pLeft = pointProb(:, 2);
    pRight = pointProb(:, 3);
    defectScore = [(1 - pNormal) .* pLeft, (1 - pNormal) .* pRight];
end

function coord28 = AI_get_current_28_visual_coordinates()
    % 当前28个真实检测点的视野坐标。
    % 这里与AI_plot_sap_like_vf_report.m中的坐标换算保持一致：
    % 先使用实验设计中的像素坐标，再通过锚点换算为视角坐标。
    pixelXY = [
         76,   76;
        -76,   76;
        -76,  -76;
         76,  -76;
        173,  173;
       -173,  173;
       -173, -173;
        173, -173;
         65,  282;
        -65,  282;
        -65, -282;
         65, -282;
        282,   65;
       -282,   65;
       -282,  -65;
        282,  -65;
        286,  286;
       -286,  286;
       -286, -286;
        286, -286;
        176,  397;
       -176,  397;
       -176, -397;
        176, -397;
        397,  176;
       -397,  176;
       -397, -176;
        397, -176];

    anchorPixel = [0, 76, 173, 286, 397];
    anchorDeg = [0, 4, 9, 19, 24];
    vfXDeg = sign(pixelXY(:, 1)) .* interp1(anchorPixel, anchorDeg, ...
        abs(pixelXY(:, 1)), 'pchip', 'extrap');
    vfYDeg = sign(pixelXY(:, 2)) .* interp1(anchorPixel, anchorDeg, ...
        abs(pixelXY(:, 2)), 'pchip', 'extrap');
    coord28 = [vfXDeg, vfYDeg];
end

function coord54 = AI_get_sap24_2_metric_coordinates(eyeSide)
    % SAP 24-2样54个伪检测点坐标。
    % 主体为6度间距、偏移3度的24-2分布；鼻侧额外延伸到27度。
    % 左眼鼻侧在右侧视野，右眼鼻侧在左侧视野，因此左右眼坐标镜像。
    switch lower(char(eyeSide))
        case 'right'
            nasalSide = -1;
        otherwise
            nasalSide = 1;
    end

    rowY = [21; 15; 9; 3; -3; -9; -15; -21];
    rowX = {[-9, -3, 3, 9], ...
        [-15, -9, -3, 3, 9, 15], ...
        [-21, -15, -9, -3, 3, 9, 15, 21], ...
        [-21, -15, -9, -3, 3, 9, 15, 21, nasalSide * 27], ...
        [-21, -15, -9, -3, 3, 9, 15, 21, nasalSide * 27], ...
        [-21, -15, -9, -3, 3, 9, 15, 21], ...
        [-15, -9, -3, 3, 9, 15], ...
        [-9, -3, 3, 9]};

    coord54 = zeros(54, 2);
    row_i = 0;
    for y_i = 1:numel(rowY)
        currentX = sort(rowX{y_i});
        n = numel(currentX);
        coord54(row_i + 1:row_i + n, 1) = currentX(:);
        coord54(row_i + 1:row_i + n, 2) = rowY(y_i);
        row_i = row_i + n;
    end
end

function [sensitivity54, defectScore54] = AI_expand_one_eye_to_54_points( ...
        coord28, coord54, sensitivity28, defectScore28, settings)
    % 将单眼28点结果扩展为54点。
    % sensitivity28: 28点敏感度样指标，用于VFI/MD/PSD计算。
    % defectScore28: 28点缺损概率样指标，用于正常/可疑/缺损点数统计。
    sensitivity28 = max(0, min(100, sensitivity28(:)));
    defectScore28 = max(0, defectScore28(:));

    % 先在28点水平做邻域一致性修正，降低孤立异常点对插值结果的影响。
    correctedSensitivity28 = AI_correct_metric_spatial_outliers( ...
        coord28, sensitivity28, settings, 'sensitivity');
    correctedDefect28 = AI_correct_metric_spatial_outliers( ...
        coord28, defectScore28, settings, 'defect');

    % 再用二维插值把28点扩展到SAP 24-2样54点。
    sensitivity54 = AI_interpolate_metric_to_54_points( ...
        coord28, correctedSensitivity28, coord54, settings);
    defectScore54 = AI_interpolate_metric_to_54_points( ...
        coord28, correctedDefect28, coord54, settings);

    % 最后在54点水平再做邻域一致性平滑，避免插值后出现孤立点。
    for iter_i = 1:settings.metricPseudoSmoothIterations
        sensitivity54 = AI_correct_metric_spatial_outliers( ...
            coord54, sensitivity54, settings, 'sensitivity');
        defectScore54 = AI_correct_metric_spatial_outliers( ...
            coord54, defectScore54, settings, 'defect');
    end

    sensitivity54 = max(0, min(100, sensitivity54(:)));
    defectScore54 = max(0, defectScore54(:));
end

function correctedValue = AI_correct_metric_spatial_outliers(coord, value, settings, valueType)
    % 邻域一致性修正。
    % 对缺损分数：孤立高值表示单个异常点，孤立低值表示异常区域中的空洞。
    % 对敏感度：方向相反，孤立低值可能是单个异常点，孤立高值可能是空洞。
    value = value(:);
    finiteValue = value(isfinite(value));
    if isempty(finiteValue)
        value(~isfinite(value)) = 0;
    else
        value(~isfinite(value)) = mean(finiteValue);
    end

    correctedValue = value;
    updatedValue = correctedValue;
    for i = 1:numel(value)
        dist = hypot(coord(:, 1) - coord(i, 1), coord(:, 2) - coord(i, 2));
        neighborIdx = dist > eps & dist <= settings.metricNeighborRadiusDeg;
        if ~any(neighborIdx)
            continue;
        end

        neighborDist = dist(neighborIdx);
        neighborValue = correctedValue(neighborIdx);
        weight = 1 ./ max(neighborDist, 0.5);
        neighborMean = sum(weight(:) .* neighborValue(:)) ./ sum(weight(:));
        neighborMean = double(neighborMean);

        currentValue = correctedValue(i);
        if strcmp(valueType, 'sensitivity')
            scaleValue = 100;
            isIsolatedHigh = currentValue - neighborMean >= settings.metricIsolatedDelta * scaleValue;
            isIsolatedLow = neighborMean - currentValue >= settings.metricIsolatedDelta * scaleValue;
        else
            isIsolatedHigh = currentValue > settings.metricNormalThreshold && ...
                neighborMean < settings.metricNormalThreshold && ...
                currentValue - neighborMean >= settings.metricIsolatedDelta;
            isIsolatedLow = currentValue < settings.metricNormalThreshold && ...
                neighborMean > settings.metricNormalThreshold && ...
                neighborMean - currentValue >= settings.metricIsolatedDelta;
        end

        blendWeight = settings.metricSmoothBlend;
        if isIsolatedHigh || isIsolatedLow
            blendWeight = max(blendWeight, 0.65);
        end

        updatedValue(i) = (1 - blendWeight) .* currentValue + ...
            blendWeight .* neighborMean;
    end

    correctedValue = updatedValue;
end

function targetValue = AI_interpolate_metric_to_54_points(coord28, value28, coord54, settings)
    % 二维插值：优先使用自然邻域插值；如果不可用，则使用反距离加权插值。
    x28 = coord28(:, 1);
    y28 = coord28(:, 2);
    x54 = coord54(:, 1);
    y54 = coord54(:, 2);
    value28 = value28(:);

    validIdx = isfinite(x28) & isfinite(y28) & isfinite(value28);
    try
        interpObj = scatteredInterpolant(x28(validIdx), y28(validIdx), ...
            value28(validIdx), 'natural', 'nearest');
        targetValue = interpObj(x54, y54);
    catch
        targetValue = AI_idw_metric_interpolation( ...
            x28(validIdx), y28(validIdx), value28(validIdx), x54, y54, settings);
    end

    targetValue = targetValue(:);
end

function targetValue = AI_idw_metric_interpolation(xSource, ySource, valueSource, xTarget, yTarget, settings)
    % 反距离加权插值后备方案。
    targetValue = zeros(numel(xTarget), 1);
    for i = 1:numel(xTarget)
        dist = hypot(xSource - xTarget(i), ySource - yTarget(i));
        [minDist, minIdx] = min(dist);
        if minDist < 1e-6
            targetValue(i) = valueSource(minIdx);
            continue;
        end

        weight = 1 ./ max(dist, 0.5) .^ settings.metricInterpPower;
        targetValue(i) = sum(weight .* valueSource) ./ sum(weight);
    end
end

function metrics = AI_one_eye_metrics(sensitivity, defectScore, eyeName, pointVersion, settings)
    % 计算单眼报告指标。
    %
    % sensitivity:
    %   N x 1敏感度样指标，范围0-100。数值越高，表示越接近正常。
    %   N可以是28，也可以是54，取决于当前报告版本。
    % defectScore:
    %   N x 1缺损概率样指标。数值越高，表示该眼该位置越可能异常。
    %   正常/可疑/缺损点数就是根据这个变量和阈值统计的。
    % pointVersion:
    %   'point28'表示真实采集的28点版本；
    %   'point54'表示插值后的SAP 24-2样式54点版本。
    threshold = AI_get_metric_threshold(settings, eyeName, pointVersion);
    epsVal = 1e-3;
    pointDb = 10 * log10(max(sensitivity, epsVal) ./ 100);

    metrics = struct();
    metrics.eye = eyeName;
    metrics.pointVersion = pointVersion;
    metrics.pointCount = numel(sensitivity);
    metrics.normalThreshold = threshold.normal;
    metrics.defectThreshold = threshold.defect;
    % VFI使用缺损分数扣分算法计算：
    %   defectScore < 正常阈值：该点不扣分；
    %   正常阈值 <= defectScore < 缺损阈值：按比例扣分；
    %   defectScore >= 缺损阈值：该点扣掉完整点位分数。
    % dotScore = 100 / N，因此28点和54点都可以统一映射到0-100分。
    metrics.VFI = AI_round4(AI_vfi_from_defect_score(defectScore, threshold));
    metrics.MD = AI_round4(mean(pointDb, 'omitnan'));
    metrics.PSD = AI_round4(std(pointDb, 1, 'omitnan'));
    metrics.nNormal = sum(defectScore < threshold.normal);
    metrics.nSuspect = sum(defectScore >= threshold.normal & ...
        defectScore < threshold.defect);
    metrics.nDefect = sum(defectScore >= threshold.defect);
    metrics.judgement = AI_eye_judgement(metrics);
end

function VFI = AI_vfi_from_defect_score(defectScore, threshold)
    % 根据缺损分数计算VFI。
    %
    % 输入：
    %   defectScore:
    %       N x 1缺损概率样分数。数值越大，表示越可能异常。
    %   threshold.normal:
    %       正常阈值。低于该阈值时alpha=0，不扣分。
    %   threshold.defect:
    %       缺损阈值。高于该阈值时alpha=1，扣除完整点位分数。
    %
    % 输出：
    %   VFI:
    %       0-100之间的视野功能指数。

    defectScore = defectScore(:);
    validIdx = isfinite(defectScore);
    validDefectScore = defectScore(validIdx);

    if isempty(validDefectScore)
        VFI = NaN;
        return;
    end

    pointCount = numel(validDefectScore);
    dotScore = 100 / pointCount;

    alpha = zeros(pointCount, 1);
    alpha(validDefectScore >= threshold.defect) = 1;

    middleIdx = validDefectScore >= threshold.normal & ...
        validDefectScore < threshold.defect;
    alpha(middleIdx) = (validDefectScore(middleIdx) - threshold.normal) ./ ...
        (threshold.defect - threshold.normal);

    VFI = 100 - sum(alpha) * dotScore;
    VFI = max(0, min(100, VFI));
end

function threshold = AI_get_metric_threshold(settings, eyeName, pointVersion)
    % 读取当前眼别和当前点位版本对应的点数统计阈值。
    %
    % eyeName:
    %   '左眼'或'右眼'。
    % pointVersion:
    %   'point28'或'point54'。
    %
    % 输出threshold.normal/threshold.defect用于统计正常点、可疑点和缺损点。
    % 如果某个字段缺失，会退回到旧版全局阈值，避免旧参数结构报错。
    versionKey = lower(char(pointVersion));
    switch versionKey
        case {'point28', '28'}
            versionKey = 'point28';
        case {'point54', 'sap54', '54'}
            versionKey = 'point54';
        otherwise
            error('Unsupported pointVersion for threshold: %s', pointVersion);
    end

    if contains(char(eyeName), '左')
        eyeKey = 'left';
    elseif contains(char(eyeName), '右')
        eyeKey = 'right';
    else
        error('Unsupported eyeName for threshold: %s', eyeName);
    end

    threshold = struct();
    if isfield(settings, 'metricThreshold') && ...
            isfield(settings.metricThreshold, versionKey) && ...
            isfield(settings.metricThreshold.(versionKey), eyeKey)
        threshold = settings.metricThreshold.(versionKey).(eyeKey);
    end

    if ~isfield(threshold, 'normal') || isempty(threshold.normal)
        threshold.normal = settings.metricNormalThreshold;
    end
    if ~isfield(threshold, 'defect') || isempty(threshold.defect)
        threshold.defect = settings.metricDefectThreshold;
    end

    if threshold.normal >= threshold.defect
        error(['Metric threshold error: normal threshold must be smaller ', ...
            'than defect threshold. pointVersion=%s, eyeName=%s'], ...
            pointVersion, eyeName);
    end
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

function reportEyeResult = AI_select_eye_result_for_report(eyeResult, pointVersion)
    % 根据报告版本选择对应的指标。
    %
    % eyeResult:
    %   AI_compute_eye_indices输出的总结果，里面同时保存28点和54点指标。
    % pointVersion:
    %   'point28'表示报告采用28点图和28点指标；
    %   'point54'表示报告采用54点图和54点指标。
    % reportEyeResult:
    %   专门给AI_write_report_figure使用的结构体。
    %   它的leftMetrics/rightMetrics/overallJudgement已经切换到指定版本。
    reportEyeResult = eyeResult;

    switch lower(char(pointVersion))
        case 'point28'
            reportEyeResult.leftMetrics = eyeResult.leftMetrics28;
            reportEyeResult.rightMetrics = eyeResult.rightMetrics28;
            reportEyeResult.overallJudgement = eyeResult.overallJudgement28;
            reportEyeResult.reportPointVersion = 'point28';
            reportEyeResult.reportPointLabel = '28点版本';
        case {'point54', 'sap54'}
            reportEyeResult.leftMetrics = eyeResult.leftMetrics54;
            reportEyeResult.rightMetrics = eyeResult.rightMetrics54;
            reportEyeResult.overallJudgement = eyeResult.overallJudgement54;
            reportEyeResult.reportPointVersion = 'point54';
            reportEyeResult.reportPointLabel = '54点版本';
        otherwise
            error('Unsupported report pointVersion: %s', pointVersion);
    end
end

function reportFiles = AI_write_report_figure(patientInfo, clinicalResult, eyeResult, mapResult, settings, reportVersion)
    % 拼接单个版本的PNG/PDF报告。
    %
    % eyeResult:
    %   已经通过AI_select_eye_result_for_report选好的报告指标。
    %   因此这里不再判断28点/54点，只负责把当前版本写到报告上。
    % mapResult:
    %   当前版本对应的六张视野图路径，包括密度图、数值图、灰度方块图。
    % reportVersion:
    %   输出文件名后缀。建议使用'point28'或'point54'。
    if nargin < 6 || isempty(reportVersion)
        reportVersion = 'point54';
    end

    if isfield(eyeResult, 'reportPointLabel')
        reportPointLabel = eyeResult.reportPointLabel;
    else
        reportPointLabel = reportVersion;
    end

    reportPng = fullfile(settings.outputDir, ['AI_SAP_like_report_', reportVersion, '.png']);
    reportPdf = fullfile(settings.outputDir, ['AI_SAP_like_report_', reportVersion, '.pdf']);

    fig = figure('Color', 'w', 'Position', [80, 60, 1650, 1120], ...
        'Visible', 'off');
    fontName = 'Microsoft YaHei';

    AI_add_textbox(fig, [0.035, 0.925, 0.45, 0.05], ...
        ['DCPM客观视野检测报告（', reportPointLabel, '）'], 22, 'bold', fontName);
    AI_add_textbox(fig, [0.64, 0.925, 0.32, 0.04], ...
        ['报告生成时间：', datestr(now, 'yyyy-mm-dd HH:MM')], 10, 'normal', fontName);

    infoText = AI_patient_info_text(patientInfo, settings);
    AI_add_textbox(fig, [0.035, 0.825, 0.93, 0.095], infoText, 10.5, 'normal', fontName);

    %% 报告图像区域：使用更大的图框，插图函数内部会裁剪白边并保持原始长宽比
    % imgBoxW/imgBoxH 是每张子图在总报告中的最大可用区域，不会强行拉伸图片。
    imgBoxW = 0.240;
    imgBoxH = 0.300;
    imgX = [0.025, 0.265, 0.505];
    leftY = 0.505;
    rightY = 0.185;

    AI_add_report_image(fig, mapResult.leftDensityPng, [imgX(1), leftY, imgBoxW, imgBoxH], settings);
    AI_add_report_image(fig, mapResult.leftValuePng, [imgX(2), leftY, imgBoxW, imgBoxH], settings);
    AI_add_report_image(fig, mapResult.leftPng, [imgX(3), leftY, imgBoxW, imgBoxH], settings);
    AI_add_report_image(fig, mapResult.rightDensityPng, [imgX(1), rightY, imgBoxW, imgBoxH], settings);
    AI_add_report_image(fig, mapResult.rightValuePng, [imgX(2), rightY, imgBoxW, imgBoxH], settings);
    AI_add_report_image(fig, mapResult.rightPng, [imgX(3), rightY, imgBoxW, imgBoxH], settings);

    leftMetricText = AI_metric_text(['左眼指标（', reportPointLabel, '）'], eyeResult.leftMetrics);
    rightMetricText = AI_metric_text(['右眼指标（', reportPointLabel, '）'], eyeResult.rightMetrics);
    AI_add_textbox(fig, [0.765, 0.565, 0.20, 0.20], leftMetricText, 10.5, 'normal', fontName);
    AI_add_textbox(fig, [0.765, 0.335, 0.20, 0.20], rightMetricText, 10.5, 'normal', fontName);

    conclusionText = AI_conclusion_text(clinicalResult, eyeResult);
    AI_add_textbox(fig, [0.035, 0.055, 0.93, 0.105], conclusionText, 10.5, 'normal', fontName);

    annotation(fig, 'line', [0.035, 0.965], [0.815, 0.815], 'Color', [0.35, 0.35, 0.35]);
    annotation(fig, 'line', [0.755, 0.755], [0.17, 0.805], 'Color', [0.35, 0.35, 0.35]);
    annotation(fig, 'line', [0.035, 0.965], [0.17, 0.17], 'Color', [0.35, 0.35, 0.35]);

    exportgraphics(fig, reportPng, 'Resolution', 300);
    exportgraphics(fig, reportPdf, 'ContentType', 'vector');
    close(fig);

    reportFiles = struct('png', reportPng, 'pdf', reportPdf, ...
        'pointVersion', reportVersion);
end

function AI_add_report_image(fig, imageFile, pos, settings)
    % 将单张视野图放入总报告。
    % 优先截取源图中的主axes区域，只保留视野图主体；
    % 再根据裁剪后图像的真实长宽比调整axes位置，避免横向压缩或纵向拉伸。
    img = imread(imageFile);
    if settings.reportCropToAxes
        img = AI_crop_axes_region(img, settings.reportMapAxesPosition, ...
            settings.reportAxesCropPadPx);
    else
        img = AI_crop_white_margin(img, settings.reportImageWhiteTolerance);
    end
    img = AI_crop_white_margin(img, settings.reportImageWhiteTolerance);

    figPos = fig.Position;
    figW = figPos(3);
    figH = figPos(4);
    imgH = size(img, 1);
    imgW = size(img, 2);
    imgAspect = imgW / imgH;
    boxAspect = (pos(3) * figW) / (pos(4) * figH);

    fitPos = pos;
    if imgAspect > boxAspect
        fitH = pos(3) * figW / imgAspect / figH;
        fitPos(2) = pos(2) + (pos(4) - fitH) / 2;
        fitPos(4) = fitH;
    else
        fitW = pos(4) * figH * imgAspect / figW;
        fitPos(1) = pos(1) + (pos(3) - fitW) / 2;
        fitPos(3) = fitW;
    end

    ax = axes(fig, 'Position', fitPos);
    image(ax, img);
    axis(ax, 'image');
    axis(ax, 'off');
end

function croppedImg = AI_crop_axes_region(img, axesPosition, padPx)
    % 根据源视野图的axesPosition裁剪主坐标轴区域。
    % axesPosition采用MATLAB normalized单位：[left, bottom, width, height]。
    imgH = size(img, 1);
    imgW = size(img, 2);
    x1 = floor(axesPosition(1) * imgW) + 1;
    x2 = ceil((axesPosition(1) + axesPosition(3)) * imgW);
    y1 = floor((1 - axesPosition(2) - axesPosition(4)) * imgH) + 1;
    y2 = ceil((1 - axesPosition(2)) * imgH);

    x1 = max(1, x1 - padPx);
    x2 = min(imgW, x2 + padPx);
    y1 = max(1, y1 - padPx);
    y2 = min(imgH, y2 + padPx);
    croppedImg = img(y1:y2, x1:x2, :);
end

function croppedImg = AI_crop_white_margin(img, whiteTolerance)
    % 裁剪接近纯白的外边距。
    % whiteTolerance越高，裁剪越保守；当前只去掉四周连续白边，
    % 保留坐标轴、标题、文字和视野图主体。
    if ismatrix(img)
        grayImg = img;
    else
        grayImg = min(img(:, :, 1:3), [], 3);
    end

    contentMask = grayImg < whiteTolerance;
    rowHasContent = any(contentMask, 2);
    colHasContent = any(contentMask, 1);
    if ~any(rowHasContent) || ~any(colHasContent)
        croppedImg = img;
        return;
    end

    rowIdx = find(rowHasContent);
    colIdx = find(colHasContent);
    pad = 8;
    r1 = max(1, rowIdx(1) - pad);
    r2 = min(size(img, 1), rowIdx(end) + pad);
    c1 = max(1, colIdx(1) - pad);
    c2 = min(size(img, 2), colIdx(end) + pad);
    croppedImg = img(r1:r2, c1:c2, :);
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

function txt = AI_patient_info_text(patientInfo, ~)
    % 报告顶部只显示患者基本信息，不显示数据文件夹。
    % 检测结果由报告底部的结构化结论和右侧指标区体现，不放在患者信息区。
    txt = sprintf(['患者编号：%s    姓名：%s    性别：%s    年龄：%s\n', ...
        '检查日期：%s    检查人员：%s'], ...
        AI_get_info(patientInfo, 'patientId'), AI_get_info(patientInfo, 'name'), ...
        AI_get_info(patientInfo, 'sex'), AI_get_info(patientInfo, 'age'), ...
        AI_get_info(patientInfo, 'examDate'), AI_get_info(patientInfo, 'operator'));

    notes = strtrim(AI_get_info(patientInfo, 'notes'));
    if ~isempty(notes) && ~strcmpi(notes, 'None')
        txt = sprintf('%s\n备注：%s', txt, notes);
    end
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

function txt = AI_conclusion_text(~, eyeResult)
    txt = sprintf(['结构化结论\n', ...
        '总体判断：%s    左眼判断：%s    右眼判断：%s\n', ...
        '说明：本报告基于脑电信号校准技术生成，该技术仍处于探索阶段，实际视野状态以临床检测报告为准！'], ...
        eyeResult.overallJudgement, eyeResult.leftMetrics.judgement, ...
        eyeResult.rightMetrics.judgement);
        
        
     % '判断标准：VFI > 95 为视野正常，70 <= VFI <= 95 为可疑异常，VFI < 70 为视野异常。\n', ...
        % 'OverallReport：meanVFI=%.4f, meanVFI_loss=%.4f, meanMD_loss=%.4f, meanPSD=%.4f, meanDefectBurden=%.4f\n', ...
end

function AI_write_report_tables(clinicalResult, eyeResult, settings)
    % 输出报告相关Excel表格。
    %
    % PointResults:
    %   28个真实检测点的三分类概率结果。
    % GroupSummary:
    %   每组train/test文件的基本信息和4点预测模式。
    % EyeMetrics:
    %   同时保存28点版本和54点版本的左右眼VFI、MD、PSD和点数统计。
    %   pointVersion列用于区分当前行对应的是point28还是point54。
    % PointSensitivity:
    %   28点左右眼敏感度样指标和缺损分数。
    % PointSensitivity54:
    %   插值后的54点左右眼敏感度样指标和缺损分数。
    writetable(clinicalResult.pointTable, settings.excelFile, 'Sheet', 'PointResults');
    writetable(clinicalResult.groupTable, settings.excelFile, 'Sheet', 'GroupSummary');
    if isfield(clinicalResult, 'overallTable') && ~isempty(clinicalResult.overallTable)
        writetable(clinicalResult.overallTable, settings.excelFile, 'Sheet', 'OverallReport');
    end
    writetable(eyeResult.eyeMetricTable, settings.excelFile, 'Sheet', 'EyeMetrics');
    writetable(eyeResult.pointSensitivityTable, settings.excelFile, 'Sheet', 'PointSensitivity');
    writetable(eyeResult.pointSensitivity54Table, settings.excelFile, 'Sheet', 'PointSensitivity54');
end

function names = AI_point_table_names()
    names = {'group', 'point', 'globalPoint', 'trainEventType', 'testEventType', ...
        'predictedLabel', 'predictedState', 'pNormal', 'pLeftAbnormal', ...
        'pRightAbnormal', 'pDefect'};
end

function names = AI_group_table_names()
    names = {'group', 'trainFile', 'testFile', 'trainTrials', 'testTrials', ...
        'predictedPattern'};
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
