# Renseigné après le bootstrap du compte prod (sortie tfstate_bucket de infra/global/accounts/prod).
bucket       = "cgp-tfstate-prod-ACCOUNT_ID"
key          = "envs/prod/agents.tfstate"
region       = "eu-central-1"
use_lockfile = true
encrypt      = true
kms_key_id   = "alias/cgp-prod-tfstate"
