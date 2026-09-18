# Renseigné après le bootstrap du compte dev (sortie tfstate_bucket de infra/global/accounts/dev).
bucket       = "cgp-tfstate-dev-ACCOUNT_ID"
key          = "envs/dev/foundation.tfstate"
region       = "eu-central-1"
use_lockfile = true
encrypt      = true
kms_key_id   = "alias/cgp-dev-tfstate"
