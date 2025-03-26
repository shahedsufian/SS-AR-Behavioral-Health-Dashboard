/*find all inpatient and ed visits with a primary diagnosis in the list of behavorial health ccsr*/

%let diag_info = MC041_PrincipalDiagnosis,MC042_OtherDiagnosis1,MC043_OtherDiagnosis2,MC044_OtherDiagnosis3,MC045_OtherDiagnosis4
,MC046_OtherDiagnosis5,MC047_OtherDiagnosis6,MC048_OtherDiagnosis7,MC049_OtherDiagnosis8,MC050_OtherDiagnosis9,MC051_OtherDiagnosis10
,MC052_OtherDiagnosis11,MC053_OtherDiagnosis12;

%let bh_ccsr = "MBD001", "MBD002", "MBD003", "MBD004", "MBD005", "MBD006", "MBD007", "MBD008", "MBD009", "MBD010", "MBD011", "MBD012", "MBD013", "MBD014", "MBD027";

%let sub_ccsr =  "MBD017", "MBD018", "MBD019", "MBD020", "MBD021", "MBD022", "MBD023", "MBD025", "MBD028", "MBD029", "MBD030", "MBD031", "MBD032", "MBD033";

%let bh_sub_ccsr_add = "MBD026", "MBD034";

%let inpatient = "0100","0101","0110","0111","0112","0113","0114","0116","0117","0118","0119","0120","0121","0122","0123","0124","0126","0127"
,"0128","0129","0130","0131","0132","0133","0134","0136","0137","0138","0139","0140","0141","0142","0143","0144","0146","0147","0148","0149","0150"
,"0151","0152","0153","0154","0156","0157","0158","0159","0160","0164","0167","0169","0170","0171","0172","0173","0174","0179","0190","0191","0192"
,"0193","0194","0199","0200","0201","0202","0203","0204","0206","0207","0208","0209","0210","0211","0212","0213","0214","0219","1000","1001","1002";

%let ed_cpt = "99281", "99282", "99283", "99284", "99085";
%let ed_rev = "0450", "0451", "0452", "0456", "0459", "0981";

%let loa = "0183", "0184";

proc sql;
  	select distinct quote(compress(code," .")) into :hospice separated by "," 
	from hedis.Hedis_valuesets_2021
  	where value_set_name = "Hospice Encounter" and code_system = "UBREV";
quit;

%let nurs_rev = "0022", "0190", "0191", "0192", "0193", "0194", "0199";
%let nurs_tob = "210", "211", "212", "213", "214", "215", "216", "217", "218", "21F", "21G", "21H"
, "21I", "21J", "21K", "21M", "21O", "21Q", "21X", "21Y", "21Z";

/*look at the dx codes assigned*/
proc sql;
	create table bh_dxcodes as
		select distinct *
		from lu.icd10_to_ccsr_2024_1
		where ICD_10_CM_Code in (select distinct ICD_10_CM_Code from lu.icd10_to_ccsr_2024_1 where ccsr_category in (&bh_ccsr., &sub_ccsr.));
quit;

proc sql;
	select distinct icd_10_cm_code into: bh_diags separated by '","' from bh_dxcodes;
quit;

proc sql;
	create table ccsr_for_bh_codes1 as	
		select distinct *
		from bh_dxcodes
		where Inpatient_Default_CCSR__Y_N_X_ = "Y" and ccsr_category in (&bh_ccsr., &sub_ccsr.);

	create table ccsr_for_bh_codes2 as
		select distinct *
		from bh_dxcodes
		where Inpatient_Default_CCSR__Y_N_X_ ne "Y" and ccsr_category in (&bh_ccsr., &sub_ccsr.) and ICD_10_CM_Code not in (select distinct ICD_10_CM_Code from ccsr_for_bh_codes1);

	create table ssdrive.ccsr_for_bh_codes as	
		select distinct *
		from ccsr_for_bh_codes1
			union
		select distinct *
		from ccsr_for_bh_codes2;
quit;

/*find all primary bh claims for last 6 months of 2019, 2020-2023, and first 6 months of 2024*/
proc sql;
	create table rdrive.bh_claims1 as
		select distinct &med_varis.
		from apcdclms.apcd_claims24b2019
		where MC041_PrincipalDiagnosis in ("&bh_diags.")
			and "01JUL2019"d le MC059_DateOfServiceFrom le "31DEC2019"d 
			union
		select distinct &med_varis.
		from apcdclms.apcd_claims24b2020
		where MC041_PrincipalDiagnosis in ("&bh_diags.")
			union
		select distinct &med_varis.
		from apcdclms.apcd_claims24b2021
		where MC041_PrincipalDiagnosis in ("&bh_diags.")
			union
		select distinct &med_varis.
		from apcdclms.apcd_claims24b2022
		where MC041_PrincipalDiagnosis in ("&bh_diags.")
			union
		select distinct &med_varis.
		from apcdclms.apcd_claims24b2023
		where MC041_PrincipalDiagnosis in ("&bh_diags.")
			union
		select distinct &med_varis.
		from apcdclms.apcd_claims24b2024
		where MC041_PrincipalDiagnosis in ("&bh_diags.")
			and "01JAN2024"d le MC059_DateOfServiceFrom le "30JUN2024"d;
quit;

/*get rid of passe flags*/
proc sql; 
	create table ssdrive.bh_nopasse_dups as	
		select distinct *
		from rdrive.bh_claims1
		where MC841_PASSE ne 1;
quit;

/*find ed and ip stays*/
/*excludes ICFs*/
proc sql; 
	create table rdrive.ip_ed_bh_claims as	
		select distinct compress(MC001_submitter||MC137_CarrierSpecificUniqueMembe) as newid, *, "inpatient" as type
		from ssdrive.bh_nopasse_dups
		where MC054_RevenueCode in (&inpatient.) and (substr(MC036_TypeOfBill_Institutional,1,2) in ("11", "12"))
			and "31DEC2023"d ge MC059_DateOfServiceFrom ge "01JAN2020"d
			union
		select distinct compress(MC001_submitter||MC137_CarrierSpecificUniqueMembe) as newid, *, "ED" as type
		from ssdrive.bh_nopasse_dups
		where (MC054_RevenueCode in (&ed_rev.) or MC055_ProcedureCode in (&ed_cpt.))
			and "31DEC2023"d ge MC059_DateOfServiceFrom ge "01JAN2020"d;
quit;

/*add mpids & define quarter & fiscal year*/
proc sql; 
	create table ip_ed_bh_starter as	
		select distinct a.MPID, case
			when b.MC059_DateOfServiceFrom < "01APR2020"d then "Q3_2020"
			when "01APR2020"d le b.MC059_DateOfServiceFrom < "01JUL2020"d then "Q4_2020"
			when "01JUL2020"d le b.MC059_DateOfServiceFrom < "01OCT2020"d then "Q1_2021"
			when "01OCT2020"d le b.MC059_DateOfServiceFrom < "01JAN2021"d then "Q2_2021"
			when "01JAN2021"d le b.MC059_DateOfServiceFrom < "01APR2021"d then "Q3_2021"
			when "01APR2021"d le b.MC059_DateOfServiceFrom < "01JUL2021"d then "Q4_2021"
			when "01JUL2021"d le b.MC059_DateOfServiceFrom < "01OCT2021"d then "Q1_2022"
			when "01OCT2021"d le b.MC059_DateOfServiceFrom < "01JAN2022"d then "Q2_2022"
			when "01JAN2022"d le b.MC059_DateOfServiceFrom < "01APR2022"d then "Q3_2022"
			when "01APR2022"d le b.MC059_DateOfServiceFrom < "01JUL2022"d then "Q4_2022"
			when "01JUL2022"d le b.MC059_DateOfServiceFrom < "01OCT2022"d then "Q1_2023"
			when "01OCT2022"d le b.MC059_DateOfServiceFrom < "01JAN2023"d then "Q2_2023"
			when "01JAN2023"d le b.MC059_DateOfServiceFrom < "01APR2023"d then "Q3_2023"
			when "01APR2023"d le b.MC059_DateOfServiceFrom < "01JUL2023"d then "Q4_2023"
			when "01JUL2023"d le b.MC059_DateOfServiceFrom < "01OCT2023"d then "Q1_2024"
			when "01OCT2023"d le b.MC059_DateOfServiceFrom < "01JAN2024"d then "Q2_2024"
		end as quarter, case
			when b.MC059_DateOfServiceFrom < "01APR2020"d then 1
			when "01APR2020"d le b.MC059_DateOfServiceFrom < "01JUL2020"d then 2
			when "01JUL2020"d le b.MC059_DateOfServiceFrom < "01OCT2020"d then 3
			when "01OCT2020"d le b.MC059_DateOfServiceFrom < "01JAN2021"d then 4
			when "01JAN2021"d le b.MC059_DateOfServiceFrom < "01APR2021"d then 5
			when "01APR2021"d le b.MC059_DateOfServiceFrom < "01JUL2021"d then 6
			when "01JUL2021"d le b.MC059_DateOfServiceFrom < "01OCT2021"d then 7
			when "01OCT2021"d le b.MC059_DateOfServiceFrom < "01JAN2022"d then 8
			when "01JAN2022"d le b.MC059_DateOfServiceFrom < "01APR2022"d then 9
			when "01APR2022"d le b.MC059_DateOfServiceFrom < "01JUL2022"d then 10
			when "01JUL2022"d le b.MC059_DateOfServiceFrom < "01OCT2022"d then 11
			when "01OCT2022"d le b.MC059_DateOfServiceFrom < "01JAN2023"d then 12
			when "01JAN2023"d le b.MC059_DateOfServiceFrom < "01APR2023"d then 13
			when "01APR2023"d le b.MC059_DateOfServiceFrom < "01JUL2023"d then 14
			when "01JUL2023"d le b.MC059_DateOfServiceFrom < "01OCT2023"d then 15
			when "01OCT2023"d le b.MC059_DateOfServiceFrom < "01JAN2024"d then 16
		end as quarter_order, case
			when "01JAN2020"d le b.MC059_DateOfServiceFrom < "01JUL2020"d then "2020"
			when "01JUL2020"d le b.MC059_DateOfServiceFrom < "01JUL2021"d then "2021"
			when "01JUL2021"d le b.MC059_DateOfServiceFrom < "01JUL2022"d then "2022"
			when "01JUL2022"d le b.MC059_DateOfServiceFrom < "01JUL2023"d then "2023"
			when "01JUL2023"d le b.MC059_DateOfServiceFrom < "01JAN2024"d then "2024"
		end as fiscal_year, case
			when "01JAN2020"d le b.MC059_DateOfServiceFrom < "01JAN2021"d then "2020"
			when "01JAN2021"d le b.MC059_DateOfServiceFrom < "01JAN2022"d then "2021"
			when "01JAN2022"d le b.MC059_DateOfServiceFrom < "01JAN2023"d then "2022"
			when "01JAN2023"d le b.MC059_DateOfServiceFrom < "01JAN2024"d then "2023"
		end as calendar_year, b.*
		from rdrive.ip_ed_bh_claims b left join (select distinct * from apcdclms.mpix_roster24b0116to0624 where type = "NID") a on b.newid=a.value;
quit;

/*count newids with no mpid by quarter*/
proc sql;
	create table no_mpids as	
		select distinct quarter, quarter_order, count(distinct newid) as newids_nompids
		from ip_ed_bh_starter
		where MPID is null
		group by quarter
		order by quarter_order;

	create table yes_mpids as	
		select distinct quarter, quarter_order, count(distinct newid) as newids_yesmpids
		from ip_ed_bh_starter
		where MPID is not null
		group by quarter
		order by quarter_order;
quit;

/*get rid of blank mpids*/
proc sql; 
	create table rdrive.ip_ed_bh_starter  as	
		select distinct *
		from ip_ed_bh_starter
		where MPID is not null;
quit;


/*now we need to add demographic information on these individuals*/

/*find all nids for these individuals active anytime from 2020-2023*/
proc sql;
	create table bh_nids as	
		select distinct *
		from apcdclms.mpid_enrollsegs_24b0116to0624
		where MPID in (select distinct MPID from rdrive.ip_ed_bh_starter) and payer_type not in ("DNT", "MCRAdv Pharm", "MCR Pharm", "COM Pharm");

	create table bh_member_records as	
		select distinct a.MPID
			, a.newid
			, a.payer_type
			, a.ME162A_DateOfFirstEnrollment as segment_start
			, a.ME163A_DateOfDisenrollment as segment_end
			, a.maxped
			, b.ME018_MedicalServicesIndicator
			, b.ME003_InsuranceType_ProductCode
			, b.ME001_Submitter
			, b.ME107_CarrierSpecificUniqueMembe
        	, b.ME998_APCDUniqueId
        	, b.ME013_MemberGender
			, b.ME016_MemberStateOrProvince
			, b.ME017_MemberZipCode
			, b.ME021_MemberRace1
			, b.ME025_MemberEthnicity1
        	, b.ME014_MemberDateOfBirth
			, b.ME162A_DateOfFirstEnrollment /*need to keep these in order to correctly identify county in time periods*/
			, b.ME163A_DateOfDisenrollment
			, b.ME164A_HealthPlan
			, b.ME173A_MemberCounty
       	 	, b.PeriodEndingDate
		from bh_nids a inner join apcdclms.apcd_members24b b on a.newid = compress(b.ME001_Submitter||b.ME107_CarrierSpecificUniqueMembe)
		where b.ME162A_DateOfFirstEnrollment le "31DEC2023"d and b.ME163A_DateOfDisenrollment ge "01JAN2020"d
			and b.ME162A_DateOfFirstEnrollment ge a.ME162A_DateOfFirstEnrollment and b.ME163A_DateOfDisenrollment le b.ME163A_DateOfDisenrollment /*sc added*/
		order by MPID, PeriodEndingDate, ME162A_DateOfFirstEnrollment;
quit;


/*Checking cliam records that has any 'Pharm' as the payer type*/

proc sql;
    select distinct payer_type
    from apcdclms.mpid_enrollsegs_24b0116to0624
    where payer_type contains "Pharm";
quit;

proc sql;
    select distinct payer_type
    from bh_member_records
    where payer_type contains "Pharm";
quit;

/*find "best" race, gender and dob for each mpid*/

/*this wont be needed after it's updated in the roster, if we do that*/
/*take out blank sex and dobs*/
proc sql;
	create table onlypopulateddob as 
		select distinct *
		from bh_member_records
		where ME014_MemberDateOfBirth is not null
			and ME014_MemberDateOfBirth > "01JAN1910"d /*anything else is likely a typo*/
		order by MPID, PeriodEndingDate, ME162A_DateOfFirstEnrollment;

	create table onlypopulatedg as	
			select distinct *
		from bh_member_records
		where ME013_MemberGender in ("F", "M")
		order by MPID, PeriodEndingDate, ME162A_DateOfFirstEnrollment;

		/*make sure there aren't a bunch that are unpopulated for these*/
			/*there are zero here, but if you have any, you should probably exclude them*/
	create table unpopulateddob as	
		select distinct *
		from bh_member_records
		where MPID not in (select distinct MPID from onlypopulateddob);

	create table unpopulatedg as	
		select distinct *
		from bh_member_records
		where MPID not in (select distinct MPID from onlypopulatedg);
quit;

data bestage; 
set onlypopulateddob;
by MPID PeriodEndingDate ME162A_DateOfFirstEnrollment;
if last.MPID then output;
run;

data bestsex; 
set onlypopulatedg;
by MPID PeriodEndingDate ME162A_DateOfFirstEnrollment;
if last.MPID then output;
run;


/*just keep the stuffs we want*/
proc sql; 
	create table bestagesex2 as
		select distinct a.MPID, a.ME013_MemberGender, b.ME014_MemberDateOfBirth
		from bestsex a left join bestage b on a.MPID=b.MPID;
quit;


/*now race/ethnicity*/

/*If using race with Medicare Advantange, update race/ethnicity using Medicare FFS when possible*/
proc sql;
	create table mcradv_forrace as	
		select distinct *
		from bh_member_records
		where payer_type = "MCR Adv";

	create table mcradv_roster as	
		select distinct *
		from apcdclms.mpix_roster24b0116to0624
		where MPID in (select distinct MPID from mcradv_forrace)
			and type = "NID"
			and substr(value,1,6) = "99MCR1";
quit;

/*now look for them in the bene table*/
proc sql;
	create table mcradv_racereplace as	
		select distinct a.MPID, a.value as newid, b.ME021_MemberRace1, b.ME025_MemberEthnicity1
		from mcradv_roster a inner join mcrclms.mcr_bene b on compress(b.ME001_Submitter||b.ME107_CarrierSpecificUniqueMembe) = a.value;
quit; 

/*replace the mcr adv records race and ethnicity with the information from the ffs record*/
proc sql;
	create table full_cohort_mcrfix as 
		select distinct a.MPID, a.newid, case	
			when a.newid in (select distinct newid from mcradv_forrace) and a.ME021_MemberRace1 = "9999-9" or a.ME021_MemberRace1 is null then b.ME021_MemberRace1
			else a.ME021_MemberRace1
		end as ME021_MemberRace1b, case
			when a.newid in (select distinct newid from mcradv_forrace) and a.ME025_MemberEthnicity1 is null or a.ME025_MemberEthnicity1 in ("03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "33")  then b.ME025_MemberEthnicity1
			else a.ME025_MemberEthnicity1
		end as ME025_MemberEthnicity1b, a.*
	from bh_member_records a left join mcradv_racereplace b on a.MPID=b.MPID;
quit;


proc sql;
	create table race as 
		select distinct MPID, newid, case
				when ME021_MemberRace1b in ("1002-5", "1004-1", "1072-8") then "Native American"
				when ME021_MemberRace1b in ("2028-9", "2029-7", "2034-7", "2039-6", "2040-4", "2041-2", "2047-9") then "Asian"
				when ME021_MemberRace1b in ("2054-5", "2056-0", "2058-6") then "Black"
				when ME021_MemberRace1b in ("2036-2", "2076-8", "2079-2", "2080-0", "2086-7", "2500-7") then "Pacific Islander"
				when ME021_MemberRace1b in ("2106-3", "2110-5", "2116-2") then "White"
				when ME021_MemberRace1b in ("1886-1", "2131-1") then "Other"
				else "Unknown"
			end as race, case 
				when ME021_MemberRace1b in ("1002-5", "1004-1", "1072-8") then 2
				when ME021_MemberRace1b in ("2028-9", "2029-7", "2034-7", "2039-6", "2040-4", "2041-2", "2047-9") then 3
				when ME021_MemberRace1b in ("2054-5", "2056-0", "2058-6") then 5
				when ME021_MemberRace1b in ("2036-2", "2076-8", "2079-2", "2080-0", "2086-7", "2500-7") then 1
				when ME021_MemberRace1b in ("2106-3", "2110-5", "2116-2") then 6
				when ME021_MemberRace1b in ("1886-1", "2131-1") then 4
				else 7
			end as racenumber, ME021_MemberRace1b, payer_type, ME001_Submitter
		from  full_cohort_mcrfix
		order by MPID, racenumber;

	create table ethnic as 
		select distinct MPID, newid, case
				when ME025_MemberEthnicity1b in ("13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "34") then "Y"
				when ME025_MemberEthnicity1b in ("03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "33") then "N"
				else "U"
			end as ethnicity, case
				when ME025_MemberEthnicity1b in ("13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "34") then 1
				when ME025_MemberEthnicity1b in ("03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "33") then 2
				else 3
			end as ethnicitynumber, ME025_MemberEthnicity1b, payer_type, ME001_Submitter
		from  full_cohort_mcrfix
		order by MPID, ethnicitynumber;

	create table race_ethnicity as	
		select distinct a.MPID, a.newid, a.race, a.racenumber, a.ME021_MemberRace1b as ME021_MemberRace1, b.ethnicity
			, b.ethnicitynumber, b.ME025_MemberEthnicity1b as ME025_MemberEthnicity1, a.payer_type, a.ME001_Submitter
		from race a inner join ethnic b on a.MPID=b.MPID and a.newid=b.newid;
quit;



/*fixing the qhp race & ethnicity issues*/
/*issue = too many Asian assignments, looks like incorrect codes*/
proc sql; /**/
		/*replace race for qhp with race from mcd record*/
	create table qhp_racereplacements as 
		select distinct *
		from race_ethnicity
		where MPID in (select distinct MPID from race_ethnicity where payer_type = "MCD QHP")
			and MPID is not null
			and payer_type in ("MCD", "HCIP");

	create table new_qhp_race as /*77,928*/
		select distinct a.MPID, a.newid, b.race, b.racenumber, b.ME021_MemberRace1, b.ethnicity, b.ethnicitynumber, b.ME025_MemberEthnicity1, a.payer_type, a.ME001_Submitter
		from (select distinct * from race_ethnicity where payer_type = "MCD QHP" and MPID is not null) a left join qhp_racereplacements b on a.MPID=b.MPID;

	create table newrace as /*433,437*/
		select distinct a.MPID, a.newid, case
			when a.payer_type = "MCD QHP" and a.MPID is not null and b.race is not null then b.race
			when a.payer_type = "MCD QHP" and a.MPID is null then "Unknown"
			when a.payer_type = "MCD QHP" and a.MPID is not null and b.race is null then "Unknown"
			else a.race
		end as race, case
			when a.payer_type = "MCD QHP" and a.MPID is not null and b.race is not null then b.racenumber
			when a.payer_type = "MCD QHP" and a.MPID is null then 7
			when a.payer_type = "MCD QHP" and a.MPID is not null and b.race is null then 7
			else a.racenumber
		end as racenumber, case
			when a.payer_type = "MCD QHP" and a.MPID is not null and b.ME021_MemberRace1 is not null then b.ME021_MemberRace1
			when a.payer_type = "MCD QHP" and a.MPID is null then ""
			when a.payer_type = "MCD QHP" and a.MPID is not null and b.ME021_MemberRace1 is null then ""
			else a.ME021_MemberRace1
		end as ME021_MemberRace1, case
			when a.payer_type = "MCD QHP" and a.MPID is not null and b.ethnicity is not null then b.ethnicity
			when a.payer_type = "MCD QHP" and a.MPID is null then "Unknown"
			when a.payer_type = "MCD QHP" and a.MPID is not null and b.ethnicity is null then "Unknown"
			else a.ethnicity
		end as ethnicity, case
			when a.payer_type = "MCD QHP" and a.MPID is not null and b.ethnicity is not null then b.ethnicitynumber
			when a.payer_type = "MCD QHP" and a.MPID is null then 7
			when a.payer_type = "MCD QHP" and a.MPID is not null and b.ethnicity is null then 7
			else a.ethnicitynumber
		end as ethnicitynumber, case
			when a.payer_type = "MCD QHP" and a.MPID is not null and b.ME025_Memberethnicity1 is not null then b.ME025_Memberethnicity1
			when a.payer_type = "MCD QHP" and a.MPID is null then ""
			when a.payer_type = "MCD QHP" and a.MPID is not null and b.ME025_Memberethnicity1 is null then ""
			else a.ME025_Memberethnicity1
		end as ME025_Memberethnicity1, a.payer_type, a.ME001_Submitter
		from race_ethnicity a left join new_qhp_race b on a.MPID=b.MPID;
quit;


/*assign first race by rank order*/
proc sql;
	create table racenonblanks as 
		select distinct MPID, race, racenumber
		from newrace
		order by MPID, racenumber;
quit;

data raceassign; 
set racenonblanks;
by MPID racenumber;
if first.MPID then output;
run;


/*assign first ethnicity by rank order*/
proc sql;
	create table ethnonblanks as 
		select distinct MPID, ethnicity, ethnicitynumber
		from newrace
		order by MPID, ethnicitynumber;
quit;


data ethassign; 
set ethnonblanks;
by MPID ethnicitynumber;
if first.MPID then output;
run;


/*put "good" ones together*/
proc sql; 
	create table raceethnicitynonblank as
		select distinct a.MPID, a.race, b.ethnicity
		from raceassign a left join ethassign b on a.MPID=b.MPID;
quit;


/*replace dob, sex, and race/ethnicity in population table*/
/*and only keep those records in our timeline*/
proc sql; 
	create table totalpopinquestion_full (drop= ME025_MemberEthnicity1 ME021_MemberRace1) as
		select distinct a.MPID, a.newid, b.ME014_MemberDateOfBirth, b.ME013_MemberGender, c.race, c.ethnicity, a.*
		from bh_member_records a left join bestagesex2 b on a.MPID=b.MPID
			left join raceethnicitynonblank c on a.MPID=c.MPID;
quit;

proc sql;
	create table totalpopinquestion_full2 as /*1,768,991*/
		select distinct *
		from totalpopinquestion_full
		where payer_type ne "HCIP"
		order by MPID, segment_start;
quit;


libname geo xlsx "";
proc sql;
select distinct quote(strip(zip_code)) into :AR_zips separated by ","
from geo.zips;
quit;

/*clean up county*/
proc sql; 
	create table totalpopinquestion_full3 as
		select distinct a.*, case
				when substr(a.ME017_MemberZipCode,1,5) is not null and substr(a.ME017_MemberZipCode,1,5) in (&AR_zips.) and a.ME016_MemberStateOrProvince is null and a.ME173A_MemberCounty is null then b.FIPS_Code /*unsure of state, but based on zip code can assign county*/
				when substr(a.ME017_MemberZipCode,1,5) is not null and a.ME016_MemberStateOrProvince in ("05", "AR") and a.ME173A_MemberCounty is null then b.FIPS_Code /*in state, county based on zip code*/
				when substr(a.ME017_MemberZipCode,1,5) is null and a.ME173A_MemberCounty is null then "" /*no zip or county available*/
				when a.ME016_MemberStateOrProvince in ("05", "AR") and a.ME173A_MemberCounty is not null then a.ME173A_MemberCounty /*county obtained from member record*/
				when  substr(a.ME017_MemberZipCode,1,5) is not null and substr(a.ME017_MemberZipCode,1,5) not in (&AR_zips.) then "" /*out of state zip code*/
				when a.ME016_MemberStateOrProvince not in ("05", "AR") and a.ME016_MemberStateOrProvince is not null then "" /*out of state*/
				else a.ME173A_MemberCounty /*only has county available, using it as in member table, if it's bad, it wont join in next step*/
			end as County
		from totalpopinquestion_full2 a left join geoinfo.clean_county_xwalk b on substr(a.ME017_MemberZipCode,1,5)=b.zipcode;

	  create table totalpopinquestion_full4 as	
	  	select distinct a.*, b.clean_county
		from totalpopinquestion_full3 a left join geoinfo.clean_county_xwalk b on a.county=b.FIPS_Code;
quit;


/*need "best" county per year & "best" county per quarter*/
%macro county;
proc sql;
	create table members_&time. as	
		select distinct MPID, newid, PeriodEndingDate, ME162A_DateOfFirstEnrollment, ME163A_DateOfDisenrollment, clean_county
		from totalpopinquestion_full4
		where ME162A_DateOfFirstEnrollment le &stop. and ME163A_DateOfDisenrollment ge &start.
			and clean_county is not null
		order by MPID, PeriodEndingDate, ME162A_DateOfFirstEnrollment;

	create table null_members_&time. as
		select distinct MPID, newid, PeriodEndingDate, ME162A_DateOfFirstEnrollment, ME163A_DateOfDisenrollment, clean_county
		from totalpopinquestion_full4
		where MPID not in (select distinct MPID from members_&time.) and ME162A_DateOfFirstEnrollment ge &stop.
			and clean_county is not null
		order by MPID, ME162A_DateOfFirstEnrollment, PeriodEndingDate;

	create table doublenull_membs_&time. as
		select distinct MPID, newid, PeriodEndingDate, ME162A_DateOfFirstEnrollment, ME163A_DateOfDisenrollment, clean_county
		from totalpopinquestion_full4
		where MPID not in (select distinct MPID from members_&time.) and MPID not in (select distinct MPID from null_members_&time.)
			and clean_county is not null
		order by MPID, PeriodEndingDate, ME162A_DateOfFirstEnrollment;
quit;

data members2_&time.;
set members_&time.;
by MPID PeriodEndingDate ME162A_DateOfFirstEnrollment;
if last.MPID then output;
run;

data null_members2_&time.;
set null_members_&time.;
by MPID ME162A_DateOfFirstEnrollment PeriodEndingDate;
if first.MPID then output;
run;

data doublenull_membs2_&time.;
set doublenull_membs_&time.;
by MPID PeriodEndingDate ME162A_DateOfFirstEnrollment;
if last.MPID then output;
run;

proc sql;
	create table ssdrive.best_county_&time.  as
		select distinct MPID, clean_county
		from members2_&time.
			union
		select distinct MPID, clean_county
		from null_members2_&time.
			union
		select distinct MPID, clean_county
		from doublenull_membs2_&time.;
quit;

proc datasets library = work;
	delete members_&time.;
	delete null_members_&time.;
	delete doublenull_membs_&time.;
run;

%mend;

%let time = FY2020;
%let start = '01JAN2020'd;
%let stop = '30JUN2020'd;
%county;

%let time = FY2021;
%let start = '01JUL2020'd;
%let stop = '30JUN2021'd;
%county;

%let time = FY2022;
%let start = '01JUL2021'd;
%let stop = '30JUN2022'd;
%county;

%let time = FY2023;
%let start = '01JUL2022'd;
%let stop = '30JUN2023'd;
%county;

%let time = FY2024;
%let start = '01JUL2023'd;
%let stop = '31DEC2023'd;
%county;

%let time = 2020Q3;
%let start = '01JAN2020'd;
%let stop = '31MAR2020'd;
%county;

%let time = 2020Q4;
%let start = '01APR2020'd;
%let stop = '30JUN2020'd;
%county;

%let time = 2021Q1;
%let start = '01JUL2020'd;
%let stop = '30SEP2020'd;
%county;

%let time = 2021Q2;
%let start = '01OCT2020'd;
%let stop = '31DEC2020'd;
%county;

%let time = 2021Q3;
%let start = '01JAN2021'd;
%let stop = '31MAR2021'd;
%county;

%let time = 2021Q4;
%let start = '01APR2021'd;
%let stop = '30JUN2021'd;
%county;

%let time = 2022Q1;
%let start = '01JUL2021'd;
%let stop = '30SEP2021'd;
%county;

%let time = 2022Q2;
%let start = '01OCT2021'd;
%let stop = '31DEC2021'd;
%county;

%let time = 2022Q3;
%let start = '01JAN2022'd;
%let stop = '31MAR2022'd;
%county;

%let time = 2022Q4;
%let start = '01APR2022'd;
%let stop = '30JUN2022'd;
%county;

%let time = 2023Q1;
%let start = '01JUL2022'd;
%let stop = '30SEP2022'd;
%county;

%let time = 2023Q2;
%let start = '01OCT2022'd;
%let stop = '31DEC2022'd;
%county;

%let time = 2023Q3;
%let start = '01JAN2023'd;
%let stop = '31MAR2023'd;
%county;

%let time = 2023Q4;
%let start = '01APR2023'd;
%let stop = '30JUN2023'd;
%county;

%let time = 2024Q1;
%let start = '01JUL2023'd;
%let stop = '30SEP2023'd;
%county;

%let time = 2024Q2;
%let start = '01OCT2023'd;
%let stop = '31DEC2023'd;
%county;

%let time = CY2020;
%let start = '01JAN2020'd;
%let stop = '31DEC2020'd;
%county;

%let time = CY2021;
%let start = '01JAN2021'd;
%let stop = '31DEC2021'd;
%county;

%let time = CY2022;
%let start = '01JAN2022'd;
%let stop = '31DEC2022'd;
%county;

%let time = CY2023;
%let start = '01JAN2023'd;
%let stop = '31DEC2023'd;
%county;

/*create member file*/
proc sql;
	create table ssdrive.bhmember_file as	
		select distinct b.MPID, b.ME014_MemberDateOfBirth, b.ME013_MemberGender, b.race, b.ethnicity, case	
			when b.ethnicity = "Y" then "Hispanic"
			else b.race
		end as race_ethnicity, c.clean_county as county_FY2020, d.clean_county as county_FY2021, e.clean_county as county_FY2022, f.clean_county as county_FY2023
			, a.clean_county as county_FY2024, /*newly added*/ s.clean_county as county_CY2020, t.clean_county as county_CY2021, u.clean_county as county_CY2022
			, v.clean_county as county_CY2023, /*newly added*/ g.clean_county as county_2020Q3, h.clean_county as county_2020Q4, i.clean_county as county_2021Q1, j.clean_county as county_2021Q2
			, k.clean_county as county_2021Q3, l.clean_county as county_2021Q4, m.clean_county as county_2022Q1, n.clean_county as county_2022Q2
			, o.clean_county as county_2022Q3, p.clean_county as county_2022Q4, q.clean_county as county_2023Q1, r.clean_county as county_2023Q2
			, w.clean_county as county_2023Q3, /*newly added*/ x.clean_county as county_2023Q4, /*newly added*/ y.clean_county as county_2024Q1, /*newly added*/ z.clean_county as county_2024Q2 /*newly added*/
		from totalpopinquestion_full2 b left join ssdrive.best_county_FY2020 c on b.MPID=c.MPID
			left join ssdrive.best_county_FY2021 d on b.MPID=d.MPID
			left join ssdrive.best_county_FY2022 e on b.MPID=e.MPID
			left join ssdrive.best_county_FY2023 f on b.MPID=f.MPID
			left join ssdrive.best_county_FY2024 a on b.MPID=a.MPID /*newly added*/
			left join ssdrive.best_county_2020Q3 g on b.MPID=g.MPID
			left join ssdrive.best_county_2020Q4 h on b.MPID=h.MPID
			left join ssdrive.best_county_2021Q1 i on b.MPID=i.MPID
			left join ssdrive.best_county_2021Q2 j on b.MPID=j.MPID
			left join ssdrive.best_county_2021Q3 k on b.MPID=k.MPID
			left join ssdrive.best_county_2021Q4 l on b.MPID=l.MPID
			left join ssdrive.best_county_2022Q1 m on b.MPID=m.MPID
			left join ssdrive.best_county_2022Q2 n on b.MPID=n.MPID
			left join ssdrive.best_county_2022Q3 o on b.MPID=o.MPID
			left join ssdrive.best_county_2022Q4 p on b.MPID=p.MPID
			left join ssdrive.best_county_2023Q1 q on b.MPID=q.MPID
			left join ssdrive.best_county_2023Q2 r on b.MPID=r.MPID
			left join ssdrive.best_county_2023Q3 w on b.MPID=w.MPID /*newly added*/
			left join ssdrive.best_county_2023Q4 x on b.MPID=x.MPID /*newly added*/
			left join ssdrive.best_county_2024Q1 y on b.MPID=y.MPID /*newly added*/
			left join ssdrive.best_county_2024Q2 z on b.MPID=z.MPID /*newly added*/
			left join ssdrive.best_county_CY2020 s on b.MPID=s.MPID
			left join ssdrive.best_county_CY2021 t on b.MPID=t.MPID
			left join ssdrive.best_county_CY2022 u on b.MPID=u.MPID
			left join ssdrive.best_county_CY2023 v on b.MPID=v.MPID; /*newly added*/
quit;

/*assign claims to best demographic info & best county for that year and quarter*/
proc sql; 
	create table with_demographics as
		select distinct a.MPID, a.calendar_year, a.fiscal_year, a.quarter, a.quarter_order, b.ME014_MemberDateOfBirth, b.ME013_MemberGender, b.race
			, b.ethnicity, b.race_ethnicity, a.type, a.*
		from rdrive.ip_ed_bh_starter a left join ssdrive.bhmember_file b on a.MPID=b.MPID;
quit;

proc sql; /*sc updated join table & added where*/
	create table with_demo_toc as /*630,498 (lost about 5K due to claims being outside of the member record time period*/
		select distinct a.MPID, a.calendar_year, a.fiscal_year, a.quarter, a.quarter_order, case
				when b.payer_type in ("COM", "EBD", "EBD Ret", "QHP") then "COM"
				when b.payer_type = "MCD DDS" then "MCD"
				else b.payer_type
			end as payer_type, a.*
	from with_demographics a inner join (select distinct * from bh_nids where payer_type ne "HCIP") b on a.newid=b.newid
	where b.ME162A_DateOfFirstEnrollment le a.MC059_DateOfServiceFrom le b.ME163A_DateOfDisenrollment;
quit;

/*looking at those lost because their claim  falls outside of their dates of coverage*/
proc sql; /*4,685*/
	create table outsideoftime_post as /*3,396*/
		select distinct a.MPID, a.calendar_year, a.fiscal_year, a.quarter, a.quarter_order, case
				when b.payer_type in ("COM", "EBD", "EBD Ret", "QHP") then "COM"
				when b.payer_type = "MCD DDS" then "MCD"
				else b.payer_type
			end as payer_type, a.*
		from with_demographics a inner join (select distinct * from bh_nids where payer_type ne "HCIP") b on a.newid=b.newid
		where compress(a.MPID||a.newid||put(a.MC059_DateOfServiceFrom, date9.)) not in (select distinct compress(MPID||newid||put(MC059_DateOfServiceFrom, date9.)) from with_demo_toc)
			and a.MC059_DateOfServiceFrom < ME162A_DateOfFirstEnrollment;

	create table outsideoftime_pre as /*1,376*/
		select distinct a.MPID, a.calendar_year, a.fiscal_year, a.quarter, a.quarter_order, case
				when b.payer_type in ("COM", "EBD", "EBD Ret", "QHP") then "COM"
				when b.payer_type = "MCD DDS" then "MCD"
				else b.payer_type
			end as payer_type, a.*
		from with_demographics a inner join (select distinct * from bh_nids where payer_type ne "HCIP") b on a.newid=b.newid
		where compress(a.MPID||a.newid||put(a.MC059_DateOfServiceFrom, date9.)) not in (select distinct compress(MPID||newid||put(MC059_DateOfServiceFrom, date9.)) from with_demo_toc)
			and compress(a.MPID||a.newid||put(a.MC059_DateOfServiceFrom, date9.)) not in (select distinct compress(MPID||newid||put(MC059_DateOfServiceFrom, date9.)) from outsideoftime_post)
			and a.MC059_DateOfServiceFrom > ME163A_DateOfDisenrollment;

	create table outsideoftime as /*4,772*/
		select distinct *
		from outsideoftime_post
			union
		select distinct *
		from outsideoftime_pre;
quit;

proc sql; /*635,270*/
	create table with_demo_payer as
		select distinct *
		from with_demo_toc
			union
		select distinct *
		from outsideoftime;
quit;

proc sql; /*113*/  /*looked into these, orphan claims*/
	create table orphan_claims as
		select distinct *
		from with_demographics
		where compress(MPID||newid||put(MC059_DateOfServiceFrom, date9.)) not in (select distinct compress(MPID||newid||put(MC059_DateOfServiceFrom, date9.)) from with_demo_toc)
			and compress(MPID||newid||put(MC059_DateOfServiceFrom, date9.)) not in (select distinct compress(MPID||newid||put(MC059_DateOfServiceFrom, date9.)) from outsideoftime);
quit;

proc  sql;
	create table total_claims_wcounties as	/*635,270*/
		select distinct a.MPID, a.calendar_year, case
				when a.calendar_year = "2020" then r.clean_county
				when a.calendar_year = "2021" then s.clean_county
				when a.calendar_year = "2022" then t.clean_county
				when a.calendar_year = "2023" then u.clean_county
			end as CY_county, a.fiscal_year, case
				when a.fiscal_year = "2020" then b.clean_county
				when a.fiscal_year = "2021"  then c.clean_county
				when a.fiscal_year = "2022"  then d.clean_county
				when a.fiscal_year = "2023"  then e.clean_county
				when a.fiscal_year = "2024"  then v.clean_county
			end as FY_county, a.quarter, a.quarter_order, case	
				when a.quarter = "Q3_2020" then f.clean_county
				when a.quarter = "Q4_2020" then g.clean_county
				when a.quarter = "Q1_2021" then h.clean_county
				when a.quarter = "Q2_2021" then i.clean_county
				when a.quarter = "Q3_2021" then j.clean_county
				when a.quarter = "Q4_2021" then k.clean_county
				when a.quarter = "Q1_2022" then l.clean_county
				when a.quarter = "Q2_2022" then m.clean_county
				when a.quarter = "Q3_2022" then n.clean_county
				when a.quarter = "Q4_2022" then o.clean_county
				when a.quarter = "Q1_2023" then p.clean_county
				when a.quarter = "Q2_2023" then q.clean_county
				when a.quarter = "Q3_2023" then w.clean_county
				when a.quarter = "Q4_2023" then x.clean_county
				when a.quarter = "Q1_2024" then y.clean_county
				when a.quarter = "Q2_2024" then z.clean_county
			end as Q_county, payer_type, a.*
			from with_demo_payer a left join ssdrive.best_county_FY2020 b on a.MPID=b.MPID
				left join ssdrive.best_county_FY2021 c on a.MPID=c.MPID
				left join ssdrive.best_county_FY2022 d on a.MPID=d.MPID
				left join ssdrive.best_county_FY2023 e on a.MPID=e.MPID
				left join ssdrive.best_county_FY2024 v on a.MPID=v.MPID
				left join ssdrive.best_county_2020Q3 f on a.MPID=f.MPID
				left join ssdrive.best_county_2020Q4 g on a.MPID=g.MPID
				left join ssdrive.best_county_2021Q1 h on a.MPID=h.MPID
				left join ssdrive.best_county_2021Q2 i on a.MPID=i.MPID
				left join ssdrive.best_county_2021Q3 j on a.MPID=j.MPID
				left join ssdrive.best_county_2021Q4 k on a.MPID=k.MPID
				left join ssdrive.best_county_2022Q1 l on a.MPID=l.MPID
				left join ssdrive.best_county_2022Q2 m on a.MPID=m.MPID
				left join ssdrive.best_county_2022Q3 n on a.MPID=n.MPID
				left join ssdrive.best_county_2022Q4 o on a.MPID=o.MPID
				left join ssdrive.best_county_2023Q1 p on a.MPID=p.MPID
				left join ssdrive.best_county_2023Q2 q on a.MPID=q.MPID
				left join ssdrive.best_county_CY2020 r on a.MPID=r.MPID
				left join ssdrive.best_county_CY2021 s on a.MPID=s.MPID
				left join ssdrive.best_county_CY2022 t on a.MPID=t.MPID
				left join ssdrive.best_county_CY2023 u on a.MPID=u.MPID
				left join ssdrive.best_county_2023Q3 w on a.MPID=w.MPID
				left join ssdrive.best_county_2023Q4 x on a.MPID=x.MPID
				left join ssdrive.best_county_2024Q1 y on a.MPID=y.MPID
				left join ssdrive.best_county_2024Q2 z on a.MPID=z.MPID
			order by MPID, fiscal_year, quarter_order, MC059_DateOfServiceFrom;
quit;

proc sql; /*635,318*/
	create table ssdrive.total_claims_set as
		select distinct a.*, b.ICD_10_CM_Code_Description, b.ccsr_category, b.ccsr_category_Description
		from total_claims_wcounties a left join ssdrive.ccsr_for_bh_codes b on a.MC041_PrincipalDiagnosis=b.ICD_10_CM_Code;
quit;


/*adjust order place on the rdrive*/
proc sql; /*635,318*/
	create table rdrive.total_claims_set as	
		select distinct MPID, calendar_year, cy_county, fiscal_year, fy_county, quarter, quarter_order, q_county, payer_type, MC041_PrincipalDiagnosis
			, ICD_10_CM_Code_Description, ccsr_category, ccsr_category_Description, *
		from ssdrive.total_claims_set;
quit;


/*next step seperate ED vs IP claims & proceed*/