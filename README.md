Files with prefix "nb_" are jupyter notebooks.

There are original observation folders named as per ObsID

The same folders inside nicer/bootstrap_folder contain period estimations made by bootstrap python script. 

lcfile.txt contains the path of all the lightcurves generated for each ObsID. It can be given to ftools for quick run. 

Scripts used for NICER analysis, all scripts save a log file inside individual observation folders.
| Script Name                 | Description                                                     |
|-----------------------------|-----------------------------------------------------------------|
| `nicer_data_download_commands.sh` | All 76 observations with exposure in heasarc >100s between the period of xx201 observation and xx284 observation|
| `download_files.sh`          | Downloading observation small batch                                  |
| `lc_efold.sh`               | Epoch folding with manual input of known period                 |
| `lc_file_combine.sh`        | Script to gather paths of all light curves inside observation folders |
| `run_barrycorr_day.sh`      | Run barycenter correction on cleaned event files (Day)          |
| `run_barrycorr_night.sh`    | Run barycenter correction on cleaned event files (Night)        |
| `run_nicer.sh`              | Run `nicerl2` task to generate cleaned event files              |
| `run_nicerl3_lc_day.sh`     | Run `nicerl3-lc` task to generate light curve with desired binning (Day) |
| `run_nicerl3_lc_night.sh`   | Run `nicerl3-lc` task to generate light curve with desired binning (Night) |
| `run_nicerl3_lc_night_binned.sh` | Run `nicerl3-lc`  on observation for different energy bins|
| `bootstrap_period.sh` | Run `efsearch` on observation for 1000 times depending on the input obs folder array taken by scanning for 10-digit obsID. Has a python version which is easier to tweak|
|`run_flux_calculation.sh`|Running the script uses xcm file `saved_spec_files.txt` which is just names of all .xcm files for which one required the flux, it saves all output in `flux_results.txt` file in the same location. Has to be run from the location where .xcm file can be openned. |
| `run_nicerl3_spect.sh`     | Run `nicerl3-spect` task to generate spectra from reduced event files after orbital correction. It does not matter for spectra so using original event file gives same result.|
| `run_hxmt_he/me/le.sh`     | Run HXMTDAS tasks to generate spectra from L1 files. specgen commands are where spectra generation starts so altering the script to remove further steps would ensure generation of L2 products.|
| `run_hxmt_after_binary.sh`        | Used corrected GTI, event and other files to regenerate the L3 files accounting for correction |
| `run_hxmt_bootstrap_error.sh`        | Doing bootstrap for given efsearch initial parameters or can take initial from period calculated using run_efsearch.sh |




Notebooks Used in the Analysis
| Notebook Name                 | Description                                                     |
|-----------------------------|-----------------------------------------------------------------|
| `nb_hcxt_read_prepare_load_spectra.ipynb`               | Adding xcm files based on observation where LE and ME exists for easy loading of spectra|
| `nb_phase_resolved_setup.ipynb`               | Adding phase column based on spin period and known epoch from orbittime column. Hints from Phase resolved spectrum thread on barycenter corrected files of NICER page. Outputs `****/night_barycorr_orbit_piexpiex_yes_phase_added.evt` named event files which can be plotted as histogram to ideally reveal pulse peaks       |
| `nb_adding_orbittime_column_evt.ipynb`               | Adding Orbittime column to the base event file which contans uncorrected TIME and BARYTIME columns       |
| `nb_orbital_correction_final.ipynb`               | Calculating kepler's solution using Mikkola's approximation taken from old code of Tubingen. Outputs `_orbit_piexpiex.evt` subject to change with TIME column edited. Used for further analysis     |
| `nb_bootstrap_error.ipynb`          | Predicting period using bootstrap method. Outputs best fit period and max chi-sq as text file inside `bootstrap_error` folder with respected obsID folder dynamically created.                               |
| `nb_bootstrap_error_compilation.ipynb`          | collects the bootstrap results from the bootstrap file in hxmt and creates a csv for all observations instrument wise.     |
| `nb_bootstrap_reportin.ipynb`               | Plotting variation of period with iteration using best fit period texts generated from previous script                 |
| `nb_folding_pulse_fraction.ipynb`        | Epoch folding using python and RMS Pulsed fraction computation|
| `nb_rms_phase_resolved_deviation.ipynb`        | Computing RMS deviation in each phase. Contains own implementation and Aru implementation. Outputs png as well|
| `download_utility.py`        | Altered and collected the batches of wget script to add flags necessary to track progress of download |
|`nb_efold.ipynb`| Used the period found from efsearch manual filtering on efold task to generate folded pulse profiles, same epoch can be used|
|`nb_efsearch.ipynb` | Used to search for period, both event file and lc file can be given with tweaks in input. |
| `nb_period_reporting.py`        | Routine to plot period vs MJD or TJD |
| `nb_report_spectrum.ipynb`        | Average NICER spectrum and its evolution with MJD and Lum, uses a csv file created from excel records of spectrum |
| `nb_reporting_efsearch.ipynb`        | Plot frequency variation of HXMT with respect to NICER using final manually created period values |
| `nb_pf_reporting.ipynb`        | Plots the data from pulsed fraction calculation |
| `nb_hxmt_reporting_spectra.ipynb`        | Plot variation of HXMT spectral parameters with respect to NICER using final spectral params csv |
| `nb_hxmt_reporting_profile_rms.ipynb`        | Plot variation of HXMT timing parameters with with csv |

