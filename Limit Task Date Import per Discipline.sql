/*Limit Task Date Import per Discipline
1) Get a list of Column Headers from the Grid Data
	a) See if this User has discpline
		yes) do nothing
		no) delete column header and insert error log entry for removing the column header
 */
declare
	ThisImpRun number := :IMP_RUN_ID;
	ThisUser number;
	OrdNum number;
	HasPermission number;
begin
	-- The curently Logged in user running this import
	ThisUser := util.GetCurrentUserID;
	for col in (
		-- Row zero has the column headers
		select
			i.col_num num,
			i.data
		from
			imp_run_grid_incr i
			join imp_run ir on (ir.imp_run_id = i.imp_run_id)
			left outer join imp_column ic on (
				ic.IMP_SPEC_ID = ir.imp_spec_id
				and
				ic.NAME = i.data
				)
		where
			i.imp_run_id = ThisImpRun
			and
			i.row_num = 0
			and
			ic.IMP_COLUMN_ID is null
	)loop
		-- This is a Task Date column if first 2 characters are correct
		if (
			(
				(substr(col.data,1,1) in ('P','A','B','R') and substr(col.data,2,1) in ('F','S'))
				or
				(substr(col.data,1,2) = 'NA')
			)
			and util.IsNumber(substr(col.data,3,100)) = 1
		)then
			-- Get Order Number of this column's task
			OrdNum := to_number(substr(col.data,3,100));
			-- Find if we have the discipline for this Task
			select
				count(*) cnt
			into
				HasPermission
			from
				wp_tasks t
				join user_obj_lookup uol on (
					uol.token_type_id = 16
					and uol.obj_id = t.discp_id
					and uol.user_id = ThisUser)
			where
				t.wp_workplan_id = 1001127408 --Augment Workplan Template ID
				and
				t.order_number = OrdNum;
			-- Do stuff if this user doesn't have permissions
			if HasPermission = 0 then
				-- Delete Column Header in grid table
				update imp_run_grid_incr set data = null
				where imp_run_id = ThisImpRun and row_num = 0 and col_num = col.num;
                commit;
				-- Add error message for skipping column
				insert into imp_run_error
					(program_id,imp_run_id,imp_error_type_id,error_msg)
					values
					(pkg_sec.get_pid,ThisImpRun,19,'You do not have permissions for column '||col.data);
			end if;
		end if;
	end loop;
end;