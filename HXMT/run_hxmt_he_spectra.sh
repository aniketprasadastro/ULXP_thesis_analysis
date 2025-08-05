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
    local log_file=$3

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
    local output_dir="$obs_dir/output"
    mkdir -p "$output_dir"

    # Define log file inside the output directory with exposure-specific naming
    local log_file="$output_dir/${exposure_id}_he_process.log"
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

    # # Step 1: Run hepical
    # if file_exists "$evt_file"; then
    #     run_command "hepical evtfile=$evt_file outfile=$pi_file clobber=YES seed=42" "$log_file"
    # fi

    # # Step 2: Run hegtigen
    # if file_exists "$hv_file" && file_exists "$temp_file" && file_exists "$ehk_file"; then
    #     run_command "hegtigen hvfile=$hv_file tempfile=$temp_file ehkfile=$ehk_file outfile=$gti_file defaultexpr=NONE expr=\"ELV>10&&COR>8&&SAA_FLAG==0&&ANG_DIST<0.04&&T_SAA>300&&TN_SAA>300\" " "$log_file"
    # fi

    # # Step 3: Run hescreen
    # if file_exists "$pi_file" && file_exists "$gti_file"; then
    #     run_command "hescreen evtfile=$pi_file gtifile=$gti_file outfile=$screen_file userdetid=\"0-17\"" "$log_file"
    # fi

    # # Step 4: Run hespecgen
    # if file_exists "$screen_file" && file_exists "$dtime_file"; then
    #     run_command "hespecgen evtfile=$screen_file deadfile=$dtime_file outfile=$pha_file userdetid=\"0-15,17\"" "$log_file"
    # fi

    # # Step 5: Run herspgen
    # if file_exists "${pha_file}_g0.pha" && file_exists "$att_file"; then
    #     run_command "herspgen phafile=${pha_file}_g0.pha attfile=$att_file outfile=$resp_file ra=-1 dec=-91" "$log_file"
    # fi

    # Step 5.5: Collect .pha files and store in he_specname.txt
    local spec_file="$output_dir/${exexposure_id}_he_specname.txt"
    find "$output_dir" -name "${exposure_id}_he*.pha" > "$spec_file"
    echo "Stored all .pha files in $spec_file"

    # Step 6: Run hebkgmap
    if file_exists "$screen_file" && file_exists "$gti_file"; then
        run_command "hebkgmap spec $screen_file $ehk_file $gti_file $dtime_file $spec_file 0 255 $bkg_file" "$log_file"
    fi
}

process_observation() {
    local obs_dir=$1
    local log_file="$obs_dir/output/he_process.log"

    mkdir -p "$obs_dir/output"
    touch "$log_file"

    for exposure in "$obs_dir"/P*; do
        if [ -d "$exposure" ]; then
            process_exposure "$exposure" "$obs_dir" "$log_file"
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