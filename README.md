# ICTP RegCM — Regional Climate Model

[![DOI](https://zenodo.org/badge/181515678.svg)](https://zenodo.org/badge/latestdoi/181515678)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**RegCM** is the ICTP Regional Climate Model system, maintained by the
[Earth System Physics (ESP)](https://www.ictp.it/research/esp.aspx) section of the
International Centre for Theoretical Physics (ICTP). It is a widely used, flexible,
and portable tool for high-resolution regional climate simulation.

---

## Overview

Originally developed at the National Center for Atmospheric Research (NCAR), RegCM has
undergone continuous development since its first release (RegCM1, 1989):

| Version | Year |
|---------|------|
| RegCM1  | 1989 |
| RegCM2  | 1993 |
| RegCM2.5 | 1999 |
| RegCM3  | 2006 |
| RegCM4  | 2010 |
| **RegCM5** | **2023** |

The current version is **RegCM 5.0.0**. It includes major upgrades to the model
structure, pre- and post-processors, and new physics parameterizations.

The model can be applied to **any region of the world**, with grid spacings down to
approximately **3 km**, for a wide range of applications — from process studies to
paleoclimate and future climate simulations.

---

## Features

- High-resolution regional climate simulation (grid spacing ~3 km or coarser)
- Multiple physics parameterizations (radiation, PBL, convection, microphysics, chemistry)
- Community Land Model (CLM 3.5 / CLM 4.5) integration
- Atmospheric chemistry module
- OASIS3-MCT coupler support for coupled climate simulations
- MPI parallelization with optional serial mode
- Optional GPU acceleration (OpenACC / PGI)
- NetCDF4 / HDF5 I/O
- Comprehensive pre- and post-processing toolchain

---

## Directory Structure

```
RegCM/
├── Main/          # Core model source code and physics libraries
├── PreProc/       # Preprocessing tools (terrain, emissions, initial/boundary conditions)
├── PostProc/      # Post-processing tools (averaging, regridding, format conversion)
├── Tools/         # Utility programs and helper scripts
├── Doc/           # Documentation (UserGuide, ReferenceManual, DeveloperGuide)
├── Share/         # Shared data and resources
├── Testing/       # Test suite
└── external/      # External dependencies (MPI stub, aerosols, BMI)
```

### Main Model Components (`Main/`)

The core Fortran 90 model is organized into physics sub-libraries:

| Directory | Description |
|-----------|-------------|
| `radlib/` | Radiation module |
| `pbllib/` | Planetary boundary layer |
| `cumlib/` | Cumulus convection |
| `microlib/` | Cloud microphysics |
| `chemlib/` | Atmospheric chemistry |
| `clmlib/` | Community Land Model integration |
| `cloudlib/` | Cloud processing |
| `oasislib/` | OASIS coupler interface |

---

## Requirements

- **Fortran 90/95** compiler (e.g., gfortran, ifort, nvfortran)
- **C compiler** (e.g., gcc)
- **NetCDF** (with Fortran bindings) — required
- **HDF5** — optional (for compressed NetCDF4 output)
- **MPI** — recommended for parallel runs; serial stub included via `--enable-mpiserial`

---

## Building

If the `configure` script is not present, generate it first:

```bash
./bootstrap.sh
```

Then configure, build, and install:

```bash
./configure --with-netcdf=/path/to/netcdf [OPTIONS]
make
make install
```

### Common `configure` options

| Option | Description |
|--------|-------------|
| `--with-netcdf=PATH` | Path to NetCDF installation |
| `--with-hdf5=PATH` | Path to HDF5 installation |
| `--with-szip=PATH` | Path to SZIP installation |
| `--with-oasis-path=PATH` | Path to OASIS3-MCT coupler |
| `--enable-mpiserial` | Use serial MPI stub (single processor) |
| `--enable-singleprecision` | Use single-precision reals |
| `--enable-openacc` | Enable GPU acceleration (PGI/NVHPC) |
| `--prefix=DIR` | Installation prefix (default: `/usr/local`) |

For a full list of options run:

```bash
./configure --help
```

---

## Running

After building, the main executable is `regcm`. A typical run requires:

1. Preprocessing: run `terrain`, `sst`, and `icbc` tools from `PreProc/`
2. Configure the namelist file for your domain and simulation period
3. Run the model: `mpirun -np <N> regcm <namelist_file>`
4. Post-process outputs using tools in `PostProc/`

Refer to the **User Guide** in `Doc/UserGuide/` for detailed instructions.

---

## Documentation

- `Doc/UserGuide/` — Step-by-step user documentation
- `Doc/ReferenceManual/` — Technical reference for all namelist options
- `Doc/DeveloperGuide/` — Guide for model developers and contributors
- `Doc/README.namelist` — Quick reference for namelist parameters

---

## Community

ICTP supports the **RegCNET** (Regional Climate Research Network), which expands and
strengthens the network of RegCM users and facilitates collaborative research on
regional climate change.

- **Mailing list:** https://lists.ictp.it/mailman/listinfo/regcnet
- **Model input data:** http://clima-dods.ictp.it/regcm4 *(legacy input data archive)*

---

## Citation

If you use RegCM in your research, please cite:

> Giorgi, F. et al. (2023). *The ICTP RegCM*. Version 5.0.0.
> DOI: [10.1029/2022JD038199](https://doi.org/10.1029/2022JD038199)

CITATION.cff metadata is also provided in this repository.

---

## License

Copyright © 2025 UNESCO ICTP — Graziano Giuliani.
Released under the [MIT License](LICENSE).
