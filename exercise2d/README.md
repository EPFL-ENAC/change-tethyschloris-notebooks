# Exercise 2D: spatially-distributed T&C

Julia translation of the MATLAB `Exercise 2D` (`TC_spatial_demo`), using the
spatially-distributed (`Model2D`) implementation in TethysChloris.jl.

## Contents

- `exercise2d.ipynb` - the exercise notebook
- `create_data_2d.jl` - script that generates the NetCDF forcing + YAML
  parameters from the raw MATLAB files in `data/`
- `utils/data_utils.jl` - shared data-conversion helpers
- `data/` - raw inputs (committed) and generated files (not committed)

## Data sources

The raw files ship with the exercise so it runs out of the box:

- `Data_CH-Cha_run.mat` - hourly CH-Cha (Chamau) station data
- `GeoExample.mat` - demo catchment geodata (50x50 cells at 40 m)
- `Ca_Data.mat` - atmospheric CO2 record

The simulation window is 1 May to 3 October 2005 (3743 hourly steps), as in
the MATLAB demo `GO_TeC_Demo.m`. Students fill in the bedrock conductivity
`Kbot` in the generated YAML before the full run (mirrors the MATLAB
exercise's `Kbot = [NaN NaN]` gap).

The full run takes several hours on a laptop; a 10-step smoke run validates
the setup first.
