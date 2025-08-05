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

    # Find the LE and AUX directories (searches recursively)
    local exposure_sub
    exposure_sub=$(find "$exposure" -type d -name "LE" | head -n 1)
    
    local aux_dir
    aux_dir=$(find "$exposure" -type d -name "AUX" | head -n 1)
    
    if [ -z "$exposure_sub" ] || [ -z "$aux_dir" ]; then
        echo "Error: LE or AUX directory not found in $exposure."
        return 1
    fi

    # Extract OBS_ID and exposure identifier
    local obs_id=$(basename "$exposure" | cut -d'-' -f1)
    local exposure_id=$(basename "$(dirname "$exposure_sub")" | cut -d'-' -f1)

    # Name output folder
    local output_dir="$obs_dir/output"
    mkdir -p "$output_dir"

    # Define log file inside the output directory with exposure-specific naming
    local log_file="$output_dir/${exposure_id}_le_process.log"
    touch "$log_file"
    
    # Define paths for input/output files
    local evt_file="$exposure_sub/HXMT_${obs_id}_LE-Evt_FFFFFF_V1_L1P.FITS"
    local temp_file="$exposure_sub/HXMT_${obs_id}_LE-TH_FFFFFF_V1_L1P.FITS"
    local instatus_file="$exposure_sub/HXMT_${obs_id}_LE-InsStat_FFFFFF_V1_L1P.FITS"
    local ehk_file="$aux_dir/HXMT_${obs_id}_EHK_FFFFFF_V1_L1P.FITS"
    local att_file="$exposure/ACS/HXMT_${obs_id}_Att_FFFFFF_V1_L1P.FITS"

    
    # Define output file paths
    local pi_file="$output_dir/${exposure_id}_le_pi.fits"
    local recon_file="$output_dir/${exposure_id}_le_recon.fits"
    local gti_file="$output_dir/${exposure_id}_le_gti.fits"
    local gti_corr_file="$output_dir/${exposure_id}_le_gti_corr.fits"
    local screen_file="$output_dir/${exposure_id}_le_screen.fits"
    local pha_file="$output_dir/${exposure_id}_le_pha"
    local resp_file="$output_dir/${exposure_id}_le_resp.fits"
    local bkg_file="$output_dir/${exposure_id}_le_specbkg"
    
    # Step 1: Run lepical
    if file_exists "$evt_file" && file_exists "$temp_file" && [ ! -f  "$pi_file" ]; then
        run_command "lepical evtfile=$evt_file tempfile=$temp_file outfile=$pi_file clobber=YES" "$log_file"
    fi

    # Step 2: Run lerecon
    if file_exists "$pi_file" && file_exists "$instatus_file" && [ ! -f "$recon_file" ]; then
        run_command "lerecon evtfile=$pi_file instatusfile=$instatus_file outfile=$recon_file" "$log_file"
    fi

    # Step 3: Run legtigen
    if file_exists "$ehk_file" && file_exists "$instatus_file" && [ ! -f "$gti_file" ]; then
        run_command "legtigen defaultexpr=NONE expr=\"ELV>10&&COR>8&&SAA_FLAG==0&&ANG_DIST<0.04&&T_SAA>300&&TN_SAA>300\" tempfile=$temp_file ehkfile=$ehk_file instatusfile=$instatus_file evtfile=NONE outfile=$gti_file" "$log_file"
    fi

    # Step 4: Run legticorr
    if file_exists "$recon_file" && file_exists "$gti_file" && [ ! -f "$gti_corr_file" ]; then
        run_command "legticorr $recon_file $gti_file $gti_corr_file" "$log_file"
    fi

    # Step 5: lescreen
    if file_exists "$recon_file" && file_exists "$gti_corr_file" && [ ! -f "$screen_file" ]; then
        run_command "lescreen evtfile=$recon_file gtifile=$gti_corr_file userdetid="0-95" eventtype=1 outfile=$screen_file" "$log_file"
    fi

    # Step 6: Run lespecgen
    ## if you ever want to skip pha step:: add this
    #&& [ -z "$(ls "$output_dir/${exposure_id}_le_pha_"*.pha 2>/dev/null)" ]
    if file_exists "$screen_file" ; then
        run_command "lespecgen evtfile=$screen_file userdetid=\"0 2-4 6-10 12 14 20 22-26 28-30 32 34-36 38-42 44 46 52 54-58 60-62 64 66-68 70-74 76 78 84 86-90 92-94\" outfile=$pha_file eventtype=1" "$log_file"
    fi

    # Step 7: Run lerspgen
    #file_exists "$pha_file" && 
    if file_exists "$att_file" && [ ! -f "$resp_file" ]; then
        run_command "lerspgen phafile=${pha_file}_g0.pha tempfile=$temp_file attfile=$att_file outfile=$resp_file ra=-1 dec=-91" "$log_file"
    fi

    # Step 7.5: Collect .pha files and store in specname.txt
    local spec_file="$output_dir/le_specname.txt"
    find "$output_dir" -name "${exposure_id}_le_*.pha" > "$spec_file"
    echo "Stored all .pha files in $spec_file"

    # Step 8: Run lebkgmap
    if file_exists "$screen_file" && file_exists "$gti_file"; then
        run_command "lebkgmap spec $screen_file $gti_file $spec_file 0 1535 $bkg_file" "$log_file"
    fi
}

process_observation() {
    local obs_dir=$1
    local log_file="$obs_dir/output/le_process.log"

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