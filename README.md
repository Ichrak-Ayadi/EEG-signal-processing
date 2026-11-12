# EEG Signal Processing 

A MATLAB-based EEG signal processing project focused on analyzing brain electrical activity, exploring frequency-domain characteristics, visualizing electrode-level activity, and investigating motor-task classification using machine learning.

## Overview

This project explores EEG signals through a combination of digital signal processing, spectral analysis, spatial visualization, and machine learning techniques.

Using EEG recordings in European Data Format (EDF), the project implements two complementary analysis workflows:

- **Single-recording analysis:** Detailed investigation of one EEG recording, including signal characteristics, frequency decomposition, artifact detection, topographic visualization, connectivity analysis, and brain-state estimation.
- **Multi-run analysis:** Comparison of EEG activity across different experimental conditions, including eyes-open versus eyes-closed states, real versus imagined movements, and left versus right fist movements.

The project also includes an interactive EEG viewer for exploring multichannel recordings.


## Dataset

This project uses the **[EEG Motor Movement/Imagery Dataset (EEGMMIDB)](https://physionet.org/content/eegmmidb/1.0.0/)**, available through [PhysioNet](https://physionet.org/).

The dataset contains 64-channel EEG recordings collected from participants performing and imagining different motor tasks. Each subject completed 14 experimental runs, including eyes-open and eyes-closed resting states, real motor movements, and motor imagery tasks.

### Dataset Authors and Contributors

- **Dataset contributor:** Gerwin Schalk
- **Data collection:** W. A. Sarnacki
- **Dataset compilation and documentation:** Aditya Joshi
- **Experimental design:** D. J. McFarland
- **Project oversight:** J. R. Wolpaw

### Dataset Citation

If you use this dataset, please cite:

Schalk, G. (2009). *EEG Motor Movement/Imagery Dataset* (Version 1.0.0). PhysioNet. https://doi.org/10.13026/C28G6P

### Related Publication

Schalk, G., McFarland, D. J., Hinterberger, T., Birbaumer, N., & Wolpaw, J. R. (2004). BCI2000: A General-Purpose Brain-Computer Interface (BCI) System. *IEEE Transactions on Biomedical Engineering, 51*(6), 1034–1043.

### Dataset Access and License

- **Source:** [PhysioNet – EEGMMIDB](https://physionet.org/content/eegmmidb/1.0.0/)
- **Version:** 1.0.0
- **DOI:** [10.13026/C28G6P](https://doi.org/10.13026/C28G6P)
- **Dataset license:** Open Data Commons Attribution License v1.0

## Features

### 1. EEG Signal Acquisition and Visualization
- Import EEG recordings from EDF files.
- Extract numerical signals and channel labels.
- Determine sampling frequency and recording duration.
- Visualize multiple EEG channels using stacked plots.
- Display basic signal statistics, including mean, standard deviation, maximum, and minimum amplitude.

### 2. Frequency-Domain Analysis
- Fast Fourier Transform (FFT) for frequency spectrum analysis.
- Digital bandpass filtering using Butterworth filters.
- Zero-phase filtering using `filtfilt`.
- Decomposition of EEG signals into five conventional frequency bands:

| Band | Frequency range |
|---|---|
| Delta | 0.5–4 Hz |
| Theta | 4–8 Hz |
| Alpha | 8–13 Hz |
| Beta | 13–30 Hz |
| Gamma | 30–45 Hz |

- Computation and comparison of frequency-band power.
- Spectrogram visualization to investigate time-frequency characteristics.

### 3. Artifact Detection and Removal
- Amplitude-threshold-based artifact detection.
- Identification of abnormal signal amplitudes.
- Linear interpolation of detected artifact samples.
- Comparison of EEG signals before and after artifact correction.

### 4. EEG Topographic Visualization
- Representation of electrode positions using a 64-channel electrode coordinate map.
- Calculation of frequency-band power for individual electrodes.
- Spatial interpolation of electrode measurements.
- Generation of scalp topographic maps to visualize the spatial distribution of Delta, Theta, Alpha, Beta, and Gamma activity.

### 5. Brain Connectivity Analysis
- Investigation of relationships between EEG channels.
- Alpha-band filtering (8–13 Hz).
- Computation of a normalized cross-spectral connectivity measure.
- Visualization of channel-to-channel connections on a scalp representation.

### 6. Brain-State Estimation
- Division of EEG signals into one-second epochs.
- Extraction of relative frequency-band power.
- Rule-based classification into five estimated activity states:
  - Deep Rest
  - Relaxed
  - Alert
  - Drowsy
  - Mixed
- Visualization of frequency-band evolution and estimated brain states over time.

### 7. Multi-Condition EEG Analysis

The multi-run workflow investigates several experimental conditions:

**Eyes Open vs. Eyes Closed**
- Comparison of Alpha-band power.
- Focus on occipital electrodes O1, Oz, and O2.

**Rest vs. Real vs. Imagined Movement**
- Comparison of Beta-band activity.
- Focus on motor electrodes C3, Cz, and C4.
- Averaging across repeated experimental runs.

**Left vs. Right Fist Movement**
- Extraction of T1 and T2 event-related epochs.
- Comparison of EEG activity and Beta-band power.

### 8. Motor-Task Classification Using LDA

A binary classification experiment is implemented to distinguish left-fist and right-fist movement conditions.

The classification pipeline includes:

- Event-based epoch extraction from EEG annotations.
- Beta-band filtering (13–30 Hz).
- Feature extraction using C3 and C4 Beta-band power.
- Calculation of a logarithmic C3/C4 power ratio as a lateralization feature.
- Linear Discriminant Analysis (LDA).
- Leave-One-Out Cross-Validation (LOOCV).
- Classification accuracy and confusion matrix evaluation.
- Feature-space and classification-performance visualization.

The current implementation extracts classification trials from the real-movement runs R03, R07, and R11.

## Project Structure

```text
EEG-Signal-Processing/
│
├── single_run_analysis.m
│   └── Complete analysis of a single EEG recording
│
├── multi_run.m
│   └── Multi-run comparisons, topographic analysis,
│       and LDA-based classification
│
├── eeg_viewer.m
│   └── Interactive multichannel EEG visualization
│
├── 64_channel_sharbrough.pdf
│   └── 64-channel electrode reference layout
│
├── .gitignore
│
└── README.md
```

## Dataset

The scripts are designed to work with EEG recordings stored in EDF format.

The multi-run analysis is configured for subject `S001` and expects 14 recordings:

```text
S001R01.edf
S001R02.edf
S001R03.edf
...
S001R14.edf
```

The experimental runs are organized as follows:

| Runs | Experimental condition |
|---|---|
| R01 | Baseline — Eyes Open |
| R02 | Baseline — Eyes Closed |
| R03, R07, R11 | Real Left/Right Fist |
| R04, R08, R12 | Imagined Left/Right Fist |
| R05, R09, R13 | Real Both Fists/Feet |
| R06, R10, R14 | Imagined Both Fists/Feet |

The multi-run script uses selected electrodes (C3, Cz, C4, O1, Oz, O2, and Fp1) for its initial comparisons and reloads all available channels for topographic analysis.

**Note:** EEG recordings are not included in this repository. Users must obtain the corresponding EDF files separately and ensure they have permission to use them.

## Requirements

- MATLAB with support for `edfread` and `edfinfo`.
- Signal Processing Toolbox:
  - `butter`
  - `filtfilt`
  - `spectrogram`
- Statistics and Machine Learning Toolbox:
  - `fitcdiscr`
  - `predict`

## Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/YOUR_USERNAME/EEG-Signal-Processing.git
```

### 2. Navigate to the project directory

```bash
cd EEG-Signal-Processing
```

### 3. Prepare the EEG dataset

Place the required EDF recordings in the project directory, or configure the paths in the MATLAB scripts.

For `single_run_analysis.m`, the default recording is:

```matlab
filename = 'S001R01.edf';
```

For `multi_run.m`, configure the data directory:

```matlab
subject = 'S001';
n_runs = 14;
data_folder = '';
```

If the EDF recordings are stored in another directory, update `data_folder` accordingly. The current filename construction expects the folder path to end with a directory separator.

### 4. Run the single-recording analysis

Open MATLAB, navigate to the project directory, and execute:

```matlab
single_run_analysis
```

This script performs the complete single-recording analysis and launches the interactive EEG viewer.

### 5. Run the multi-recording analysis

Execute:

```matlab
multi_run
```

This script loads the 14 experimental runs, performs the specified comparisons, generates topographic visualizations, and evaluates the LDA classifier.

### 6. Use the interactive EEG viewer

The viewer can also be called independently after loading EEG data:

```matlab
eeg_viewer(clean_data, clean_labels, fs)
```

The interface provides:
- Time-window navigation using a slider.
- Channel navigation.
- Time-axis zoom controls.
- Amplitude-spacing adjustments.
- Keyboard shortcuts for navigating through the recording.

## Notes and Limitations

- The analysis is configured for the channel naming conventions and experimental structure of the supplied EDF recordings.
- The multi-run script currently uses a predefined subject identifier and run configuration.
- Artifact correction in the single-recording script is demonstrated on the Fp1 channel using an amplitude threshold.
- The brain-state labels are heuristic estimates based on relative frequency-band power. They are not clinically validated diagnoses.
- The LDA classification experiment uses a relatively limited dataset and Leave-One-Out Cross-Validation. Its accuracy should be interpreted as an exploratory result rather than evidence of generalizable performance.
- Generated figures are displayed in MATLAB; the scripts do not automatically export all figures to files.

## Technologies

- MATLAB
- Digital Signal Processing
- EEG Signal Analysis
- Fast Fourier Transform (FFT)
- Butterworth Filtering
- Time-Frequency Analysis
- Brain Topography
- EEG Connectivity Analysis
- Linear Discriminant Analysis (LDA)
- Machine Learning
- Data Visualization

## Disclaimer

This project is intended for educational and research purposes. The implemented signal-processing methods and brain-state estimation procedures are exploratory and are not intended for clinical diagnosis or medical decision-making.

## Authors

Ichrak Ayadi & Emna Ghorbel
Developed for a Signal processing course at ENIT.