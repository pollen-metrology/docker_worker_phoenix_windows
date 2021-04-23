
function startUp() {
  Write-Host "Register Runner"
  c:\GitLab-Runner\.\gitlab-runner.exe register `
  --non-interactive `
  --executor "shell" `
  --shell "powershell" `
  --url "https://gitlab.com/" `
  --registration-token $env:KUBERNETES_RUNNER_REGISTER_TOKEN `
  --description "Kubernetes-Runner" `
  --tag-list $env:KUBERNETES_RUNNER_TAG `
  --cache-type "s3" `
  --cache-shared=true `
  --cache-s3-server-address $env:KUBERNETES_RUNNER_CACHE_SERVER_ADDRESS.trim("") `
  --cache-s3-access-key $env:KUBERNETES_RUNNER_CACHE_ACCESS_KEY.trim("") `
  --cache-s3-secret-key $env:KUBERNETES_RUNNER_CACHE_SECRET_KEY.trim("") `
  --cache-s3-bucket-name "runner" `
  --run-untagged="true" `
  --limit=1 `
  --locked="false"
   # Disable run else windows launch two gitlab-runner process
   #c:\GitLab-Runner\.\gitlab-runner.exe run
}

function shutDown() {
  Write-Host "Unregister Runner"
  c:\GitLab-Runner\.\gitlab-runner.exe unregister --all-runners
}

try
{
  # startup 
  startUp
    # Keep Alive
    while($true)
    {
      #  "Working.."
      Start-Sleep -Seconds 1
    }
}
finally
{
  # when the docker stopped
  shutDown
}  
