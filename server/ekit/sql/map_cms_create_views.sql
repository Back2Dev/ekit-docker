/* $Id: map_cms_create_views.sql,v 1.31 2007-12-03 07:30:58 triton Exp $ */
/*--------------------------------------------------------------
 *
 * Script to create views and tables in CMS database. 
 *
 * These views are handy because they reduce the complexity 
 * in the code that glues the systems together, and also has
 * the ability to insulate the logic from changes to the DB
 * structures.
 *
 * For example when we are getting a list of hotels (AKA locations),
 * we can just do "SELECT * FROM VW_LOCATION", or 
 * "SELECT * FROM VW_PARTICIPANT WHERE WSH_START_DATE>'2005-12-1'"
 *
 *-------------------------------------------------------------*/

/*--------------------------------------------------------------
	THIS ONE FIXES A PROBLEM AFTER RE-ATTACHING THE CMS DATABASE 
	(IF SQL SERVER RE-INSTALLED, OR RESTORING FROM A BACKUP)
USE CMS;
sp_change_users_login 'Auto_Fix', 'triton';
*/

/* -------------------------------------------------------------
 * Participant records, select with something like:
	SELECT * FROM VW_PARTICIPANT 	
		where cst_ref_no=724494;
		order by cst_ref_no desc;
- Note that you will get one record for each boss. 
- If querying by date range, the order by is important to group the boss records together
Here is an example with no bosses:
	SELECT * FROM VW_PARTICIPANT 	
		where id=724371
		order by id desc;

*/
If Exists (Select Table_Name From Information_Schema.Views
         Where Table_Name = 'VW_PARTICIPANT_BOSS')
   Drop View VW_PARTICIPANT_BOSS
Go
CREATE VIEW VW_PARTICIPANT_BOSS AS
  select 	
	cst1.cst_ref_no as 					id, 
	cst1.cst_salutation as				salutation,
	cst1.cst_fname as 					firstname, 
	cst1.cst_lname as 					lastname,
	cst1.cst_sex as 					sex,
	cst1.cst_title as 					title,
	cst1.cst_email as 					email,
	convert(varchar,cst1.cst_last_update_dt,20) as 	cst_last_update_dt,
	
	company.com_name as 				company,
	
	a.par_status as 			cms_status, 
	convert(varchar,a.par_last_update_dt,20) as 		par_last_update_dt,
	convert(varchar,a.par_send_ekit_dt,20) as 			par_send_ekit_dt,
	CASE
		WHEN par_eid_ekit_admin is null THEN CAST(RIGHT(htl_eid_ekit_admin,6) AS INTEGER)
		ELSE CAST(RIGHT(par_eid_ekit_admin,6) AS INTEGER) END as admin_id,
                                		
	boss.cst_fname as 					bossfirstname, 
	boss.cst_lname as 					bosslastname, 
	boss.cst_email as 					bossemail,
	boss.cst_ref_no as					bossid,
	convert(varchar,boss.cst_last_update_dt,20) as 	boss_last_update_dt,
	CASE 
		WHEN (cst1.cst_last_update_dt>par_last_update_dt) AND (cst1.cst_last_update_dt>boss.cst_last_update_dt) THEN convert(varchar,cst1.cst_last_update_dt,20)
		WHEN (boss.cst_last_update_dt>par_last_update_dt) AND (boss.cst_last_update_dt>cst1.cst_last_update_dt) THEN convert(varchar,boss.cst_last_update_dt,20)
		ELSE convert(varchar,par_last_update_dt,20) END as last_update_dt,
		
	convert(varchar,workshop.wsh_start_date,20) as 			startdate, 
	
	c.emp_fname + ' ' + c.emp_lname as 	execname,
	c.emp_email as					 	execemail,
	
	htl_map_id as 						locationcode, 
	htl_name as 						location, 
	htl_address as						locationaddress,
	htl_city as							locationcity, 
	htl.sta_postal_abbrev as 			locationstate, 
	
    hotel_rate.htr_package_rate as 		hotelrate,
    cls_code as							flag

  from customer as cst1
	inner join customer_contact on cst1.cst_id = csc_cst_id and csc_end_date is null
	inner join customer_manager on cst1.cst_id = csm_cst_customer_id 
	inner join customer as boss on csm_cst_manager_id = boss.cst_id 
	inner join participant as a on cst1.cst_id = a.par_cst_id
	  and a.par_id = (select max(b.par_id)
				from participant as b
				where a.par_cst_id = b.par_cst_id)
	inner join company on cst1.cst_com_id = com_id
	inner join workshop on a.par_wsh_id = wsh_id
	inner join hotel on wsh_htl_id = htl_id
	inner join employee as c on csc_eid_id = c.emp_eid_id
	  and c.emp_rev_id = (select max(d.emp_rev_id)
				from employee as d
				where c.emp_eid_id = d.emp_eid_id)
	inner join state_or_province as htl on htl_sta_id = htl.sta_id
    inner join hotel_rate on htl_id = htr_htl_id
    inner join rate_type on (htr_rty_id = rty_id
      and rty_id = 'rty000000001' 
      and htr_valid_from < wsh_start_Date
      and htr_valid_to > wsh_start_Date
      and htl_is_active = 'Y')
    inner join company_classification on (cls_id=par_cls_id)
Go
grant all on VW_PARTICIPANT_BOSS to triton
GO

/* -------------------------------------------------------
 * A Participant view that returns participants with NOT bosses, using the 
 where not exists.
 */

If Exists (Select Table_Name From Information_Schema.Views
         Where Table_Name = 'VW_PARTICIPANT_NOBOSS')
   Drop View VW_PARTICIPANT_NOBOSS
Go
CREATE VIEW VW_PARTICIPANT_NOBOSS AS
  select 	
	cst1.cst_ref_no as 					id, 
	cst1.cst_salutation as				salutation,
	cst1.cst_fname as 					firstname, 
	cst1.cst_lname as 					lastname,
	cst1.cst_sex as 					sex,
	cst1.cst_title as 					title,
	cst1.cst_email as 					email,
	convert(varchar,cst1.cst_last_update_dt,20) as 	cst_last_update_dt,
	
	company.com_name as 				company,
	
	a.par_status as 			cms_status, 
	convert(varchar,a.par_last_update_dt,20) as 		par_last_update_dt,
	convert(varchar,a.par_send_ekit_dt,20) as 			par_send_ekit_dt,
	eid_employee_id as admin_id,
                                		
	'' as bossfirstname, 
	'' as bosslastname, 
	'' as bossemail,
	NULL as bossid,
	convert(varchar,a.par_last_update_dt,20) as boss_last_update_dt,
	CASE 
		WHEN cst1.cst_last_update_dt>par_last_update_dt THEN convert(varchar,cst1.cst_last_update_dt,20)
		
		  ELSE convert(varchar,par_last_update_dt,20) END as last_update_dt,
		
	convert(varchar,workshop.wsh_start_date,20) as 			startdate, 
	
	c.emp_fname + ' ' + c.emp_lname as 	execname,
	c.emp_email as					 	execemail,
	
	htl_map_id as 						locationcode, 
	htl_name as 						location, 
	htl_address as						locationaddress,
	htl_city as							locationcity, 
	htl.sta_postal_abbrev as 			locationstate, 
	
    hotel_rate.htr_package_rate as 		hotelrate,
    cls_code as							flag

  from customer as cst1
	inner join customer_contact on cst1.cst_id = csc_cst_id and csc_end_date is null
	inner join participant as a on cst1.cst_id = a.par_cst_id
	  and a.par_id = (select max(b.par_id)
				from participant as b
				where a.par_cst_id = b.par_cst_id)
	inner join company on cst1.cst_com_id = com_id
	inner join workshop on a.par_wsh_id = wsh_id
	inner join hotel on wsh_htl_id = htl_id
	inner join employee_id on htl_eid_ekit_admin = eid_id
	inner join employee as c on csc_eid_id = c.emp_eid_id
	  and c.emp_rev_id = (select max(d.emp_rev_id)
				from employee as d
				where c.emp_eid_id = d.emp_eid_id)
	inner join state_or_province as htl on htl_sta_id = htl.sta_id
    inner join hotel_rate on htl_id = htr_htl_id
    inner join rate_type on (htr_rty_id = rty_id
      and rty_id = 'rty000000001' 
      and htr_valid_from < wsh_start_Date
      and htr_valid_to > wsh_start_Date
      and htl_is_active = 'Y')
    inner join company_classification on (cls_id=par_cls_id)
    
    WHERE NOT EXISTS (SELECT *
    		      FROM customer_manager
    		      INNER JOIN customer AS boss on csm_cst_manager_id = boss.cst_id
    		      WHERE cst1.cst_id = csm_cst_customer_id)
Go
grant all on VW_PARTICIPANT_NOBOSS to triton
GO

/* 
 * Another participant view to pick up people that are on hold/cancel/reschedule
*/
If Exists (Select Table_Name From Information_Schema.Views
         Where Table_Name = 'VW_PARTICIPANT_HOLD')
   Drop View VW_PARTICIPANT_HOLD
Go
CREATE VIEW VW_PARTICIPANT_HOLD AS  
select 	
	cst1.cst_ref_no as 					id, 
	cst1.cst_salutation as				salutation,
	cst1.cst_fname as 					firstname, 
	cst1.cst_lname as 					lastname,
	cst1.cst_sex as 					sex,
	cst1.cst_title as 					title,
	cst1.cst_email as 					email,
	convert(varchar,cst1.cst_last_update_dt,20) as 	cst_last_update_dt,
	
	company.com_name as 				company,
	
	a.par_status as 			cms_status, 
	convert(varchar,a.par_last_update_dt,20) as 		par_last_update_dt,
	convert(varchar,a.par_send_ekit_dt,20) as 			par_send_ekit_dt,
	624 as admin_id,
                                		
	'' as bossfirstname, 
	'' as bosslastname, 
	'' as bossemail,
	NULL as bossid,
	convert(varchar,a.par_last_update_dt,20) as boss_last_update_dt,
	CASE 
		WHEN cst1.cst_last_update_dt>par_last_update_dt THEN convert(varchar,cst1.cst_last_update_dt,20)
		
		  ELSE convert(varchar,par_last_update_dt,20) END as last_update_dt,
		
	'' as 			startdate, 
	
	c.emp_fname + ' ' + c.emp_lname as 	execname,
	c.emp_email as					 	execemail,
	
	CASE 
		WHEN a.par_status = 'I' THEN 'HOLD'
		  ELSE 'CANCEL' END as 	locationcode, 
	'' as 						location, 
	'' as						locationaddress,
	'' as							locationcity, 
	'' as 			locationstate, 
	
    0 as 		hotelrate,
    cls_code as							flag

  from customer as cst1
	inner join customer_contact on cst1.cst_id = csc_cst_id and csc_end_date is null
	inner join participant as a on cst1.cst_id = a.par_cst_id
	  and a.par_id = (select max(b.par_id)
				from participant as b
				where a.par_cst_id = b.par_cst_id)
	inner join company on cst1.cst_com_id = com_id
	inner join employee as c on csc_eid_id = c.emp_eid_id
	  and c.emp_rev_id = (select max(d.emp_rev_id)
				from employee as d
				where c.emp_eid_id = d.emp_eid_id)
    inner join company_classification on (cls_id=par_cls_id)
    
    WHERE a.par_status in( 'I','X')
GO
grant all on VW_PARTICIPANT_HOLD to triton
GO

/*
 * The is the big mother sucker...
 * A union of boss/noboss/hold, to make sure we get everything
 */
If Exists (Select Table_Name From Information_Schema.Views
         Where Table_Name = 'VW_PARTICIPANT')
   Drop View VW_PARTICIPANT
Go
create view VW_PARTICIPANT as 
select * from VW_PARTICIPANT_BOSS
UNION ALL 
select * from VW_PARTICIPANT_NOBOSS 
UNION ALL 
select * from VW_PARTICIPANT_HOLD 
GO

grant all on VW_PARTICIPANT to triton
GO

				
/* -------------------------------------------------------
 * Participant forms, select with something like:
	SELECT * FROM VW_PART_FORM
		where cst_ref_no=724494
		order by tic_short_name;
*/
IF EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.VIEWS
         WHERE TABLE_NAME = 'VW_PART_FORM')
   DROP VIEW VW_PART_FORM
GO
create view VW_PART_FORM as 
select 	cst1.cst_ref_no, 
	cst1.cst_fname+' '+cst1.cst_lname as FULLNAME, 
	tic_name as FORM,
	tic_short_name as FID,
	pti_receive_date as RCV_DATE,
	tic_to_be_returned as EXPECTED,
	pti_quantity_to_send as QTY,
	pti_receive_quantity as RCV_QTY,
	convert(varchar,pti_last_update_dt,20) as 		last_update_dt
from customer as cst1
inner join participant as a on cst1.cst_id = a.par_cst_id
  and a.par_cst_id = (select max(b.par_cst_id)
			from participant as b
			where a.par_cst_id = b.par_cst_id)
left outer join participant_tickler on a.par_id = pti_par_id
inner join tickler_item on pti_tic_id = tic_id
GO
grant all on VW_PART_FORM to triton
GO

/* -------------------------------------------------------
 * Workshop location, select with something like:
	SELECT * FROM VW_LOCATION where ACTIVE='Y' order by ID;
*/
IF EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.VIEWS
         WHERE TABLE_NAME = 'VW_LOCATION')
   DROP VIEW VW_LOCATION
GO
create view VW_LOCATION AS
select 
	CAST(RIGHT(HTL_ID,6) AS INTEGER) as ID,
	htl_map_id as LOC_CODE,
	htl_name as NAME,
	htl_name+', '+htl_city+', '+sta_postal_abbrev as NAME_LONG,
	htl_address AS ADDRESS,
	htl_city AS CITY,
	sta_name as STATE_LONG,
	sta_postal_abbrev as STATE,
	htl_zip AS ZIP,
	htl_reservation_phone AS RES_PHONE,
	htl_frontdesk_phone AS PHONE,
	htl_fax AS FAX,
	htl_email as EMAIL,
	htl_check_in as CHECKIN,
	htl_ekit_fax as ADMIN_FAX,
	htl_ekit_phone as ADMIN_PHONE,
	htl_is_active as ACTIVE_FLAG,
	convert(varchar,htl_last_update_dt,20) as 	last_update_dt
from HOTEL
inner join state_or_province on htl_sta_id=sta_id
GO
grant all on VW_LOCATION to triton
GO

/* -------------------------------------------------------
 * Administrators, select with something like:
	SELECT * FROM VW_ADMIN order by ADMIN_NAME;
*/
IF EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.VIEWS
         WHERE TABLE_NAME = 'VW_ADMIN')
   DROP VIEW VW_ADMIN
GO
create view VW_ADMIN AS
select 
	eid_employee_id as id,
	emp_fname+' '+emp_lname as ADMIN_NAME,
	emp_special_init as initials,
	substring(emp_email,1,charindex('@',emp_email)) + 'mappwi.com' as email,
	convert(varchar,emp_close_date,20) as 	emp_close_date,
	convert(varchar,emp_last_update_dt,20) as 	last_update_dt

 from EMPLOYEE e
inner join employee_id eid on e.emp_eid_id=eid.eid_id
	where e.emp_rev_id = (select max(d.emp_rev_id)
				from employee as d
				where e.emp_eid_id = d.emp_eid_id)
AND (emp_close_date is null or emp_close_date > '2005-1-1')
and emp_is_ekit_admin='Y'
GO
grant all on VW_ADMIN to triton
GO

/* -------------------------------------------------------
 * Exec consultants, select with something like:
	SELECT * FROM VW_EXEC order by FULLNAME;
*/
IF EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.VIEWS
         WHERE TABLE_NAME = 'VW_EXEC')
   DROP VIEW VW_EXEC
GO
create view VW_EXEC AS
select 
	eid_employee_id as id,
	emp_fname+' '+emp_lname as FULLNAME,
	emp_special_init as initials,
	emp_email as email,
	convert(varchar,emp_close_date,20) as		emp_close_date,
	emt_description as job_desc,
	convert(varchar,emp_last_update_dt,20) as 		last_update_dt
from EMPLOYEE e
inner join employee_id eid on e.emp_eid_id=eid.eid_id
inner join employee_type on emp_emt_id=emt_id
where e.emp_rev_id = (select max(d.emp_rev_id)
			from employee as d
			where e.emp_eid_id = d.emp_eid_id)
AND (emp_close_date is null or emp_close_date > '2005-1-1')
AND (emt_type in ('W','C'))
GO
grant all on VW_EXEC to triton
GO

/* -------------------------------------------------------
 * Workshops, select with something like:
	SELECT * FROM VW_WORKSHOP 
	WHERE wsdate>'12/12/2005' 
	order by wsdate;
*/
IF EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.VIEWS
         WHERE TABLE_NAME = 'VW_WORKSHOP')
   DROP VIEW VW_WORKSHOP
GO
CREATE VIEW VW_WORKSHOP AS
select 
	htl_map_id as LOC_CODE,
	wsh_map_id as ID,
	convert(varchar,wsh_start_date,20) as WSDATE,
	emp_fname+' '+emp_lname as admin_name,
	convert(varchar,wsh_last_update_dt,20) as 		last_update_dt
 from workshop 
	inner join hotel on wsh_htl_id=hotel.htl_id
	inner join employee as c on htl_eid_ekit_admin = c.emp_eid_id
	  and c.emp_rev_id = (select max(d.emp_rev_id)
				from employee as d
				where c.emp_eid_id = d.emp_eid_id)
where wsh_is_canceled < 1
GO
grant all on VW_WORKSHOP to triton
GO


/* -------------------------------------------------------
 * TABLE DEFINITIONS
 * ------------------------------------------------------- */

/* -------------------------------------------------------
 *
 * EKIT_PAR_UPLOAD - Record of participant upload activity
 *
 */
IF EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
         WHERE TABLE_NAME = 'EKIT_PAR_UPLOAD')
   DROP TABLE EKIT_PAR_UPLOAD
GO

    CREATE TABLE EKIT_PAR_UPLOAD
        (
        ID            INTEGER IDENTITY(1,1)PRIMARY KEY CLUSTERED,
        WHEN_DT       UD_LAST_UPDATE_DT,
        RECORDS       INTEGER,
        TITLE         varchar(50),
        HTTP_STATUS   INTEGER,
        HTTP_BYTES    INTEGER,
        HTTP_MESSAGE  VARCHAR(100),
        HTTP_BODY     VARCHAR(500),
        FILENAME      varchar(250),
        TABLENAME     varchar(50),
        PAR_LAST_DT   DATETIME,
        PAR_LAST_ID   INTEGER
        )
GO
grant all on EKIT_PAR_UPLOAD to triton
GO
/* -------------------------------------------------------
 *
 * EKIT_PAR_DOWNLOAD - Record of participant download activity
 *
 */
IF EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
         WHERE TABLE_NAME = 'EKIT_PAR_DOWNLOAD')
   DROP TABLE EKIT_PAR_DOWNLOAD
GO

    CREATE TABLE EKIT_PAR_DOWNLOAD
        (
        ID            INTEGER IDENTITY(1,1)PRIMARY KEY CLUSTERED,
        WHEN_DT       UD_LAST_UPDATE_DT,
        RECORDS       INTEGER,
        TITLE         varchar(50),
        HTTP_STATUS   INTEGER,
        HTTP_BYTES    INTEGER,
        HTTP_MESSAGE  VARCHAR(100),
        HTTP_BODY     VARCHAR(500),
        TABLENAME     varchar(50),
        PAR_LAST_DT   DATETIME
        )
GO
grant all on EKIT_PAR_DOWNLOAD to triton
GO

/* -------------------------------------------------------
 *
 * EKIT_PAR_HOTEL - Record of hotel booking update activity
 *
 */
IF EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
         WHERE TABLE_NAME = 'EKIT_PAR_HOTEL')
   DROP TABLE EKIT_PAR_HOTEL
GO

    CREATE TABLE EKIT_PAR_HOTEL
        (
        ID            	INTEGER IDENTITY(1,1)PRIMARY KEY CLUSTERED,
        WHEN_DT       	UD_LAST_UPDATE_DT,
        RECORDS       	INTEGER,
        TITLE         	varchar(50),
        LAST_UPDATE_TS  INTEGER
        )
GO
grant all on EKIT_PAR_HOTEL to triton
GO


/* -------------------------------------------------------
 *
 * EKIT_PWI_STATUS - Holds Status + encrypted Credit Card information on it's way to the CMS system
 *
 */
IF EXISTS (SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
         WHERE TABLE_NAME = 'EKIT_PWI_STATUS')
   DROP TABLE EKIT_PWI_STATUS
GO
CREATE TABLE EKIT_PWI_STATUS(
			UID VARCHAR(50) NOT NULL PRIMARY KEY,
			PWD VARCHAR(15),
			CNT INTEGER,
			ISREADY INTEGER,
			Q1 INTEGER,
			Q2 INTEGER,
			Q3 INTEGER,
			Q4 INTEGER,
			Q5 INTEGER,
			Q6 INTEGER,
			Q7 INTEGER,
			Q8 INTEGER,
			Q9 INTEGER,
			Q10A INTEGER,
			Q10 INTEGER,
			Q11 INTEGER,
			Q12 INTEGER,
			Q18 INTEGER,
			FULLNAME VARCHAR(60),
			BATCHNO INTEGER,
			EXECNAME VARCHAR(60),
			LOCID VARCHAR(12),
			LOCNAME VARCHAR(60),
			WSID VARCHAR(25),
			WSDATE_D DATETIME,
			DUEDATE_D DATETIME,
			NBOSS INTEGER,
			NPEER INTEGER,
/* Added for hotel booking */
			CREDIT_CARD_HOLDER VARCHAR(40),
			CCT_ID VARCHAR(12),
			CREDIT_CARD_NO VARCHAR(20),
			CREDIT_CARD_REC VARCHAR(20),
			CREDIT_EXP_DATE VARCHAR(15),
			EARLY_ARRIVAL VARCHAR(2),
			EARLY_ARRIVAL_DATE DATETIME,
			EARLY_ARRIVAL_TIME VARCHAR(10),
			WITH_GUEST VARCHAR(2),
			GUEST_DINNER_DAY1 VARCHAR(2),
			GUEST_DINNER_DAY2 VARCHAR(2),
			DIETARY_RESTRICT VARCHAR(255),
			REVISED_FULLNAME VARCHAR(80),
			OCCUPANCY VARCHAR(20),
			LAST_UPDATE_TS INTEGER
			)
GO
grant all on EKIT_PWI_STATUS to triton
GO
/* END OF FILE */

