"""Lambda d'exécution des migrations Alembic, invoquée par la CI."""

from importlib.metadata import version

__version__ = version("cgp-migrations")
