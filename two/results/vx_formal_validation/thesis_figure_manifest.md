# VX-V1 Thesis Figure Manifest

- Formal runtime count: `0`
- Images generated from formal runtime: `0`
- Allowed status values: `NOT_GENERATED`, `GENERATED_NEEDS_REVIEW`, `DIRECTLY_USABLE`, `NEEDS_THESIS_REFORMAT`

## Frozen visual-style contract

- Style source: `results/vy_lifesig_v2_8a19_thesis_figures/generate_thesis_figures.js`
- Style source SHA-256: `CCBF52A4D6192889E32814B3877947C6DCAF612F3E26AD84C03AC1DFAA069FAB`
- Supporting manifests: `thesis_plot_style_manifest.md`, `thesis_figure_export_manifest.md` in the same Vy directory.
- Canvas: `175 x 150 mm` for VX-FIG-01; `175 x 235 mm` for the multi-panel VX-FIG-02, directly reusing the two frozen Vy canvas classes.
- Palette/strokes: truth `#111111`, WSS `#0072B2` dash-dot, IMU `#D55E00` dashed, Fusion `#009E73` long-dashed; line widths `2.6/2.0/2.0/2.3` respectively; no markers.
- Axes: white background, `#111111` frame, `1.2` frame width, `#D8D8D8` grid at `0.55` opacity, Times New Roman with Chinese serif fallback, horizontal frameless legends, compact subplot spacing.
- Export: PNG at `600 dpi`, plus vector PDF and SVG. No visual style may be redesigned during formal plotting without a new documented thesis-figure freeze.
- MATLAB has named dash styles rather than arbitrary SVG dash arrays. The paired `.m` scripts use the closest native equivalents and preserve the exact frozen colors and widths; this limitation is recorded rather than silently inventing a new style.

## VX-FIG-01

| Field | Value |
|---|---|
| figure_id | `VX-FIG-01` |
| recommended_title | 正常动态工况下纵向速度估计结果 |
| scientific_question | 正常纵向动态条件下，两局部轨迹和融合估计是否保持有效？ |
| source_case | `N2` (default); `T1` may replace it only before thesis freeze if steering is the selected representative input |
| source_result_file | `results/vx_formal_validation/VX_N2_formal.mat` |
| plotting_code | `results/vx_formal_validation/thesis_figures/VX_FIG01_normal_dynamic_estimation.m` |
| output_image | `results/vx_formal_validation/thesis_figures/VX_FIG01_normal_dynamic_estimation.png` |
| required_signals | time, Ax, CarSim Vx, WSS, IMU, Fusion |
| subplot_layout | `2x1`: (a) Ax; (b) four Vx curves |
| curves_per_axis | `1`, `4` |
| thesis_role | Main normal/dynamic performance figure |
| status | `NOT_GENERATED` |

## VX-FIG-02

| Field | Value |
|---|---|
| figure_id | `VX-FIG-02` |
| recommended_title | 轮速退化—恢复及自适应融合过程 |
| scientific_question | 轮速退化后 rho 是否下降、WSS 是否降权，并在恢复后重新启用？ |
| source_case | `D1` by default; D2 replaces it only if its preregistered metrics are more representative |
| source_result_file | `results/vx_formal_validation/VX_D1_formal.mat` |
| plotting_code | `results/vx_formal_validation/thesis_figures/VX_FIG02_degradation_recovery_fusion.m` |
| output_image | `results/vx_formal_validation/thesis_figures/VX_FIG02_degradation_recovery_fusion.png` |
| required_signals | time, CarSim Vx, WSS, IMU, Fusion, rho_RL, rho_RR, alpha_W, alpha_I |
| subplot_layout | `3x1`: speed; affected-wheel health; fusion weights |
| curves_per_axis | `4`, `2`, `2` |
| thesis_role | Main degradation/recovery mechanism figure |
| status | `NOT_GENERATED` |

No image may move out of `NOT_GENERATED` unless its paired plotting code is present and the MAT metadata says `formalRuntime=true` with matching current hashes.
