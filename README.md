# testing
testing metrics, alerts and logging

See `CLAUDE.md` for what this sandbox is and why.

## Layout

```
app/                    the test app (Node)
infra/
  bootstrap.bicep       one-time: the two identities
  main.bicep            logs, environment, app
  main.bicepparam       your values
  modules/              one file per piece
.github/workflows/
  deploy.yml            PR: what-if. Main: build, push, deploy
  teardown.yml          manual button that deletes the sandbox
```

## One-time setup

You only do this once. Teardown leaves the two identities alone, so you never redo it.

### 1. Deploy the identities

From cloud shell (it already has the az CLI and bicep), with this repo cloned:

```
az deployment group create --resource-group Emeka-Sandbox --template-file infra/bootstrap.bicep --query properties.outputs
```

Keep the output. You need it in the next two steps.

### 2. Ask an Owner for three role grants

You are Contributor on the resource group, and Contributor can't hand out roles. Send this to someone with Owner on `Emeka-Sandbox`. Fill in the ids from step 1.

```
RG=/subscriptions/<AZURE_SUBSCRIPTION_ID>/resourceGroups/Emeka-Sandbox

# GitHub Actions can deploy into this resource group only
az role assignment create --assignee-object-id <ciPrincipalId> --assignee-principal-type ServicePrincipal --role Contributor --scope $RG

# The test app can send custom metrics into this resource group only
az role assignment create --assignee-object-id <appPrincipalId> --assignee-principal-type ServicePrincipal --role "Monitoring Metrics Publisher" --scope $RG

# You can send custom metrics yourself with push-metric.sh
az role assignment create --assignee <your login email> --role "Monitoring Metrics Publisher" --scope $RG
```

All three are scoped to your resource group, nothing wider.

### 3. Add GitHub secrets

Go to the repo, then Settings, then Secrets and variables, then Actions. Add `AZURE_CLIENT_ID`, `AZURE_TENANT_ID` and `AZURE_SUBSCRIPTION_ID` from the step 1 output.

### 4. Make the image public

The first run on main pushes the image to ghcr. Then go to your GitHub profile, then Packages, then `obs-sandbox-app`, then Package settings. Set it to public. Azure can then pull it without a password. If the first deploy failed because it couldn't pull the image, re-run it.

## Day to day

- Open a PR. The deploy workflow shows the what-if in its logs.
- Merge to main. It builds, pushes and deploys.
- Done testing? Go to Actions, then teardown, then Run workflow, and type `DELETE`.
