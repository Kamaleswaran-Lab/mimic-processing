#!/bin/bash

# Set environment variables manually
export PGPORT=15432
export PGDATA=/var/lib/postgresql/data
export PGUSER=labuser

echo "Starting PostgreSQL container..."
echo "Port: $PGPORT"
echo "Data directory: $PGDATA"
echo "User: $PGUSER"

# Create runtime directories
mkdir -p /tmp/postgresql_run
mkdir -p /tmp/postgresql_log
chmod 777 /tmp/postgresql_run /tmp/postgresql_log

# Initialize database if empty
if [ ! -f "$PGDATA/PG_VERSION" ]; then
    echo "Initializing PostgreSQL database..."
    initdb -D "$PGDATA" \
        --auth-local=trust \
        --auth-host=trust \
        --username="$PGUSER"
    
    # Configure PostgreSQL
    cat >> "$PGDATA/postgresql.conf" << CONF
port = $PGPORT
listen_addresses = 'localhost'
unix_socket_directories = '/tmp/postgresql_run'
log_directory = '/tmp/postgresql_log'
logging_collector = off
shared_preload_libraries = ''
timezone_abbreviations = ''
jit = off
CONF
    
    chmod 700 "$PGDATA"
fi

# Start PostgreSQL server
echo "Starting PostgreSQL server..."
postgres -D "$PGDATA" \
    -k /tmp/postgresql_run \
    -p $PGPORT \
    > /tmp/postgresql_log/postgresql.log 2>&1 &

# Wait for server to start
echo "Waiting for PostgreSQL to start..."
for i in {1..30}; do
    if pg_isready -h /tmp/postgresql_run -p $PGPORT >/dev/null 2>&1; then
        echo "PostgreSQL is ready!"
        break
    fi
    sleep 1
done

# Create mimiciv database if it doesn't exist
if ! psql -h /tmp/postgresql_run -p "$PGPORT" -U "$PGUSER" -lqt | cut -d \| -f 1 | grep -qw "mimiciv" 2>/dev/null; then
    echo "Creating mimiciv database..."
    createdb -h /tmp/postgresql_run -p "$PGPORT" -U "$PGUSER" mimiciv
fi

echo ""
echo "============================="
echo "Lab PostgreSQL Server Ready!"
echo "============================="
echo "Connect with: psql -h /tmp/postgresql_run -p $PGPORT -U $PGUSER -d mimiciv"
echo ""

# Start interactive shell
#exec /bin/bash
