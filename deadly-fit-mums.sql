--truncate table [sqldb-iuih-research-sandbox].[dbo].[Deadly_fit_mums];

--insert into [sqldb-iuih-research-sandbox].[dbo].[Deadly_fit_mums]
select distinct
--patient details
	isnull(ptmg.[Primary Patient ID],fm.[Patient ID]) as [Patient ID]
	,fm.[Form ID]
	,convert(date, pt.[Patient Date Of Birth]) as [Date of Birth]
	--,pt.[Patient Deceased Date]
	,pt.[Patient Sex]
	,pt.[Patient ATSI Status]
	--,pt.[Patient Family of ATSI]
	--,pt.[Patient Clinic Catchment]
	,case
    when pt.[Patient Clinic Catchment] like '%(%' 
		then substring(
				pt.[Patient Clinic Catchment],
				charindex('(', pt.[Patient Clinic Catchment]) + 1,
				charindex(')', pt.[Patient Clinic Catchment]) - charindex('(', pt.[Patient Clinic Catchment]) - 1
			)
	when pt.[Patient Clinic Catchment] like '%ATSICHS%'
		then substring(pt.[Patient Clinic Catchment], 
				charindex(' ', pt.[Patient Clinic Catchment], charindex(' ', pt.[Patient Clinic Catchment]) + 1) + 1,
				len(pt.[Patient Clinic Catchment]))
    else pt.[Patient Clinic Catchment]  
	end as [Patient Clinic Catchment]
	,pt.[Patient Primary Organisation Name]
	--,pt.[Patient Post Code]
	--,pt.[Patient Suburb]
	--,pt.[Type Of Accomodation]
	--,pt.[CCSS Care Plan]
	--,pt.[Tag Pods]
	,pt.[Patient Active Status]
	,pt.[Patient Test Patient]

--form details
	,fm.[Create Timestamp]
	,fm.[Create User Full Name]
	,fm.[Create User Organisation Name]
	,fm.[Is Completed]
	,fm.[Is Archived]

--referral details
	--,refDetail.[Referral Date]
	,case
		when refDetail.[Referral Date] like '__/__/____%M' 
			then try_convert(date, refDetail.[Referral Date], 103) 
		when refDetail.[Referral Date] like '__/__/____' 
			then try_convert(date, refDetail.[Referral Date], 103)
		when refDetail.[Referral Date] like '____-__-__' 
			then try_convert(date, refDetail.[Referral Date], 23) 
		else null
	end as [Referral Date]
	,refDetail.[Program Referred To]
	,refDetail.[Referring Clinic]
	,case
		when refDetail.[Referring Clinic] like '%(%'
			then substring(refDetail.[Referring Clinic],
					charindex('(', refDetail.[Referring Clinic]) +1,
					charindex(')', refDetail.[Referring Clinic]) - charindex('(', refDetail.[Referring Clinic]) -1
					)
		else refDetail.[Referring Clinic]
	end as [Referring Clinic]
	,IndOrGrp.[Individual or Group]
	,refDetail.[Program Location]
	,case
		when refDetail.[Program Location (Other)] = 'Location of program - Other - free text field'
			then null
		else refDetail.[Program Location (Other)]
	end as [Program Location (Other)]

--current status
	,currentStatus.[Current Status]

--discharge date
	--,dischargeDate.[Discharge Date]
	,case
		when dischargeDate.[Discharge Date] like '__/__/____%M' 
			then try_convert(date, dischargeDate.[Discharge Date], 103) 
		when dischargeDate.[Discharge Date] like '__/__/____' 
			then try_convert(date, dischargeDate.[Discharge Date], 103)
		when dischargeDate.[Discharge Date] like '____-__-__' 
			then try_convert(date, dischargeDate.[Discharge Date], 23) 
		else null
	end as [Discharge Date]
	,dischargeDate.[Discharge Reason]

--discharge to
	,referredTo.[Referred To]

-- into [sqldb-iuih-research-sandbox].[dbo].[Deadly_fit_mums]
-- form
from [sqldb-iuih-dwh-prod].[raw_mmex].[PSA_Form] as fm

--patient merge
left join [sqldb-iuih-dwh-prod].[raw_mmex].[PSA_PatientMerge] ptmg
on
	fm.[Patient ID] = ptmg.[Secondary Patient ID]
	and ptmg.[RCT] != 'D'	
	and ptmg.[Unmerge Timestamp] is null
	and ptmg.[RCURRENT] = 1

--patient details
left join [sqldb-iuih-dwh-prod].[transform_mmex].[VW_Patient_BaseDetail] pt
on
	isnull(ptmg.[Primary Patient ID],fm.[Patient ID]) = pt.[Patient ID]

--form details
left join [sqldb-iuih-dwh-prod].[raw_mmex].[PSA_FormData] fd
on 
	fm.[Form ID] = fd.[Form ID]
	and fd.[RCT] != 'D'
	and fd.[RCURRENT] = 1

-- referral details
left join (
	select 
		[Form ID]
		,[Referral Date]
		,[Program Referred To]
		,[Program Location]
		,[Program Location (Other)]
		,[Referring Clinic]
	from (
		select distinct
			[Form ID]
			,case
				when [key] = 'referralDate' then 'Referral Date'
				when [key] = 'program.text' then 'Program Referred To'
				when [key] = 'dfmLocation.value' then 'Program Location'
				when [key] = 'dfmLocationOther' then 'Program Location (Other)'
				when [key] = 'referringClinic.name' then 'Referring Clinic'				
			end as [KeyName]
			,[Value]
			,row_number() over (partition by [Form ID], [Key] order by [rfdts] desc) as rn
		from [sqldb-iuih-dwh-prod].[raw_mmex].[PSA_FormData]
		where
			[Form ID] in (
				select distinct [Form ID]
				from [sqldb-iuih-dwh-prod].[raw_mmex].[PSA_Form]
				where [Name] = 'IUIH Exercise & Rehab Programs'
			)
			and [Key] in (
				'referralDate'
				,'program.text'	
				,'dfmLocation.value'
				,'dfmLocationOther'
				,'referringClinic.name'
			)
			and [RCT] != 'D'
			and [RCURRENT] = 1			
			
		) rd
		pivot (
			max([Value])
			for [KeyName] in (
				[Referral Date]
				,[Program Referred To]
				,[Program Location]
				,[Program Location (Other)]
				,[Referring Clinic]
			)
		) refPivot
		where rn = 1
) refDetail
on fm.[Form ID] = refDetail.[Form ID]

-- Ind or Group
left join (
	select
	[Form ID]
	,[Individual or Group]
	from(	
		select distinct
			[Form ID]
			,[Value] as [Individual or Group]
			,row_number() over (partition by [Form ID], [Key] order by [rfdts] desc) as rn
			from [sqldb-iuih-dwh-prod].[raw_mmex].[PSA_FormData]
			where [Form ID] in (
				select distinct [Form ID]
				from [sqldb-iuih-dwh-prod].[raw_mmex].[PSA_Form]
				where [Name] = 'IUIH Exercise & Rehab Programs'
			)
			and [Key] like 'dfmType%.value'
			and [RCT] != 'D'
			and [RCURRENT] = 1
		) IndOrGrp
	where rn = 1
)IndOrGrp
on fm.[Form ID] = IndOrGrp.[Form ID]

-- current status
left join (
	select
	[Form ID]
	,[Current Status]
	from(	
		select distinct
			[Form ID]
			,[Value] as [Current Status]
			,row_number() over (partition by [Form ID], [Key] order by [rfdts] desc) as rn
			from [sqldb-iuih-dwh-prod].[raw_mmex].[PSA_FormData]
			where [Form ID] in (
				select distinct [Form ID]
				from [sqldb-iuih-dwh-prod].[raw_mmex].[PSA_Form]
				where [Name] = 'IUIH Exercise & Rehab Programs'
			)
			and [Key] = 'currentStatus.value'
			and [RCT] != 'D'
			and [RCURRENT] = 1
		) IndOrGrp
	where rn = 1
)currentStatus
on fm.[Form ID] = currentStatus.[Form ID]


--discharge date
left join (
	select 
		[Form ID]
		,[Discharge Date]
		,[Discharge Reason]
	from (
		select distinct
			[Form ID]
			,case
				when [key] = 'dischargeDate' then 'Discharge Date'
				when [key] = 'dischargeReason.text' then 'Discharge Reason'	
			end as [KeyName]
			,[Value]
			,row_number() over (partition by [Form ID], [Key] order by [rfdts] desc) as rn
		from [sqldb-iuih-dwh-prod].[raw_mmex].[PSA_FormData]
		where
			[Form ID] in (
				select distinct [Form ID]
				from [sqldb-iuih-dwh-prod].[raw_mmex].[PSA_Form]
				where [Name] = 'IUIH Exercise & Rehab Programs'
			)
			and [Key] in (
				'dischargeDate'
				,'dischargeReason.text'
			)
			and [RCT] != 'D'
			and [RCURRENT] = 1			
			
		) rd
		pivot (
			max([Value])
			for [KeyName] in (
				[Discharge Date]
				,[Discharge Reason]
			)
		) dischargePivot
		where rn = 1
) dischargeDate
on fm.[Form ID] = dischargeDate.[Form ID]

-- Referred to
left join (
	select
	[Form ID]
	,[Referred To]
	from(	
		select distinct
			[Form ID]
			,[Value] as [Referred To]
			,row_number() over (partition by [Form ID], [Key] order by [rfdts] desc) as rn
			from [sqldb-iuih-dwh-prod].[raw_mmex].[PSA_FormData]
			where [Form ID] in (
				select distinct [Form ID]
				from [sqldb-iuih-dwh-prod].[raw_mmex].[PSA_Form]
				where [Name] = 'IUIH Exercise & Rehab Programs'
			)
			and [Key] like 'dischargeReferred%.text'
			and [RCT] != 'D'
			and [RCURRENT] = 1
		) referredToDetails
	where rn = 1
)referredTo
on fm.[Form ID] = referredTo.[Form ID]	

--main filters
where
	fm.[Name] = 'IUIH Exercise & Rehab Programs'
	and fm.[RCT] != 'D'
	and fm.[RCURRENT] = 1
	and refDetail.[Program Referred To] = 'Deadly Fit Mums'
--	and pt.[Patient Test Patient] = 1
--	and fm.[Form ID] = 189828 