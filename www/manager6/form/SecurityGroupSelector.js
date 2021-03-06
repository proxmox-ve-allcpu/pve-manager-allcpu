Ext.define('PVE.form.SecurityGroupsSelector', {
    extend: 'Proxmox.form.ComboGrid',
    alias: ['widget.pveSecurityGroupsSelector'],

    valueField: 'group',
    displayField: 'group',
    initComponent: function() {
	var me = this;

	var store = Ext.create('Ext.data.Store', {
	    autoLoad: true,
	    fields: ['group', 'comment'],
	    idProperty: 'group',
	    proxy: {
		type: 'proxmox',
		url: "/api2/json/cluster/firewall/groups",
	    },
	    sorters: {
		property: 'group',
		direction: 'ASC',
	    },
	});

	Ext.apply(me, {
	    store: store,
            listConfig: {
		columns: [
		    {
			header: gettext('Security Group'),
			dataIndex: 'group',
			hideable: false,
			width: 100,
		    },
		    {
			header: gettext('Comment'),
			dataIndex: 'comment',
			renderer: Ext.String.htmlEncode,
			flex: 1,
		    },
		],
	    },
	});

        me.callParent();
    },
});

