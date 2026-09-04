# 阶段2A：两通道相关融合公式（WSS + IMU递推）

本节只给出当前阶段可直接实现的两通道标量形式，不使用 GPS，不采用互相关忽略的逆方差加权。

## 1) 两局部标量KF（通道1=WSS，通道2=IMU递推）

### 1.1 预测

```math
x_{i,k}^{-}=x_{i,k-1}^{+}
```

```math
P_{ii,k}^{-}=P_{ii,k-1}^{+}+Q_v,\quad i\in\{1,2\}
```

### 1.2 增益（标量）

```math
K_{i,k}=\frac{P_{ii,k}^{-}}{P_{ii,k}^{-}+R_{i,k}},\quad i\in\{1,2\}
```

### 1.3 状态更新

```math
x_{i,k}^{+}=x_{i,k}^{-}+K_{i,k}\bigl(z_{i,k}-x_{i,k}^{-}\bigr),\quad i\in\{1,2\}
```

### 1.4 方差更新

```math
P_{ii,k}^{+}=(1-K_{i,k})\,P_{ii,k}^{-},\quad i\in\{1,2\}
```

## 2) 互协方差递推（P12）

```math
P_{12,k}^{-}=P_{12,k-1}^{+}+Q_v
```

```math
P_{12,k}^{+}=(1-K_{1,k})\,P_{12,k}^{-}(1-K_{2,k})
```

```math
P_{21,k}^{+}=P_{12,k}^{+}
```

## 3) 全局误差协方差矩阵 Φ（2×2）

```math
\Phi_k=
\begin{bmatrix}
P_{11,k}^{+} & P_{12,k}^{+}\\
P_{12,k}^{+} & P_{22,k}^{+}
\end{bmatrix}
```

## 4) 最优相关融合权重（两通道）

```math
\alpha_k=
\frac{\Phi_k^{-1}\mathbf{1}}
{\mathbf{1}^\mathrm{T}\Phi_k^{-1}\mathbf{1}},
\quad
\mathbf{1}=\begin{bmatrix}1\\1\end{bmatrix}
```

显式成分形式：

```math
\alpha_{1,k}=\frac{\phi_{22}-\phi_{12}}{\phi_{11}+\phi_{22}-2\phi_{12}},\qquad
\alpha_{2,k}=\frac{\phi_{11}-\phi_{12}}{\phi_{11}+\phi_{22}-2\phi_{12}}
```

其中

```math
\phi_{11}=P_{11,k}^{+},\ \phi_{22}=P_{22,k}^{+},\ \phi_{12}=P_{12,k}^{+}
```

## 5) 融合速度与融合方差

```math
\hat v_{x,k}^{fused}
=\alpha_{1,k}\hat x_{1,k}^{+}+\alpha_{2,k}\hat x_{2,k}^{+}
```

```math
P_k^{fused}=\alpha_k^\mathrm{T}\Phi_k\alpha_k
```

## 6) 一通道失效/降维处理（本项目两通道）

设通道有效性为 \(s_{WSS},s_{IMU}\in\{0,1\}\)：

1. 全部有效 \(s_{WSS}=1,s_{IMU}=1\)：  
   使用上面的 \(\Phi_k,\alpha_k,\hat v_{x,k}^{fused},P_k^{fused}\)。

2. 仅 WSS 有效 \(s_{WSS}=1,s_{IMU}=0\)：  
   \[
   \hat v_{x,k}^{fused}=\hat x_{1,k}^{+},\quad
   P_k^{fused}=P_{11,k}^{+},\quad
   [\alpha_{1,k},\alpha_{2,k}]=[1,0]
   \]

3. 仅 IMU 有效 \(s_{WSS}=0,s_{IMU}=1\)：  
   \[
   \hat v_{x,k}^{fused}=\hat x_{2,k}^{+},\quad
   P_k^{fused}=P_{22,k}^{+},\quad
   [\alpha_{1,k},\alpha_{2,k}]=[0,1]
   \]

4. 两通道都无效 \(s_{WSS}=0,s_{IMU}=0\)：  
   保留上一拍融合状态不置零；进入退化模式计时（`imuOnlyDuration` 累加），按系统规则维持 IMU 递推通道输出或按降级阈值保持状态。

## 7) 说明

上述公式已对应当前阶段的两通道标量实现，不使用简单逆方差加权，不新增 GPS 通道，不涉及控制器重构。  
