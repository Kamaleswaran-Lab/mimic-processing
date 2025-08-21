# MIMIC-IV PostgreSQL Database Setup with Apptainer

This guide walks through setting up a PostgreSQL database for MIMIC-IV data using Apptainer containers on an HPC system without sudo privileges.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Container Setup](#container-setup)
3. [Directory Structure](#directory-structure)
4. [Download MIMIC Data](#download-mimic-data)
5. [Build and Download Container](#build-and-download-container)
6. [Test Container Setup](#test-container-setup)
7. [Run MIMIC Database Build](#run-mimic-database-build)
8. [Verify Installation](#verify-installation)
9. [Usage Examples](#usage-examples)
10. [Troubleshooting](#troubleshooting)

## Prerequisites

- Access to HPC system with Apptainer installed
- MIMIC-IV data downloaded from PhysioNet
- GitLab account for container builds
- Sufficient storage space (~200GB for database)

### Required HPC Resources
- **Disk Space**: 150-200GB persistent storage
- **Memory**: 32GB RAM for build process
- **Time**: 8-24 hours for initial build

## Container Setup

### 1. Container Setup

Follow the Apptainer definition and build process documented here: [https://gitlab.oit.duke.edu/klab/postgressql](https://gitlab.oit.duke.edu/klab/postgressql)

## Directory Structure

Create the following directory structure on your HPC system:

```bash
# Create project directories
mkdir -p /hpc/group/kamaleswaranlab/mimic_iv/{builtdata,mimic-iv-3.1}
mkdir -p /hpc/group/kamaleswaranlab/mimic_iv/builtdata/{postgres_data,csv_exports,sql_scripts}

# Set permissions for lab sharing
chmod -R 775 /hpc/group/kamaleswaranlab/mimic_iv/builtdata/
```

Expected structure:
```
/hpc/group/kamaleswaranlab/mimic_iv/
├── builtdata/
│   ├── postgres_data/          # PostgreSQL database files (persistent)
│   ├── csv_exports/            # Exported analysis results
│   └── sql_scripts/            # MIMIC build scripts
│       └── mimic-processing/   # Contains mimic-code repository
└── mimic-iv-3.1/              # Original MIMIC CSV files
    ├── core/
    │   ├── admissions.csv.gz
    │   ├── patients.csv.gz
    │   └── transfers.csv.gz
    ├── hosp/
    │   ├── diagnoses_icd.csv.gz
    │   └── ...
    ├── icu/
    │   ├── chartevents.csv.gz
    │   └── ...
    └── ed/
        └── ...
```

## Download MIMIC Data

1. **Get PhysioNet access** for MIMIC-IV
2. **Download and organize data**:
   ```bash
   # Download MIMIC-IV v3.1 (or latest version)
   cd /hpc/group/kamaleswaranlab/mimic_iv/mimic-iv-3.1/
   
   # Your data should be organized as:
   # core/ - core patient data
   # hosp/ - hospital data  
   # icu/ - ICU data
   # ed/ - emergency department data
   ```

3. **Clone MIMIC build scripts**:
   ```bash
   cd /hpc/group/kamaleswaranlab/mimic_iv/builtdata/sql_scripts/
   git clone https://github.com/MIT-LCP/mimic-code.git mimic-processing
   ```

## Build and Download Container

### 1. Download Container from GitLab CI

```bash
cd /hpc/group/kamaleswaranlab/mimic_iv/

# Download your built container (replace with your actual GitLab info)
curl -O https://research-containers-01.oit.duke.edu/YOUR_USERNAME/YOUR_PROJECT.sif

# Verify download
ls -lh *.sif
file *.sif  # Should show "data" not "HTML document"
```

### 2. Test Container

```bash
# Quick test
apptainer shell --bind /hpc/group/kamaleswaranlab/mimic_iv/builtdata/postgres_data:/var/lib/postgresql/data postgres.sif

# Inside container, check PostgreSQL
psql --version
which postgres
exit
```

## Test Container Setup

### 1. Interactive Test

```bash
# Start container interactively
apptainer exec \
  --bind /hpc/group/kamaleswaranlab/mimic_iv/builtdata/postgres_data:/var/lib/postgresql/data \
  --bind /hpc/group/kamaleswaranlab/mimic_iv/builtdata/csv_exports:/exports \
  --bind /hpc/group/kamaleswaranlab/mimic_iv/builtdata/sql_scripts/mimic-processing/:/scripts \
  --bind /hpc/group/kamaleswaranlab/mimic_iv/mimic-iv-3.1/:/mimic_data \
  postgres.sif bash

# Inside container, test PostgreSQL setup
export PGPORT=15432 PGDATA=/var/lib/postgresql/data PGUSER=labuser

# Remove any problematic config
sed -i '/^timezone_abbreviations = .*/d' "$PGDATA/postgresql.conf" 2>/dev/null || true

# Start PostgreSQL
postgres -D "$PGDATA" -p $PGPORT &
sleep 5

# Test connection
psql -h localhost -p 15432 -U labuser -d postgres -c "SELECT version();"

# If successful, create MIMIC database
createdb -h localhost -p 15432 -U labuser mimiciv

# Test MIMIC database
psql -h localhost -p 15432 -U labuser -d mimiciv -c "SELECT current_database();"

exit
```

### 2. Verify MIMIC Scripts

```bash
# Check scripts are accessible
apptainer exec \
  --bind /hpc/group/kamaleswaranlab/mimic_iv/builtdata/sql_scripts/mimic-processing/:/scripts \
  postgres.sif ls -la /scripts/mimic-code/mimic-iv/buildmimic/postgres/

# Should show: create.sql, load_gz.sql, constraint.sql, index.sql
```

## Run MIMIC Database Build

### 1. Create SLURM Job Script

Create `load_mimic.slurm`:

```bash
#!/bin/bash
#SBATCH --job-name=load_mimic
#SBATCH --time=24:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=8
#SBATCH --partition=common
#SBATCH --output=/hpc/group/kamaleswaranlab/mimic_iv/builtdata/scripts/logs/load_%j.out
#SBATCH --error=/hpc/group/kamaleswaranlab/mimic_iv/builtdata/scripts/logs/load_%j.err

# Set working directory
cd /hpc/group/kamaleswaranlab/mimic_iv

echo "Starting MIMIC-IV PostgreSQL setup..."
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "Start time: $(date)"

# Start PostgreSQL in apptainer
echo "Starting PostgreSQL container..."
apptainer exec \
  --bind /hpc/group/kamaleswaranlab/mimic_iv/builtdata/postgres_data:/var/lib/postgresql/data \
  --bind /hpc/group/kamaleswaranlab/mimic_iv/builtdata/csv_exports:/exports \
  --bind /hpc/group/kamaleswaranlab/mimic_iv/builtdata/sql_scripts/mimic-processing/:/scripts \
  --bind /hpc/group/kamaleswaranlab/mimic_iv/mimic-iv-3.1/:/mimic_data \
  --bind /hpc/group/kamaleswaranlab/mimic_iv:/workspace \
  postgres.sif bash -c "
    # Set environment variables manually
    export PGPORT=15432
    export PGDATA=/var/lib/postgresql/data
    export PGUSER=labuser

    echo 'Starting PostgreSQL container...'
    echo 'Port: \$PGPORT'
    echo 'Data directory: \$PGDATA'
    echo 'User: \$PGUSER'

    # Create runtime directories
    mkdir -p /tmp/postgresql_run
    mkdir -p /tmp/postgresql_log
    chmod 777 /tmp/postgresql_run /tmp/postgresql_log

    # Initialize database if empty
    if [ ! -f \"\$PGDATA/PG_VERSION\" ]; then
        echo 'Initializing PostgreSQL database...'
        initdb -D \"\$PGDATA\" \\
            --auth-local=trust \\
            --auth-host=trust \\
            --username=\"\$PGUSER\"
        
        # Configure PostgreSQL
        cat >> \"\$PGDATA/postgresql.conf\" << CONF
port = \$PGPORT
listen_addresses = 'localhost'
unix_socket_directories = '/tmp/postgresql_run'
log_directory = '/tmp/postgresql_log'
logging_collector = off
shared_preload_libraries = ''
timezone_abbreviations = ''
jit = off
CONF
        
        chmod 700 \"\$PGDATA\"
    fi

    # Start PostgreSQL server in background
    echo 'Starting PostgreSQL server...'
    postgres -D \"\$PGDATA\" \\
        -k /tmp/postgresql_run \\
        -p \$PGPORT \\
        > /tmp/postgresql_log/postgresql.log 2>&1 &
    
    # Wait for PostgreSQL to be ready
    echo 'Waiting for PostgreSQL to start...'
    for i in {1..60}; do
        if pg_isready -h /tmp/postgresql_run -p 15432 >/dev/null 2>&1; then
            echo 'PostgreSQL is ready!'
            break
        fi
        sleep 5
    done
    
    # Check if PostgreSQL started successfully
    if ! pg_isready -h /tmp/postgresql_run -p 15432 >/dev/null 2>&1; then
        echo 'ERROR: PostgreSQL failed to start'
        exit 1
    fi
    
    # Set connection variables
    export PGHOST=/tmp/postgresql_run
    export PGPORT=15432
    export PGUSER=labuser
    export PGDATABASE=mimiciv
    
    echo 'Creating database and schemas...'
    
    # Step 1: Create schemas and tables
    psql -h /tmp/postgresql_run -p 15432 -U labuser -d mimiciv -f /scripts/mimic-code/mimic-iv/buildmimic/postgres/create.sql
    
    if [ \$? -ne 0 ]; then
        echo 'ERROR: Failed to create schemas and tables'
        exit 1
    fi
    
    echo 'Schemas and tables created successfully!'
    
    # Step 2: Load data (using compressed files)
    echo 'Loading MIMIC-IV data...'
    psql -h /tmp/postgresql_run -p 15432 -U labuser -d mimiciv \
         -v ON_ERROR_STOP=1 \
         -v mimic_data_dir=/mimic_data \
         -f /scripts/mimic-code/mimic-iv/buildmimic/postgres/load_gz.sql
    
    if [ \$? -ne 0 ]; then
        echo 'ERROR: Failed to load data'
        exit 1
    fi
    
    echo 'Data loaded successfully!'
    
    # Step 3: Add constraints
    echo 'Adding constraints...'
    psql -h /tmp/postgresql_run -p 15432 -U labuser -d mimiciv \
         -v ON_ERROR_STOP=1 \
         -f /scripts/mimic-code/mimic-iv/buildmimic/postgres/constraint.sql
    
    if [ \$? -ne 0 ]; then
        echo 'ERROR: Failed to add constraints'
        exit 1
    fi
    
    echo 'Constraints added successfully!'
    
    # Step 4: Create indexes
    echo 'Creating indexes...'
    psql -h /tmp/postgresql_run -p 15432 -U labuser -d mimiciv \
         -v ON_ERROR_STOP=1 \
         -f /scripts/mimic-code/mimic-iv/buildmimic/postgres/index.sql
    
    if [ \$? -ne 0 ]; then
        echo 'ERROR: Failed to create indexes'
        exit 1
    fi
    
    echo 'Indexes created successfully!'
    
    # Verify installation
    echo 'Verifying installation...'
    psql -h /tmp/postgresql_run -p 15432 -U labuser -d mimiciv -c '\dt mimiciv_hosp.*' -c '\dt mimiciv_icu.*'
    
    echo 'MIMIC-IV setup completed successfully!'
    
    # Shutdown PostgreSQL cleanly
    echo 'Shutting down PostgreSQL...'
    pg_ctl -D /var/lib/postgresql/data -m fast stop
    
    echo 'End time: \$(date)'
"

echo "Job completed at: $(date)"
```

### 2. Submit Job

```bash
# Create logs directory
mkdir -p /hpc/group/kamaleswaranlab/mimic_iv/builtdata/scripts/logs

# Submit job
sbatch load_mimic.slurm

# Check status
squeue -u $USER

# Monitor progress
tail -f /hpc/group/kamaleswaranlab/mimic_iv/builtdata/scripts/logs/load_<JOB_ID>.out
```

### 3. Expected Timeline

- **Step 1** (create tables): ~5-10 minutes
- **Step 2** (load data): ~2-8 hours (largest step)
- **Step 3** (constraints): ~30-60 minutes
- **Step 4** (indexes): ~1-3 hours

**Total**: 4-12 hours depending on system performance

## Verify Installation

### 1. Check Database Size and Tables

```bash
# Start container to check database
apptainer exec \
  --bind /hpc/group/kamaleswaranlab/mimic_iv/builtdata/postgres_data:/var/lib/postgresql/data \
  postgres.sif bash -c "
    export PGPORT=15432 PGDATA=/var/lib/postgresql/data PGUSER=labuser
    postgres -D \$PGDATA -p \$PGPORT &
    sleep 5
    
    # Check database size
    psql -h localhost -p 15432 -U labuser -d mimiciv -c '
    SELECT pg_size_pretty(pg_database_size(\"mimiciv\")) as database_size;'
    
    # Check table counts by schema
    psql -h localhost -p 15432 -U labuser -d mimiciv -c '
    SELECT schemaname, count(*) as table_count 
    FROM pg_tables 
    WHERE schemaname LIKE \"mimiciv_%\" 
    GROUP BY schemaname 
    ORDER BY schemaname;'
    
    # Check sample record counts
    psql -h localhost -p 15432 -U labuser -d mimiciv -c '
    SELECT \"patients\" as table_name, count(*) FROM mimiciv_core.patients
    UNION ALL
    SELECT \"admissions\", count(*) FROM mimiciv_core.admissions
    UNION ALL  
    SELECT \"chartevents\", count(*) FROM mimiciv_icu.chartevents;'
"
```

### 2. Expected Results

```
Database size: ~50-100GB
Schemas: mimiciv_core, mimiciv_hosp, mimiciv_icu, mimiciv_ed
Patient count: ~300,000
Admission count: ~500,000
Chart events: ~300,000,000+
```

## Usage Examples

### 1. Interactive Analysis

```bash
# Start container for analysis
apptainer exec \
  --bind /hpc/group/kamaleswaranlab/mimic_iv/builtdata/postgres_data:/var/lib/postgresql/data \
  --bind /hpc/group/kamaleswaranlab/mimic_iv/builtdata/csv_exports:/exports \
  postgres.sif bash

# Inside container
export PGPORT=15432 PGDATA=/var/lib/postgresql/data PGUSER=labuser
postgres -D $PGDATA -p $PGPORT &
sleep 5

# Connect to database
psql -h localhost -p 15432 -U labuser -d mimiciv

# Example queries
mimiciv=# SELECT COUNT(*) FROM mimiciv_core.patients;
mimiciv=# SELECT * FROM mimiciv_core.admissions LIMIT 5;
mimiciv=# \q
```

### 2. Export Analysis Results

```bash
# Export query results to CSV
psql -h localhost -p 15432 -U labuser -d mimiciv -c "
\\copy (
  SELECT p.subject_id, p.gender, a.admittime, a.dischtime 
  FROM mimiciv_core.patients p 
  JOIN mimiciv_core.admissions a ON p.subject_id = a.subject_id 
  LIMIT 1000
) TO '/exports/sample_patients.csv' CSV HEADER"

# Files saved to: /hpc/group/kamaleswaranlab/mimic_iv/builtdata/csv_exports/
```


### Lab Usage

Once built, anyone in the lab can use the database:

```bash
# Anyone can start the container and connect
apptainer exec \
  --bind /hpc/group/kamaleswaranlab/mimic_iv/builtdata/postgres_data:/var/lib/postgresql/data \
  postgres.sif bash

# Start PostgreSQL and connect
export PGPORT=15432 PGDATA=/var/lib/postgresql/data PGUSER=labuser
postgres -D $PGDATA -p $PGPORT &
psql -h localhost -p 15432 -U labuser -d mimiciv
```

The database persists between sessions, so the build only needs to be done once!

---

## Summary

This setup provides:
- ✅ **Persistent PostgreSQL database** for MIMIC-IV data
- ✅ **No sudo/root privileges required**  
- ✅ **Containerized environment** for reproducibility
- ✅ **Multi-user lab access** with shared credentials
- ✅ **CSV export capabilities** for analysis results
- ✅ **Full PostgreSQL functionality** for complex queries

The database will contain all MIMIC-IV tables and can be used for research, analysis, and teaching purposes.
