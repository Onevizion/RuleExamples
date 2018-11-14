/* Notify on Hourly/Nightly Rule Failures

Send a notification if any Hourly or Nightly Rules have failed in hte last 2 hours.
 */
declare
	v_Message_Body clob;
	v_This_System varchar(4000);
	v_Sender varchar2(4000);
	ErrCount number := 0;
begin
	/* Get System Parameters to insure mail changes stay in sync with current system */
	select value into v_This_System from param_system where name = 'DomainName';
	select value into v_Sender from param_system where name = 'NotificationSender';

	v_Message_Body := '<html>
	<head>
		<style>
			table {
				color: black;
				background-color: white;
                border-spacing: 0px;
				}
			th {
				font-weight: bold;
				background-color: LightGray;
				margin: 0px;
				padding: 5px;
				border: 1px solid gray;
				}
			td {
				margin: 0px;
				padding: 5px;
				border: 1px solid gray;
				}
		</style>
	</head>
	<body>
		<table>
			<tr>
				<th>Rule ID</th><th>Rule</th><th>Date</th><th>Status</th><th>Error</th>
			</tr>';
	for rec in (
		select
			r.rule_id,
			r.rule,
			to_char(prc.start_date,'mm/dd/yyyy hh24:mi:ss') start_date_time,
			sts.status,
			prc.error_message
		from
			rule_run rr
			join rule r on (r.rule_id = rr.rule_id)
			join process prc on (prc.process_id = rr.process_id)
			join process_status sts on (sts.process_status_id = prc.status_id)
		where
			sts.status <> 'Executed without Errors'
			and r.rule_type_id in (6,60) /* Nightly, Hourly*/
			and prc.start_date between current_date - 2/24 and current_date
			and r.rule <> 'Notify on Hourly Rule Failures' --this rule
		order by prc.start_date desc
	)loop
		ErrCount := ErrCount + 1;
		v_Message_Body :=
			v_Message_Body  ||
			'<tr>' ||
			'<td>' || rec.rule_id || '</td>' ||
			'<td>' || rec.rule || '</td>' ||
			'<td>' || rec.start_date_time || '</td>' ||
			'<td>' || rec.status || '</td>' ||
			'<td>' || substr(rec.error_message,1,200) || '</td>' ||
			'</tr>' || chr(10);

	end loop;
	v_Message_Body := v_Message_Body || '</table></body></html>';
	if ErrCount > 0 Then
		util.SendMail(
			Subject   => 'Failed Hourly Rules Notification for '||v_This_System,
			Message   => v_Message_Body,
			Sender    => 'Robot OneVizion <'||v_Sender||'>',
			Recipient => 'alert-email-address@company.com',
			--cc        => 'jsmith@company.com,mjones@company.com',
            --bcc       => null,
            --ReplyTo   => null,
			style     => 'HTML'
		);
	else
		return;
	end if;

exception when others then raise;
end;