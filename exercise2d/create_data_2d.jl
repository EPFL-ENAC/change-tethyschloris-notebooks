using NCDatasets
using YAML
using MAT: matread
using Dates
using SparseArrays: findnz

FT = Float64

include(joinpath(@__DIR__, "utils", "data_utils.jl"))

# ---------------------------------------------------------------------------
# Simulation window
#
# The MATLAB exercise (GO_TeC_Demo.m) runs from 1 May 2005 00:00 to
# 3 October 2005 23:00, hourly. The indices below point into the raw
# CH-Cha record (Data_CH-Cha_run.mat), which starts on 1 January 2005.
# ---------------------------------------------------------------------------
local_data_dir = joinpath(@__DIR__, "data")

meteo_file = joinpath(local_data_dir, "Data_CH-Cha_run.mat")
if !isfile(meteo_file)
    @error "The file 'Data_CH-Cha_run.mat' is missing. Please request it from the repository owner and place it in the '$local_data_dir' directory."
end

geo_file = joinpath(local_data_dir, "GeoExample.mat")
if !isfile(geo_file)
    @error "The file 'GeoExample.mat' is missing. Please request it from the repository owner and place it in the '$local_data_dir' directory."
end

meteo_data = matread(meteo_file)
geo_data = matread(geo_file)
ca_data = matread(joinpath(local_data_dir, "Ca_Data.mat"))
ca_data["Date_CO2"] = vec(ca_data["Date_CO2"])

# Indices of the exercise window inside the raw record.
# The raw CH-Cha timestamps sit at half past the hour; MATLAB slices
# [first >= 1 May 2005 00:00, first >= 3 Oct 2005 23:00] = 3744 records,
# with the loop running steps 2..3744 (N_time_step = 3743).
raw_dates = vec(meteo_data["Date"]) # MATLAB serial dates, kept for CO2 matching
datevec_dates = datevec(raw_dates)
start_time = findfirst(>=(DateTime(2005, 5, 1, 0, 0)), datevec_dates)
end_time = findfirst(>=(DateTime(2005, 10, 3, 23, 0)), datevec_dates)
@info "Simulation window" start_time end_time n_records = end_time - start_time + 1

cc_max = 1 # max number of crown areas in each grid
ms_max = 12 # number of soil layers
md_max = 1
landusetypes = collect(1:2)
nlandusetypes = length(landusetypes)
nvegetationtypes = 2

meteo_data = process_data(meteo_data, start_time, end_time)

Datam = datevec(meteo_data["Date"])

m_cell, n_cell = size(geo_data["DTM"])
ncells = m_cell * n_cell

filename = "exercise_2d_data.nc"
filepath = joinpath(@__DIR__, "data", filename)

hours = 1:length(Datam)

Zs = FT[0, 10, 20, 50, 100, 150, 200, 300, 400, 500, 600, 700, 800]

n_layers = length(Zs) - 1

spatial_parameters = Dict{String,Any}()
spatial_parameters["simulation"] = Dict{String,Any}("zatm" => [30.0, 3.0])
spatial_parameters["landcover"] = Dict{String,Any}("Ccrown" => [1.0, 1.0])

vegetation_dependent = Dict{String,Any}()
vegetation_dependent["high"] = Dict{String,Any}(
    "ZRmax" => fill(FT(NaN), nvegetationtypes),
    "ZR50" => fill(FT(NaN), nvegetationtypes),
    "Knit" => [0.35, 0.35],
    "mSl" => [0.002, 0.002],
    "FI" => fill(0.081, nvegetationtypes),
    "Do" => fill(1000.0, nvegetationtypes),
    "a1" => [6.0, 6.0],
    "go" => fill(0.01, nvegetationtypes),
    "CT" => fill(3, nvegetationtypes),
    "DSE" => [0.649, 0.649],
    "Ha" => [72.0, 72.0],
    "gmes" => fill(FT(Inf), nvegetationtypes),
    "rjv" => [2.1, 2.1],
    "Vmax" => [55.0, 55.0],
    "Psi_sto_00" => fill(-0.5, nvegetationtypes),
    "Psi_sto_50" => [-2.5, -2.5],
    "PsiL00" => [-1.0, -1.0],
    "PsiL50" => [-3.2, -3.2],
    "PsiX50" => [-5.0, -5.0],
    "Kleaf_max" => [10.0, 10.0],
    "Cl" => fill(1200.0, nvegetationtypes),
    "Axyl" => fill(15.0, nvegetationtypes),
    "Kx_max" => fill(80000.0, nvegetationtypes),
    "Cx" => fill(150.0, nvegetationtypes),
    "Sl" => [0.008, 0.008],
    "Osm_reg_Max" => fill(0.0, nvegetationtypes),
    "eps_root_base" => fill(0.9, nvegetationtypes),
    "d_leaf" => [0.25, 0.25],
    "Sp_LAI_In" => [0.1, 0.1],
    "OM" => 1.0,
    "PFT_Class" => [2, 0],
)

vegetation_dependent["low"] = Dict{String,Any}(
    "ZRmax" => fill(FT(NaN), nvegetationtypes),
    "ZR50" => fill(FT(NaN), nvegetationtypes),
    "Knit" => [0.15, 0.15],
    "mSl" => zeros(FT, nvegetationtypes),
    "FI" => fill(0.081, nvegetationtypes),
    "Do" => fill(1000.0, nvegetationtypes),
    "a1" => fill(6.0, nvegetationtypes),
    "go" => fill(0.01, nvegetationtypes),
    "CT" => fill(3, nvegetationtypes),
    "DSE" => fill(0.649, nvegetationtypes),
    "Ha" => fill(55.0, nvegetationtypes),
    "gmes" => fill(FT(Inf), nvegetationtypes),
    "rjv" => fill(2.2, nvegetationtypes),
    "Vmax" => [68.0, 68.0],
    "Psi_sto_00" => [-0.5, -0.5],
    "Psi_sto_50" => [-3.0 -3.0],
    "PsiL00" => [-0.9, -0.9],
    "PsiL50" => [-4.0, -4.0],
    "PsiX50" => [-4.5, -4.5],
    "Kleaf_max" => [5.0 5.0],
    "Cl" => [1200.0, 1200.0],
    "Axyl" => zeros(FT, nvegetationtypes),
    "Kx_max" => fill(80000.0, nvegetationtypes),
    "Cx" => fill(150.0, nvegetationtypes),
    "Sl" => fill(0.035, nvegetationtypes),
    "Osm_reg_Max" => fill(0.0, nvegetationtypes),
    "eps_root_base" => fill(0.9, nvegetationtypes),
    "d_leaf" => fill(0.2, nvegetationtypes),
    "Sp_LAI_In" => fill(0.8, nvegetationtypes),
    "OM" => 1.0,
    "PFT_Class" => [0, 13],
)

vegetation_dynamics = Dict{String,Any}(
    "high" => Dict{String,Any}(
        "Sl" => fill(0.008, nvegetationtypes),
        "mSl" => fill(0.002, nvegetationtypes),
        "r" => fill(0.058, nvegetationtypes),
        "gR" => fill(0.25, nvegetationtypes),
        "LtR" => fill(0.7, nvegetationtypes),
        "eps_ac" => fill(0.1, nvegetationtypes),
        "aSE" => [0, 0],
        "Trr" => [0.25, 0.25],
        "dd_max" => [1/150, 1/150],
        "dc_C" => [78/365, 78/365],
        "Tcold" => [-20.0, -20.0],
        "drn" => [1/900, 1/900],
        "dsn" => [1/1100, 1/1100],
        "age_cr" => [950.0, 950.0],
        "Bfac_lo" => [0.99, 0.99],
        "Bfac_ls" => fill(FT(NaN), nvegetationtypes),
        "Tlo" => [4.5, 4.5],
        "Tls" => fill(FT(NaN), nvegetationtypes),
        "mjDay" => [220, 220],
        "LDay_min" => [14.05, 14.05],
        "dmg" => [30.0, 30.0],
        "Mf" => [1/80, 1/80],
        "Wm" => fill(1/(37.6477*365), nvegetationtypes),
        "LAI_min" => [0.001, 0.001],
        "LDay_cr" => [9.45, 9.45],
        "PsiG50" => [-0.5, -0.5],
        "PsiG99" => [-2.5, -2.5],
        "gcoef" => [3.5, 3.5],
        "Klf" => [1/40, 1/40],
        "fab" => [0.74, 0.74],
        "fbe" => [0.26, 0.26],
        "ff_r" => [0.1, 0.1],
        "PAR_th" => fill(FT(NaN), nvegetationtypes),
        "PsiL50" => [-3.2, -3.2],
        "PsiL00" => [-1.0, -1.0],
        "Nl" => [42.0, 42.0],
    ),
    "low" => Dict{String,Any}(
        "Sl" => fill(0.035, nvegetationtypes),
        "mSl" => zeros(FT, nvegetationtypes),
        "r" => [0.062, 0.06],
        "gR" => fill(0.25, nvegetationtypes),
        "LtR" => fill(0.35, nvegetationtypes),
        "eps_ac" => fill(0.2, nvegetationtypes),
        "aSE" => fill(2, nvegetationtypes),
        "Trr" => fill(2.0, nvegetationtypes),
        "dd_max" => fill(1/45, nvegetationtypes),
        "dc_C" => fill(7/365, nvegetationtypes),
        "Tcold" => fill(-2.0, nvegetationtypes),
        "drn" => fill(1/450, nvegetationtypes),
        "dsn" => fill(1/365, nvegetationtypes),
        "age_cr" => fill(180.0, nvegetationtypes),
        "Bfac_lo" => fill(0.99, nvegetationtypes),
        "Bfac_ls" => fill(FT(NaN), nvegetationtypes),
        "Tlo" => zeros(FT, nvegetationtypes),
        "Tls" => fill(FT(NaN), nvegetationtypes),
        "mjDay" => fill(250, nvegetationtypes),
        "LDay_min" => [10.0, 10.7],
        "dmg" => fill(20.0, nvegetationtypes),
        "Mf" => fill(1/50, nvegetationtypes),
        "Wm" => zeros(FT, nvegetationtypes),
        "LAI_min" => fill(0.1, nvegetationtypes),
        "LDay_cr" => fill(10.7, nvegetationtypes),
        "PsiG50" => [-3.0, -3.0],
        "PsiG99" => [-4.0, -4.0],
        "gcoef" => [3.5, 3.5],
        "fab" => zeros(FT, nvegetationtypes),
        "fbe" => fill(1.0, nvegetationtypes),
        "Klf" => fill(1/50, nvegetationtypes),
        "ff_r" => fill(0.1, nvegetationtypes),
        "PAR_th" => fill(FT(NaN), nvegetationtypes),
        "PsiL50" => [-4.0, -4.0],
        "PsiL00" => [-0.9, -0.9],
        "Nl" => fill(23.0, nvegetationtypes),
    ),
)

vegetationmanagement = Dict{String,Any}(
    "LAI_cut" => 0.0,
    "B_harv" => 0.0,
    "fract_log" => 0.0,
    "fire_eff" => 0.0,
    "funb_nit" => 0.15,
    "fract_girdling" => 0.0,
    "Crop_B" => [0.0, 0.0],
    "Crop_crown" => 1.0,
    "fract_resprout" => 0.2,
    "fract_left" => 1.0,
    "fract_left_fr" => 0.0,
    "fract_left_AB" => 0.0,
    "fract_left_BG" => 1.0,
)

vegetation_indices = Dict{Int,Vector{Bool}}(1 => [true, false], 2 => [false, true])

data = Dict{String,Any}()

for index in eachindex(landusetypes)

    data[string(index)] = Dict{String,Any}()
    index_data = data[string(index)]

    index_data["n_layers"] = n_layers

    # Parameters - Cell properties
    index_data["cell"] = Dict{String,Any}(
        "cellsize" => 40.0,
        # "SvF" => 1.0, # is calculated by Sky_View_Factor
        # "SN" => 0.0, # comes from the geodata structure
        # "Slo_top" => 0.0, # comes from the geodata structure
        "Ared" => 1.0,
        "aR" => 20.0,
    )

    index_data["debris"] = Dict{String,Any}(
        "alb" => 0.13,
        "e_sur" => 0.94,
        "lan" => 0.94,
        "rho" => 1496.0,
        "cs" => 948.0,
        "zom" => 0.016,
        "dbThick" => 0.0,
    )

    index_data["simulation"] = Dict{String,Any}(
        "Zs" => Zs,
        "dt" => 3600,
        "dtd" => 1,
        "Lon" => 8.4104,
        "Lat" => 47.2102,
        "DeltaGMT" => 1,
        "t_bef" => 0.25,
        "t_aft" => 0.75,
        "Zdes" => 10.0,
        "Zinf" => 10.0,
        "Zbio" => 250.0,
        "SPAR" => 2,
        "fpr" => 1.0,
        "CASE_ROOT" => 1,
        "zatm" => spatial_parameters["simulation"]["zatm"][index], # This is linked to landuse
        "timerange" => [DateTime(2005, 5, 1, 0, 0), DateTime(2005, 10, 3, 23, 0)],
        "Zbas" => 393,
    )

    index_data["landcover"] = Dict{String,Any}(
        "Cbare" => 0.0,
        "Cwat" => 0.0,
        "Curb" => 0.0,
        "Crock" => 0.0,
        "Ccrown" => spatial_parameters["landcover"]["Ccrown"][index],
    )

    index_data["rock"] =
        # STUDENT GAP: Kbot is the bedrock conductivity [mm/h]. The demo ships
        # it as NaN; the notebook asks you to fill in the value before running.
        Dict{String,Any}("Kbot" => NaN, "Krock" => 0.1, "In_max_rock" => 2.0)

    index_data["snowice"] = Dict{String,Any}(
        "TminS" => -2.5,
        "TmaxS" => -1.0,
        "WatFreez_Th" => -8.0,
        "dz_ice" => 0.45,
        "Th_Pr_sno" => 4.5,
        "ros_max1" => 450.0,
        "ros_max2" => 250.0,
        "Ice_wc_sp" => 0.01,
        "ros_ice_thr" => 500.0,
        "Aice" => 0.28,
        "dir_vis" => 0.2, # where is albedo set?
        "dif_vis" => 0.2,
        "dir_nir" => 0.2,
        "dif_nir" => 0.2,
        "Sp_SN_In" => 5.9,
    )

    index_data["soil"] = Dict{String,Any}(
        # "Pcla" => 0.13, # comes from the geodata structure
        # "Psan" => 0.30, # comes from the geodata structure
        # "Porg" => 0.0139, # comes from the geodata structure
        "Kfc" => 0.2,
        "Phy" => 10000.0,
        "color_class" => 0,
    )

    index_data["urban"] = Dict{String,Any}(
        "alb" => 0.13,
        "e_sur" => 0.94,
        "BuildH" => 12.0, # absent?
        "In_max_urb" => 5.0,
    )

    index_data["vegetation"] = Dict{String,Any}(
        "gcI" => 3.7,
        "KcI" => 0.06,
        "Kct" => 0.75,
        "Sllit" => 2.0,
        "Oa" => 210000.0,
    )

    index_data["vegetation"]["high"] = Dict{String,Any}(
        "ZRmax" => vegetation_dependent["high"]["ZRmax"][vegetation_indices[index]],
        "ZR50" => vegetation_dependent["high"]["ZR50"][vegetation_indices[index]],
        "Knit" => vegetation_dependent["high"]["Knit"][vegetation_indices[index]],
        "mSl" => vegetation_dependent["high"]["mSl"][vegetation_indices[index]],
        "FI" => vegetation_dependent["high"]["FI"][vegetation_indices[index]],
        "Do" => vegetation_dependent["high"]["Do"][vegetation_indices[index]],
        "a1" => vegetation_dependent["high"]["a1"][vegetation_indices[index]],
        "go" => vegetation_dependent["high"]["go"][vegetation_indices[index]],
        "CT" => vegetation_dependent["high"]["CT"][vegetation_indices[index]],
        "DSE" => vegetation_dependent["high"]["DSE"][vegetation_indices[index]],
        "Ha" => vegetation_dependent["high"]["Ha"][vegetation_indices[index]],
        "gmes" => vegetation_dependent["high"]["gmes"][vegetation_indices[index]],
        "rjv" => vegetation_dependent["high"]["rjv"][vegetation_indices[index]],
        "Vmax" => vegetation_dependent["high"]["Vmax"][vegetation_indices[index]],
        "Psi_sto_00" =>
            vegetation_dependent["high"]["Psi_sto_00"][vegetation_indices[index]],
        "Psi_sto_50" =>
            vegetation_dependent["high"]["Psi_sto_50"][vegetation_indices[index]],
        "PsiL00" => vegetation_dependent["high"]["PsiL00"][vegetation_indices[index]],
        "PsiL50" => vegetation_dependent["high"]["PsiL50"][vegetation_indices[index]],
        "PsiX50" => vegetation_dependent["high"]["PsiX50"][vegetation_indices[index]],
        "Kleaf_max" =>
            vegetation_dependent["high"]["Kleaf_max"][vegetation_indices[index]],
        "Cl" => vegetation_dependent["high"]["Cl"][vegetation_indices[index]],
        "Axyl" => vegetation_dependent["high"]["Axyl"][vegetation_indices[index]],
        "Kx_max" => vegetation_dependent["high"]["Kx_max"][vegetation_indices[index]],
        "Cx" => vegetation_dependent["high"]["Cx"][vegetation_indices[index]],
        "Sl" => vegetation_dependent["high"]["Sl"][vegetation_indices[index]],
        "Osm_reg_Max" =>
            vegetation_dependent["high"]["Osm_reg_Max"][vegetation_indices[index]],
        "eps_root_base" =>
            vegetation_dependent["high"]["eps_root_base"][vegetation_indices[index]],
        "d_leaf" => vegetation_dependent["high"]["d_leaf"][vegetation_indices[index]],
        "Sp_LAI_In" =>
            vegetation_dependent["high"]["Sp_LAI_In"][vegetation_indices[index]],
        "OM" => vegetation_dependent["high"]["OM"],
        "PFT_Class" =>
            vegetation_dependent["high"]["PFT_Class"][vegetation_indices[index]],
    )

    index_data["vegetation"]["low"] = Dict{String,Any}(
        "ZRmax" => vegetation_dependent["low"]["ZRmax"][vegetation_indices[index]],
        "ZR50" => vegetation_dependent["low"]["ZR50"][vegetation_indices[index]],
        "Knit" => vegetation_dependent["low"]["Knit"][vegetation_indices[index]],
        "mSl" => vegetation_dependent["low"]["mSl"][vegetation_indices[index]],
        "FI" => vegetation_dependent["low"]["FI"][vegetation_indices[index]],
        "Do" => vegetation_dependent["low"]["Do"][vegetation_indices[index]],
        "a1" => vegetation_dependent["low"]["a1"][vegetation_indices[index]],
        "go" => vegetation_dependent["low"]["go"][vegetation_indices[index]],
        "CT" => vegetation_dependent["low"]["CT"][vegetation_indices[index]],
        "DSE" => vegetation_dependent["low"]["DSE"][vegetation_indices[index]],
        "Ha" => vegetation_dependent["low"]["Ha"][vegetation_indices[index]],
        "gmes" => vegetation_dependent["low"]["gmes"][vegetation_indices[index]],
        "rjv" => vegetation_dependent["low"]["rjv"][vegetation_indices[index]],
        "Vmax" => vegetation_dependent["low"]["Vmax"][vegetation_indices[index]],
        "Psi_sto_00" =>
            vegetation_dependent["low"]["Psi_sto_00"][vegetation_indices[index]],
        "Psi_sto_50" =>
            vegetation_dependent["low"]["Psi_sto_50"][vegetation_indices[index]],
        "PsiL00" => vegetation_dependent["low"]["PsiL00"][vegetation_indices[index]],
        "PsiL50" => vegetation_dependent["low"]["PsiL50"][vegetation_indices[index]],
        "PsiX50" => vegetation_dependent["low"]["PsiX50"][vegetation_indices[index]],
        "Kleaf_max" =>
            vegetation_dependent["low"]["Kleaf_max"][vegetation_indices[index]],
        "Cl" => vegetation_dependent["low"]["Cl"][vegetation_indices[index]],
        "Axyl" => vegetation_dependent["low"]["Axyl"][vegetation_indices[index]],
        "Kx_max" => vegetation_dependent["low"]["Kx_max"][vegetation_indices[index]],
        "Cx" => vegetation_dependent["low"]["Cx"][vegetation_indices[index]],
        "Sl" => vegetation_dependent["low"]["Sl"][vegetation_indices[index]],
        "Osm_reg_Max" =>
            vegetation_dependent["low"]["Osm_reg_Max"][vegetation_indices[index]],
        "eps_root_base" =>
            vegetation_dependent["low"]["eps_root_base"][vegetation_indices[index]],
        "d_leaf" => vegetation_dependent["low"]["d_leaf"][vegetation_indices[index]],
        "Sp_LAI_In" =>
            vegetation_dependent["low"]["Sp_LAI_In"][vegetation_indices[index]],
        "OM" => vegetation_dependent["low"]["OM"],
        "PFT_Class" =>
            vegetation_dependent["low"]["PFT_Class"][vegetation_indices[index]],
    )

    # That one is a bit more complicated: for each index (composite of landuse and potential soil type)
    # we need to create a vector of Dicts, one for each vegetation type present in the grid cell.
    # The number of vegetation types is given by the sum of the boolean vector in vegetation_indices for that index.
    # Each Dict in the vector will contain the parameters for that vegetation type, which are taken from the
    # vegetation_dynamics dictionary using the same index to select the appropriate values.
    index_data["vegetationdynamics"] = Dict{String,Any}(
        "high" => fill(Dict{String,Any}(), count(vegetation_indices[index])),
        "low" => fill(Dict{String,Any}(), count(vegetation_indices[index])),
    )

    nz_indices = findall(vegetation_indices[index])
    for veg_index in eachindex(nz_indices)
        index_data["vegetationdynamics"]["high"][veg_index] = Dict{String,Any}(
            "Sl" => vegetation_dynamics["high"]["Sl"][nz_indices[veg_index]],
            "mSl" => vegetation_dynamics["high"]["mSl"][nz_indices[veg_index]],
            "r" => vegetation_dynamics["high"]["r"][nz_indices[veg_index]],
            "gR" => vegetation_dynamics["high"]["gR"][nz_indices[veg_index]],
            "LtR" => vegetation_dynamics["high"]["LtR"][nz_indices[veg_index]],
            "eps_ac" => vegetation_dynamics["high"]["eps_ac"][nz_indices[veg_index]],
            "aSE" => vegetation_dynamics["high"]["aSE"][nz_indices[veg_index]],
            "Trr" => vegetation_dynamics["high"]["Trr"][nz_indices[veg_index]],
            "dd_max" => vegetation_dynamics["high"]["dd_max"][nz_indices[veg_index]],
            "dc_C" => vegetation_dynamics["high"]["dc_C"][nz_indices[veg_index]],
            "Tcold" => vegetation_dynamics["high"]["Tcold"][nz_indices[veg_index]],
            "drn" => vegetation_dynamics["high"]["drn"][nz_indices[veg_index]],
            "dsn" => vegetation_dynamics["high"]["dsn"][nz_indices[veg_index]],
            "age_cr" => vegetation_dynamics["high"]["age_cr"][nz_indices[veg_index]],
            "Bfac_lo" => vegetation_dynamics["high"]["Bfac_lo"][nz_indices[veg_index]],
            "Bfac_ls" => vegetation_dynamics["high"]["Bfac_ls"][nz_indices[veg_index]],
            "Tlo" => vegetation_dynamics["high"]["Tlo"][nz_indices[veg_index]],
            "Tls" => vegetation_dynamics["high"]["Tls"][nz_indices[veg_index]],
            "mjDay" => vegetation_dynamics["high"]["mjDay"][nz_indices[veg_index]],
            "LDay_min" =>
                vegetation_dynamics["high"]["LDay_min"][nz_indices[veg_index]],
            "dmg" => vegetation_dynamics["high"]["dmg"][nz_indices[veg_index]],
            "Mf" => vegetation_dynamics["high"]["Mf"][nz_indices[veg_index]],
            "Wm" => vegetation_dynamics["high"]["Wm"][nz_indices[veg_index]],
            "LAI_min" => vegetation_dynamics["high"]["LAI_min"][nz_indices[veg_index]],
            "LDay_cr" => vegetation_dynamics["high"]["LDay_cr"][nz_indices[veg_index]],
            "Nl" => vegetation_dynamics["high"]["Nl"][nz_indices[veg_index]],
            "Klf" => vegetation_dynamics["high"]["Klf"][nz_indices[veg_index]],
            "fab" => vegetation_dynamics["high"]["fab"][nz_indices[veg_index]],
            "fbe" => vegetation_dynamics["high"]["fbe"][nz_indices[veg_index]],
            "ff_r" => vegetation_dynamics["high"]["ff_r"][nz_indices[veg_index]],
            "PAR_th" => vegetation_dynamics["high"]["PAR_th"][nz_indices[veg_index]],
            "PsiG50" => vegetation_dynamics["high"]["PsiG50"][nz_indices[veg_index]],
            "PsiG99" => vegetation_dynamics["high"]["PsiG99"][nz_indices[veg_index]],
            "PsiL50" => vegetation_dynamics["high"]["PsiL50"][nz_indices[veg_index]],
            "PsiL00" => vegetation_dynamics["high"]["PsiL00"][nz_indices[veg_index]],
        )

        index_data["vegetationdynamics"]["low"][veg_index] = Dict{String,Any}(
            "Sl" => vegetation_dynamics["low"]["Sl"][nz_indices[veg_index]],
            "mSl" => vegetation_dynamics["low"]["mSl"][nz_indices[veg_index]],
            "r" => vegetation_dynamics["low"]["r"][nz_indices[veg_index]],
            "gR" => vegetation_dynamics["low"]["gR"][nz_indices[veg_index]],
            "LtR" => vegetation_dynamics["low"]["LtR"][nz_indices[veg_index]],
            "eps_ac" => vegetation_dynamics["low"]["eps_ac"][nz_indices[veg_index]],
            "aSE" => vegetation_dynamics["low"]["aSE"][nz_indices[veg_index]],
            "Trr" => vegetation_dynamics["low"]["Trr"][nz_indices[veg_index]],
            "dd_max" => vegetation_dynamics["low"]["dd_max"][nz_indices[veg_index]],
            "dc_C" => vegetation_dynamics["low"]["dc_C"][nz_indices[veg_index]],
            "Tcold" => vegetation_dynamics["low"]["Tcold"][nz_indices[veg_index]],
            "drn" => vegetation_dynamics["low"]["drn"][nz_indices[veg_index]],
            "dsn" => vegetation_dynamics["low"]["dsn"][nz_indices[veg_index]],
            "age_cr" => vegetation_dynamics["low"]["age_cr"][nz_indices[veg_index]],
            "Bfac_lo" => vegetation_dynamics["low"]["Bfac_lo"][nz_indices[veg_index]],
            "Bfac_ls" => vegetation_dynamics["low"]["Bfac_ls"][nz_indices[veg_index]],
            "Tlo" => vegetation_dynamics["low"]["Tlo"][nz_indices[veg_index]],
            "Tls" => vegetation_dynamics["low"]["Tls"][nz_indices[veg_index]],
            "mjDay" => vegetation_dynamics["low"]["mjDay"][nz_indices[veg_index]],
            "LDay_min" => vegetation_dynamics["low"]["LDay_min"][nz_indices[veg_index]],
            "dmg" => vegetation_dynamics["low"]["dmg"][nz_indices[veg_index]],
            "Mf" => vegetation_dynamics["low"]["Mf"][nz_indices[veg_index]],
            "Wm" => vegetation_dynamics["low"]["Wm"][nz_indices[veg_index]],
            "LAI_min" => vegetation_dynamics["low"]["LAI_min"][nz_indices[veg_index]],
            "LDay_cr" => vegetation_dynamics["low"]["LDay_cr"][nz_indices[veg_index]],
            "Nl" => vegetation_dynamics["low"]["Nl"][nz_indices[veg_index]],
            "Klf" => vegetation_dynamics["low"]["Klf"][nz_indices[veg_index]],
            "fab" => vegetation_dynamics["low"]["fab"][nz_indices[veg_index]],
            "fbe" => vegetation_dynamics["low"]["fbe"][nz_indices[veg_index]],
            "ff_r" => vegetation_dynamics["low"]["ff_r"][nz_indices[veg_index]],
            "PAR_th" => vegetation_dynamics["low"]["PAR_th"][nz_indices[veg_index]],
            "PsiG50" => vegetation_dynamics["low"]["PsiG50"][nz_indices[veg_index]],
            "PsiG99" => vegetation_dynamics["low"]["PsiG99"][nz_indices[veg_index]],
            "PsiL50" => vegetation_dynamics["low"]["PsiL50"][nz_indices[veg_index]],
            "PsiL00" => vegetation_dynamics["low"]["PsiL00"][nz_indices[veg_index]],
        )

    end

    index_data["vegetationmanagement"] = Dict{String,Any}(
        "high" => fill(vegetationmanagement, count(vegetation_indices[index])),
        "low" => fill(vegetationmanagement, count(vegetation_indices[index])),
    )

    index_data["exudation"] = Dict{String,Any}(
        "high" =>
            fill(Dict{String,Any}("bfix" => false), count(vegetation_indices[index])),
        "low" =>
            fill(Dict{String,Any}("bfix" => false), count(vegetation_indices[index])),
    )

    index_data["biogeochemistry"] = Dict{String,Any}("PH" => 5.0, "ExEM" => 0.0)

end

YAML.write_file(joinpath(@__DIR__, "data", "exercise_2d_parameters.yaml"), data)

isfile(filepath) && rm(filepath)

ds = NCDataset(filepath, "c")

defDim(ds, "hours", length(hours))
defDim(ds, "ncells", ncells)
defDim(ds, "m_cell", m_cell)
defDim(ds, "n_cell", n_cell)
defDim(ds, "carbonpools", 8)
defDim(ds, "nutrient", 3)
defDim(ds, "biomasspools", 8)  # For vegetation biomass compartments
defDim(ds, "nutrientpools", 3)  # For N, P, K
defDim(ds, "landusetypes", nlandusetypes)
defDim(ds, "nvegetationtypes", 2)
defDim(ds, "ms_max", ms_max)
defDim(ds, "n_outlets", 1)
defDim(ds, "biogeochemistrypools", 55)

# Forcing inputs
defVar(ds, "datetime", Datam, ("hours",))
defVar(ds, "Pr", meteo_data["Pr"][hours], ("hours",))
defVar(ds, "Ta", meteo_data["Ta"][hours], ("hours",))
defVar(ds, "Ws", meteo_data["Ws"][hours], ("hours",))
defVar(ds, "ea", meteo_data["ea"][hours], ("hours",))
defVar(ds, "SAD1", meteo_data["SAD1"][hours], ("hours",))
defVar(ds, "SAD2", meteo_data["SAD2"][hours], ("hours",))
defVar(ds, "SAB1", meteo_data["SAB1"][hours], ("hours",))
defVar(ds, "SAB2", meteo_data["SAB2"][hours], ("hours",))
defVar(ds, "Pre", meteo_data["Pre"][hours], ("hours",))
defVar(ds, "N", meteo_data["N"][hours], ("hours",))
defVar(ds, "Tdew", meteo_data["Tdew"][hours], ("hours",))
defVar(ds, "esat", meteo_data["esat"][hours], ("hours",))
defVar(ds, "PARB", meteo_data["PARB"][hours], ("hours",))
defVar(ds, "PARD", meteo_data["PARD"][hours], ("hours",))

Ds = max.(meteo_data["esat"][hours] - meteo_data["ea"][hours], 0)
defVar(ds, "Ds", Ds, ("hours",))

date_index = finddate(ca_data, raw_dates, start_time)
Ca = vec(ca_data["Ca"][date_index:finddate(ca_data, raw_dates, end_time)])
@assert length(Ca) == length(hours) "CO2 record does not cover the simulation window"
defVar(ds, "Ca", Ca, ("hours",))

# Grid

grid = defGroup(ds, "grid")

defVar(grid, "cellsize", geo_data["cellsize"], ())

Slo_top = geo_data["Slo_top"]

# Land-use codes: the MATLAB demo collapses classes 1-4 to two vegetation
# types (1 = wood, 2-4 = grass/shrub) before running (GO_TeC_Demo.m:184-188).
ksv = copy(geo_data["ksv"])
ksv[ksv.==3] .= 2
ksv[ksv.==4] .= 2
Xout = Int.(geo_data["Xout"])
Yout = Int.(geo_data["Yout"])
Slo_top[Yout, Xout] = 0.05

defVar(grid, "DTM", geo_data["DTM"], ("m_cell", "n_cell"))
defVar(grid, "Slo_top", Slo_top, ("m_cell", "n_cell"))
defVar(grid, "Aspect", geo_data["Aspect"], ("m_cell", "n_cell"))
defVar(grid, "ksv", ksv, ("m_cell", "n_cell"))
defVar(grid, "PSAN", geo_data["PSAN"] ./ 100, ("m_cell", "n_cell"))
defVar(grid, "PORG", geo_data["PORG"] ./ 100, ("m_cell", "n_cell"))
defVar(grid, "PCLA", geo_data["PCLA"] ./ 100, ("m_cell", "n_cell"))
defVar(grid, "SN", geo_data["SN"], ("m_cell", "n_cell"))
defVar(grid, "rho_g", geo_data["rho_g"], ())
defVar(grid, "NMAN_H", geo_data["NMAN_H"], ("m_cell", "n_cell"))
defVar(grid, "NMAN_C", geo_data["NMAN_C"], ("m_cell", "n_cell"))
defVar(grid, "MRough", geo_data["MRough"], ("m_cell", "n_cell"))
defVar(grid, "WC", geo_data["WC"], ("m_cell", "n_cell"))

I, J, V = findnz(geo_data["T_flow"])
defDim(grid, "n_connections", length(I))

defVar(grid, "T_flow_I", I, ("n_connections",))
defVar(grid, "T_flow_J", J, ("n_connections",))
defVar(grid, "T_flow_V", V, ("n_connections",))

defVar(grid, "Xout", geo_data["Xout"], ("n_outlets",))
defVar(grid, "Yout", geo_data["Yout"], ("n_outlets",))

ZR95 = Dict{String,Any}("high" => [400.0, 0.0], "low" => [0.0, 250.0])

for index in eachindex(landusetypes)
    nz_indices = findall(vegetation_indices[index])

    index_ds = defGroup(ds, string(index))

    cc = length(spatial_parameters["landcover"]["Ccrown"][index])

    defDim(index_ds, "crownareas", length(cc))
    defDim(index_ds, "layers", length(Zs))
    defDim(index_ds, "layerbelowsurface", n_layers)

    # TODO: account for mask

    # State variables
    index_state = defGroup(index_ds, "state")

    ## Hydrologic state variables
    index_hsv = defGroup(index_state, "hydrologic")
    V_init = [
        2.7124,
        2.6137,
        7.2269,
        11.6407,
        14.9032,
        15.5283,
        30.9157,
        30.9457,
        30.9867,
        30.9867,
        30.9867,
        30.9867,
    ]
    defVar(index_hsv, "V", V_init, ("layerbelowsurface",))
    defVar(index_hsv, "Ts", FT(5.0), ())
    defVar(index_hsv, "Tdp", fill(FT(5.0), n_layers), ("layerbelowsurface",))
    defVar(index_hsv, "Tdamp", FT(5.0), ())
    defVar(index_hsv, "e_sno", FT(0.97), ())
    defVar(index_hsv, "Ws_under", FT(1.0), ())

    index_hsv_H = defGroup(index_hsv, "high")
    defVar(index_hsv_H, "Ci_sun", fill(FT(370.0), cc), ("crownareas",))
    defVar(index_hsv_H, "Ci_shd", fill(FT(370.0), cc), ("crownareas",))

    index_hsv_L = defGroup(index_hsv, "low")
    defVar(index_hsv_L, "Ci_sun", fill(FT(370.0), cc), ("crownareas",))
    defVar(index_hsv_L, "Ci_shd", fill(FT(370.0), cc), ("crownareas",))

    ## Vegetation state variables
    index_vsv = defGroup(index_state, "vegetation")

    ### High vegetation state variables
    index_vsv_H = defGroup(index_vsv, "high")
    defVar(index_vsv_H, "TdpI", fill(FT(5.0), cc), ("crownareas",))
    defVar(index_vsv_H, "PHE_S", ones(Int, cc), ("crownareas",))
    defVar(index_vsv_H, "Bfac_week", ones(Int, cc), ("crownareas",))
    # defVar(index_vsv_H, "Nreserve", fill(FT(1000.0), cc), ("crownareas",))
    # defVar(index_vsv_H, "Preserve", fill(FT(1000.0), cc), ("crownareas",))
    # defVar(index_vsv_H, "Kreserve", fill(FT(1000.0), cc), ("crownareas",))
    defVar(index_vsv_H, "FNC", ones(Int, cc), ("crownareas",)) # Truly defined

    defVar(index_vsv_H, "ZR95", ZR95["high"][nz_indices], ("crownareas",))

    if index == 1
        defVar(index_vsv_H, "Nreserve", fill(FT(1.55), cc), ("crownareas",))
        defVar(index_vsv_H, "Preserve", fill(FT(1.0198), cc), ("crownareas",))
        defVar(index_vsv_H, "Kreserve", fill(FT(4.55), cc), ("crownareas",))
        defVar(index_vsv_H, "NupI", [0.026, 0.035, 0.0148], ("nutrients",))
        defVar(index_vsv_H, "AgeL", fill(921.7089, cc), ("crownareas",))


        B = zeros(FT, cc, 8)
        B[1, :] .=
            1e4 * [
                0.033092308952079,
                0.084705546337639,
                0.047195657817041,
                0.001260057362465,
                0.001137111675597,
                1.416593548682712,
                0.001350153649459,
                0.0,
            ]
        defVar(index_vsv_H, "B", B, ("crownareas", "carbonpools"))
    elseif index == 2
        defVar(index_vsv_H, "Nreserve", fill(FT(4.07), cc), ("crownareas",))
        defVar(index_vsv_H, "Preserve", fill(FT(0.05), cc), ("crownareas",))
        defVar(index_vsv_H, "Kreserve", fill(FT(5.88), cc), ("crownareas",))
        defVar(
            index_vsv_H,
            "NupI",
            [0.050622818855329, 0.003112271545765, 0.018798279749436],
            ("nutrients",),
        )
        defVar(index_vsv_H, "AgeL", fill(208.0, cc), ("crownareas",))
    end

    ### Low vegetation state variables
    index_vsv_L = defGroup(index_vsv, "low")
    defVar(index_vsv_L, "TdpI", fill(FT(5.0), cc), ("crownareas",)) # check
    defVar(index_vsv_L, "PHE_S", ones(Int, cc), ("crownareas",))
    defVar(index_vsv_L, "Bfac_week", ones(Int, cc), ("crownareas",))
    # defVar(index_vsv_L, "Nreserve", fill(FT(1000.0), cc), ("crownareas",))
    # defVar(index_vsv_L, "Preserve", fill(FT(1000.0), cc), ("crownareas",))
    # defVar(index_vsv_L, "Kreserve", fill(FT(1000.0), cc), ("crownareas",))
    defVar(index_vsv_L, "FNC", ones(Int, cc), ("crownareas",))
    defVar(index_vsv_L, "ZR95", ZR95["low"][nz_indices], ("crownareas",))

    if index == 2
        B_L = zeros(FT, cc, 8)
        B_L[1, :] = [68.5080, 0.0, 385.6041, 287.1935, 0.0, 0.0, 133.6411, 0.0]
        defVar(index_vsv_L, "B", B_L, ("crownareas", "carbonpools"))
    end

    ## Biogeochemistry state variables
    index_bsv = defGroup(index_state, "biogeochemistry")

    if index == 1
        defVar(
            index_bsv,
            "RexmyI",
            [0.034494477728013, 0.083401382638014, 0.0],
            ("nutrient",),
        )
        defVar(
            index_bsv,
            "NavlI",
            [0.368914375972645, 0.021511814488325, 0.163037496597298],
            ("nutrient",),
        )

        P =
            10000 * [
                0.012887678521659,
                0.026513768835875,
                0.004294053140209,
                -0.000000000000306,
                -0.000000000000306,
                0.009849579839365,
                0.015730209309402,
                0.001747801034378,
                0.054980747092949,
                0.065851893223213,
                0.487702327772202,
                0.000969636557271,
                0.000775709245775,
                0.000005215826732,
                0.000003352755345,
                0.000002173261138,
                0.000005587925575,
                0.001832210660043,
                0.006412870033077,
                0.002762981381532,
                -0.000000000022002,
                0.000472757790703,
                0.000645718115902,
                -0.000000000000306,
                0.000578731901920,
                0.075820314530414,
                0.000354616443662,
                0.000989877483989,
                0.000153338048960,
                -0.000000000010825,
                0.000046401470598,
                0.000011867526542,
                0.000001884743933,
                0.000047275779070,
                0.000046122722564,
                -0.000000000000306,
                0.000041337992994,
                0.010500686803967,
                0.000114482200304,
                0.000160719978234,
                0.000023000707344,
                -0.000000000010825,
                0.000009999680873,
                2.225634090052153,
                0.000206082941260,
                0.150087462559334,
                0.000000014290621,
                0.000322859057951,
                -0.000000000000306,
                0.000067294407200,
                0.000243874309129,
                0.000017195888964,
                0.000015728961616,
                0.000353867324328,
                0.049097316650901,
            ]
        defVar(index_bsv, "P", P, ("biogeochemistrypools",))
    elseif index == 2
        defVar(index_bsv, "RexmyI", [0.0529, 0.1086, 0.0], ("nutrient",))
        defVar(index_bsv, "NavlI", [0.1156, 1.5238, 1.2212], ("nutrient",))
    end

    ### High biogeochemistry state variables
    index_bsv_H = defGroup(index_bsv, "high")

    # Auxiliary variables
    index_auxiliary = defGroup(index_ds, "auxiliary")

    ## Vegetation auxiliary variables
    index_vav = defGroup(index_auxiliary, "vegetation")

    ### High vegetation auxiliary variables
    index_vav_H = defGroup(index_vav, "high")
    if index == 1
        defVar(index_vav_H, "LAI", fill(3.98, cc), ("crownareas",))
        defVar(index_vav_H, "hc", fill(19.0, cc), ("crownareas",))
        defVar(index_vav_H, "e_rel", ones(Int, cc), ("crownareas",))
        defVar(index_vav_H, "e_relN", ones(Int, cc), ("crownareas",))
        defVar(index_vav_H, "SAI", fill(0.2, cc), ("crownareas",))
    end


    ### Low vegetation auxiliary variables
    index_vav_L = defGroup(index_vav, "low")
    if index == 2
        defVar(index_vav_L, "LAI", fill(FT(2.4), cc), ("crownareas",))
        defVar(index_vav_L, "hc", fill(0.16, cc), ("crownareas",))
        defVar(index_vav_L, "e_rel", ones(Int, cc), ("crownareas",))
        defVar(index_vav_L, "e_relN", ones(Int, cc), ("crownareas",))
        defVar(index_vav_L, "SAI", fill(0.001, cc), ("crownareas",))
    end

end

close(ds)

# end
