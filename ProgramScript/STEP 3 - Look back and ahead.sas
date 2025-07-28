/*looking for 7 days, 30 days, 3 months and 6 months outpatient services before & after each ip and ed index date*/

%let icd10_proc = MC058_Principal_ICD_9_CM_Or_ICD_, MC058A_Other_ICD_9_CM_Or_ICD_10_, MC058B_Other_ICD_9_CM_Or_ICD_10_, MC058C_Other_ICD_9_CM_Or_ICD_10_, MC058D_Other_ICD_9_CM_Or_ICD_10_
	, MC058E_Other_ICD_9_CM_Or_ICD_10_, MC058EA_Other_ICD_9_CM_Or_ICD_10, MC058F_Other_ICD_9_CM_Or_ICD_10_, MC058G_Other_ICD_9_CM_Or_ICD_10_, MC058H_Other_ICD_9_CM_Or_ICD_10_
	, MC058J_Other_ICD_9_CM_Or_ICD_10_, MC058K_Other_ICD_9_CM_Or_ICD_10_, MC058L_Other_ICD_9_CM_Or_ICD_10_;

proc sql;
  	select distinct quote(compress(code," .")) into :out_ubrev separated by "," 
	from hedis.Hedis_valuesets_2021
  	where value_set_name = "Outpatient" and code_system = "UBREV";

  	select distinct quote(compress(code," .")) into :out_cpt separated by "," 
	from hedis.Hedis_valuesets_2021
  	where value_set_name = "Outpatient" and code_system = "CPT";

	select distinct quote(compress(code," .")) into :out_hcpcs separated by "," 
	from hedis.Hedis_valuesets_2021
  	where value_set_name = "Outpatient" and code_system = "HCPCS";

	select distinct quote(compress(code," .")) into :bhout_ubrev separated by ","
	from hedis.Hedis_valuesets_2021
	where value_set_name = "BH Outpatient" and code_system = "UBREV";

	select distinct quote(compress(code," .")) into :bhout_cpt separated by ","
	from hedis.Hedis_valuesets_2021
	where value_set_name = "BH Outpatient" and code_system = "CPT";

	select distinct quote(compress(code," .")) into :bhout_hcpcs separated by ","
	from hedis.Hedis_valuesets_2021
	where value_set_name = "BH Outpatient" and code_system = "HCPCS";

	select distinct quote(compress(code," .")) into :psy_cpt separated by ","
	from hedis.Hedis_valuesets_2021
	where value_set_name = "Psychiatry" and code_system = "CPT";

	select distinct quote(compress(code," .")) into :vsu_cpt separated by ","
	from hedis.Hedis_valuesets_2021
	where value_set_name = "Visit Setting Unspecified" and code_system = "CPT";

	select distinct quote(compress(code," .")) into :phone_cpt separated by ","
	from hedis.Hedis_valuesets_2021
	where value_set_name = "Telephone Visits" and code_system = "CPT";

	select distinct quote(compress(code," .")) into :online_cpt separated by ","
	from hedis.Hedis_valuesets_2021
  	where value_set_name = "Online Assessments" and code_system in ("CPT", "HCPCS");
quit;



/*look at the dx codes assigned as sequela*/
/*these are mh "follow up" codes that we need to add for the look forward and back*/
proc sql;
	create table bh_seq_codes as
		select distinct *
		from lu.icd10_to_ccsr_2024_1
		where ICD_10_CM_Code in (select distinct ICD_10_CM_Code from lu.icd10_to_ccsr_2024_1 where ccsr_category in (&bh_sub_ccsr_add.));
quit;

proc sql;
	select distinct icd_10_cm_code into: bh_sub_diags separated by '","' from bh_seq_codes;
quit;

proc sql;
	create table ccsr_for_bhseq1 as	
		select distinct *
		from bh_seq_codes
		where Inpatient_Default_CCSR__Y_N_X_ = "Y" and ccsr_category in (&bh_sub_ccsr_add.);

	create table ccsr_for_bhseq2 as
		select distinct *
		from bh_seq_codes
		where Inpatient_Default_CCSR__Y_N_X_ ne "Y" and ccsr_category in (&bh_sub_ccsr_add.) and ICD_10_CM_Code not in (select distinct ICD_10_CM_Code from ccsr_for_bhseq1);

	create table ssdrive.ccsr_for_bh_seq as	
		select distinct *
		from ccsr_for_bhseq1
			union
		select distinct *
		from ccsr_for_bhseq2;
quit;

/*find all primary bh claims for last 6 months of 2019, 2020-2023, and first 6 months of 2024*/
proc sql; /*227,099*/
	create table rdrive.bh_claimsseq as
		select distinct &med_varis.
		from apcdclms.apcd_claims24b2019
		where MC041_PrincipalDiagnosis in ("&bh_sub_diags.")
			and "01JUL2019"d le MC059_DateOfServiceFrom le "31DEC2019"d 
			union
		select distinct &med_varis.
		from apcdclms.apcd_claims24b2020
		where MC041_PrincipalDiagnosis in ("&bh_sub_diags.")
			union
		select distinct &med_varis.
		from apcdclms.apcd_claims24b2021
		where MC041_PrincipalDiagnosis in ("&bh_sub_diags.")
			union
		select distinct &med_varis.
		from apcdclms.apcd_claims24b2022
		where MC041_PrincipalDiagnosis in ("&bh_sub_diags.")
			union
		select distinct &med_varis.
		from apcdclms.apcd_claims24b2023
		where MC041_PrincipalDiagnosis in ("&bh_sub_diags.")
			union
		select distinct &med_varis.
		from apcdclms.apcd_claims24b2024
		where MC041_PrincipalDiagnosis in ("&bh_sub_diags.")
			and "01JAN2024"d le MC059_DateOfServiceFrom le "30JUN2024"d;
quit;

/*get rid of passe flags*/
proc sql; /*206,872*/
	create table ssdrive.bhseq_nopasse_dups as	
		select distinct *
		from rdrive.bh_claimsseq
		where MC841_PASSE ne 1;
quit;

/*put these together with the original bh/sa claims*/
proc sql; /*56,577,590*/
	create table ssdrive.all_prepost_available as		
		select distinct *
		from ssdrive.bh_nopasse_dups
			union
		select distinct *
		from ssdrive.bhseq_nopasse_dups;
quit;


/*bh claims that are outpatient*/
%macro outpatient;
proc sql; /*29,791,702*/
	create table ssdrive.outpatient_starter as	
		select distinct compress(MC001_submitter||MC137_CarrierSpecificUniqueMembe) as newid, *
		from ssdrive.all_prepost_available
		where ((MC054_RevenueCode not in (&inpatient.) and (substr(MC036_TypeOfBill_Institutional,1,2) not in ("11", "12"))
			and (MC055_ProcedureCode in (&psy_cpt.) 
			or MC058_Principal_ICD_9_CM_Or_ICD_ in (&psy_cpt.)
			%do i = 2 %to 13;
        		%let proccode = %scan((&icd10_proc.),&i," ,()",q);
				or &proccode. in (&psy_cpt.)
			%end;))
			or MC054_RevenueCode in (&out_ubrev., &bhout_ubrev.)
			or MC055_ProcedureCode in (&out_cpt., &out_hcpcs., &bhout_cpt., &bhout_hcpcs., &psy_cpt.) 
			or MC058_Principal_ICD_9_CM_Or_ICD_ in (&out_cpt., &out_hcpcs., &bhout_cpt., &bhout_hcpcs., &psy_cpt.)
			%do i = 2 %to 13;
        		%let proccode2 = %scan((&icd10_proc.),&i," ,()",q);
				or &proccode2. in (&out_cpt., &out_hcpcs., &bhout_cpt., &bhout_hcpcs., &psy_cpt.)
			%end;
);
quit;
%mend;
%outpatient;



/*bh claims that are telehealth*/
%macro tele;
proc sql; /*2,244,765*/
	create table telehealth_starter as	
		select distinct compress(MC001_submitter||MC137_CarrierSpecificUniqueMembe) as newid, *
		from ssdrive.all_prepost_available
		where ((MC055_ProcedureCode in (&vsu_cpt.) 
			or MC058_Principal_ICD_9_CM_Or_ICD_ in (&vsu_cpt.)
			%do i = 2 %to 13;
        		%let proccode = %scan((&icd10_proc.),&i," ,()",q);
				or &proccode. in (&vsu_cpt.)
			%end;) and MC037_FacilityType = 2)
			or MC055_ProcedureCode in (&phone_cpt., &online_cpt.) 
			or MC058_Principal_ICD_9_CM_Or_ICD_ in (&phone_cpt., &online_cpt.)
			%do i = 2 %to 13;
        		%let proccode2 = %scan((&icd10_proc.),&i," ,()",q);
				or &proccode2. in (&phone_cpt., &online_cpt.)
			%end;
;
quit;
%mend;
%tele;

/*did adding the telehealth add any we weren't capturing before?*/
proc sql; /*29,887,904*/
	create table ssdrive.outpatient_starter_wth as	
		select distinct *
		from telehealth_starter
			union
		select distinct *
		from ssdrive.outpatient_starter;
quit;

proc sql;
	create table ssdrive.outpatient_starter_wtf2 as /*29,887,904*/
		select distinct *, case
			when compress(newid||put(MC059_DateOfServiceFrom,date9.)||MC055_ProcedureCode|| MC058_Principal_ICD_9_CM_Or_ICD_) in 
				(select distinct compress(newid||put(MC059_DateOfServiceFrom,date9.)||MC055_ProcedureCode|| MC058_Principal_ICD_9_CM_Or_ICD_)  from telehealth_starter) then 1
			when MC037_FacilityType = 2 then 1
			else 0
		end as telehealth
		from ssdrive.outpatient_starter_wth;
quit;


/*add mpid*/
proc sql;
	create table ssdrive.outpatient_starter2 as	/*29,887,904*/
		select distinct b.MPID, a.*
		from ssdrive.outpatient_starter_wtf2 a left join (select distinct * from apcdclms.mpix_roster24b0116to0624 where type = "NID") b on a.newid=b.value;
quit;

/*only want those that are in our ed/ip groups*/
proc sql; /*5,351,512*/
	create table ssdrive.outpatient_starter3 as
		select distinct *
		from ssdrive.outpatient_starter2
		where MPID is not null and (MPID in (select distinct MPID from ssdrive.ip_bh_fulldates4) or MPID in (select distinct MPID from ssdrive.ed_bh_claims4));
quit;

/*take out ones that are at the same time as either inpatient or ed visits*/
proc sql;
	create table ssdrive.out_into_ed as	/*4,936*/ /*had an outpatient claims the same day as an ed claim.  we are keeping these now!  For flagging*/
		select distinct a.*, compress(a.MPID||put(a.MC059_DateOfServiceFrom,date9.)) as event
		from ssdrive.outpatient_starter3 a left join ssdrive.ed_bh_claims4 b on a.MPID=b.MPID
		where a.MC059_DateOfServiceFrom = b.date_of_service;

	create table ssdrive.out_into_ip as	/*48,974 had an outpatient visit same day as went inpatient.  For flagging*/
		select distinct a.*, compress(a.MPID||put(a.MC059_DateOfServiceFrom,date9.)) as event
		from ssdrive.outpatient_starter3 a left join ssdrive.ip_bh_fulldates4 b on a.MPID=b.MPID
		where b.ip_start_date = a.MC059_DateOfServiceFrom;

	create table ip_concurrent as /*245,637 these are likely ones that happened between two ip visits, but since this is after we rolled them, they look like they are the same time*/	
		select distinct a.*
		from ssdrive.outpatient_starter3 a left join ssdrive.ip_bh_fulldates4 b on a.MPID=b.MPID 
		where b.ip_start_date le a.MC059_DateOfServiceFrom le b.ip_end_date;

	  create table ssdrive.outpatient_starter4 as	/*5,105,875*/
	  	select distinct *
		from ssdrive.outpatient_starter3
		where compress(MPID||put(MC059_DateOfServiceFrom,date9.)) not in (select distinct  compress(MPID||put(MC059_DateOfServiceFrom,date9.)) from ip_concurrent);

		create table ssdrive.outpatient_starter5 as	/*3,924,873*/
			select distinct MPID, MC059_DateOfServiceFrom, MC041_PrincipalDiagnosis
			from ssdrive.outpatient_starter4;
quit;

/*using above to create flags in the demographic versions of the ED and IP files*/
proc sql;
	create table ssdrive.ip_for_demographics as /*205,950*/
		select distinct MPID, event, calendar_year, cy_county, fiscal_year, fy_county, quarter, q_county, gender, dob, race_ethnicity, payer_type, case
			when ccsr_category in (&bh_ccsr.) then "BH"
			when ccsr_category in (&sub_ccsr.) then "SA"
		end as event_type, ccsr_category, ccsr_desc, *, case	
			when event in (select distinct event from ssdrive.out_into_ip) then 1
			else 0
		end as outpatient_into_ip
		from ssdrive.ip_bh_fulldates_fc2;

	create table ssdrive.ed_for_demographics as /*142,171*/
			select distinct MPID, event, calendar_year, cy_county, fiscal_year, fy_county, quarter, q_county, gender, dob, race_ethnicity, payer_type, case
			when ccsr_category in (&bh_ccsr.) then "BH"
			when ccsr_category in (&sub_ccsr.) then "SA"
		end as event_type, ccsr_category, ccsr_desc, *, case	
			when event in (select distinct event from ssdrive.out_into_ed) then 1
			else 0
		end as outpatient_into_ed
		from ssdrive.ed_bh_claims_fc2;
quit;

proc sql;
	select distinct count(distinct event) as sent_to_ed /*3,924*/
	from ssdrive.out_into_ed;

	select distinct count(distinct event) as sent_to_ip /*28,893*/
	from ssdrive.out_into_ip;
quit;

		/*ed (only) first*/
/*date of service as index date*/
proc sql; /*2,261,641*/
	create table ed_lookback_forward as
		select distinct a.MPID, a.date_of_service as ed_index_dte, compress(a.MPID||put(a.date_of_service,date9.)) as event, a.ccsr_category, b.MC059_DateOfServiceFrom, intck('day',a.date_of_service
			, b.MC059_DateOfServiceFrom) as days_between format=comma8.
		from ssdrive.ed_bh_claims4 a left join ssdrive.outpatient_starter5 b on a.MPID=b.MPID; 
quit;

/*find first outpatient after the event*/
proc sql; /*1,058,877*/
	create table ed_forfirst as	
		select distinct *
		from ed_lookback_forward
		where days_between > 0
		order by event, days_between;
quit;

data ssdrive.calc_ed_first_out; /*45,442*/
set ed_forfirst;
by event days_between;
if first.event then output;
run;

proc sql; /*53,492*/
	create table ssdrive.ed_first_outpatient_event as	
		select distinct a.MPID, a.ed_index_dte, a.event, a.ccsr_category, a.days_between, b.*
		from ssdrive.calc_ed_first_out a left join ssdrive.outpatient_starter4 b on a.MPID=b.MPID and a.MC059_DateOfServiceFrom = b.MC059_DateOfServiceFrom;
quit;



/*lookback and forward files creation*/
proc sql;
	create table ed_lookback_start as	/*126,281*/
		select distinct MPID, ed_index_dte, compress(MPID||put(ed_index_dte,date9.)) as mpiddate, case	
			when -1 ge days_between ge -120 then 1
			else 0
		end as lookback120, case
			when -1 ge days_between ge -90 then 1
			else 0
		end as lookback90, case
			when -1 ge days_between ge -60 then 1
			else 0
		end as lookback60, case
			when -1 ge days_between ge -30 then 1
			else 0
		end as lookback30, case
			when -1 ge days_between ge -7 then 1
			else 0
		end as lookback7
		from ed_lookback_forward
		order by mpiddate, lookback120, lookback90, lookback60, lookback30, lookback7;
run;

data ed_lookback (drop=mpiddate); /*69,429*/
set ed_lookback_start;
by mpiddate lookback120 lookback90 lookback60 lookback30 lookback7;
if last.mpiddate then output;
run;

proc sql;
	create table ed_lookforward_start as	/*142,545*/
		select distinct MPID, ed_index_dte, compress(MPID||put(ed_index_dte,date9.)) as mpiddate, case	
			when 1 le days_between le 120 then 1
			else 0
		end as lookforward120, case
			when 1 le days_between le 90 then 1
			else 0
		end as lookforward90, case
			when 1 le days_between le 60 then 1
			else 0
		end as lookforward60, case
			when 1 le days_between le 30 then 1
			else 0
		end as lookforward30, case
			when 1 le days_between le 7 then 1
			else 0
		end as lookforward7
		from ed_lookback_forward
		order by mpiddate, lookforward120, lookforward90, lookforward60, lookforward30, lookforward7;
run;

data ed_lookforward (drop=mpiddate); /*69,429*/
set ed_lookforward_start;
by mpiddate lookforward120 lookforward90 lookforward60 lookforward30 lookforward7;
if last.mpiddate then output;
run;

proc sql;
	create table ssdrive.ed_lookback_forward as	/*101,882*/
		select distinct a.MPID, a.event, a.calendar_year, a.cy_county, a.fiscal_year, a.fy_county, a.quarter, a.q_county, a.gender, a.dob, a.race_ethnicity, a.payer_type, case
			when a.ccsr_category in (&bh_ccsr.) then "BH"
			when a.ccsr_category in (&sub_ccsr.) then "SA"
		end as event_type, a.ccsr_category, a.ccsr_desc, a.*, case
			when compress(a.MPID||put(a.date_of_service,date9.)) in (select distinct compress(MPID||put(MC059_DateOfServiceFrom,date9.)) from ssdrive.out_into_ed) then 1
			else 0
		end as outpat_ed_sameday, b.lookback120, b.lookback90, b.lookback60, b.lookback30, b.lookback7, c.lookforward7, c.lookforward30, c.lookforward60, c.lookforward90, c.lookforward120
		from ssdrive.ed_bh_claims4 a left join ed_lookback b on a.MPID = b.MPID and a.date_of_service = b.ed_index_dte
			left join ed_lookforward c on a.MPID = c.MPID and a.date_of_service = c.ed_index_dte
		order by a.MPID, a.date_of_service, a.payer_type;
quit;


/*initial output*/
proc sql;
	create table ssdrive.ed_lookbackforward_out (drop = putin) as	
		select distinct count(distinct event) as events format = comma8., "no known before" as timeline, 0 as putin
		from ssdrive.ed_lookback_forward
		where lookback120 ne 1
			union
		select distinct count(distinct event) as events, "back120" as timeline, 1 as putin
		from ssdrive.ed_lookback_forward
		where lookback120 = 1
			union
		select distinct count(distinct event) as events, "back90" as timeline, 2 as putin
		from ssdrive.ed_lookback_forward
		where lookback90 = 1
			union
		select distinct count(distinct event) as events, "back60" as timeline, 3 as putin
		from ssdrive.ed_lookback_forward
		where lookback60 = 1
			union
		select distinct count(distinct event) as events, "back30" as timeline, 4 as putin
		from ssdrive.ed_lookback_forward
		where lookback30 = 1
			union
		select distinct count(distinct event) as events, "back7" as timeline, 5 as putin
		from ssdrive.ed_lookback_forward
		where lookback7 = 1
			union
		select distinct count(distinct event) as events, "forward7" as timeline, 6 as putin
		from ssdrive.ed_lookback_forward
		where lookforward7 = 1
			union
		select distinct count(distinct event) as events, "forward30" as timeline, 7 as putin
		from ssdrive.ed_lookback_forward
		where lookforward30 = 1
			union
		select distinct count(distinct event) as events, "forward60" as timeline, 8 as putin
		from ssdrive.ed_lookback_forward
		where lookforward60 = 1
			union
		select distinct count(distinct event) as events, "forward90" as timeline, 9 as putin
		from ssdrive.ed_lookback_forward
		where lookforward90 = 1
			union
		select distinct count(distinct event) as events, "forward120" as timeline, 10 as putin
		from ssdrive.ed_lookback_forward
		where lookforward120 = 1
			union
		select distinct count(distinct event) as events, "no known after" as timeline, 11 as putin
		from ssdrive.ed_lookback_forward
		where lookforward120 ne 1
		order by putin;
quit;
		 

proc sql;
	select distinct count(distinct event) as total_events /*69,429*/
	from ssdrive.ed_lookback_forward;

	select distinct count(distinct mpid) as total_peeps /*53,409*/
	from ssdrive.ed_lookback_forward;

	select distinct count(distinct event) as events_same /*3,924*/
	from ssdrive.ed_lookback_forward
	where outpat_ed_sameday = 1;
quit;
				 

proc sql;
	select distinct count(distinct event) as total_events /*96,726*/
	from ssdrive.ed_bh_claims_fc1;

	select distinct count(distinct mpid) as total_peeps /*58,279*/
	from ssdrive.ed_bh_claims_fc1;
quit;





/*breakout by BH vs SA*/
proc sql; /*65,331*/
	create table ssdrive.ed_bh_lookbackforward as
		select distinct *
		from ssdrive.ed_lookback_forward
		where event_type = "BH";

	create table ssdrive.ed_sa_lookbackforward as	/*36,551*/
		select distinct *
		from ssdrive.ed_lookback_forward
		where event_type = "SA";
quit;


/*initial output*/
proc sql;
	create table ssdrive.ed_bh_out (drop = putin) as	
		select distinct count(distinct event) as events format = comma8., "no known before" as timeline, 0 as putin
		from ssdrive.ed_bh_lookbackforward
		where lookback120 ne 1
			union
		select distinct count(distinct event) as events, "back120" as timeline, 1 as putin
		from ssdrive.ed_bh_lookbackforward
		where lookback120 = 1
			union
		select distinct count(distinct event) as events, "back90" as timeline, 2 as putin
		from ssdrive.ed_bh_lookbackforward
		where lookback90 = 1
			union
		select distinct count(distinct event) as events, "back60" as timeline, 3 as putin
		from ssdrive.ed_bh_lookbackforward
		where lookback60 = 1
			union
		select distinct count(distinct event) as events, "back30" as timeline, 4 as putin
		from ssdrive.ed_bh_lookbackforward
		where lookback30 = 1
			union
		select distinct count(distinct event) as events, "back7" as timeline, 5 as putin
		from ssdrive.ed_bh_lookbackforward
		where lookback7 = 1
			union
		select distinct count(distinct event) as events, "forward7" as timeline, 6 as putin
		from ssdrive.ed_bh_lookbackforward
		where lookforward7 = 1
			union
		select distinct count(distinct event) as events, "forward30" as timeline, 7 as putin
		from ssdrive.ed_bh_lookbackforward
		where lookforward30 = 1
			union
		select distinct count(distinct event) as events, "forward60" as timeline, 8 as putin
		from ssdrive.ed_bh_lookbackforward
		where lookforward60 = 1
			union
		select distinct count(distinct event) as events, "forward90" as timeline, 9 as putin
		from ssdrive.ed_bh_lookbackforward
		where lookforward90 = 1
			union
		select distinct count(distinct event) as events, "forward120" as timeline, 10 as putin
		from ssdrive.ed_bh_lookbackforward
		where lookforward120 = 1
			union
		select distinct count(distinct event) as events, "no known after" as timeline, 11 as putin
		from ssdrive.ed_bh_lookbackforward
		where lookforward120 ne 1
		order by putin;
quit;

proc sql; 
	select distinct count(distinct event) as total_events /*44,068*/
	from ssdrive.ed_bh_lookbackforward;

	select distinct count(distinct mpid) as total_peeps /*35,917*/
	from ssdrive.ed_bh_lookbackforward;
quit;

proc sql; 
	create table ssdrive.ed_sa_out (drop = putin) as	
		select distinct count(distinct event) as events format = comma8., "no known before" as timeline, 0 as putin
		from ssdrive.ed_sa_lookbackforward
		where lookback120 ne 1
			union
		select distinct count(distinct event) as events, "back120" as timeline, 1 as putin
		from ssdrive.ed_sa_lookbackforward
		where lookback120 = 1
			union
		select distinct count(distinct event) as events, "back90" as timeline, 2 as putin
		from ssdrive.ed_sa_lookbackforward
		where lookback90 = 1
			union
		select distinct count(distinct event) as events, "back60" as timeline, 3 as putin
		from ssdrive.ed_sa_lookbackforward
		where lookback60 = 1
			union
		select distinct count(distinct event) as events, "back30" as timeline, 4 as putin
		from ssdrive.ed_sa_lookbackforward
		where lookback30 = 1
			union
		select distinct count(distinct event) as events, "back7" as timeline, 5 as putin
		from ssdrive.ed_sa_lookbackforward
		where lookback7 = 1
			union
		select distinct count(distinct event) as events, "forward7" as timeline, 6 as putin
		from ssdrive.ed_sa_lookbackforward
		where lookforward7 = 1
			union
		select distinct count(distinct event) as events, "forward30" as timeline, 7 as putin
		from ssdrive.ed_sa_lookbackforward
		where lookforward30 = 1
			union
		select distinct count(distinct event) as events, "forward60" as timeline, 8 as putin
		from ssdrive.ed_sa_lookbackforward
		where lookforward60 = 1
			union
		select distinct count(distinct event) as events, "forward90" as timeline, 9 as putin
		from ssdrive.ed_sa_lookbackforward
		where lookforward90 = 1
			union
		select distinct count(distinct event) as events, "forward120" as timeline, 10 as putin
		from ssdrive.ed_sa_lookbackforward
		where lookforward120 = 1
			union
		select distinct count(distinct event) as events, "no known after" as timeline, 11 as putin
		from ssdrive.ed_sa_lookbackforward
		where lookforward120 ne 1
		order by putin;
quit;

proc sql; 
	select distinct count(distinct event) as total_events /*26,139*/
	from ssdrive.ed_sa_lookbackforward;

	select distinct count(distinct mpid) as total_peeps /*20,897*/
	from ssdrive.ed_sa_lookbackforward;
quit;



/**********************************************************/
/*ip now*/
/*date of service as index date*/
proc sql;
	create table ip_lookback_forward as /*7,172,419*/
		select distinct a.MPID, a.ip_start_date, a.ip_end_date, compress(a.MPID||put(a.ip_start_date, date9.)) as event, a.ccsr_category, b.MC059_DateOfServiceFrom, case	
			when b.MC059_DateOfServiceFrom < a.ip_start_date then intck('day',a.ip_start_date, b.MC059_DateOfServiceFrom) 
			when b.MC059_DateOfServiceFrom > a.ip_end_date then intck('day', a.ip_end_date, b.MC059_DateOfServiceFrom)
		end as days_between format=comma8.
		from ssdrive.ip_bh_fulldates4 a left join ssdrive.outpatient_starter5 b on a.MPID=b.MPID; 
quit;


/*find first outpatient after the event*/
proc sql; /*3,545,330*/
	create table ip_forfirst as	
		select distinct *
		from ip_lookback_forward
		where days_between > 0
		order by event, days_between;
quit;

data ssdrive.calc_ip_first_out; /*87,560*/
set ip_forfirst;
by event days_between;
if first.event then output;
run;

proc sql;
	create table ssdrive.ip_first_outpatient_event as	/*106,090*/
		select distinct a.MPID, a.ip_start_date, a.ip_end_date, a.event, a.ccsr_category, a.days_between, b.*
		from ssdrive.calc_ip_first_out a left join ssdrive.outpatient_starter4 b on a.MPID=b.MPID and a.MC059_DateOfServiceFrom = b.MC059_DateOfServiceFrom;
quit;



/*lookback and forward files creation*/
proc sql;
	create table ip_lookback_start as	/*267,849*/
		select distinct MPID, ip_start_date, ip_end_date, compress(MPID||put(ip_start_date,date9.)) as mpiddate, case	
			when -1 ge days_between ge -120 then 1
			else 0
		end as lookback120, case
			when -1 ge days_between ge -90 then 1
			else 0
		end as lookback90, case
			when -1 ge days_between ge -60 then 1
			else 0
		end as lookback60, case
			when -1 ge days_between ge -30 then 1
			else 0
		end as lookback30, case
			when -1 ge days_between ge -7 then 1
			else 0
		end as lookback7
		from ip_lookback_forward
		order by mpiddate, lookback120, lookback90, lookback60, lookback30, lookback7;
run;

data ip_lookback (drop=mpiddate); /*107,748*/
set ip_lookback_start;
by mpiddate lookback120 lookback90 lookback60 lookback30 lookback7;
if last.mpiddate then output;
run;

proc sql; /*312,253*/
	create table ip_lookforward_start as	
		select distinct MPID, ip_start_date, ip_end_date, compress(MPID||put(ip_start_date,date9.)) as mpiddate, case	
			when 1 le days_between le 120 then 1
			else 0
		end as lookforward120, case
			when 1 le days_between le 90 then 1
			else 0
		end as lookforward90, case
			when 1 le days_between le 60 then 1
			else 0
		end as lookforward60, case
			when 1 le days_between le 30 then 1
			else 0
		end as lookforward30, case
			when 1 le days_between le 7 then 1
			else 0
		end as lookforward7
		from ip_lookback_forward
		order by mpiddate, lookforward120, lookforward90, lookforward60, lookforward30, lookforward7;
run;

data ip_lookforward (drop=mpiddate); /*107,748*/
set ip_lookforward_start;
by mpiddate lookforward120 lookforward90 lookforward60 lookforward30 lookforward7;
if last.mpiddate then output;
run;

proc sql;
	create table ssdrive.ip_lookback_forward as	/*182,842*/
		select distinct a.MPID, a.event, a.calendar_year, a.cy_county, a.fiscal_year, a.fy_county, a.quarter, a.q_county, a.gender, a.dob, a.race_ethnicity, a.payer_type, case
			when a.ccsr_category in (&bh_ccsr.) then "BH"
			when a.ccsr_category in (&sub_ccsr.) then "SA"
		end as event_type, a.ccsr_category, a.ccsr_desc, a.*, case
			when compress(a.MPID||put(a.ip_start_date,date9.)) in (select distinct compress(MPID||put(MC059_DateOfServiceFrom,date9.)) from ssdrive.out_into_ip) then 1
			else 0
		end as op_ip_sameday, b.lookback120, b.lookback90, b.lookback60, b.lookback30, b.lookback7, c.lookforward7, c.lookforward30, c.lookforward60, c.lookforward90, c.lookforward120
		from ssdrive.ip_bh_fulldates4 a left join ip_lookback b on a.MPID = b.MPID and a.ip_start_date = b.ip_start_date
			left join ip_lookforward c on a.MPID = c.MPID and a.ip_start_date = c.ip_start_date
		order by a.MPID, a.ip_start_date, a.payer_type;
quit;


/*initial output*/
proc sql;
	create table ssdrive.ip_lookbackforward_out (drop = putin) as	
		select distinct count(distinct event) as events format = comma8., "no known before" as timeline, 0 as putin
		from ssdrive.ip_lookback_forward
		where lookback120 ne 1
			union
		select distinct count(distinct event) as events, "back120" as timeline, 1 as putin
		from ssdrive.ip_lookback_forward
		where lookback120 = 1
			union
		select distinct count(distinct event) as events, "back90" as timeline, 2 as putin
		from ssdrive.ip_lookback_forward
		where lookback90 = 1
			union
		select distinct count(distinct event) as events, "back60" as timeline, 3 as putin
		from ssdrive.ip_lookback_forward
		where lookback60 = 1
			union
		select distinct count(distinct event) as events, "back30" as timeline, 4 as putin
		from ssdrive.ip_lookback_forward
		where lookback30 = 1
			union
		select distinct count(distinct event) as events, "back7" as timeline, 5 as putin
		from ssdrive.ip_lookback_forward
		where lookback7 = 1
			union
		select distinct count(distinct event) as events, "forward7" as timeline, 6 as putin
		from ssdrive.ip_lookback_forward
		where lookforward7 = 1
			union
		select distinct count(distinct event) as events, "forward30" as timeline, 7 as putin
		from ssdrive.ip_lookback_forward
		where lookforward30 = 1
			union
		select distinct count(distinct event) as events, "forward60" as timeline, 8 as putin
		from ssdrive.ip_lookback_forward
		where lookforward60 = 1
			union
		select distinct count(distinct event) as events, "forward90" as timeline, 9 as putin
		from ssdrive.ip_lookback_forward
		where lookforward90 = 1
			union
		select distinct count(distinct event) as events, "forward120" as timeline, 10 as putin
		from ssdrive.ip_lookback_forward
		where lookforward120 = 1
			union
		select distinct count(distinct event) as events, "no known after" as timeline, 11 as putin
		from ssdrive.ip_lookback_forward
		where lookforward120 ne 1
		order by putin;
quit;
		 

proc sql;
	select distinct count(distinct event) as total_events /*107,748*/
	from ssdrive.ip_lookback_forward;

	select distinct count(distinct mpid) as total_peeps /*64,546*/
	from ssdrive.ip_lookback_forward;

	select distinct count(distinct event) as events_same /*28,893*/
	from ssdrive.ip_lookback_forward
	where op_ip_sameday = 1;
quit;


proc sql;
	select distinct count(distinct event) as total_events /*142,389*/
	from ssdrive.ip_bh_fulldates_fc1;

	select distinct count(distinct mpid) as total_peeps /*67,611*/
	from ssdrive.ip_bh_fulldates_fc1;
quit;






/*breakout by BH vs SA*/
proc sql; /*156,831*/
	create table ssdrive.ip_bh_lookbackforward as
		select distinct *
		from ssdrive.ip_lookback_forward
		where event_type = "BH";

	create table ssdrive.ip_sa_lookbackforward as	/*26,011*/
		select distinct *
		from ssdrive.ip_lookback_forward
		where event_type = "SA";
quit;

/*initial output*/
proc sql;
	create table ssdrive.ip_bh_out (drop = putin) as	
		select distinct count(distinct event) as events format = comma8., "no known before" as timeline, 0 as putin
		from ssdrive.ip_bh_lookbackforward
		where lookback120 ne 1
			union
		select distinct count(distinct event) as events, "back120" as timeline, 1 as putin
		from ssdrive.ip_bh_lookbackforward
		where lookback120 = 1
			union
		select distinct count(distinct event) as events, "back90" as timeline, 2 as putin
		from ssdrive.ip_bh_lookbackforward
		where lookback90 = 1
			union
		select distinct count(distinct event) as events, "back60" as timeline, 3 as putin
		from ssdrive.ip_bh_lookbackforward
		where lookback60 = 1
			union
		select distinct count(distinct event) as events, "back30" as timeline, 4 as putin
		from ssdrive.ip_bh_lookbackforward
		where lookback30 = 1
			union
		select distinct count(distinct event) as events, "back7" as timeline, 5 as putin
		from ssdrive.ip_bh_lookbackforward
		where lookback7 = 1
			union
		select distinct count(distinct event) as events, "forward7" as timeline, 6 as putin
		from ssdrive.ip_bh_lookbackforward
		where lookforward7 = 1
			union
		select distinct count(distinct event) as events, "forward30" as timeline, 7 as putin
		from ssdrive.ip_bh_lookbackforward
		where lookforward30 = 1
			union
		select distinct count(distinct event) as events, "forward60" as timeline, 8 as putin
		from ssdrive.ip_bh_lookbackforward
		where lookforward60 = 1
			union
		select distinct count(distinct event) as events, "forward90" as timeline, 9 as putin
		from ssdrive.ip_bh_lookbackforward
		where lookforward90 = 1
			union
		select distinct count(distinct event) as events, "forward120" as timeline, 10 as putin
		from ssdrive.ip_bh_lookbackforward
		where lookforward120 = 1
			union
		select distinct count(distinct event) as events, "no known after" as timeline, 11 as putin
		from ssdrive.ip_bh_lookbackforward
		where lookforward120 ne 1
		order by putin;
quit;
		 

proc sql;
	select distinct count(distinct event) as total_events /*89,116*/
	from ssdrive.ip_bh_lookbackforward;

	select distinct count(distinct mpid) as total_peeps /*53,777*/
	from ssdrive.ip_bh_lookbackforward;
quit;



/*initial output*/
proc sql;
	create table ssdrive.ip_sa_out (drop = putin) as	
		select distinct count(distinct event) as events format = comma8., "no known before" as timeline, 0 as putin
		from ssdrive.ip_sa_lookbackforward
		where lookback120 ne 1
			union
		select distinct count(distinct event) as events, "back120" as timeline, 1 as putin
		from ssdrive.ip_sa_lookbackforward
		where lookback120 = 1
			union
		select distinct count(distinct event) as events, "back90" as timeline, 2 as putin
		from ssdrive.ip_sa_lookbackforward
		where lookback90 = 1
			union
		select distinct count(distinct event) as events, "back60" as timeline, 3 as putin
		from ssdrive.ip_sa_lookbackforward
		where lookback60 = 1
			union
		select distinct count(distinct event) as events, "back30" as timeline, 4 as putin
		from ssdrive.ip_sa_lookbackforward
		where lookback30 = 1
			union
		select distinct count(distinct event) as events, "back7" as timeline, 5 as putin
		from ssdrive.ip_sa_lookbackforward
		where lookback7 = 1
			union
		select distinct count(distinct event) as events, "forward7" as timeline, 6 as putin
		from ssdrive.ip_sa_lookbackforward
		where lookforward7 = 1
			union
		select distinct count(distinct event) as events, "forward30" as timeline, 7 as putin
		from ssdrive.ip_sa_lookbackforward
		where lookforward30 = 1
			union
		select distinct count(distinct event) as events, "forward60" as timeline, 8 as putin
		from ssdrive.ip_sa_lookbackforward
		where lookforward60 = 1
			union
		select distinct count(distinct event) as events, "forward90" as timeline, 9 as putin
		from ssdrive.ip_sa_lookbackforward
		where lookforward90 = 1
			union
		select distinct count(distinct event) as events, "forward120" as timeline, 10 as putin
		from ssdrive.ip_sa_lookbackforward
		where lookforward120 = 1
			union
		select distinct count(distinct event) as events, "no known after" as timeline, 11 as putin
		from ssdrive.ip_sa_lookbackforward
		where lookforward120 ne 1
		order by putin;
quit;
		 

proc sql;
	select distinct count(distinct event) as total_events /*21,231*/
	from ssdrive.ip_sa_lookbackforward;

	select distinct count(distinct mpid) as total_peeps /*14,970*/
	from ssdrive.ip_sa_lookbackforward;
quit;



/*final initial versions on the rdrive for cain for demographics*/
data rdrive.ip_for_demographics;
set ssdrive.ip_for_demographics;
run;

data rdrive.ed_for_demographics;
set ssdrive.ed_for_demographics;
run;

proc sql;
	create table rdrive.all_events_demographics as	
		select distinct MPID, event, "ED" as event_loc, event_type, calendar_year, cy_county, fiscal_year, fy_county, quarter, q_county, payer_type, race_ethnicity, gender, dob, ccsr_category, ccsr_desc, icd10, icd10_desc, date_of_service, hospital_name as admit_hospital
			, date_of_service as discharge_date format=date9., hospital_name as discharge_hospital, death_at_discharge, outpatient_into_ed as came_from_outpatient, "" as admitted_from_ed, ed_readmit as ed_wi_30d, ed_ip_readmits as readmitted_wi_30d
		from rdrive.ed_for_demographics
			union
		select distinct MPID, event, "IP" as event_loc, event_type, calendar_year, cy_county, fiscal_year, fy_county, quarter, q_county, payer_type, race_ethnicity, gender, dob, ccsr_category, ccsr_desc, icd10, icd10_desc, ip_start_date as date_of_service
			, admit_hospital, ip_end_date as discharge_date, discharge_hospital, death_at_discharge, outpatient_into_ip as came_from_outpatient, admitted_from_ed, ed_readmit as ed_wi_30d, ip_readmit_wi_30 as readmitted_wi_30d
		from rdrive.ip_for_demographics;
quit;