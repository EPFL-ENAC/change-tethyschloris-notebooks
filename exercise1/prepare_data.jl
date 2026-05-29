using MAT: matread
using Dates: DateTime
using YAML: write_file
using NCDatasets: NCDataset, defGroup, defDim, defVar

"""
  prepare_parameters(; Psan::Float64 = 0.254, Pcla::Float64 = 0.244)

  Prepares a dictionary containing the parameters for the Tethys-Chloris model. The
  parameters are organized into different categories such as cell properties, debris cover
  parameters, simulation settings, landcover properties, rock properties, snow and ice
  properties, soil properties, urban properties, vegetation properties, vegetation dynamics,
  vegetation management, and exudation.

  The function takes optional keyword arguments for the soil properties (Psan and Pcla) and
  returns a dictionary with all the parameters.

  # Arguments
  - `Psan::Float64`: The percentage of sand in the soil. Default is 0.254.
  - `Pcla::Float64`: The percentage of clay in the soil. Default is 0.244.

  # Returns
  - `data::Dict{String,Any}`: A dictionary containing all the parameters for the
    Tethys-Chloris model, organized into different categories.
"""
function prepare_parameters(;
  Psan::Float64 = 0.254,
  Pcla::Float64 = 0.244,
)

  FT = Float64

  Zs = FT.([0, 10, 20, 50, 100, 150, 200, 300, 400, 500, 600, 800, 1000, 1300])

  n_layers = length(Zs) - 1

  data = Dict{String,Any}()

  data["n_layers"] = n_layers

  # Parameters - Cell properties
  data["cell"] = Dict{String,Any}(
      "cellsize" => 1.0,
      "SvF" => 1.0,
      "SN" => 1.0,
      "Slo_top" => 0.0,
      "Ared" => 1.0,
      "aR" => 1.0,
  );

  # Parameters - Debris cover parameters
  data["debris"] = Dict{String,Any}(
      "alb" => 0.13,
      "e_sur" => 0.94,
      "lan" => 0.945,
      "rho" => 1496.0,
      "cs" => 948.0,
      "dbThick" => 0.0,
      "zom" => 0.016,
  );

  data["simulation"] = Dict{String,Any}(
      "Zs" => Zs,
      "dt" => 3600,
      "dtd" => 1,
      "Lon" => 8.4104,
      "Lat" => 47.2102,
      "DeltaGMT" => 1,
      "t_bef" => 0.0,
      "t_aft" => 1.0,
      "Zdes" => 10.0,
      "Zinf" => 10.0,
      "Zbio" => 250.0,
      "SPAR" => 2,
      "fpr" => 1.0,
      "CASE_ROOT" => 1,
      "zatm" => 2.41,
      # "timerange" => [minimum(Datam), maximum(Datam)],
      "timerange" => [DateTime("2005-01-01T00:30:00"), DateTime("2014-12-31T23:30:00")],
  );

  data["landcover"] = Dict{String,Any}(
      "Cbare" => 0.0,
      "Cwat" => 0.0,
      "Curb" => 0.0,
      "Crock" => 0.0,
      "Ccrown" => [1.0],
  );

  data["rock"] = Dict{String,Any}("Kbot" => NaN64, "Krock" => NaN64, "In_max_rock" => 0.1);

  data["snowice"] = Dict{String,Any}(
      "TminS" => -0.8,
      "TmaxS" => 2.8,
      "WatFreez_Th" => -8.0,
      "dz_ice" => 0.45,
      "Th_Pr_sno" => 8.0,
      "ros_max1" => 550.0,
      "ros_max2" => 300.0,
      "Ice_wc_sp" => 0.01,
      "ros_ice_thr" => 500.0,
      "Aice" => 0.28,
      "dir_vis" => 0.2,
      "dif_vis" => 0.2,
      "dir_nir" => 0.2,
      "dif_nir" => 0.2,
      "Sp_SN_In" => 5.9,
  );

  data["soil"] = Dict{String,Any}(
      "Pcla" => Pcla,
      "Psan" => Psan,
      "Porg" => 0.055,
      "Kfc" => 0.2,
      "Phy" => 10000.0,
      "color_class" => 0,
  );

  data["urban"] =
      Dict{String,Any}("alb" => 0.15, "e_sur" => 0.92, "BuildH" => 12.0, "In_max_urb" => 5.0)

  data["vegetation"] = Dict{String,Any}(
      "gcI" => 3.7,
      "KcI" => 0.06,
      "Kct" => 0.75,
      "Sllit" => 2.0,
      "Oa" => 210000.0,
  );

  data["vegetation"]["high"] = Dict{String,Any}(
      "ZRmax" => [NaN64],
      "ZR50" => [NaN64],
      "Knit" => [0.2],
      "mSl" => [0.0],
      "FI" => [0.081],
      "Do" => [1000.0],
      "a1" => [7.0],
      "go" => [0.01],
      "CT" => [3],
      "DSE" => [0.649],
      "Ha" => [72.0],
      "gmes" => [Inf64],
      "rjv" => [1.97],
      "Vmax" => [0.0],
      "Psi_sto_00" => [-0.5],
      "Psi_sto_50" => [-2.0],
      "PsiL00" => [-2.7],
      "PsiL50" => [-5.6],
      "PsiX50" => [-3.5],
      "Kleaf_max" => [5.0],
      "Cl" => [1200.0],
      "Axyl" => [15.0],
      "Kx_max" => [80000.0],
      "Cx" => [150.0],
      "Sl" => [0.016],
      "Osm_reg_Max" => [0.0],
      "eps_root_base" => [0.9],
      "d_leaf" => [3.5],
      "Sp_LAI_In" => [0.2],
      "OM" => [1.0],
      "PFT_Class" => [0],
  );

  data["vegetation"]["low"] = Dict{String,Any}(
      "ZRmax" => [NaN64],
      "ZR50" => [NaN64],
      "Knit" => [0.15],
      "mSl" => [0.0],
      "FI" => [0.081],
      "Do" => [1000.0],
      "a1" => [6.0],
      "go" => [0.01],
      "CT" => [3],
      "DSE" => [0.656],
      "Ha" => [55.0],
      "gmes" => [Inf64],
      "rjv" => [2.4],
      "Vmax" => [96.0],
      "Psi_sto_00" => [-0.5],
      "Psi_sto_50" => [-3.0],
      "PsiL00" => [-0.9],
      "PsiL50" => [-4.0],
      "PsiX50" => [-4.5],
      "Kleaf_max" => [5.0],
      "Cl" => [1200.0],
      "Axyl" => [0.0],
      "Kx_max" => [80000.0],
      "Cx" => [150.0],
      "Sl" => [0.035],
      "Osm_reg_Max" => [0.0],
      "eps_root_base" => [0.9],
      "d_leaf" => [0.8],
      "Sp_LAI_In" => [0.2],
      "OM" => [1.0],
      "PFT_Class" => [13],
  );

  data["vegetationdynamics"] = Dict{String,Any}(
      "high" => [
          Dict{String,Any}(
              "Sl" => 0.016,
              "mSl" => 0.0,
              "r" => 0.030,
              "gR" => 0.25,
              "LtR" => 1.0,
              "eps_ac" => 1.0,
              "aSE" => 1,
              "Trr" => 3.5,
              "dd_max" => 1/365,
              "dc_C" => 2/365,
              "Tcold" => 7.0,
              "drn" => 1/1095,
              "dsn" => 1/365,
              "age_cr" => 150.0,
              "Bfac_lo" => 0.95,
              "Bfac_ls" => NaN64,
              "Tlo" => 12.9,
              "Tls" => NaN64,
              "mjDay" => 180,
              "LDay_min" => 11.0,
              "dmg" => 35.0,
              "Mf" => 1/50,
              "Wm" => 1/16425,
              "LAI_min" => 0.01,
              "LDay_cr" => 12.30,
              "PsiG50" => -0.45,
              "PsiG99" => -1.2,
              "gcoef" => 3.5,
              "Klf" => 1/15,
              "fab" => 0.74,
              "fbe" => 0.26,
              "ff_r" => 0.1,
              "PAR_th" => NaN64,
              "PsiL50" => -5.6,
              "PsiL00" => -2.7,
              "Nl" => 30.0,
          ),
      ],
      "low" => [
          Dict{String,Any}(
              "Sl" => 0.035,
              "mSl" => 0.0,
              "r" => 0.06,
              "gR" => 0.25,
              "LtR" => 0.35,
              "eps_ac" => 0.2,
              "aSE" => 2,
              "Trr" => 2.0,
              "dd_max" => 1/45,
              "dc_C" => 7/365,
              "Tcold" => -2.0,
              "drn" => 1/450,
              "dsn" => 1/365,
              "age_cr" => 180.0,
              "Bfac_lo" => 0.99,
              "Bfac_ls" => -7.0,
              "Tlo" => 0.0,
              "Tls" => NaN64,
              "mjDay" => 250,
              "LDay_min" => 10.7,
              "dmg" => 20.0,
              "Mf" => 1/50,
              "Wm" => 0.0,
              "LAI_min" => 0.1,
              "LDay_cr" => 10.7,
              "PsiG50" => -3.0,
              "PsiG99" => -4.0,
              "gcoef" => 3.5,
              "fab" => 0.0,
              "fbe" => 1.0,
              "Klf" => 1/50,
              "ff_r" => 0.1,
              "PAR_th" => NaN64,
              "PsiL50" => -4.0,
              "PsiL00" => -0.9,
              "Nl" => 23.0,
          ),
      ],
  );

  data["vegetationmanagement"] = Dict{String,Any}(
      "high" => [
          Dict{String,Any}(
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
          ),
      ],
  );
  data["vegetationmanagement"]["low"] = [Dict{String,Any}()];
  data["vegetationmanagement"]["low"][1] = copy(data["vegetationmanagement"]["high"][1]);
  data["vegetationmanagement"]["low"][1]["jDay_cut"] = [125, 156, 186, 217, 247, 278];
  data["vegetationmanagement"]["low"][1]["LAI_cut"] = 1.68;

  data["exudation"] = Dict{String,Any}(
      "high" => [Dict{String,Any}("bfix" => false)],
      "low" => [Dict{String,Any}("bfix" => false)],
  );

  return data
end

"""
  save_parameters(data::AbstractDict, filepath::AbstractString)

  Saves the given parameters data to a YAML file at tyhe specified filepath.

  # Arguments
  - `data::AbstractDict`: A dictionary containing the parameters to be saved.
  - `filepath::AbstractString`: The path where the YAML file will be saved.
"""
function save_parameters(data::AbstractDict, filepath::AbstractString)
  write_file(filepath, data)

  return nothing
end

"""
  prepare_netcdf(input_data_path, ca_data_path, filepath; ZR95_L = [250.0], Pre_frac = 1.0)

  Prepares a NetCDF file with the necessary structure and variables for the Tethys-Chloris model.
  It reads the input meteorological data and atmospheric CO2 concentration data from the specified paths,
  processes them, and saves them in a NetCDF format at the given filepath.

  # Arguments
  - `input_data_path::AbstractString`: Path to the input meteorological data in .mat format.
  - `ca_data_path::AbstractString`: Path to the atmospheric CO2 concentration data in .mat format.
  - `filepath::AbstractString`: Path where the prepared NetCDF file will be saved.
  - `ZR95_L::Vector{Float64}`: Optional vector specifying the ZR95 parameter for low vegetation. Default is [250.0].
  - `Pre_frac::Float64`: Optional scaling factor for the precipitation data. Default is 1.0.

"""
function prepare_netcdf(
  input_data_path::AbstractString,
  ca_data_path::AbstractString,
  filepath::AbstractString;
  ZR95_L::Vector{Float64} = [250.0],
  Pre_frac::Float64 = 1.0,
)
  FT = Float64

  input_data = matread(input_data_path)

  start_time = 1
  end_time = 87648

  input_data = process_data(input_data, start_time, end_time)
  Datam = datevec(input_data["Date"])

  ca_data = matread(ca_data_path)
  ca_data["Date_CO2"] = vec(ca_data["Date_CO2"])

  Zs = FT.([0, 10, 20, 50, 100, 150, 200, 300, 400, 500, 600, 800, 1000, 1300])

  n_layers = length(Zs) - 1

  isfile(filepath) && rm(filepath)

  NCDataset(filepath, "c") do ds

    high_vegetation = defGroup(ds, "high_vegetation")
    low_vegetation = defGroup(ds, "low_vegetation")

    hours = 1:length(Datam)
    defDim(ds, "hours", length(hours))
    defVar(ds, "hours", hours, ("hours",))
    defVar(ds, "datetime", Datam, ("hours",))

    defDim(ds, "crownareas", 1)
    defVar(ds, "crownareas", [1], ("crownareas",))

    defDim(ds, "carbonpools", 8)
    defVar(ds, "carbonpools", 1:8, ("carbonpools",))

    defDim(ds, "nutrient", 3)
    nutr = defVar(ds, "nutrient", ["N", "P", "K"], ("nutrient",))

    defDim(ds, "layers", length(Zs))
    defDim(ds, "layerbelowsurface", n_layers)

    defDim(ds, "biogeochemistrypools", 55)

    ### Forcing inputs
    defVar(ds, "Zs", Zs, ("layers",))

    # ForcingInputs - Meteorological inputs
    defVar(ds, "Pr", input_data["Pr"][hours], ("hours",))
    defVar(ds, "Ta", input_data["Ta"][hours], ("hours",))
    defVar(ds, "Ws", input_data["Ws"][hours], ("hours",))
    defVar(ds, "ea", input_data["ea"][hours], ("hours",))
    defVar(ds, "SAD1", input_data["SAD1"][hours], ("hours",))
    defVar(ds, "SAD2", input_data["SAD2"][hours], ("hours",))
    defVar(ds, "SAB1", input_data["SAB1"][hours], ("hours",))
    defVar(ds, "Pre", input_data["Pre"][hours] * Pre_frac, ("hours",))
    defVar(ds, "SAB2", input_data["SAB2"][hours], ("hours",))
    defVar(ds, "N", input_data["Latm"][hours], ("hours",)) # TODO: explain why this is happening
    defVar(ds, "Tdew", input_data["Tdew"][hours], ("hours",))
    defVar(ds, "esat", input_data["esat"][hours], ("hours",))
    defVar(ds, "PARB", input_data["PARB"][hours], ("hours",))
    defVar(ds, "PARD", input_data["PARD"][hours], ("hours",))

    Ds = max.(input_data["esat"][hours] - input_data["ea"][hours], 0)
    defVar(ds, "Ds", Ds, ("hours",))

    date_index = finddate(ca_data, input_data["Date"], start_time)
    Ca = vec(ca_data["Ca"][date_index:finddate(ca_data, input_data["Date"], end_time)])
    defVar(ds, "Ca", Ca, ("hours",))

    # ForcingInputs - Anthropogenic inpus
    # Both inputs are optional and should be created if missing

    ### Initial conditions

    # Hydrologic state variables

    ## Height-dependent state variables - high vegetation

    defVar(high_vegetation, "Ci_sun", [Ca[1]], ("crownareas",))
    defVar(high_vegetation, "Ci_shd", [Ca[1]], ("crownareas",))
    defVar(high_vegetation, "In", [0.0], ("crownareas",))

    ## Height-dependent state variables - low vegetation

    defVar(low_vegetation, "Ci_sun", [Ca[1]], ("crownareas",))
    defVar(low_vegetation, "Ci_shd", [Ca[1]], ("crownareas",))
    defVar(low_vegetation, "In", [0.0], ("crownareas",))

    ## Shared variables
    defVar(ds, "SWE", 0.0, ())
    defVar(ds, "SND", 0.0, ())
    defVar(ds, "Ts", input_data["Ta"][1] + 2.0, ())
    defVar(ds, "Tdamp", 15.0, ())
    defVar(ds, "In_urb", 0.0, ())
    defVar(ds, "In_rock", 0.0, ())
    defVar(ds, "SP_wc", 0.0, ())
    defVar(ds, "In_Litter", 0.0, ())
    defVar(ds, "In_SWE", 0.0, ())
    defVar(ds, "ros", 0.0, ())
    defVar(ds, "t_sls", 0.0, ())
    defVar(ds, "e_sno", 0.97, ())
    defVar(ds, "tau_sno", 0.0, ())
    defVar(ds, "EK", 0.0, ())
    defVar(ds, "WAT", 0.0, ())
    defVar(ds, "ICE", 0.0, ())
    defVar(ds, "IP_wc", 0.0, ())
    defVar(ds, "ICE_D", 0.0, ())
    defVar(ds, "FROCK", 0.0, ())
    defVar(ds, "Ws_under", 1.0, ())

    Tdp = 15 * ones(FT, n_layers)
    defVar(ds, "Tdp", Tdp, ("layerbelowsurface",))

    # Height-dependent auxiliary variables - high vegetation
    defVar(high_vegetation, "Rrootl", [0.0], ("crownareas",))

    # Height-dependent state variables - high vegetation
    defVar(high_vegetation, "LAI", [0.0], ("crownareas",))
    defVar(high_vegetation, "PHE_S", [0], ("crownareas",))
    defVar(high_vegetation, "dflo", [0.0], ("crownareas",))
    defVar(high_vegetation, "AgeL", [0.0], ("crownareas",))
    defVar(high_vegetation, "e_rel", [0.0], ("crownareas",))
    defVar(high_vegetation, "hc", [0.0], ("crownareas",))
    defVar(high_vegetation, "SAI", [0.0], ("crownareas",))
    defVar(high_vegetation, "Nreserve", [0.0], ("crownareas",))
    defVar(high_vegetation, "Preserve", [0.0], ("crownareas",))
    defVar(high_vegetation, "Kreserve", [0.0], ("crownareas",))
    defVar(high_vegetation, "FNC", [1.0], ("crownareas",))
    defVar(high_vegetation, "Vx", [0.0], ("crownareas",))
    defVar(high_vegetation, "Vl", [0.0], ("crownareas",))
    defVar(high_vegetation, "TBio", [0.0], ("crownareas",))
    defVar(high_vegetation, "TdpI", [2.0], ("crownareas",))

    defVar(high_vegetation, "B", zeros(FT, 8), ("carbonpools",))

    defVar(high_vegetation, "NupI", zeros(FT, 3), ("nutrient",))

    # Height-dependent auxiliary variables - low vegetation
    defVar(low_vegetation, "Rrootl", [4250.0], ("crownareas",))

    # Height-dependent state variables - low vegetation
    defVar(low_vegetation, "PHE_S", [3], ("crownareas",))
    defVar(low_vegetation, "dflo", [0.0], ("crownareas",))
    defVar(low_vegetation, "AgeL", [115.0], ("crownareas",))
    defVar(low_vegetation, "e_rel", [1.0], ("crownareas",))
    defVar(low_vegetation, "hc", [0.05], ("crownareas",))
    defVar(low_vegetation, "SAI", [0.001], ("crownareas",))
    defVar(low_vegetation, "LAI", [0.96], ("crownareas",))
    defVar(low_vegetation, "Vx", [0.0], ("crownareas",))
    defVar(low_vegetation, "Vl", [100.0], ("crownareas",))
    defVar(low_vegetation, "TBio", [1.0], ("crownareas",))
    defVar(low_vegetation, "TdpI", [2.0], ("crownareas",))
    defVar(low_vegetation, "ZR95", ZR95_L, ("crownareas",))
    defVar(
        low_vegetation,
        "B",
        [29.0, 0.0, 445.0, 320.0, 0.0, 0.0, 29.0, 0.0],
        ("carbonpools",),
    )

    # Biogeochemistry auxiliary variables
    defVar(ds, "BLit", [0.0], ("crownareas",))
    defVar(low_vegetation, "Nreserve", [1000.0], ("crownareas",))
    defVar(low_vegetation, "Preserve", [1000.0], ("crownareas",))
    defVar(low_vegetation, "Kreserve", [1000.0], ("crownareas",))
    defVar(low_vegetation, "FNC", [1.0], ("crownareas",))
    defVar(low_vegetation, "NupI", zeros(FT, 3), ("nutrient",))
    defVar(ds, "RexmyI", zeros(FT, 3), ("nutrient",))
  end

  return nothing
end
