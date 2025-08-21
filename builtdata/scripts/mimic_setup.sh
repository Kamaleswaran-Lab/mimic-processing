#!/bin/bash

export PGPORT=15432
export PGDATA=/var/lib/postgresql/data
export PGUSER=labuser
export PGHOST=localhost

echo "PostgreSQL Connection Test:"
psql -h $PGHOST -p $PGPORT -U $PGUSER -d postgres -c "SELECT version();"

echo "Creating MIMIC database..."
createdb -h $PGHOST -p $PGPORT -U $PGUSER mimiciv || echo "Database already exists"

echo "Testing MIMIC database connection..."
psql -h $PGHOST -p $PGPORT -U $PGUSER -d mimiciv -c "SELECT 'MIMIC database ready!' as status;"

echo ""
echo "SUCCESS! Use this connection string:"
echo "psql -h $PGHOST -p $PGPORT -U $PGUSER -d mimiciv"
echo ""
echo "For MIMIC build scripts, use:"
echo "psql -h $PGHOST -p $PGPORT -U $PGUSER -d mimiciv -f script.sql"
