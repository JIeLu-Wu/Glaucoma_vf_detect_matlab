r"""检查单个 CNT 文件的读取和预处理结果。

这个脚本用于第一步验证：
1. CNT 文件能不能被 Python 正常读取；
2. 事件数量是否和预期一致；
3. 分段后的 EEG 数据维度是否正确。

运行示例：

```powershell
C:\Users\10656\anaconda3\envs\eeg2erp\python.exe `
    D:\0课题\青光眼\data_processing-20\glaucoma_bci_python\scripts\check_cnt_preprocessing.py `
    --cnt-file D:\0课题\青光眼\data\临床实验\260617丁艳荣\train1.cnt `
    --max-event-count 400
```
"""

from pathlib import Path
import argparse
import sys


# ==================== 1. 项目路径加入 Python 搜索路径 ====================

# 这样脚本无论从哪里运行，都能正确导入 src 和 config 里的代码。
PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))


from config.config import DEFAULT_DATA_DIR, TRAIN_TRIAL_TOTAL
from src.eeg.preprocess_pipeline import load_cnt_epochs


def main() -> None:
    """主流程：读取命令行参数，然后打印 CNT 预处理结果。"""

    # ==================== 2. 读取用户输入参数 ====================

    parser = argparse.ArgumentParser(description="检查 CNT 文件读取、事件提取和 EEG 分段是否正常。")
    parser.add_argument(
        "--cnt-file",
        type=str,
        default=str(DEFAULT_DATA_DIR / "train1.cnt"),
        help="需要检查的 CNT 文件路径。默认使用 config.py 里的 DEFAULT_DATA_DIR/train1.cnt。",
    )
    parser.add_argument(
        "--max-event-count",
        type=int,
        default=TRAIN_TRIAL_TOTAL,
        help="最多读取多少个刺激事件。训练文件通常是 400，测试文件通常是 240。",
    )
    args = parser.parse_args()

    cnt_file = Path(args.cnt_file)

    # ==================== 3. 运行 CNT 读取和预处理 ====================

    print("========== CNT 预处理检查 ==========")
    print(f"CNT 文件：{cnt_file}")
    print(f"最多读取事件数：{args.max_event_count}")

    result = load_cnt_epochs(
        cnt_file=cnt_file,
        max_event_count=args.max_event_count,
    )

    epoch_data = result["epoch_data"]
    event_types = result["event_types"]
    trial_count_before_epoch = result["trial_count_before_epoch"]

    # ==================== 4. 打印检查结果 ====================

    print("\n========== 事件信息 ==========")
    print(f"原始有效事件数：{result['raw_event_count']}")
    print(f"分段前每类事件数量：{trial_count_before_epoch}")
    print(f"分段后保留的事件类型：{event_types.tolist()}")

    print("\n========== EEG 数据维度 ==========")
    print("epoch_data 维度含义：通道数 × 时间点数 × 试次数 × 刺激类型数")
    print(f"epoch_data.shape = {epoch_data.shape}")
    print(f"采样率：{result['sample_rate']} Hz")
    print(f"时间窗：{result['epoch_time_window']} 秒")
    print(f"数据单位：{result['data_unit']}")

    print("\n========== 通道信息 ==========")
    print(f"通道数：{len(result['channel_names'])}")
    print(f"前 10 个通道名：{result['channel_names'][:10]}")


if __name__ == "__main__":
    main()
