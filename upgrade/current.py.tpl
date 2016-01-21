# -*- python -*-
# coding: utf-8

# Save this file as 'current.py' in the same folder if you want to use it for migration script of your Pull Request.
# All migration scripts of merged PRs will be merged in this file, make it ready to go in production

# sample script
#     # from branch 'feature-partner++better-good
#     partner_m = env['res.partner']
#     partners = partner_m.search([('field', '=', '...')]):
#     partners.write({'key': val})
]
from openerp.api import Environment


INSTALL = [

]
UPDATE = [

]

def run(session, logger):
    if INSTALL:
        session.install_modules(INSTALL)
    if UPDATE:
        session.update_modules(UPDATE)
    env = Environment(session.cr, 1, {})
