using CSV: File
using DataFrames: DataFrame
using NaNMath: NaNMath
using Dates: DateTime, Day, Millisecond, dayofyear, hour, month, year
using MAT: matwrite
using NCDatasets: NCDataset, defDim, defVar, defGroup

required_variables = [
  "TIMESTAMP_END",
  "TA_F", "SW_IN_F", "PPFD_IN", "LW_IN_F", "VPD_F", "PA_F", "P_F",
          "WS_F", "RH", "CO2_F_MDS", "TS_F_MDS_1", "TS_F_MDS_2", "TS_F_MDS_3",
          "TS_F_MDS_4", "TS_F_MDS_5", "TS_F_MDS_6", "SWC_F_MDS_1", "SWC_F_MDS_2",
          "SWC_F_MDS_3", "SWC_F_MDS_4", "SWC_F_MDS_5", "SWC_F_MDS_6",
          "SWC_F_MDS_7", "NETRAD", "LE_F_MDS", "LE_F_MDS_QC", "LE_CORR", "H_F_MDS",
          "H_F_MDS_QC", "H_CORR", "G_F_MDS", "NEE_CUT_REF", "NEE_VUT_REF",
          "NEE_CUT_50", "NEE_VUT_50", "RECO_NT_VUT_REF", "RECO_NT_VUT_50",
          "RECO_DT_VUT_REF", "RECO_DT_VUT_50", "GPP_NT_VUT_REF", "GPP_NT_VUT_50",
          "GPP_DT_VUT_REF", "GPP_DT_VUT_50",
]
input_path = joinpath(@__DIR__, "data", "EUF_CH-Cha_FLUXNET_FLUXMET_HH_2005-2024_v1.3_r1.csv")
# input_path = joinpath(@__DIR__, "data", "FLX_CH-Lae_FLUXNET2015_FULLSET_HH_2004-2023_1-3.csv")
raw_data = File(input_path, select = required_variables)
df = DataFrame(raw_data)

# convert all vars except TIMESTAMP_END to Float64
for var in required_variables
    if var != "TIMESTAMP_END" && hasproperty(df, var)
        df[!, var] = Float64.(df[!, var])
    end
end

# Hard-coded parameters for now
Lon = 8.4104
Lat = 47.2102
DeltaGMT = 1
Zbas = 	393

# apply datenum
date_start = 7.323130208333334e+05 # df.TIMESTAMP_START[1]
date_end = 7.396179583333334e+05 # df.TIMESTAMP_START[end]
Date = date_start:(1/24):date_end

# allowmissing!(df)
@. df = ifelse(df == -9999, NaN64, df)

# Aggregate half-hourly data to hourly
dt = 0.5
n = size(df, 1)
fr = Int(1/dt)
m = floor(Int, n/fr)

# create a new DataFrame to hold the aggregated data

# Create a new column for the hourly timestamps, 1,1,2,2,3,3, ..., m, m
df[!, :hourly_index] = repeat(1:m, inner=fr)[1:n]

mean_variables = setdiff(propertynames(df), [:hourly_index, :TIMESTAMP_END, :P_F])

df_hourly = combine(
  groupby(df, :hourly_index),
  :TIMESTAMP_END => first,
  mean_variables .=> NaNMath.mean,
  :P_F => NaNMath.sum,
  keepkeys = false,
  renamecols = false
)

# add missing variables

for var in required_variables
    if !hasproperty(df_hourly, var)
        df_hourly[!, var] .= NaN64
    end
end

# Remove poorly interpolated data
threshold_radiation = 3
threshold_co2 = 0.2
radiation_variables = [:NETRAD, :LE_F_MDS, :H_F_MDS, :G_F_MDS]

function correct_interpolation!(
  v::AbstractVector,
  interval::Int,
  threshold::Number
)
  half_interval = div(interval, 2)
  m = length(v)
  for j = interval:half_interval:m
    if sum(abs.(v[j-interval+1:j-half_interval] - v[j-half_interval+1:j])) < threshold*half_interval
      v[j-half_interval+1:j] .= NaN64
    end
  end

  return nothing
end

for var in radiation_variables
  # Correction over two weeks
  correct_interpolation!(df_hourly[!, var], 336, threshold_radiation)
  # Correction over six days
  correct_interpolation!(df_hourly[!, var], 144, threshold_radiation)
  # Correction over 2 days
  correct_interpolation!(df_hourly[!, var], 48, threshold_radiation)
end


co2_variables = [:NEE_CUT_REF, :NEE_VUT_REF, :NEE_CUT_50, :NEE_VUT_50, :RECO_NT_VUT_REF,
    :RECO_NT_VUT_50,
    :RECO_DT_VUT_REF,
    :RECO_DT_VUT_50,
    :GPP_NT_VUT_REF, :GPP_NT_VUT_50, :GPP_DT_VUT_REF, :GPP_DT_VUT_50]

for var in co2_variables
  # Correction over two weeks
  correct_interpolation!(df_hourly[!, var], 336, threshold_co2)
  # Correction over six days
  correct_interpolation!(df_hourly[!, var], 144, threshold_co2)
  # Correction over 2 days
  correct_interpolation!(df_hourly[!, var], 48, threshold_co2)
end

function outside_to_nan!(
  v::AbstractVector{<:AbstractFloat},
  lo::Real,
  hi::Real;
)
    @inbounds for i in eachindex(v)
        x = v[i]
        if !isnan(x) && (x < lo || x > hi)
            v[i] = NaN
        end
    end
    return v
end

transform!(
  df_hourly,
  :TA_F => (x -> outside_to_nan!(x, -60, 70)) => :Ta,
  :SW_IN_F => (x -> clamp.(outside_to_nan!(x, -10, 2000), 0, 2000)) => :Rsw,
  :PPFD_IN => (x -> clamp.(outside_to_nan!(x, -10, 3000), 0, 3000)) => :PPFD,
  :LW_IN_F => (x -> outside_to_nan!(x, -600, 600)) => :Latm,
  :VPD_F => (x -> outside_to_nan!(x, 0, 70)) => :VPD,
  :PA_F => (x -> outside_to_nan!(x .* 10, 0, Inf)) => :Pre,
  :P_F => (x -> outside_to_nan!(x, 0, 220)) => :Pr,
  :WS_F => (x -> outside_to_nan!(x, 0, 100)) => :Ws,
  :RH => (x -> outside_to_nan!(x, 0, 100) ./ 100) => :U,
  :CO2_F_MDS => (x -> outside_to_nan!(x, 0, 900)) => :CO2,
  :TS_F_MDS_1 => (x -> outside_to_nan!(x, -50, 90)) => :Tsoil1,
  :TS_F_MDS_2 => (x -> outside_to_nan!(x, -50, 90)) => :Tsoil2,
  :TS_F_MDS_3 => (x -> outside_to_nan!(x, -50, 90)) => :Tsoil3,
  :TS_F_MDS_4 => (x -> outside_to_nan!(x, -50, 90)) => :Tsoil4,
  :TS_F_MDS_5 => (x -> outside_to_nan!(x, -50, 90)) => :Tsoil5,
  :TS_F_MDS_6 => (x -> outside_to_nan!(x, -50, 90)) => :Tsoil6,
  :SWC_F_MDS_1 => (x -> outside_to_nan!(x, 0, 100)) => :SWC1,
  :SWC_F_MDS_2 => (x -> outside_to_nan!(x, 0, 100)) => :SWC2,
  :SWC_F_MDS_3 => (x -> outside_to_nan!(x, 0, 100)) => :SWC3,
  :SWC_F_MDS_4 => (x -> outside_to_nan!(x, 0, 100)) => :SWC4,
  :SWC_F_MDS_5 => (x -> outside_to_nan!(x, 0, 100)) => :SWC5,
  :SWC_F_MDS_6 => (x -> outside_to_nan!(x, 0, 100)) => :SWC6,
  :SWC_F_MDS_7 => (x -> outside_to_nan!(x, 0, 100)) => :SWC7,
  :NETRAD => (x -> outside_to_nan!(x, -1550, 1000)) => :Rn,
  :LE_F_MDS => (x -> outside_to_nan!(x, -250, 1500)) => :LE,
  :LE_F_MDS_QC => :LE_QC,
  :LE_CORR => :LE_CORR,
  :H_F_MDS => (x -> outside_to_nan!(x, -1550, 1500)) => :H,
  :H_F_MDS_QC => :H_QC,
  :H_CORR => :H_CORR,
  :G_F_MDS => (x -> outside_to_nan!(x, -250, 1500)) => :G,
  :NEE_CUT_REF => (x -> outside_to_nan!(x, -500, 500)) => :NEE1,
  :NEE_VUT_REF => (x -> outside_to_nan!(x, -500, 500)) => :NEE2,
  :NEE_CUT_50 => (x -> outside_to_nan!(x, -500, 500)) => :NEE3,
  :NEE_VUT_50 => (x -> outside_to_nan!(x, -500, 500)) => :NEE4,
  :RECO_NT_VUT_REF => (x -> outside_to_nan!(x, -10, 1500)) => :Reco1,
  :RECO_NT_VUT_50 => (x -> outside_to_nan!(x, -10, 1500)) => :Reco2,
  :RECO_DT_VUT_REF => (x -> outside_to_nan!(x, -10, 1500)) => :Reco3,
  :RECO_DT_VUT_50 => (x -> outside_to_nan!(x, -10, 1500)) => :Reco4,
  :GPP_NT_VUT_REF => (x -> outside_to_nan!(x, -10, Inf)) => :GPP1,
  :GPP_NT_VUT_50 => (x -> outside_to_nan!(x, -10, Inf)) => :GPP2,
  :GPP_DT_VUT_REF => (x -> outside_to_nan!(x, -10, Inf)) => :GPP3,
  :GPP_DT_VUT_50 => (x -> outside_to_nan!(x, -10, Inf)) => :GPP4,
)

df_hourly.LE[df_hourly.LE_QC .== 3] .= NaN
df_hourly.H[df_hourly.H_QC .== 3] .= NaN

# Fill gaps through interpolation
replace!(df_hourly.Pre, NaN => NaNMath.mean(df_hourly.Pre))

function remove_bumps!(df_hourly, var, threshold)
  dVar = vcat(0, diff(df_hourly[!, var]))
  df_hourly[abs.(dVar) .> threshold, var] .= NaN
  dVar = vcat(0, diff(df_hourly[!, var]))
  df_hourly[isnan.(dVar), var] .= NaN
  dVar = vcat(0, diff(df_hourly[!, var]))
  df_hourly[isnan.(dVar), var] .= NaN
  return nothing
end

remove_bumps!(df_hourly, :Ta, 10)
remove_bumps!(df_hourly, :Ws, 9)
remove_bumps!(df_hourly, :CO2, 40)
