---
title: "手写反向传播：从链式法则到矩阵形式"
description: "把逐元素的链式法则整理成矩阵运算，并用力梯度校验确认实现正确"
date: 2026-11-01
tags: [machine-learning, numpy, backpropagation]
type: note
topic: "机器学习"
project: mlp
---

反向传播的难点不在链式法则本身，而在把逐元素的推导整理成矩阵运算。以一个两层 MLP 为例，前向是 \(Z^{(\ell)}=A^{(\ell-1)}W^{(\ell)}+b^{(\ell)}\)，\(A^{(\ell)}=\sigma(Z^{(\ell)})\)，输出层接 softmax 与交叉熵。

对 softmax + 交叉熵，输出层的误差有一个很干净的形式：

$$
dZ^{(L)}=\frac{1}{N}(P-Y)
$$

其中 \(P\) 是 softmax 概率，\(Y\) 是 one-hot 标签。把它逐层回传：

$$
dA^{(\ell)}=dZ^{(\ell)}W^{(\ell)\top},\qquad dZ^{(\ell)}=dA^{(\ell)}\odot\sigma'(Z^{(\ell)})
$$

$$
dW^{(\ell)}=A^{(\ell-1)\top}dZ^{(\ell)},\qquad db^{(\ell)}=\sum_{n=1}^{N}dZ^{(\ell)}_n
$$

实现时每层要缓存 \((A^{(\ell-1)},Z^{(\ell)},A^{(\ell)})\)，否则反向时拿不到激活值。矩阵乘法把样本维一起处理，循环只留在层数上，这也是 NumPy 版本能跑满 MNIST 的原因。

写完一定要做数值梯度校验：对每个参数加减小扰动，用中心差分算数值梯度，再和解析梯度比。实验里全部参数的相对误差在 \(10^{-10}\) 量级，才敢相信后面的训练结果。MNIST 全量上，这套手写 MLP 的测试准确率是 98.16%，线性分类器是 92.66%——差距来自隐藏层带来的非线性，而不是优化器。
