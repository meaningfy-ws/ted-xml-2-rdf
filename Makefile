SHELL=/bin/bash -o pipefail
BUILD_PRINT = \e[1;34mSTEP:
END_BUILD_PRINT = \e[0m

CURRENT_UID := $(shell id -u)
export CURRENT_UID
# These are constants used for make targets so we can start prod and staging services on the same machine
ENV_FILE := .env

# include .env files if they exist
-include .env

PROJECT_PATH = $(shell pwd)
AIRFLOW_INFRA_FOLDER ?= ${PROJECT_PATH}/.airflow
RML_MAPPER_PATH = ${PROJECT_PATH}/.rmlmapper/rmlmapper.jar
XML_PROCESSOR_PATH = ${PROJECT_PATH}/.saxon/saxon-he-10.9.jar
LIMES_ALIGNMENT_PATH = $(PROJECT_PATH)/.limes/limes.jar
HOSTNAME = $(shell hostname)
CAROOT = $(shell pwd)/infra/traefik/certs

#-----------------------------------------------------------------------------
# Dev commands
#-----------------------------------------------------------------------------
install:
	@ echo -e "$(BUILD_PRINT)Installing the requirements$(END_BUILD_PRINT)"
	@ pip install --upgrade pip
	@ pip install --no-cache-dir -r requirements.txt --constraint "https://raw.githubusercontent.com/apache/airflow/constraints-2.5.1/constraints-no-providers-3.8.txt"

install-dev:
	@ echo -e "$(BUILD_PRINT)Installing the dev requirements$(END_BUILD_PRINT)"
	@ pip install --upgrade pip
	@ pip install --no-cache-dir -r requirements.dev.txt --constraint "https://raw.githubusercontent.com/apache/airflow/constraints-2.5.1/constraints-no-providers-3.8.txt"

test: test-unit

test-unit:
	@ echo -e "$(BUILD_PRINT)Unit Testing ...$(END_BUILD_PRINT)"
	@ tox -e unit

test-features:
	@ echo -e "$(BUILD_PRINT)Gherkin Features Testing ...$(END_BUILD_PRINT)"
	@ tox -e features

test-e2e:
	@ echo -e "$(BUILD_PRINT)End to End Testing ...$(END_BUILD_PRINT)"
	@ tox -e e2e

test-all-parallel:
	@ echo -e "$(BUILD_PRINT)Complete Testing ...$(END_BUILD_PRINT)"
	@ tox -p

test-all:
	@ echo -e "$(BUILD_PRINT)Complete Testing ...$(END_BUILD_PRINT)"
	@ tox

build-externals:
	@ echo -e "$(BUILD_PRINT)Creating the necessary volumes, networks and folders and setting the special rights"
	@ docker network create proxy-net || true
	@ docker network create common-ext-${ENVIRONMENT} || true


#-----------------------------------------------------------------------------
# SERVER SERVICES
#-----------------------------------------------------------------------------
start-traefik: build-externals
	@ echo -e "$(BUILD_PRINT)Starting the Traefik services $(END_BUILD_PRINT)"
	@ docker-compose -p common --file ./infra/traefik/docker-compose.yml --env-file ${ENV_FILE} up -d

stop-traefik:
	@ echo -e "$(BUILD_PRINT)Stopping the Traefik services $(END_BUILD_PRINT)"
	@ docker-compose -p common --file ./infra/traefik/docker-compose.yml --env-file ${ENV_FILE} down

start-portainer: build-externals
	@ echo -e "$(BUILD_PRINT)Starting the Portainer services $(END_BUILD_PRINT)"
	@ docker-compose -p common --file ./infra/portainer/docker-compose.yml --env-file ${ENV_FILE} up -d

stop-portainer:
	@ echo -e "$(BUILD_PRINT)Stopping the Portainer services $(END_BUILD_PRINT)"
	@ docker-compose -p common --file ./infra/portainer/docker-compose.yml --env-file ${ENV_FILE} down

start-server-services: | start-traefik start-portainer
stop-server-services: | stop-traefik stop-portainer

#-----------------------------------------------------------------------------
# PROJECT SERVICES
#-----------------------------------------------------------------------------
create-env-airflow:
	@ echo -e "$(BUILD_PRINT) Create Airflow env $(END_BUILD_PRINT)"
	@ echo -e "$(BUILD_PRINT) ${AIRFLOW_INFRA_FOLDER} ${ENVIRONMENT} $(END_BUILD_PRINT)"
	@ mkdir -p ${AIRFLOW_INFRA_FOLDER}/logs ${AIRFLOW_INFRA_FOLDER}/plugins
	@ ln -s -f ${PROJECT_PATH}/.env ${AIRFLOW_INFRA_FOLDER}/.env
	@ ln -s -f -n ${PROJECT_PATH}/dags ${AIRFLOW_INFRA_FOLDER}/dags
	@ ln -s -f -n ${PROJECT_PATH}/ted_sws ${AIRFLOW_INFRA_FOLDER}/ted_sws
	@ chmod 777 ${AIRFLOW_INFRA_FOLDER}/logs ${AIRFLOW_INFRA_FOLDER}/plugins ${AIRFLOW_INFRA_FOLDER}/.env
	@ cp requirements.txt ./infra/airflow/
	@ cp -r ted_sws ./infra/airflow/
	@ cp -r dags ./infra/airflow/
	@ cp -r libraries ./infra/airflow/


build-airflow: guard-ENVIRONMENT create-env-airflow build-externals
	@ echo -e "$(BUILD_PRINT) Build Airflow services $(END_BUILD_PRINT)"
	@ docker build -t meaningfy/airflow ./infra/airflow/
	@ docker-compose -p ${ENVIRONMENT} --file ./infra/airflow/docker-compose.yaml --env-file ${ENV_FILE} up -d --force-recreate

#--------------------------------------AIRFLOW_CLUSTER----BEGIN----TARGETS----------------------------------------------

create-env-airflow-cluster:
	@ echo -e "$(BUILD_PRINT) Create Airflow env $(END_BUILD_PRINT)"
	@ echo -e "$(BUILD_PRINT) ${AIRFLOW_INFRA_FOLDER} ${ENVIRONMENT} $(END_BUILD_PRINT)"
	@ mkdir -p ${AIRFLOW_INFRA_FOLDER}/logs ${AIRFLOW_INFRA_FOLDER}/plugins
	@ ln -s -f ${PROJECT_PATH}/.env ${AIRFLOW_INFRA_FOLDER}/.env
	@ ln -s -f -n ${PROJECT_PATH}/dags ${AIRFLOW_INFRA_FOLDER}/dags
	@ ln -s -f -n ${PROJECT_PATH}/ted_sws ${AIRFLOW_INFRA_FOLDER}/ted_sws
	@ chmod 777 ${AIRFLOW_INFRA_FOLDER}/logs ${AIRFLOW_INFRA_FOLDER}/plugins ${AIRFLOW_INFRA_FOLDER}/.env
	@ cp requirements.txt ./infra/airflow-cluster/

build-airflow-cluster: guard-ENVIRONMENT create-env-airflow-cluster build-externals
	@ echo -e "$(BUILD_PRINT) Build Airflow Common Image $(END_BUILD_PRINT)"
	@ docker build -t meaningfy/airflow ./infra/airflow-cluster/

start-airflow-master: build-externals
	@ echo -e "$(BUILD_PRINT)Starting Airflow Master $(END_BUILD_PRINT)"
	@ docker-compose -p ${ENVIRONMENT} --file ./infra/airflow-cluster/docker-compose.yaml --env-file ${ENV_FILE} up -d --force-recreate

start-airflow-worker: build-externals
	@ echo -e "$(BUILD_PRINT)Starting Airflow Worker $(END_BUILD_PRINT)"
	@ docker-compose -p ${ENVIRONMENT} --file ./infra/airflow-cluster/docker-compose-worker.yaml --env-file ${ENV_FILE} up -d

stop-airflow-master:
	@ echo -e "$(BUILD_PRINT)Stopping Airflow Master $(END_BUILD_PRINT)"
	@ docker-compose -p ${ENVIRONMENT} --file ./infra/airflow-cluster/docker-compose.yaml --env-file ${ENV_FILE} down

stop-airflow-worker:
	@ echo -e "$(BUILD_PRINT)Stopping Airflow Worker $(END_BUILD_PRINT)"
	@ docker-compose -p ${ENVIRONMENT} --file ./infra/airflow-cluster/docker-compose-worker.yaml --env-file ${ENV_FILE} down


#---------------------------------------AIRFLOW_CLUSTER----END----TARGETS-----------------------------------------------

start-airflow: build-externals
	@ echo -e "$(BUILD_PRINT)Starting Airflow services $(END_BUILD_PRINT)"
	@ docker-compose -p ${ENVIRONMENT} --file ./infra/airflow/docker-compose.yaml --env-file ${ENV_FILE} up -d

stop-airflow:
	@ echo -e "$(BUILD_PRINT)Stopping Airflow services $(END_BUILD_PRINT)"
	@ docker-compose -p ${ENVIRONMENT} --file ./infra/airflow/docker-compose.yaml --env-file ${ENV_FILE} down

#	------------------------
start-allegro-graph: build-externals
	@ echo -e "$(BUILD_PRINT)Starting Allegro-Graph services $(END_BUILD_PRINT)"
	@ docker-compose -p ${ENVIRONMENT} --file ./infra/allegro-graph/docker-compose.yml --env-file ${ENV_FILE} up -d

stop-allegro-graph:
	@ echo -e "$(BUILD_PRINT)Stopping Allegro-Graph services $(END_BUILD_PRINT)"
	@ docker-compose -p ${ENVIRONMENT} --file ./infra/allegro-graph/docker-compose.yml --env-file ${ENV_FILE} down

#	------------------------
start-fuseki: build-externals
	@ echo -e "$(BUILD_PRINT)Starting Fuseki services $(END_BUILD_PRINT)"
	@ docker-compose -p ${ENVIRONMENT} --file ./infra/fuseki/docker-compose.yml --env-file ${ENV_FILE} up -d

stop-fuseki:
	@ echo -e "$(BUILD_PRINT)Stopping Fuseki services $(END_BUILD_PRINT)"
	@ docker-compose -p ${ENVIRONMENT} --file ./infra/fuseki/docker-compose.yml --env-file ${ENV_FILE} down

#	------------------------
start-sftp: build-externals
	@ echo -e "$(BUILD_PRINT)Starting SFTP services $(END_BUILD_PRINT)"
	@ docker-compose -p ${ENVIRONMENT} --file ./infra/sftp/docker-compose.yml --env-file ${ENV_FILE} up -d

stop-sftp:
	@ echo -e "$(BUILD_PRINT)Stopping SFTP services $(END_BUILD_PRINT)"
	@ docker-compose -p ${ENVIRONMENT} --file ./infra/sftp/docker-compose.yml --env-file ${ENV_FILE} down

#	------------------------
build-elasticsearch: build-externals
	@ echo -e "$(BUILD_PRINT) Build Elasticsearch services $(END_BUILD_PRINT)"
	@ docker-compose -p ${ENVIRONMENT} --file ./infra/elasticsearch/docker-compose.yml --env-file ${ENV_FILE} build --no-cache --force-rm
	@ docker-compose -p ${ENVIRONMENT} --file ./infra/elasticsearch/docker-compose.yml --env-file ${ENV_FILE} up -d --force-recreate

start-elasticsearch: build-externals
	@ echo -e "$(BUILD_PRINT)Starting the Elasticsearch services $(END_BUILD_PRINT)"
	@ docker-compose -p ${ENVIRONMENT} --file ./infra/elasticsearch/docker-compose.yml --env-file ${ENV_FILE} up -d

stop-elasticsearch:
	@ echo -e "$(BUILD_PRINT)Stopping the Elasticsearch services $(END_BUILD_PRINT)"
	@ docker-compose -p ${ENVIRONMENT} --file ./infra/elasticsearch/docker-compose.yml --env-file ${ENV_FILE} down


start-minio: build-externals
	@ echo -e "$(BUILD_PRINT)Starting the Minio services $(END_BUILD_PRINT)"
	@ docker-compose -p ${ENVIRONMENT} --file ./infra/minio/docker-compose.yml --env-file ${ENV_FILE} up -d

stop-minio:
	@ echo -e "$(BUILD_PRINT)Stopping the Minio services $(END_BUILD_PRINT)"
	@ docker-compose -p ${ENVIRONMENT} --file ./infra/minio/docker-compose.yml --env-file ${ENV_FILE} down


start-mongo: build-externals
	@ echo -e "$(BUILD_PRINT)Starting the Mongo services $(END_BUILD_PRINT)"
	@ docker-compose -p ${ENVIRONMENT} --file ./infra/mongo/docker-compose.yml --env-file ${ENV_FILE} up -d

stop-mongo:
	@ echo -e "$(BUILD_PRINT)Stopping the Mongo services $(END_BUILD_PRINT)"
	@ docker-compose -p ${ENVIRONMENT} --file ./infra/mongo/docker-compose.yml --env-file ${ENV_FILE} down

start-metabase: build-externals
	@ echo -e "$(BUILD_PRINT)Starting the Metabase services $(END_BUILD_PRINT)"
	@ docker-compose -p metabase-${ENVIRONMENT} --file ./infra/metabase/docker-compose.yml --env-file ${ENV_FILE} up -d

stop-metabase:
	@ echo -e "$(BUILD_PRINT)Stopping the Metabase services $(END_BUILD_PRINT)"
	@ docker-compose -p metabase-${ENVIRONMENT} --file ./infra/metabase/docker-compose.yml --env-file ${ENV_FILE} down

init-rml-mapper:
	@ echo -e "RMLMapper folder initialisation!"
	@ mkdir -p ./.rmlmapper
	@ wget -c https://github.com/RMLio/rmlmapper-java/releases/download/v6.2.2/rmlmapper-6.2.2-r371-all.jar -O ./.rmlmapper/rmlmapper.jar

init-limes:
	@ echo -e "Limes folder initialisation!"
	@ mkdir -p ./.limes
	@ wget -c https://github.com/dice-group/LIMES/releases/download/1.7.9/limes.jar -P ./.limes

init-saxon:
	@ echo -e "$(BUILD_PRINT)Saxon folder initialization $(END_BUILD_PRINT)"
	@ wget -c https://github.com/Saxonica/Saxon-HE/releases/download/SaxonHE10-9/SaxonHE10-9J.zip -P .saxon/
	@ cd .saxon && unzip SaxonHE10-9J.zip && rm -rf SaxonHE10-9J.zip

start-project-services: | start-airflow start-mongo init-rml-mapper init-limes start-allegro-graph start-metabase
stop-project-services: | stop-airflow stop-mongo stop-allegro-graph stop-metabase

#-----------------------------------------------------------------------------
# VAULT SERVICES
#-----------------------------------------------------------------------------
# Testing whether an env variable is set or not
guard-%:
	@ if [ "${${*}}" = "" ]; then \
        echo -e "$(BUILD_PRINT)Environment variable $* not set $(END_BUILD_PRINT)"; \
        exit 1; \
	fi

# Testing that vault is installed
vault-installed: #; @which vault1 > /dev/null
	@ if ! hash vault 2>/dev/null; then \
        echo -e "$(BUILD_PRINT)Vault is not installed, refer to https://www.vaultproject.io/downloads $(END_BUILD_PRINT)"; \
        exit 1; \
	fi
# Get secrets in dotenv format
staging-dotenv-file: guard-VAULT_ADDR guard-VAULT_TOKEN vault-installed
	@ echo -e "$(BUILD_PRINT)Creating .env.staging file $(END_BUILD_PRINT)"
	@ echo VAULT_ADDR=${VAULT_ADDR} > .env
	@ echo VAULT_TOKEN=${VAULT_TOKEN} >> .env
	@ echo ENVIRONMENT=staging >> .env
	@ echo SUBDOMAIN=staging. >> .env
	@ echo RML_MAPPER_PATH=${RML_MAPPER_PATH} >> .env
	@ echo LIMES_ALIGNMENT_PATH=${LIMES_ALIGNMENT_PATH} >> .env
	@ echo XML_PROCESSOR_PATH=${XML_PROCESSOR_PATH} >> .env
	@ echo AIRFLOW_INFRA_FOLDER=~/airflow-infra/staging >> .env
	@ echo AIRFLOW_WORKER_HOSTNAME=${HOSTNAME} >> .env
	@ vault kv get -format="json" ted-staging/airflow | jq -r ".data.data | keys[] as \$$k | \"\(\$$k)=\(.[\$$k])\"" >> .env
	@ vault kv get -format="json" ted-staging/mongo-db | jq -r ".data.data | keys[] as \$$k | \"\(\$$k)=\(.[\$$k])\"" >> .env
	@ vault kv get -format="json" ted-staging/metabase | jq -r ".data.data | keys[] as \$$k | \"\(\$$k)=\(.[\$$k])\"" >> .env
	@ vault kv get -format="json" ted-staging/ted-sws | jq -r ".data.data | keys[] as \$$k | \"\(\$$k)=\(.[\$$k])\"" >> .env
	@ vault kv get -format="json" ted-staging/agraph | jq -r ".data.data | keys[] as \$$k | \"\(\$$k)=\(.[\$$k])\"" >> .env
	@ vault kv get -format="json" ted-staging/fuseki | jq -r ".data.data | keys[] as \$$k | \"\(\$$k)=\(.[\$$k])\"" >> .env
	@ vault kv get -format="json" ted-staging/github | jq -r ".data.data | keys[] as \$$k | \"\(\$$k)=\(.[\$$k])\"" >> .env
	@ vault kv get -format="json" ted-staging/minio | jq -r ".data.data | keys[] as \$$k | \"\(\$$k)=\(.[\$$k])\"" >> .env


dev-dotenv-file: guard-VAULT_ADDR guard-VAULT_TOKEN vault-installed
	@ echo -e "$(BUILD_PRINT)Create .env file $(END_BUILD_PRINT)"
	@ echo VAULT_ADDR=${VAULT_ADDR} > .env
	@ echo VAULT_TOKEN=${VAULT_TOKEN} >> .env
	@ echo ENVIRONMENT=dev >> .env
	@ echo SUBDOMAIN= >> .env
	@ echo RML_MAPPER_PATH=${RML_MAPPER_PATH} >> .env
	@ echo LIMES_ALIGNMENT_PATH=${LIMES_ALIGNMENT_PATH} >> .env
	@ echo XML_PROCESSOR_PATH=${XML_PROCESSOR_PATH} >> .env
	@ echo AIRFLOW_INFRA_FOLDER=${AIRFLOW_INFRA_FOLDER} >> .env
	@ echo AIRFLOW_WORKER_HOSTNAME=${HOSTNAME} >> .env
	@ vault kv get -format="json" ted-dev/airflow | jq -r ".data.data | keys[] as \$$k | \"\(\$$k)=\(.[\$$k])\"" >> .env
	@ vault kv get -format="json" ted-dev/mongo-db | jq -r ".data.data | keys[] as \$$k | \"\(\$$k)=\(.[\$$k])\"" >> .env
	@ vault kv get -format="json" ted-dev/metabase | jq -r ".data.data | keys[] as \$$k | \"\(\$$k)=\(.[\$$k])\"" >> .env
	@ vault kv get -format="json" ted-dev/agraph | jq -r ".data.data | keys[] as \$$k | \"\(\$$k)=\(.[\$$k])\"" >> .env
	@ vault kv get -format="json" ted-dev/fuseki | jq -r ".data.data | keys[] as \$$k | \"\(\$$k)=\(.[\$$k])\"" >> .env
	@ vault kv get -format="json" ted-dev/ted-sws | jq -r ".data.data | keys[] as \$$k | \"\(\$$k)=\(.[\$$k])\"" >> .env
	@ vault kv get -format="json" ted-dev/github | jq -r ".data.data | keys[] as \$$k | \"\(\$$k)=\(.[\$$k])\"" >> .env
	@ vault kv get -format="json" ted-dev/minio | jq -r ".data.data | keys[] as \$$k | \"\(\$$k)=\(.[\$$k])\"" >> .env


prod-dotenv-file: guard-VAULT_ADDR guard-VAULT_TOKEN vault-installed
	@ echo -e "$(BUILD_PRINT)Create .env file $(END_BUILD_PRINT)"
	@ echo VAULT_ADDR=${VAULT_ADDR} > .env
	@ echo VAULT_TOKEN=${VAULT_TOKEN} >> .env
	@ echo ENVIRONMENT=prod >> .env
	@ echo SUBDOMAIN= >> .env
	@ echo RML_MAPPER_PATH=${RML_MAPPER_PATH} >> .env
	@ echo LIMES_ALIGNMENT_PATH=${LIMES_ALIGNMENT_PATH} >> .env
	@ echo XML_PROCESSOR_PATH=${XML_PROCESSOR_PATH} >> .env
	@ echo AIRFLOW_INFRA_FOLDER=~/airflow-infra/prod >> .env
	@ echo AIRFLOW_WORKER_HOSTNAME=${HOSTNAME} >> .env
	@ echo AIRFLOW_CELERY_WORKER_CONCURRENCY=32 >> .env
	@ vault kv get -format="json" ted-prod/airflow | jq -r ".data.data | keys[] as \$$k | \"\(\$$k)=\(.[\$$k])\"" >> .env
	@ vault kv get -format="json" ted-prod/mongo-db | jq -r ".data.data | keys[] as \$$k | \"\(\$$k)=\(.[\$$k])\"" >> .env
	@ vault kv get -format="json" ted-prod/metabase | jq -r ".data.data | keys[] as \$$k | \"\(\$$k)=\(.[\$$k])\"" >> .env
	@ vault kv get -format="json" ted-prod/agraph | jq -r ".data.data | keys[] as \$$k | \"\(\$$k)=\(.[\$$k])\"" >> .env
	@ vault kv get -format="json" ted-prod/fuseki | jq -r ".data.data | keys[] as \$$k | \"\(\$$k)=\(.[\$$k])\"" >> .env
	@ vault kv get -format="json" ted-prod/ted-sws | jq -r ".data.data | keys[] as \$$k | \"\(\$$k)=\(.[\$$k])\"" >> .env
	@ vault kv get -format="json" ted-prod/github | jq -r ".data.data | keys[] as \$$k | \"\(\$$k)=\(.[\$$k])\"" >> .env
	@ vault kv get -format="json" ted-prod/minio | jq -r ".data.data | keys[] as \$$k | \"\(\$$k)=\(.[\$$k])\"" >> .env

local-dotenv-file: rml-mapper-path-add-dotenv-file

rml-mapper-path-add-dotenv-file:
	@ echo -e "$(BUILD_PRINT)Add rml-mapper path to local .env file $(END_BUILD_PRINT)"
	@ sed -i '/^RML_MAPPER_PATH/d' .env
	@ echo RML_MAPPER_PATH=${RML_MAPPER_PATH} >> .env

#clean-mongo-db:
#	@ export PYTHONPATH=$(PWD) && python ./tests/clean_mongo_db.py


#build-open-semantic-search:
#	@ echo -e "Build open-semantic-search"
#	@ cd infra && rm -rf open-semantic-search
#	@ cd infra && git clone --recurse-submodules --remote-submodules https://github.com/opensemanticsearch/open-semantic-search.git
#	@ cd infra/open-semantic-search/ && ./build-deb
#	@ echo -e "Patch open-semantic-search configs"
#	@ cat infra/docker-compose-configs/open-semantic-search-compose-patch.yml > infra/open-semantic-search/docker-compose.yml
#	@ cd infra/open-semantic-search/ && docker-compose rm -fsv
#	@ cd infra/open-semantic-search/ && docker-compose build
#
#start-open-semantic-search:
#	@ echo -e "Start open-semantic-search"
#	@ cd infra/open-semantic-search/ && docker-compose up -d
#
#
#stop-open-semantic-search:
#	@ echo -e "Stop open-semantic-search"
#	@ cd infra/open-semantic-search/ && docker-compose down
#
#
#start-silk-service:
#	@ echo -e "Start silk service"
#	@ cd infra/silk/ && docker-compose up -d
#
#stop-silk-service:
#	@ echo -e "Stop silk service"
#	@ cd infra/silk/ && docker-compose down


#-----------------------------------------------------------------------------
# API Service commands
#-----------------------------------------------------------------------------
build-all-apis: build-digest_service-api

start-all-apis: start-digest_service-api

stop-all-apis: stop-digest_service-api

create-env-digest-api:
	@ cp requirements.txt ./infra/digest_api/digest_service/project_requirements.txt
	@ cp -r ted_sws ./infra/digest_api/

build-digest_service-api: create-env-digest-api
	@ echo -e "$(BUILD_PRINT) Build digest_service API service $(END_BUILD_PRINT)"
	@ docker-compose -p common --file infra/digest_api/docker-compose.yml --env-file ${ENV_FILE} build --no-cache --force-rm
	@ rm -rf ./infra/digest_api/ted_sws || true
	@ docker-compose -p common --file infra/digest_api/docker-compose.yml --env-file ${ENV_FILE} up -d --force-recreate

start-digest_service-api:
	@ echo -e "$(BUILD_PRINT)Starting digest_service API service $(END_BUILD_PRINT)"
	@ docker-compose -p common --file infra/digest_api/docker-compose.yml --env-file ${ENV_FILE} up -d

stop-digest_service-api:
	@ echo -e "$(BUILD_PRINT)Stopping digest_service API service $(END_BUILD_PRINT)"
	@ docker-compose -p common --file infra/digest_api/docker-compose.yml --env-file ${ENV_FILE} down


dump-mongodb:
	@ echo -e "Start dump data from mongodb."
	@ docker exec -i mongodb-${ENVIRONMENT} /usr/bin/mongodump --username ${ME_CONFIG_MONGODB_ADMINUSERNAME} --password ${ME_CONFIG_MONGODB_ADMINPASSWORD} --authenticationDatabase admin --db aggregates_db --out /mongodb_dump
	@ mv ./mongodb_dump/aggregates_db "./mongodb_dump/aggregates_db_$$(date +"%Y_%m_%d_%H_%M_%S")" 2>/dev/null || true
	@ docker cp mongodb-${ENVIRONMENT}:/mongodb_dump .
	@ docker exec -it mongodb-${ENVIRONMENT} rm -rf mongodb_dump
	@ echo -e "Finish dump data from mongodb."


restore-mongodb:
	@ echo -e "Start restore data in mongodb."
	@ docker cp ./mongodb_dump mongodb-${ENVIRONMENT}:/mongodb_dump
	@ docker exec -i mongodb-${ENVIRONMENT} /usr/bin/mongorestore --username ${ME_CONFIG_MONGODB_ADMINUSERNAME} --password ${ME_CONFIG_MONGODB_ADMINPASSWORD} --authenticationDatabase admin --db aggregates_db /mongodb_dump/aggregates_db
	@ docker exec -it mongodb-${ENVIRONMENT} rm -rf mongodb_dump
	@ echo -e "Finish restore data in mongodb."

install-allure:
	@ echo -e "Start install Allure commandline."
	@ sudo apt -y install npm
	@ sudo npm install -g allure-commandline
	@ sudo pip install allure-combine

install-mkcert:
	@ mkdir -p .ssl && cd .ssl && rm -rf *
	@ curl -JLO "https://dl.filippo.io/mkcert/latest?for=linux/amd64"
	@ chmod +x mkcert-v*-linux-amd64
	@ sudo mv mkcert-v*-linux-amd64 /usr/local/bin/mkcert
	@ cd ..
	@ sudo apt install ca-certificates

traefik-certs:
	@ cd infra/traefik && mkdir -p certs && cd certs && sudo rm -rf *
	@ CAROOT=${CAROOT} mkcert -install
	@ echo -e "Generating 'minio' certificates ..." && echo ${CAROOT}
	@ sudo echo $(mkcert -CAROOT)
	@ cd infra/traefik/certs && mkcert minio.${SUBDOMAIN}${DOMAIN}
	@ cd infra/traefik/certs && cat minio.${SUBDOMAIN}${DOMAIN}.pem > minio.${SUBDOMAIN}${DOMAIN}-fullchain.pem
	@ cd infra/traefik/certs && cat ${CAROOT}/rootCA.pem >> minio.${SUBDOMAIN}${DOMAIN}-fullchain.pem
	@ sudo rm -rf /usr/share/ca-certificates/minio.${SUBDOMAIN}${DOMAIN}*
	@ sudo cp infra/traefik/certs/minio.${SUBDOMAIN}${DOMAIN}* /usr/share/ca-certificates