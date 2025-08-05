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

# Function to process an exposure by finding all relevant files
process_exposure() {
    local exposure=$1
    local obs_dir=$2
    local log_file=$3

    # Find the ME and AUX directories (searches recursively)
    local exposure_sub
    exposure_sub=$(find "$exposure" -type d -name "ME" | head -n 1)
    # echo "exposure sub is $exposure_sub"

    local aux_dir
    aux_dir=$(find "$exposure" -type d -name "AUX" | head -n 1)
    
    if [ -z "$exposure_sub" ] || [ -z "$aux_dir" ]; then
        echo "Error: ME or AUX directory not found in $exposure."
        return 1
    fi

    # Extract OBS_ID and exposure identifier
    local obs_id=$(basename "$exposure" | cut -d'-' -f1)
    local exposure_id=$(basename "$(dirname "$exposure_sub")" | cut -d'-' -f1)

    # Name output folder
    local output_dir="$obs_dir/output"
    mkdir -p "$output_dir"

    # Define log file inside the output directory with exposure-specific naming
    local log_file="$output_dir/${exposure_id}_me_process.log"
    touch "$log_file"

    # Append exposure_id to filenames to ensure uniqueness
    local pi_file="$output_dir/${exposure_id}_me_pi.fits"
    local grade_file="$output_dir/${exposure_id}_me_grade.fits"
    local dead_file="$output_dir/${exposure_id}_me_dead.fits"
    local gti_file="$output_dir/${exposure_id}_me_gti.fits"
    local gti_corr_file="$output_dir/${exposure_id}_me_gti_corr.fits"
    local new_status_file="$output_dir/${exposure_id}_newmedetectorstatus.fits"
    local screen_file="$output_dir/${exposure_id}_me_screen.fits"
    local pha_file="$output_dir/${exposure_id}_me_pha"
    local resp_file="$output_dir/${exposure_id}_me_resp.fits"
    local bkg_file="$output_dir/${exposure_id}_me_specbkg"

     # Define paths for input/output files
    local evt_file="$exposure_sub/HXMT_${exposure_id}_ME-Evt_FFFFFF_V1_L1P.FITS"
    local temp_file="$exposure_sub/HXMT_${exposure_id}_ME-TH_FFFFFF_V1_L1P.FITS"
    local ehk_file="$exposure/AUX/HXMT_${obs_id}_EHK_FFFFFF_V1_L1P.FITS"
    local att_file="$exposure/ACS/HXMT_${obs_id}_Att_FFFFFF_V1_L1P.FITS"

    # Step 1: Run mepical if necessary
    if file_exists "$evt_file" && file_exists "$temp_file"; then
        run_command "mepical evtfile=$evt_file tempfile=$temp_file outfile=$pi_file clobber=YES seed=42" "$log_file"
    fi

    # Step 2: Run megrade if necessary
    if file_exists "$pi_file"; then
        run_command "megrade evtfile=$pi_file outfile=$grade_file deadfile=$dead_file binsize=0.008" "$log_file"
    fi

    # Step 3: Run megtigen if necessary
    if file_exists "$ehk_file"; then
        run_command "megtigen defaultexpr=NONE expr=\"ELV>10&&COR>8&&SAA_FLAG==0&&ANG_DIST<0.04&&T_SAA>300&&TN_SAA>300\" tempfile=$temp_file ehkfile=$ehk_file outfile=$gti_file" "$log_file"
    fi

    # Step 4: Run megticorr if necessary
    if file_exists "$gti_file"; then
        run_command "megticorr $grade_file $gti_file $gti_corr_file $HEADAS/refdata/medetectorstatus.fits $new_status_file" "$log_file"
    fi

    # Step 5: Run mescreen if necessary
    if file_exists "$gti_corr_file" && file_exists "$new_status_file"; then
        run_command "mescreen evtfile=$grade_file gtifile=$gti_corr_file outfile=$screen_file userdetid=\"0-53\" baddetfile=$new_status_file" "$log_file"
    fi

    # Step 6: Run mespecgen if necessary
    if file_exists "$screen_file" && file_exists "$dead_file"; then
        run_command "mespecgen evtfile=$screen_file deadfile=$dead_file userdetid=\"0 1 2 3 4 5 6 7 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 47 48 49 50 51 52 53; 10 28 46\" outfile=$pha_file" "$log_file"
    fi

    # Step 7: Run merspgen if necessary
    if file_exists "$att_file"; then
        run_command "merspgen phafile=${pha_file}_g0.pha attfile=$att_file outfile=$resp_file ra=-1 dec=-91" "$log_file"
    fi

    # Step 7.5: Collect .pha files and store in specname.txt
    spec_file="$output_dir/me_specname.txt"
    find "$output_dir" -name "${exposure_id}_me_*.pha" > "$spec_file"
    echo "Stored all .pha files in $spec_file"

    # Step 8: Run mebkgmap if necessary
    if file_exists "$screen_file" && file_exists "$gti_file" && file_exists "$dead_file"; then
        run_command "mebkgmap spec $screen_file $ehk_file $gti_file $dead_file $temp_file $output_dir/me_specname.txt 0 1023 $bkg_file $new_status_file" "$log_file"
    fi
}

process_observation() {
    local obs_dir=$1
    local log_file="$obs_dir/output/me_process.log"

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
        break
    done
}


# Run the main function
main
