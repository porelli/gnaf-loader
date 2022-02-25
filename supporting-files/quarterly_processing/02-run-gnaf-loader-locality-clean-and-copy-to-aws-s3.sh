#!/usr/bin/env bash

# need a Python 3.6+ environment with Psycopg2 (run 01_setup_conda_env.sh to create Conda environment)
conda deactivate
conda activate geo

# get the directory this script is running from
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# ---------------------------------------------------------------------------------------------------------------------
# edit these to taste - NOTE: you can't use "~" for your home folder, Postgres doesn't like it
# ---------------------------------------------------------------------------------------------------------------------

AWS_PROFILE="default"
OUTPUT_FOLDER="/Users/$(whoami)/tmp/geoscape_202202"
GNAF_PATH="/Users/$(whoami)/Downloads/g-naf_feb22_allstates_gda94_psv_105"
BDYS_PATH="/Users/$(whoami)/Downloads/FEB22_AdminBounds_GDA94_SHP"

echo "---------------------------------------------------------------------------------------------------------------------"
echo "Run gnaf-loader and locality boundary clean"
echo "---------------------------------------------------------------------------------------------------------------------"

python3 /Users/$(whoami)/git/minus34/gnaf-loader/load-gnaf.py --pgport=5432 --pgdb=geo --max-processes=6 --gnaf-tables-path="${GNAF_PATH}" --admin-bdys-path="${BDYS_PATH}"
python3 /Users/$(whoami)/git/iag_geo/psma-admin-bdys/locality-clean.py --pgport=5432 --pgdb=geo --max-processes=6 --output-path=${OUTPUT_FOLDER}

echo "---------------------------------------------------------------------------------------------------------------------"
echo "dump postgres schemas to a local folder"
echo "---------------------------------------------------------------------------------------------------------------------"

mkdir -p "${OUTPUT_FOLDER}"

/Applications/Postgres.app/Contents/Versions/13/bin/pg_dump -Fc -d geo -n gnaf_202202 -p 5432 -U postgres -f "${OUTPUT_FOLDER}/gnaf-202202.dmp" --no-owner
echo "GNAF schema exported to dump file"
/Applications/Postgres.app/Contents/Versions/13/bin/pg_dump -Fc -d geo -n admin_bdys_202202 -p 5432 -U postgres -f "${OUTPUT_FOLDER}/admin-bdys-202202.dmp" --no-owner
echo "Admin Bdys schema exported to dump file"

echo "---------------------------------------------------------------------------------------------------------------------"
echo "copy Postgres dump files to AWS S3 and allow public read access (requires AWSCLI installed & AWS credentials setup)"
echo "---------------------------------------------------------------------------------------------------------------------"

aws --profile=${AWS_PROFILE} s3 sync ${OUTPUT_FOLDER} s3://minus34.com/opendata/geoscape-202202 --exclude "*" --include "*.dmp" --acl public-read

echo "---------------------------------------------------------------------------------------------------------------------"
echo "create parquet versions of GNAF and Admin Bdys and upload to AWS S3"
echo "---------------------------------------------------------------------------------------------------------------------"

# first - activate or create Conda environment with Apache Spark + Sedona
#. /Users/$(whoami)/git/iag_geo/spark_testing/apache_sedona/01_setup_sedona.sh

conda activate sedona

python ${SCRIPT_DIR}/../../spark/02_export_gnaf_and_admin_bdys_to_s3.py

aws --profile=${AWS_PROFILE} s3 sync ${SCRIPT_DIR}/../../spark/data s3://minus34.com/opendata/geoscape-202202/parquet --acl public-read
