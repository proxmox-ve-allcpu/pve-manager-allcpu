Ext.define('PVE.sdn.controllers.EvpnInputPanel', {
    extend: 'PVE.panel.SDNControllerBase',

    onlineHelp: 'pvesdn_controller_plugin_evpn',

    initComponent : function() {
	var me = this;

	me.items = [
	    {
		xtype: me.isCreate ? 'textfield' : 'displayfield',
		name: 'controller',
		maxLength: 10,
		value: me.controllerid || '',
		fieldLabel: 'ID',
		allowBlank: false
	    },
	    {
		xtype: 'proxmoxintegerfield',
		name: 'asn',
		minValue: 1,
		maxValue: 4294967295,
		value: 65000,
		fieldLabel: 'ASN #',
		allowBlank: false
	    },
	    {
		xtype: 'textfield',
		name: 'peers',
		fieldLabel: gettext('Peers'),
		allowBlank: false
	    },
	    {
		xtype: 'textfield',
		name: 'gateway-external-peers',
		fieldLabel: gettext('External Gateway Peers'),
		allowBlank: true
	    },
	    {
		xtype: 'pveNodeSelector',
		name: 'gateway-nodes',
		fieldLabel: gettext('Gateway Nodes'),
		multiSelect: true,
		autoSelect: false
	    },
	];

	me.callParent();
    }
});
