"""Test de fumée : le package est installé et expose sa version."""

from importlib.metadata import version

import cgp_review_workflow


def test_package_exposes_installed_version() -> None:
    assert cgp_review_workflow.__version__ == version("cgp-review-workflow")
