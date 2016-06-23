FROM akretion/voodoo:voodoo-2

RUN groupadd -g 1000 odoo && adduser --uid 1000 --gid 1000 odoo # set your uid and guid here
USER odoo
EXPOSE 8069
