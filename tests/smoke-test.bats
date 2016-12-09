#!/usr/bin/env bats

@test "Checking proxy container is active." {
	run docker ps -a --filter "name=docksal-vhost-proxy" --format "{{ .Status }}"
  [ $status -eq 0 ]
	[[ $output =~ "Up" ]]
}

@test "Checking nginx inside proxy container is active." {
	run curl -I http://test.docksal/
  [ $status -eq 0 ]
	[[ $output =~ "HTTP/1.1 404 Not Found" ]]
}

@test "Checking proxy container can start project." {
	# Stop if running.
	containers=$(docker ps -q --filter "label=com.docker.compose.project=drupal7")
	for container in $containers; do
		docker stop $container
	done
	if [[ "$(docker network ls -q --filter "name=drupal7_default")" != "" ]]; then
		docker network disconnect drupal7_default docksal-vhost-proxy
		docker network rm drupal7_default
	fi
	run curl http://drupal7.docksal/
  [ $status -eq 0 ]
	[[ $output =~ "Waking up the daemons..." ]]
}

@test "Checking proxy container started project." {
	# Wait for start.
	sleep 15
	run curl http://drupal7.docksal/
  [ $status -eq 0 ]
	[[ $output =~ "My Drupal 7 Site" ]]
}
