# #!/bin/bash

# # Barrycenter correction for night on manually given folder list. Can be automated to detect obsID in file tree.
# # Array of folders
# folders=("6050390204" "6050390284" "6050390216" "6050390244" "6050390227" "6050390261" "6050390201")

# # Loop through each folder and run the nicerl3-lc command followed by the barycorr command
# for folder in "${folders[@]}";
# do    
#     # Run the barycorr command
#     barycorr infile="./${folder}/xti/event_cl/ni${folder}_0mpu7_cl_night.evt" \
#              outfile="./${folder}/xti/event_cl/ni${folder}_0mpu7_cl_night_barycorr.evt" \
#              orbitfile="./${folder}/auxil/ni${folder}.orb.gz" barytime=yes clobber=YES refframe=ICRS ephem=JPLEPH.430\
#              2>&1 | tee "$folder/${folder}_barycorr.log"
# done
 

for batch in {0..1}; do
    # Find all obsid folders inside the batch folder
    batch_folder="batch_${batch}"
    obsid_folders=$(find "$batch_folder" -maxdepth 1 -type d -name "6050*")
    
    # Loop through each obsid folder
    for obsid_folder in $obsid_folders; do
        obsid=$(basename "$obsid_folder")
        
        # Define paths for input/output event files and orbit file
        infile="output/${obsid}/ni${obsid}_0mpu7_cl_night.evt"
        #infile="output/${obsid}/ni${obsid}_cl_nightmpu7_sr_night_0.1.lc"
        outfile="output/${obsid}/ni${obsid}_0mpu7_cl_night_barycorr.evt"
        #outfile="output/${obsid}/ni${obsid}_cl_nightmpu7_sr_night_0.1_barycorr.lc"
        orbitfile="${obsid_folder}/auxil/ni${obsid}.orb.gz"
        log_file="output/${obsid}/${obsid}_barycorr_night_0.01.log"
        modified_infile="output/${obsid}/ni${obsid}_0mpu7_cl_night_nofpmsel.evt"

        # Check if necessary files exist before processing
        if [[ -f "$infile" && -f "$orbitfile" ]]; then
            echo "Processing folder: $obsid (Batch: $batch)"
            
            # Run the barycorr command
            barycorr infile="$infile" \
                     outfile="$outfile" \
                     orbitfile="$orbitfile" \
                     barytime=no clobber=Yes \
                     refframe=ICRS ephem=JPLEPH.430 \
                     2>&1 | tee "$log_file"

            # Check for "no bracketing sample" error in the log file
            if grep -q "no bracketing sample found" "$log_file"; then
                echo "Error detected: no bracketing sample found for $obsid. Attempting fix..."
                
                # Create a copy of the infile to modify
                cp "$infile" "$modified_infile"
                
                # Remove the FPM_SEL extension from the copied event file
                ftdelhdu "$modified_infile[FPM_SEL]" "$modified_infile" clobber=YES
                
                # Rerun barycorr on the modified event file
                barycorr infile="$modified_infile" \
                         outfile="$outfile" \
                         orbitfile="$orbitfile" \
                         barytime=Yes clobber=yes \
                         refframe=ICRS ephem=JPLEPH.430 \
                         2>&1 | tee -a "$log_file"  # Append to the log file
                
                echo "Barycorr completed after fix for $obsid (Batch: $batch)"
            else
                echo "Barycorr completed successfully for $obsid (Batch: $batch)"
            fi
        else
            echo "Missing necessary files for $obsid in batch_$batch. Skipping..."
        fi
    done
done
