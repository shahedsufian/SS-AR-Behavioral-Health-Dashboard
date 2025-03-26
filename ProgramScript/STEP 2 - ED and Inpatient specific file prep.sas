/*seperate ED and IP claims*/
proc sql; 
	create table ssdrive.ed_bh_claims as /*287,281*/
		select distinct *
		from rdrive.total_claims_set
		where type = "ED";

	create table ssdrive.ip_bh_claims as /*348,037*/
		select distinct *
		from rdrive.total_claims_set
		where type = "inpatient";
quit;

/*ip roll up*/
/*calculate first and last dates in order to determine length of stay*/
proc sql; /*225,261*/
	create table ip_basic_dates as	
		select distinct MPID, case	
				when MC018_AdmissionDate ne "01JAN1900"d and MC059_DateOfServiceFrom ne "01JAN1900"d and MC018_AdmissionDate ge "01JAN2020"d then coalesce(MC018_AdmissionDate, MC059_DateOfServiceFrom) 
				when MC018_AdmissionDate is not null and MC018_AdmissionDate ne "01JAN1900"d and MC018_AdmissionDate ge "01JAN2020"d then MC018_AdmissionDate
				when MC059_DateOfServiceFrom is not null and MC059_DateOfServiceFrom ne "01JAN1900"d and MC059_DateOfServiceFrom ge "01JAN2020"d then MC059_DateOfServiceFrom
			end as IP_start format=date9., case
				when MC069_DischargeDate is not null and MC069_DischargeDate ne "31DEC9999"d then MC069_DischargeDate
				when MC060_DateOfServiceThru is not null and MC060_DateOfServiceThru ne "31DEC9999"d then MC060_DateOfServiceThru
			end as IP_end format=date9., MC023_FinalDischargeStatus
		from ssdrive.ip_bh_claims
		order by MPID, calculated ip_start, calculated ip_end desc;
quit;



/*remove nested dates*/
%macro nonestloop;

	data ip_nonest_dates; 
	set ip_basic_dates;
	by mpid;
	ipstartlast = lag(ip_start);
	ipendlast = lag(ip_end);
	if first.mpid = 0 then do;
		if ip_start ge ipstartlast and ip_end le ipendlast then delete;
	end;
	format ipstartlast ipendlast date9.;
	run;

	%do %until (&lastlength = &nowlength);

		proc sql; select count(*) into :lastlength from ip_nonest_dates; quit;

		data ip_nonest_dates; 
		set ip_nonest_dates;
		by mpid;
		ipstartlast = lag(ip_start);
		ipendlast = lag(ip_end);
		if first.mpid = 0 then do;
			if ip_start ge ipstartlast and ip_end le ipendlast then delete;
		end;
		format ipstartlast ipendlast date9.;
		run;

		proc sql; select count(*) into :nowlength from ip_nonest_dates; quit;

	%end;
%mend nonestloop;

%nonestloop; /*159,158*/



/*creating sequence*/
data ip_seqs;  /*159,158*/
	set ip_nonest_dates;
	by mpid ip_start ip_end ;
	if first.mpid then seq = 1;
	else seq+1;
run;

proc sort data=ip_seqs;
by mpid seq;
run;

data ip_seqs_2; /*159,158*/
	set ip_seqs;
	by mpid seq;
	format discharge date9.;
	discharge = lag(ip_end);
	prev_discharge_status = lag(MC023_FinalDischargeStatus);
	length_of_stay=intck('day',ip_start,ip_end);
	if seq = 1 then	gap = .;/*sequence will be used to collect discharge date before/after gaps as needed*/
	if seq ne 1 then gap = intck('day',discharge,ip_start);
	drop discharge;
run;

/*any second visit that's within 30 days of a visit is rolled together with the first for followup eval*/
data mpid_index_seq_ref; /*159,158*/
	set ip_seqs_2;
	by mpid;
	if first.mpid then seqnew = 1;
	if gap le 30 then seqnew = seqnew;
	if gap > 30 then seqnew+1;
run;

/*any second visit that's within 1 day of a visit is rolled together with the first for full eval*/
data mpid_index_seq_full; /*159,158*/
	set ip_seqs_2;
	by mpid;
	if first.mpid then seqnew = 1;
	if gap le 1 then seqnew = seqnew;
	if gap > 1 then seqnew+1;
run;

/*readmits within 30 days but more than 1 day*/
/*these are excluded from our outpatient eval*/
proc sql; /*28,066*/
	create table ssdrive.ip_30day_readmits as	
		select distinct *
		from mpid_index_seq_ref
		where 30 ge gap > 1;
quit;

proc sql; /*76,224- these were ed claims that went straight to ip, these should be excluded for all*/
	create table rdrive.ed_into_ip as	
		select distinct a.MPID, b.MC059_DateOfServiceFrom as ip_start, a.MC059_DateOfServiceFrom as date_of_service
		from ssdrive.ed_bh_claims a left join ssdrive.ip_bh_claims b on a.MPID=b.MPID
		where intnx('day', b.MC059_DateOfServiceFrom, -1) = a.MC059_DateOfServiceFrom or a.MC059_DateOfServiceFrom = b.MC059_DateOfServiceFrom;
quit;

/*roll up back to back dates*/
/*version for demographics*/
proc sql; /*144,988*/
	create table ip_full_dates1 as	
		select distinct MPID, seqnew as seq, min(ip_start) as ip_start_new format=date9., max(ip_end) as ip_end_new format=date9., (calculated ip_end_new - calculated ip_start_new) as days_ip
		from mpid_index_seq_full
		group by MPID, seqnew;
quit;


/*ip seen in the ed within 30 days of non-rolled discharge*/
proc sql; /*38,077*/
	create table ssdrive.ip_ed_readmits as	 /* 38,077- these are ip visits that were "readmitted" to the ED (only) within 30 days for flagging*/
		select distinct  a.MPID, a.ip_start_new, a.ip_end_new, b.MC059_DateOfServiceFrom as date_seen_in_ed
		from ip_full_dates1 a left join ssdrive.ed_bh_claims b on a.MPID=b.MPID
		where a.ip_end_new < b.MC059_DateOfServiceFrom le intnx('day', a.ip_end_new, 30);
quit;

/*ip readmits within 30 days on the non-rolled up version*/
proc sql; /*for flagging*/ /*44,873*/
	create table ssdrive.ip_ip_readmits as	
		select distinct  a.MPID, a.ip_start_new, a.ip_end_new, b.MC059_DateOfServiceFrom as date_readmitted
		from ip_full_dates1 a left join ssdrive.ip_bh_claims b on a.MPID=b.MPID
		where a.ip_end_new < b.MC059_DateOfServiceFrom le intnx('day', a.ip_end_new, 30);
quit;

/*add full dates without rollup to claim information*/
proc sql; /*205,950*/
	create table ssdrive.ip_bh_fulldates_fc1 as	
		select distinct a.MPID, compress(b.MPID||put(b.ip_start_new,date9.)) as event, calendar_year, cy_county, fiscal_year, fy_county, quarter, q_county, ME013_MemberGender as gender, ME014_MemberDateOfBirth as DOB, race_ethnicity, payer_type, ccsr_category
			, ccsr_category_description as ccsr_desc, MC041_PrincipalDiagnosis as icd10, ICD_10_CM_Code_Description as icd10_desc, b.seq as ip_stay_numb, b.ip_start_new as ip_start_date, /*b.admit_hospital, */b.ip_end_new as ip_end_date
			,/* b.discharge_hospital, */MC023_FinalDischargeStatus, case
				when compress(b.MPID||put(b.ip_start_new,date9.)) in (select distinct compress(MPID||put(ip_start_new,date9.)) from ssdrive.ip_ed_readmits) then 1
				else 0
			end as ed_readmit, case
				when compress(b.MPID||put(b.ip_start_new,date9.)) in (select distinct compress(MPID||put(ip_start_new,date9.)) from ssdrive.ip_ip_readmits) then 1
				else 0
			end as ip_readmit_wi_30, case
				when compress(b.MPID||put(b.ip_start_new,date9.)) in (select distinct compress(MPID||put(ip_start,date9.)) from rdrive.ed_into_ip) then 1
				else 0
			end as admitted_from_ed
		from ssdrive.ip_bh_claims a left join ip_full_dates1 b on a.MPID=b.MPID
		where b.ip_start_new le a.MC059_DateOfServiceFrom le b.ip_end_new
		order by MPID, ip_stay_numb, ip_start_date;
quit;


/*rolled version for lookback/forward*/
/*roll up back to back dates*/

proc sql; /*116,922*/
	create table ip_full_dates1_rolled as	
		select distinct MPID, seqnew as seq, min(ip_start) as ip_start_new format=date9., max(ip_end) as ip_end_new format=date9., (calculated ip_end_new - calculated ip_start_new) as days_ip
		from mpid_index_seq_ref
		group by MPID, seqnew;
quit;

/*this is on the rolled up version*/
/*ip seen in the ed within 30 days of final discharge*/
proc sql;
	create table ssdrive.ip_ed_readmits_fc as /*7,077*/
		select distinct a.MPID, a.ip_start_new, a.ip_end_new, b.MC059_DateOfServiceFrom as date_seen_in_ed
		from ip_full_dates1_rolled a left join ssdrive.ed_bh_claims b on a.MPID=b.MPID 
		where ip_end_new < b.MC059_DateOfServiceFrom le intnx('day', a.ip_end_new, 30);
quit;

/*ip readmits within 30 days on the rolled up version (where the time included includes a roll up)*/
proc sql; /*for flagging*/ /*28,066*/
	create table ssdrive.ip_ip_readmits_fc as	
		select distinct  a.MPID, a.ip_start_new, a.ip_end_new, b.ip_start_new as date_readmitted
		from ip_full_dates1_rolled a left join ip_full_dates1 b on a.MPID=b.MPID 
		where a.ip_start_new < b.ip_start_new le a.ip_end_new;
quit;

/*add full dates with rollup to claim information*/
proc sql; /*196,795*/
	create table ssdrive.ip_bh_fulldates1 as	
		select distinct a.MPID, compress(b.MPID||put(b.ip_start_new,date9.)) as event, calendar_year, cy_county, fiscal_year, fy_county, quarter, q_county
			, ME013_MemberGender as gender, ME014_MemberDateOfBirth as DOB, race_ethnicity, payer_type, ccsr_category
			, ccsr_category_description as ccsr_desc, MC041_PrincipalDiagnosis as icd10, ICD_10_CM_Code_Description as icd10_desc, b.seq as ip_stay_numb
			, b.ip_start_new as ip_start_date, b.ip_end_new as ip_end_date, MC023_FinalDischargeStatus, case
				when compress(b.MPID||put(b.ip_start_new,date9.)) in (select distinct compress(MPID||put(ip_start_new,date9.)) from ssdrive.ip_ed_readmits_fc) then 1
				else 0
			end as ed_readmit, case
				when compress(b.MPID||put(b.ip_start_new,date9.)) in (select distinct compress(MPID||put(ip_start_new,date9.)) from ssdrive.ip_ip_readmits_fc) then 1
				else 0
			end as ip_30d_readmit_includes, case
				when compress(b.MPID||put(b.ip_start_new,date9.)) in (select distinct compress(MPID||put(ip_start,date9.)) from rdrive.ed_into_ip) then 1
				else 0
			end as admitted_from_ed
		from ssdrive.ip_bh_claims a left join ip_full_dates1_rolled b on a.MPID=b.MPID
		where b.ip_start_new le a.MC059_DateOfServiceFrom le b.ip_end_new
		order by MPID, ip_stay_numb, ip_start_date;
quit;


/*******************************************************************/
/*ed claims*/
proc sql;
	create table ssdrive.ed_ip_readmits as	/* 53,653 these are ed visits that were "readmitted" to the IP within 30 days for flagging for counts*/
		select distinct  a.MPID, compress(a.MPID||put(a.MC059_DateOfServiceFrom,date9.)) as event, a.MC059_DateOfServiceFrom as ed_date_of_service
			, b.MC059_DateOfServiceFrom as ip_date_of_service
		from ssdrive.ed_bh_claims a left join ssdrive.ip_bh_claims b on a.MPID=b.MPID
		where  intnx('day', a.MC059_DateOfServiceFrom, 1) < b.MC059_DateOfServiceFrom le intnx('day', a.MC059_DateOfServiceFrom, 30);
quit;

proc sql;
	  create table ssdrive.ed_alone as	/*142,171 these are stand alone ed visits that didn't go directly into ip*/
	  	select distinct MPID, compress(MPID||put(MC059_DateOfServiceFrom,date9.)) as event, calendar_year, cy_county, fiscal_year, fy_county, quarter
			, q_county, ME013_MemberGender as gender, ME014_MemberDateOfBirth as DOB, race_ethnicity, payer_type, ccsr_category
			, ccsr_category_description as ccsr_desc, MC041_PrincipalDiagnosis as icd10, ICD_10_CM_Code_Description as icd10_desc
			, MC059_DateOfServiceFrom as date_of_service, MC023_FinalDischargeStatus, case		
				when calculated event in (select distinct event from ssdrive.ed_ip_readmits) then 1
				else 0
			end as ed_ip_readmits
		from ssdrive.ed_bh_claims
		where calculated event not in (select distinct compress(MPID||put(date_of_service,date9.)) from rdrive.ed_into_ip)
		order by mpid, date_of_service;
quit;

proc sql; /*96,726*/
	create table ed_basic_dates as	
		select distinct MPID, date_of_service
		from ssdrive.ed_alone
		order by MPID, date_of_service;
quit;

/*need to exclude those within 30 days of another ed visit*/
/*creating sequence*/
data ed_seqs;  /*96,726*/
	set ed_basic_dates;
	by mpid date_of_service ;
	if first.mpid then seq = 1;
	else seq+1;
run;

proc sort data=ed_seqs;
by mpid seq;
run;

data ed_seqs2; /*96,726*/
	set ed_seqs;
	by mpid seq;
	format discharge date9.;
	discharge = lag(date_of_service); 
	if seq = 1 then	gap = .;/*sequence will be used to collect discharge date before/after gaps as needed*/
	if seq ne 1 then gap = intck('day',discharge,date_of_service);
	drop discharge;
run;

/*any second visit that's within 30 days of a visit is deleted*/
proc sql;
	create table ed_no_30days as /*80,674*/	
		select distinct *
		from ed_seqs2
		where gap is null or gap > 30;

	create table ssdrive.ed_ed_readmissions as /*16,052*/	
		select distinct *
		from ed_seqs2
		where gap is not null and gap le 30;

/*for flagging*/
	create table ssdrive.ed_ed_readmits_fc as /*42,048*/	
		select distinct  a.MPID, a.date_of_service, b.MC059_DateOfServiceFrom
		from ed_seqs2 a left join ssdrive.ed_bh_claims b on a.MPID=b.MPID
		where a.date_of_service < b.MC059_DateOfServiceFrom le intnx('day', a.date_of_service, 30);
quit;



/*full ed claims having taken out claims that are within 30 days of an "original" ed claims*/
proc sql; /*118,169*/
	create table ssdrive.ed_bh_claims1  as	
		select distinct *, case
			when event in (select distinct compress(MPID||put(date_of_service,date9.)) from ssdrive.ed_ed_readmits_fc) then 1
			else 0
		end as ed_readmit
		from ssdrive.ed_alone
		where event in (select distinct compress(MPID||put(date_of_service,date9.)) from ed_no_30days);
quit;

/*this is all, without exclusions*/
proc sql; /*142,171*/
	create table ssdrive.ed_bh_claims_fc1  as	
		select distinct *, case
			when event in (select distinct compress(MPID||put(date_of_service,date9.)) from ssdrive.ed_ed_readmits_fc) then 1
			else 0
		end as ed_readmit
		from ssdrive.ed_alone
		order by MPID, date_of_service, payer_type;
quit;


/*need to remove any individual events that have a nursing home stay, or hospice claims up to 30 days before or 30 days after*/
/*this is for lookback lookforward only, both ed & ip*/
/*identify potential newids*/
proc sql; /*994,437*/
	create table newids_of_interest as	
		select distinct a.MPID, b.newid, a.ip_start_date as start_date format=date9., a.ip_end_date as end_date format=date9.
		from ssdrive.ip_bh_fulldates1 a left join apcdclms.mpid_enrollsegs_24B0116to0624 b on a.MPID=b.MPID
			union
		select distinct a.MPID, b.newid, a.date_of_service as start_date, a.date_of_service as end_date
		from ssdrive.ed_bh_claims1 a left join apcdclms.mpid_enrollsegs_24B0116to0624 b on a.MPID=b.MPID;
quit;


/*find claims that fit the profile*/
proc sql; /*30,199,033*/
	create table ssdrive.peeps_full_claims as	
		select distinct &med_varis.
		from apcdclms.apcd_claims24b2019
		where "01DEC2019"d le MC059_DateOfServiceFrom le "31DEC2019"d
			and compress(MC001_submitter||MC137_CarrierSpecificUniqueMembe) in (select distinct newid from newids_of_interest)
				union
		select distinct &med_varis.
		from apcdclms.apcd_claims24b2020
		where compress(MC001_submitter||MC137_CarrierSpecificUniqueMembe) in (select distinct newid from newids_of_interest)
				union
		select distinct &med_varis.
		from apcdclms.apcd_claims24b2021
		where compress(MC001_submitter||MC137_CarrierSpecificUniqueMembe) in (select distinct newid from newids_of_interest)
				union
		select distinct &med_varis.
		from apcdclms.apcd_claims24b2022
		where compress(MC001_submitter||MC137_CarrierSpecificUniqueMembe) in (select distinct newid from newids_of_interest)
				union
		select distinct &med_varis.
		from apcdclms.apcd_claims24b2023
		where "01JAN2023"d le MC059_DateOfServiceFrom le "31JAN2023"d
			and compress(MC001_submitter||MC137_CarrierSpecificUniqueMembe) in (select distinct newid from newids_of_interest);
quit;

proc sql;
  	select distinct quote(compress(code," .")) into :hospice separated by "," 
	from hedis.Hedis_valuesets_2021
  	where value_set_name = "Hospice Encounter" and code_system = "UBREV";
quit;

/*find claims that fit the profile*/
proc sql; /*189,916*/
	create table pot_disqualifying_claims as	
		select distinct *
		from ssdrive.peeps_full_claims
		where (MC054_RevenueCode in (&hospice., &nurs_rev.)  
			or (MC036_TypeOfBill_Institutional in (&nurs_tob.) and MC054_RevenueCode in (&inpatient.))
			or (substr(MC036_TypeOfBill_Institutional,1,1) = "6" and MC054_RevenueCode not in (&loa.)));
quit;

proc sql;
	create table ssdrive.disqualifying_claims as	/*19,587*/
		select distinct b.MPID, b.newid, b.start_date, b.end_date, a.MC059_DateofServiceFrom, a.MC060_DateOfServiceThru, a.*
		from pot_disqualifying_claims a inner join newids_of_interest b on compress(a.MC001_submitter||a.MC137_CarrierSpecificUniqueMembe)=b.newid
		where intnx('day', b.end_date, 30) ge a.MC059_DateOfServiceFrom ge intnx('day', b.start_date, -30)
				or intnx('day', b.end_date, 30) ge a.MC060_DateOfServiceThru ge intnx('day', b.start_date, -30);;
quit;


/*take out those ip/ed incidences*/
proc sql;
	create table ssdrive.ed_bh_claims2 as /*117,011*/
		select distinct *
		from ssdrive.ed_bh_claims1
		where event not in (select distinct compress(MPID||put(start_date,date9.)) from ssdrive.disqualifying_claims);

	create table ssdrive.ip_bh_fulldates2 as	/*194,448*/
		select distinct *
		from ssdrive.ip_bh_fulldates1 
		where event not in (select distinct compress(MPID||put(start_date,date9.)) from ssdrive.disqualifying_claims);;
quit;

/*remove ed visits that have an ip stay of ANY kind within 30 days of discharge*/
/*find all inpatient stays*/
proc sql; /*413,981*/
	create table ed_newids as
		select distinct a.MPID, b.newid, a.date_of_service as start_date, a.date_of_service as end_date
		from ssdrive.ed_bh_claims1 a left join apcdclms.mpid_enrollsegs_24b0116to0624 b on a.MPID=b.MPID;
quit;

proc sql; /*/*547,787*/
	create table rdrive.all_inpatient_edpeeps as	
		select distinct b.MPID, b.newid, b.start_date, &med_varis.
		from ssdrive.peeps_full_claims a inner join ed_newids b on compress(a.MC001_submitter||a.MC137_CarrierSpecificUniqueMembe)=b.newid
		where a.MC054_RevenueCode in (&inpatient.);
quit;

proc sql; /*15,106*/
	create table ed_exclude as
		select distinct a.*
		from ssdrive.ed_bh_claims2 a left join rdrive.all_inpatient_edpeeps b on a.MPID=b.MPID
		where (intnx('day', a.date_of_service, 30) ge b.MC059_DateOfServiceFrom ge a.date_of_service)
			or (intnx('day', a.date_of_service, 30) ge b.MC060_DateOfServiceThru ge a.date_of_service);
quit;

proc sql; /*101,905*/
	create table ssdrive.ed_bh_claims3 as
		select distinct *
		from ssdrive.ed_bh_claims2 
		where event not in (select distinct event from ed_exclude);
quit;

/*remove ip visits that have a ip stay of ANY OTHER kind within 30 days of (final) discharge*/
/*find all inpatient stays*/
proc sql; /*571,687*/
	create table justip_newids as	
		select distinct a.MPID, b.newid, a.ip_start_date as start_date format=date9., a.ip_end_date as end_date format=date9.
		from ssdrive.ip_bh_fulldates2 a left join apcdclms.mpid_enrollsegs_24b0116to0624 b on a.MPID=b.MPID;
quit;


proc sql; /*1,537,723*/
	create table rdrive.all_inpatient_ippeeps as	
		select distinct b.MPID, b.newid, b.start_date, b.end_date, &med_varis.
		from ssdrive.peeps_full_claims a inner join justip_newids b on compress(a.MC001_submitter||a.MC137_CarrierSpecificUniqueMembe)=b.newid
		where a.MC054_RevenueCode in (&inpatient.);
quit;

proc sql; /*11,399*/
	create table ip_exclude as
		select distinct a.*
		from ssdrive.ip_bh_fulldates2 a left join rdrive.all_inpatient_ippeeps b on a.MPID=b.MPID
		where (intnx('day', a.ip_end_date, 30) ge b.MC059_DateOfServiceFrom ge a.ip_end_date);
quit;

proc sql; /*183,049*/
	create table ssdrive.ip_bh_fulldates3 as
		select distinct *
		from ssdrive.ip_bh_fulldates2 
		where event not in (select distinct event from ip_exclude);
quit;


/*exclude individual events where the patient died before being discharged*/
/*ed*/
proc sql;
	create table ed_deaths as /*217*/
		select distinct *
		from ssdrive.ed_bh_claims
		where MC023_FinalDischargeStatus in ("20", "22", "23", "24", "25", "26", "27", "28", "29", "40", "41", "42");

/*ip*/
	create table ip_deaths as /*379*/
		select distinct *
		from ssdrive.ip_bh_claims
		where MC023_FinalDischargeStatus in ("20", "22", "23", "24", "25", "26", "27", "28", "29", "40", "41", "42");
quit;

/*exclude those that died in the hospital for lookback/forward*/
/*flag them for the demographics*/
proc sql;
	create table ssdrive.ed_bh_claims4 as /*101,882*/
		select distinct *
		from ssdrive.ed_bh_claims3
		where event not in (select distinct compress(MPID||put(MC059_DateOfServiceFrom,date9.)) from ed_deaths);

	create table ssdrive.ed_bh_claims_fc2 as /*142,171*/
		select distinct *, case
			when event in (select distinct compress(MPID||put(MC059_DateOfServiceFrom, date9.)) from ed_deaths) then 1
			else 0
		end as death_at_discharge
		from ssdrive.ed_bh_claims_fc1;

	create table ssdrive.ip_bh_fulldates4 as /*182,842*/
		select distinct *
		from ssdrive.ip_bh_fulldates3
		where event not in (select distinct compress(MPID||put(MC059_DateOfServiceFrom,date9.)) from ip_deaths);

	create table ssdrive.ip_bh_fulldates_fc2 as /*205,950*/
		select distinct *, case	
			when event in (select distinct compress(MPID||put(MC059_DateOfServiceFrom, date9.)) from ip_deaths) then 1
			else 0
		end as death_at_discharge
		from ssdrive.ip_bh_fulldates_fc1;
quit;

