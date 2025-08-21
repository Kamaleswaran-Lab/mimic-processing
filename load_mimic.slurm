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
    psql -h /tmp/postgresql_run -p 15432 -U labuser -d mimiciv -f /scripts/mimic-iv/buildmimic/postgres/create.sql
    
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
         -f /scripts/mimic-iv/buildmimic/postgres/load_gz.sql
    
    if [ \$? -ne 0 ]; then
        echo 'ERROR: Failed to load data'
        exit 1
    fi
    
    echo 'Data loaded successfully!'
    
    # Step 3: Add constraints
    echo 'Adding constraints...'
    psql -h /tmp/postgresql_run -p 15432 -U labuser -d mimiciv \
         -v ON_ERROR_STOP=1 \
         -f /scripts/mimic-iv/buildmimic/postgres/constraint.sql
    
    if [ \$? -ne 0 ]; then
        echo 'ERROR: Failed to add constraints'
        exit 1
    fi
    
    echo 'Constraints added successfully!'
    
    # Step 4: Create indexes
    echo 'Creating indexes...'
    psql -h /tmp/postgresql_run -p 15432 -U labuser -d mimiciv \
         -v ON_ERROR_STOP=1 \
         -f /scripts/mimic-iv/buildmimic/postgres/index.sql
    
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
