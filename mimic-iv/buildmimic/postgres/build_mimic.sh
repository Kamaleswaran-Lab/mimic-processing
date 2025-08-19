#!/bin/bash
#SBATCH -J build_mimic
#SBATCH -o build_mimic.out
#SBATCH -e build_mimic.err
#SBATCH -p common
#SBATCH --mem=64G
#SBATCH -c 8
#SBATCH -t 2-00:00:00   
#SBATCH -D /hpc/dctrl/yy450   


IMG=/hpc/dctrl/yy450/postgres.sif
DB=mimiciv
MIMIC_DIR=/hpc/group/kamaleswaranlab/mimic_iv/mimic-iv-3.1
CODE_DIR=/hpc/dctrl/yy450/mimic-code/mimic-iv/buildmimic/postgres


DATA=/hpc/dctrl/yy450/pgdata
echo "Step 0: Start database..."
apptainer exec $IMG pg_ctl -D $DATA -l $DATA/logfile start -o "-k $DATA"
sleep 5



echo "Step 1: Create schema/tables..."
apptainer exec -B /work:/work -B /hpc/group:/hpc/group $IMG psql -d $DB -f $CODE_DIR/create.sql

echo "Step 2: Load data (this will take HOURS)..."
apptainer exec -B /work:/work -B /hpc/group:/hpc/group $IMG psql -d $DB \
  -v ON_ERROR_STOP=1 -v mimic_data_dir=$MIMIC_DIR -f $CODE_DIR/load_gz.sql

echo "Step 3: Constraints..."
apptainer exec -B /work:/work -B /hpc/group:/hpc/group $IMG psql -d $DB \
  -v ON_ERROR_STOP=1 -v mimic_data_dir=$MIMIC_DIR -f $CODE_DIR/constraint.sql

echo "Step 4: Indexes..."
apptainer exec -B /work:/work -B /hpc/group:/hpc/group $IMG psql -d $DB \
  -v ON_ERROR_STOP=1 -v mimic_data_dir=$MIMIC_DIR -f $CODE_DIR/index.sql

echo "✅ Done!"
