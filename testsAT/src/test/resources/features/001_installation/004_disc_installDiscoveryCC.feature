@rest
Feature: [QATM-1866][Installation Discovery Command Center] Discovery install with command center


  @runOnEnv(DISC_VERSION>0.29.0)
  Scenario: [QATM-1866][Installation Discovery Command Center][00] Check PostgresTLS
    Given I authenticate to DCOS cluster '${DCOS_IP}' using email '${DCOS_USER:-admin}' with user '${REMOTE_USER:-operador}' and pem file '${BOOTSTRAP_PEM:-src/test/resources/credentials/key.pem}'
    And I securely send requests to '${CLUSTER_ID}.${CLUSTER_DOMAIN:-labs.stratio.com}:443'
    Then in less than '100' seconds, checking each '10' seconds, I send a 'GET' request to '/service/deploy-api/deploy/status/all' so that the response contains '${DISC_POSTGRES_FRAMEWORK_ID_TLS:-postgrestls}'
    And in less than '100' seconds, checking each '10' seconds, I send a 'GET' request to '/service/deploy-api/deploy/status/service?service=/${DISC_POSTGRES_FRAMEWORK_ID_TLS:-postgrestls}' so that the response contains '"healthy":1'

    Given I authenticate to DCOS cluster '${DCOS_IP}' using email '${DCOS_USER:-admin}' with user '${REMOTE_USER:-operador}' and pem file '${BOOTSTRAP_PEM:-src/test/resources/credentials/key.pem}'
    And I securely send requests to '${DCOS_IP}:443'
    Then in less than '100' seconds, checking each '5' seconds, I send a 'GET' request to '/service/${DISC_POSTGRES_FRAMEWORK_ID_TLS:-postgrestls}/v1/service/status' so that the response contains '"pg-0001","role":"master","status":"RUNNING"'
    And in less than '100' seconds, checking each '5' seconds, I send a 'GET' request to '/service/${DISC_POSTGRES_FRAMEWORK_ID_TLS:-postgrestls}/v1/service/status' so that the response contains '"pg-0002","role":"sync_slave","status":"RUNNING"'
    And in less than '100' seconds, checking each '5' seconds, I send a 'GET' request to '/service/${DISC_POSTGRES_FRAMEWORK_ID_TLS:-postgrestls}/v1/service/status' so that the response contains '"pg-0003","role":"async_slave","status":"RUNNING"'


  @skipOnEnv(DISC_ADVANCED_INSTALL)
  Scenario: [QATM-1866][Installation Discovery Command Center][1] Basic install
    Given I authenticate to DCOS cluster '${DCOS_IP}' using email '${DCOS_USER:-admin}' with user '${REMOTE_USER:-operador}' and pem file '${BOOTSTRAP_PEM:-src/test/resources/credentials/key.pem}'
    And I securely send requests to '${CLUSTER_ID}.${CLUSTER_DOMAIN:-labs.stratio.com}:443'

    # Obtain schema
    When I send a 'GET' request to '/service/deploy-api/deploy/discovery/${DISC_FLAVOUR:-hydra}/schema?level=1'
    Then I save element '$' in environment variable 'discovery-json-schema'
    And I run 'echo !{discovery-json-schema}' locally

    # Convert to jsonSchema
    And I convert jsonSchema '!{discovery-json-schema}' to json and save it in variable 'discovery-basic.json'
    And I run 'echo '!{discovery-basic.json}' > target/test-classes/schemas/discovery-basic.json' locally

    # Launch basic install
    When I send a 'POST' request to '/service/deploy-api/deploy/discovery/${DISC_FLAVOUR:-hydra}/schema' based on 'schemas/discovery-basic.json' as 'json' with:
       # GENERAL
      | $.general.serviceId                         | UPDATE  | ${SERVICE_ID:-/discovery/discovery}                         | n/a     |
       # MARATHON LB
      | $.general.marathonlb.haproxyhost            | UPDATE  | ${MARATHONLB_HA_PROXY_HOST:-discovery.labs.stratio.com}     | n/a     |
      | $.general.marathonlb.haproxypath            | UPDATE  | ${MARATHONLB_HA_PROXY_PATH:-/discovery}                     | n/a     |
       # POSTGRESQL
      | $.general.datastore.metadataDbInstanceName  | UPDATE  | ${DISC_POSTGRES_FRAMEWORK_ID_TLS:-postgrestls}              | n/a     |
      | $.general.datastore.metadataDbName          | UPDATE  | ${DISCOVERY_METADATA_DB_NAME:-pruebadiscovery}              | n/a     |
      | $.general.datastore.tenantName              | UPDATE  | ${DISCOVERY_TENANT_NAME:-crossdata-1}                       | n/a     |
      | $.general.datastore.metadataDbHost          | UPDATE  | ${DISCOVERY_METADATA_DB_HOST:-pg-0001.postgrestls.mesos}    | n/a     |
       # CALICO NETWORK
      | $.general.calico.networkName                | UPDATE  | ${DISCOVERY_NETWORK_NAME:-stratio}                          | n/a     |
       # RESOURCES
      | $.general.resources.instances               | REPLACE | ${DISCOVERY_SERVICE_INSTANCES:-1}                           | number  |
      | $.general.resources.cpus                    | REPLACE | ${DISCOVERY_SERVICE_CPUS:-1}                                | number  |
      | $.general.resources.mem                     | REPLACE | ${DISCOVERY_SERVICE_MEM:-1024}                              | number  |

    Then the service response status must be '202'
    And I run 'rm -f target/test-classes/schemas/discovery-basic.json' locally


  @runOnEnv(DISC_ADVANCED_INSTALL)
  Scenario: [QATM-1866][Installation Discovery Command Center][1] Advanced install
    Given I authenticate to DCOS cluster '${DCOS_IP}' using email '${DCOS_USER:-admin}' with user '${REMOTE_USER:-operador}' and pem file '${BOOTSTRAP_PEM:-src/test/resources/credentials/key.pem}'

    And I securely send requests to '${CLUSTER_ID}.${CLUSTER_DOMAIN:-labs.stratio.com}:443'
    # Obtain schema
    When I send a 'GET' request to '/service/deploy-api/deploy/discovery/${DISC_FLAVOUR:-hydra}/schema?level=1'
    Then I save element '$' in environment variable 'discovery-json-schema'
    And I run 'echo !{discovery-json-schema}' locally
    # Convert to jsonSchema
    And I convert jsonSchema '!{discovery-json-schema}' to json and save it in variable 'discovery-basic.json'
    And I run 'echo '!{discovery-basic.json}' > target/test-classes/schemas/discovery-basic.json' locally

    When I send a 'POST' request to '/service/deploy-api/deploy/discovery/${DISC_FLAVOUR:-hydra}/schema' based on 'schemas/discovery-basic.json' as 'json' with:
       # GENERAL
      | $.general.serviceId                         | UPDATE  | ${SERVICE_ID:-/discovery/discovery}                         | n/a     |
       # MARATHON LB
      | $.general.marathonlb.haproxyhost            | UPDATE  | ${MARATHONLB_HA_PROXY_HOST:-discovery.labs.stratio.com}     | n/a     |
      | $.general.marathonlb.haproxypath            | UPDATE  | ${MARATHONLB_HA_PROXY_PATH:-/discovery}                     | n/a     |
       # POSTGRESQL
      | $.general.datastore.metadataDbInstanceName  | UPDATE  | ${DISC_POSTGRES_FRAMEWORK_ID_TLS:-postgrestls}              | n/a     |
      | $.general.datastore.metadataDbName          | UPDATE  | ${DISCOVERY_METADATA_DB_NAME:-pruebadiscovery}              | n/a     |
      | $.general.datastore.tenantName              | UPDATE  | ${DISCOVERY_TENANT_NAME:-crossdata-1}                       | n/a     |
      | $.general.datastore.metadataDbHost          | UPDATE  | ${DISCOVERY_METADATA_DB_HOST:-pg-0001.postgrestls.mesos}    | n/a     |
       # CALICO NETWORK
      | $.general.calico.networkName                | UPDATE  | ${DISCOVERY_NETWORK_NAME:-stratio}                          | n/a     |
       # RESOURCES
      | $.general.resources.instances               | REPLACE | ${DISCOVERY_SERVICE_INSTANCES:-1}                           | number  |
      | $.general.resources.cpus                    | REPLACE | ${DISCOVERY_SERVICE_CPUS:-1}                                | number  |
      | $.general.resources.mem                     | REPLACE | ${DISCOVERY_SERVICE_MEM:-2048}                              | number  |
       #ADVANCE INSTALL
      | $.settings.jdbcParameters                   | UPDATE  | ${JDBC_PARAMETERS:-prepareThreshold=1}                      | n/a     |
      | $.settings.init.mb-init-admin-user          | UPDATE  | ${DISCOVERY_DISCOVERY_USER:-ADVANCEINSTALL}                 | n/a     |
      | $.settings.init.mb-init-admin-mail          | UPDATE  | ${DISCOVERY_DISCOVERY_USERMAIL:-ADVANCEINSTALL@stratio.com} | n/a     |
      | $.settings.init.mb-init-admin-password      | REPLACE | ${DISCOVERY_DISCOVERY_PASSWORD:-654321}                     | number  |

       # Comentamos variables ya que no disponemos de valores válidos
#       | $.settings.Login                            | ADD     | {}                                            | object  |
#       | $.settings.Login.mb-user-header             | ADD     | ${MB_USER_HEADER:- "fdsa"}                    | string  |
#       | $.settings.Login.mb-admin-group-header      | ADD     | ${MB_ADMIN_GROUP_HEADER:-"4e32" }             | string  |
#       | $.settings.Login.mb-group-header            | ADD     | ${MB_GROUP_HEADER:-"433" }                    | string  |
#       | $.general.indentity.approlename             | UPDATE  | ${DISCOVERY_SECURITY_INSTANCE_APP_ROLE:-open} | n/a     |

    Then the service response status must be '202'
    And I run 'rm -f target/test-classes/schemas/discovery-basic.json' locally

  Scenario: [QATM-1866][Installation Discovery Command Center][2] Check status
    Given I authenticate to DCOS cluster '${DCOS_IP}' using email '${DCOS_USER:-admin}' with user '${REMOTE_USER:-operador}' and pem file '${BOOTSTRAP_PEM:-src/test/resources/credentials/key.pem}'
    And I securely send requests to '${CLUSTER_ID}.${CLUSTER_DOMAIN:-labs.stratio.com}:443'
    # Check Application in API
    Then in less than '100' seconds, checking each '10' seconds, I send a 'GET' request to '/service/deploy-api/deploy/status/all' so that the response contains '${SERVICE_ID:-/discovery/discovery}'
    # Check status in API
    And in less than '100' seconds, checking each '10' seconds, I send a 'GET' request to '/service/deploy-api/deploy/status/service?service=${SERVICE_ID:-/discovery/discovery}' so that the response contains '"healthy":1'
    # Check status in DCOS
    # Checking if service_ID contains "/" character or subdirectories. Ex: /discovery/discovery
    When I open a ssh connection to '${DCOS_CLI_HOST}' with user 'root' and password 'stratio'
    Then I run 'echo ${SERVICE_ID:-/discovery/discovery} | sed 's/\//./g' |  sed 's/^\.\(.*\)/\1/'' in the ssh connection and save the value in environment variable 'serviceIDDcosTaskPath'
    And in less than '500' seconds, checking each '20' seconds, the command output 'dcos task | grep !{serviceIDDcosTaskPath} | grep R | wc -l' contains '1'
    When I run 'dcos task |  awk '{print $5}' | grep !{serviceIDDcosTaskPath}' in the ssh connection and save the value in environment variable 'dicoveryTaskId'
    Then in less than '10' seconds, checking each '10' seconds, the command output 'dcos marathon task show !{dicoveryTaskId} | grep TASK_RUNNING |wc -l' contains '1'
    And in less than '10' seconds, checking each '10' seconds, the command output 'dcos marathon task show !{dicoveryTaskId} | grep '"alive": true |wc -l' contains '1'


