---
title: "逻辑回归实验复盘：公式、NumPy 代码与结果分析"
description: "把逻辑回归的公式、NumPy 实现与相关高斯数据、UCI Bank 数据上的结果串起来复盘。"
date: 2026-10-11
tags: [machine-learning, logistic-regression]
type: note
topic: "机器学习"
project: logistic-regression
---

## 1. 复盘范围

实验二的目标是实现逻辑回归的参数估计，覆盖无惩罚负对数似然和带 L2 惩罚两种目标函数，并选用梯度下降或牛顿法求解。实验包含两部分数据：人工生成的相关高斯数据和 UCI Bank Marketing 实际营销数据。当前目录下的 `code/` 保存了从逐步实现到绘图的分步代码，`exp2_report/full_experiment.py` 是能够完整运行并产出 `results.json`、图 1 至图 10 的最终版本。

复盘按三层展开：数学公式如何对应 NumPy 运算，最终代码如何处理形状、数值稳定性和优化细节，以及两组实验的实际结果说明了什么。分步代码中存在的问题也会单独列出，避免直接提交带语法错误或逻辑错误的文件。

## 2. 数学推导与代码映射

### 2.1 从对数几率到 sigmoid

逻辑回归直接建模正类后验概率。设线性得分为 \(z=w^Tx+b\)，正类概率为

$$
P(y=1\mid x)=\sigma(z)=\frac{1}{1+e^{-z}}
$$


这个式子的 NumPy 实现只需要一次矩阵乘法和一次逐元素 sigmoid：

```python
def sigmoid(z):
    z = np.clip(z, -500, 500)
    return 1.0 / (1.0 + np.exp(-z))
```

`np.clip` 把 `z` 限制在有限区间内，避免 `np.exp` 在大负数上溢出。这个细节在特征未标准化或训练早期权重较大时很重要。

### 2.2 负对数似然

对 N 个独立样本，似然函数是伯努利分布的连乘。取负对数后得到

$$
J_0(w,b)=
-\frac{1}{N}\sum_{i=1}^{N}
\left[
y_i\log p_i+(1-y_i)\log(1-p_i)
\right]
$$

代码中对 `log` 的参数加一个极小值 `eps`，防止概率接近 0 或 1 时出现 `-inf` 或 `NaN`：

```python
p = sigmoid(Xb @ theta)
eps = 1e-12
ce = -np.mean(y * np.log(p + eps) + (1 - y) * np.log(1 - p + eps))
```

`np.mean` 把长度为 N 的向量压成一个标量，这与公式中的 \(1/N\) 完全对应。如果改成 `np.sum`，损失和梯度都会放大 N 倍，学习率需要重新调整。

### 2.3 梯度

数据部分损失对参数的梯度为

$$
\nabla_w J_0=\frac{1}{N}X^T(p-y),
\qquad
\frac{\partial J_0}{\partial b}=\frac{1}{N}\sum_{i=1}^{N}(p_i-y_i)
$$

代码先计算误差向量 `p - y`，再用一次矩阵乘法得到所有特征的梯度：

```python
error = p - y
grad_w = Xb.T @ error / n
```

`Xb` 在最终实验中被扩展为 `[1, X]`，所以 `grad_w` 实际包含偏置项，代码中统一使用 `theta` 表示：

```python
def _loss_grad(self, Xb, y):
    n = len(y)
    p = sigmoid(Xb @ self.theta)
    eps = 1e-12

    ce = -np.mean(y * np.log(p + eps) + (1 - y) * np.log(1 - p + eps))
    reg = 0.5 * self.lam * np.sum(self.theta[1:] ** 2)
    loss = ce + reg

    error = p - y
    grad = Xb.T @ error / n
    if self.lam > 0:
        grad[1:] += self.lam * self.theta[1:]
    return loss, grad
```

这段代码体现了最终版本的两个设计：偏置被放在 `theta[0]`，L2 惩罚只作用于 `theta[1:]`；正则化梯度直接加在 `grad[1:]` 上，不改变形状。

### 2.4 L2 惩罚

加入 L2 惩罚后，目标函数变为

$$
J_\lambda(w,b)=J_0(w,b)+\frac{\lambda}{2}\|w\|_2^2
$$

对应的权重梯度多出一项 \(\lambda w\)。在最终实验的约定中，正则项没有除以样本数 N，因此第一项实验的主要表格使用 \(\lambda=0,10^{-4},10^{-3},10^{-2},10^{-1},1\)。如果改用

$$
\frac{\lambda}{2N}\|w\|_2^2
$$

相同的有效惩罚强度需要把 \(\lambda\) 乘以 N。这个缩放关系在比较不同实现或 scikit-learn 的 `C` 参数时很容易出错。`LogisticRegression(C=...)` 中的 `C` 与正则化强度近似成反比，不能直接与本实验的 `lam` 数值对照。

### 2.5 牛顿法

牛顿法需要海森矩阵。sigmoid 的导数为 \(p(1-p)\)，因此

$$
H=\frac{1}{N}X_b^T S X_b+\lambda I,
\qquad
S=\operatorname{diag}\bigl(p_i(1-p_i)\bigr)
$$

最终实现为

```python
def fit_newton(self, X, y, n_iter=50, tol=1e-8, verbose=False):
    Xb = add_bias(X)
    n, d1 = Xb.shape
    self.theta = np.zeros(d1)
    self.history = []

    for it in range(n_iter):
        loss, grad = self._loss_grad(Xb, y)

        p = sigmoid(Xb @ self.theta)
        s = np.maximum(p * (1 - p), 1e-12)
        H = (Xb * s[:, None]).T @ Xb / n
        if self.lam > 0:
            H[1:, 1:] += self.lam * np.eye(d1 - 1)
        H += 1e-10 * np.eye(d1)

        try:
            delta = solve(H, grad)
        except np.linalg.LinAlgError:
            delta = np.linalg.pinv(H) @ grad

        self.theta -= delta
        self.history.append(float(loss))
        if np.linalg.norm(delta) < tol:
            break
    return self
```

这段实现有两个值得注意的地方。正则化强度为零且数据近似完全可分时，海森矩阵可能接近奇异，因此代码加入 `1e-10 * np.eye(d1)` 作为数值稳定项；L2 项则直接增强正定性，使牛顿法更稳定。另一个细节是 `H` 只对 `theta[1:]` 对应的块加正则，偏置块保持不变。

## 3. 最终代码的结构

`full_experiment.py` 可以划分为四层。基础层包括 `sigmoid`、`add_bias` 和 `standardize`；模型层包含 `LogisticRegression` 与 `GaussianNB`；数据与评价层包含 `split_dataset`、`classification_metrics` 和手工实现的 `roc_curve_manual`；绘图层包含 `plot_data`、`make_meshgrid` 和 `plot_boundary`。这种划分让人工数据实验和 UCI 数据实验复用同一套模型、标准化和评价代码。

`standardize` 使用训练集均值和标准差：

```python
def standardize(X_train, X_test):
    mu = X_train.mean(axis=0)
    sd = X_train.std(axis=0)
    sd[sd == 0] = 1.0
    return (X_train - mu) / sd, (X_test - mu) / sd, mu, sd
```

`X_train.mean(axis=0)` 的形状是 `(d,)`，通过广播对每一列操作。测试集使用训练集的 `mu` 和 `sd`，避免测试集信息泄漏。常量特征的标准差被替换为 1，防止除零。

数据划分使用 `rng.permutation`：

```python
def split_dataset(X, y, test_ratio=0.3, seed=42):
    rng = np.random.default_rng(seed)
    idx = rng.permutation(len(y))
    n_test = int(len(y) * test_ratio)
    test_idx = idx[:n_test]
    train_idx = idx[n_test:]
    return X[train_idx], X[test_idx], y[train_idx], y[test_idx]
```

人工数据在生成时先按类堆叠，如果不打乱就切分，训练集和测试集的类别分布会完全失衡。打乱后按索引取数可以保证样本和标签同步重排。

决策边界的绘制使用网格法。`make_meshgrid` 先在特征范围内生成网格，再把网格展平成模型输入：

```python
xx, yy = np.meshgrid(
    np.linspace(x_min, x_max, resolution),
    np.linspace(y_min, y_max, resolution)
)
grid = np.c_[xx.ravel(), yy.ravel()]
```

预测后得到 `(R*R,)` 的概率向量，再恢复为 `(R,R)` 才能与 `xx`、`yy` 一起传给 `contour` 和 `contourf`。这条形状链是 `(R,R) -> (R*R,) -> (R*R,2) -> (R*R,) -> (R,R)`，任何一步顺序不一致都会导致边界错位。

## 4. 分步代码的问题

`code/` 下的分步文件保留了学习过程，但有多处不能直接运行。`step3.py` 和 `step4.py` 的 `train_logreg_gd` 把 `return` 放在 `for` 循环内部，函数会在第一次迭代后就返回；同时 `history.append(loss)` 和 `history.append(float(loss))` 各写了一次，即使修正缩进也会让每个迭代记录两份损失。

`step4.py` 还存在明显的语法与拼写错误：协方差矩阵写成了不合法的一维 `np.array([-1.0, rho], [0.0, 1.0])`，拼接函数写成了 `np.vsatck`，标签拼接写成了 `np.r__`，`split_dataset` 的定义缺少冒号，函数体中的 `N` 也没有定义。这个文件显然停留在半成品状态。

`step5.py` 的 `plot_data` 函数体全部缩进在 `if ax is None:` 分支内，只有不传入 `ax` 时才会画图；调用者如果传入已有坐标轴，函数将只返回空的坐标轴。`predict_proba` 在 `linear_score` 之前定义，运行期调用没有问题，但阅读顺序不自然。`if __name__ == "__main__"` 也只测试了散点图，没有测试决策边界。

`code/logistic_regression.py` 只实现了 `sigmoid` 和 `cost_function`，没有梯度和训练过程，无法完成参数估计。它的 `sigmoid` 没有数值截断，`cost_function` 使用 `np.log(h)` 而没有加 `eps`，当预测概率接近 0 时会产生 `-inf`。正则项使用 `lambda_/(2*m)` 的约定；最终 `full_experiment.py` 的 `_loss_grad` 则使用 `0.5*lam*np.sum(theta[1:]**2)`，即 `lambda/2` 的约定。两处代码对同一个 `lambda` 的数值含义不同，比较结果时必须先统一尺度。

这些文件适合保留为学习记录，最终提交和复现实验应以 `exp2_report/full_experiment.py` 为准。`full_experiment.py` 修正了上述问题，并且通过一次运行生成全部结果。

## 5. 人工相关高斯数据实验

人工数据每个类生成 500 个样本，两个类的均值分别为 `[-1, 0]` 和 `[1, 0]`，共享协方差矩阵

$$
\Sigma=
\begin{bmatrix}
1.0 & 0.8\\
0.8 & 1.0
\end{bmatrix}
$$

相关系数约为 0.8，属于强相关。数据按 70%/30% 划分为 700 个训练样本和 300 个测试样本，并在训练集上标准化。

最终结果如下：

| 模型 | 训练准确率 | 测试准确率 |
|---|---:|---:|
| 逻辑回归（无惩罚，梯度下降） | 0.9614 | 0.9600 |
| 高斯朴素贝叶斯 | 0.8500 | 0.8767 |

逻辑回归学到的参数为 `theta = [0.211083, 8.279255, -5.312428]`，其中第二项和第三项分别是两个特征的权重。第二个权重为负，说明模型在利用 `x1` 与 `x2` 之间的正相关关系来调整决策边界。梯度下降运行了 12152 次迭代，最终损失约为 0.1047，梯度范数降到 `9.99e-7`。

高斯朴素贝叶斯只估计每个类内每个特征单独的均值和方差，等价于把协方差矩阵强制看成对角矩阵。它忽略了 0.8 的协方差，因此学到的决策边界更接近竖直方向，测试准确率比逻辑回归低约 8.3 个百分点。这个对比直接验证了实验要求中“类条件分布不满足朴素贝叶斯假设”的场景：逻辑回归作为判别式模型不需要特征条件独立假设，可以保留相关性带来的信息。

## 6. L2 正则化实验

第一组数据上对六个正则化强度进行了训练，结果如下：

| lambda | 训练准确率 | 测试准确率 | `||w||` | w1 | w2 |
|---|---:|---:|---:|---:|---:|
| 0 | 0.9614 | 0.9600 | 9.8371 | 8.2793 | -5.3124 |
| 1e-4 | 0.9586 | 0.9567 | 9.2202 | 7.7682 | -4.9666 |
| 1e-3 | 0.9586 | 0.9567 | 6.9681 | 5.9016 | -3.7049 |
| 1e-2 | 0.9614 | 0.9467 | 3.8321 | 3.2998 | -1.9485 |
| 1e-1 | 0.9471 | 0.9367 | 1.4558 | 1.3158 | -0.6228 |
| 1.0 | 0.8957 | 0.9133 | 0.2861 | 0.2780 | -0.0674 |

权重范数随着 `lambda` 增大而单调下降，说明惩罚项确实在收缩参数。测试准确率并没有随正则化强度增大而单调提高：无惩罚模型在这组低维、强信号数据上表现最好，说明此时过拟合并不是主要矛盾；`lambda` 较大时训练准确率和测试准确率都下降，模型开始欠拟合。

这并不说明 L2 没有价值。数据只有两个特征，样本量 1000，模型复杂度很低，无惩罚逻辑回归本身就不容易过拟合。L2 的价值通常体现在特征数多、噪声大、样本相对不足或特征高度共线的情况下。UCI Bank Marketing 实验正好提供了更接近这种场景的验证。

另一个细节是偏置没有被惩罚，但它的值也从 0.211 降到 0.041。这是因为在优化过程中，数据项会把偏置拉向使正类比例匹配的位置，而权重收缩后偏置的最优值也会随之变化。偏置本身不受正则项约束，但并不是不变。

## 7. UCI Bank Marketing 实验

Bank Marketing 数据集记录银行的电话营销活动，目标是预测客户是否认购定期存款。使用的是 `bank.csv`，包含 4521 条样本；原始特征 16 个，其中若干类别特征经 `pd.get_dummies(..., drop_first=True)` 独热编码后变为 42 个特征。正类比例约为 11.52%，负类占绝大多数，多数类基线准确率为 0.8916。

数据处理的核心代码为：

```python
df = pd.read_csv(data_path, sep=";")
y = (df["y"] == "yes").astype(int).values
X_df = pd.get_dummies(df.drop(columns=["y"]), drop_first=True)
X = X_df.values.astype(float)
```

随后按 70%/30% 划分训练集和测试集，并标准化。模型使用牛顿法训练，比较了五个正则化强度：

| lambda | 训练准确率 | 测试准确率 | 精确率 | 召回率 | F1 |
|---|---:|---:|---:|---:|---:|
| 0 | 0.9036 | 0.9012 | 0.5867 | 0.2993 | 0.3964 |
| 0.001 | 0.9014 | 0.9012 | 0.5867 | 0.2993 | 0.3964 |
| 0.01 | 0.9017 | 0.9056 | 0.6462 | 0.2857 | 0.3962 |
| 0.1 | 0.8891 | 0.8960 | 0.6250 | 0.1020 | 0.1754 |
| 1.0 | 0.8818 | 0.8916 | 0.0000 | 0.0000 | 0.0000 |

`lambda=0.01` 时测试准确率最高，约为 0.9056，比多数类基线高约 1.4 个百分点。模型的测试准确率在 `lambda=1.0` 时回落到 0.8916，正好等于多数类基线；此时精确率和召回率都为 0，模型把所有样本都预测为负类。这是强正则化导致权重接近零、线性得分落在阈值以下的直接后果，也说明准确率在类别不平衡数据上会掩盖模型失效。

最佳测试模型的召回率约为 0.2857，意味着在真实认购客户中只识别出约三成。精确率约 0.6462，在被模型预测为认购的客户中约六成确实认购。F1 约 0.3962，ROC AUC 约 0.8857。AUC 高于 0.5 说明模型对两类样本有排序能力，但召回率偏低，若实际目标是尽可能找出潜客，需要调整分类阈值、设置类别权重或使用代价敏感学习。营销场景通常更关心 PR 曲线，因为正类稀少，ROC 曲线在负类极多时可能显得过于乐观。

从权重看，标准化后绝对值最大的特征是 `duration`，对应权重约 0.9899；其次是 `contact_unknown`（约 -0.3934）、`poutcome_success`（约 0.3755）、`loan_yes`（约 -0.2167）和 `campaign`（约 -0.1978）。电话持续时间与认购行为强相关，但该特征也带有因果方向问题：客户愿意长时间通话可能本身就是因为已有认购意向，实际部署时需要注意这类信息是否在预测时可用。

实验直接用测试集准确率选择 `lambda`，这会造成测试集泄漏。严格流程应先在训练集内部切出验证集，或者使用 K 折交叉验证选择 `lambda` 和分类阈值，最后只在测试集上评估一次。

## 8. 数值稳定性与工程细节

最终代码在工程上有几处值得展开。`sigmoid` 使用 `np.clip(z, -500, 500)`，避免 `np.exp` 在极端输入上溢出；损失函数给 `log` 参数加 `1e-12`，避免 `log(0)`。标准化全部使用训练集统计量，测试集复用同一组 `mu` 和 `sd`，这是防止数据泄漏的最低要求。

牛顿法实现里，`H = (Xb * s[:, None]).T @ Xb / n` 对每个样本的 sigmoid 导数做了加权。`s[:, None]` 把 `(N,)` 变为 `(N,1)`，从而正确广播到 `Xb` 的每一行。`solve(H, grad)` 比显式求逆数值更稳；异常时回退到伪逆，保证算法不会直接崩溃。L2 项同时作用于目标函数、梯度和海森矩阵，三者必须一致；如果只在损失里加惩罚而忘记在梯度里加，收敛结果会偏离正确的正则化解。

收敛判断使用完整梯度范数，包括偏置对应的分量。`tol=1e-6` 对标准化后的数据通常可行，但它是绝对阈值，特征尺度变化后需要重新评估。梯度下降在人工数据上运行了一万两千多次迭代才达到该阈值，而牛顿法在 Bank 数据上通常几次迭代即可收敛；这说明在中小规模特征问题中，牛顿法的效率优势很明显，代价是每次迭代需要构造 d+1 维海森矩阵并求解线性方程组。

## 9. 改进方向

第一项改进是超参数选择。当前实验在测试集上比较 `lambda`，应改为训练集内部验证集或 K 折交叉验证，并同时搜索分类阈值。对于 Bank Marketing 这类不平衡数据，阈值 0.5 不一定最优，可以通过 PR 曲线选择使 F1 或召回率满足业务要求的阈值。

第二项改进是代码整理。`code/` 下的分步文件存在语法错误和半成品函数，保留为学习记录即可，最终提交应明确指向 `exp2_report/full_experiment.py`。可以进一步把模型、数据、指标和绘图拆成独立模块，并为 `sigmoid`、损失、梯度增加形状断言和数值梯度检查。

第三项改进是评价体系。Bank 实验应增加精确率—召回率曲线、PR AUC、不同阈值下的混淆矩阵。如果目标是在有限营销成本下最大化转化，也可以按预测概率排序后只联系前 K% 的客户，而不是固定使用 0.5 阈值。

第四项改进是特征与数据层面。`duration` 虽然权重最大，但它在真实营销预测时可能不可提前获得；可以分别做包含与不包含 `duration` 的对照实验。此外，`balance`、`pdays`、`previous` 等特征存在大量特殊值，可以考虑分箱、指示变量或非线性变换。

## 10. 结论

逻辑回归的核心实现可以压缩成前向计算、损失、梯度和参数更新四步，但要让代码在真实数据上稳定工作，必须同时处理形状对齐、数值稳定、标准化和正则化尺度。人工相关高斯实验说明，逻辑回归不需要类条件独立假设，因此在高相关特征上明显优于高斯朴素贝叶斯；这也解释了实验要求中考察非朴素贝叶斯场景的意义。

L2 惩罚的作用取决于数据条件。在低维、强信号数据上，它主要带来权重收缩和轻微欠拟合；在 Bank Marketing 这种特征较多、类别不平衡的数据上，适当惩罚可以略微提高测试准确率，但强惩罚会让模型退化为多数类预测。最终模型是否有效不能只看准确率，还要结合精确率、召回率、F1、AUC 和业务阈值综合判断。
