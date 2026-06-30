# Glaucoma BCI Python

这个项目用于把当前 MATLAB 版青光眼客观视野检测流程逐步迁移到 Python。

当前阶段先搭建项目框架，后续再逐步迁移以下核心功能：

1. EEG 读取、滤波、重采样和分段。
2. DCPM 二分类空间滤波和决策值计算。
3. 决策值到三分类概率的转换。
4. 模拟实验的视野判别准确率分析。
5. 临床实验的 SAP-like 报告生成。

## 目录结构

```text
config/      配置文件，常改的数据路径和算法参数放这里
data/        数据说明或小型示例数据，不建议放大体积原始 CNT
results/     Python 结果输出
logs/        运行日志
src/         通用函数和核心算法
scripts/     主入口脚本
tests/       单元测试和 MATLAB/Python 对照测试
```

## 推荐使用方式

临床报告：

```bash
python scripts/run_clinical_report.py --config config/clinical_config.yaml
```

模拟实验准确率：

```bash
python scripts/run_simulation_accuracy.py --config config/default_config.yaml
```

不同试次叠加数量比较：

```bash
python scripts/run_foldnum_comparison.py --config config/default_config.yaml
```

## 迁移原则

第一阶段优先保证 Python 输出和 MATLAB 中间结果一致，尤其是：

- `RR_fold`
- `Prob_dv`
- `pointProbability`
- `predictedLabel`

这些核心结果对齐以后，再完善报告绘图和表格输出。
