#!/bin/bash

# Exit on error, unset variable, or failure in any part of a pipe
set -euo pipefail

# Trap and print line number and error on failure
trap 'echo "Error occurred in script at line $LINENO while running: $BASH_COMMAND"; exit 1' ERR
trap 'echo "Script interrupted (e.g., CTRL+C)"; exit 1' SIGINT

# Base directory
BASE_DIR="rerun_bootstrap"

# Check if a file exists
file_exists() {
    local file=$1
    [[ -f "$file" ]]
}

# Run a command and log it
run_command() {
    local cmd=$1
    local log_file=$2
    echo "Running: $cmd" | tee -a "$log_file"
    eval "$cmd" 2>&1 | tee -a "$log_file"
}

# Process exposure light curve
process_exposure_lc() {
    local obs_dir=$1
    local input_lc=$2
    local exposure_type=$3

    echo "Processing $exposure_type exposure: $input_lc"

    local output_dir="$obs_dir/bootstrap_output/$exposure_type"
    mkdir -p "$output_dir"

    rm -f "$output_dir/t-chi1.qdp" "$output_dir/periods1.dat" "$output_dir/bootstrap.lc"

    for ((i=1; i<=500; i++)); do
        echo "Running fcalc on $input_lc for iteration $i"
        fcalc "$input_lc" "$output_dir/bootstrap.lc" RATE "RATE+(2.0*random(RATE)-1)*ERROR"

        if [[ ! -f "$output_dir/bootstrap.lc" ]]; then
            echo "Error: bootstrap.lc not created in iteration $i"
            return 1
        fi

        printf "$output_dir/bootstrap.lc\n-\nINDEF\n9.79267\n64\nINDEF\n1e-4\n512\n \nyes\n/null\nwe $output_dir/test_efs\nstat\nq" > "$output_dir/efsearch_inp"
        efsearch < "$output_dir/efsearch_inp" > "$output_dir/test1.log"

        if [[ ! -f "$output_dir/test_efs.pco" ]]; then
            echo "Error: test_efs.pco missing in iteration $i"
            return 1
        fi

        per=$(awk '{if (NR==5) print $8}' "$output_dir/test_efs.pco")
        chi=$(tail -4 "$output_dir/test1.log" | head -1 | awk '{print $7}')

        echo "$per $chi" >> "$output_dir/periods1.dat"
        echo "$i $per $chi"

        rm -f "$output_dir/test"* "$output_dir/"*inp "$output_dir/bootstrap.lc"
    done

    mean=$(awk '{sum+=$1} END {print sum/NR}' "$output_dir/periods1.dat")
    stddev=$(awk -v mean=$mean '{sum+=($1-mean)^2} END {print sqrt(sum/NR)}' "$output_dir/periods1.dat")

    echo "Mean period for $exposure_type: $mean"
    echo "Standard deviation: $stddev"

    echo "Mean period: $mean" >> "$output_dir/t-chi1.qdp"
    echo "Standard deviation (error on period): $stddev" >> "$output_dir/t-chi1.qdp"
}

process_observation() {
    local obs_dir=$1
    local pipeline_dir="$obs_dir/pipeline_output"

    # local he_exposure=$(find "$pipeline_dir" -type f -name "*HE_lcnet*.lc" | head -n 1 || true)
    # local me_exposure=$(find "$pipeline_dir" -type f -name "*ME_lcnet*.lc" | head -n 1 || true)
    local le_exposure=$(find "$pipeline_dir" -type f -name "*LE_lcnet*.lc" | head -n 1 || true)

    # [ -n "$he_exposure" ] && process_exposure_lc "$obs_dir" "$he_exposure" "HE"
    # [ -n "$me_exposure" ] && process_exposure_lc "$obs_dir" "$me_exposure" "ME"
    [ -n "$le_exposure" ] && process_exposure_lc "$obs_dir" "$le_exposure" "LE"

    # echo "$he_exposure"
    # echo "$me_exposure"
    echo "$le_exposure"
}

process_proposal() {
    local proposal=$1
    for obs_dir in "$proposal"/*; do
        if [ -d "$obs_dir" ]; then
            process_observation "$obs_dir"
        fi
    done
}

main() {
    for proposal in "$BASE_DIR"/P*; do
        if [ -d "$proposal" ]; then
            process_proposal "$proposal"
        fi
    done
}

main
