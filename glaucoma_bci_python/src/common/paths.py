"""路径和结果文件夹管理。

后续对应 MATLAB 中 AI_generate_sap_like_clinical_report.m 的：
- 常用修改区路径
- existingResultDir 逻辑
- 患者姓名 + 版本号结果文件夹命名
"""

from pathlib import Path


def ensure_dir(path: str | Path) -> Path:
    """确认文件夹存在，并返回 Path 对象。"""
    path = Path(path)
    path.mkdir(parents=True, exist_ok=True)
    return path
