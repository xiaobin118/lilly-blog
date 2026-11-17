---
title: 机器学习实验三：k-means 与 GMM
description: 纯 NumPy 手写 k-means 与 EM，不依赖 scipy / sklearn
date: 2026-10-13
status: done
tech: [Python, NumPy, Matplotlib]
---

这个实验的目标是把两类无监督方法从公式推到能跑起来的代码：k-means 和混合高斯模型（GMM）。约束是只用 Python + NumPy，不调用 scikit-learn 或 scipy 的聚类/优化实现，所有距离计算、初始化、EM 迭代都要自己写。

实现范围包括：k-means 的目标函数与交替优化、k-means++ 初始化、肘部法与轮廓系数选 K、多次重启取最优；GMM 的 E 步责任度、M 步参数更新、对数域数值稳定（log-sum-exp）、协方差正则化，以及在合成数据和 Iris / WDBC 上的对比实验。

结论主要落在「内部指标会骗人」这件事上：k-means 的 J 随 K 单调下降，不能跨 K 比较；轮廓系数在数据分布不均时会偏好错误的分组；GMM 的单调性在没有正则化时会因为协方差奇异而破坏，而 BIC 在小样本上会系统性地偏向更小的模型。这些结论和对应的数值实验都整理在实验报告与配套讲义里。
