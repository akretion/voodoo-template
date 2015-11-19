# -*- coding: utf-8 -*-
from openerp.osv import orm, fields

class hello_world(orm.Model):
    _name = "hello.world"

    _columns = {
        'name': fields.char("Name", size=128),
    }


# v8 style:
#from openerp.models import Model
#from openerp.fields import Char


#class hello.world(Model):
#    _name = "demo_module.hello.world"

#    name = Char()
