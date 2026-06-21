function result = AI_plot_sap_like_vf_report(sensitivity, varargin)
% 绘制类似SAP的视野缺损情况散点图。
%
% 这个函数可以接收两种点位数量：
%   1) 28点：当前实验真实采集的28个检测点；
%   2) 54点：插值后的SAP 24-2样伪检测点。
%
% 输入数据可以是：
%   N x 2：左右眼敏感度样指标，第一列左眼，第二列右眼；
%   N x 2：左右眼缺损概率样指标，此时需要设置'inputValueType','defectScore'；
%   N x 3：三分类概率，三列依次为正常、左眼异常、右眼异常；
%   N x 1：状态标签，1正常，2左眼异常，3右眼异常，0或4双眼异常。
% 其中N可以是28或54。
%
% Example:
%   sens = 100 * ones(28, 2);
%   sens([3 10 25], 1) = 15;
%   sens([8 14], 2) = 20;
%   AI_plot_sap_like_vf_report(sens, 'filePrefix', 'subject01');

    settings = AI_parse_inputs(varargin{:});

    if nargin < 1 || isempty(sensitivity)
        sensitivity = 100 * ones(28, 2);
    end

    % ==================== 1. 整理输入数据 ====================
    % sensitivity: N x 2，左右眼敏感度样指标；
    % plotValue: N x 2，左右眼缺损概率样指标，真正用于灰度/密度绘图。
    [sensitivity, plotValue, pointMode] = AI_prepare_plot_values(sensitivity, settings);

    % ==================== 2. 根据点位数量生成左右眼坐标 ====================
    % 28点时左右眼坐标相同；54点时左右眼鼻侧延伸点是镜像的。
    [leftCoordTable, rightCoordTable] = AI_get_plot_coord_tables(pointMode, settings);
    settings = AI_adjust_axis_limit_for_input_points(settings, leftCoordTable, rightCoordTable);

    if ~exist(settings.outputDir, 'dir')
        mkdir(settings.outputDir);
    end

    % ==================== 3. 绘制6张单独视野图 ====================
    leftFig = AI_draw_report_map(leftCoordTable, plotValue(:, 1), ...
        settings.leftTitle, settings);
    rightFig = AI_draw_report_map(rightCoordTable, plotValue(:, 2), ...
        settings.rightTitle, settings);
    leftDensityFig = AI_draw_density_map(leftCoordTable, plotValue(:, 1), ...
        settings.leftDensityTitle, settings);
    rightDensityFig = AI_draw_density_map(rightCoordTable, plotValue(:, 2), ...
        settings.rightDensityTitle, settings);
    leftValueFig = AI_draw_value_map(leftCoordTable, plotValue(:, 1), ...
        settings.leftValueTitle, settings);
    rightValueFig = AI_draw_value_map(rightCoordTable, plotValue(:, 2), ...
        settings.rightValueTitle, settings);

    leftPng = fullfile(settings.outputDir, [settings.filePrefix '_left_eye_report.png']);
    rightPng = fullfile(settings.outputDir, [settings.filePrefix '_right_eye_report.png']);
    leftDensityPng = fullfile(settings.outputDir, [settings.filePrefix '_left_eye_density.png']);
    rightDensityPng = fullfile(settings.outputDir, [settings.filePrefix '_right_eye_density.png']);
    leftValuePng = fullfile(settings.outputDir, [settings.filePrefix '_left_eye_value.png']);
    rightValuePng = fullfile(settings.outputDir, [settings.filePrefix '_right_eye_value.png']);
    leftFigFile = fullfile(settings.outputDir, [settings.filePrefix '_left_eye_report.fig']);
    rightFigFile = fullfile(settings.outputDir, [settings.filePrefix '_right_eye_report.fig']);
    leftDensityFigFile = fullfile(settings.outputDir, [settings.filePrefix '_left_eye_density.fig']);
    rightDensityFigFile = fullfile(settings.outputDir, [settings.filePrefix '_right_eye_density.fig']);
    leftValueFigFile = fullfile(settings.outputDir, [settings.filePrefix '_left_eye_value.fig']);
    rightValueFigFile = fullfile(settings.outputDir, [settings.filePrefix '_right_eye_value.fig']);
    coordFile = fullfile(settings.outputDir, [settings.filePrefix '_point_angles.xlsx']);

    if settings.saveFigure
        print(leftFig, leftPng, '-dpng', ['-r', num2str(settings.resolution)]);
        print(rightFig, rightPng, '-dpng', ['-r', num2str(settings.resolution)]);
        print(leftDensityFig, leftDensityPng, '-dpng', ['-r', num2str(settings.resolution)]);
        print(rightDensityFig, rightDensityPng, '-dpng', ['-r', num2str(settings.resolution)]);
        print(leftValueFig, leftValuePng, '-dpng', ['-r', num2str(settings.resolution)]);
        print(rightValueFig, rightValuePng, '-dpng', ['-r', num2str(settings.resolution)]);
        savefig(leftFig, leftFigFile);
        savefig(rightFig, rightFigFile);
        savefig(leftDensityFig, leftDensityFigFile);
        savefig(rightDensityFig, rightDensityFigFile);
        savefig(leftValueFig, leftValueFigFile);
        savefig(rightValueFig, rightValueFigFile);

        outTable = AI_build_output_coord_table(leftCoordTable, rightCoordTable, ...
            sensitivity, plotValue);
        writetable(outTable, coordFile, 'Sheet', 'PointAngle');
    end

    if ~settings.showFigure
        close(leftFig);
        close(rightFig);
        close(leftDensityFig);
        close(rightDensityFig);
        close(leftValueFig);
        close(rightValueFig);
    end

    result = struct();
    result.pointMode = pointMode;
    result.leftCoordTable = leftCoordTable;
    result.rightCoordTable = rightCoordTable;
    result.sensitivity = sensitivity;
    result.plotValue = plotValue;
    result.leftPng = leftPng;
    result.rightPng = rightPng;
    result.leftDensityPng = leftDensityPng;
    result.rightDensityPng = rightDensityPng;
    result.leftValuePng = leftValuePng;
    result.rightValuePng = rightValuePng;
    result.leftFig = leftFigFile;
    result.rightFig = rightFigFile;
    result.leftDensityFig = leftDensityFigFile;
    result.rightDensityFig = rightDensityFigFile;
    result.leftValueFig = leftValueFigFile;
    result.rightValueFig = rightValueFigFile;
    result.coordFile = coordFile;
end

function settings = AI_parse_inputs(varargin)
    % ==================== 绘图基础参数 ====================
    settings = struct();
    settings.outputDir = fullfile(fileparts(mfilename('fullpath')), ...
        'AI_SAP_like_visual_field_report');
    settings.filePrefix = 'AI_SAP_like_VF';
    settings.saveFigure = true;
    settings.showFigure = false;
    settings.resolution = 300;

    % ==================== 输入点位模式 ====================
    % inputPointMode:
    %   'auto'    自动根据输入行数判断是28点还是54点；
    %   'point28' 强制按28个真实检测点解释输入；
    %   'sap54'   强制按54个SAP 24-2样伪检测点解释输入。
    settings.inputPointMode = 'auto';
    % inputValueType:
    %   'sensitivity' 表示N x 2输入是左右眼敏感度样指标；
    %   'defectScore' 表示N x 2输入是左右眼缺损概率样指标；
    %   'probability' 表示N x 3输入是正常/左眼异常/右眼异常三分类概率；
    %   'state' 表示N x 1输入是状态标签。
    settings.inputValueType = 'sensitivity';

    % ==================== 各类图标题和文字 ====================
    settings.leftTitle = 'Left eye grayscale field';
    settings.rightTitle = 'Right eye grayscale field';
    settings.leftDensityTitle = 'Left eye density plot';
    settings.rightDensityTitle = 'Right eye density plot';
    settings.leftValueTitle = 'Left eye numeric plot';
    settings.rightValueTitle = 'Right eye numeric plot';
    settings.xLabel = 'Visual field X (deg)';
    settings.yLabel = 'Visual field Y (deg)';
    settings.fontName = 'Microsoft YaHei';

    % ==================== 28点坐标换算参数 ====================
    % 当前28个真实检测点先用像素坐标记录，再通过以下锚点换算成视角坐标。
    % anchorPixel: 原始刺激程序中的像素距离；
    % anchorDeg:   对应的视角距离，单位degree。
    settings.angleMode = 'component_anchor';
    settings.anchorPixel = [0, 76, 173, 286, 397];
    settings.anchorDeg = [0, 4, 9, 19, 24];

    % ==================== 灰阶方块图参数 ====================
    settings.axisLimitDeg = 27;
    settings.squareSizeDeg = 3.5;
    settings.drawSensitivityText = false;
    settings.drawFixation = false;
    settings.drawBlindSpot = false;
    settings.blindSpotXY = [15, 0];
    settings.blindSpotRadius = 2.2;
    settings.colorbarLabel = '缺损概率样指标';
    settings.lowClip = 0.10;
    settings.highClip = 0.25;
    settings.whiteClip = 0.10;
    settings.grayLower = 0.15;
    settings.drawColorbar = true;
    settings.forceColorbar = true;
    settings.figurePosition = [120, 80, 930, 596];
    settings.axesPosition = [0.285, 0.23, 0.43, 0.68];

    % ==================== 密度散点图参数 ====================
    % densityBaseSpacingDeg: 背景均匀点阵的点间距，调小会让底图更密。
    settings.densityDotSpacingDeg = 0.42;
    settings.densityDotSize = 7;
    settings.densityBaseSpacingDeg = 1.05;
    % densityExtraSpacingDeg: 异常区域加密点阵的候选点间距，调小会让异常区域更细腻。
    settings.densityExtraSpacingDeg = 0.34;
    % densityGamma: 灰度值到点密度的非线性系数。
    % 小于1时中等异常会更容易显示出密度变化。
    settings.densityGamma = 0.85;
    % densityDomainPaddingDeg: 密度图外轮廓向外扩展的视角范围。
    settings.densityDomainPaddingDeg = 2.6;
    % densityExtraRectWidthDeg/densityExtraRectHeightDeg:
    % 每个检测点影响周围点密度的空间范围。
    settings.densityExtraRectWidthDeg = 7.2;
    settings.densityExtraRectHeightDeg = 7.2;
    settings.densityExtraShapePower = 6;
    % densityNeighborRadiusDeg/densitySmoothBlend/densityIsolatedDelta:
    % 旧版密度图内部平滑参数。当前绘图脚本不再做28点到54点转换，
    % 这些空间修正已经放在AI_generate_sap_like_clinical_report.m中完成。
    settings.densityNeighborRadiusDeg = 8.8;
    settings.densitySmoothBlend = 0.25;
    settings.densityIsolatedDelta = 0.08;
    settings.densityInterpPower = 2.4;
    settings.densityPseudoSmoothIterations = 2;
    settings.valueFontSize = 11;
    settings.normalEdgeColor = [0, 0, 0];
    settings.abnormalEdgeColor = [0, 0, 0];
    settings.axisLineWidth = 1.1;

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

    if strcmp(settings.colorbarLabel, 'Sensitivity-like index') || ...
            strcmp(settings.colorbarLabel, '敏感度样指标')
        settings.colorbarLabel = '缺损概率样指标';
    end
end

function [sensitivity, plotValue, pointMode] = AI_prepare_plot_values(inputValue, settings)
    % 整理绘图输入。
    %
    % 输入：
    %   inputValue:
    %       可以是N x 2敏感度、N x 3概率，或N x 1状态标签。
    %   settings.inputPointMode:
    %       指定输入是28点还是54点；auto表示自动判断。
    %
    % 输出：
    %   sensitivity:
    %       N x 2，左右眼敏感度样指标。
    %   plotValue:
    %       N x 2，左右眼缺损概率样指标，真正用于绘图。
    %   pointMode:
    %       'point28'或'sap54'。
    if ~isnumeric(inputValue)
        error('sensitivity must be numeric.');
    end

    inputValue = double(inputValue);

    % ==================== 1. 自动判断输入点数 ====================
    inputSize = size(inputValue);
    if inputSize(2) == 2 || inputSize(2) == 3
        pointNum = inputSize(1);
    elseif inputSize(1) == 2 || inputSize(1) == 3
        pointNum = inputSize(2);
    else
        pointNum = numel(inputValue);
    end
    pointMode = AI_choose_point_mode(pointNum, settings.inputPointMode);

    % ==================== 2. 根据输入形状转换为sensitivity和plotValue ====================
    if inputSize(2) == 2 && ismember(inputSize(1), [28, 54])
        if strcmpi(settings.inputValueType, 'defectScore')
            plotValue = max(0, inputValue);
            sensitivity = max(0, min(100, 100 .* (1 - plotValue)));
        else
            sensitivity = inputValue;
            pointProb = AI_recover_point_prob_from_eye_sensitivity(sensitivity);
            plotValue = AI_defect_score_from_point_prob(pointProb);
        end
    elseif inputSize(2) == 3 && ismember(inputSize(1), [28, 54])
        pointProb = inputValue;
        pointProb = max(pointProb, 0);
        pointProb = pointProb ./ sum(pointProb, 2);
        sensitivity = [100 * (pointProb(:, 1) + pointProb(:, 3)), ...
            100 * (pointProb(:, 1) + pointProb(:, 2))];
        plotValue = AI_defect_score_from_point_prob(pointProb);
    elseif inputSize(1) == 2 && ismember(inputSize(2), [28, 54])
        if strcmpi(settings.inputValueType, 'defectScore')
            plotValue = max(0, inputValue');
            sensitivity = max(0, min(100, 100 .* (1 - plotValue)));
        else
            sensitivity = inputValue';
            pointProb = AI_recover_point_prob_from_eye_sensitivity(sensitivity);
            plotValue = AI_defect_score_from_point_prob(pointProb);
        end
    elseif inputSize(1) == 3 && ismember(inputSize(2), [28, 54])
        pointProb = inputValue';
        pointProb = max(pointProb, 0);
        pointProb = pointProb ./ sum(pointProb, 2);
        sensitivity = [100 * (pointProb(:, 1) + pointProb(:, 3)), ...
            100 * (pointProb(:, 1) + pointProb(:, 2))];
        plotValue = AI_defect_score_from_point_prob(pointProb);
    elseif ismember(numel(inputValue), [28, 54])
        state = inputValue(:);
        sensitivity = 100 * ones(numel(state), 2);
        for i = 1:numel(state)
            switch state(i)
                case 1
                    sensitivity(i, :) = [100, 100];
                case 2
                    sensitivity(i, :) = [0, 100];
                case 3
                    sensitivity(i, :) = [100, 0];
                case {0, 4}
                    sensitivity(i, :) = [0, 0];
                otherwise
                    sensitivity(i, :) = [50, 50];
            end
        end
        pointProb = AI_recover_point_prob_from_eye_sensitivity(sensitivity);
        plotValue = AI_defect_score_from_point_prob(pointProb);
    else
        error('Input must be N-by-2, N-by-3, or N labels. N must be 28 or 54.');
    end

    % ==================== 3. 检查输入点数是否和指定模式一致 ====================
    if strcmp(pointMode, 'point28') && size(sensitivity, 1) ~= 28
        error('inputPointMode is point28, but input has %d points.', size(sensitivity, 1));
    elseif strcmp(pointMode, 'sap54') && size(sensitivity, 1) ~= 54
        error('inputPointMode is sap54, but input has %d points.', size(sensitivity, 1));
    end

    sensitivity = max(0, min(100, sensitivity));
    plotValue = max(0, plotValue);
end

function pointMode = AI_choose_point_mode(pointNum, inputPointMode)
    % 根据输入点数和用户设置决定当前绘图使用28点还是54点。
    switch lower(char(inputPointMode))
        case 'auto'
            if pointNum == 28
                pointMode = 'point28';
            elseif pointNum == 54
                pointMode = 'sap54';
            else
                error('Auto mode only supports 28 or 54 points, but got %d.', pointNum);
            end
        case {'point28', '28'}
            pointMode = 'point28';
        case {'sap54', 'point54', '54'}
            pointMode = 'sap54';
        otherwise
            error('Unsupported inputPointMode: %s', inputPointMode);
    end
end

function pointProb = AI_recover_point_prob_from_eye_sensitivity(sensitivity)
    % 从旧版左右眼敏感度样指标反推三类归一化评分
    leftSensitivity = max(0, min(100, sensitivity(:, 1))) ./ 100;
    rightSensitivity = max(0, min(100, sensitivity(:, 2))) ./ 100;

    pLeft = 1 - leftSensitivity;
    pRight = 1 - rightSensitivity;
    pNormal = leftSensitivity + rightSensitivity - 1;
    pointProb = [pNormal, pLeft, pRight];
    pointProb = max(pointProb, 0);
    pointProb = pointProb ./ sum(pointProb, 2);
end

function [leftCoordTable, rightCoordTable] = AI_get_plot_coord_tables(pointMode, settings)
    % 根据绘图模式生成左右眼坐标表。
    %
    % point28:
    %   左右眼都使用当前实验真实采集的28个检测点坐标。
    % sap54:
    %   使用SAP 24-2样54点坐标，左右眼鼻侧延伸点镜像。
    switch pointMode
        case 'point28'
            pixelXY = AI_get_pixel_coordinates();
            coordTable28 = AI_pixel_to_visual_angle(pixelXY, settings);
            leftCoordTable = coordTable28;
            rightCoordTable = coordTable28;
        case 'sap54'
            [leftX, leftY] = AI_get_sap24_2_pseudo_coordinates('left');
            [rightX, rightY] = AI_get_sap24_2_pseudo_coordinates('right');
            leftCoordTable = AI_xy_to_coord_table(leftX, leftY, 'L');
            rightCoordTable = AI_xy_to_coord_table(rightX, rightY, 'R');
        otherwise
            error('Unsupported pointMode: %s', pointMode);
    end
end

function settings = AI_adjust_axis_limit_for_input_points(settings, leftCoordTable, rightCoordTable)
    % 根据实际输入点位自动放宽坐标范围。
    %
    % 为什么需要这一步：
    %   54点SAP样式坐标中，鼻侧延伸点会到达±27度。
    %   如果axisLimitDeg也刚好是27度，灰度方块图最外侧的方块会被边界裁掉。
    %
    % 这里会根据左右眼所有点位的最大坐标，给坐标范围额外留出半个方块加少量边距。
    % 对28点版本通常不会改变原来的axisLimitDeg；对54点版本会自动放宽到约29-30度。
    allX = [leftCoordTable.vfXDeg; rightCoordTable.vfXDeg];
    allY = [leftCoordTable.vfYDeg; rightCoordTable.vfYDeg];
    maxPointDeg = max(abs([allX(:); allY(:)]));
    neededLimitDeg = maxPointDeg + settings.squareSizeDeg / 2 + 0.75;
    settings.axisLimitDeg = max(settings.axisLimitDeg, neededLimitDeg);
end

function coordTable = AI_xy_to_coord_table(pointX, pointY, namePrefix)
    % 把视角坐标转换为和28点坐标表类似的table，便于绘图函数共用。
    pointX = pointX(:);
    pointY = pointY(:);
    pointIndex = (1:numel(pointX))';
    pointName = compose("%s%d", string(namePrefix), pointIndex);
    pixelX = nan(numel(pointX), 1);
    pixelY = nan(numel(pointX), 1);
    pixelRadius = nan(numel(pointX), 1);
    polarAngleDeg = atan2d(pointY, pointX);
    vfXDeg = pointX;
    vfYDeg = pointY;
    eccentricityDeg = hypot(pointX, pointY);
    coordTable = table(pointIndex, pointName, pixelX, pixelY, ...
        pixelRadius, polarAngleDeg, vfXDeg, vfYDeg, eccentricityDeg);
end

function outTable = AI_build_output_coord_table(leftCoordTable, rightCoordTable, sensitivity, plotValue)
    % 保存本次绘图使用的左右眼坐标和数值。
    % 28点时左右眼坐标相同；54点时左右眼坐标可能因为鼻侧延伸而不同。
    outTable = table((1:size(sensitivity, 1))', ...
        leftCoordTable.vfXDeg, leftCoordTable.vfYDeg, ...
        rightCoordTable.vfXDeg, rightCoordTable.vfYDeg, ...
        sensitivity(:, 1), sensitivity(:, 2), ...
        plotValue(:, 1), plotValue(:, 2), ...
        'VariableNames', {'pointIndex', ...
        'leftXDeg', 'leftYDeg', 'rightXDeg', 'rightYDeg', ...
        'leftSensitivity', 'rightSensitivity', ...
        'leftDefectScore', 'rightDefectScore'});
end

function plotValue = AI_defect_score_from_point_prob(pointProb)
    % 灰度图使用缺损概率样指标：
    % 左眼=(1-Pn)*PL，右眼=(1-Pn)*PR
    pNormal = pointProb(:, 1);
    pLeft = pointProb(:, 2);
    pRight = pointProb(:, 3);
    plotValue = [(1 - pNormal) .* pLeft, (1 - pNormal) .* pRight];
end

function pixelXY = AI_get_pixel_coordinates()
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
end

function coordTable = AI_pixel_to_visual_angle(pixelXY, settings)
    pixelX = pixelXY(:, 1);
    pixelY = pixelXY(:, 2);
    pixelRadius = hypot(pixelX, pixelY);
    polarAngleDeg = atan2d(pixelY, pixelX);

    switch lower(settings.angleMode)
        case 'component_anchor'
            absXDeg = interp1(settings.anchorPixel, settings.anchorDeg, ...
                abs(pixelX), 'pchip', 'extrap');
            absYDeg = interp1(settings.anchorPixel, settings.anchorDeg, ...
                abs(pixelY), 'pchip', 'extrap');
            vfXDeg = sign(pixelX) .* absXDeg;
            vfYDeg = sign(pixelY) .* absYDeg;
            eccentricityDeg = AI_combine_component_angles(vfXDeg, vfYDeg);

        case 'component_linear'
            pxPerDeg = settings.anchorPixel(2) / settings.anchorDeg(2);
            vfXDeg = pixelX ./ pxPerDeg;
            vfYDeg = pixelY ./ pxPerDeg;
            eccentricityDeg = AI_combine_component_angles(vfXDeg, vfYDeg);

        otherwise
            error('Unsupported angleMode: %s', settings.angleMode);
    end

    pointIndex = (1:28)';
    pointName = compose("P%d", pointIndex);
    coordTable = table(pointIndex, pointName, pixelX, pixelY, ...
        pixelRadius, polarAngleDeg, vfXDeg, vfYDeg, eccentricityDeg);
end

function eccentricityDeg = AI_combine_component_angles(vfXDeg, vfYDeg)
    eccentricityDeg = atan2d(sqrt(tand(vfXDeg).^2 + tand(vfYDeg).^2), 1);
end

function fig = AI_draw_report_map(coordTable, sensitivity, titleText, settings)
    % 绘制“灰阶方块图”。
    %
    % 输入：
    %   coordTable:
    %       当前绘图点位坐标表。28点或54点都可以，每一行是一个检测点。
    %       主要使用其中的vfXDeg和vfYDeg，也就是视野坐标，单位是degree。
    %   sensitivity:
    %       当前眼的缺损概率样指标或灰度指标。这里变量名沿用旧版，
    %       实际上传入的是plotValue(:, eye)，数值越大，方块越黑。
    %   titleText:
    %       这张图的标题，例如“左眼视野灰阶图”。
    %   settings:
    %       绘图参数结构体。你后续调图主要改AI_parse_inputs里的settings。
    %
    % 常改参数说明：
    %   settings.figurePosition:
    %       整张单独PNG图的窗口大小，影响保存图片的外部尺寸。
    %   settings.axesPosition:
    %       坐标轴在图中的位置，[left,bottom,width,height]，单位是归一化比例。
    %       想让视野图主体在PNG里更大，通常调大width/height。
    %   settings.axisLimitDeg:
    %       坐标轴显示范围。当前为27，表示x/y都显示-27到27度。
    %   settings.squareSizeDeg:
    %       每个检测点方块的边长，单位degree。调大方块更大，调小更稀疏。
    %   settings.lowClip/highClip/whiteClip:
    %       灰度映射范围。数值低于whiteClip接近白色，高于highClip接近黑色。
    %   settings.drawColorbar:
    %       是否显示色条。报告拼图中如果觉得色条占空间，可以设为false。

    % ==================== 1. 建立图窗和坐标轴 ====================
    fig = figure('Color', 'w', 'Position', settings.figurePosition);
    ax = axes(fig, 'Position', settings.axesPosition);
    hold(ax, 'on');

    % lim控制视野显示范围，例如lim=27表示显示-27到27度。
    lim = settings.axisLimitDeg;
    axis(ax, [-lim, lim, -lim, lim]);
    axis(ax, 'equal');
    set(ax, 'Color', 'w', 'YDir', 'normal');
    colormap(ax, flipud(gray(256)));

    % ==================== 2. 绘制水平和垂直中线 ====================
    % axisLineWidth控制中线粗细。
    plot(ax, [-lim, lim], [0, 0], 'k-', 'LineWidth', settings.axisLineWidth);
    plot(ax, [0, 0], [-lim, lim], 'k-', 'LineWidth', settings.axisLineWidth);

    % ==================== 3. 逐个点绘制灰阶方块 ====================
    % halfSize是方块半边长。settings.squareSizeDeg越大，每个点对应方块越大。
    halfSize = settings.squareSizeDeg / 2;
    for i = 1:height(coordTable)
        % value先被限制在lowClip到highClip之间，避免极端值让灰度失控。
        value = max(settings.lowClip, min(settings.highClip, sensitivity(i)));
        % grayValue越接近0越黑，越接近1越白。
        grayValue = 1 - (value - settings.whiteClip) ./ ...
            (settings.highClip - settings.whiteClip);
        grayValue = max(0, min(1, grayValue));
        faceColor = [grayValue, grayValue, grayValue];
        edgeColor = [0, 0, 0];
        lineWidth = 1;

        % x/y是该检测点在视野坐标系中的位置，单位degree。
        x = coordTable.vfXDeg(i);
        y = coordTable.vfYDeg(i);
        rectangle(ax, 'Position', ...
            [x - halfSize, y - halfSize, settings.squareSizeDeg, ...
            settings.squareSizeDeg], ...
            'FaceColor', faceColor, ...
            'EdgeColor', edgeColor, ...
            'LineWidth', lineWidth);
    end

    % ==================== 4. 可选绘制盲点和中央注视点 ====================
    % drawBlindSpot为true时，会画出盲点参考圆。
    if settings.drawBlindSpot
        theta = linspace(0, 2 * pi, 180);
        bx = settings.blindSpotXY(1) + settings.blindSpotRadius * cos(theta);
        by = settings.blindSpotXY(2) + settings.blindSpotRadius * sin(theta);
        plot(ax, bx, by, 'k--', 'LineWidth', 1.0);
    end

    % drawFixation为true时，会在中央画红色十字。
    if settings.drawFixation
        plot(ax, 0, 0, 'r+', 'MarkerSize', 14, 'LineWidth', 2.0);
    end

    % drawSensitivityText为true时，会在每个方块上写数值。
    % 如果方块太小或点太密，建议保持false。
    if settings.drawSensitivityText
        for i = 1:height(coordTable)
            textColor = AI_text_color_for_gray(sensitivity(i));
            text(ax, coordTable.vfXDeg(i), coordTable.vfYDeg(i), ...
                sprintf('%.0f', sensitivity(i)), ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'middle', ...
                'FontName', settings.fontName, ...
                'FontSize', 8.5, ...
                'FontWeight', 'bold', ...
                'Color', textColor, ...
                'Clipping', 'on');
        end
    end

    % ==================== 5. 坐标轴、标题和色条格式 ====================
    % 这里控制单独PNG图里的坐标轴显示。报告总图中会裁剪axes主体，
    % 所以如果你只想改报告拼图位置，应优先改AI_generate_sap_like_clinical_report。
    box(ax, 'off');
    ax.FontName = settings.fontName;
    ax.FontSize = 9.5;
    ax.XTick = -25:5:25;
    ax.YTick = -25:5:25;
    xlabel(ax, settings.xLabel, 'FontSize', 10.5, 'FontName', settings.fontName);
    ylabel(ax, settings.yLabel, 'FontSize', 10.5, 'FontName', settings.fontName);
    title(ax, titleText, 'FontSize', 12.5, 'FontWeight', 'bold', ...
        'FontName', settings.fontName);

    % caxis控制色条数值范围，要和上面的灰度映射范围保持一致。
    caxis(ax, [settings.lowClip, settings.highClip]);
    if settings.forceColorbar || settings.drawColorbar
        cb = colorbar(ax, 'eastoutside');
        cb.Label.String = settings.colorbarLabel;
        cb.Label.FontName = settings.fontName;
        cb.FontName = settings.fontName;
        cb.Ticks = [settings.whiteClip, settings.grayLower, 0.20, settings.highClip];
    end

    hold(ax, 'off');
end

function fig = AI_draw_density_map(coordTable, plotValue, titleText, settings)
    % 绘制“密度散点图”。
    %
    % 这张图不是直接画方块，而是在视野区域内铺很多小黑点。
    % 某个区域缺损分数越高，该区域额外保留的小黑点越多，看起来越密。
    %
    % 输入：
    %   coordTable:
    %       当前眼使用的点位坐标表。可以是28点，也可以是54点。
    %   plotValue:
    %       当前眼每个点的缺损概率样指标。数值越大，局部点密度越高。
    %   titleText:
    %       图标题。
    %   settings:
    %       绘图参数。
    % 注意：
    %   本函数只负责画图，不负责点数转换。
    %   如果输入28个点，就画28个点对应的密度图；
    %   如果输入54个点，就画54个点对应的密度图。
    %   28点到54点的插值和平滑统一在AI_generate_sap_like_clinical_report.m中完成。
    %
    % 常改参数说明：
    %   settings.densityDotSize:
    %       小黑点大小。调大点更粗，调小更细。
    %   settings.densityBaseSpacingDeg:
    %       背景基础点阵间距。调小会让整张图底部点更多。
    %   settings.densityExtraSpacingDeg:
    %       异常区域加密点阵的候选间距。调小会让异常区域更细腻，但图可能更黑。
    %   settings.densityExtraRectWidthDeg / densityExtraRectHeightDeg:
    %       每个检测点影响周围密度的范围。调大后异常区域扩散更宽。
    %   settings.densityGamma:
    %       缺损分数到点密度的非线性映射。调小会增强中等缺损的显示。
    %   settings.densityDomainPaddingDeg:
    %       密度图外轮廓向外扩展的范围。调大后整体点阵范围更大。
    % ==================== 1. 建立图窗和坐标轴 ====================
    fig = figure('Color', 'w', 'Position', settings.figurePosition);
    ax = axes(fig, 'Position', settings.axesPosition);
    hold(ax, 'on');

    % lim控制视野显示范围，和灰阶方块图保持一致。
    lim = settings.axisLimitDeg;
    axis(ax, [-lim, lim, -lim, lim]);
    axis(ax, 'equal');
    set(ax, 'Color', 'w', 'YDir', 'normal');

    % ==================== 2. 读取当前输入点位和缺损分数 ====================
    % pointX/pointY:
    %   当前要绘制的检测点坐标。点数由输入决定，可能是28，也可能是54。
    % plotValue:
    %   当前眼每个检测点的缺损分数。这里不再做插值、不再做平滑。
    pointX = coordTable.vfXDeg;
    pointY = coordTable.vfYDeg;
    plotValue = plotValue(:);

    % ==================== 3. 生成密度图外轮廓 ====================
    % domainPoly是密度点阵允许出现的外边界。
    % 它由最终参与绘图的点位外轮廓向外扩展得到，而不是简单画一个大方形。
    domainPoly = AI_density_domain_polygon(pointX, pointY, settings);

    % ==================== 4. 绘制背景点阵 ====================
    % 背景点阵让整个视野区域有基本纹理。
    % densityBaseSpacingDeg越小，背景小点越密。
    xBase = -lim:settings.densityBaseSpacingDeg:lim;
    yBase = -lim:settings.densityBaseSpacingDeg:lim;
    [XB, YB] = meshgrid(xBase, yBase);
    baseMask = inpolygon(XB, YB, domainPoly(:, 1), domainPoly(:, 2));
    scatter(ax, XB(baseMask), YB(baseMask), settings.densityDotSize, ...
        'k', 'filled', 'Marker', 'o', ...
        'MarkerFaceAlpha', 1, 'MarkerEdgeAlpha', 1);

    % ==================== 5. 计算异常区域的额外点密度 ====================
    % 加密点阵不是直接全部画出来，而是先计算每个候选点被保留的概率。
    % extraKeepProb越高，该位置越容易画出额外黑点。
    %
    % halfExtraW/halfExtraH:
    %   单个检测点对周围区域的影响半宽和半高。
    %   如果你觉得异常区域太小，可以调大densityExtraRectWidthDeg/HeightDeg。
    halfExtraW = settings.densityExtraRectWidthDeg / 2;
    halfExtraH = settings.densityExtraRectHeightDeg / 2;
    xExtra = -lim:settings.densityExtraSpacingDeg:lim;
    yExtra = -lim:settings.densityExtraSpacingDeg:lim;
    [XE, YE] = meshgrid(xExtra, yExtra);
    extraMask = inpolygon(XE, YE, domainPoly(:, 1), domainPoly(:, 2));
    extraKeepProb = zeros(size(XE));

    for i = 1:numel(pointX)
        % pointDensityScore是该检测点的缺损分数。
        % 低于whiteClip基本不加密，高于highClip接近最大加密。
        pointDensityScore = double(plotValue(i));
        densityValue = (pointDensityScore - settings.whiteClip) ./ ...
            (settings.highClip - settings.whiteClip);
        densityValue = double(max(0, min(1, densityValue)) .^ settings.densityGamma);
        densityValue = densityValue(1);

        if densityValue <= 0
            continue;
        end

        % softRect是当前检测点周围的软矩形影响范围。
        % 中心影响大，边缘逐渐减弱，避免出现生硬边界。
        softRect = AI_soft_rect_kernel(XE, YE, pointX(i), pointY(i), ...
            halfExtraW, halfExtraH, settings.densityExtraShapePower);
        localProb = densityValue .* softRect;
        % 多个检测点的影响叠加时，用概率合并方式避免超过1。
        extraKeepProb = 1 - (1 - extraKeepProb) .* (1 - localProb);
    end

    % ==================== 6. 根据保留概率绘制额外小黑点 ====================
    % AI_hash_grid_value生成稳定的伪随机数。
    % 好处是同样的数据每次画出来的小点位置一致，不会每次运行都变化。
    hashValue = AI_hash_grid_value(XE, YE);
    dotMask = extraMask & hashValue <= extraKeepProb;
    scatter(ax, XE(dotMask), YE(dotMask), settings.densityDotSize, ...
        'k', 'filled', 'Marker', 'o', ...
        'MarkerFaceAlpha', 1, 'MarkerEdgeAlpha', 1);

    % ==================== 7. 绘制中线并统一坐标轴格式 ====================
    plot(ax, [-lim, lim], [0, 0], 'k-', 'LineWidth', settings.axisLineWidth);
    plot(ax, [0, 0], [-lim, lim], 'k-', 'LineWidth', settings.axisLineWidth);

    AI_style_field_axes(ax, titleText, settings, false);
    hold(ax, 'off');
end

function softRect = AI_soft_rect_kernel(X, Y, centerX, centerY, halfWidth, halfHeight, shapePower)
    % 近矩形软核：中心接近矩形，边缘圆滑过渡，相邻区域自然融合
    normX = abs(X - centerX) ./ halfWidth;
    normY = abs(Y - centerY) ./ halfHeight;
    superRectRadius = normX .^ shapePower + normY .^ shapePower;
    softRect = exp(-superRectRadius);
end

function [pointX, pointY] = AI_get_sap24_2_pseudo_coordinates(eyeSide)
    % 生成SAP 24-2样的54个伪检测位点。
    % 主体采用6 deg间距、相对水平/垂直中线偏移3 deg的24-2分布。
    % SAP 24-2包含鼻侧延伸点：左眼鼻侧在右侧视野，右眼鼻侧在左侧视野。
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

    pointX = zeros(54, 1);
    pointY = zeros(54, 1);
    row_i = 0;
    for y_i = 1:numel(rowY)
        currentX = sort(rowX{y_i});
        n = numel(currentX);
        pointX(row_i + 1:row_i + n) = currentX(:);
        pointY(row_i + 1:row_i + n) = rowY(y_i);
        row_i = row_i + n;
    end
end

function domainPoly = AI_density_domain_polygon(pointX, pointY, settings)
    % 根据最终参与密度绘图的检测点外轮廓生成检测范围，避免使用规则大方形
    hullIdx = convhull(pointX, pointY);
    hullX = pointX(hullIdx);
    hullY = pointY(hullIdx);
    centerX = mean(pointX);
    centerY = mean(pointY);
    dx = hullX - centerX;
    dy = hullY - centerY;
    radius = hypot(dx, dy);
    scale = (radius + settings.densityDomainPaddingDeg) ./ max(radius, eps);
    domainPoly = [centerX + dx .* scale, centerY + dy .* scale];
end

function fig = AI_draw_value_map(coordTable, plotValue, titleText, settings)
    % 绘制“数值图”。
    %
    % 这张图只在每个检测点位置写出对应的缺损概率样指标，
    % 不画方块、不画密度点，主要用于核对每个点的具体数值。
    %
    % 输入：
    %   coordTable:
    %       当前眼的点位坐标表。
    %   plotValue:
    %       当前眼每个点的缺损概率样指标。
    %   titleText:
    %       图标题。
    %   settings:
    %       绘图参数。
    %
    % 常改参数说明：
    %   settings.valueFontSize:
    %       每个点显示数值的字号。54点时点更密，如果数值重叠，可以调小。
    %   settings.fontName:
    %       字体名称。
    %   settings.axisLimitDeg:
    %       视野坐标范围。调大显示范围更宽，点会显得更集中。
    %   AI_format_score_text:
    %       控制数值显示格式，例如“.12”还是“0.12”。

    % ==================== 1. 建立图窗和坐标轴 ====================
    fig = figure('Color', 'w', 'Position', settings.figurePosition);
    ax = axes(fig, 'Position', settings.axesPosition);
    hold(ax, 'on');

    % lim控制视野显示范围。
    lim = settings.axisLimitDeg;
    axis(ax, [-lim, lim, -lim, lim]);
    axis(ax, 'equal');
    set(ax, 'Color', 'w', 'YDir', 'normal');

    % ==================== 2. 绘制水平和垂直中线 ====================
    plot(ax, [-lim, lim], [0, 0], 'k-', 'LineWidth', settings.axisLineWidth);
    plot(ax, [0, 0], [-lim, lim], 'k-', 'LineWidth', settings.axisLineWidth);

    % ==================== 3. 在每个检测点位置写出数值 ====================
    % 如果54点数值太密，可以优先调小settings.valueFontSize；
    % 如果仍然重叠，可以考虑不把数值图放进最终报告，只保存在文件夹中核对。
    for i = 1:height(coordTable)
        text(ax, coordTable.vfXDeg(i), coordTable.vfYDeg(i), ...
            AI_format_score_text(plotValue(i)), ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', ...
            'FontName', settings.fontName, ...
            'FontSize', settings.valueFontSize, ...
            'FontWeight', 'normal', ...
            'Color', [0, 0, 0], ...
            'Clipping', 'on');
    end

    % ==================== 4. 统一坐标轴格式 ====================
    % 这里showAxisLabel=false，所以最终图不显示坐标刻度和坐标轴标签。
    AI_style_field_axes(ax, titleText, settings, false);
    hold(ax, 'off');
end

function AI_style_field_axes(ax, titleText, settings, showAxisLabel)
    % 统一设置视野图坐标轴格式。
    %
    % 这里集中控制：
    %   1) 坐标轴字体；
    %   2) 是否显示x/y刻度；
    %   3) 是否显示x/y坐标轴标签；
    %   4) 图标题字号和加粗。
    %
    % 如果你后续要改标题大小：
    %   修改下面title中的'FontSize', 12.5。
    % 如果你要改坐标轴刻度字号：
    %   修改 ax.FontSize。
    % 如果你要让密度图/数值图也显示坐标轴标签：
    %   调用AI_style_field_axes时把showAxisLabel设为true。
    if nargin < 4
        showAxisLabel = true;
    end
    box(ax, 'off');
    ax.FontName = settings.fontName;
    ax.FontSize = 9.5;
    if showAxisLabel
        ax.XTick = -25:5:25;
        ax.YTick = -25:5:25;
        xlabel(ax, settings.xLabel, 'FontSize', 10.5, 'FontName', settings.fontName);
        ylabel(ax, settings.yLabel, 'FontSize', 10.5, 'FontName', settings.fontName);
    else
        ax.XTick = [];
        ax.YTick = [];
        xlabel(ax, '');
        ylabel(ax, '');
    end
    title(ax, titleText, 'FontSize', 12.5, 'FontWeight', 'bold', ...
        'FontName', settings.fontName);
end

function hashValue = AI_hash_grid_value(X, Y)
    hashValue = sin(X .* 12.9898 + Y .* 78.233) .* 43758.5453;
    hashValue = hashValue - floor(hashValue);
end

function textValue = AI_format_score_text(value)
    textValue = sprintf('%.2f', value);
    if startsWith(textValue, '0')
        textValue = textValue(2:end);
    elseif startsWith(textValue, '-0')
        textValue = ['-', textValue(3:end)];
    end
end

function textColor = AI_text_color_for_gray(value)
    if value < 45
        textColor = [1, 1, 1];
    else
        textColor = [0, 0, 0];
    end
end
