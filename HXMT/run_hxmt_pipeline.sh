#!/bin/bash

# Base directory
BASE_DIR="."

# Function to check if a file exists
file_exists() {
    local file=$1
    if [ ! -f "$file" ]; then
        echo "Error: $file not found."
        return 1
    fi
    return 0
}

# Function to run a command and log the output
run_command() {
    local cmd=$1
    local log_file=$2
    echo "Running: $cmd" | tee -a "$log_file"
    eval "$cmd" 2>&1 | tee -a "$log_file"
}

# Function to process an exposure
process_exposure() {
    local exposure=$1
    local obs_dir=$2

    # Find the HE and AUX directories (searches recursively)
    local exposure_sub
    exposure_sub=$(find "$exposure" -type d -name "HE" | head -n 1)
    
    local aux_dir
    aux_dir=$(find "$exposure" -type d -name "AUX" | head -n 1)
    
    if [ -z "$exposure_sub" ] || [ -z "$aux_dir" ]; then
        echo "Error: HE or AUX directory not found in $exposure."
        return 1
    fi

    # Extract OBS_ID and exposure identifier
    local obs_id=$(basename "$exposure" | cut -d'-' -f1)
    local exposure_id=$(basename "$(dirname "$exposure_sub")" | cut -d'-' -f1)

    # Name output folder
    local output_dir="$obs_dir/pipeline_output"
    mkdir -p "$output_dir"

    # Define log file inside the output directory with exposure-specific naming
    local log_file="$output_dir/${exposure_id}_full_process.log"
    touch "$log_file"
    
    # Define paths for input/output files
    local evt_file="$exposure_sub/HXMT_${obs_id}_HE-Evt_FFFFFF_V1_L1P.FITS"
    local temp_file="$exposure_sub/HXMT_${obs_id}_HE-TH_FFFFFF_V1_L1P.FITS"
    local hv_file="$exposure_sub/HXMT_${obs_id}_HE-HV_FFFFFF_V1_L1P.FITS"
    local dtime_file="$exposure_sub/HXMT_${obs_id}_HE-DTime_FFFFFF_V1_L1P.FITS"
    local ehk_file="$aux_dir/HXMT_${obs_id}_EHK_FFFFFF_V1_L1P.FITS"
    local att_file="$exposure/ACS/HXMT_${obs_id}_Att_FFFFFF_V1_L1P.FITS"
    
    # Define output file paths
    local pi_file="$output_dir/${exposure_id}_he_pi.fits"
    local gti_file="$output_dir/${exposure_id}_he_gti.fits"
    local screen_file="$output_dir/${exposure_id}_he_screen.fits"
    local pha_file="$output_dir/${exposure_id}_he_pha"
    local resp_file="$output_dir/${exposure_id}_he_resp.fits"
    local bkg_file="$output_dir/${exposure_id}_he_specbkg"

    if [[ "$exposure_id" == "P050419601901" ]]; then
        run_command "hpipeline -i $exposure  -o $output_dir --stem $exposure_id --hxbary --ephem='JPLEPH.DE430' --ra=40.92 --dec=61.43 --HE_LC_BINSIZE=0.05 --ME_LC_BINSIZE=0.05 --LE_LC_BINSIZE=0.05 --parallel"
    fi

}

process_observation() {
    local obs_dir=$1
    #local log_file="$obs_dir/output/he_process.log"

    mkdir -p "$obs_dir/pipeline_output"

    for exposure in "$obs_dir"/P*; do
        if [ -d "$exposure" ]; then
            process_exposure "$exposure" "$obs_dir"
        fi
    done
}

# Function to process each proposal
process_proposal() {
    local proposal=$1

    for obs_dir in "$proposal"/*; do
        if [ -d "$obs_dir" ]; then
            process_observation "$obs_dir"
        fi
    done
}

# Main execution
main() {
    for proposal in "$BASE_DIR"/P*; do
        if [ -d "$proposal" ]; then
            process_proposal "$proposal"
        fi
    done
}

# Run the main function
main
