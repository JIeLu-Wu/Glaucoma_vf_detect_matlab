r"""对比 MATLAB 和 Python 的 CNT 预处理结果。

这个脚本用于确认 Python 迁移后的“数据读取 + 预处理 + 分段”流程，
是否和 MATLAB 的 `EEGRead5.m` 输出基本一致。

需要提前在 MATLAB 中保存：

```matlab
file_name = 'D:\0课题\青光眼\data\临床实验\260617丁艳荣\train1.cnt';
[EEG, data_seg, type_all] = EEGRead5(file_name, 1000, 250, [0, 0.45], [0.5, 2, 20, 30], 400);
chan_name = {EEG.chanlocs.labels};
save('matlab_train1_preprocess.mat', 'data_seg', 'type_all', 'chan_name', '-v7');
```

运行示例：

```powershell
C:\Users\10656\anaconda3\envs\eeg2erp\python.exe `
    D:\0课题\青光眼\data_processing-20\glaucoma_bci_python\scripts\compare_matlab_python_preprocess.py
```

输出内容：
1. 命令行打印整体对比结果；
2. 保存 CSV 表格，记录误差和相关系数；
3. 保存若干张 ERP 平均波形对比图。
"""

from pathlib import Path
import argparse
import sys

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from scipy.io import loadmat


# ==================== 1. 项目路径加入 Python 搜索路径 ====================

PROJECT_ROOT = Path(__file__).resolve().parents[1]
WORKSPACE_ROOT = PROJECT_ROOT.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))


from config.config import DEFAULT_DATA_DIR, DEFAULT_RESULT_DIR, TRAIN_TRIAL_TOTAL
from src.common.paths import ensure_dir
from src.eeg.preprocess_pipeline import load_cnt_epochs


def calc_signal_metrics(matlab_data: np.ndarray, python_data: np.ndarray) -> dict:
    """计算两组同形状数据之间的整体差异。

    参数
    ----
    matlab_data:
        MATLAB 输出的数据。
    python_data:
        Python 输出的数据。

    返回
    ----
    metrics:
        包含相关系数、平均绝对误差、均方根误差、最大绝对误差等指标。
    """

    matlab_flat = matlab_data.reshape(-1)
    python_flat = python_data.reshape(-1)
    difference = python_flat - matlab_flat

    if np.std(matlab_flat) == 0 or np.std(python_flat) == 0:
        correlation = np.nan
    else:
        correlation = float(np.corrcoef(matlab_flat, python_flat)[0, 1])

    metrics = {
        "correlation": correlation,
        "mean_abs_error": float(np.mean(np.abs(difference))),
        "root_mean_square_error": float(np.sqrt(np.mean(difference**2))),
        "max_abs_error": float(np.max(np.abs(difference))),
        "matlab_mean": float(np.mean(matlab_flat)),
        "python_mean": float(np.mean(python_flat)),
        "matlab_std": float(np.std(matlab_flat)),
        "python_std": float(np.std(python_flat)),
    }

    return metrics


def parse_matlab_channel_names(chan_name_array: np.ndarray) -> list[str]:
    """把 MATLAB 保存的 cell 格式通道名转成 Python 字符串列表。"""

    channel_names = []
    for channel_cell in chan_name_array.reshape(-1):
        channel_name = str(np.asarray(channel_cell).reshape(-1)[0])
        channel_names.append(channel_name)

    return channel_names


def main() -> None:
    """主流程：读取 MATLAB 结果，重新跑 Python 预处理，然后逐层对比。"""

    # ==================== 2. 读取用户输入参数 ====================

    parser = argparse.ArgumentParser(description="对比 MATLAB 和 Python 的 CNT 预处理结果。")
    parser.add_argument(
        "--mat-file",
        type=str,
        default=str(WORKSPACE_ROOT / "matlab_train1_preprocess.mat"),
        help="MATLAB 导出的预处理结果 mat 文件。",
    )
    parser.add_argument(
        "--cnt-file",
        type=str,
        default=str(DEFAULT_DATA_DIR / "train1.cnt"),
        help="用于重新运行 Python 预处理的 CNT 文件。",
    )
    parser.add_argument(
        "--max-event-count",
        type=int,
        default=TRAIN_TRIAL_TOTAL,
        help="最多读取多少个刺激事件。train1.cnt 默认是 400。",
    )
    parser.add_argument(
        "--output-dir",
        type=str,
        default=str(DEFAULT_RESULT_DIR / "intermediate" / "preprocess_compare_train1"),
        help="对比结果输出文件夹。",
    )
    args = parser.parse_args()

    mat_file = Path(args.mat_file)
    cnt_file = Path(args.cnt_file)
    output_dir = ensure_dir(args.output_dir)

    # ==================== 3. 读取 MATLAB 保存的数据 ====================

    if not mat_file.exists():
        raise FileNotFoundError(f"找不到 MATLAB 对比文件：{mat_file}")

    matlab_result = loadmat(mat_file)
    matlab_data = np.asarray(matlab_result["data_seg"], dtype=float)
    matlab_type_all = np.asarray(matlab_result["type_all"]).reshape(-1).astype(int)
    matlab_channel_names = parse_matlab_channel_names(matlab_result["chan_name"])

    # ==================== 4. 使用 Python 当前流程重新处理同一个 CNT ====================

    python_result = load_cnt_epochs(
        cnt_file=cnt_file,
        max_event_count=args.max_event_count,
    )

    python_data = np.asarray(python_result["epoch_data"], dtype=float)
    python_type_all = np.asarray(python_result["event_types"]).reshape(-1).astype(int)
    python_channel_names = list(python_result["channel_names"])

    # ==================== 5. 基础结构对比：维度、事件类型、通道名称 ====================

    shape_is_same = matlab_data.shape == python_data.shape
    type_is_same = np.array_equal(matlab_type_all, python_type_all)
    channel_name_is_same = matlab_channel_names == python_channel_names

    print("========== MATLAB 与 Python 预处理对比 ==========")
    print(f"MAT 文件：{mat_file}")
    print(f"CNT 文件：{cnt_file}")
    print(f"输出文件夹：{output_dir}")

    print("\n========== 1. 基础结构 ==========")
    print(f"MATLAB data_seg.shape  = {matlab_data.shape}")
    print(f"Python epoch_data.shape = {python_data.shape}")
    print(f"维度是否一致：{shape_is_same}")
    print(f"MATLAB type_all  = {matlab_type_all.tolist()}")
    print(f"Python event_types = {python_type_all.tolist()}")
    print(f"事件类型是否一致：{type_is_same}")
    print(f"通道名是否一致：{channel_name_is_same}")

    if not shape_is_same:
        raise ValueError("MATLAB 和 Python 数据维度不一致，不能继续计算逐点误差。")

    # ==================== 6. 整体数值对比：所有点一起比较 ====================

    overall_metrics = calc_signal_metrics(matlab_data, python_data)
    overall_metric_table = pd.DataFrame([overall_metrics])
    overall_metric_table.to_csv(output_dir / "overall_metrics.csv", index=False, encoding="utf-8-sig")

    print("\n========== 2. 整体数值差异 ==========")
    print(f"整体相关系数 correlation = {overall_metrics['correlation']:.6f}")
    print(f"平均绝对误差 MAE = {overall_metrics['mean_abs_error']:.6f}")
    print(f"均方根误差 RMSE = {overall_metrics['root_mean_square_error']:.6f}")
    print(f"最大绝对误差 MaxAbs = {overall_metrics['max_abs_error']:.6f}")
    print(f"MATLAB 均值/标准差 = {overall_metrics['matlab_mean']:.6f} / {overall_metrics['matlab_std']:.6f}")
    print(f"Python 均值/标准差 = {overall_metrics['python_mean']:.6f} / {overall_metrics['python_std']:.6f}")

    # ==================== 7. 平均 ERP 对比：按通道和刺激类型分别比较 ====================

    channel_type_metric_rows = []

    for channel_index in range(matlab_data.shape[0]):
        for type_index in range(matlab_data.shape[3]):
            # 对试次维度求平均，得到该通道、该刺激类型的平均 ERP 波形。
            matlab_erp = np.mean(matlab_data[channel_index, :, :, type_index], axis=1)
            python_erp = np.mean(python_data[channel_index, :, :, type_index], axis=1)

            erp_metrics = calc_signal_metrics(matlab_erp, python_erp)
            channel_type_metric_rows.append(
                {
                    "channel_index_matlab": channel_index + 1,
                    "channel_name": matlab_channel_names[channel_index],
                    "event_type": int(matlab_type_all[type_index]),
                    **erp_metrics,
                }
            )

    channel_type_metric_table = pd.DataFrame(channel_type_metric_rows)
    channel_type_metric_table.to_csv(
        output_dir / "channel_type_erp_metrics.csv",
        index=False,
        encoding="utf-8-sig",
    )

    print("\n========== 3. 平均 ERP 波形相似度 ==========")
    print(f"通道-类型 ERP 相关系数中位数 = {channel_type_metric_table['correlation'].median():.6f}")
    print(f"通道-类型 ERP 相关系数最小值 = {channel_type_metric_table['correlation'].min():.6f}")
    print(f"通道-类型 ERP 相关系数最大值 = {channel_type_metric_table['correlation'].max():.6f}")

    # ==================== 8. 时间偏移诊断：检查是否存在整体错位 1-2 个采样点 ====================

    # 如果 Python 和 MATLAB 的事件点定义差了 1 个采样点，
    # 那么把时间轴轻微平移后，相关系数可能明显升高。
    shift_rows = []
    for sample_shift in [-2, -1, 0, 1, 2]:
        if sample_shift < 0:
            matlab_shift_data = matlab_data[:, :sample_shift, :, :]
            python_shift_data = python_data[:, -sample_shift:, :, :]
        elif sample_shift > 0:
            matlab_shift_data = matlab_data[:, sample_shift:, :, :]
            python_shift_data = python_data[:, :-sample_shift, :, :]
        else:
            matlab_shift_data = matlab_data
            python_shift_data = python_data

        shift_metrics = calc_signal_metrics(matlab_shift_data, python_shift_data)
        shift_rows.append({"sample_shift": sample_shift, **shift_metrics})

    shift_metric_table = pd.DataFrame(shift_rows)
    shift_metric_table.to_csv(output_dir / "time_shift_diagnostic.csv", index=False, encoding="utf-8-sig")

    best_shift_row = shift_metric_table.loc[shift_metric_table["correlation"].idxmax()]
    print("\n========== 4. 时间偏移诊断 ==========")
    print("sample_shift 的含义：正数表示 Python 相对 MATLAB 向前错开比较。")
    print(f"最佳 sample_shift = {int(best_shift_row['sample_shift'])}")
    print(f"最佳偏移下相关系数 = {best_shift_row['correlation']:.6f}")

    # ==================== 9. 保存 ERP 对比图：选几个枕顶区和枕区通道直观看波形 ====================

    # MATLAB 通道编号从 1 开始。这里选择你常用 DCPM 通道范围内的一些代表通道。
    selected_matlab_channels = [44, 48, 53, 56, 61, 62, 63]
    time_axis = np.arange(matlab_data.shape[1]) / python_result["sample_rate"] + python_result["epoch_time_window"][0]

    for matlab_channel_number in selected_matlab_channels:
        channel_index = matlab_channel_number - 1

        if channel_index < 0 or channel_index >= matlab_data.shape[0]:
            continue

        figure, axes = plt.subplots(2, 2, figsize=(10, 7), sharex=True)
        axes = axes.reshape(-1)

        for type_index in range(matlab_data.shape[3]):
            matlab_erp = np.mean(matlab_data[channel_index, :, :, type_index], axis=1)
            python_erp = np.mean(python_data[channel_index, :, :, type_index], axis=1)

            axes[type_index].plot(time_axis, matlab_erp, label="MATLAB", linewidth=2)
            axes[type_index].plot(time_axis, python_erp, label="Python", linewidth=1.5, linestyle="--")
            axes[type_index].axhline(0, color="black", linewidth=0.8)
            axes[type_index].set_title(f"Ch {matlab_channel_number} {matlab_channel_names[channel_index]} / Type {matlab_type_all[type_index]}")
            axes[type_index].set_xlabel("Time (s)")
            axes[type_index].set_ylabel("Amplitude (uV)")
            axes[type_index].legend()

        figure.tight_layout()
        figure.savefig(output_dir / f"erp_compare_channel_{matlab_channel_number}.png", dpi=200)
        plt.close(figure)

    # ==================== 10. 保存 Python 预处理结果，方便后续继续检查 ====================

    np.savez_compressed(
        output_dir / "python_preprocess_result.npz",
        epoch_data=python_data,
        event_types=python_type_all,
        channel_names=np.asarray(python_channel_names, dtype=object),
    )

    print("\n========== 5. 输出文件 ==========")
    print(f"整体指标：{output_dir / 'overall_metrics.csv'}")
    print(f"通道-类型 ERP 指标：{output_dir / 'channel_type_erp_metrics.csv'}")
    print(f"时间偏移诊断：{output_dir / 'time_shift_diagnostic.csv'}")
    print(f"ERP 对比图：{output_dir / 'erp_compare_channel_*.png'}")
    print(f"Python 预处理结果：{output_dir / 'python_preprocess_result.npz'}")


if __name__ == "__main__":
    main()
