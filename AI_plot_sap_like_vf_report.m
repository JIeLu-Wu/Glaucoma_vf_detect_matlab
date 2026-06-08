function result = AI_plot_sap_like_vf_report(sensitivity, varargin)
% 绘制类似SAP的视野缺损情况散点图
%AI_PLOT_SAP_LIKE_VF_REPORT Plot SAP-like square grayscale visual-field reports.
%
% sensitivity:
%   28-by-2 numeric matrix, column 1 = left eye, column 2 = right eye.
%   The function keeps this input compatible with the previous report
%   pipeline, then internally converts it back to three-class scores and
%   plots a defect-like grayscale score:
%       left eye  = (1 - Pn) * PL
%       right eye = (1 - Pn) * PR
%
% Optional compatibility:
%   If sensitivity is a 28-by-1 numeric state vector, it is converted by:
%       1 = normal              -> both eyes 100
%       2 = left abnormal       -> left 0, right 100
%       3 = right abnormal      -> left 100, right 0
%       4 or 0 = bilateral/null -> both eyes 0
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

    [sensitivity, plotValue] = AI_prepare_plot_values(sensitivity, settings);
    pixelXY = AI_get_pixel_coordinates();
    coordTable = AI_pixel_to_visual_angle(pixelXY, settings);

    if ~exist(settings.outputDir, 'dir')
        mkdir(settings.outputDir);
    end

    leftFig = AI_draw_report_map(coordTable, plotValue(:, 1), ...
        settings.leftTitle, settings);
    rightFig = AI_draw_report_map(coordTable, plotValue(:, 2), ...
        settings.rightTitle, settings);
    leftDensityFig = AI_draw_density_map(coordTable, plotValue(:, 1), ...
        settings.leftDensityTitle, settings);
    rightDensityFig = AI_draw_density_map(coordTable, plotValue(:, 2), ...
        settings.rightDensityTitle, settings);
    leftValueFig = AI_draw_value_map(coordTable, plotValue(:, 1), ...
        settings.leftValueTitle, settings);
    rightValueFig = AI_draw_value_map(coordTable, plotValue(:, 2), ...
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

        outTable = coordTable;
        outTable.leftSensitivity = sensitivity(:, 1);
        outTable.rightSensitivity = sensitivity(:, 2);
        outTable.leftDefectScore = plotValue(:, 1);
        outTable.rightDefectScore = plotValue(:, 2);
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
    result.coordTable = coordTable;
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
    settings = struct();
    settings.outputDir = fullfile(fileparts(mfilename('fullpath')), ...
        'AI_SAP_like_visual_field_report');
    settings.filePrefix = 'AI_SAP_like_VF';
    settings.saveFigure = true;
    settings.showFigure = false;
    settings.resolution = 300;

    settings.leftTitle = 'Left eye grayscale field';
    settings.rightTitle = 'Right eye grayscale field';
    settings.leftDensityTitle = 'Left eye density plot';
    settings.rightDensityTitle = 'Right eye density plot';
    settings.leftValueTitle = 'Left eye numeric plot';
    settings.rightValueTitle = 'Right eye numeric plot';
    settings.xLabel = 'Visual field X (deg)';
    settings.yLabel = 'Visual field Y (deg)';
    settings.fontName = 'Microsoft YaHei';

    % Component-wise calibration. It matches the user's current design
    % anchors and avoids placing eccentricity labels on every point.
    settings.angleMode = 'component_anchor';
    settings.anchorPixel = [0, 76, 173, 286, 397];
    settings.anchorDeg = [0, 4, 9, 19, 24];

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
    settings.densityDotSpacingDeg = 0.42;
    settings.densityDotSize = 7;
    settings.densityBaseSpacingDeg = 1.05;
    settings.densityExtraSpacingDeg = 0.34;
    settings.densityGamma = 0.85;
    settings.densityDomainPaddingDeg = 2.6;
    settings.densityExtraRectWidthDeg = 7.2;
    settings.densityExtraRectHeightDeg = 7.2;
    settings.densityExtraShapePower = 6;
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

function [sensitivity, plotValue] = AI_prepare_plot_values(inputValue, settings)
    if ~isnumeric(inputValue)
        error('sensitivity must be numeric.');
    end

    inputValue = double(inputValue);
    if isequal(size(inputValue), [28, 2])
        sensitivity = inputValue;
        pointProb = AI_recover_point_prob_from_eye_sensitivity(sensitivity);
        plotValue = AI_defect_score_from_point_prob(pointProb);
    elseif isequal(size(inputValue), [28, 3])
        pointProb = inputValue;
        pointProb = max(pointProb, 0);
        pointProb = pointProb ./ sum(pointProb, 2);
        sensitivity = [100 * (pointProb(:, 1) + pointProb(:, 3)), ...
            100 * (pointProb(:, 1) + pointProb(:, 2))];
        plotValue = AI_defect_score_from_point_prob(pointProb);
    elseif isequal(size(inputValue), [2, 28])
        sensitivity = inputValue';
        pointProb = AI_recover_point_prob_from_eye_sensitivity(sensitivity);
        plotValue = AI_defect_score_from_point_prob(pointProb);
    elseif isequal(size(inputValue), [3, 28])
        pointProb = inputValue';
        pointProb = max(pointProb, 0);
        pointProb = pointProb ./ sum(pointProb, 2);
        sensitivity = [100 * (pointProb(:, 1) + pointProb(:, 3)), ...
            100 * (pointProb(:, 1) + pointProb(:, 2))];
        plotValue = AI_defect_score_from_point_prob(pointProb);
    elseif numel(inputValue) == 28
        state = inputValue(:);
        sensitivity = 100 * ones(28, 2);
        for i = 1:28
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
        error('Input must be 28-by-2, 28-by-3, or 28 labels.');
    end

    sensitivity = max(0, min(100, sensitivity));
    plotValue = max(0, plotValue);
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
    fig = figure('Color', 'w', 'Position', settings.figurePosition);
    ax = axes(fig, 'Position', settings.axesPosition);
    hold(ax, 'on');

    lim = settings.axisLimitDeg;
    axis(ax, [-lim, lim, -lim, lim]);
    axis(ax, 'equal');
    set(ax, 'Color', 'w', 'YDir', 'normal');
    colormap(ax, flipud(gray(256)));

    plot(ax, [-lim, lim], [0, 0], 'k-', 'LineWidth', settings.axisLineWidth);
    plot(ax, [0, 0], [-lim, lim], 'k-', 'LineWidth', settings.axisLineWidth);

    halfSize = settings.squareSizeDeg / 2;
    for i = 1:height(coordTable)
        value = max(settings.lowClip, min(settings.highClip, sensitivity(i)));
        grayValue = 1 - (value - settings.whiteClip) ./ ...
            (settings.highClip - settings.whiteClip);
        grayValue = max(0, min(1, grayValue));
        faceColor = [grayValue, grayValue, grayValue];
        edgeColor = [0, 0, 0];
        lineWidth = 1;

        x = coordTable.vfXDeg(i);
        y = coordTable.vfYDeg(i);
        rectangle(ax, 'Position', ...
            [x - halfSize, y - halfSize, settings.squareSizeDeg, ...
            settings.squareSizeDeg], ...
            'FaceColor', faceColor, ...
            'EdgeColor', edgeColor, ...
            'LineWidth', lineWidth);
    end

    if settings.drawBlindSpot
        theta = linspace(0, 2 * pi, 180);
        bx = settings.blindSpotXY(1) + settings.blindSpotRadius * cos(theta);
        by = settings.blindSpotXY(2) + settings.blindSpotRadius * sin(theta);
        plot(ax, bx, by, 'k--', 'LineWidth', 1.0);
    end

    if settings.drawFixation
        plot(ax, 0, 0, 'r+', 'MarkerSize', 14, 'LineWidth', 2.0);
    end

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

    box(ax, 'off');
    ax.FontName = settings.fontName;
    ax.FontSize = 9.5;
    ax.XTick = -25:5:25;
    ax.YTick = -25:5:25;
    xlabel(ax, settings.xLabel, 'FontSize', 10.5, 'FontName', settings.fontName);
    ylabel(ax, settings.yLabel, 'FontSize', 10.5, 'FontName', settings.fontName);
    title(ax, titleText, 'FontSize', 12.5, 'FontWeight', 'bold', ...
        'FontName', settings.fontName);

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
    fig = figure('Color', 'w', 'Position', settings.figurePosition);
    ax = axes(fig, 'Position', settings.axesPosition);
    hold(ax, 'on');

    lim = settings.axisLimitDeg;
    axis(ax, [-lim, lim, -lim, lim]);
    axis(ax, 'equal');
    set(ax, 'Color', 'w', 'YDir', 'normal');

    pointX = coordTable.vfXDeg;
    pointY = coordTable.vfYDeg;
    domainPoly = AI_density_domain_polygon(pointX, pointY, settings);

    % 背景点阵：检测范围整体均匀铺满，每个小点归属于最近检测点
    xBase = -lim:settings.densityBaseSpacingDeg:lim;
    yBase = -lim:settings.densityBaseSpacingDeg:lim;
    [XB, YB] = meshgrid(xBase, yBase);
    baseMask = inpolygon(XB, YB, domainPoly(:, 1), domainPoly(:, 2));
    scatter(ax, XB(baseMask), YB(baseMask), settings.densityDotSize, ...
        'k', 'filled', 'Marker', 'o', ...
        'MarkerFaceAlpha', 1, 'MarkerEdgeAlpha', 1);

    % 加密点阵：所有检测点共同生成连续的近矩形软区域，避免硬边界
    halfExtraW = settings.densityExtraRectWidthDeg / 2;
    halfExtraH = settings.densityExtraRectHeightDeg / 2;
    xExtra = -lim:settings.densityExtraSpacingDeg:lim;
    yExtra = -lim:settings.densityExtraSpacingDeg:lim;
    [XE, YE] = meshgrid(xExtra, yExtra);
    extraMask = inpolygon(XE, YE, domainPoly(:, 1), domainPoly(:, 2));
    extraKeepProb = zeros(size(XE));

    for i = 1:height(coordTable)
        densityValue = (plotValue(i) - settings.whiteClip) ./ ...
            (settings.highClip - settings.whiteClip);
        densityValue = max(0, min(1, densityValue));
        densityValue = densityValue .^ settings.densityGamma;

        if densityValue <= 0
            continue;
        end

        softRect = AI_soft_rect_kernel(XE, YE, pointX(i), pointY(i), ...
            halfExtraW, halfExtraH, settings.densityExtraShapePower);
        localProb = densityValue .* softRect;
        extraKeepProb = 1 - (1 - extraKeepProb) .* (1 - localProb);
    end

    hashValue = AI_hash_grid_value(XE, YE);
    dotMask = extraMask & hashValue <= extraKeepProb;
    scatter(ax, XE(dotMask), YE(dotMask), settings.densityDotSize, ...
        'k', 'filled', 'Marker', 'o', ...
        'MarkerFaceAlpha', 1, 'MarkerEdgeAlpha', 1);

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

function domainPoly = AI_density_domain_polygon(pointX, pointY, settings)
    % 根据28个检测点的外轮廓生成检测范围，避免使用规则大方形
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
    fig = figure('Color', 'w', 'Position', settings.figurePosition);
    ax = axes(fig, 'Position', settings.axesPosition);
    hold(ax, 'on');

    lim = settings.axisLimitDeg;
    axis(ax, [-lim, lim, -lim, lim]);
    axis(ax, 'equal');
    set(ax, 'Color', 'w', 'YDir', 'normal');

    plot(ax, [-lim, lim], [0, 0], 'k-', 'LineWidth', settings.axisLineWidth);
    plot(ax, [0, 0], [-lim, lim], 'k-', 'LineWidth', settings.axisLineWidth);

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

    AI_style_field_axes(ax, titleText, settings, false);
    hold(ax, 'off');
end

function AI_style_field_axes(ax, titleText, settings, showAxisLabel)
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

function regionIndex = AI_nearest_region_index(X, Y, pointX, pointY)
    distMin = inf(size(X));
    regionIndex = ones(size(X));
    for i = 1:numel(pointX)
        d = (X - pointX(i)).^2 + (Y - pointY(i)).^2;
        updateIdx = d < distMin;
        regionIndex(updateIdx) = i;
        distMin(updateIdx) = d(updateIdx);
    end
end

function valueMap = AI_smooth_value_map(X, Y, pointX, pointY, pointValue, sigmaDeg)
    valueNumerator = zeros(size(X));
    weightSum = zeros(size(X));
    for i = 1:numel(pointX)
        dist2 = (X - pointX(i)).^2 + (Y - pointY(i)).^2;
        weight = exp(-dist2 ./ (2 * sigmaDeg ^ 2));
        valueNumerator = valueNumerator + weight .* pointValue(i);
        weightSum = weightSum + weight;
    end
    valueMap = valueNumerator ./ max(weightSum, eps);
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
