#!/bin/bash

# Base directory
BASE_DIR="/home/supremekai/thesis/J0243_6p6124/hxmt"

# Store the script's original directory
SCRIPT_DIR=$(pwd)

# Consolidated output files (use absolute paths)
he_output_file="$SCRIPT_DIR/all_hxmt_lc_periods_chisq_HE.txt"
me_output_file="$SCRIPT_DIR/all_hxmt_lc_periods_chisq_ME.txt"
le_output_file="$SCRIPT_DIR/all_hxmt_lc_periods_chisq_LE.txt"

# Create or clear the consolidated files
echo -e "LC_File_Path\tPeriod\tChi-square\tDate" > "$he_output_file"
echo -e "LC_File_Path\tPeriod\tChi-square\tDate" > "$me_output_file"
echo -e "LC_File_Path\tPeriod\tChi-square\tDate" > "$le_output_file"

# Function to find and process light curve files
process_light_curves() {
    local lc_dir="$1"
    local lc_files=$(find "$lc_dir" -type f -name "*_lcnet_*.lc")
    
    if [[ -z "$lc_files" ]]; then
        echo "No lcnet light curve files found in $lc_dir"
        return
    fi

    # Move to pipeline_output directory
    cd "$lc_dir" || { echo "Error: Unable to access $lc_dir"; return; }

    for lc_file in $lc_files; do
        echo "Processing light curve: $lc_file"
        
        lc_basename=$(basename "$lc_file" .lc)
        fes_file="efsearch.pco"  # Short file name
        log_file="${lc_basename}_efsearch.log"

        # Run efsearch
        printf "$lc_file\n-\nINDEF\n9.8\n64\nINDEF\n1e-4\n1024\n \nyes \n/null\nwe $fes_file\nstat\nq" > efsearch_inp
        efsearch < efsearch_inp > "$log_file"

        if [[ -f "$fes_file" ]]; then
            best_period=$(grep "Period :" "$log_file" | awk '{print $3}')
            chi_square=$(grep "Chisq " "$log_file" | awk '{print $5}' | sed 's/^[ \t]*//;s/[ \t]*$//')
            date=$(grep "Start Time " "$log_file" | awk '{print $8}')
            
            if [[ -n "$best_period" && -n "$chi_square" ]]; then
                if [[ "$lc_basename" == *"HE"* ]]; then
                    echo -e "$lc_file\t$best_period\t$chi_square\t$date" >> "$he_output_file"
                elif [[ "$lc_basename" == *"ME"* ]]; then
                    echo -e "$lc_file\t$best_period\t$chi_square\t$date" >> "$me_output_file"
                elif [[ "$lc_basename" == *"LE"* ]]; then
                    echo -e "$lc_file\t$best_period\t$chi_square\t$date" >> "$le_output_file"
                fi
                echo "Saved results for $lc_file"
            else
                echo "Warning: Missing period or chi-square for $lc_basename"
            fi
        else
            echo "Error: efsearch failed for $lc_file"
        fi
    done

    # Move back to the original directory
    cd "$SCRIPT_DIR"
}

# Process all proposals and observations
for proposal in "$BASE_DIR"/P*; do
    for obs_dir in "$proposal"/*; do
        if [[ -d "$obs_dir" ]]; then
        # if [[ $(basename "$obs_dir") == "P0504196019" ]]; then
            process_light_curves "$obs_dir/pipeline_output"
        fi
    done
done

echo "All periods and chi-squares recorded."
