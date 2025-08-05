#!/bin/bash

# Define the base directory where data is stored
BASE_DIR="."  # Change this if needed

# Define possible detector types (HE, LE, ME)
detector_types=("he" "le" "me")

# Loop through all proposal IDs found in the base directory
for proposal_dir in "$BASE_DIR"/*/; do
    proposal_id=$(basename "$proposal_dir")  # Extract the Proposal ID

    # Loop through all observation IDs inside each proposal directory
    # Observation IDs follow the format: one letter + 10 digits (e.g., P0504196005)
    for obs_dir in "$proposal_dir"P[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]/; do
        observation_id=$(basename "$obs_dir")  # Extract the Observation ID

        # Define the output directory inside each observation
        output_dir="$obs_dir/output"

        # Check if the output directory exists
        if [[ ! -d "$output_dir" ]]; then
            echo "Output folder missing for $observation_id (Proposal: $proposal_id). Skipping..."
            echo "--------------------------------------"
            continue
        fi

        echo "Processing Observation: $observation_id (Proposal: $proposal_id)"

        # Extract all unique exposure IDs from filenames in the output directory
        exposure_ids=($(find "$output_dir" -maxdepth 1 -type f -name "*.pha" | awk -F'/' '{print $NF}' | cut -d'_' -f1 | sort -u))

        # If no exposure IDs are found, skip this observation
        if [[ ${#exposure_ids[@]} -eq 0 ]]; then
            echo "No exposure IDs found in $output_dir. Skipping..."
            echo "--------------------------------------"
            continue
        fi

        # Process each unique exposure ID separately
        for exposure_id in "${exposure_ids[@]}"; do
            echo "Detected Exposure ID: $exposure_id"

            # Process each detector type separately
            for detector in "${detector_types[@]}"; do
                echo "Processing Detector: $detector"

                # Find all spectra files matching the exposure ID and detector type
                spectra=($(find "$output_dir" -maxdepth 1 -type f -name "${exposure_id}_${detector}_pha_*"))

                # Find all background (specbkg) files matching the exposure ID and detector type
                backgrounds=($(find "$output_dir" -maxdepth 1 -type f -name "${exposure_id}_${detector}_specbkg.pha"))

                # Find all response files matching the exposure ID and detector type
                responses=($(find "$output_dir" -maxdepth 1 -type f -name "${exposure_id}_${detector}_resp.fits"))

                # Print found files
                echo "Spectra Files (${detector}):"
                if [ ${#spectra[@]} -eq 0 ]; then
                    echo "No spectra files found for $detector."
                else
                    printf '%s\n' "${spectra[@]}"
                fi

                echo "Background Files (${detector}):"
                if [ ${#backgrounds[@]} -eq 0 ]; then
                    echo "No background files found for $detector."
                else
                    printf '%s\n' "${backgrounds[@]}"
                fi

                echo "Response Files (${detector}):"
                if [ ${#responses[@]} -eq 0 ]; then
                    echo "No response files found for $detector."
                else
                    printf '%s\n' "${responses[@]}"
                fi

                echo "--------------------------------------"
            done
        done
    done
done