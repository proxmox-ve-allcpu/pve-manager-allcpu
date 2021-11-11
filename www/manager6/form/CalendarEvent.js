Ext.define('PVE.form.CalendarEvent', {
    extend: 'Ext.form.field.ComboBox',
    xtype: 'pveCalendarEvent',

    editable: true,
    emptyText: gettext('Editable'), // FIXME: better way to convey that to confused users?

    valueField: 'value',
    queryMode: 'local',

    matchFieldWidth: false,
    listConfig: {
	maxWidth: 450,
    },

    store: {
	field: ['value', 'text'],
	data: [
	    { value: '*/30', text: Ext.String.format(gettext("Every {0} minutes"), 30) },
	    { value: '*/2:00', text: gettext("Every two hours") },
	    { value: '2,22:30', text: gettext("Every day") + " 02:30, 22:30" },
	    { value: 'mon..fri', text: gettext("Monday to Friday") + " 00:00" },
	    { value: 'mon..fri */1:00', text: gettext("Monday to Friday") + ': ' + gettext("hourly") },
	    {
		value: 'mon..fri 7..18:00/15',
		text: gettext("Monday to Friday") + ', '
		    + Ext.String.format(gettext('{0} to {1}'), '07:00', '18:45') + ': '
		    + Ext.String.format(gettext("Every {0} minutes"), 15),
	    },
	    { value: 'sun 01:00', text: gettext("Sunday") + " 01:00" },
	    { value: 'sat *-1..7 15:00', text: gettext("First Saturday each month") + " 15:00" },
	],
    },

    tpl: [
	'<ul class="x-list-plain"><tpl for=".">',
	    '<li role="option" class="x-boundlist-item">{text}</li>',
	'</tpl></ul>',
    ],

    displayTpl: [
	'<tpl for=".">',
	    '{value}',
	'</tpl>',
    ],

});
