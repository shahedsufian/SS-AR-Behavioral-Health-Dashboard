/****************************************************************************************************************************************************
*   PURPOSE: This program holds the locations of the libraries used, the macro variable of the list of variable interests, and the code to create   *
*            the macro variable list of diagnoses and procedures.                                                                                   *                                                                                            *
****************************************************************************************************************************************************/

options compress = yes;

libname rdrive "";
libname ssdrive "";

/*static APCD*/
libname APCDclms "";
libname MCRclms "";

/*APCD reference tables*/
libname apcdlu ODBC noprompt = "" schema = lookups;
libname apcdanas ODBC noprompt = "" schema = dbo;
libname medispan ODBC noprompt = "" schema = dbo;
libname CarePrec ODBC noprompt = "" SCHEMA=dbo;

/*Genderal reference tables*/
libname geoinfo '';
libname hedis '';
libname lu '';
libname npi '';

/*HDI reference tables*/
libname hdi ODBC noprompt = '' schema = dbo;
libname hdilu ODBC noprompt = '' schema = dbo;

%let med_varis = MC001_submitter,MC137_CarrierSpecificUniqueMembe,MC003_InsuranceType_ProductCode,MC004_PayerClaimControlNumber,MC005_LineNumber,
                 MC005A_VersionNumber,MC012_MemberGender,MC013_MemberDateOfBirth,MC016_MemberZipCode,MC023_FinalDischargeStatus,MC036_TypeOfBill_Institutional,
                 MC037_FacilityType,MC041_PrincipalDiagnosis,MC042_OtherDiagnosis1,MC043_OtherDiagnosis2,MC044_OtherDiagnosis3,MC045_OtherDiagnosis4,
                 MC046_OtherDiagnosis5,MC047_OtherDiagnosis6,MC048_OtherDiagnosis7,MC049_OtherDiagnosis8,MC050_OtherDiagnosis9,
                 MC051_OtherDiagnosis10,MC052_OtherDiagnosis11,MC053_OtherDiagnosis12,MC054_RevenueCode,MC055_ProcedureCode,MC056_ProcedureModifier1,
                 MC057_ProcedureModifier2,MC057B_ProcedureModifier3,MC057C_ProcedureModifier4,MC058_Principal_ICD_9_CM_Or_ICD_,
                 MC058A_Other_ICD_9_CM_Or_ICD_10_,MC058B_Other_ICD_9_CM_Or_ICD_10_,MC058C_Other_ICD_9_CM_Or_ICD_10_,MC058D_Other_ICD_9_CM_Or_ICD_10_,
                 MC058E_Other_ICD_9_CM_Or_ICD_10_,MC058EA_Other_ICD_9_CM_Or_ICD_10,MC058F_Other_ICD_9_CM_Or_ICD_10_,MC058G_Other_ICD_9_CM_Or_ICD_10_,
                 MC058H_Other_ICD_9_CM_Or_ICD_10_,MC058J_Other_ICD_9_CM_Or_ICD_10_,MC058K_Other_ICD_9_CM_Or_ICD_10_,MC058L_Other_ICD_9_CM_Or_ICD_10_,
                 MC059_DateOfServiceFrom,MC060_DateOfServiceThru,MC018_AdmissionDate,MC069_DischargeDate,MC024_ServiceProviderNumber,
                 MC026_NationalServiceProviderId,MC028_ServiceProviderFirstName,MC029_ServiceProviderMiddleName,MC030_ServiceProviderLastNameOrO,
                 MC033_ServiceProviderCity,MC034_ServiceProviderState,MC035_ServiceProviderZipCode,MC134_NationalServiceOrganizatio,
                 MC077_NationalBillingProviderId,MC078_BillingProviderLastNameOrO,MC207_BillingProviderStreetAddre,MC208_BillingProviderCity,
                 MC209_BillingProviderState,MC210_BillingProviderZipCode,MC211_BillingProviderCountryCode,MC061_Quantity,MC062_ChargeAmount,
                 MC063_PaidAmount,MC063A_HeaderLinePaymentIndicato,MC063C_WithholdAmount,MC064_CapitationAmount,MC065_CopayAmount,
                 MC066_CoinsuranceAmount,MC067_DeductibleAmount,MC094_TypeOfClaim,MC706_VersioningMethod,MC138_ClaimStatus,MC841_PASSE,MC840_PASSE;

%let mcr_varis = MC001_submitter,MC137_CarrierSpecificUniqueMembe,MC003_InsuranceType_ProductCode,MC004_PayerClaimControlNumber,MC005_LineNumber,
                 MC005A_VersionNumber,MC012_MemberGender,MC013_MemberDateOfBirth,MC016_MemberZipCode,MC023_FinalDischargeStatus,MC036_TypeOfBill_Institutional,
                 MC037_FacilityType,MC041_PrincipalDiagnosis,MC042_OtherDiagnosis1,MC043_OtherDiagnosis2,MC044_OtherDiagnosis3,MC045_OtherDiagnosis4,
                 MC046_OtherDiagnosis5,MC047_OtherDiagnosis6,MC048_OtherDiagnosis7,MC049_OtherDiagnosis8,MC050_OtherDiagnosis9,
                 MC051_OtherDiagnosis10,MC052_OtherDiagnosis11,MC053_OtherDiagnosis12,MC054_RevenueCode,MC055_ProcedureCode,MC056_ProcedureModifier1,
                 MC057_ProcedureModifier2,MC057B_ProcedureModifier3,MC057C_ProcedureModifier4,MC058_Principal_ICD_9_CM_Or_ICD_,
                 MC058A_Other_ICD_9_CM_Or_ICD_10_,MC058B_Other_ICD_9_CM_Or_ICD_10_,MC058C_Other_ICD_9_CM_Or_ICD_10_,MC058D_Other_ICD_9_CM_Or_ICD_10_,
                 MC058E_Other_ICD_9_CM_Or_ICD_10_,MC058EA_Other_ICD_9_CM_Or_ICD_10,MC058F_Other_ICD_9_CM_Or_ICD_10_,MC058G_Other_ICD_9_CM_Or_ICD_10_,
                 MC058H_Other_ICD_9_CM_Or_ICD_10_,MC058J_Other_ICD_9_CM_Or_ICD_10_,MC058K_Other_ICD_9_CM_Or_ICD_10_,MC058L_Other_ICD_9_CM_Or_ICD_10_,
                 MC059_DateOfServiceFrom,MC060_DateOfServiceThru,MC018_AdmissionDate,MC069_DischargeDate,MC024_ServiceProviderNumber,
                 MC026_NationalServiceProviderId,MC028_ServiceProviderFirstName,MC029_ServiceProviderMiddleName,MC030_ServiceProviderLastNameOrO,
                 MC033_ServiceProviderCity,MC034_ServiceProviderState,MC035_ServiceProviderZipCode,MC134_NationalServiceOrganizatio,
                 MC077_NationalBillingProviderId,MC078_BillingProviderLastNameOrO,MC207_BillingProviderStreetAddre,MC208_BillingProviderCity,
                 MC209_BillingProviderState,MC210_BillingProviderZipCode,MC211_BillingProviderCountryCode,MC061_Quantity,MC062_ChargeAmount,
                 MC063_PaidAmount,MC063A_HeaderLinePaymentIndicato,MC063C_WithholdAmount,MC064_CapitationAmount,MC065_CopayAmount,
                 MC066_CoinsuranceAmount,MC067_DeductibleAmount,MC094_TypeOfClaim,MC706_VersioningMethod,MC138_ClaimStatus;

%let mem_varis = ME001_Submitter,ME107_CarrierSpecificUniqueMembe,ME003_InsuranceType_ProductCode,ME007_CoverageLevelCode,ME013_MemberGender,
                 ME014_MemberDateOfBirth,ME016_MemberStateOrProvince,ME017_MemberZipCode,ME018_MedicalServicesIndicator,
                 ME019_PharmacyServicesIndicator,ME020_DentalServicesIndicator,ME030_MarketCategory,ME059_DisabilityIndicator,ME063_BenefitStatus,
                 ME120_ActuarialValue,ME121_MetallicValue,ME123_MonthlyPremium,ME124_Attributed_PCP_ProviderId,ME032_GroupName,
                 ME162A_DateOfFirstEnrollment,ME163A_DateOfDisenrollment,ME164A_HealthPlan,ME173A_MemberCounty,ME992_HIOS_ID,ME998_APCDUniqueID,
                 PeriodBeginDate,PeriodEndingDate;

				 
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


%let nurs_rev = "0022", "0190", "0191", "0192", "0193", "0194", "0199";
%let nurs_tob = "210", "211", "212", "213", "214", "215", "216", "217", "218", "21F", "21G", "21H"
, "21I", "21J", "21K", "21M", "21O", "21Q", "21X", "21Y", "21Z";

proc sql;
  	select distinct quote(compress(code," .")) into :hospice separated by "," 
	from hedis.Hedis_valuesets_2021
  	where value_set_name = "Hospice Encounter" and code_system = "UBREV";
quit;

libname geo xlsx "R:\Geographic info\zip_to_zcta_xwalk.xlsx";
proc sql;
select distinct quote(strip(zip_code)) into :AR_zips separated by "," 
from geo.zips;
quit;

proc contents data=geo._all_;
run;

libname hosp 'R:\Geographic Info\Hospital XWALK.xlsx';
data hosp_xwalk;
set hosp.'Hospitals_simple$'n;
run;
libname hosp clear;


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

%let dx_vari = (pat_diagnosis_1 pat_diagnosis_2 pat_diagnosis_3 pat_diagnosis_4 pat_diagnosis_5 pat_diagnosis_6 pat_diagnosis_7 pat_diagnosis_8 pat_diagnosis_9
					pat_diagnosis_10 pat_diagnosis_11 pat_diagnosis_12 pat_diagnosis_13 pat_diagnosis_14 pat_diagnosis_15 pat_diagnosis_16 pat_diagnosis_17 pat_diagnosis_18
					pat_diagnosis_19 pat_diagnosis_20 pat_diagnosis_21 pat_diagnosis_22 pat_diagnosis_23 pat_diagnosis_24 pat_diagnosis_25 pat_diagnosis_26 pat_diagnosis_27);
