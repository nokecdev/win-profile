function nokecdev {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateSet("restart", "rebuild", "down", "up", "purge", "volume")]
        [string]$Command,

        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Args
    )

    # -----------------------------
    # Environment (default: test)
    # -----------------------------
    $env = "test"

    if ($Args -contains "--dev")   { $env = "dev" }
    if ($Args -contains "--test")  { $env = "test" }
    if ($Args -contains "--stage") { $env = "stage" }

    $services = $Args | Where-Object {
        $_ -notin @("--dev", "--test", "--stage")
    }

    switch ($env) {
        "dev"   { $composeFile = "docker-compose.yml";        $project = "docker_dev" }
        "test"  { $composeFile = "docker-compose.test.yml";  $project = "docker_test" }
        "stage" { $composeFile = "docker-compose.stage.yml"; $project = "docker_stage" }
    }

    Write-Host "Environment: $env"
    Write-Host "Compose file: $composeFile"

    switch ($Command) {

        # -----------------------------
        # RESTART
        # -----------------------------
        "restart" {
            if (-not $services -or $services -contains "all") {
                docker compose -f $composeFile up -d
            } else {
                docker compose -f $composeFile up -d --build @services
            }
        }

        # -----------------------------
        # REBUILD
        # -----------------------------
        "rebuild" {
            docker compose -f $composeFile up -d --build
        }

        # -----------------------------
        # UP
        # -----------------------------
        "up" {
            docker compose -f $composeFile up
        }

        # -----------------------------
        # DOWN
        # -----------------------------
        "down" {
            docker compose -f $composeFile down
        }

        # -----------------------------
        # PURGE (containers + volumes)
        # -----------------------------
        "purge" {
            Write-Host "Stopping containers..."
            docker compose -f $composeFile down

            if (-not $services -or $services -contains "all") {
                Write-Host "Removing ALL volumes for project: $project"

                docker volume ls -q |
                    Where-Object { $_ -like "$project*" } |
                    ForEach-Object {
                        Write-Host "Removing volume $_"
                        docker volume rm $_
                    }
            }
            else {
                foreach ($svc in $services) {
                    Write-Host "Removing volumes for service: $svc"

                    docker volume ls -q |
                        Where-Object { $_ -like "$project-$svc*" } |
                        ForEach-Object {
                            Write-Host "Removing volume $_"
                            docker volume rm $_
                        }
                }
            }
        }

        
        # -----------------------------
        # VOLUME RESET (MYSQL)
        # -----------------------------
        "volume" {
            if (-not $services -or $services.Count -eq 0) {
                Write-Error "Please specify at least one service name (e.g. friend, user)"
                return
            }

            foreach ($svc in $services) {

                $dbContainer = "$env-$svc-db"
                $volumeName  = "$project-$svc-mysql-data"

                Write-Host "Stopping DB container: $dbContainer"
                docker stop $dbContainer 2>$null

                Write-Host "Removing DB container: $dbContainer"
                docker rm $dbContainer 2>$null

                Write-Host "Removing volume: $volumeName"
                docker volume rm $volumeName
            }
        }
    }
}
