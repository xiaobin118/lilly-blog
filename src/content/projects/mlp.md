---
title: 多层感知机
description: 纯 NumPy 手写反向传播与优化器，并在 MNIST 上与线性分类器对比
date: 2026-10-31
status: done
tech: [Python, NumPy, PyTorch]
repo: https://github.com/xiaobin118/HIT_ML_Lab/tree/main/experiment4
---

目标是在只用 NumPy 的前提下实现多层感知机，手写前向传播、反向传播、softmax 交叉熵与 SGD、Momentum、Adam，不使用任何自动微分工具。作为对照，另外独立实现了一个 softmax 线性分类器，两者共用同一套小批量训练循环。

实验分四组：二维四类数据的决策边界对照（四团高斯、同心圆环、四臂螺旋）、数据量学习曲线、隐藏层宽度与深度、激活函数、学习率、初始化、批大小、L2 和优化器的扫描，以及 MNIST 全量训练与误差分析。报告还在 6 个公开数据集上重复了线性分类器与 MLP 的对照。

在四团线性可分数据上，线性分类器 98.1%、MLP 97.5%；在四圆环与四臂螺旋上，MLP 分别达到 99.1% 与 99.7%，线性分类器只有 24.7% 与 26.7%。MNIST 全量训练集上，线性分类器测试准确率 92.66%，MLP 为 98.16%。额外数据集上结论并不一边倒，MLP 在 Letter 上优势明显，但在 WDBC 上反而略低。

目录里的 lab2_mlp 是课程 Lab2 的 PyTorch 版本，在 Ionosphere 二分类上做分层五折交叉验证，最优配置的开放准确率为 94.02% ± 3.30%，OOF F1 为 0.955。
