
if [ ! -d /${USER}/.hal ]; then
  mkdir /${USER}/.hal
fi

hal config --set-current-deployment ${DEPLOYMENT_NAME}

if [ ${DEPLOYMENT_INDEX} -eq 0 ]; then
  # remove default deployment that gets automatically created
  yq d -i ~/.hal/config 'deploymentConfigurations[0]'
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
    --kubeconfig-file ${KUBE_CONFIG}

hal config version edit --version $(hal version latest -q)

hal config deploy edit --type distributed --account-name "${ACCOUNT_NAME}"

hal config edit --timezone America/New_York

hal config generate

# set-up admin groups for fiat:
tee /${USER}/.hal/${DEPLOYMENT_NAME}/profiles/fiat-local.yml << FIAT_LOCAL
fiat:
  admin:
    roles:
      - gg_spinnaker_admins
FIAT_LOCAL

# set-up redis (memorystore):
tee /${USER}/.hal/${DEPLOYMENT_NAME}/profiles/gate-local.yml << GATE_LOCAL
redis:
  configuration:
    secure: true
GATE_LOCAL

tee /${USER}/.hal/${DEPLOYMENT_NAME}/service-settings/redis.yml << REDIS
overrideBaseUrl: redis://${SPIN_REDIS_ADDR}
REDIS

# set-up orca to use cloudsql proxy
tee /tmp/halconfig-orca-patch-${DEPLOYMENT_INDEX}.yml << ORCA_PATCH
deploymentConfigurations.${DEPLOYMENT_INDEX}.deploymentEnvironment.sidecars.spin-orca.0.name: cloudsql-proxy
deploymentConfigurations.${DEPLOYMENT_INDEX}.deploymentEnvironment.sidecars.spin-orca.0.port: 3306
deploymentConfigurations.${DEPLOYMENT_INDEX}.deploymentEnvironment.sidecars.spin-orca.0.dockerImage: "gcr.io/cloudsql-docker/gce-proxy:1.13"
deploymentConfigurations.${DEPLOYMENT_INDEX}.deploymentEnvironment.sidecars.spin-orca.0.command.0: "'/cloud_sql_proxy'"
deploymentConfigurations.${DEPLOYMENT_INDEX}.deploymentEnvironment.sidecars.spin-orca.0.command.1: "'--dir=/cloudsql'"
deploymentConfigurations.${DEPLOYMENT_INDEX}.deploymentEnvironment.sidecars.spin-orca.0.command.2: "'-instances=${DB_CONNECTION_NAME}=tcp:3306'"
deploymentConfigurations.${DEPLOYMENT_INDEX}.deploymentEnvironment.sidecars.spin-orca.0.command.3: "'-credential_file=/secrets/cloudsql/secret'"
deploymentConfigurations.${DEPLOYMENT_INDEX}.deploymentEnvironment.sidecars.spin-orca.0.mountPath: /cloudsql
deploymentConfigurations.${DEPLOYMENT_INDEX}.deploymentEnvironment.sidecars.spin-orca.0.secretVolumeMounts.0.mountPath: /secrets/cloudsql
deploymentConfigurations.${DEPLOYMENT_INDEX}.deploymentEnvironment.sidecars.spin-orca.0.secretVolumeMounts.0.secretName: cloudsql-instance-credentials
ORCA_PATCH

yq write -i -s /tmp/halconfig-orca-patch-${DEPLOYMENT_INDEX}.yml /${USER}/.hal/config && rm /tmp/halconfig-orca-patch-${DEPLOYMENT_INDEX}.yml

# set-up clouddriver to use cloudsql proxy
tee /tmp/halconfig-clouddriver-patch-${DEPLOYMENT_INDEX}.yml << CLOUDDRIVER_PATCH
deploymentConfigurations.${DEPLOYMENT_INDEX}.deploymentEnvironment.sidecars.spin-clouddriver.0.name: cloudsql-proxy
deploymentConfigurations.${DEPLOYMENT_INDEX}.deploymentEnvironment.sidecars.spin-clouddriver.0.port: 3306
deploymentConfigurations.${DEPLOYMENT_INDEX}.deploymentEnvironment.sidecars.spin-clouddriver.0.dockerImage: "gcr.io/cloudsql-docker/gce-proxy:1.13"
deploymentConfigurations.${DEPLOYMENT_INDEX}.deploymentEnvironment.sidecars.spin-clouddriver.0.command.0: "'/cloud_sql_proxy'"
deploymentConfigurations.${DEPLOYMENT_INDEX}.deploymentEnvironment.sidecars.spin-clouddriver.0.command.1: "'--dir=/cloudsql'"
deploymentConfigurations.${DEPLOYMENT_INDEX}.deploymentEnvironment.sidecars.spin-clouddriver.0.command.2: "'-instances=${DB_CONNECTION_NAME}=tcp:3306'"
deploymentConfigurations.${DEPLOYMENT_INDEX}.deploymentEnvironment.sidecars.spin-clouddriver.0.command.3: "'-credential_file=/secrets/cloudsql/secret'"
deploymentConfigurations.${DEPLOYMENT_INDEX}.deploymentEnvironment.sidecars.spin-clouddriver.0.mountPath: /cloudsql
deploymentConfigurations.${DEPLOYMENT_INDEX}.deploymentEnvironment.sidecars.spin-clouddriver.0.secretVolumeMounts.0.mountPath: /secrets/cloudsql
deploymentConfigurations.${DEPLOYMENT_INDEX}.deploymentEnvironment.sidecars.spin-clouddriver.0.secretVolumeMounts.0.secretName: cloudsql-instance-credentials
CLOUDDRIVER_PATCH

yq write -i -s /tmp/halconfig-clouddriver-patch-${DEPLOYMENT_INDEX}.yml /${USER}/.hal/config && rm /tmp/halconfig-clouddriver-patch-${DEPLOYMENT_INDEX}.yml

# set-up replica patch
tee /tmp/halconfig-replica-patch-${DEPLOYMENT_INDEX}.yml << REPLICA_PATCH
deploymentConfigurations.${DEPLOYMENT_INDEX}.deploymentEnvironment.customSizing.spin-front50.replicas: 2
deploymentConfigurations.${DEPLOYMENT_INDEX}.deploymentEnvironment.customSizing.spin-clouddriver.replicas: 2
deploymentConfigurations.${DEPLOYMENT_INDEX}.deploymentEnvironment.customSizing.spin-deck.replicas: 2
deploymentConfigurations.${DEPLOYMENT_INDEX}.deploymentEnvironment.customSizing.spin-gate.replicas: 2
deploymentConfigurations.${DEPLOYMENT_INDEX}.deploymentEnvironment.customSizing.spin-rosco.replicas: 2
deploymentConfigurations.${DEPLOYMENT_INDEX}.deploymentEnvironment.customSizing.spin-fiat.replicas: 2
deploymentConfigurations.${DEPLOYMENT_INDEX}.deploymentEnvironment.customSizing.spin-orca.replicas: 2
REPLICA_PATCH

yq write -i -s /tmp/halconfig-replica-patch-${DEPLOYMENT_INDEX}.yml /${USER}/.hal/config && rm /tmp/halconfig-replica-patch-${DEPLOYMENT_INDEX}.yml

tee /${USER}/.hal/${DEPLOYMENT_NAME}/profiles/orca-local.yml << ORCA_LOCAL
sql:
  enabled: true
  connectionPool:
    jdbcUrl: jdbc:mysql://localhost:3306/orca?useSSL=false&useUnicode=true&characterEncoding=utf8
    user: orca_service
    password: ${DB_SERVICE_USER_PASSWORD}
    connectionTimeout: 5000
    maxLifetime: 30000
    # MariaDB-specific:
    maxPoolSize: 50
  migration:
    jdbcUrl: jdbc:mysql://localhost:3306/orca?useSSL=false&useUnicode=true&characterEncoding=utf8
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

tee /${USER}/.hal/${DEPLOYMENT_NAME}/profiles/clouddriver-local.yml << CLOUDDRIVER_LOCAL
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
      jdbcUrl: jdbc:mysql://localhost:3306/clouddriver?useSSL=false&useUnicode=true&characterEncoding=utf8
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
      jdbcUrl: jdbc:mysql://localhost:3306/clouddriver?useSSL=false&useUnicode=true&characterEncoding=utf8
  migration:
    user: clouddriver_migrate
    password: ${DB_CLOUDDRIVER_MIGRATE_PASSWORD}
    jdbcUrl: jdbc:mysql://localhost:3306/clouddriver?useSSL=false&useUnicode=true&characterEncoding=utf8

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

# Changing health check to be native instead of wget https://github.com/spinnaker/spinnaker/issues/4479
cat <<EOF >> /${USER}/.hal/${DEPLOYMENT_NAME}/service-settings/gate.yml
kubernetes:
  useExecHealthCheck: false

EOF

echo "Running initial Spinnaker deployment for deployment named ${DEPLOYMENT_NAME}"
hal deploy apply
