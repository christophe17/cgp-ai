# Renseigné après le bootstrap du compte staging (sortie tfstate_bucket de infra/global/accounts/staging).
bucket       = "cgp-tfstate-staging-ACCOUNT_ID"
key          = "envs/staging/agents.tfstate"
region       = "eu-central-1"
use_lockfile = true
encrypt      = true
kms_key_id   = "alias/cgp-staging-tfstate"
