---
title: k-means 与混合高斯模型
description: 纯 NumPy 手写 k-means 与 EM，不依赖 scipy / sklearn
date: 2026-10-13
status: doing
tech: [Python, NumPy, Matplotlib]
repo: https://github.com/xiaobin118/HIT_ML_Lab/tree/main/experiment3
---

目标是把 k-means 与混合高斯模型从公式推到能跑起来的代码，约束是只用 Python 加 NumPy，不调用 scikit-learn 或 scipy 的聚类、优化实现。

k-means 部分包括目标函数、分配与更新两步、k-means++ 初始化、肘部法与轮廓系数选 K、多次重启取最优；GMM 部分包括 E 步责任度、M 步参数更新、log-sum-exp 数值稳定、协方差正则化与对数似然校验。实验在合成数据、Iris 与 pendigits 上对比两种方法，并记录目标函数与似然的单调性。

结果上，Iris 上 GMM 的 ARI 从 k-means 的 0.7302 提升到 0.9039，pendigits 上从 0.5463 提升到 0.5650。实验也记录了内部指标的失效案例：BIC 在 Iris 上选择了 K=2，对数似然随 K 单调上升，不能直接用于跨 K 比较。

目前代码目录里的 gmm.py 仍是带 NotImplementedError 的练习骨架，报告中的 GMM 数值由复现脚本内的一份参考实现跑出，报告第 6.2 节与仓库 README 都已如实标注。等骨架替换成自己的实现后，这个项目会转为已完成。
