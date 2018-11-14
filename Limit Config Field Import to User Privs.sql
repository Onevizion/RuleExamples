/*Limit Config Field Import to User Privs
1) Get a list of Column Headers from the Grid Data matching with ConfifField Name or label
	a) See if this User has Privs to edit
		yes) swap field label for names
		no) delete column header and insert error log entry for removing the column header
 */
declare
	ThisImpRun number := :IMP_RUN_ID;
	ThisUser number;
	CFPrivs varchar2(255);
	HasPermission number;
begin
	-- The curently Logged in user running this import
	ThisUser := util.GetCurrentUserID;
	for col in (
		-- Get a list of un-mapped column headers in this import and see if they match to an ConfigField Name or label
		with conf_field as (
			-- Get complete labels for config fields to compare column headers
			select
				cf.config_field_id,
				cf.config_field_name,
				xl.label_program_text || ' ' || fl.label_program_text complete_label
			from
				config_field cf
				join xitor_type xt on (xt.xitor_type_id = cf.xitor_type_id)
				left outer join users u on (u.user_id = util.GetCurrentUserID)
				join label_program xl on (xl.app_lang_id = nvl(u.app_lang_id,1) and xl.label_program_id = xt.prefix_label_id)
				join label_program fl on (fl.app_lang_id = nvl(u.app_lang_id,1) and fl.label_program_id = cf.app_label_id)
			)
		select
			i.col_num num,
			i.data,
			conf_field.*
		from
			imp_run_grid_incr i
			join imp_run ir on (ir.imp_run_id = i.imp_run_id)
			left outer join imp_column ic on (
				ic.IMP_SPEC_ID = ir.imp_spec_id
				and
				ic.NAME = i.data
				)
			left outer join conf_field on (
				conf_field.config_field_name = i.data
				or
				conf_field.complete_label = i.data
				)
		where
			i.imp_run_id = ThisImpRun
			and
			-- Row zero has the column headers
			i.row_num = 0
			and
			-- This eliminates defined columns that will be used for mappings
			ic.IMP_COLUMN_ID is null
	)loop
		-- See if any columns have config field matches
		if (col.config_field_id is not null)then
			-- Get user's Privs for this Field
			CFPrivs := pkg_vqsecurity.get_max_field_privs_by_uid(
				p_user_id	=> util.GetCurrentUserID,
				p_cfid		=> col.config_field_id,
				p_prog_id	=> pkg_sec.get_pid,
				p_ignore_ro	=> 1
				);
			-- Do stuff if this user doesn't have permissions
			if instr(CFPrivs,'E') = 0 then
				-- Delete Column Header in grid table
				update imp_run_grid_incr set data = null
				where imp_run_id = ThisImpRun and row_num = 0 and col_num = col.num;
				commit;
				-- Add error message for skipping column
				insert into imp_run_error
					(program_id,imp_run_id,imp_error_type_id,error_msg)
					values
					(pkg_sec.get_pid,ThisImpRun,19,'You do not have permissions for column '||col.data);
			else
			-- If user does have privs, make sure to swich to CFName instead of label
				update imp_run_grid_incr set data = col.config_field_name
				where imp_run_id = ThisImpRun and row_num = 0 and col_num = col.num;
				commit;
			end if;
		end if;
	end loop;
end;