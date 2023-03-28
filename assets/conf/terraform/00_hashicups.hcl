# When set to true starts Consul servers on deploy
autostart_control_plane     = false
# When set to true starts Consul clients on deploy
autostart_data_plane        = false
# When set to true automatically bootstraps Consul ACLs
auto_acl_bootstrap          = false
# When set to true automatically generates Consul clients ACLs
auto_acl_clients            = false
# When set to true configures services for service mesh (instead of configuring them for service discovery)
config_services_for_mesh    = false
# When set to true starts Grafana agent on Consul clients to collect monitoring data
start_monitoring_client     = false 