using 'main.bicep'

// GitHub Actions sets IMAGE to the image it just built.
// To deploy from your PC, set IMAGE first or the latest tag is used.
param image = readEnvironmentVariable('IMAGE', 'ghcr.io/emeka-ubahakwe/obs-sandbox-app:latest')

param emitLoop = true
param dailyCapGb = '0.1'
