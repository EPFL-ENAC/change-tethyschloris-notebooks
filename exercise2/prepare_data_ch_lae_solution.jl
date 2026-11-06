using MAT: matread
using Dates: DateTime
using YAML: write_file
using NCDatasets: NCDataset, defGroup, defDim, defVar

"""
    prepare_parameters(; timerange = [
        DateTime("2004-01-01T00:30:00"),
        DateTime("2014-12-31T23:30:00"),
    ])

Create the parameter dictionary for the CH-Lae case study. All site, soil,
snow, vegetation, vegetation-dynamics, and initial model settings are based on
the original `CH-Lae_data.jl` case definition.

The default `timerange` covers the complete CH-Lae forcing record. It may be
overridden when preparing a shorter forcing period.
"""
function prepare_parameters(;
    timerange = [
        DateTime("2004-01-01T00:30:00"),
        DateTime("2014-12-31T23:30:00"),
    ],
)
FT = Float64

  # ---------------------------------------------------------------------------
  # How to read the parameter dictionaries
  # ---------------------------------------------------------------------------
  # Depths are expressed in millimetres unless stated otherwise. Fractions are
  # dimensionless and normally range from 0 to 1. High and low refer to the
  # overstory and understory vegetation layers. Arrays contain one value per
  # crown area; NaN indicates that a parameter is unavailable or not used for
  # the selected configuration. Several secondary soil and optical properties
  # are derived by TethysChloris from the primary values supplied below.

  # Soil-layer interface depths [mm]. The differences between adjacent values
  # define the thicknesses of the 13 soil layers.
  # CH-Lae uses two crown areas in beech-fir order: index 1 is deciduous beech
  # and index 2 is evergreen fir. The same ordering is used by all parameter
  # arrays and by the two dictionaries inside vegetationdynamics["high"].
Zs = FT.([0, 10, 20, 50, 100, 150, 200, 300, 400, 500, 600, 800, 1000, 1300])
n_layers = length(Zs) - 1

data = Dict{String,Any}()

data["n_layers"] = n_layers

  # Cell and topographic properties
  # cellsize : nominal grid-cell size used in the area/contour-length terms
  # SvF      : sky-view factor [-]
  # SN       : stream identifier
  # Slo_top  : surface slope, dy/dx [-]
  # Ared     : fraction of the cell not occupied by rock [-]
  # aR       : vertical-to-horizontal hydraulic-conductivity anisotropy [-]
# Parameters - Cell properties
data["cell"] = Dict{String,Any}(
    "cellsize" => 1.0,
    "SvF" => 1.0,
    "SN" => 1.0,
    "Slo_top" => 0.0,
    "Ared" => 1.0,
    "aR" => 1.0,
)

  # Debris-cover properties (mainly relevant over glaciers or snow)
  # alb      : debris albedo [-]
  # e_sur    : debris surface emissivity [-]
  # lan      : debris thermal conductivity [W m^-1 K^-1]
  # rho      : debris density [kg m^-3]
  # cs       : debris specific heat capacity [J kg^-1 K^-1]
  # dbThick  : debris-layer thickness [m]; zero disables the debris layer
  # zom      : debris aerodynamic roughness length [m]
# Parameters - Debris cover parameters
data["debris"] = Dict{String,Any}(
    "alb" => 0.13,
    "e_sur" => 0.94,
    "lan" => 0.945,
    "rho" => 1496.0,
    "cs" => 948.0,
    "dbThick" => 0.0,
    "zom" => 0.016,
)

  # Simulation and spatial settings
  # Zs       : soil-layer interface depths [mm]
  # dt       : hydrologic model time step [s]
  # dtd      : vegetation-dynamics time step [day]
  # Lon/Lat  : site longitude and latitude [degrees]
  # DeltaGMT : local time offset from GMT [h]
  # t_bef/aft: time-window offsets used by the forcing/solar calculations
  # Zdes     : effective depth over which direct soil evaporation is distributed [mm]
  # Zinf     : effective depth over which infiltration enters the soil [mm]
  # Zbio     : biologically active soil depth [mm]
  # SPAR     : soil hydraulic formulation (1 = van Genuchten, 2 = Saxton-Rawls)
  # fpr      : precipitation-frequency/disaggregation factor [-]
  # CASE_ROOT: root-profile formulation selector
  # zatm     : meteorological measurement/reference height [m]
  # timerange: first and last timestamp represented by the forcing record
data["simulation"] = Dict{String,Any}(
    "Zs" => Zs,
    "dt" => 3600,
    "dtd" => 1,
    "Lon" => 8.3644,
    "Lat" => 47.4783,
    "DeltaGMT" => 1,
    "t_bef" => 0.0,
    "t_aft" => 1.0,
    "Zdes" => 10.0,
    "Zinf" => 10.0,
    "Zbio" => 250.0,
    "SPAR" => 2,
    "fpr" => 1.0,
    "CASE_ROOT" => 1,
    "zatm" => 49.0,
    "timerange" => timerange,
)

  # Land-cover fractions [-]. Cbare, Cwat, Curb, Crock, and the sum of Ccrown
  # must add to one. Ccrown contains one fraction for each vegetation crown area.
  # Cbare: bare soil; Cwat: open water; Curb: impervious/urban surface;
  # Crock: exposed rock; Ccrown: vegetated crown fractions.
data["landcover"] = Dict{String,Any}(
    "Cbare" => 0.0,
    "Cwat" => 0.0,
    "Curb" => 0.0,
    "Crock" => 0.0,
    "Ccrown" => [0.55, 0.45],
)

  # Rock/bedrock properties
  # Kbot       : hydraulic conductivity at the soil-bedrock interface [mm h^-1]
  # Krock      : fractured-rock hydraulic conductivity [mm h^-1]
  # In_max_rock: maximum water interception storage on exposed rock [mm]
data["rock"] = Dict{String,Any}("Kbot" => NaN64, "Krock" => NaN64, "In_max_rock" => 0.1)

  # Snow and ice parameters
  # TminS/TmaxS: lower/upper air-temperature thresholds for precipitation phase [degC]
  # WatFreez_Th: threshold for freezing open water [degC]
  # dz_ice     : ice/freezing-layer growth rate [mm h^-1]
  # Th_Pr_sno  : snowfall-intensity threshold used to identify new snow
  # ros_max1/2 : empirical maximum snow-density parameters [kg m^-3]
  # Ice_wc_sp  : maximum specific liquid-water content of ice [-]
  # ros_ice_thr: snow-density threshold for conversion to ice [kg m^-3]
  # Aice       : ice albedo [-]
  # dir/dif_vis/nir: initial direct/diffuse visible and near-infrared albedos [-]
  # Sp_SN_In   : snow interception capacity per unit leaf area [mm LAI^-1]
data["snowice"] = Dict{String,Any}(
    "TminS" => -0.7,
    "TmaxS" => 2.8,
    "WatFreez_Th" => -8.0,
    "dz_ice" => 0.54,
    "Th_Pr_sno" => 8.0,
    "ros_max1" => 580.0,
    "ros_max2" => 300.0,
    "Ice_wc_sp" => 0.01,
    "ros_ice_thr" => 500.0,
    "Aice" => 0.28,
    "dir_vis" => 0.2,
    "dif_vis" => 0.2,
    "dir_nir" => 0.2,
    "dif_nir" => 0.2,
    "Sp_SN_In" => 5.9,
)

  # Primary soil-texture parameters used to derive the hydraulic and thermal properties
  # Pcla       : clay mass fraction [-]
  # Psan       : sand mass fraction [-]
  # Porg       : soil organic-matter fraction [-]
  # Kfc        : hydraulic conductivity used to define field capacity [mm h^-1]
  # Phy        : matric-potential magnitude at the hygroscopic water content [kPa]
  # color_class: soil colour class used by the surface-radiation parameterization
data["soil"] = Dict{String,Any}(
    "Pcla" => 0.11,
    "Psan" => 0.8,
    "Porg" => 0.055,
    "Kfc" => 0.2,
    "Phy" => 10000.0,
    "color_class" => 0,
)

  # Urban/impervious-surface properties
  # alb: albedo [-]; e_sur: emissivity [-]; BuildH: building height [m];
  # In_max_urb: maximum interception storage of the impervious surface [mm].
data["urban"] =
    Dict{String,Any}("alb" => 0.15, "e_sur" => 0.92, "BuildH" => 12.0, "In_max_urb" => 5.0)

  # Vegetation parameters shared by the high and low vegetation layers
  # gcI  : canopy-interception evaporation parameter [mm^-1]
  # KcI  : canopy-interception drainage coefficient [mm]
  # Kct  : foliage-cover decay factor controlling throughfall [-]
  # Sllit: specific leaf area of litter [m2 litter kg^-1 dry matter]
  # Oa   : atmospheric/intercellular oxygen concentration [umol mol^-1]
data["vegetation"] = Dict{String,Any}(
    "gcI" => 3.7,
    "KcI" => 0.06,
    "Kct" => 0.75,
    "Sllit" => 2.0,
    "Oa" => 210000.0,
)

  # Height-dependent vegetation, photosynthesis, and plant-hydraulic parameters
  # ZRmax/ZR50 : maximum and 50%-cumulative rooting depths [mm]
  # Knit       : vertical canopy-nitrogen decay coefficient [-]
  # mSl        : change in specific leaf area with LAI
  # FI         : intrinsic quantum efficiency [umol CO2 umol^-1 photons]
  # Do         : vapour-pressure-deficit sensitivity of stomatal conductance [Pa]
  # a1         : coupling coefficient between assimilation and stomatal conductance
  # go         : minimum stomatal conductance [mol m^-2 s^-1]
  # CT         : photosynthesis pathway selector (3 = C3, 4 = C4)
  # DSE/Ha     : activation-energy and entropy terms for temperature response [kJ mol^-1]
  # gmes       : mesophyll conductance [mol CO2 m^-2 s^-1]
  # rjv        : Jmax-to-Vmax scaling factor [-]
  # Vmax       : maximum Rubisco capacity at 25 degC [umol CO2 m^-2 s^-1]
  # Psi_sto_00/50: water potentials at onset and 50% stomatal closure [MPa]
  # PsiL00/50  : leaf water potentials at 2% and 50% conductivity loss [MPa]
  # PsiX50     : xylem water potential at 50% conductivity loss [MPa]
  # Kleaf_max  : maximum leaf hydraulic conductivity
  # Cl/Cx      : leaf and stem hydraulic capacitances
  # Axyl       : xylem cross-sectional area per unit plant-functional-type area
  # Kx_max     : maximum xylem hydraulic conductivity
  # Sl         : specific leaf area [m2 leaf gC^-1]
  # Osm_reg_Max: maximum osmotic-regulation potential
  # eps_root_base: root filtration efficiency (used for mangrove applications)
  # d_leaf     : characteristic leaf dimension [cm]
  # Sp_LAI_In  : rainfall interception capacity per unit LAI [mm LAI^-1]
  # OM         : canopy clumping factor [-]
  # PFT_Class  : plant-functional-type class used to obtain optical properties
data["vegetation"]["high"] = Dict{String,Any}(
    "ZRmax" => [NaN64, NaN64],
    "ZR50" => [NaN64, NaN64],
    "Knit" => [0.35, 0.20],
    "mSl" => [0.0, 0.0],
    "FI" => [0.081, 0.081],
    "Do" => [1000.0, 1000.0],
    "a1" => [8.0, 6.0],
    "go" => [0.01, 0.01],
    "CT" => [3, 3],
    "DSE" => [0.649, 0.649],
    "Ha" => [76.0, 72.0],
    "gmes" => [Inf64, Inf64],
    "rjv" => [2.2, 2.0],
    "Vmax" => [70.0, 50.0],
    "Psi_sto_00" => [-0.5, -0.5],
    "Psi_sto_50" => [-2.2, -2.5],
    "PsiL00" => [-1.0, -1.0],
    "PsiL50" => [-3.0, -3.2],
    "PsiX50" => [-4.5, -5.5],
    "Kleaf_max" => [10.0, 10.0],
    "Cl" => [1200.0, 1200.0],
    "Axyl" => [15.0, 15.0],
    "Kx_max" => [80000.0, 80000.0],
    "Cx" => [150.0, 150.0],
    "Sl" => [0.024, 0.012],
    "Osm_reg_Max" => [0.0, 0.0],
    "eps_root_base" => [0.9, 0.9],
    "d_leaf" => [4.0, 0.25],
    "Sp_LAI_In" => [0.2, 0.1],
    "OM" => [1.0, 1.0],
    "PFT_Class" => [7, 1],
)

data["vegetation"]["low"] = Dict{String,Any}(
    "ZRmax" => [NaN64, NaN64],
    "ZR50" => [NaN64, NaN64],
    "Knit" => [0.0, 0.0],
    "mSl" => [0.0, 0.0],
    "FI" => [0.04, 0.04],
    "Do" => [1800.0, 1800.0],
    "a1" => [6.0, 6.0],
    "go" => [0.01, 0.01],
    "CT" => [4, 4],
    "DSE" => [0.649, 0.649],
    "Ha" => [72.0, 72.0],
    "gmes" => [Inf64, Inf64],
    "rjv" => [2.1, 2.1],
    "Vmax" => [0.0, 0.0],
    "Psi_sto_00" => [-0.5, -0.5],
    "Psi_sto_50" => [-1.6, -1.6],
    "PsiL00" => [-1.0, -1.0],
    "PsiL50" => [-2.0, -2.0],
    "PsiX50" => [-10.0, -10.0],
    "Kleaf_max" => [5.0, 5.0],
    "Cl" => [1200.0,1200.0],
    "Axyl" => [6.0, 6.0],
    "Kx_max" => [80000.0, 80000.0],
    "Cx" => [150.0, 150.0],
    "Sl" => [0.020, 0.020],
    "Osm_reg_Max" => [0.0, 0.0],
    "eps_root_base" => [0.9,0.9],
    "d_leaf" => [0.0, 0.0],
    "Sp_LAI_In" => [0.2, 0.2],
    "OM" => [1.0, 1.0],
    "PFT_Class" => [0, 0],
)

  # Vegetation-dynamics and phenology parameters (one dictionary per crown area)
  # Sl/mSl   : specific leaf area and its LAI-dependent slope
  # r        : maintenance-respiration rate at 10 degC [gC gN^-1 day^-1]
  # gR       : fraction of assimilated carbon used by growth respiration [-]
  # LtR      : maximum leaf-to-root allocation ratio [-]
  # eps_ac   : allocation-to-carbohydrate-reserve parameter [-]
  # aSE      : plant type (0 evergreen, 1 seasonal, 2 grass, 3 crop)
  # Trr      : reserve translocation rate [gC m^-2 day^-1]
  # dd_max   : maximum drought-driven mortality rate [day^-1]
  # dc_C     : cold-driven mortality coefficient
  # Tcold    : cold leaf-shedding threshold [degC]
  # drn/dsn  : fine-root and sapwood turnover rates [day^-1]
  # age_cr   : critical leaf age [day]
  # Bfac_lo/ls: water-stress thresholds for leaf onset/shedding [-]
  # Tlo/Tls  : mean-temperature thresholds for leaf onset/shedding [degC]
  # mjDay    : latest Julian day allowed for leaf onset
  # LDay_min : minimum day length for leaf onset [h]
  # dmg      : day of maximum growth
  # Mf/Wm    : fruit-maturation and wood-turnover rates [day^-1]
  # LAI_min  : minimum retained leaf area index [-]
  # LDay_cr  : day-length threshold for senescence [h]
  # PsiG50/99: water potentials at 50% and 99% growth reduction [MPa]
  # gcoef    : maximum growth-rate coefficient [gC m^-2 day^-1]
  # Klf      : turnover/fall rate of dead leaves [day^-1]
  # fab/fbe  : above- and below-ground sapwood/reserve fractions [-]
  # ff_r     : reference allocation fraction to fruits/reproduction [-]
  # PAR_th   : photosynthetically active radiation threshold
  # PsiL00/50: leaf-hydraulic vulnerability thresholds [MPa]
  # Nl       : leaf carbon-to-nitrogen ratio [gC gN^-1]
data["vegetationdynamics"] = Dict{String,Any}(
    "high" => [
        Dict{String,Any}(
            "Sl" => 0.024,
            "mSl" => 0.0,
            "r" => 0.028,
            "gR" => 0.25,
            "LtR" => 0.50,
            "eps_ac" => 1.0,
            "aSE" => 1,
            "Trr" => 5.0,
            "dd_max" => 1 / 100,
            "dc_C" => 36 / 365,
            "Tcold" => 3.5,
            "drn" => 1 / 1200,
            "dsn" => 1 / 1000,
            "age_cr" => 120.0,
            "Bfac_lo" => 0.95,
            "Bfac_ls" => NaN64,
            "Tlo" => 3.0,
            "Tls" => NaN64,
            "mjDay" => 250,
            "LDay_min" => 12.8,
            "dmg" => 30.0,
            "Mf" => 1 / 80,
            "Wm" => 0.0,
            "LAI_min" => 0.01,
            "LDay_cr" => 10.8,
            "PsiG50" => -0.5,
            "PsiG99" => -2.2,
            "gcoef" => 4.5,
            "Klf" => 1 / 28,
            "fab" => 0.74,
            "fbe" => 0.26,
            "ff_r" => 0.1,
            "PAR_th" => NaN64,
            "PsiL50" => -3.0,
            "PsiL00" => -1.0,
            "Nl" => 28.0,
        ),
        Dict{String,Any}(
            "Sl" => 0.012,
            "mSl" => 0.0,
            "r" => 0.058,
            "gR" => 0.25,
            "LtR" => 0.8,
            "eps_ac" => 0.25,
            "aSE" => 0,
            "Trr" => 0.25,
            "dd_max" => 1 / 150,
            "dc_C" => 78 / 365,
            "Tcold" => -30.0,
            "drn" => 1 / 1000,
            "dsn" => 1 / 1000,
            "age_cr" => 1000.0,
            "Bfac_lo" => 0.99,
            "Bfac_ls" => NaN64,
            "Tlo" => 4.2,
            "Tls" => NaN64,
            "mjDay" => 220,
            "LDay_min" => 12.4,
            "dmg" => 30.0,
            "Mf" => 1 / 80,
            "Wm" => 0.0,
            "LAI_min" => 0.001,
            "LDay_cr" => 11.0,
            "PsiG50" => -0.5,
            "PsiG99" => -2.5,
            "gcoef" => 4.5,
            "Klf" => 1 / 40,
            "fab" => 0.74,
            "fbe" => 0.26,
            "ff_r" => 0.1,
            "PAR_th" => NaN64,
            "PsiL50" => -3.2,
            "PsiL00" => -1.0,
            "Nl" => 40.0,
        ),
    ],
    "low" => [
        Dict{String,Any}(
            "Sl" => 0.020,
            "mSl" => 0.0,
            "r" => 0.050,
            "gR" => 0.25,
            "LtR" => 0.25,
            "eps_ac" => 1.0,
            "aSE" => 2,
            "Trr" => 3.5,
            "dd_max" => 1/12,
            "dc_C" => 7/365,
            "Tcold" => 2.0,
            "drn" => 1/650,
            "dsn" => 1/365,
            "age_cr" => 150.0,
            "Bfac_lo" => 0.95,
            "Bfac_ls" => NaN64,
            "Tlo" => 8.0,
            "Tls" => NaN64,
            "mjDay" => -1,
            "LDay_min" => 10.2,
            "dmg" => 20.0,
            "Mf" => 1/50,
            "Wm" => 0.0,
            "LAI_min" => 0.05,
            "LDay_cr" => 10.6,
            "PsiG50" => -1.6,
            "PsiG99" => -2.0,
            "gcoef" => 3.5,
            "fab" => 0.0,
            "fbe" => 1.0,
            "Klf" => 1/20,
            "ff_r" => 0.1,
            "PAR_th" => NaN64,
            "PsiL50" => -2.0,
            "PsiL00" => -1.0,
            "Nl" => 28.0,
        ),
        Dict{String,Any}(
            "Sl" => 0.020,
            "mSl" => 0.0,
            "r" => 0.050,
            "gR" => 0.25,
            "LtR" => 0.25,
            "eps_ac" => 1.0,
            "aSE" => 2,
            "Trr" => 3.5,
            "dd_max" => 1/12,
            "dc_C" => 7/365,
            "Tcold" => 2.0,
            "drn" => 1/650,
            "dsn" => 1/365,
            "age_cr" => 150.0,
            "Bfac_lo" => 0.95,
            "Bfac_ls" => NaN64,
            "Tlo" => 8.0,
            "Tls" => NaN64,
            "mjDay" => -1,
            "LDay_min" => 10.0,
            "dmg" => 20.0,
            "Mf" => 1/50,
            "Wm" => 0.0,
            "LAI_min" => 0.05,
            "LDay_cr" => 10.6,
            "PsiG50" => -1.6,
            "PsiG99" => -2.0,
            "gcoef" => 3.5,
            "fab" => 0.0,
            "fbe" => 1.0,
            "Klf" => 1/20,
            "ff_r" => 0.1,
            "PAR_th" => NaN64,
            "PsiL50" => -2.0,
            "PsiL00" => -1.0,
            "Nl" => 28.0,
        ),
    ],
)
  # Vegetation-management parameters (one dictionary per crown area)
  # jDay_cut      : Julian days of cutting or grazing
  # LAI_cut       : LAI remaining after cutting/grazing
  # B_harv        : harvested biomass; -1 denotes complete harvest [gC m^-2]
  # fract_log     : fraction of above-ground biomass removed by logging
  # fire_eff      : fire-effect coefficient
  # funb_nit      : fraction of nitrogen left unburned
  # fract_girdling: fraction of vegetation affected by girdling
  # Crop_B        : initial crop biomass pools [gC m^-2]
  # Crop_crown    : crop crown-cover parameter
  # fract_resprout: below-ground fraction surviving and able to resprout
  # fract_left    : fraction of leaves/dead leaves left after disturbance
  # fract_left_fr : fraction of fruits left after disturbance
  # fract_left_AB/BG: fractions of above-/below-ground woody biomass left
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
)
data["vegetationmanagement"]["low"] = [Dict{String,Any}(), Dict{String,Any}()]
data["vegetationmanagement"]["low"][1] = copy(data["vegetationmanagement"]["high"][1])
data["vegetationmanagement"]["low"][2] = copy(data["vegetationmanagement"]["high"][2])

  # Root-exudation setting. bfix controls whether biological nitrogen fixation
  # is enabled for each high- and low-vegetation crown area.
data["exudation"] = Dict{String,Any}(
    "high" => [Dict{String,Any}("bfix" => false), Dict{String,Any}("bfix" => false)],
    "low" => [Dict{String,Any}("bfix" => false), Dict{String,Any}("bfix" => false)],
)
  # Soil-biogeochemistry controls
  # PH  : soil pH [-]
  # ExEM: ectomycorrhizal association/control parameter [-]
data["biogeochemistry"] = Dict{String,Any}("PH" => 5.0, "ExEM" => 0.0)

return data
end

"""
    save_parameters(data, filepath)

Save a Tethys-Chloris parameter dictionary as a YAML configuration file.
"""
function save_parameters(data::AbstractDict, filepath::AbstractString)
    write_file(filepath, data)
    return nothing
end

"""
    prepare_netcdf(input_data_path, ca_data_path, filepath;
                   start_time = 1, end_time = 96432)

Create the NetCDF forcing and initial-condition file for the CH-Lae case
study from the original meteorological MAT file and atmospheric CO2 MAT file.
The defaults retain the complete 96,432-hour CH-Lae record.
"""
function prepare_netcdf(
    input_data_path::AbstractString,
    ca_data_path::AbstractString,
    filepath::AbstractString;
    start_time::Int = 1,
    end_time::Int = 96432,
)
FT = Float64

input_data = matread(input_data_path)
input_data = process_data(input_data, start_time, end_time)
Datam = datevec(input_data["Date"])

ca_data = matread(ca_data_path)
ca_data["Date_CO2"] = vec(ca_data["Date_CO2"])

Zs = FT.([0, 10, 20, 50, 100, 150, 200, 300, 400, 500, 600, 800, 1000, 1300])
n_layers = length(Zs) - 1

isfile(filepath) && rm(filepath)

# -----------------------------------------------------------------------------
# NetCDF layout and variable guide
# -----------------------------------------------------------------------------
# Dimensions
# hours              : hourly forcing time steps
# crownareas          : vegetation crown areas represented at the site
# carbonpools         : 1 leaves, 2 sapwood, 3 fine roots, 4 live stemwood,
#                       5 fruits/flowers, 6 dead stemwood, 7 dead leaves,
#                       8 dead fruits
# nutrient            : nitrogen (N), phosphorus (P), and potassium (K)
# layers              : soil-layer interfaces; layerbelowsurface: soil layers
# biogeochemistrypools: pools required by the optional biogeochemistry module
#
# Meteorological forcing variables
# Zs   : soil-layer interface depths [mm]
# Pr   : precipitation [mm h^-1]
# Ta   : air temperature at the reference height [degC]
# Ws   : wind speed at the reference height [m s^-1]
# ea   : actual vapour pressure [kPa]
# SAD1/SAD2: diffuse incoming UV-visible / near-infrared radiation [W m^-2]
# SAB1/SAB2: direct incoming UV-visible / near-infrared radiation [W m^-2]
# Pre  : atmospheric pressure [hPa]
# N    : cloud fraction [0-1], or measured incoming longwave radiation [W m^-2]
#        when values exceed 1; TethysChloris detects the representation used
# Tdew : dew-point temperature [degC]
# esat : saturation vapour pressure [kPa]
# PARB/PARD: direct and diffuse photosynthetically active radiation [W m^-2]
# Ds   : non-negative vapour-pressure deficit, esat - ea [kPa]
# Ca   : atmospheric CO2 concentration [umol mol^-1]
#
# Hydrologic initial conditions
# Ci_sun/Ci_shd: internal CO2 of sunlit/shaded leaves [umol mol^-1]
# In       : canopy interception storage [mm]
# O        : liquid volumetric soil water content for each layer [-]
# SWE/SND  : snow water equivalent [mm] and snow depth [m]
# Ts/Tdamp : surface and soil damping-depth temperatures [degC]
# Tdp      : initial soil-temperature profile [degC]
# In_urb/In_rock/In_Litter/In_SWE: initial interception stores [mm]
# SP_wc    : snowpack liquid-water content [-]
# ros      : snow density [kg m^-3]
# t_sls    : time since the last snowfall [h]
# e_sno/tau_sno: snow emissivity and optical depth [-]
# EK       : rainfall kinetic-energy state [J m^-2 h^-1]
# WAT/ICE  : open-water and ice water-equivalent stores [mm]
# IP_wc    : impermeable-surface water content [-]
# ICE_D    : ice depth [m]
# FROCK    : initial rock-cover state/fraction [-]
# Ws_under : wind speed beneath the canopy [m s^-1]
#
# Vegetation initial conditions (defined separately for high and low layers)
# Rrootl : fine-root length index
# LAI/SAI: leaf and stem area indices [m2 m^-2]
# PHE_S  : phenological state (1 dormant, 2 maximum growth,
#          3 normal growth, 4 senescence)
# dflo   : days since leaf onset [day]
# AgeL   : mean leaf age [day]
# e_rel  : relative photosynthetic efficiency associated with leaf age [-]
# hc     : canopy height [m]
# Nreserve/Preserve/Kreserve: plant nutrient reserves [g nutrient m^-2]
# FNC    : nitrogen-stress factor [-]
# Vx/Vl  : xylem and leaf water stores [mm per m2 PFT]
# TBio   : standing vegetation biomass [ton dry matter ha^-1]
# TdpI   : running soil-temperature state used by vegetation dynamics [degC]
# ZR95   : depth containing 95% of the root system [mm]
# B      : eight initial vegetation carbon pools [gC m^-2]
# NupI   : initial integrated uptake of N, P, and K
# BLit   : litter biomass [kg dry matter m^-2]
# RexmyI : integrated root-exudation / mycorrhizal carbon terms [gC m^-2 day^-1]
NCDataset(filepath, "c") do ds

high_vegetation = defGroup(ds, "high_vegetation")
low_vegetation = defGroup(ds, "low_vegetation")

hours = 1:length(Datam)
defDim(ds, "hours", length(hours))
defVar(ds, "hours", hours, ("hours",))
defVar(ds, "datetime", Datam, ("hours",))

    defDim(ds, "crownareas", 2)
defVar(ds, "crownareas", [1, 2], ("crownareas",))

defDim(ds, "carbonpools", 8)
defVar(ds, "carbonpools", 1:8, ("carbonpools",))

defDim(ds, "nutrient", 3)
    defVar(ds, "nutrient", ["N", "P", "K"], ("nutrient",))

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
defVar(ds, "Pre", input_data["Pre"][hours], ("hours",))
defVar(ds, "SAB2", input_data["SAB2"][hours], ("hours",))
defVar(ds, "N", input_data["N"][hours], ("hours",))
defVar(ds, "Tdew", input_data["Tdew"][hours], ("hours",))
defVar(ds, "esat", input_data["esat"][hours], ("hours",))
defVar(ds, "PARB", input_data["PARB"][hours], ("hours",))
defVar(ds, "PARD", input_data["PARD"][hours], ("hours",))

Ds = max.(input_data["esat"][hours] - input_data["ea"][hours], 0)
defVar(ds, "Ds", Ds, ("hours",))

date_index = finddate(ca_data, input_data["Date"], start_time)
Ca = vec(ca_data["Ca"][date_index:finddate(ca_data, input_data["Date"], end_time)])
defVar(ds, "Ca", Ca, ("hours",))

# Forcing inputs - Anthropogenic inputs
# Both inputs are optional and should be created if missing

### Initial conditions

# Hydrologic state variables

## Height-dependent state variables - high vegetation

defVar(high_vegetation, "Ci_sun", [Ca[1], Ca[1]], ("crownareas",))
defVar(high_vegetation, "Ci_shd", [Ca[1], Ca[1]], ("crownareas",))
defVar(high_vegetation, "In", [0.0, 0.0], ("crownareas",))

## Height-dependent state variables - low vegetation

defVar(low_vegetation, "Ci_sun", [Ca[1], Ca[1]], ("crownareas",))
defVar(low_vegetation, "Ci_shd", [Ca[1], Ca[1]], ("crownareas",))
defVar(low_vegetation, "In", [0.0, 0.0], ("crownareas",))

## Shared variables
O = [
    0.3174,
    0.3180,
    0.3184,
    0.3189,
    0.3202,
    0.3221,
    0.3254,
    0.3291,
    0.3321,
    0.3344,
    0.3374,
    0.3398,
    0.3419,
]
defVar(ds, "O", O, ("layerbelowsurface",))


defVar(ds, "SWE", 0.0, ())
defVar(ds, "SND", 0.0, ())
defVar(ds, "Ts", input_data["Ta"][1] + 2.0, ())
defVar(ds, "Tdamp", 14.0, ())
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

Tdp = 0.0 * ones(FT, n_layers)
defVar(ds, "Tdp", Tdp, ("layerbelowsurface",))


# Height-dependent auxiliary variables - high vegetation
defVar(high_vegetation, "Rrootl", [4000, 3800], ("crownareas",))

# Height-dependent state variables - high vegetation
defVar(high_vegetation, "LAI", [0.0, 0.0], ("crownareas",))
defVar(high_vegetation, "PHE_S", [1, 1], ("crownareas",))
defVar(high_vegetation, "dflo", [0, 0], ("crownareas",))
defVar(high_vegetation, "AgeL", [0, 1003], ("crownareas",))
defVar(high_vegetation, "e_rel", [1.0, 1.0], ("crownareas",))
defVar(high_vegetation, "hc", [22.0, 22.0], ("crownareas",))
defVar(high_vegetation, "SAI", [0.2, 0.2], ("crownareas",))
defVar(high_vegetation, "Nreserve", [1000.0, 1000.0], ("crownareas",))
defVar(high_vegetation, "Preserve", [100.0, 100.0], ("crownareas",))
defVar(high_vegetation, "Kreserve", [1000.0, 1000.0], ("crownareas",))
defVar(high_vegetation, "FNC", [1.0, 1.0], ("crownareas",))
defVar(high_vegetation, "Vx", [10, 10], ("crownareas",))
defVar(high_vegetation, "Vl", [10, 10], ("crownareas",))
defVar(high_vegetation, "TBio", [200, 200], ("crownareas",))
defVar(high_vegetation, "TdpI", [input_data["Ta"][1] + 2.0, input_data["Ta"][1] + 2.0], ("crownareas",))
defVar(high_vegetation, "ZR95", [1000, 1000], ("crownareas",))
defVar(
    high_vegetation,
    "B",
    [
        0.0 694.0 412.0 489.0 10.0 0.0 0.4 0.0;
        516.0 1394.0 645.0 968.0 10.0 0.0 20.0 0.0
    ],
    ("crownareas", "carbonpools"),
)

defVar(high_vegetation, "NupI", zeros(FT, 2, 3), ("crownareas", "nutrient"))

# Height-dependent auxiliary variables - low vegetation
defVar(low_vegetation, "Rrootl", [4907, 5246], ("crownareas",))

# Height-dependent state variables - low vegetation
defVar(low_vegetation, "PHE_S", [3, 3], ("crownareas",))
defVar(low_vegetation, "dflo", [0.0, 27], ("crownareas",))
defVar(low_vegetation, "AgeL", [117.0, 16], ("crownareas",))
defVar(low_vegetation, "e_rel", [1, 1], ("crownareas",))
defVar(low_vegetation, "hc", [0, 0], ("crownareas",))
defVar(low_vegetation, "SAI", [0, 0], ("crownareas",))
defVar(low_vegetation, "LAI", [0, 0], ("crownareas",))
defVar(low_vegetation, "Nreserve", [1000.0, 1000.0], ("crownareas",))
defVar(low_vegetation, "Preserve", [1000.0, 1000.0], ("crownareas",))
defVar(low_vegetation, "Kreserve", [1000.0, 1000.0], ("crownareas",))
defVar(low_vegetation, "FNC", [1.0, 1.0], ("crownareas",))
defVar(low_vegetation, "Vx", [10, 10], ("crownareas",))
defVar(low_vegetation, "Vl", [10, 10], ("crownareas",))
defVar(low_vegetation, "TBio", [0, 0], ("crownareas",))
defVar(low_vegetation, "TdpI", [0, 0], ("crownareas",))
defVar(low_vegetation, "ZR95", [0, 0], ("crownareas",))
defVar(low_vegetation, "B", zeros(FT, 2, 8), ("crownareas", "carbonpools"))
defVar(low_vegetation, "NupI", zeros(FT, 2, 3), ("crownareas", "nutrient"))

# Biogeochemistry auxiliary variables
defVar(ds, "BLit", [0.0, 0.0], ("crownareas",))

defVar(ds, "RexmyI", zeros(FT, 3), ("nutrient",))

end

return nothing
end
