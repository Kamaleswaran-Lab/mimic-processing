apptainer exec \
  --bind /hpc/group/kamaleswaranlab/mimic_iv/builtdata/postgres_data:/var/lib/postgresql/data \
  --bind /hpc/group/kamaleswaranlab/mimic_iv/builtdata/csv_exports:/exports \
  --bind /hpc/group/kamaleswaranlab/mimic_iv/builtdata/sql_scripts/mimic-processing/:/scripts \
  --bind /hpc/group/kamaleswaranlab/mimic_iv/mimic-iv-3.1/:/mimic_data \
  --bind $(pwd)/run_postgres.sh:/run_postgres.sh \
  postgres.sif /run_postgres.sh

