# Module `data` : Aurora PostgreSQL Serverless v2 avec pgvector (scale-to-zero en dev et staging, PITR, deletion_protection), RDS Proxy avec authentification IAM, buckets S3 (documents, corpus brut, export d'audit avec Object Lock), AWS Backup avec second coffre.
# Les ressources arrivent en phase 3 (docs/07-roadmap.md) ; le module expose déjà son préfixe et ses tags.

locals {
  name_prefix = "${var.project}-${var.env}"
  tags        = var.tags
}
