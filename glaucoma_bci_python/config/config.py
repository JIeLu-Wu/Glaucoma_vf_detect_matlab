"""项目常用配置参数。

这个文件专门放“经常需要改”的参数，例如数据路径、采样率、滤波参数、
截取时间窗等。后续如果你换了患者数据文件夹，或者想调整预处理参数，
优先改这里，不需要到每个脚本里到处找。
"""

from pathlib import Path


# ==================== 1. 项目路径 ====================

# PROJECT_ROOT: Python 项目的根目录，也就是 glaucoma_bci_python 文件夹。
PROJECT_ROOT = Path(__file__).resolve().parents[1]

# DEFAULT_DATA_DIR: 默认的临床实验数据文件夹，里面通常放 train1.cnt、test1.cnt 等文件。
DEFAULT_DATA_DIR = Path(r"D:\0课题\青光眼\data\临床实验\260617丁艳荣")

# DEFAULT_RESULT_DIR: Python 版程序的默认结果输出文件夹。
DEFAULT_RESULT_DIR = PROJECT_ROOT / "results"

# DEFAULT_LOG_DIR: Python 版程序的默认日志输出文件夹。
DEFAULT_LOG_DIR = PROJECT_ROOT / "logs"


# ==================== 2. EEG 读取和预处理参数 ====================

# ORIGINAL_SAMPLE_RATE: CNT 原始采样率。你当前的数据通常是 1000 Hz。
ORIGINAL_SAMPLE_RATE = 1000

# TARGET_SAMPLE_RATE: 降采样后的采样率。为了和 MATLAB 当前分析保持一致，默认 250 Hz。
TARGET_SAMPLE_RATE = 250

# LOWPASS_HZ: 降采样前的低通滤波截止频率，对应 MATLAB 里的 lowpass(data, 1000)。
# 这里明确写成 90 Hz，避免高频噪声在降采样时混叠到低频。
LOWPASS_HZ = 90

# BANDPASS_PARAM: Chebyshev 带通滤波参数，对应 MATLAB 的 Wn_para = [0.5, 2, 20, 30]。
# 含义是：[低频阻带边界, 低频通带边界, 高频通带边界, 高频阻带边界]，单位 Hz。
BANDPASS_PARAM = [0.5, 2, 20, 30]

# EPOCH_TIME_WINDOW: 每个刺激事件后截取的时间窗，单位秒。
# MATLAB 临床报告脚本中主要使用 [0, 0.45]。
EPOCH_TIME_WINDOW = [0.0, 0.45]

# DATA_UNIT: MNE 读出的 EEG 默认单位是伏特 V。
# MATLAB/EEGLAB 通常按微伏 uV 使用，因此这里默认转成微伏，便于和 MATLAB 数值接近。
DATA_UNIT = "uV"


# ==================== 3. 事件和试次数参数 ====================

# TRAIN_TRIAL_TOTAL: 读取训练 CNT 时最多使用多少个事件。
TRAIN_TRIAL_TOTAL = 400

# TEST_TRIAL_TOTAL: 读取测试 CNT 时最多使用多少个事件。
TEST_TRIAL_TOTAL = 240


# ==================== 4. DCPM 常用通道参数 ====================

# MATLAB_CHAN_LIST: MATLAB 中使用的通道编号，MATLAB 编号从 1 开始。
MATLAB_CHAN_LIST = list(range(44, 65))

# PYTHON_CHAN_INDEX: Python 中使用的通道下标，Python 下标从 0 开始。
# 例如 MATLAB 的第 44 个通道，对应 Python 的第 43 个通道。
PYTHON_CHAN_INDEX = [channel_number - 1 for channel_number in MATLAB_CHAN_LIST]

