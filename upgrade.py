# -*- python -*-
"""This is a template upgrade script.

The purpose is both to cover the most common use-case (updating all modules)
and to provide an example of how this works.
"""

from anybox.recipe.odoo.runtime.session import OpenERPVersion
import os, imp


def run(session, logger):
    """Update all modules."""
    if session.is_initialization:
        logger.warn("Usage of upgrade script for initialization detected. "
                    "You should consider customizing the present upgrade "
                    "script to add modules install commands. The present "
                    "script is at : %s (byte-compiled form)", __file__)
        return
    files = [f.replace('.py', '') for f in os.listdir('upgrade')
             if f[-3:] == '.py']
    files.sort(key=OpenERPVersion)
    if 'current' in files:
        files.remove('current')
        files.append('current')
        for version in files:
            if session.db_version < version or version == 'current':
                script = imp.load_source('script', 'upgrade/%s.py' % version)
                script.run(session, logger)
                if version != 'current':
                    session.db_version = version
                session.cr.commit()
