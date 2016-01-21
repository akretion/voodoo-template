# -*- python -*-
# coding: utf-8

# Merci de mettre vos scripts d'upgrade à la suite de ce fichier
# INDIQUER LE NOM DE BRANCHE QUI REQUIERT L'UPGRADE comme ci-dessous

# script sample
#     # from branch 'feature-partner++mieux-bien
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
