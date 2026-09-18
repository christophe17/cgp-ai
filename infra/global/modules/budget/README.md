# Module `budget`

Budget mensuel AWS Budgets avec quatre notifications par courriel : 50 %, 80 % et 100 % du réel,
100 % de la prévision (`docs/08-production-readiness.md` §8). AWS Budgets n'accepte que le dollar :
le plafond approuvé en euros est saisi arrondi en USD, la conversion est notée dans les `tfvars`.
