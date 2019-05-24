#!/bin/bash

if [ ! -d /${USER}/.hal ]; then
  mkdir /${USER}/.hal
fi

GCS_SA_DEST="${ACCOUNT_PATH}"

hal config storage gcs edit \
    --project $(gcloud info --format='value(config.project)') \
    --json-path "$GCS_SA_DEST"
hal config storage edit --type gcs

hal config provider docker-registry enable

hal config provider docker-registry account add "${DOCKER}" \
    --address gcr.io \
    --password-file "$GCS_SA_DEST" \
    --username _json_key
    

hal config provider kubernetes enable

hal config provider kubernetes account add ${ACCOUNT_NAME} \
    --docker-registries "${DOCKER}" \
    --provider-version v2 \
    --only-spinnaker-managed=true \
    --context $(kubectl config current-context)

hal config version edit --version $(hal version latest -q)

hal config deploy edit --type distributed --account-name "${ACCOUNT_NAME}"

hal config edit --timezone America/New_York

hal config generate

# set-up admin groups for fiat:
tee /${USER}/.hal/default/profiles/fiat-local.yml << FIAT_LOCAL
fiat:
  admin:
    roles:
      - gg_spinnaker_admins
FIAT_LOCAL

# set-up redis (memorystore):
tee /${USER}/.hal/default/profiles/gate-local.yml << GATE_LOCAL
redis:
  configuration:
    secure: true
GATE_LOCAL

tee /${USER}/.hal/default/service-settings/redis.yml << REDIS
overrideBaseUrl: redis://${SPIN_REDIS_ADDR}
REDIS

# set-up orca to use cloudsql proxy
tee /tmp/halconfig-orca-patch.yml << ORCA_PATCH
deploymentConfigurations.0.deploymentEnvironment.sidecars.spin-orca.0.name: cloudsql-proxy
deploymentConfigurations.0.deploymentEnvironment.sidecars.spin-orca.0.port: 3306
deploymentConfigurations.0.deploymentEnvironment.sidecars.spin-orca.0.dockerImage: "gcr.io/cloudsql-docker/gce-proxy:1.13"
deploymentConfigurations.0.deploymentEnvironment.sidecars.spin-orca.0.command.0: "'/cloud_sql_proxy'"
deploymentConfigurations.0.deploymentEnvironment.sidecars.spin-orca.0.command.1: "'--dir=/cloudsql'"
deploymentConfigurations.0.deploymentEnvironment.sidecars.spin-orca.0.command.2: "'-instances=${DB_CONNECTION_NAME}=tcp:3306'"
deploymentConfigurations.0.deploymentEnvironment.sidecars.spin-orca.0.command.3: "'-credential_file=/secrets/cloudsql/secret'"
deploymentConfigurations.0.deploymentEnvironment.sidecars.spin-orca.0.mountPath: /cloudsql
deploymentConfigurations.0.deploymentEnvironment.sidecars.spin-orca.0.secretVolumeMounts.0.mountPath: /secrets/cloudsql
deploymentConfigurations.0.deploymentEnvironment.sidecars.spin-orca.0.secretVolumeMounts.0.secretName: cloudsql-instance-credentials
ORCA_PATCH

yq write -i -s /tmp/halconfig-orca-patch.yml /${USER}/.hal/config && rm /tmp/halconfig-orca-patch.yml

# set-up clouddriver to use cloudsql proxy
tee /tmp/halconfig-clouddriver-patch.yml << CLOUDDRIVER_PATCH
deploymentConfigurations.0.deploymentEnvironment.sidecars.spin-clouddriver.0.name: cloudsql-proxy
deploymentConfigurations.0.deploymentEnvironment.sidecars.spin-clouddriver.0.port: 3306
deploymentConfigurations.0.deploymentEnvironment.sidecars.spin-clouddriver.0.dockerImage: "gcr.io/cloudsql-docker/gce-proxy:1.13"
deploymentConfigurations.0.deploymentEnvironment.sidecars.spin-clouddriver.0.command.0: "'/cloud_sql_proxy'"
deploymentConfigurations.0.deploymentEnvironment.sidecars.spin-clouddriver.0.command.1: "'--dir=/cloudsql'"
deploymentConfigurations.0.deploymentEnvironment.sidecars.spin-clouddriver.0.command.2: "'-instances=${DB_CONNECTION_NAME}=tcp:3306'"
deploymentConfigurations.0.deploymentEnvironment.sidecars.spin-clouddriver.0.command.3: "'-credential_file=/secrets/cloudsql/secret'"
deploymentConfigurations.0.deploymentEnvironment.sidecars.spin-clouddriver.0.mountPath: /cloudsql
deploymentConfigurations.0.deploymentEnvironment.sidecars.spin-clouddriver.0.secretVolumeMounts.0.mountPath: /secrets/cloudsql
deploymentConfigurations.0.deploymentEnvironment.sidecars.spin-clouddriver.0.secretVolumeMounts.0.secretName: cloudsql-instance-credentials
CLOUDDRIVER_PATCH

yq write -i -s /tmp/halconfig-clouddriver-patch.yml /${USER}/.hal/config && rm /tmp/halconfig-clouddriver-patch.yml

# set-up replica patch
tee /tmp/halconfig-replica-patch.yml << REPLICA_PATCH
deploymentConfigurations.0.deploymentEnvironment.customSizing.spin-front50.replicas: 2
deploymentConfigurations.0.deploymentEnvironment.customSizing.spin-clouddriver.replicas: 2
deploymentConfigurations.0.deploymentEnvironment.customSizing.spin-deck.replicas: 2
deploymentConfigurations.0.deploymentEnvironment.customSizing.spin-gate.replicas: 2
deploymentConfigurations.0.deploymentEnvironment.customSizing.spin-rosco.replicas: 2
deploymentConfigurations.0.deploymentEnvironment.customSizing.spin-fiat.replicas: 2
deploymentConfigurations.0.deploymentEnvironment.customSizing.spin-orca.replicas: 2
REPLICA_PATCH

yq write -i -s /tmp/halconfig-replica-patch.yml /${USER}/.hal/config && rm /tmp/halconfig-replica-patch.yml

tee /${USER}/.hal/default/profiles/orca-local.yml << ORCA_LOCAL
sql:
  enabled: true
  connectionPool:
    jdbcUrl: jdbc:mysql://localhost:3306/orca
    user: orca_service
    password: ${DB_SERVICE_USER_PASSWORD}
    connectionTimeout: 5000
    maxLifetime: 30000
    # MariaDB-specific:
    maxPoolSize: 50
  migration:
    jdbcUrl: jdbc:mysql://localhost:3306/orca
    user: orca_migrate
    password: ${DB_MIGRATE_USER_PASSWORD}

# Ensure we're only using SQL for accessing execution state
executionRepository:
  sql:
    enabled: true
  redis:
    enabled: false

# Reporting on active execution metrics will be handled by SQL
monitor:
  activeExecutions:
    redis: false
ORCA_LOCAL

tee /${USER}/.hal/default/profiles/clouddriver-local.yml << CLOUDDRIVER_LOCAL
sql:
  enabled: true
  taskRepository:
    enabled: true
  cache:
    enabled: true
    # These parameters were determined to be optimal via benchmark comparisons
    # in the Netflix production environment with Aurora. Setting these too low
    # or high may negatively impact performance. These values may be sub-optimal
    # in some environments.
    readBatchSize: 500
    writeBatchSize: 300
  scheduler:
    enabled: false
  connectionPools:
    default:
      # additional connection pool parameters are available here,
      # for more detail and to view defaults, see:
      # https://github.com/spinnaker/kork/blob/master/kork-sql/src/main/kotlin/com/netflix/spinnaker/kork/sql/config/ConnectionPoolProperties.kt
      default: true
      jdbcUrl: jdbc:mysql://localhost:3306/clouddriver
      user: clouddriver_service
      password: ${DB_CLOUDDRIVER_SVC_PASSWORD}
      # password: depending on db auth and how spinnaker secrets are managed
    # The following tasks connection pool is optional. At Netflix, clouddriver
    # instances pointed to Aurora read replicas have a tasks pool pointed at the
    # master. Instances where the default pool is pointed to the master omit a
    # separate tasks pool.
    tasks:
      user: clouddriver_service
      password: ${DB_CLOUDDRIVER_SVC_PASSWORD}
      jdbcUrl: jdbc:mysql://localhost:3306/clouddriver
  migration:
    user: clouddriver_migrate
    password: ${DB_CLOUDDRIVER_MIGRATE_PASSWORD}
    jdbcUrl: jdbc:mysql://localhost:3306/clouddriver

redis:
  enabled: true
  connection: redis://${SPIN_REDIS_ADDR}
  cache:
    enabled: false
  scheduler:
    enabled: true
  taskRepository:
    enabled: false
CLOUDDRIVER_LOCAL

echo "You may want to run 'hal deploy apply'"
