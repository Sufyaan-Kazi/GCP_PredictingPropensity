#!/bin/sh
# Copyright 2018 Google LLC. This software is provided as-is, without warranty or representation for any use or purpose. Your use of it is subject to your agreements with Google.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# “Copyright 2018 Google LLC. This software is provided as-is, without warranty or representation for any use or purpose.
#  Your use of it is subject to your agreements with Google.”
#

# Author: Sufyaan Kazi
# Date: November 2020
# This is an scrupt to automate the instructions here: https://cloud.google.com/solutions/predicting-customer-propensity-to-buy

## Enable GCloud APIS
enableAPIs() {
  if [ "$#" -eq 0 ]; then
    echo "Usage: $0 APIs" >&2
    echo "e.g. $0 iam compute" >&2
    exit 1
  fi

  #echo "Required apis for this project are: $@"
  declare -a REQ_APIS=(${@})

  local ENABLED_APIS=$(gcloud services list --enabled | grep -v NAME | sort | cut -d " " -f1)
  #echo "Current APIs enabled are: ${ENABLED_APIS}"

  for api in "${REQ_APIS[@]}"
  do
    #printf "\tChecking to see if ${api} api is enabled on this project\n"
    local API_EXISTS=$(echo ${ENABLED_APIS} | grep ${api}.googleapis.com | wc -l)
    if [ ${API_EXISTS} -eq 0 ]
    then
      echo "*** Enabling ${api} API"
      gcloud services enable "${api}.googleapis.com"
    fi
  done
}

#
# Handle an error in the script
#
abort()
{
  echo >&2 '
  ***************
  *** ABORTED ***
  ***************
  '
  echo "An error occurred. Exiting..." >&2
  echo "${PROGNAME}: ${1:-"Unknown Error"}" 1>&2
  local lineno=$1
  local msg=$2
  echo "Failed at $lineno: $msg"
  exit 1
}

main() {
  #Enable Required GCP APIs
  local APIS="ml"
  enableAPIs "${APIS}"

  #Set up some vars
  local PROJECT=$(gcloud config list project --format "value(core.project)")
  local BUCKET=${PROJECT}-bucket
  local REGION=us-central1
  local DATASET_NAME=bqml

  #Create dataset with sample Google Analytics data
  echo "Preparing Sample data"
  bq --location=US rm -r -f --dataset ${PROJECT}:${DATASET_NAME} || true
  bq --location=US mk --dataset ${PROJECT}:${DATASET_NAME}
  bq query --use_legacy_sql=false < ./create_propensity_data.sql
  bq query --use_legacy_sql=false < ./train_model.sql
  echo "Evaluating model"
  bq query --use_legacy_sql=false < ./eval_model.sql
  echo "Get Batch Predictions"
  bq query --use_legacy_sql=false < ./get_batch_predictions.sql

  # Get Online Predictions
  echo "Deploying BQML model to AI Platforms"
  gsutil rm -rf gs://${BUCKET} || true
  gsutil mb gs://${BUCKET}
  gsutil ls gs://${BUCKET}
  bq extract -m bqml.rpm_bqml_model "gs://${BUCKET}/V_1"
  gcloud ai-platform models delete rpm_bqml_model -q || true
  gcloud ai-platform models create rpm_bqml_model
  gcloud ai-platform versions create --model=rpm_bqml_model V_1 --framework=tensorflow --python-version=3.7 --runtime-version=1.15 --origin="gs://${BUCKET}/V_1/" --staging-bucket="gs://${BUCKET}"

  echo "Getting Online model"
  echo "{\"bounces\": 0, \"time_on_site\": 7363}" > input.json
  gcloud ai-platform predict --model rpm_bqml_model --version V_1 --json-instances input.json
}

#Run the Script
trap 'abort ${LINENO} "$BASH_COMMAND' ERR
SECONDS=0
PROGNAME=$(basename ${0})
main
printf "\n$PROGNAME complete in %s seconds.\n" "${SECONDS}"