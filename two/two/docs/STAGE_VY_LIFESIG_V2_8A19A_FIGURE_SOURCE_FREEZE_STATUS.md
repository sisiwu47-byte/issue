# V2.8-A19a thesis figure source code freeze

## Final verdict

`THESIS_FIGURE_SOURCE_FREEZE_PASS`

- `PERSISTED_PLOTTING_SOURCE_FOUND = YES`
- `PLOTTING_SOURCE_MODIFIED = NO`
- `PLOTTING_SOURCE = results/vy_lifesig_v2_8a19_thesis_figures/generate_thesis_figures.js`
- `PLOTTING_SOURCE_SHA256 = CCBF52A4D6192889E32814B3877947C6DCAF612F3E26AD84C03AC1DFAA069FAB`
- `THREE_FIGURES_REPRODUCIBLE = YES`
- `REPRODUCIBILITY_MODE = VISUAL/STRUCTURAL_REPRODUCIBILITY_ONLY`
- `A19A_PLOTTING_RUNTIME_COUNT = 0`
- `A17d_FORMAL_RUNTIME_COUNT_REMAINS = 1`
- `DATA_MODIFICATION = NO`
- `ALGORITHM_MODIFICATION = NO`
- `PARAMETER_MODIFICATION = NO`
- `FIGURE_STYLE_MODIFICATION = NO`
- `THESIS_FIGURE_SOURCE_FROZEN = YES`

## Source decision

The actual A19 plotting source was already persisted as `generate_thesis_figures.js` and had generated the accepted Figure 1/2/3 PNG, PDF, and SVG files. Per the A19a existing-source branch, the source was not edited and no replacement Python implementation was created.

Runtime environment frozen in the source manifest:

- Node.js `24.19.0`;
- `sharp 0.35.4`;
- `playwright 1.62.1`;
- system Microsoft Edge headless PDF backend;
- Times New Roman / SimSun font chain;
- Python `3.12.13` used only for A19a's read-only static audit, with no third-party Python package.

## SOURCE_REPRODUCIBILITY_CHECK

`STATIC_SOURCE_CONTRACT_PASS`

- Figure count: `3`.
- Formats: all `3 x PNG/PDF/SVG` outputs exist and are non-empty.
- Dimensions: `4134 x 3543`, `4134 x 5551`, `4134 x 3543`.
- SVG curve counts: `4`, `7`, `5`, matching `1+3`, `2+1+1+3`, `3+2`.
- Source signals match the frozen Figure 1/2/3 contracts.
- X range remains `0--40.5 s`; boundaries remain `5.0 s` and `22.5 s`.
- A17d `full_timeseries.csv` SHA-256 remains `7CEB37FCDF2C10812D5EB79E73EDACB582458869352CD7C416800C206426FC1B`.
- A17d/A18 phase metrics match exactly for all 12 rows and four metrics.
- No scientific metric was recalculated, re-frozen, or changed.

A19a did not run the JavaScript plotting source because regeneration was restricted to a Python plotting script and the existing-source branch prohibits rewriting the accepted source. Consequently, no `reproduction_check/` directory was needed and no accepted A19 output was overwritten. Byte/pixel identity is not newly claimed; the freeze status is `VISUAL/STRUCTURAL_REPRODUCIBILITY_ONLY`.

## Frozen files

- `results/vy_lifesig_v2_8a19_thesis_figures/generate_thesis_figures.js`
- `results/vy_lifesig_v2_8a19_thesis_figures/thesis_figure_source_manifest.md`
- `results/vy_lifesig_v2_8a19_thesis_figures/requirements_thesis_figures.txt`

No MATLAB, Simulink, CarSim, GUI, `sim()`, or vehicle-model runtime was invoked.
