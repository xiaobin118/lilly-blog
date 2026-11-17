---
title: 机器学习实验合集
description: 六个课程实验的代码、报告与复现结果，从线性模型到生成模型
date: 2026-11-17
status: done
tech: [Python, NumPy, PyTorch, C++]
repo: https://github.com/xiaobin118/HIT_ML_Lab
---

这个项目把课程里的六个机器学习实验整理成一个可复现的仓库。约束是尽量不使用现成实现：线性模型、聚类与 EM、多层感知机都直接用 NumPy 手写，只有卷积网络和生成模型用 PyTorch 做 GPU 训练。

覆盖的内容从多项式回归、逻辑回归，到 k-means 与混合高斯、多层感知机、卷积神经网络，最后是 DCGAN、VAE 与扩散模型。每个实验目录都包含可运行代码、Markdown 实验报告、results.json 和报告插图，报告正文的数字由结果文件生成，避免手工抄写。

结果上，MNIST 上手写 MLP 达到 98.16%，PyTorch 的 SmallVGG 达到 99.52% ± 0.07%，扩散模型在动漫头像上的 FID 为 20.0。各实验的设置、消融与失效案例记录在对应报告里。

数据集、模型权重和 Office 导出没有入库，按各目录 README 的说明下载即可复现。实验三的 gmm.py 仍保留为练习骨架，报告中的结果来自复现脚本里的参考实现，README 与报告都做了标注。
