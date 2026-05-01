FROM postgres:15

# Install pglogical extension (required for Master-Master replication)
RUN apt-get update && apt-get install -y \
    postgresql-15-pglogical \
    && rm -rf /var/lib/apt/lists/*
