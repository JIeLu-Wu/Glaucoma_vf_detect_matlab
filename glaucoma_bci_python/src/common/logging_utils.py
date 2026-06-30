"""日志工具。

后续用于把临床报告、模拟实验和 foldNum 分析的运行过程写入 logs/。
"""

import logging
from pathlib import Path


def setup_logger(name: str, log_file: str | Path) -> logging.Logger:
    """创建同时输出到屏幕和文件的 logger。"""
    logger = logging.getLogger(name)
    logger.setLevel(logging.INFO)
    logger.handlers.clear()

    formatter = logging.Formatter("%(asctime)s [%(levelname)s] %(message)s")

    stream_handler = logging.StreamHandler()
    stream_handler.setFormatter(formatter)
    logger.addHandler(stream_handler)

    log_file = Path(log_file)
    log_file.parent.mkdir(parents=True, exist_ok=True)
    file_handler = logging.FileHandler(log_file, encoding="utf-8")
    file_handler.setFormatter(formatter)
    logger.addHandler(file_handler)

    return logger
