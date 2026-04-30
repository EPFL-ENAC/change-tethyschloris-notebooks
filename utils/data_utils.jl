using Dates

"""
    process_data(x::Dict, start_time::Int, end_time::Int)

Process input data dictionary by slicing arrays to the specified time range.

# Arguments
- `x`: Input data dictionary with time series arrays
- `start_time`: Start time index
- `end_time`: End time index

# Returns
- The input dictionary with array values trimmed to the specified range
"""
function process_data(x::Dict, start_time::Int, end_time::Int)
    result = copy(x)
    for key in keys(result)
        if isa(result[key], AbstractArray)
            result[key] = result[key][start_time:end_time]
        end
    end

    return result
end

"""
    datevec(serial_dates::Vector{Float64})

Convert MATLAB serial dates to Julia DateTime objects.

# Arguments
- `serial_dates`: Vector of MATLAB serial dates

# Returns
- Vector of DateTime objects corresponding to the input MATLAB serial dates
"""
function datevec(serial_dates::Vector{Float64})
    # MATLAB date origin (year 0000)
    matlab_epoch = DateTime(0, 1, 1)

    days = floor.(Int, serial_dates)
    frac_days = serial_dates .- days
    p = 24 * 60 * 60 * 1000
    result = matlab_epoch + Day.(days .- 1) + Millisecond.(round.(Int, frac_days .* p))

    return result
end

"""
    ensure_data_directory()

Create the data directory if it doesn't exist.

# Returns
- Path to the data directory
"""
function ensure_data_directory()
    data_dir = joinpath(@__DIR__, "..", "data")
    !isdir(data_dir) && mkdir(data_dir)
    return data_dir
end

"""
    download_input_files(files::Dict, data_dir::AbstractString)

Download necessary input files if they don't exist locally.

# Arguments
- `files`: Dictionary mapping file names to their URLs
- `data_dir`: Directory where files should be downloaded
"""
function download_input_files(files::Dict, data_dir::AbstractString)
    !isdir(data_dir) && mkpath(data_dir)

    for (file, url) in files
        filepath = joinpath(data_dir, file)
        if !isfile(filepath)
            @info "Downloading $file..."
            download(url, filepath)
        end
    end
end

"""
    download_input_files(files::Dict)

Download necessary input files if they don't exist locally.
Uses the old behavior for backwards compatibility (downloads to ../data relative to data_utils.jl).

# Arguments
- `files`: Dictionary mapping file names to their URLs
"""
function download_input_files(files::Dict)
    data_dir = ensure_data_directory()
    download_input_files(files, data_dir)
end

"""
    finddate(ca_data, input_data_date, index)

Find matching date index in CO2 data array.

# Arguments
- `ca_data`: CO2 data dictionary with Date_CO2 field
- `input_data_date`: Date field from input data
- `index`: Index in input data to match

# Returns
- Index in ca_data that matches the date
"""
function finddate(ca_data, input_data_date, index)
    return findfirst(abs.(ca_data["Date_CO2"] .- input_data_date[index]) .< 1/36)
end
