#!/bin/bash

# Base directory
BASE_DIR="."

# Function to check if a file exists
file_exists() {
    local file=$1
    if [ -f "$file" ]; then
        return 0  # File exists
    else
        return 1  # File does not exist
    fi
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

    # Find HE and AUX directories (searches recursively)
    local HE_exposure_sub=$(find "$exposure" -type d -name "HE" | head -n 1)
    local ME_exposure_sub=$(find "$exposure" -type d -name "ME" | head -n 1)
    local LE_exposure_sub=$(find "$exposure" -type d -name "LE" | head -n 1)

    local aux_dir=$(find "$exposure" -type d -name "AUX" | head -n 1)
    # echo $aux_dir

    if [ -z "$HE_exposure_sub" ] || [ -z "$aux_dir" ] || [ -z "$ME_exposure_sub" ] || [ -z "$LE_exposure_sub" ]; then
        echo "Error: HE or AUX directory not found in $exposure."
        return 1
    fi

    # Extract OBS_ID and exposure identifier
    local obs_id=$(basename "$exposure" | cut -d'-' -f1)
    local exposure_id=$(basename "$(dirname "$HE_exposure_sub")" | cut -d'-' -f1)
    echo $exposure_id

    # Name output folder
    local output_dir="$obs_dir/pipeline_output"
    mkdir -p "$output_dir"

    # Define log file inside the output directory
    local log_file="$output_dir/${exposure_id}_lc_reprocess.log"
    touch "$log_file"

    # Define paths for input/output files
    local HE_screen_orbit_file="$output_dir/${exposure_id}_HE_screen_orbittimeNO.fits"
    local ME_screen_orbit_file="$output_dir/${exposure_id}_ME_screen_orbittimeNO.fits"
    local LE_screen_orbit_file="$output_dir/${exposure_id}_LE_screen_orbittimeNO.fits"
    local HE_gti_file="$output_dir/${exposure_id}_HE_gti_orbittimeNO.fits"
    local ME_gti_file="$output_dir/${exposure_id}_ME_gti_orbittimeNO.fits"
    local LE_gti_file="$output_dir/${exposure_id}_LE_gti_orbittimeNO.fits"
    local HE_dtime_file="$HE_exposure_sub/HXMT_${exposure_id}_HE-DTime_FFFFFF_V1_L1P.FITS"
    local ME_dtime_file="$output_dir/${exposure_id}_ME_dtime_0.05s.fits"
    local ME_temp_file="$ME_exposure_sub/HXMT_${exposure_id}_ME-TH_FFFFFF_V1_L1P.FITS"
    local ME_status_file="$output_dir/${exposure_id}_ME_status.fits"


    local HE_lc_file="$output_dir/${exposure_id}_HE_lc_27-250keV_0.05s"
    local ME_lc_file="$output_dir/${exposure_id}_ME_lc_10-35keV_0.05s"
    local LE_lc_file="$output_dir/${exposure_id}_LE_lc_2-10keV_0.05s"

    local HE_lc_bkg="$output_dir/${exposure_id}_HE_lcbkg_27-250keV_0.05s"
    local ME_lc_bkg="$output_dir/${exposure_id}_ME_lcbkg_10-35keV_0.05s"
    local LE_lc_bkg="$output_dir/${exposure_id}_LE_lcbkg_2-10keV_0.05s"

    local AUX_file="$aux_dir/HXMT_${exposure_id}_EHK_FFFFFF_V1_L1P.FITS"
    # echo $AUX_file


    # Check if orbit-corrected screen file already exists
    if file_exists "$HE_screen_orbit_file" || file_exists "$ME_screen_orbit_file" || file_exists "$LE_screen_orbit_file"; then
        echo "Orbit correction already done for $exposure_id. Skipping hpipeline. Running alternative commands..." | tee -a "$log_file"
        
        # Generate HE light curves
        helcgen evtfile=$HE_screen_orbit_file outfile=$HE_lc_file deadfile=$HE_dtime_file \
        binsize=0.05 userdetid="0-17" \
        minPI=8 maxPI=162 deadcorr="no" clobber="yes" history="yes"

        ls $output_dir/${exposure_id}_HE_lc_27-250keV_0.05s*.lc | sort -V > $output_dir/${exposure_id}_HE_lc_reprocessed.txt
        
        hebkgmap lc $HE_screen_orbit_file $AUX_file \
        $HE_gti_file $HE_dtime_file $output_dir/${exposure_id}_HE_lc_reprocessed.txt \
        8 162 $HE_lc_bkg 

        lcmath infile="$output_dir/${exposure_id}_HE_lc_27-250keV_0.05s_g0.lc" \
        bgfile="$output_dir/${exposure_id}_HE_lcbkg_27-250keV_0.05s_all.lc" \
        outfile="$output_dir/${exposure_id}_HE_lcnet_27-250keV_0.05s_all.lc" multi=1 multb=1 addsubr="no"
        
        # Generate ME light curves
        melcgen $ME_screen_orbit_file $ME_lc_file $ME_dtime_file \
        userdetid="0-7,11-25,29-43,47-53" binsize=0.05 starttime=0 stoptime=0 minPI=119 maxPI=546 \
        deadcorr="no" clobber="yes" history="yes"

        ls "$output_dir/${exposure_id}_ME_lc_10-35keV_0.05s"*.lc | sort -V > "$output_dir/${exposure_id}_ME_lc_reprocessed.txt"

        mebkgmap lc $ME_screen_orbit_file $AUX_file $ME_gti_file $ME_dtime_file $ME_temp_file "$output_dir/${exposure_id}_ME_lc_reprocessed.txt" 119 546 "$ME_lc_bkg"

        lcmath infile="$output_dir/${exposure_id}_ME_lc_10-35keV_0.05s_g0.lc" \
           bgfile="$output_dir/${exposure_id}_ME_lcbkg_10-35keV_0.05s.lc" \
           outfile="$output_dir/${exposure_id}_ME_lcnet_10-35keV_0.05s.lc" \
           multi=1 multb=1 addsubr="no" 
        
        Generate LE light curves
        lelcgen evtfile="$LE_screen_orbit_file" outfile="$LE_lc_file" \
        userdetid="0,2-4,6-10,12,14,20,22-26,28,30,32,34-36,38-42,44,46,52,54-58,60-62,64,66-68,70-74,76,78,84,86,88-90,92-94" \
        binsize=0.05 starttime=0 stoptime=0 minPI=224 maxPI=1169 eventtype=1 \
        clobber="yes" history="yes"
        
        ls "$output_dir/${exposure_id}_LE_lc_2-10keV_0.05s"*.lc | sort -V > "$output_dir/${exposure_id}_LE_lc_reprocessed.txt"

        lebkgmap lc $LE_screen_orbit_file $LE_gti_file $output_dir/${exposure_id}_LE_lc_reprocessed.txt 224 1169 "$LE_lc_bkg"
        
        lcmath infile="$output_dir/${exposure_id}_LE_lc_2-10keV_0.05s_g0.lc" bgfile= "$output_dir/${exposure_id}_LE_lcbkg_2-10keV_0.05s.lc" outfile="$output_dir/${exposure_id}_LE_lcnet_2-10keV_0.05s.lc" \
        multi=1 multb=1 addsubr="no"

        echo "Processing complete for $evts_file! Outputs saved in $output_dir"

    # else
    #     echo "No orbit-corrected file found for $exposure_id. Running hpipeline..." | tee -a "$log_file"
    #     run_command "hpipeline -i $exposure -o $output_dir --stem $exposure_id --hxbary --ephem='JPLEPH.DE430' --ra=40.92 --dec=61.43 --HE_LC_BINSIZE=0.05 --ME_LC_BINSIZE=0.05 --LE_LC_BINSIZE=0.05 --parallel" "$log_file"
    fi
}

process_observation() {
    local obs_dir=$1
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
