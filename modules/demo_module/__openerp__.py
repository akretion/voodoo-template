# -*- coding: utf-8 -*-
{
    'name': "demo_module",

    'summary': """
        ColiPoste Test""",

    'description': """
        Long description of module's purpose
    """,

    'author': "Your Company",
    'website': "http://www.yourcompany.com",

    # Categories can be used to filter modules in modules listing
    # Check <odoo>/addons/base/module/module_data.xml of the full list
    'category': 'Uncategorized',
    'version': '0.1',

    # any module necessary for this one to work correctly
    'depends': [
        'delivery_carrier_label_colissimo',
        'delivery_carrier_label_so_colissimo',
    ],
    'data': [],
    'demo': [],
    'auto_install': True,
    'tests': [
    ],
}
