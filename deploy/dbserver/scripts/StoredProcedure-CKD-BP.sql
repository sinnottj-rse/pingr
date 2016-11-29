									--TO RUN AS STORED PROCEDURE--
IF EXISTS(SELECT * FROM sys.objects WHERE Type = 'P' AND Name ='pingr.ckd.treatment.bp') DROP PROCEDURE [pingr.ckd.treatment.bp];
GO
CREATE PROCEDURE [pingr.ckd.treatment.bp] @refdate VARCHAR(10), @JustTheIndicatorNumbersPlease bit = 0
AS
SET NOCOUNT ON

									--TO TEST ON THE FLY--
--use PatientSafety_Records_Test
--declare @refdate VARCHAR(10);
--declare @JustTheIndicatorNumbersPlease bit;
--set @refdate = '2016-11-17';
--set @JustTheIndicatorNumbersPlease= 0;
	
-----------------------------------------------------------------------------------
--DEFINE ELIGIBLE POPULATION, EXCLUSIONS, DENOMINATOR, AND NUMERATOR --------------
-----------------------------------------------------------------------------------
--DEFINE ELIGIBLE POPULATION FIRST
--THEN CREATE TEMP TABLES FOR EACH COLUMN OF DATA NEEDED, FROM THE ELIGIBLE POP
--COMBINE TABLES TOGETHER THAT NEED TO BE QUERIED TO CREATE NEW TABLES
--THEN COMBINE ALL TABLES TOGETHER INTO ONE BIG TABLE TO BE QUERIED IN FUTURE
-----------------------------------------------------------------------------------
declare @achieveDate datetime;
set @achieveDate = (select case
	when MONTH(@refdate) <4 then CONVERT(VARCHAR,YEAR(@refdate)) + '-03-31' --31st March
	when MONTH(@refdate) >3 then CONVERT(VARCHAR,(YEAR(@refdate) + 1)) + '-03-31' end); --31st March

--#latestCkd35code 
--ELIGIBLE POPULATION
--NB min/max rubric checks if there have been different codes on the same day
IF OBJECT_ID('tempdb..#latestCkd35code') IS NOT NULL DROP TABLE #latestCkd35code
CREATE TABLE #latestCkd35code (PatID int, latestCkd35codeDate date, latestCkd35codeMin varchar(512), latestCkd35codeMax varchar(512), latestCkd35code varchar(512));
insert into #latestCkd35code (PatID, latestCkd35codeDate, latestCkd35codeMin, latestCkd35codeMax, latestCkd35code)
select s.PatID, latestCkd35codeDate, MIN(Rubric) as latestCkd35codeMin, MAX(Rubric) as latestCkd35codeMax, 
	case when MIN(Rubric)=MAX(Rubric) then MAX(Rubric) else 'Differ' end as latestCkd35code from SIR_ALL_Records s
	inner join (
		select PatID, MAX(EntryDate) as latestCkd35codeDate from SIR_ALL_Records
		where ReadCode in (select code from codeGroups where [group] = 'ckd35')
		and EntryDate < @refdate
		group by PatID
	) sub on sub.PatID = s.PatID and sub.latestCkd35codeDate = s.EntryDate
where ReadCode  in (select code from codeGroups where [group] = 'ckd35')
group by s.PatID, latestCkd35codeDate

--#age
IF OBJECT_ID('tempdb..#age') IS NOT NULL DROP TABLE #age
CREATE TABLE #age (PatID int, age int);
insert into #age (PatID, age)
select PatID, YEAR(@achieveDate) - year_of_birth as age from #latestCkd35code as c
	left outer join
		(select patid, year_of_birth from dbo.patients) as d on c.PatID = d.patid

--#latestCkdPermExCode
--permanent exclusions codes: CKD1/2, or ckd resolved	
--NB min/max rubric check if there have been different codes on the same day
IF OBJECT_ID('tempdb..#latestCkdPermExCode') IS NOT NULL DROP TABLE #latestCkdPermExCode
CREATE TABLE #latestCkdPermExCode (PatID int, latestCkdPermExCodeDate date, latestCkdPermExCodeMin varchar(512), latestCkdPermExCodeMax varchar(512), 
	latestCkdPermExCode varchar(512));
insert into #latestCkdPermExCode 
	(PatID, latestCkdPermExCodeDate, latestCkdPermExCodeMin, latestCkdPermExCodeMax, latestCkdPermExCode)
select s.PatID, latestCkdPermExCodeDate, MIN(Rubric) as latestCkdPermExCodeMin, MAX(Rubric) as latestCkdPermExCodeMax, 
	case when MIN(Rubric)=MAX(Rubric) then MAX(Rubric) else 'Differ' end as latestCkdPermExCode from SIR_ALL_Records s
	inner join (
		select PatID, MAX(EntryDate) as latestCkdPermExCodeDate from SIR_ALL_Records
		where PatID in (select PatID from #latestCkd35code)
		and ReadCode in (select code from codeGroups where [group] = 'ckdPermEx')
		and EntryDate < @refdate
		group by PatID
	) sub on sub.PatID = s.PatID and sub.latestCkdPermExCodeDate = s.EntryDate
where ReadCode  in (select code from codeGroups where [group] = 'ckdPermEx')
group by s.PatID, latestCkdPermExCodeDate

--#latestCkdTempExCode
--temp exceptions: BP refused, max HTN medication, CKD indicators unsuitable			
--NB min/max rubric check if there have been different codes on the same day
IF OBJECT_ID('tempdb..#latestCkdTempExCode') IS NOT NULL DROP TABLE #latestCkdTempExCode
CREATE TABLE #latestCkdTempExCode (PatID int, latestCkdTempExCodeDate date, latestCkdTempExCodeMin varchar(512), 
	latestCkdTempExCodeMax varchar(512), latestCkdTempExCode varchar(512));
insert into #latestCkdTempExCode 
	(PatID, latestCkdTempExCodeDate, latestCkdTempExCodeMin, latestCkdTempExCodeMax, latestCkdTempExCode)
select s.PatID, latestCkdTempExCodeDate, MIN(Rubric) as latestCkdTempExCodeMin, MAX(Rubric) as latestCkdTempExCodeMax, 
	case when MIN(Rubric)=MAX(Rubric) then MAX(Rubric) else 'Differ' end as latestCkdTempExCode from SIR_ALL_Records s
	inner join (
		select PatID, MAX(EntryDate) as latestCkdTempExCodeDate from SIR_ALL_Records
		where PatID in (select PatID from #latestCkd35code)
		and ReadCode in (select code from codeGroups where [group] in ('ckdTempEx','bpTempEx'))
		and EntryDate < @refdate
		group by PatID
	) sub on sub.PatID = s.PatID and sub.latestCkdTempExCodeDate = s.EntryDate
where ReadCode  in (select code from codeGroups where [group] in ('ckdTempEx','bpTempEx'))
group by s.PatID, latestCkdTempExCodeDate

--#latestRegisteredCode
--codes relating to patient registration
--NB min/max rubric check if there have been different codes on the same day
IF OBJECT_ID('tempdb..#latestRegisteredCode') IS NOT NULL DROP TABLE #latestRegisteredCode
CREATE TABLE #latestRegisteredCode (PatID int, latestRegisteredCodeDate date, latestRegisteredCodeMin varchar(512), latestRegisteredCodeMax varchar(512), 
	latestRegisteredCode varchar(512));
insert into #latestRegisteredCode 
	(PatID, latestRegisteredCodeDate, latestRegisteredCodeMin, latestRegisteredCodeMax, latestRegisteredCode)
select s.PatID, latestRegisteredCodeDate, MIN(Rubric) as latestRegisteredCodeMin, MAX(Rubric) as latestRegisteredCodeMax, 
	case when MIN(Rubric)=MAX(Rubric) then MAX(Rubric) else 'Differ' end as latestRegisteredCode from SIR_ALL_Records s
	inner join (
		select PatID, MAX(EntryDate) as latestRegisteredCodeDate from SIR_ALL_Records
		where PatID in (select PatID from #latestCkd35code)
		and ReadCode in (select code from codeGroups where [group] = 'registered')
		and EntryDate < @refdate
		group by PatID
	) sub on sub.PatID = s.PatID and sub.latestRegisteredCodeDate = s.EntryDate
where ReadCode  in (select code from codeGroups where [group] = 'registered')
group by s.PatID, latestRegisteredCodeDate

--#latestDeregCode
--codes relating to patient DEregistration
--NB min/max rubric check if there have been different codes on the same day
IF OBJECT_ID('tempdb..#latestDeregCode') IS NOT NULL DROP TABLE #latestDeregCode
CREATE TABLE #latestDeregCode (PatID int, latestDeregCodeDate date, latestDeregCodeMin varchar(512), latestDeregCodeMax varchar(512), 
	latestDeregCode varchar(512));
insert into #latestDeregCode 
	(PatID, latestDeregCodeDate, latestDeregCodeMin, latestDeregCodeMax, latestDeregCode)
select s.PatID, latestDeregCodeDate, MIN(Rubric) as latestDeregCodeMin, MAX(Rubric) as latestDeregCodeMax, 
	case when MIN(Rubric)=MAX(Rubric) then MAX(Rubric) else 'Differ' end as latestDeregCode from SIR_ALL_Records as s
	inner join (
		select PatID, MAX(EntryDate) as latestDeregCodeDate from SIR_ALL_Records
		where PatID in (select PatID from #latestCkd35code)
		and ReadCode in (select code from codeGroups where [group] = 'deRegistered')
		and EntryDate < @refdate
		group by PatID
	) sub on sub.PatID = s.PatID and sub.latestDeregCodeDate = s.EntryDate
where ReadCode in (select code from codeGroups where [group] = 'deRegistered')
group by s.PatID, latestDeregCodeDate

--#latestDeadCode 
--codes relating to patient death
--NB min/max rubric check if there have been different codes on the same day
IF OBJECT_ID('tempdb..#latestDeadCode') IS NOT NULL DROP TABLE #latestDeadCode
CREATE TABLE #latestDeadCode (PatID int, latestDeadCodeDate date, latestDeadCodeMin varchar(512), latestDeadCodeMax varchar(512), 
	latestDeadCode varchar(512));
insert into #latestDeadCode 
	(PatID, latestDeadCodeDate, latestDeadCodeMin, latestDeadCodeMax, latestDeadCode)
select s.PatID, latestDeadCodeDate, MIN(Rubric) as latestDeadCodeMin, MAX(Rubric) as latestDeadCodeMax, 
	case when MIN(Rubric)=MAX(Rubric) then MAX(Rubric) else 'Differ' end as latestDeadCode from SIR_ALL_Records as s
	inner join (
		select PatID, MAX(EntryDate) as latestDeadCodeDate from SIR_ALL_Records
		where PatID in (select PatID from #latestCkd35code)
		and ReadCode in (select code from codeGroups where [group] = 'dead')
		and EntryDate < @refdate
		group by PatID
	) sub on sub.PatID = s.PatID and sub.latestDeadCodeDate = s.EntryDate
where ReadCode in (select code from codeGroups where [group] = 'dead')
group by s.PatID, latestDeadCodeDate

--#deadTable 
--patients marked as dead in the demographics table
IF OBJECT_ID('tempdb..#deadTable') IS NOT NULL DROP TABLE #deadTable
CREATE TABLE #deadTable (PatID int, deadTable int, deadTableMonth int, deadTableYear int);
insert into #deadTable
	(PatID, deadTable, deadTableMonth, deadTableYear)	
select PatID, deadTable, deadTableMonth, deadTableYear from #latestCkd35code as c
	left outer join
		(select patid, dead as deadTable, month_of_death as deadTableMonth, year_of_death as deadTableYear from patients) as d on c.PatID = d.patid
			
--#firstCkd35code 
--needed for the 'diagnosis within 9/12 exclusion criterion'
--patients' first CKD 3-5 date
--NB min/max codes check if there have been different codes on the same day
IF OBJECT_ID('tempdb..#firstCkd35code') IS NOT NULL DROP TABLE #firstCkd35code
CREATE TABLE #firstCkd35code (PatID int, firstCkd35codeDate date, firstCkd35codeMin varchar(512), firstCkd35codeMax varchar(512), 
	firstCkd35code varchar(512));
insert into #firstCkd35code 
	(PatID, firstCkd35codeDate, firstCkd35codeMin, firstCkd35codeMax, firstCkd35code)
select s.PatID, firstCkd35codeDate, MIN(Rubric) as firstCkd35codeMin, MAX(Rubric) as firstCkd35codeMax, 
	case when MIN(Rubric)=MAX(Rubric) then MAX(Rubric) else 'Differ' end as firstCkd35code from SIR_ALL_Records s
	inner join (
		select PatID, MIN(EntryDate) as firstCkd35codeDate from SIR_ALL_Records
		where ReadCode in (select code from codeGroups where [group] = 'ckd35')
		and EntryDate < @refdate
		group by PatID
	) sub on sub.PatID = s.PatID and sub.firstCkd35codeDate = s.EntryDate
where ReadCode in (select code from codeGroups where [group] = 'ckd35')
and s.PatID in (select PatID from #latestCkd35code)
group by s.PatID, firstCkd35codeDate

--#firstCkd35codeAfter
--if patients have had a permanent exclusion code: the first CKD 3-5 date AFTER the exclusion
--needed for the 'diagnosis within 9/12 exclusion criterion'
--NB min/max codes check if there have been different codes on the same day
IF OBJECT_ID('tempdb..#firstCkd35codeAfter') IS NOT NULL DROP TABLE #firstCkd35codeAfter
CREATE TABLE #firstCkd35codeAfter (PatID int, firstCkd35codeAfterDate date, firstCkd35codeAfterMin varchar(512), 
	firstCkd35codeAfterMax varchar(512), firstCkd35codeAfter varchar(512)); --need this to exclude patients who have been diagnosed within 9/12 of target date as per QOF
insert into #firstCkd35codeAfter
	(PatID, firstCkd35codeAfterDate, firstCkd35codeAfterMin, firstCkd35codeAfterMax, firstCkd35codeAfter)
select s.PatID, firstCkd35codeAfterDate, MIN(Rubric) as firstCkd35codeAfterMin, MAX(Rubric) as firstCkd35codeAfterMax, 
	case when MIN(Rubric)=MAX(Rubric) then MAX(Rubric) else 'Differ' end as firstCkd35codeAfter from SIR_ALL_Records as s
	inner join (
		select r.PatID, MIN(EntryDate) as firstCkd35codeAfterDate from SIR_ALL_Records as r
			inner join #latestCkdPermExCode as t on t.PatID = r.PatID
		where ReadCode in (select code from codeGroups where [group] = 'ckd35')
		and EntryDate < @refdate
		and EntryDate > latestCkdPermExCodeDate --so if there is an exclusion code AND CKD code on the same day, exclusion wins - if there are further ckd codes afterwards then ckd wins
		group by r.PatID
	) sub on sub.PatID = s.PatID and sub.firstCkd35codeAfterDate = s.EntryDate
where ReadCode in (select code from codeGroups where [group] = 'ckd35')
and s.PatID in (select PatID from #latestCkd35code)
group by s.PatID, firstCkd35codeAfterDate

--#latestDmCode
--NB min/max codes check if there have been different codes on the same day
IF OBJECT_ID('tempdb..#latestDmCode') IS NOT NULL DROP TABLE #latestDmCode
CREATE TABLE #latestDmCode (PatID int, latestDmCodeDate date, latestDmCodeMin varchar(512), latestDmCodeMax varchar(512), latestDmCode varchar(512));
insert into #latestDmCode 
	(PatID, latestDmCodeDate, latestDmCodeMin, latestDmCodeMax, latestDmCode)
select s.PatID, latestDmCodeDate, MIN(Rubric) as latestDmCodeMin, MAX(Rubric) as latestDmCodeMax, 
	case when MIN(Rubric)=MAX(Rubric) then MAX(Rubric) else 'Differ' end as latestDmCode from SIR_ALL_Records as s
	inner join (
		select PatID, MAX(EntryDate) as latestDmCodeDate from SIR_ALL_Records
		where ReadCode in (select code from codeGroups where [group] = 'dm')
		and EntryDate < @refdate
		group by PatID
	) sub on sub.PatID = s.PatID and sub.latestDmCodeDate = s.EntryDate
where ReadCode in (select code from codeGroups where [group] = 'dm')
and s.PatID in (select PatID from #latestCkd35code)
group by s.PatID, latestDmCodeDate

--#latestDmPermExCode 
--dm perm exclusions - i.e. DM resolved
--dm temp ex codes not included because this is a CKD indicator NOT a dm indicator
--NB min/max codes check if there have been different codes on the same day
IF OBJECT_ID('tempdb..#latestDmPermExCode') IS NOT NULL DROP TABLE #latestDmPermExCode
CREATE TABLE #latestDmPermExCode (PatID int, latestDmPermExCodeDate date, latestDmPermExCodeMin varchar(512), latestDmPermExCodeMax varchar(512), 
	latestDmPermExCode varchar(512));
insert into #latestDmPermExCode
	(PatID, latestDmPermExCodeDate, latestDmPermExCodeMin, latestDmPermExCodeMax, latestDmPermExCode)
select s.PatID, latestDmPermExCodeDate, MIN(Rubric) as latestDmPermExCodeMin, MAX(Rubric) as latestDmPermExCodeMax, 
	case when MIN(Rubric)=MAX(Rubric) then MAX(Rubric) else 'Differ' end as latestDmPermExCode from SIR_ALL_Records as s
	inner join (
		select PatID, MAX(EntryDate) as latestDmPermExCodeDate from SIR_ALL_Records
		where ReadCode in (select code from codeGroups where [group] = 'dmPermEx')
		and EntryDate < @refdate
		group by PatID
	) sub on sub.PatID = s.PatID and sub.latestDmPermExCodeDate = s.EntryDate
where ReadCode in (select code from codeGroups where [group] = 'dmPermEx')
and s.PatID in (select PatID from #latestCkd35code)
group by s.PatID, latestDmPermExCodeDate

--#firstDmCode
--patients' first DM code
--needed for the 'diagnosis within 9/12 exclusion criterion'
--NB min/max codes check if there have been different codes on the same day
IF OBJECT_ID('tempdb..#firstDmCode') IS NOT NULL DROP TABLE #firstDmCode
CREATE TABLE #firstDmCode (PatID int, firstDmCodeDate date, firstDmCodeMin varchar(512), firstDmCodeMax varchar(512), firstDmCode varchar(512));
insert into #firstDmCode 
	(PatID, firstDmCodeDate, firstDmCodeMin, firstDmCodeMax, firstDmCode)
select s.PatID, firstDmCodeDate, MIN(Rubric) as latestDmCodeMin, MAX(Rubric) as latestDmCodeMax, 
	case when MIN(Rubric)=MAX(Rubric) then MAX(Rubric) else 'Differ' end as firstDmCode from SIR_ALL_Records as s
	inner join (
		select PatID, MIN(EntryDate) as firstDmCodeDate from SIR_ALL_Records
		where ReadCode in (select code from codeGroups where [group] = 'dm')
		and EntryDate < @refdate
		group by PatID
	) sub on sub.PatID = s.PatID and sub.firstDmCodeDate = s.EntryDate
where ReadCode in (select code from codeGroups where [group] = 'dm')
and s.PatID in (select PatID from #latestCkd35code)
group by s.PatID, firstDmCodeDate

--#firstDmCodeAfter
--if patients have had a permanent DM exclusion code: the first DM code date AFTER the exclusion
--needed for the 'diagnosis within 9/12 exclusion criterion'
--NB min/max codes check if there have been different codes on the same day
IF OBJECT_ID('tempdb..#firstDmCodeAfter') IS NOT NULL DROP TABLE #firstDmCodeAfter
CREATE TABLE #firstDmCodeAfter (PatID int, firstDmCodeAfterDate date, firstDmCodeAfterMin varchar(512), 
	firstDmCodeAfterMax varchar(512), firstDmCodeAfter varchar(512)); --need this to exclude patients who have been diagnosed within 9/12 of target date as per QOF
insert into #firstDmCodeAfter
	(PatID, firstDmCodeAfterDate, firstDmCodeAfterMin, firstDmCodeAfterMax, firstDmCodeAfter)
select s.PatID, firstDmCodeAfterDate, MIN(Rubric) as firstDmCodeAfterMin, MAX(Rubric) as firstDmCodeAfterMax, 
	case when MIN(Rubric)=MAX(Rubric) then MAX(Rubric) else 'Differ' end as firstDmCodeAfter from SIR_ALL_Records as s
	inner join (
		select r.PatID, MIN(EntryDate) as firstDmCodeAfterDate from SIR_ALL_Records as r
			inner join #latestDmPermExCode as t on t.PatID = r.PatID
		where ReadCode in (select code from codeGroups where [group] = 'dm')
		and EntryDate < @refdate
		and EntryDate > latestDmPermExCodeDate --so if there is an exclusion code AND DM code on the same day, exclusion wins - if there are further DM codes afterwards then DM wins
		group by r.PatID
	) sub on sub.PatID = s.PatID and sub.firstDmCodeAfterDate = s.EntryDate
where ReadCode in (select code from codeGroups where [group] = 'dm')
and s.PatID in (select PatID from #latestCkd35code)
group by s.PatID, firstDmCodeAfterDate

--#latestSbp
IF OBJECT_ID('tempdb..#latestSbp') IS NOT NULL DROP TABLE #latestSbp
CREATE TABLE #latestSbp (PatID int, latestSbpDate date, latestSbp int);
insert into #latestSbp 
	(PatID, latestSbpDate, latestSbp)
select s.PatID, latestSbpDate, MIN(CodeValue) as latestSbp from SIR_ALL_Records as s
	inner join (
		select PatID, MAX(EntryDate) as latestSbpDate  from SIR_ALL_Records
		where ReadCode in (select code from codeGroups where [group] = 'sbp')
		and EntryDate < @refdate
		and CodeValue is not null 
		and CodeValue > 0
		group by PatID
	) sub on sub.PatID = s.PatID and sub.latestSbpDate = s.EntryDate
where ReadCode in (select code from codeGroups where [group] = 'sbp')
and s.PatID in (select PatID from #latestCkd35code)
group by s.PatID, latestSbpDate

--#latestDbp
IF OBJECT_ID('tempdb..#latestDbp') IS NOT NULL DROP TABLE #latestDbp
CREATE TABLE #latestDbp (PatID int, latestDbpDate date, latestDbp int);
insert into #latestDbp 
	(PatID, latestDbpDate, latestDbp)
select s.PatID, latestDbpDate, MIN(CodeValue) as latestDbp from SIR_ALL_Records as s
	inner join (
		select PatID, MAX(EntryDate) as latestDbpDate  from SIR_ALL_Records
		where ReadCode in (select code from codeGroups where [group] = 'dbp')
		and EntryDate < @refdate
		and CodeValue is not null 
		and CodeValue > 0
		group by PatID
	) sub on sub.PatID = s.PatID and sub.latestDbpDate = s.EntryDate
where ReadCode in (select code from codeGroups where [group] = 'dbp')
and s.PatID in (select PatID from #latestCkd35code)
group by s.PatID, latestDbpDate

--#latestAcr
IF OBJECT_ID('tempdb..#latestAcr') IS NOT NULL DROP TABLE #latestAcr
CREATE TABLE #latestAcr (PatID int, latestAcrDate date, latestAcr int);
insert into #latestAcr 
	(PatID, latestAcrDate, latestAcr)
select s.PatID, latestAcrDate, MIN(CodeValue) as latestAcr from SIR_ALL_Records as s
	inner join (
		select PatID, MAX(EntryDate) as latestAcrDate from SIR_ALL_Records
		where ReadCode in (select code from codeGroups where [group] = 'acr')
		and EntryDate < @refdate
		group by PatID
	) sub on sub.PatID = s.PatID and sub.latestAcrDate = s.EntryDate
where ReadCode in (select code from codeGroups where [group] = 'acr')
and s.PatID in (select PatID from #latestCkd35code)
group by s.PatID, latestAcrDate

--#dmProtPatient
IF OBJECT_ID('tempdb..#dmProtPatient') IS NOT NULL DROP TABLE #dmProtPatient
CREATE TABLE #dmProtPatient (PatID int, dmPatient int, protPatient int);
insert into #dmProtPatient
	(PatID, dmPatient, protPatient)
select a.PatID,
	case when
					(
						(latestDmCode is NULL) or (latestDmPermExCodeDate > latestDmCodeDate) --no DM code, or perm ex code AFTER DM code
					)
						or
					(
						(firstDmCodeDate > DATEADD(month, -9, @achievedate)) or (firstDmCodeAfterDate > DATEADD(month, -9, @achievedate)) --first DM code is within 9/12 of achievement date, or have been perm ex but then re-diagnosed within 9/12
					) then 0 else 1 end as dmPatient, --DM patient
	case when (latestAcr is null) or (latestAcr < 70) then 0 else 1 end as protPatient
from #firstCkd35code as a
		left outer join (select PatID, latestDmCodeDate, latestDmCode from #latestDmCode) b on b.PatID = a.PatID
		left outer join (select PatID, latestDmPermExCodeDate from #latestDmPermExCode) c on c.PatID = a.PatID
		left outer join (select PatID, firstDmCodeDate from #firstDmCode) d on d.PatID = a.PatID
		left outer join (select PatID, firstDmCodeAfterDate from #firstDmCodeAfter) e on e.PatID = a.PatID
		left outer join (select PatID, latestAcr from #latestAcr) f on f.PatID = a.PatID
		
--#bpTargetMeasuredControlled
IF OBJECT_ID('tempdb..#bpTargetMeasuredControlled') IS NOT NULL DROP TABLE #bpTargetMeasuredControlled
CREATE TABLE #bpTargetMeasuredControlled 
	(PatID int, bpTarget varchar(512), bpMeasuredOk int, bpControlledOk int);
insert into #bpTargetMeasuredControlled
select a.PatID,
	case when (dmPatient = 1 or protPatient = 1) then '<130/80' else '<140/90' end as bpTarget, --SS
	case when (latestSbpDate > DATEADD(month, -12, @achievedate)) and (latestDbpDate > DATEADD(month, -12, @achievedate)) then 1 else 0 end as bpMeasuredOk,  --measured within 12/12 of achievedate (SS)
	case when 
		(
			(dmPatient = 1 or protPatient = 1) and
			(latestSbp < 130 and latestDbp < 80) --SS
		)
			or
		(
			(dmPatient = 0 and protPatient = 0) and
			(latestSbp < 140 and latestDbp < 90) --SS
		) then 1 else 0 end as bpControlledOk
from #firstCkd35code as a
		left outer join (select PatID, latestSbp, latestSbpDate from #latestSbp) b on b.PatID = a.PatID
		left outer join (select PatID, latestDbp, latestDbpDate from #latestDbp) c on c.PatID = a.PatID
		left outer join (select PatID, dmPatient, protPatient from #dmProtPatient) e on e.PatID = a.PatID

--#exclusions
IF OBJECT_ID('tempdb..#exclusions') IS NOT NULL DROP TABLE #exclusions
CREATE TABLE #exclusions 
	(PatID int, ageExclude int, regCodeExclude int, deRegCodeExclude int, tempExExclude int, 
	deadCodeExclude int, deadTableExclude int, diagExclude int, permExExclude int);
insert into #exclusions
select a.PatID,
	case when age < 17 then 1 else 0 end as ageExclude, -- Demographic exclusions: Under 18 at achievement date (from QOF v34 business rules)
	case when latestRegisteredCodeDate > DATEADD(month, -9, @achievedate) then 1 else 0 end as regCodeExclude, -- Registration date: > achievement date - 9/12 (from CKD ruleset_INLIQ_v32.0)
	case when latestDeregCodeDate > latestCkd35codeDate then 1 else 0 end as deRegCodeExclude, -- Exclude patients with deregistered codes AFTER their latest CKD 35 code
	case when latestCkdTempExCodeDate > DATEADD(month, -12, @achievedate) then 1 else 0 end as tempExExclude, -- Expiring exclusions: BP refusal or CKD not suitable or HTN max > achievement date - 12/12 (from QOF v34 business rules)
	case when latestDeadCodeDate > latestCkd35codeDate then 1 else 0 end as deadCodeExclude, -- Exclude patients with dead codes after their latest CKD35 code
	case when latestCkdPermExCodeDate > latestCkd35codeDate then 1 else 0 end as permExExclude, -- Permanent exclusions: CKD 1 or 2 or CKD resolved code afterwards (from QOF v34 business rules)
	case when deadTable = 1 then 1 else 0 end as deadTableExclude, -- Exclude patients listed as dead in the patients table
	case when (firstCkd35codeDate > DATEADD(month, -9, @achievedate)) or (firstCkd35codeAfterDate > DATEADD(month, -9, @achievedate)) then 1 else 0 end as diagExclude -- Diagnosis date: Latest CKD 3-5 code > target date - 9/12 (from CKD ruleset_INLIQ_v32.0)
from #latestCkd35code as a
	left outer join (select PatID, age from #age) b on b.PatID = a.PatID
	left outer join (select PatID, latestCkdPermExCodeDate, latestCkdPermExCode from #latestCkdPermExCode) c on c.PatID = a.PatID
	left outer join (select PatID, latestCkdTempExCodeDate, latestCkdTempExCode from #latestCkdTempExCode) d on d.PatID = a.PatID
	left outer join (select PatID, latestRegisteredCodeDate, latestRegisteredCode from #latestRegisteredCode) e on e.PatID = a.PatID
	left outer join (select PatID, latestDeregCodeDate, latestDeregCode from #latestDeregCode) f on f.PatID = a.PatID
	left outer join (select PatID, latestDeadCodeDate, latestDeadCode from #latestDeadCode) j on j.PatID = a.PatID
	left outer join (select PatID, deadTable, deadTableMonth, deadTableYear from #deadTable) g on g.PatID = a.PatID
	left outer join (select PatID, firstCkd35codeDate, firstCkd35code from #firstCkd35code) h on h.PatID = a.PatID
	left outer join (select PatID, firstCkd35codeAfterDate, firstCkd35codeAfter from #firstCkd35codeAfter) i on i.PatID = a.PatID

--#denominator
IF OBJECT_ID('tempdb..#denominator') IS NOT NULL DROP TABLE #denominator
CREATE TABLE #denominator (PatID int, denominator int);
insert into #denominator
select a.PatID,
	case when ageExclude = 0 and permExExclude  = 0 and tempExExclude  = 0 and regCodeExclude  = 0 
		and diagExclude  = 0 and deRegCodeExclude  = 0 and 	deadCodeExclude  = 0 and deadTableExclude  = 0 
		then 1 else 0 end as denominator
from #latestCkd35code as a
	left outer join (select PatID, ageExclude, permExExclude, tempExExclude, regCodeExclude, diagExclude, 
					deRegCodeExclude, deadCodeExclude, deadTableExclude from #exclusions) b on b.PatID = a.PatID

--#numerator
IF OBJECT_ID('tempdb..#numerator') IS NOT NULL DROP TABLE #numerator
CREATE TABLE #numerator (PatID int, numerator int);
insert into #numerator
select a.PatID,
	case when denominator = 1 and bpMeasuredOk = 1 and bpControlledOk = 1 then 1 else 0 end as numerator
from #latestCkd35code as a
		left outer join (select PatID, denominator from #denominator) b on b.PatID = a.PatID
		left outer join (select PatID, bpMeasuredOk, bpControlledOk from #bpTargetMeasuredControlled) c on c.PatID = a.PatID

--#eligiblePopulationAllData
--all data from above combined into one table, plus numerator column
IF OBJECT_ID('tempdb..#eligiblePopulationAllData') IS NOT NULL DROP TABLE #eligiblePopulationAllData
CREATE TABLE #eligiblePopulationAllData (PatID int, 
	age int, 
	latestCkd35codeDate date, latestCkd35code varchar(512), 
	latestCkdPermExCode varchar(512), latestCkdPermExCodeDate date, 
	latestCkdTempExCode varchar(512), latestCkdTempExCodeDate date, 
	latestRegisteredCode varchar(512), latestRegisteredCodeDate date, 
	latestDeregCode varchar(512), latestDeregCodeDate date, 
	latestDeadCode varchar(512), latestDeadCodeDate date, 
	deadTable int, deadTableMonth int, deadTableYear int, 
	firstCkd35code varchar(512), firstCkd35codeDate date, 
	firstCkd35codeAfter varchar(512), firstCkd35codeAfterDate date, 
	latestDmCode varchar(512), latestDmCodeDate date, 
	latestDmPermExCode varchar(512), latestDmPermExCodeDate date, 
	firstDmCode varchar(512), firstDmCodeDate date, 
	firstDmCodeAfter varchar(512), firstDmCodeAfterDate date, 
	latestSbpDate date, latestSbp int, 
	latestDbpDate date, latestDbp int, 
	latestAcrDate date, latestAcr int, 
	dmPatient int, protPatient int, 
	bpMeasuredOK int, bpTarget varchar(512), bpControlledOk int, 
	ageExclude int, permExExclude int, tempExExclude int, regCodeExclude int, diagExclude int, deRegCodeExclude int, deadCodeExclude int, deadTableExclude int, 
	denominator int, 
	numerator int);
insert into #eligiblePopulationAllData
select a.PatID, 
	age, 
	a.latestCkd35codeDate, a.latestCkd35code, 
	latestCkdPermExCode, latestCkdPermExCodeDate, 
	latestCkdTempExCode, latestCkdTempExCodeDate, 
	latestRegisteredCode, latestRegisteredCodeDate, 
	latestDeregCode, latestDeregCodeDate, 
	latestDeadCode, latestDeadCodeDate, 
	deadTable, deadTableMonth, deadTableYear, 
	firstCkd35code, firstCkd35codeDate, 
	firstCkd35codeAfter, firstCkd35codeAfterDate, 
	latestDmCode, latestDmCodeDate, 
	latestDmPermExCode, latestDmPermExCodeDate, 
	firstDmCode, firstDmCodeDate, 
	firstDmCodeAfter, firstDmCodeAfterDate, 
	latestSbpDate, latestSbp, 
	latestDbpDate, latestDbp, 
	latestAcrDate, latestAcr, 
	dmPatient, protPatient, 
	bpMeasuredOk, bpTarget, bpControlledOk, 
	ageExclude, permExExclude, tempExExclude, regCodeExclude, diagExclude, deRegCodeExclude, deadCodeExclude, deadTableExclude, 
	denominator, 
	numerator
from #latestCkd35code as a
		left outer join (select PatID, age from #age) b on b.PatID = a.PatID
		left outer join (select PatID, latestCkdPermExCode, latestCkdPermExCodeDate from #latestCkdPermExCode) c on c.PatID = a.PatID
		left outer join (select PatID, latestCkdTempExCode, latestCkdTempExCodeDate from #latestCkdTempExCode) d on d.PatID = a.PatID
		left outer join (select PatID, latestRegisteredCode, latestRegisteredCodeDate from #latestRegisteredCode) e on e.PatID = a.PatID
		left outer join (select PatID, latestDeregCode, latestDeregCodeDate from #latestDeregCode) f on f.PatID = a.PatID
		left outer join (select PatID, latestDeadCode, latestDeadCodeDate from #latestDeadCode) g on g.PatID = a.PatID
		left outer join (select PatID, deadTable, deadTableMonth, deadTableYear from #deadTable) h on h.PatID = a.PatID
		left outer join (select PatID, firstCkd35code, firstCkd35codeDate from #firstCkd35code) i on i.PatID = a.PatID
		left outer join (select PatID, firstCkd35codeAfter, firstCkd35codeAfterDate from #firstCkd35codeAfter) j on j.PatID = a.PatID
		left outer join (select PatID, latestDmCode, latestDmCodeDate from #latestDmCode) k on k.PatID = a.PatID
		left outer join (select PatID, latestDmPermExCode, latestDmPermExCodeDate from #latestDmPermExCode) l on l.PatID = a.PatID
		left outer join (select PatID, firstDmCode, firstDmCodeDate from #firstDmCode) m on m.PatID = a.PatID
		left outer join (select PatID, firstDmCodeAfter, firstDmCodeAfterDate from #firstDmCodeAfter) n on n.PatID = a.PatID
		left outer join (select PatID, latestSbpDate, latestSbp from #latestSbp) o on o.PatID = a.PatID
		left outer join (select PatID, latestDbpDate, latestDbp from #latestDbp) p on p.PatID = a.PatID
		left outer join (select PatID, latestAcrDate, latestAcr from #latestAcr) r on r.PatID = a.PatID
		left outer join (select PatID, dmPatient, protPatient from #dmProtPatient) s on s.PatID = a.PatID
		left outer join (select PatID, bpMeasuredOk, bpTarget, bpControlledOk from #bpTargetMeasuredControlled) t on t.PatID = a.PatID
		left outer join (select PatID, ageExclude, permExExclude, tempExExclude, regCodeExclude, diagExclude, deRegCodeExclude, 
						deadCodeExclude, deadTableExclude from #exclusions) u on u.PatID = a.PatID
		left outer join (select PatID, denominator from #denominator) v on v.PatID = a.PatID
		left outer join (select PatID, numerator from #numerator) w on w.PatID = a.PatID
		
					-----------------------------------------------------------------------------
					---------------------GET ABC (TOP 10% BENCHMARK)-----------------------------
					-----------------------------------------------------------------------------
declare @val float;
set @val = (select round(avg(perc),2) from (
select top 5 sum(case when numerator = 1 then 1.0 else 0.0 end) / SUM(case when denominator = 1 then 1.0 else 0.0 end) as perc from #eligiblePopulationAllData as a
	inner join ptPractice as b on a.PatID = b.PatID
	group by b.pracID
	having SUM(case when denominator = 1 then 1.0 else 0.0 end) > 0
	order by perc desc) sub);

					-----------------------------------------------------------------------------
					--DECLARE NUMERATOR, INDICATOR AND TARGET FROM DENOMINATOR TABLE-------------
					-----------------------------------------------------------------------------
									--TO RUN AS STORED PROCEDURE--
insert into [output.pingr.indicator](indicatorId, practiceId, date, numerator, denominator, target, benchmark)

									--TO TEST ON THE FLY--
--IF OBJECT_ID('tempdb..#indicator') IS NOT NULL DROP TABLE #indicator
--CREATE TABLE #indicator (indicatorId varchar(1000), practiceId varchar(1000), date date, numerator int, denominator int, target float, benchmark float);
--insert into #indicator

select 'ckd.treatment.bp', b.pracID, CONVERT(char(10), @refdate, 126) as date, sum(case when numerator = 1 then 1 else 0 end) as numerator, sum(case when denominator = 1 then 1 else 0 end) as denominator, 0.80 as target, @val from #eligiblePopulationAllData as a
	inner join ptPractice as b on a.PatID = b.PatID
	group by b.pracID;

								---------------------------------------------------------
								-- Exit if we're just getting the indicator numbers -----
								---------------------------------------------------------
IF @JustTheIndicatorNumbersPlease = 1 RETURN;

				---------------------------------------------------------------------------------------------------------------------
				--OBTAIN INFORMATION RELATED TO IMP OPPS FOR EACH PATIENT IN DENOMINATOR BUT *NOT* IN NUMERATOR----------------------
				---------------------------------------------------------------------------------------------------------------------
				--AS ABOVE, CREATE TEMP TABLES FOR EACH COLUMN OF DATA NEEDED, FROM EACH PATIENT IN DENOM BUT  BUT *NOT* IN NUMERATOR
				--COMBINE TABLES TOGETHER THAT NEED TO BE QUERIED TO CREATE NEW TABLES
				--THEN COMBINE ALL TABLES TOGETHER INTO ONE BIG TABLE TO BE QUERIED IN FUTURE
				---------------------------------------------------------------------------------------------------------------------

--#latestPalCode
IF OBJECT_ID('tempdb..#latestPalCode') IS NOT NULL DROP TABLE #latestPalCode
CREATE TABLE #latestPalCode 
	(PatID int, latestPalCodeDate date, latestPalCodeMin varchar(512), latestPalCodeMax varchar(512), latestPalCode varchar(512));
insert into #latestPalCode
select s.PatID, latestPalCodeDate, MIN(Rubric) as latestPalCodeMin, MAX(Rubric) as latestPalCodeMax, 
	case when MIN(Rubric)=MAX(Rubric) then MAX(Rubric) else 'Differ' end as latestPalCode from SIR_ALL_Records as s
		inner join (select PatID, MAX(EntryDate) as latestPalCodeDate from SIR_ALL_Records
							where ReadCode in (select code from codeGroups where [group] = 'pal') and EntryDate < @refdate
							and PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
							group by PatID
					) sub on sub.PatID = s.PatID and sub.latestPalCodeDate = s.EntryDate
where 
	ReadCode in (select code from codeGroups where [group] = 'pal')
	and s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
group by s.PatID, latestPalCodeDate

--#latestPalPermExCode
IF OBJECT_ID('tempdb..#latestPalPermExCode') IS NOT NULL DROP TABLE #latestPalPermExCode
CREATE TABLE #latestPalPermExCode 
	(PatID int, latestPalPermExCodeDate date, latestPalPermExCodeMin varchar(512), latestPalPermExCodeMax varchar(512), 
		latestPalPermExCode varchar(512));
insert into #latestPalPermExCode
select s.PatID, latestPalPermExCodeDate, MIN(Rubric) as latestPalPermExCodeMin, MAX(Rubric) as latestPalPermExCodeMax, 
	case when MIN(Rubric)=MAX(Rubric) then MAX(Rubric) else 'Differ' end as latestPalPermExCode from SIR_ALL_Records as s
		inner join (select PatID, MAX(EntryDate) as latestPalPermExCodeDate from SIR_ALL_Records
							where ReadCode in (select code from codeGroups where [group] = 'palPermEx') and EntryDate < @refdate
							and PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
							group by PatID
					) sub on sub.PatID = s.PatID and sub.latestPalPermExCodeDate = s.EntryDate
where 
	ReadCode in (select code from codeGroups where [group] = 'palPermEx')
	and s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
group by s.PatID, latestPalPermExCodeDate

--#latestFrailCode
IF OBJECT_ID('tempdb..#latestFrailCode') IS NOT NULL DROP TABLE #latestFrailCode
CREATE TABLE #latestFrailCode 
	(PatID int, latestFrailCodeDate date, latestFrailCodeMin varchar(512), latestFrailCodeMax varchar(512), latestFrailCode varchar(512));
insert into #latestFrailCode
select s.PatID, latestFrailCodeDate, MIN(Rubric) as latestFrailCodeMin, MAX(Rubric) as latestFrailCodeMax, 
	case when MIN(Rubric)=MAX(Rubric) then MAX(Rubric) else 'Differ' end as latestFrailCode from SIR_ALL_Records as s
		inner join (select PatID, MAX(EntryDate) as latestFrailCodeDate from SIR_ALL_Records
							where ReadCode in (select code from codeGroups where [group] = 'frail') and EntryDate < @refdate
							and PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
							group by PatID
					) sub on sub.PatID = s.PatID and sub.latestFrailCodeDate = s.EntryDate
where 
	ReadCode in (select code from codeGroups where [group] = 'frail')
	and s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
group by s.PatID, latestFrailCodeDate

--#latestHouseBedboundCode
IF OBJECT_ID('tempdb..#latestHouseBedboundCode') IS NOT NULL DROP TABLE #latestHouseBedboundCode
CREATE TABLE #latestHouseBedboundCode 
	(PatID int, latestHouseBedboundCodeDate date, latestHouseBedboundCodeMin varchar(512), latestHouseBedboundCodeMax varchar(512), 
		latestHouseBedboundCode varchar(512));
insert into #latestHouseBedboundCode
select s.PatID, latestHouseBedboundCodeDate, MIN(Rubric) as latestHouseBedboundCodeMin, MAX(Rubric) as latestHouseBedboundCodeMax, 
	case when MIN(Rubric)=MAX(Rubric) then MAX(Rubric) else 'Differ' end as latestHouseBedboundCode from SIR_ALL_Records as s
		inner join (select PatID, MAX(EntryDate) as latestHouseBedboundCodeDate from SIR_ALL_Records
							where ReadCode in (select code from codeGroups where [group] in ('housebound', 'bedridden')) and EntryDate < @refdate
							and PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
							group by PatID
					) sub on sub.PatID = s.PatID and sub.latestHouseBedboundCodeDate = s.EntryDate
where 
	ReadCode in (select code from codeGroups where [group] in ('housebound', 'bedridden'))
	and s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
group by s.PatID, latestHouseBedboundCodeDate

--#latestHouseBedboundPermExCode
IF OBJECT_ID('tempdb..#latestHouseBedboundPermExCode') IS NOT NULL DROP TABLE #latestHouseBedboundPermExCode
CREATE TABLE #latestHouseBedboundPermExCode 
	(PatID int, latestHouseBedboundPermExCodeDate date, latestHouseBedboundPermExCodeMin varchar(512), latestHouseBedboundPermExCodeMax varchar(512), 
		latestHouseBedboundPermExCode varchar(512));
insert into #latestHouseBedboundPermExCode
select s.PatID, latestHouseBedboundPermExCodeDate, MIN(Rubric) as latestHouseBedboundPermExCodeMin, MAX(Rubric) as latestHouseBedboundPermExCodeMax, 
	case when MIN(Rubric)=MAX(Rubric) then MAX(Rubric) else 'Differ' end as latestHouseBedboundPermExCode from SIR_ALL_Records as s
		inner join (select PatID, MAX(EntryDate) as latestHouseBedboundPermExCodeDate from SIR_ALL_Records
							where ReadCode in (select code from codeGroups where [group] = 'houseboundPermEx') and EntryDate < @refdate
							and PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
							group by PatID
					) sub on sub.PatID = s.PatID and sub.latestHouseBedboundPermExCodeDate = s.EntryDate
where 
	ReadCode in (select code from codeGroups where [group] = 'houseboundPermEx')
	and s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
group by s.PatID, latestHouseBedboundPermExCodeDate

--#latestCkd3rdInviteCode
IF OBJECT_ID('tempdb..#latestCkd3rdInviteCode') IS NOT NULL DROP TABLE #latestCkd3rdInviteCode
CREATE TABLE #latestCkd3rdInviteCode 
	(PatID int, latestCkd3rdInviteCodeDate date, latestCkd3rdInviteCodeMin varchar(512), latestCkd3rdInviteCodeMax varchar(512), 
		latestCkd3rdInviteCode varchar(512));
insert into #latestCkd3rdInviteCode
select s.PatID, latestCkd3rdInviteCodeDate, MIN(Rubric) as latestCkd3rdInviteCodeMin, MAX(Rubric) as latestCkd3rdInviteCodeMax, 
	case when MIN(Rubric)=MAX(Rubric) then MAX(Rubric) else 'Differ' end as latestCkd3rdInviteCode from SIR_ALL_Records as s
		inner join (select PatID, MAX(EntryDate) as latestCkd3rdInviteCodeDate from SIR_ALL_Records
							where ReadCode in (select code from codeGroups where [group] = 'ckd3rdInvite') and EntryDate < @refdate
							and PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
							group by PatID
					) sub on sub.PatID = s.PatID and sub.latestCkd3rdInviteCodeDate = s.EntryDate
where 
	ReadCode in (select code from codeGroups where [group] = 'ckd3rdInvite')
	and s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
group by s.PatID, latestCkd3rdInviteCodeDate

--#numberOfCkdInviteCodesThisFinancialYear
IF OBJECT_ID('tempdb..#numberOfCkdInviteCodesThisFinancialYear') IS NOT NULL DROP TABLE #numberOfCkdInviteCodesThisFinancialYear
CREATE TABLE #numberOfCkdInviteCodesThisFinancialYear 
	(PatID int, numberOfCkdInviteCodesThisFinancialYear int);
insert into #numberOfCkdInviteCodesThisFinancialYear
select PatID, count (*) from SIR_ALL_Records as numberOfCkdInviteCodesThisYear
	where ReadCode in (select code from codeGroups where [group] = 'ckdInvite') 
		and EntryDate < @refdate 
		and EntryDate > DATEADD(year, -1, @achievedate)
		and PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
	group by PatID

--#latestWhiteCoatCode
IF OBJECT_ID('tempdb..#latestWhiteCoatCode') IS NOT NULL DROP TABLE #latestWhiteCoatCode
CREATE TABLE #latestWhiteCoatCode 
	(PatID int, latestWhiteCoatCodeDate date, latestWhiteCoatCodeMin varchar(512), latestWhiteCoatCodeMax varchar(512), 
		latestWhiteCoatCode varchar(512));	
insert into #latestWhiteCoatCode
select s.PatID, latestWhiteCoatCodeDate, MIN(Rubric) as latestWhiteCoatCodeMin, MAX(Rubric) as latestWhiteCoatCodeMax, 
	case when MIN(Rubric)=MAX(Rubric) then MAX(Rubric) else 'Differ' end as latestWhiteCoatCode from SIR_ALL_Records as s
		inner join (select PatID, MAX(EntryDate) as latestWhiteCoatCodeDate from SIR_ALL_Records
							where ReadCode in (select code from codeGroups where [group] = 'whiteCoat') and EntryDate < @refdate
							and PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
							group by PatID
					) sub on sub.PatID = s.PatID and sub.latestWhiteCoatCodeDate = s.EntryDate
where 
	ReadCode in (select code from codeGroups where [group] = 'whiteCoat')
	and s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
group by s.PatID, latestWhiteCoatCodeDate

--#primCareContactInLastYear
--list of pat IDs that have had primary care contact in the last year
IF OBJECT_ID('tempdb..#primCareContactInLastYear') IS NOT NULL DROP TABLE #primCareContactInLastYear
CREATE TABLE #primCareContactInLastYear
	(PatID int);
insert into #primCareContactInLastYear
select PatID from SIR_ALL_Records
where EntryDate < @refdate 
	and Source !='salfordt' --not hospital code
	and ReadCode not in (select code from codeGroups where [group] in ('occupations', 'admin', 'recordOpen', 'letterReceived', 'contactAttempt', 'dna')) --not admin code
	and EntryDate > DATEADD(year, -1, @refdate)
	and PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
group by PatID

--#noPrimCareContactInLastYear
IF OBJECT_ID('tempdb..#noPrimCareContactInLastYear') IS NOT NULL DROP TABLE #noPrimCareContactInLastYear
CREATE TABLE #noPrimCareContactInLastYear
	(PatID int, noPrimCareContactInLastYear int);
insert into #noPrimCareContactInLastYear
select PatID, case when PatID in (select PatID from #primCareContactInLastYear) then 0 else 1 end as noPrimCareContactInLastYear 
from #eligiblePopulationAllData 
where denominator = 1 and numerator = 0

--#secondLatestSbp
IF OBJECT_ID('tempdb..#secondLatestSbp') IS NOT NULL DROP TABLE #secondLatestSbp
CREATE TABLE #secondLatestSbp (PatID int, secondLatestSbpDate date, secondLatestSbp int);
insert into #secondLatestSbp
select a.PatID, secondLatestSbpDate, MIN(a.CodeValue) from SIR_ALL_Records as a
	inner join
		(
			select s.PatID, max(s.EntryDate) as secondLatestSbpDate from SIR_ALL_Records as s
				inner join 
					(
						select PatID, latestSbpDate from #latestSbp --i.e. select latest SBP date
					)sub on sub.PatID = s.PatID and sub.latestSbpDate > s.EntryDate --i.e. select max date where the latest SBP date is still greate (the second to last date)
			where ReadCode in (select code from codeGroups where [group] = 'sbp')
			and s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
			group by s.PatID
		) sub on sub.PatID = a.PatID and sub.secondLatestSbpDate = a.EntryDate
where ReadCode in (select code from codeGroups where [group] = 'sbp')
and a.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
group by a.PatID, secondLatestSbpDate

--#secondLatestDbp
IF OBJECT_ID('tempdb..#secondLatestDbp') IS NOT NULL DROP TABLE #secondLatestDbp
CREATE TABLE #secondLatestDbp (PatID int, secondLatestDbpDate date, secondLatestDbp int);
insert into #secondLatestDbp
select a.PatID, secondLatestDbpDate, MIN(a.CodeValue) from SIR_ALL_Records as a
	inner join
		(
			select s.PatID, max(s.EntryDate) as secondLatestDbpDate from SIR_ALL_Records as s
				inner join 
					(
						select PatID, latestDbpDate from #latestDbp --i.e. select latest DBP date
					)sub on sub.PatID = s.PatID and sub.latestDbpDate > s.EntryDate --i.e. select max date where the latest SBP date is still greate (the second to last date)
			where ReadCode in (select code from codeGroups where [group] = 'dbp')
			and s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
			group by s.PatID
		) sub on sub.PatID = a.PatID and sub.secondLatestDbpDate = a.EntryDate
where ReadCode in (select code from codeGroups where [group] = 'dbp')
and a.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
group by a.PatID, secondLatestDbpDate

--secondLatestBpControlled
IF OBJECT_ID('tempdb..#secondLatestBpControlled') IS NOT NULL DROP TABLE #secondLatestBpControlled
CREATE TABLE #secondLatestBpControlled
	(PatID int, secondLatestBpControlled int);
insert into #secondLatestBpControlled
select a.PatID,
	case when 
		(
			(dmPatient = 1 or protPatient = 1) and
			(secondLatestSbp < 130 and secondLatestDbp < 80) --SS
		)
			or
		(
			(dmPatient = 0 and protPatient = 0) and
			(secondLatestSbp < 140 and secondLatestDbp < 90) --SS
		) then 1 else 0 end as secondLatestBpControlled
from #eligiblePopulationAllData as a
		left outer join (select PatID, secondLatestSbp, secondLatestSbpDate from #secondLatestSbp) b on b.PatID = a.PatID
		left outer join (select PatID, secondLatestDbp, secondLatestDbpDate from #secondLatestDbp) c on c.PatID = a.PatID
where denominator = 1 and numerator = 0

							-----------------------------------------------------
							--------------------MEDICATIONS----------------------
							-----------------------------------------------------

--#latestMedOptimisation
IF OBJECT_ID('tempdb..#latestMedOptimisation') IS NOT NULL DROP TABLE #latestMedOptimisation
CREATE TABLE #latestMedOptimisation 
	(PatID int, latestMedOptimisation varchar(512), latestMedOptimisationDate date, 
	latestMedOptimisationIngredient varchar(512), latestMedOptimisationDose float, 
	latestMedOptimisationFamily varchar(512));
insert into #latestMedOptimisation
	select s.PatID, s.Event, s.EntryDate, s.Ingredient, s.Dose, s.Family from MEDICATION_EVENTS_HTN as s 
  		inner join 
  			(  
			 select PatID, MAX(EntryDate) as date from MEDICATION_EVENTS_HTN
			 where PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
			 group by PatID
  			) sub on sub.PatID = s.PatID and sub.date = s.EntryDate
	where 
 		[Event] in ('DOSE INCREASED', 'STARTED', 'RESTARTED')
		and s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)

--#latestMedAdherence i.e. latest occurrence of anti-HTN (any) medication non-adherence
IF OBJECT_ID('tempdb..#latestMedAdherence') IS NOT NULL DROP TABLE #latestMedAdherence
CREATE TABLE #latestMedAdherence
	(PatID int, latestMedAdherenceDate date, latestMedAdherenceIngredient varchar(512), latestMedAdherenceDose float, latestMedAdherenceFamily varchar(512));
insert into #latestMedAdherence
		select s.PatID, s.EntryDate, s.Ingredient, s.Dose, s.Family from MEDICATION_EVENTS_HTN as s 
  		inner join 
  			(  
			 select PatID, MAX(EntryDate) as latestMedAdherenceDate from MEDICATION_EVENTS_HTN
			 where PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
			 group by PatID
  			) sub on sub.PatID = s.PatID and sub.latestMedAdherenceDate = s.EntryDate
 where 
 	[Event] = 'ADHERENCE'
	and s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)

--#currentHTNmeds
IF OBJECT_ID('tempdb..#currentHTNmeds') IS NOT NULL DROP TABLE #currentHTNmeds
CREATE TABLE #currentHTNmeds 
	(PatID int, currentMedEventDate date, currentMedIngredient varchar(512), currentMedFamily varchar(512), currentMedEvent varchar(512), currentMedDose float, currentMedMaxDose float);
insert into #currentHTNmeds
select a.PatID, a.EntryDate, a.Ingredient, a.Family, a.Event, a.Dose, c.MaxDose from MEDICATION_EVENTS_HTN as a
	inner join 
		(  
			select PatID, Ingredient, MAX(EntryDate) as LatestEventDate from MEDICATION_EVENTS_HTN
			 where PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
			group by PatID, Ingredient
		) as b on b.PatID = a.PatID and b.LatestEventDate = a.EntryDate and b.Ingredient = a.Ingredient
 	left outer join
 		(select Ingredient, MaxDose from drugIngredients) as c on b.Ingredient = c.Ingredient
where [Event] in ('DOSE DECREASED','DOSE INCREASED', 'STARTED', 'RESTARTED','ADHERENCE')
and a.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)

--#htnMeds
--above table plus a column stating the number of different drugs in the same family the patient is taking
IF OBJECT_ID('tempdb..#htnMeds') IS NOT NULL DROP TABLE #htnMeds
CREATE TABLE #htnMeds 
	(PatID int, currentMedEventDate date, currentMedIngredient varchar(512) COLLATE Latin1_General_100_CS_AS, currentMedFamily varchar(512), currentMedEvent varchar(512), currentMedDose float, currentMedMaxDose float, noIngredientsInFamily int);
insert into #htnMeds
select a.PatID, currentMedEventDate, a.currentMedIngredient, a.currentMedFamily, currentMedEvent, currentMedDose, currentMedMaxDose, noIngredientsInFamily from #currentHTNmeds as a
	inner join
		(
			select PatID, currentMedFamily, COUNT(*) as noIngredientsInFamily from #currentHTNmeds
			group by PatID, currentMedFamily
		) as b on b.PatID = a.PatID and b.currentMedFamily = a.currentMedFamily


--ALLERGIES AND CONTRA-INDICATIONS TO ANT-HTN MEDS
--------------------------------------------------
--1. Thiazides http://dx.doi.org/10.18578/BNF.748067014
	--Addison�s disease; hypercalcaemia; hyponatraemia; refractory hypokalaemia; symptomatic hyperuricaemia
--2. ACEI http://dx.doi.org/10.18578/BNF.569976968
	-- NIL!
--3. ARB http://dx.doi.org/10.18578/BNF.479478171 
	--NIL!
--4. CCB
	--AMLODIPINE http://dx.doi.org/10.18578/BNF.109201061 Cardiogenic shock; ***significant aortic stenosis***; unstable angina
	--NIFEDIPINE http://dx.doi.org/10.18578/BNF.342536833 Acute attacks of angina; cardiogenic shock; ***significant aortic stenosis***; unstable angina; ***within 1 month of myocardial infarction***
	--LERCANIDIPINE http://dx.doi.org/10.18578/BNF.421178523 ***Acute porphyrias***; ***aortic stenosis***; uncontrolled heart failure; unstable angina; ***within 1 month of myocardial infarction***
	--LACIDIPINE http://dx.doi.org/10.18578/BNF.881677908 ***Acute porphyrias***; ***aortic stenosis***; ***avoid within 1 month of myocardial infarction***; cardiogenic shock; unstable angina
	--ISRADIPINE http://dx.doi.org/10.18578/BNF.786204349 ***Acute porphyrias***; cardiogenic shock;***during or within 1 month of myocardial infarction***; unstable angina
	--FELODIPINE http://dx.doi.org/10.18578/BNF.405039793 Cardiac outflow obstruction; significant cardiac valvular obstruction (e.g. ***aortic stenosis***); uncontrolled heart failure; unstable angina; ***within 1 month of myocardial infarction***
	--DILTIAZEM http://dx.doi.org/10.18578/BNF.873608533 ***Acute porphyrias***; left ventricular failure with pulmonary congestion; ***second- or third-degree AV block (unless pacemaker fitted)***; ***severe bradycardia***; ***sick sinus syndrome***
--5. BB http://dx.doi.org/10.18578/BNF.281805035 
	--Asthma; cardiogenic shock; hypotension; marked bradycardia; metabolic acidosis; 
	--phaeochromocytoma (apart from specific use with alpha-blockers); Prinzmetal�s angina; second-degree AV block; 
	--severe peripheral arterial disease; sick sinus syndrome; third-degree AV block; uncontrolled heart failure
--6. Potassium Sparing Diuretics
	--EPLERENONE http://dx.doi.org/10.18578/BNF.845539498 ***Hyperkalaemia***
	--SPIRONOLACTONE http://dx.doi.org/10.18578/BNF.213718345 ***Addison�s disease***; anuria; ***hyperkalaemia***
	--AMILORIDE http://dx.doi.org/10.18578/BNF.840584388 ***Addison�s disease***; anuria; ***hyperkalaemia***
--7. Alpha blockers
	--DOXAZOSIN http://dx.doi.org/10.18578/BNF.782101311 History of micturition syncope (in patients with benign prostatic hypertrophy); ***history of postural hypotension***; monotherapy in patients with overflow bladder or anuria
	--INDORAMIN http://dx.doi.org/10.18578/BNF.222025343 ***Established heart failure***; history micturition syncope (when used for benign prostatic hyperplasia); ***history of postural hypotension (when used for benign prostatic hyperplasia)***
	--PRAZOSIN http://dx.doi.org/10.18578/BNF.444050694 History of micturition syncope; ***history of postural hypotension***; not recommended for congestive heart failure due to mechanical obstruction (e.g. ***aortic stenosis***)
	--TERAZOSIN http://dx.doi.org/10.18578/BNF.434025504 History of micturition syncope (in benign prostatic hyperplasia); ***history of postural hypotension (in benign prostatic hyperplasia)***
--8. Loop diuretics http://dx.doi.org/10.18578/BNF.267274341 
	--Anuria; comatose and precomatose states associated with liver cirrhosis; renal failure due to nephrotoxic or hepatotoxic drugs; 
	--***severe hypokalaemia***; ***severe hyponatraemia***

--#latestAllergyThiazideCode - i.e. allergy and 'adverse reaction' codes
IF OBJECT_ID('tempdb..#latestAllergyThiazideCode') IS NOT NULL DROP TABLE #latestAllergyThiazideCode
CREATE TABLE #latestAllergyThiazideCode
	(PatID int, latestAllergyThiazideCodeDate date, latestAllergyThiazideCode varchar(512));
insert into #latestAllergyThiazideCode
		select s.PatID, s.EntryDate, MAX(Rubric) from SIR_ALL_Records as s 
	  		inner join 
	  			(  
				 select PatID, MAX(EntryDate) as codeDate from SIR_ALL_Records
				 where ReadCode in (select code from codeGroups where [group] = 'thiazideAllergyAdverseReaction') and EntryDate < @refdate
				 and PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
				 group by PatID
	  			) sub on sub.PatID = s.PatID and sub.codeDate = s.EntryDate
		where 
			ReadCode in (select code from codeGroups where [group] = 'thiazideAllergyAdverseReaction') and
			s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
		group by s.PatID, s.EntryDate

--#latestAllergyACEIcode - i.e. allergy and 'adverse reaction' codes
IF OBJECT_ID('tempdb..#latestAllergyACEIcode') IS NOT NULL DROP TABLE #latestAllergyACEIcode
CREATE TABLE #latestAllergyACEIcode
	(PatID int, latestAllergyACEIcodeDate date, latestAllergyACEIcode varchar(512));
insert into #latestAllergyACEIcode
		select s.PatID, s.EntryDate, MAX(Rubric) from SIR_ALL_Records as s 
	  		inner join 
	  			(  
				 select PatID, MAX(EntryDate) as codeDate from SIR_ALL_Records
				 where ReadCode in (select code from codeGroups where [group] = 'ACEIallergyAdverseReaction') and EntryDate < @refdate
				 and PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
				 group by PatID
	  			) sub on sub.PatID = s.PatID and sub.codeDate = s.EntryDate
		where 
			ReadCode in (select code from codeGroups where [group] = 'ACEIallergyAdverseReaction') and
			s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
		group by s.PatID, s.EntryDate

--#latestAllergyARBcode - i.e. allergy and 'adverse reaction' codes
IF OBJECT_ID('tempdb..#latestAllergyARBcode') IS NOT NULL DROP TABLE #latestAllergyARBcode
CREATE TABLE #latestAllergyARBcode
	(PatID int, latestAllergyARBcodeDate date, latestAllergyARBcode varchar(512));
insert into #latestAllergyARBcode
		select s.PatID, s.EntryDate, MAX(Rubric) from SIR_ALL_Records as s 
	  		inner join 
	  			(  
				 select PatID, MAX(EntryDate) as codeDate from SIR_ALL_Records
				 where ReadCode in (select code from codeGroups where [group] = 'ARBallergyAdverseReaction') and EntryDate < @refdate
				 and PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
				 group by PatID
	  			) sub on sub.PatID = s.PatID and sub.codeDate = s.EntryDate
		where 
			ReadCode in (select code from codeGroups where [group] = 'ARBallergyAdverseReaction') and
			s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
		group by s.PatID, s.EntryDate

--#latestAllergyCCBcode - i.e. allergy and 'adverse reaction' codes
IF OBJECT_ID('tempdb..#latestAllergyCCBcode') IS NOT NULL DROP TABLE #latestAllergyCCBcode
CREATE TABLE #latestAllergyCCBcode
	(PatID int, latestAllergyCCBcodeDate date, latestAllergyCCBcode varchar(512));
insert into #latestAllergyCCBcode
		select s.PatID, s.EntryDate, MAX(Rubric) from SIR_ALL_Records as s 
	  		inner join 
	  			(  
				 select PatID, MAX(EntryDate) as codeDate from SIR_ALL_Records
				 where ReadCode in (select code from codeGroups where [group] = 'CCBallergyAdverseReaction') and EntryDate < @refdate
				 and PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
				 group by PatID
	  			) sub on sub.PatID = s.PatID and sub.codeDate = s.EntryDate
		where 
			ReadCode in (select code from codeGroups where [group] = 'CCBallergyAdverseReaction') and
			s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
		group by s.PatID, s.EntryDate

--#latestAllergyBBcode - i.e. allergy and 'adverse reaction' codes
IF OBJECT_ID('tempdb..#latestAllergyBBcode') IS NOT NULL DROP TABLE #latestAllergyBBcode
CREATE TABLE #latestAllergyBBcode
	(PatID int, latestAllergyBBcodeDate date, latestAllergyBBcode varchar(512));
insert into #latestAllergyBBcode
	(PatID, latestAllergyBBcodeDate, latestAllergyBBcode)
		select s.PatID, s.EntryDate, MAX(Rubric) from SIR_ALL_Records as s 
	  		inner join 
	  			(  
				 select PatID, MAX(EntryDate) as codeDate from SIR_ALL_Records
				 where ReadCode in (select code from codeGroups where [group] = 'BBallergyAdverseReaction') and EntryDate < @refdate
				 and PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
				 group by PatID
	  			) sub on sub.PatID = s.PatID and sub.codeDate = s.EntryDate
		where 
			ReadCode in (select code from codeGroups where [group] = 'BBallergyAdverseReaction') and
			s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
		group by s.PatID, s.EntryDate

--#latestAllergyPotSpareDiurCode - i.e. allergy and 'adverse reaction' codes
IF OBJECT_ID('tempdb..#latestAllergyPotSpareDiurCode') IS NOT NULL DROP TABLE #latestAllergyPotSpareDiurCode
CREATE TABLE #latestAllergyPotSpareDiurCode
	(PatID int, latestAllergyPotSpareDiurCodeDate date, latestAllergyPotSpareDiurCode varchar(512));
insert into #latestAllergyPotSpareDiurCode
		select s.PatID, s.EntryDate, MAX(Rubric) from SIR_ALL_Records as s 
	  		inner join 
	  			(  
				 select PatID, MAX(EntryDate) as codeDate from SIR_ALL_Records
				 where ReadCode in (select code from codeGroups where [group] = 'PotSparDiurAllergyAdverseReaction') and EntryDate < @refdate
				 and PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
				 group by PatID
	  			) sub on sub.PatID = s.PatID and sub.codeDate = s.EntryDate
		where 
			ReadCode in (select code from codeGroups where [group] = 'PotSparDiurAllergyAdverseReaction') and
			s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
		group by s.PatID, s.EntryDate

--#latestAllergyAlphaCode - i.e. allergy and 'adverse reaction' codes
IF OBJECT_ID('tempdb..#latestAllergyAlphaCode') IS NOT NULL DROP TABLE #latestAllergyAlphaCode
CREATE TABLE #latestAllergyAlphaCode
	(PatID int, latestAllergyAlphaCodeDate date, latestAllergyAlphaCode varchar(512));
insert into #latestAllergyAlphaCode
		select s.PatID, s.EntryDate, MAX(Rubric) from SIR_ALL_Records as s 
	  		inner join 
	  			(  
				 select PatID, MAX(EntryDate) as codeDate from SIR_ALL_Records
				 where ReadCode in (select code from codeGroups where [group] = 'alphaAllergyAdverseReaction') and EntryDate < @refdate
				 and PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
				 group by PatID
	  			) sub on sub.PatID = s.PatID and sub.codeDate = s.EntryDate
		where 
			ReadCode in (select code from codeGroups where [group] = 'alphaAllergyAdverseReaction') and
			s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
		group by s.PatID, s.EntryDate

--#latestAllergyLoopDiurCode - i.e. allergy and 'adverse reaction' codes
IF OBJECT_ID('tempdb..#latestAllergyLoopDiurCode') IS NOT NULL DROP TABLE #latestAllergyLoopDiurCode
CREATE TABLE #latestAllergyLoopDiurCode
	(PatID int, latestAllergyLoopDiurCodeDate date, latestAllergyLoopDiurCode varchar(512));
insert into #latestAllergyLoopDiurCode
		select s.PatID, s.EntryDate, MAX(Rubric) from SIR_ALL_Records as s 
	  		inner join 
	  			(  
				 select PatID, MAX(EntryDate) as codeDate from SIR_ALL_Records
				 where ReadCode in (select code from codeGroups where [group] = 'loopDiurAllergyAdverseReaction') and EntryDate < @refdate
				 and PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
				 group by PatID
	  			) sub on sub.PatID = s.PatID and sub.codeDate = s.EntryDate
		where 
			ReadCode in (select code from codeGroups where [group] = 'loopDiurAllergyAdverseReaction') and
			s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
		group by s.PatID, s.EntryDate

--#latestAddisonsCode
IF OBJECT_ID('tempdb..#latestAddisonsCode') IS NOT NULL DROP TABLE #latestAddisonsCode
CREATE TABLE #latestAddisonsCode
	(PatID int, latestAddisonsCodeDate date, latestAddisonsCode varchar(512));
insert into #latestAddisonsCode
		select s.PatID, s.EntryDate, MAX(Rubric) from SIR_ALL_Records as s 
	  		inner join 
	  			(  
				 select PatID, MAX(EntryDate) as codeDate from SIR_ALL_Records
				 where ReadCode in (select code from codeGroups where [group] = 'addisons') and EntryDate < @refdate
				 and PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
				 group by PatID
	  			) sub on sub.PatID = s.PatID and sub.codeDate = s.EntryDate
		where 
			ReadCode in (select code from codeGroups where [group] = 'addisons') and
			s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
		group by s.PatID, s.EntryDate

--#latestGoutCode
IF OBJECT_ID('tempdb..#latestGoutCode') IS NOT NULL DROP TABLE #latestGoutCode
CREATE TABLE #latestGoutCode
	(PatID int, latestGoutCodeDate date, latestGoutCode varchar(512));
insert into #latestGoutCode
		select s.PatID, s.EntryDate, MAX(Rubric) from SIR_ALL_Records as s 
	  		inner join 
	  			(  
				 select PatID, MAX(EntryDate) as codeDate from SIR_ALL_Records
				 where ReadCode in (select code from codeGroups where [group] = 'gout') and EntryDate < @refdate
				 and PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
				 group by PatID
	  			) sub on sub.PatID = s.PatID and sub.codeDate = s.EntryDate
		where 
			ReadCode in (select code from codeGroups where [group] = 'gout') and
			s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
		group by s.PatID, s.EntryDate

--#latestGoutDrug
IF OBJECT_ID('tempdb..#latestGoutDrug') IS NOT NULL DROP TABLE #latestGoutDrug
CREATE TABLE #latestGoutDrug
	(PatID int, latestGoutDrugDate date, latestGoutDrug varchar(512));
insert into #latestGoutDrug
		select s.PatID, s.EntryDate, MAX(Rubric) from SIR_ALL_Records as s 
	  		inner join 
	  			(  
				 select PatID, MAX(EntryDate) as codeDate from SIR_ALL_Records
				 where ReadCode in (select code from codeGroups where [group] = 'goutDrugs') and EntryDate < @refdate
				 and PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
				 group by PatID
	  			) sub on sub.PatID = s.PatID and sub.codeDate = s.EntryDate
		where 
			ReadCode in (select code from codeGroups where [group] = 'goutDrugs') and
			s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
		group by s.PatID, s.EntryDate

--#latestCalcium i.e. latest calcium blood test result
IF OBJECT_ID('tempdb..#latestCalcium') IS NOT NULL DROP TABLE #latestCalcium
CREATE TABLE #latestCalcium
	(PatID int, latestCalciumDate date, latestCalcium float, latestCalciumSource varchar(512));
insert into #latestCalcium
		select s.PatID, s.EntryDate, MAX(CodeValue), min(Source) from SIR_ALL_Records as s --max calcium on that day
	  		inner join 
	  			(  
				 select PatID, MAX(EntryDate) as codeDate from SIR_ALL_Records
				 where ReadCode in (select code from codeGroups where [group] = 'calcium') and EntryDate < @refdate
				 and PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
				 group by PatID
	  			) sub on sub.PatID = s.PatID and sub.codeDate = s.EntryDate
		where 
			ReadCode in (select code from codeGroups where [group] = 'calcium') and
			s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
		group by s.PatID, s.EntryDate

--#latestSodium i.e. latest sodium blood test result
IF OBJECT_ID('tempdb..#latestSodium') IS NOT NULL DROP TABLE #latestSodium
CREATE TABLE #latestSodium
	(PatID int, latestSodiumDate date, latestSodium float, latestSodiumSource varchar(512));
insert into #latestSodium
		select s.PatID, s.EntryDate, MIN(CodeValue), min(Source) from SIR_ALL_Records as s --min sodium on that day
	  		inner join 
	  			(  
				 select PatID, MAX(EntryDate) as codeDate from SIR_ALL_Records
				 where ReadCode in (select code from codeGroups where [group] = 'sodium') and EntryDate < @refdate
				 and PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
				 group by PatID
	  			) sub on sub.PatID = s.PatID and sub.codeDate = s.EntryDate
		where 
			ReadCode in (select code from codeGroups where [group] = 'sodium') and
			s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
		group by s.PatID, s.EntryDate

--#latestMinPotassium i.e. latest Potassium blood test result
IF OBJECT_ID('tempdb..#latestMinPotassium') IS NOT NULL DROP TABLE #latestMinPotassium
CREATE TABLE #latestMinPotassium
	(PatID int, latestMinPotassiumDate date, latestMinPotassium float, latestMinPotassiumSource varchar(512));
insert into #latestMinPotassium
		select s.PatID, s.EntryDate, MIN(CodeValue), min(Source) from SIR_ALL_Records as s --min Potassium on that day
	  		inner join 
	  			(  
				 select PatID, MAX(EntryDate) as codeDate from SIR_ALL_Records
				 where ReadCode in (select code from codeGroups where [group] = 'potassium') and EntryDate < @refdate
				 and PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
				 group by PatID
	  			) sub on sub.PatID = s.PatID and sub.codeDate = s.EntryDate
		where 
			ReadCode in (select code from codeGroups where [group] = 'potassium') and
			s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
		group by s.PatID, s.EntryDate


--#latestMaxPotassium i.e. latest Potassium blood test result
IF OBJECT_ID('tempdb..#latestMaxPotassium') IS NOT NULL DROP TABLE #latestMaxPotassium
CREATE TABLE #latestMaxPotassium
	(PatID int, latestMaxPotassiumDate date, latestMaxPotassium float, latestMaxPotassiumSource varchar (512));
insert into #latestMaxPotassium
		select s.PatID, s.EntryDate, max(CodeValue), min(Source) from SIR_ALL_Records as s --max Potassium on that day
	  		inner join 
	  			(  
				 select PatID, MAX(EntryDate) as codeDate from SIR_ALL_Records
				 where ReadCode in (select code from codeGroups where [group] = 'potassium') and EntryDate < @refdate
				 and PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
				 group by PatID
	  			) sub on sub.PatID = s.PatID and sub.codeDate = s.EntryDate
		where 
			ReadCode in (select code from codeGroups where [group] = 'potassium') and
			s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
		group by s.PatID, s.EntryDate

--#latestAScode
IF OBJECT_ID('tempdb..#latestAScode') IS NOT NULL DROP TABLE #latestAScode
CREATE TABLE #latestAScode
	(PatID int, latestAScodeDate date, latestAScode varchar(512));
insert into #latestAScode
		select s.PatID, s.EntryDate, MAX(Rubric) from SIR_ALL_Records as s 
	  		inner join 
	  			(  
				 select PatID, MAX(EntryDate) as codeDate from SIR_ALL_Records
				 where ReadCode in (select code from codeGroups where [group] = 'AS') and EntryDate < @refdate
				 and PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
				 group by PatID
	  			) sub on sub.PatID = s.PatID and sub.codeDate = s.EntryDate
		where 
			ReadCode in (select code from codeGroups where [group] = 'AS') and
			s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
		group by s.PatID, s.EntryDate
		
--#latestASrepairCode
IF OBJECT_ID('tempdb..#latestASrepairCode') IS NOT NULL DROP TABLE #latestASrepairCode
CREATE TABLE #latestASrepairCode
	(PatID int, latestASrepairCodeDate date, latestASrepairCode varchar(512));
insert into #latestASrepairCode
		select s.PatID, s.EntryDate, MAX(Rubric) from SIR_ALL_Records as s 
	  		inner join 
	  			(  
				 select PatID, MAX(EntryDate) as codeDate from SIR_ALL_Records
				 where ReadCode in (select code from codeGroups where [group] = 'ASrepair') and EntryDate < @refdate
				 and PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
				 group by PatID
	  			) sub on sub.PatID = s.PatID and sub.codeDate = s.EntryDate
		where 
			ReadCode in (select code from codeGroups where [group] = 'ASrepair') and
			s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
		group by s.PatID, s.EntryDate

--#latestMIcode
IF OBJECT_ID('tempdb..#latestMIcode') IS NOT NULL DROP TABLE #latestMIcode
CREATE TABLE #latestMIcode
	(PatID int, latestMIcodeDate date, latestMIcode varchar(512));
insert into #latestMIcode
		select s.PatID, s.EntryDate, MAX(Rubric) from SIR_ALL_Records as s 
	  		inner join 
	  			(  
				 select PatID, MAX(EntryDate) as codeDate from SIR_ALL_Records
				 where ReadCode in (select code from codeGroups where [group] = 'MInow') and EntryDate < @refdate
				 and PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
				 group by PatID
	  			) sub on sub.PatID = s.PatID and sub.codeDate = s.EntryDate
		where 
			ReadCode in (select code from codeGroups where [group] = 'MInow') and
			s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
		group by s.PatID, s.EntryDate

--#latestPorphyriaCode
IF OBJECT_ID('tempdb..#latestPorphyriaCode') IS NOT NULL DROP TABLE #latestPorphyriaCode
CREATE TABLE #latestPorphyriaCode
	(PatID int, latestPorphyriaCodeDate date, latestPorphyriaCode varchar(512));
insert into #latestPorphyriaCode
		select s.PatID, s.EntryDate, MAX(Rubric) from SIR_ALL_Records as s 
	  		inner join 
	  			(  
				 select PatID, MAX(EntryDate) as codeDate from SIR_ALL_Records
				 where ReadCode in (select code from codeGroups where [group] = 'porphyria') and EntryDate < @refdate
				 and PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
				 group by PatID
	  			) sub on sub.PatID = s.PatID and sub.codeDate = s.EntryDate
		where 
			ReadCode in (select code from codeGroups where [group] = 'porphyria') and
			s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
		group by s.PatID, s.EntryDate

--#latestHeartBlockCode
IF OBJECT_ID('tempdb..#latestHeartBlockCode') IS NOT NULL DROP TABLE #latestHeartBlockCode
CREATE TABLE #latestHeartBlockCode
	(PatID int, latestHeartBlockCodeDate date, latestHeartBlockCode varchar(512));
insert into #latestHeartBlockCode
		select s.PatID, s.EntryDate, MAX(Rubric) from SIR_ALL_Records as s 
	  		inner join 
	  			(  
				 select PatID, MAX(EntryDate) as codeDate from SIR_ALL_Records
				 where ReadCode in (select code from codeGroups where [group] = '2/3heartBlock') and EntryDate < @refdate
				 and PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
				 group by PatID
	  			) sub on sub.PatID = s.PatID and sub.codeDate = s.EntryDate
		where 
			ReadCode in (select code from codeGroups where [group] = '2/3heartBlock') and
			s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
		group by s.PatID, s.EntryDate
		
--#latestSickSinusCode
IF OBJECT_ID('tempdb..#latestSickSinusCode') IS NOT NULL DROP TABLE #latestSickSinusCode
CREATE TABLE #latestSickSinusCode
	(PatID int, latestSickSinusCodeDate date, latestSickSinusCode varchar(512));
insert into #latestSickSinusCode
		select s.PatID, s.EntryDate, MAX(Rubric) from SIR_ALL_Records as s 
	  		inner join 
	  			(  
				 select PatID, MAX(EntryDate) as codeDate from SIR_ALL_Records
				 where ReadCode in (select code from codeGroups where [group] = 'sickSinus') and EntryDate < @refdate
				 and PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
				 group by PatID
	  			) sub on sub.PatID = s.PatID and sub.codeDate = s.EntryDate
		where 
			ReadCode in (select code from codeGroups where [group] = 'sickSinus') and
			s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
		group by s.PatID, s.EntryDate

--#latestPacemakerCode
IF OBJECT_ID('tempdb..#latestPacemakerCode') IS NOT NULL DROP TABLE #latestPacemakerCode
CREATE TABLE #latestPacemakerCode
	(PatID int, latestPacemakerCodeDate date, latestPacemakerCode varchar(512));
insert into #latestPacemakerCode
		select s.PatID, s.EntryDate, MAX(Rubric) from SIR_ALL_Records as s 
	  		inner join 
	  			(  
				 select PatID, MAX(EntryDate) as codeDate from SIR_ALL_Records
				 where ReadCode in (select code from codeGroups where [group] = 'pacemakerDefib') and EntryDate < @refdate
				 and PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
				 group by PatID
	  			) sub on sub.PatID = s.PatID and sub.codeDate = s.EntryDate
		where 
			ReadCode in (select code from codeGroups where [group] = 'pacemakerDefib') and
			s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
		group by s.PatID, s.EntryDate

--#latestPulse
IF OBJECT_ID('tempdb..#latestPulse') IS NOT NULL DROP TABLE #latestPulse
CREATE TABLE #latestPulse
	(PatID int, latestPulseDate date, latestPulseValue int);
insert into #latestPulse
		select s.PatID, s.EntryDate, MIN(CodeValue) from SIR_ALL_Records as s --min pulse on the latest day
	  		inner join 
	  			(  
				 select PatID, MAX(EntryDate) as codeDate from SIR_ALL_Records
				 where ReadCode in (select code from codeGroups where [group] = 'pulseRate') and EntryDate < @refdate
				 and PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
				 group by PatID
	  			) sub on sub.PatID = s.PatID and sub.codeDate = s.EntryDate
		where 
			ReadCode in (select code from codeGroups where [group] = 'pulseRate') and
			s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
		group by s.PatID, s.EntryDate

--#latestAsthmaCode
IF OBJECT_ID('tempdb..#latestAsthmaCode') IS NOT NULL DROP TABLE #latestAsthmaCode
CREATE TABLE #latestAsthmaCode
	(PatID int, latestAsthmaCodeDate date, latestAsthmaCode varchar(512));
insert into #latestAsthmaCode
		select s.PatID, s.EntryDate, MAX(Rubric) from SIR_ALL_Records as s 
	  		inner join 
	  			(  
				 select PatID, MAX(EntryDate) as codeDate from SIR_ALL_Records
				 where ReadCode in (select code from codeGroups where [group] in ('asthmaQof', 'asthmaOther', 'asthmaSpiro', 'asthmaReview', 'asthmaRcp6', 'asthmaDrugs')) and EntryDate < @refdate
				 and PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
				 group by PatID
	  			) sub on sub.PatID = s.PatID and sub.codeDate = s.EntryDate
		where 
			ReadCode in (select code from codeGroups where [group] in ('asthmaQof', 'asthmaOther', 'asthmaSpiro', 'asthmaReview', 'asthmaRcp6', 'asthmaDrugs')) and
			s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
		group by s.PatID, s.EntryDate

--#latestAsthmaPermExCode
IF OBJECT_ID('tempdb..#latestAsthmaPermExCode') IS NOT NULL DROP TABLE #latestAsthmaPermExCode
CREATE TABLE #latestAsthmaPermExCode
	(PatID int, latestAsthmaPermExCodeDate date, latestAsthmaPermExCode varchar(512));
insert into #latestAsthmaPermExCode
		select s.PatID, s.EntryDate, MAX(Rubric) from SIR_ALL_Records as s 
	  		inner join 
	  			(  
				 select PatID, MAX(EntryDate) as codeDate from SIR_ALL_Records
				 where ReadCode in (select code from codeGroups where [group] = 'asthmaPermEx') and EntryDate < @refdate
				 and PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
				 group by PatID
	  			) sub on sub.PatID = s.PatID and sub.codeDate = s.EntryDate
		where 
			ReadCode in (select code from codeGroups where [group] = 'asthmaPermEx') and
			s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
		group by s.PatID, s.EntryDate


--#latestPhaeoCode
IF OBJECT_ID('tempdb..#latestPhaeoCode') IS NOT NULL DROP TABLE #latestPhaeoCode
CREATE TABLE #latestPhaeoCode
	(PatID int, latestPhaeoCodeDate date, latestPhaeoCode varchar(512));
insert into #latestPhaeoCode
	(PatID, latestPhaeoCodeDate, latestPhaeoCode)
		select s.PatID, s.EntryDate, MAX(Rubric) from SIR_ALL_Records as s 
	  		inner join 
	  			(  
				 select PatID, MAX(EntryDate) as codeDate from SIR_ALL_Records
				 where ReadCode in (select code from codeGroups where [group] = 'phaeo') and EntryDate < @refdate
				 and PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
				 group by PatID
	  			) sub on sub.PatID = s.PatID and sub.codeDate = s.EntryDate
		where 
			ReadCode in (select code from codeGroups where [group] = 'phaeo') and
			s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
		group by s.PatID, s.EntryDate
		

--#latestPosturalHypoCode
IF OBJECT_ID('tempdb..#latestPosturalHypoCode') IS NOT NULL DROP TABLE #latestPosturalHypoCode
CREATE TABLE #latestPosturalHypoCode
	(PatID int, latestPosturalHypoCodeDate date, latestPosturalHypoCode varchar(512));
insert into #latestPosturalHypoCode
		select s.PatID, s.EntryDate, MAX(Rubric) from SIR_ALL_Records as s 
	  		inner join 
	  			(  
				 select PatID, MAX(EntryDate) as codeDate from SIR_ALL_Records
				 where ReadCode in (select code from codeGroups where [group] = 'posturalHypo') and EntryDate < @refdate
				 and PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
				 group by PatID
	  			) sub on sub.PatID = s.PatID and sub.codeDate = s.EntryDate
		where 
			ReadCode in (select code from codeGroups where [group] = 'posturalHypo') and
			s.PatID in (select PatID from #eligiblePopulationAllData where denominator = 1 and numerator = 0)
		group by s.PatID, s.EntryDate
		

--#impOppsData
--all data from above combined into one table
IF OBJECT_ID('tempdb..#impOppsData') IS NOT NULL DROP TABLE #impOppsData
CREATE TABLE #impOppsData 
	(PatID int,
		latestPalCodeDate date, latestPalCode varchar(512),
		latestPalPermExCodeDate date, latestPalPermExCode varchar(512), 
		latestFrailCodeDate date, latestFrailCode varchar(512),
		latestHouseBedboundCodeDate date, latestHouseBedboundCode varchar(512), 
		latestHouseBedboundPermExCodeDate date, latestHouseBedboundPermExCode varchar(512),
		latestCkd3rdInviteCodeDate date, latestCkd3rdInviteCode varchar(512), 
		numberOfCkdInviteCodesThisFinancialYear int,
		latestWhiteCoatCodeDate date, latestWhiteCoatCode varchar(512),
		noPrimCareContactInLastYear int,
		secondLatestSbpDate date, secondLatestSbp int,
		secondLatestDbpDate date, secondLatestDbp int,
		secondLatestBpControlled int,
		latestMedOptimisation varchar(512), latestMedOptimisationDate date, latestMedOptimisationIngredient varchar(512), latestMedOptimisationDose float, latestMedOptimisationFamily varchar(512),
		latestMedAdherenceDate date, latestMedAdherenceIngredient varchar(512), latestMedAdherenceDose float, latestMedAdherenceFamily varchar(512),
			
		currentACEI_EventDate date, currentACEI_Ingredient varchar(512), currentACEI_Family varchar(512), currentACEI_Event varchar(512), currentACEI_Dose float, ACEI_MaxDose float, currentACEI_Nos int,
		currentARB_EventDate date, currentARB_Ingredient varchar(512), currentARB_Family varchar(512), currentARB_Event varchar(512), currentARB_Dose float, ARB_MaxDose float, currentARB_Nos int,
		currentCCB_EventDate date, currentCCB_Ingredient varchar(512), currentCCB_Family varchar(512), currentCCB_Event varchar(512), currentCCB_Dose float, CCB_MaxDose float, currentCCB_Nos int,
		currentDIUR_THI_EventDate date, currentDIUR_THI_Ingredient varchar(512), currentDIUR_THI_Family varchar(512), currentDIUR_THI_Event varchar(512), currentDIUR_THI_Dose float, DIUR_THI_MaxDose float, currentDIUR_THI_Nos int,
		currentDIUR_LOOP_EventDate date, currentDIUR_LOOP_Ingredient varchar(512), currentDIUR_LOOP_Family varchar(512), currentDIUR_LOOP_Event varchar(512), currentDIUR_LOOP_Dose float, DIUR_LOOP_MaxDose float, currentDIUR_LOOP_Nos int,
		currentDIUR_POT_EventDate date, currentDIUR_POT_Ingredient varchar(512), currentDIUR_POT_Family varchar(512), currentDIUR_POT_Event varchar(512), currentDIUR_POT_Dose float, DIUR_POT_MaxDose float, currentDIUR_POT_Nos int,
		currentALPHA_EventDate date, currentALPHA_Ingredient varchar(512), currentALPHA_Family varchar(512), currentALPHA_Event varchar(512), currentALPHA_Dose float, ALPHA_MaxDose float, currentALPHA_Nos int,
		currentBB_EventDate date, currentBB_Ingredient varchar(512), currentBB_Family varchar(512), currentBB_Event varchar(512), currentBB_Dose float, BB_MaxDose float, currentBB_Nos int,
				
		latestAllergyThiazideCodeDate date, latestAllergyThiazideCode varchar(512),
		latestAllergyACEIcodeDate date, latestAllergyACEIcode varchar(512),
		latestAllergyARBcodeDate date, latestAllergyARBcode varchar(512),
		latestAllergyCCBcodeDate date, latestAllergyCCBcode varchar(512),
		latestAllergyBBcodeDate date, latestAllergyBBcode varchar(512),
		latestAllergyPotSpareDiurCodeDate date, latestAllergyPotSpareDiurCode varchar(512),
		latestAllergyAlphaCodeDate date, latestAllergyAlphaCode varchar(512),
		latestAllergyLoopDiurCodeDate date, latestAllergyLoopDiurCode varchar(512),
		latestAddisonsCodeDate date, latestAddisonsCode varchar(512),
		latestGoutCodeDate date, latestGoutCode varchar(512),
		latestGoutDrugDate date, latestGoutDrug varchar(512),
		latestCalciumDate date, latestCalcium float, latestCalciumSource varchar(512),
		latestSodiumDate date, latestSodium float, latestSodiumSource varchar(512),
		latestMinPotassiumDate date, latestMinPotassium float, latestMinPotassiumSource varchar(512),
		latestMaxPotassiumDate date, latestMaxPotassium float, latestMaxPotassiumSource varchar (512),
		latestAScodeDate date, latestAScode varchar(512),
		latestASrepairCodeDate date, latestASrepairCode varchar(512),
		latestMIcodeDate date, latestMIcode varchar(512),
		latestPorphyriaCodeDate date, latestPorphyriaCode varchar(512),
		latestHeartBlockCodeDate date, latestHeartBlockCode varchar(512),
		latestSickSinusCodeDate date, latestSickSinusCode varchar(512),
		latestPacemakerCodeDate date, latestPacemakerCode varchar(512),
		latestPulseDate date, latestPulseValue int,
		latestAsthmaCodeDate date, latestAsthmaCode varchar(512),
		latestAsthmaPermExCodeDate date, latestAsthmaPermExCode varchar(512),
		latestPhaeoCodeDate date, latestPhaeoCode varchar(512),
		latestPosturalHypoCodeDate date, latestPosturalHypoCode varchar(512)
	);
insert into #impOppsData
select a.PatID, 
		latestPalCodeDate, latestPalCode,
		latestPalPermExCodeDate, latestPalPermExCode, 
		latestFrailCodeDate, latestFrailCode,
		latestHouseBedboundCodeDate, latestHouseBedboundCode, 
		latestHouseBedboundPermExCodeDate, latestHouseBedboundPermExCode,
		latestCkd3rdInviteCodeDate, latestCkd3rdInviteCode, 
		numberOfCkdInviteCodesThisFinancialYear,
		latestWhiteCoatCodeDate, latestWhiteCoatCode,
		noPrimCareContactInLastYear, 
		secondLatestSbpDate, secondLatestSbp,
		secondLatestDbpDate, secondLatestDbp,
		secondLatestBpControlled,

		latestMedOptimisation, latestMedOptimisationDate, latestMedOptimisationIngredient, latestMedOptimisationDose, latestMedOptimisationFamily,
		latestMedAdherenceDate, latestMedAdherenceIngredient, latestMedAdherenceDose, latestMedAdherenceFamily,
			
		currentACEI_EventDate, currentACEI_Ingredient, currentACEI_Family, currentACEI_Event, currentACEI_Dose, ACEI_MaxDose, currentACEI_Nos,
		currentARB_EventDate, currentARB_Ingredient, currentARB_Family, currentARB_Event, currentARB_Dose, ARB_MaxDose, currentARB_Nos,
		currentCCB_EventDate, currentCCB_Ingredient, currentCCB_Family, currentCCB_Event, currentCCB_Dose, CCB_MaxDose, currentCCB_Nos,
		currentDIUR_THI_EventDate, currentDIUR_THI_Ingredient, currentDIUR_THI_Family, currentDIUR_THI_Event, currentDIUR_THI_Dose, DIUR_THI_MaxDose, currentDIUR_THI_Nos,
		currentDIUR_LOOP_EventDate, currentDIUR_LOOP_Ingredient, currentDIUR_LOOP_Family, currentDIUR_LOOP_Event, currentDIUR_LOOP_Dose, DIUR_LOOP_MaxDose, currentDIUR_LOOP_Nos,
		currentDIUR_POT_EventDate, currentDIUR_POT_Ingredient, currentDIUR_POT_Family, currentDIUR_POT_Event, currentDIUR_POT_Dose, DIUR_POT_MaxDose, currentDIUR_POT_Nos,
		currentALPHA_EventDate, currentALPHA_Ingredient, currentALPHA_Family, currentALPHA_Event, currentALPHA_Dose, ALPHA_MaxDose, currentALPHA_Nos,
		currentBB_EventDate, currentBB_Ingredient, currentBB_Family, currentBB_Event, currentBB_Dose, BB_MaxDose, currentBB_Nos,
				
		latestAllergyThiazideCodeDate, latestAllergyThiazideCode,
		latestAllergyACEIcodeDate, latestAllergyACEIcode,
		latestAllergyARBcodeDate, latestAllergyARBcode,
		latestAllergyCCBcodeDate, latestAllergyCCBcode,
		latestAllergyBBcodeDate, latestAllergyBBcode,
		latestAllergyPotSpareDiurCodeDate, latestAllergyPotSpareDiurCode,
		latestAllergyAlphaCodeDate, latestAllergyAlphaCode,
		latestAllergyLoopDiurCodeDate, latestAllergyLoopDiurCode,
		latestAddisonsCodeDate, latestAddisonsCode,
		latestGoutCodeDate, latestGoutCode,
		latestGoutDrugDate, latestGoutDrug,
		latestCalciumDate, latestCalcium, latestCalciumSource,
		latestSodiumDate, latestSodium, latestSodiumSource,
		latestMinPotassiumDate, latestMinPotassium, latestMinPotassiumSource,
		latestMaxPotassiumDate, latestMaxPotassium, latestMaxPotassiumSource,
		latestAScodeDate, latestAScode,
		latestASrepairCodeDate, latestASrepairCode,
		latestMIcodeDate, latestMIcode,
		latestPorphyriaCodeDate, latestPorphyriaCode,
		latestHeartBlockCodeDate, latestHeartBlockCode,
		latestSickSinusCodeDate, latestSickSinusCode,
		latestPacemakerCodeDate, latestPacemakerCode,
		latestPulseDate, latestPulseValue,
		latestAsthmaCodeDate, latestAsthmaCode,
		latestAsthmaPermExCodeDate, latestAsthmaPermExCode,
		latestPhaeoCodeDate, latestPhaeoCode,
		latestPosturalHypoCodeDate, latestPosturalHypoCode
from #eligiblePopulationAllData as a
		left outer join (select PatID, latestPalCodeDate, latestPalCode from #latestPalCode) b on b.PatID = a.PatID
		left outer join (select PatID, latestPalPermExCodeDate, latestPalPermExCode from #latestPalPermExCode) c on c.PatID = a.PatID
		left outer join (select PatID, latestFrailCodeDate, latestFrailCode from #latestFrailCode) d on d.PatID = a.PatID
		left outer join (select PatID, latestHouseBedboundCodeDate, latestHouseBedboundCode from #latestHouseBedboundCode) e on e.PatID = a.PatID
		left outer join (select PatID, latestHouseBedboundPermExCodeDate, latestHouseBedboundPermExCode from #latestHouseBedboundPermExCode) f on f.PatID = a.PatID
		left outer join (select PatID, latestCkd3rdInviteCodeDate, latestCkd3rdInviteCode from #latestCkd3rdInviteCode) g on g.PatID = a.PatID
		left outer join (select PatID, numberOfCkdInviteCodesThisFinancialYear from #numberOfCkdInviteCodesThisFinancialYear) h on h.PatID = a.PatID
		left outer join (select PatID, latestWhiteCoatCodeDate, latestWhiteCoatCode from #latestWhiteCoatCode) i on i.PatID = a.PatID
		left outer join (select PatID, noPrimCareContactInLastYear from #noPrimCareContactInLastYear) j on j.PatID = a.PatID
		left outer join (select PatID, secondLatestSbpDate, secondLatestSbp from #secondLatestSbp) pp on pp.PatID = a.PatID
		left outer join (select PatID, secondLatestDbpDate, secondLatestDbp from #secondLatestDbp) qq on qq.PatID = a.PatID
		left outer join (select PatID, secondLatestBpControlled from #secondLatestBpControlled) ss on ss.PatID = a.PatID
		left outer join (select PatID, latestMedOptimisation, latestMedOptimisationDate, latestMedOptimisationIngredient, latestMedOptimisationDose, latestMedOptimisationFamily from #latestMedOptimisation) l on l.PatID = a.PatID
		left outer join (select PatID, latestMedAdherenceDate, latestMedAdherenceIngredient, latestMedAdherenceDose, latestMedAdherenceFamily from #latestMedAdherence) m on m.PatID = a.PatID
		left outer join
					(
					select PatID,
						max(case when currentMedFamily='ACEI' then currentMedEventDate else null end) as currentACEI_EventDate,
						max(case when currentMedFamily='ACEI' then currentMedIngredient else null end) as currentACEI_Ingredient,
						max(case when currentMedFamily='ACEI' then currentMedFamily else null end) as currentACEI_Family,
						max(case when currentMedFamily='ACEI' then currentMedEvent else null end) as currentACEI_Event,
						max(case when currentMedFamily='ACEI' then currentMedDose else null end) as currentACEI_Dose,
						max(case when currentMedFamily='ACEI' then currentMedMaxDose else null end) as ACEI_MaxDose,
						max(case when currentMedFamily='ACEI' then noIngredientsInFamily else null end) as currentACEI_Nos,

						max(case when currentMedFamily='ARB' then currentMedEventDate else null end) as currentARB_EventDate,
						max(case when currentMedFamily='ARB' then currentMedIngredient else null end) as currentARB_Ingredient,
						max(case when currentMedFamily='ARB' then currentMedFamily else null end) as currentARB_Family,
						max(case when currentMedFamily='ARB' then currentMedEvent else null end) as currentARB_Event,
						max(case when currentMedFamily='ARB' then currentMedDose else null end) as currentARB_Dose,
						max(case when currentMedFamily='ARB' then currentMedMaxDose else null end) as ARB_MaxDose,
						max(case when currentMedFamily='ARB' then noIngredientsInFamily else null end) as currentARB_Nos,

						max(case when currentMedFamily='CCB' then currentMedEventDate else null end) as currentCCB_EventDate,
						max(case when currentMedFamily='CCB' then currentMedIngredient else null end) as currentCCB_Ingredient,
						max(case when currentMedFamily='CCB' then currentMedFamily else null end) as currentCCB_Family,
						max(case when currentMedFamily='CCB' then currentMedEvent else null end) as currentCCB_Event,
						max(case when currentMedFamily='CCB' then currentMedDose else null end) as currentCCB_Dose,
						max(case when currentMedFamily='CCB' then currentMedMaxDose else null end) as CCB_MaxDose,
						max(case when currentMedFamily='CCB' then noIngredientsInFamily else null end) as currentCCB_Nos,

						max(case when currentMedFamily='DIUR_THI' then currentMedEventDate else null end) as currentDIUR_THI_EventDate,
						max(case when currentMedFamily='DIUR_THI' then currentMedIngredient else null end) as currentDIUR_THI_Ingredient,
						max(case when currentMedFamily='DIUR_THI' then currentMedFamily else null end) as currentDIUR_THI_Family,
						max(case when currentMedFamily='DIUR_THI' then currentMedEvent else null end) as currentDIUR_THI_Event,
						max(case when currentMedFamily='DIUR_THI' then currentMedDose else null end) as currentDIUR_THI_Dose,
						max(case when currentMedFamily='DIUR_THI' then currentMedMaxDose else null end) as DIUR_THI_MaxDose,
						max(case when currentMedFamily='DIUR_THI' then noIngredientsInFamily else null end) as currentDIUR_THI_Nos,

						max(case when currentMedFamily='DIUR_LOOP' then currentMedEventDate else null end) as currentDIUR_LOOP_EventDate,
						max(case when currentMedFamily='DIUR_LOOP' then currentMedIngredient else null end) as currentDIUR_LOOP_Ingredient,
						max(case when currentMedFamily='DIUR_LOOP' then currentMedFamily else null end) as currentDIUR_LOOP_Family,
						max(case when currentMedFamily='DIUR_LOOP' then currentMedEvent else null end) as currentDIUR_LOOP_Event,
						max(case when currentMedFamily='DIUR_LOOP' then currentMedDose else null end) as currentDIUR_LOOP_Dose,
						max(case when currentMedFamily='DIUR_LOOP' then currentMedMaxDose else null end) as DIUR_LOOP_MaxDose,
						max(case when currentMedFamily='DIUR_LOOP' then noIngredientsInFamily else null end) as currentDIUR_LOOP_Nos,

						max(case when currentMedFamily='DIUR_POT' then currentMedEventDate else null end) as currentDIUR_POT_EventDate,
						max(case when currentMedFamily='DIUR_POT' then currentMedIngredient else null end) as currentDIUR_POT_Ingredient,
						max(case when currentMedFamily='DIUR_POT' then currentMedFamily else null end) as currentDIUR_POT_Family,
						max(case when currentMedFamily='DIUR_POT' then currentMedEvent else null end) as currentDIUR_POT_Event,
						max(case when currentMedFamily='DIUR_POT' then currentMedDose else null end) as currentDIUR_POT_Dose,
						max(case when currentMedFamily='DIUR_POT' then currentMedMaxDose else null end) as DIUR_POT_MaxDose,
						max(case when currentMedFamily='DIUR_POT' then noIngredientsInFamily else null end) as currentDIUR_POT_Nos,

						max(case when currentMedFamily='ALPHA' then currentMedEventDate else null end) as currentALPHA_EventDate,
						max(case when currentMedFamily='ALPHA' then currentMedIngredient else null end) as currentALPHA_Ingredient,
						max(case when currentMedFamily='ALPHA' then currentMedFamily else null end) as currentALPHA_Family,
						max(case when currentMedFamily='ALPHA' then currentMedEvent else null end) as currentALPHA_Event,
						max(case when currentMedFamily='ALPHA' then currentMedDose else null end) as currentALPHA_Dose,
						max(case when currentMedFamily='ALPHA' then currentMedMaxDose else null end) as ALPHA_MaxDose,
						max(case when currentMedFamily='ALPHA' then noIngredientsInFamily else null end) as currentALPHA_Nos,

						max(case when currentMedFamily='BB' then currentMedEventDate else null end) as currentBB_EventDate,
						max(case when currentMedFamily='BB' then currentMedIngredient else null end) as currentBB_Ingredient,
						max(case when currentMedFamily='BB' then currentMedFamily else null end) as currentBB_Family,
						max(case when currentMedFamily='BB' then currentMedEvent else null end) as currentBB_Event,
						max(case when currentMedFamily='BB' then currentMedDose else null end) as currentBB_Dose,
						max(case when currentMedFamily='BB' then currentMedMaxDose else null end) as BB_MaxDose,
						max(case when currentMedFamily='BB' then noIngredientsInFamily else null end) as currentBB_Nos
						from #htnMeds group by PatID
					) n on n.PatID = a.PatID
		left outer join (select PatID, latestAllergyThiazideCodeDate, latestAllergyThiazideCode from #latestAllergyThiazideCode) o on o.PatID = a.PatID
		left outer join (select PatID, latestAllergyACEIcodeDate, latestAllergyACEIcode from #latestAllergyACEIcode) p on p.PatID = a.PatID
		left outer join (select PatID, latestAllergyARBcodeDate, latestAllergyARBcode from #latestAllergyARBcode) q on q.PatID = a.PatID
		left outer join (select PatID, latestAllergyCCBcodeDate, latestAllergyCCBcode  from #latestAllergyCCBcode) r on r.PatID = a.PatID
		left outer join (select PatID, latestAllergyBBcodeDate, latestAllergyBBcode from #latestAllergyBBcode) s on s.PatID = a.PatID
		left outer join (select PatID, latestAllergyPotSpareDiurCodeDate, latestAllergyPotSpareDiurCode from #latestAllergyPotSpareDiurCode) t on t.PatID = a.PatID
		left outer join (select PatID, latestAllergyAlphaCodeDate, latestAllergyAlphaCode from #latestAllergyAlphaCode) u on u.PatID = a.PatID
		left outer join (select PatID, latestAllergyLoopDiurCodeDate, latestAllergyLoopDiurCode from #latestAllergyLoopDiurCode) v on v.PatID = a.PatID
		left outer join (select PatID, latestAddisonsCodeDate, latestAddisonsCode from #latestAddisonsCode) w on w.PatID = a.PatID
		left outer join (select PatID, latestGoutCodeDate, latestGoutCode  from #latestGoutCode) x on x.PatID = a.PatID
		left outer join (select PatID, latestGoutDrugDate, latestGoutDrug  from #latestGoutDrug) y on y.PatID = a.PatID
		left outer join (select PatID, latestCalciumDate, latestCalcium, latestCalciumSource  from #latestCalcium) z on z.PatID = a.PatID
		left outer join (select PatID, latestSodiumDate, latestSodium, latestSodiumSource from #latestSodium) aa on aa.PatID = a.PatID
		left outer join (select PatID, latestMinPotassiumDate, latestMinPotassium, latestMinPotassiumSource from #latestMinPotassium) bb on bb.PatID = a.PatID
		left outer join (select PatID, latestMaxPotassiumDate, latestMaxPotassium, latestMaxPotassiumSource from #latestMaxPotassium) cc on cc.PatID = a.PatID
		left outer join (select PatID, latestAScodeDate, latestAScode from #latestAScode) dd on dd.PatID = a.PatID
		left outer join (select PatID, latestASrepairCodeDate, latestASrepairCode from #latestASrepairCode) ee on ee.PatID = a.PatID
		left outer join (select PatID, latestMIcodeDate, latestMIcode from #latestMIcode) ff on ff.PatID = a.PatID
		left outer join (select PatID, latestPorphyriaCodeDate, latestPorphyriaCode from #latestPorphyriaCode) gg on gg.PatID = a.PatID
		left outer join (select PatID, latestHeartBlockCodeDate, latestHeartBlockCode from #latestHeartBlockCode) hh on hh.PatID = a.PatID
		left outer join (select PatID, latestSickSinusCodeDate, latestSickSinusCode from #latestSickSinusCode) ii on ii.PatID = a.PatID
		left outer join (select PatID, latestPacemakerCodeDate, latestPacemakerCode from #latestPacemakerCode) jj on jj.PatID = a.PatID
		left outer join (select PatID, latestPulseDate, latestPulseValue from #latestPulse) kk on kk.PatID = a.PatID
		left outer join (select PatID, latestAsthmaCodeDate, latestAsthmaCode from #latestAsthmaCode) ll on ll.PatID = a.PatID
		left outer join (select PatID, latestAsthmaPermExCodeDate, latestAsthmaPermExCode from #latestAsthmaPermExCode) mm on mm.PatID = a.PatID
		left outer join (select PatID, latestPhaeoCodeDate, latestPhaeoCode from #latestPhaeoCode) nn on nn.PatID = a.PatID
		left outer join (select PatID, latestPosturalHypoCodeDate, latestPosturalHypoCode from #latestPosturalHypoCode) oo on oo.PatID = a.PatID
where denominator = 1 and numerator = 0

							---------------------------------------------------------------
							-------------------MEDICATION SUGGESTIONS----------------------
							---------------------------------------------------------------


IF OBJECT_ID('tempdb..#medSuggestion') IS NOT NULL DROP TABLE #medSuggestion
CREATE TABLE #medSuggestion
	(PatID int, family varchar(max), start_or_inc varchar(12), reasonText varchar(max), reasonNumber int, priority int);
insert into #medSuggestion

--1st line: start ACEI
select distinct a.PatID, 
	'ACE inhibitor (e.g. <a href="http://dx.doi.org/10.18578/BNF.437242180" title="BNF" target="_blank">lisonopril 5mg or 10mg</a>)' as family, 
	'Start' as start_or_inc,
	 case 
		when 
			(
			a.PatID not in (select PatID from #htnMeds) 
			and (age < 55 or (dmPatient = 1 or protPatient = 1)) --no HTN meds and under 55 / DM or proteinuria
			) then 
			'<ul><li>Patient is not prescribed anti-hypertensive medication' +
				(case when age < 55 then ' and is < 55 years old' else '' end) +
				(case when dmPatient = 1 then ' and has diabetes' else '' end) + 
				(case when protPatient = 1 then ' and has an ACR > 70' else '' end) + '.</li>' +
			'<li>NICE recommends an ACE inhibitor first-line (patient has no documented allergies or contra-indications).</li></ul>'
		when (currentMedFamily not in ('CCB', 'ACEI', 'ARB')) then
			'<ul><li>Patient is on anti-hypertensive medication but not an ACE Inhibitor (or ARB) or a Calcium Channel Blocker.</li>' +
			'<li>NICE recommends an ACE Inhibitor (patient has no documented allergies or contra-indications) or a Calcium Channel Blocker.</li></ul>'
		when (currentMedFamily not in ('ACEI', 'ARB') and currentMedFamily = 'CCB') then
			'<ul><li>Patient is on anti-hypertensive medication (including a Calcium Channel Blocker) but not an ACE Inhibitor or ARB.</li>' +
			'<li>NICE recommends an ACE Inhibitor (patient has no documented allergies or contra-indications).</li></ul>'
		when (a.PatID not in (select PatID from #htnMeds) and age > 54) and ((latestAllergyCCBcode is not null or latestAScode is not null or (latestMIcodeDate is not null or latestMIcodeDate > DATEADD(month, -1, @refdate)) or latestPorphyriaCode is not null)) then --indication for CCB but CI present
			'<ul><li>Patient is not currently prescribed anti-hypertensive medication and is 55 years old or older.</li>' +
			'<li>NICE recommends a Calcium Channel Blocker first-line.</li>' +
			'<li><strong>But</strong> there is a documented contraindication, so an ACE Inhibitor is preferred.</li></ul>'
	end as reasonText,
		(case when age < 55 then 1 else 0 end) + (case when dmPatient = 1 then 1 else 0 end) + (case when protPatient = 1 then 1 else 0 end) as reasonNumber,
		2 as priority
from #impOppsData as a
	left outer join (select PatID, currentMedFamily from #htnMeds) as b on b.PatID = a.PatID
	left outer join (select PatID, dmPatient, protPatient, age from #eligiblePopulationAllData) as c on c.PatID = a.PatID
where
	a.PatID in (select PatID from #eligiblePopulationAllData where bpMeasuredOK = 1 and bpControlledOk = 0)
	and
	(
		(
			a.PatID not in (select PatID from #htnMeds) 
			and (age < 55 or (dmPatient = 1 or protPatient = 1)) --no HTN meds and under 55 / DM or proteinuria
		) 
		or
		(currentMedFamily not in ('ACEI', 'ARB')) --on HTN meds BUT not ACEI or ARB
		or
		((a.PatID not in (select PatID from #htnMeds) and age > 54) and ((latestAllergyCCBcode is not null and latestAScode is not null and (latestMIcodeDate is not null or latestMIcodeDate > DATEADD(month, -1, @refdate)) and latestPorphyriaCode is not null))) --indication for CCB but CI present
	)
		and (latestAllergyACEIcode is null and latestMaxPotassium < 5.1) --no CIs: http://cks.nice.org.uk/chronic-kidney-disease-not-diabetic#!prescribinginfosub

union

--1st line (alternative): start ARB
select distinct a.PatID, 
	'ARB (e.g. <a href="http://dx.doi.org/10.18578/BNF.958956352" title="BNF" target="_blank">losartan 25mg or 50mg</a>)' as family, 
	'Start' as start_or_inc,
	 case
		when 
			(
			a.PatID not in (select PatID from #htnMeds) 
			and (age < 55 or (dmPatient = 1 or protPatient = 1)) --no HTN meds and under 55 / DM or proteinuria
			) then 
			'<ul><li>Patient is not prescribed anti-hypertensive medication' +
				(case when age < 55 then ' and is < 55 years old' else '' end) +
				(case when dmPatient = 1 then ' and has diabetes' else '' end) + 
				(case when protPatient = 1 then ' and has an ACR > 70' else '' end) + '.</li>' +
			'<li>NICE recommends an ACE inhibitor first-line <strong>but</strong> there is a documented contraindication on ' +  CONVERT(VARCHAR, latestAllergyACEIcodeDate, 3) + ', so an ARB is preferred.</li></ul>'
		when (currentMedFamily not in ('CCB', 'ACEI', 'ARB')) then
			'<ul><li>Patient is on anti-hypertensive medication but not an ACE Inhibitor (or ARB) or a Calcium Channel Blocker.</li>' +
			'<li>NICE recommends an ACE Inhibitor or a Calcium Channel Blocker.</li>' +
			'<li><strong>But</strong> there is a documented contraindication to ACE Inhibitors on ' +  CONVERT(VARCHAR, latestAllergyACEIcodeDate, 3) + ', so an ARB is preferred.</li>'
		when (currentMedFamily not in ('ACEI', 'ARB') and currentMedFamily = 'CCB') then
			'<ul><li>Patient is on anti-hypertensive medication (including a Calcium Channel Blocker) but not an ACE Inhibitor (or ARB).</li>' +
			'<li>NICE recommends an ACE Inhibitor.</li>' +
			'<li><strong>But</strong> there is a documented contraindication to ACE Inhibitors on ' +  CONVERT(VARCHAR, latestAllergyACEIcodeDate, 3) + ', so an ARB is preferred.</li>'
		when (a.PatID not in (select PatID from #htnMeds) and age > 54) and ((latestAllergyCCBcode is not null or latestAScode is not null or (latestMIcodeDate is not null or latestMIcodeDate > DATEADD(month, -1, @refdate)) or latestPorphyriaCode is not null)) then --indication for CCB but CI present
			'<ul><li>Patient is not currently prescribed anti-hypertensive medication and is 55 years old or older.</li>' +
			'<li>NICE recommends a Calcium Channel Blocker first-line.</li>' +
			'<li><strong>But</strong> there is a documented contraindication to both CCBs and ACE inhibitors, so an ARB is preferred.</li></ul>'
		end as reasonText,
		(case when age < 55 then 1 else 0 end) + (case when dmPatient = 1 then 1 else 0 end) + (case when protPatient = 1 then 1 else 0 end) as reasonNumber,
		3 as priority
from #impOppsData as a
	left outer join (select PatID, currentMedFamily from #htnMeds) as b on b.PatID = a.PatID
	left outer join (select PatID, dmPatient, protPatient, age from #eligiblePopulationAllData) as c on c.PatID = a.PatID
where
	a.PatID in (select PatID from #eligiblePopulationAllData where bpMeasuredOK = 1 and bpControlledOk = 0)
	and
	(
		(a.PatID not in (select PatID from #htnMeds) and age < 55) --no HTN meds and under 55
		or
		(currentMedFamily not in ('ACEI', 'ARB')) --on HTN meds BUT not ACEI or ARB
		or
		(a.PatID not in (select PatID from #htnMeds) and age > 54) and ((latestAllergyCCBcode is not null or latestAScode is not null or (latestMIcodeDate is not null or latestMIcodeDate > DATEADD(month, -1, @refdate)) or latestPorphyriaCode is not null)) --indication for CCB but CI present
	)
		and (latestAllergyACEIcode is not null) --allergy to ACEI 
		and (latestAllergyARBcode is null and latestMaxPotassium < 5.1) --no CIs to ARBs: http://cks.nice.org.uk/chronic-kidney-disease-not-diabetic#!prescribinginfosub

union

--1st line (also): start CCB
select distinct a.PatID, 
	'Calcium Channel Blocker (e.g. <a href="http://dx.doi.org/10.18578/BNF.109201061" title="BNF" target="_blank">amlodipine 5mg</a>)' as family, 
	'Start' as start_or_inc,
	 case 
		when (a.PatID not in (select PatID from #htnMeds) and age > 54) then 
			'<ul><li>Patient is not prescribed anti-hypertensive medication and is 55 years old or older.</li>' +
			'<li>NICE recommends a Calcium Channel Blocker  first-line (patient has no documented allergies or contra-indications).</li></ul>'
		when (currentMedFamily not in ('CCB', 'ACEI', 'ARB')) then
			'<ul><li>Patient is on anti-hypertensive medication but not a Calcium Channel Blocker or ACE Inhibitor (or ARB).</li>' +
			'<li>NICE recommends a Calcium Channel Blocker (patient has no documented allergies or contra-indications) or ACE Inhibitor.</li></ul>'
		when (currentMedFamily != 'CCB' and currentMedFamily in ('ACEI', 'ARB')) then
			'<ul><li>Patient is on anti-hypertensive medication (including an ACE Inhibitor or ARB) but not a Calcium Channel Blocker.</li>' +
			'<li>NICE recommends a Calcium Channel Blocker (patient has no documented allergies or contra-indications).</li></ul>'
		when (a.PatID not in (select PatID from #htnMeds) and age < 55) and ((latestAllergyACEIcode is not null and latestAllergyARBcode is not null) or latestMaxPotassium > 5.0) then 
			'<ul><li>Patient is not currently prescribed anti-hypertensive medication and is < 55 years old.</li>' +
			'<li>NICE recommends an ACE inhibitor first-line <strong>but</strong> there is a documented contraindication (' +
				(case 
					when latestAllergyACEIcode is not null then latestAllergyACEIcode + 'on' + CONVERT(VARCHAR, latestAllergyACEIcodeDate, 3)
					when latestAllergyACEIcode is null and latestMaxPotassium > 5.0 then 'potassium ' + STR(latestMaxPotassium) + 'on' + CONVERT(VARCHAR, latestMaxPotassiumDate, 3)
				end) +
			') and ARBs (' + 
				(case 
					when latestAllergyARBcode is not null then latestAllergyARBcode + 'on' + CONVERT(VARCHAR, latestAllergyARBcodeDate, 3)  
					when latestAllergyARBcode is null and latestMaxPotassium > 5.0 then 'potassium ' + STR(latestMaxPotassium) + 'on' + CONVERT(VARCHAR, latestMaxPotassiumDate, 3)
				end) +
			'), so a CCB is preferred.</li></ul>'
		end as reasonText,
		1 as reasonNumber,
		3 as priority
from #impOppsData as a
	left outer join (select PatID, currentMedFamily from #htnMeds) as b on b.PatID = a.PatID
	left outer join (select PatID, bpMeasuredOK, bpControlledOk, age from #eligiblePopulationAllData) as c on c.PatID = a.PatID
where
	a.PatID in (select PatID from #eligiblePopulationAllData where bpMeasuredOK = 1 and bpControlledOk = 0)
	and
	(
		(a.PatID not in (select PatID from #htnMeds) and age > 54) --no HTN meds and > 54
		or
		(currentMedFamily != 'CCB') --on HTN meds BUT not CCB
		or
		(a.PatID not in (select PatID from #htnMeds) and age < 55) and ((latestAllergyACEIcode is not null and latestAllergyARBcode is not null) or latestMaxPotassium > 5.0) --indication for ACE I, but CIs to both ACEI and ARBs
	)
		and (latestAllergyCCBcode is null and latestAScode is null and (latestMIcodeDate is null or latestMIcodeDate < DATEADD(month, -1, @refdate)) and latestPorphyriaCode is null) --no CIs

union

--2nd line: start thiazide
select distinct a.PatID, 
	'Indapamide (e.g. <a href="http://dx.doi.org/10.18578/BNF.748067014" title="BNF" target="_blank">2.5mg</a>)' as family, 
	'Start' as start_or_inc,
	 case
		when (currentMedFamily in ('ACEI', 'ARB') and currentMedFamily = 'CCB') then
			'<ul><li>Patient is prescribed an ACE Inhibitor (or ARB) and a Calcium Channel Blocker.</li>' +
			'<li>NICE recommends starting Indapamide (patient has no documented allergies or contra-indications).</li></ul>'
		when (currentMedFamily in ('ACEI', 'ARB') and (latestAllergyCCBcode is not null or latestAScode is not null or (latestMIcodeDate is not null or latestMIcodeDate > DATEADD(month, -1, @refdate)) or latestPorphyriaCode is not null)) then
			'<ul><li>Patient is prescribed an ACE Inhibitor (or ARB) and there is a documented contraindication to Calcium Channel Blockers' +
				case 
					when latestAllergyCCBcode is not null then '(' + latestAllergyCCBcode + 'on' + CONVERT(VARCHAR, latestAllergyCCBcodeDate, 3) +')'
					when latestAllergyCCBcode is null then ''
				end +
			', so Indapamide is preferred.</li></ul>'
		when (currentMedFamily in ('CCB') and  ((latestAllergyACEIcode is not null and latestAllergyARBcode is not null) or latestMaxPotassium > 5.0)) then
			'<ul><li>Patient is prescribed a Calcium Channel Blocker and there are documented contraindications to both ACE Inhibitors (' +
				(case 
					when latestAllergyACEIcode is not null then latestAllergyACEIcode + 'on' + CONVERT(VARCHAR, latestAllergyACEIcodeDate, 3)
					when latestAllergyACEIcode is null and latestMaxPotassium > 5.0 then 'potassium ' + STR(latestMaxPotassium) + 'on' + CONVERT(VARCHAR, latestMaxPotassiumDate, 3)
				end )+
			') and ARBs (' + 
				(case 
					when latestAllergyARBcode is not null then latestAllergyARBcode + 'on' + CONVERT(VARCHAR, latestAllergyARBcodeDate, 3)  
					when latestAllergyARBcode is null and latestMaxPotassium > 5.0 then 'potassium ' + STR(latestMaxPotassium) + 'on' + CONVERT(VARCHAR, latestMaxPotassiumDate, 3)
				end) +
			'), so Indapamide is preferred.</li></ul>'
		when (a.PatID not in (select PatID from #htnMeds) and ((latestAllergyACEIcode is not null and latestAllergyARBcode is not null) or latestMaxPotassium > 5.0) and (latestAllergyCCBcode is not null or latestAScode is not null or (latestMIcodeDate is not null or latestMIcodeDate > DATEADD(month, -1, @refdate)) or latestPorphyriaCode is not null)) then
			'<ul><li>Patient is not prescribed anti-hypertensive medication.</li>' +
			'<li><strong>But</strong> there are contra-indications to ACE Inhibitors (' +
				(case 
					when latestAllergyACEIcode is not null then latestAllergyACEIcode + 'on' + CONVERT(VARCHAR, latestAllergyACEIcodeDate, 3)
					when latestAllergyACEIcode is null and latestMaxPotassium > 5.0 then 'potassium ' + STR(latestMaxPotassium) + 'on' + CONVERT(VARCHAR, latestMaxPotassiumDate, 3)
				end) +
			') and ARBs (' + 
				(case 
					when latestAllergyARBcode is not null then latestAllergyARBcode + 'on' + CONVERT(VARCHAR, latestAllergyARBcodeDate, 3)  
					when latestAllergyARBcode is null and latestMaxPotassium > 5.0 then 'potassium ' + STR(latestMaxPotassium) + 'on' + CONVERT(VARCHAR, latestMaxPotassiumDate, 3)
				end) +
			') and CCBs' +
				(case 
					when latestAllergyCCBcode is not null then '(' + latestAllergyCCBcode + 'on' + CONVERT(VARCHAR, latestAllergyCCBcodeDate, 3) +')'
					when latestAllergyCCBcode is null then ''
				end) +
			', so Indapamide is preferred.</li></ul>'
	end as reasonText,
	1 as reasonNumber,
	3 as priority
from #impOppsData as a
	left outer join (select PatID, currentMedFamily from #htnMeds) as b on b.PatID = a.PatID
where
	a.PatID in (select PatID from #eligiblePopulationAllData where bpMeasuredOK = 1 and bpControlledOk = 0)
	and
	(	--at stage 2 (i.e. on an ACEI or ARB, and on a CCB)
		(currentMedFamily in ('ACEI', 'ARB') and currentMedFamily = 'CCB') 
		or --on ACEI / ARB but CI to CCB
		(currentMedFamily in ('ACEI', 'ARB') and (latestAllergyCCBcode is not null or latestAScode is not null or (latestMIcodeDate is not null or latestMIcodeDate > DATEADD(month, -1, @refdate)) or latestPorphyriaCode is not null))
		or --on CCB but CI to both ACEI and ARB
		(currentMedFamily in ('CCB') and  ((latestAllergyACEIcode is not null and latestAllergyARBcode is not null) or latestMaxPotassium > 5.0))
		or --not on htn meds but CI to CCB, ACEI and ARB
		(a.PatID not in (select PatID from #htnMeds) and ((latestAllergyACEIcode is not null and latestAllergyARBcode is not null) or latestMaxPotassium > 5.0) and (latestAllergyCCBcode is not null or latestAScode is not null or (latestMIcodeDate is not null or latestMIcodeDate > DATEADD(month, -1, @refdate)) or latestPorphyriaCode is not null))
	)
	and (currentMedFamily not in ('DIUR_THI', 'DIUR_LOOP')) --not already on a thiazide or loop diuretic
	and (latestAllergyThiazideCode is null and latestCalcium < 3 and latestSodium > 130 and latestGoutCode is null) --no CIs

union

--3rd line: spironolactone, alpha, or beta
select distinct a.PatID, 
	case 
		when currentMedFamily !='DIUR_POT' and latestAllergyPotSpareDiurCode is null and latestMaxPotassium < 4.6 and latestAddisonsCode is null then 'Spironolactone (e.g. <a http://dx.doi.org/10.18578/BNF.213718345" title="Spironolactone BNF" target="_blank">25mg</a>)' 
		when currentMedFamily !='ALPHA' and latestAllergyAlphaCode is null and latestPosturalHypoCode is null then 'Alpha Blocker (e.g. <a http://dx.doi.org/10.18578/BNF.782101311" title="Doxazosin BNF" target="_blank" >Doxazosin 1mg</a>)'
		when currentMedFamily !='BB' and latestAllergyBBcode is null and latestAsthmaCode is null and latestPulseValue > 45 and latestPhaeoCode is null and latestHeartBlockCodeDate is null and latestSickSinusCodeDate is null then 'Beta Blocker (e.g. <a http://dx.doi.org/10.18578/BNF.281805035" title="BNF" target="_blank">Bisoprolol 5mg</a>)'
	end as family, 
	'Start' as start_or_inc, 
	case
		when (currentMedFamily in ('ACEI', 'ARB') and currentMedFamily = 'CCB' and currentMedFamily = 'DIUR_THI') then
			'<ul><li>Patient is prescribed an ACE Inhibitor (or ARB), Calcium Channel Blocker, and Thiazide-type Diuretic.</li>'
		when (currentMedFamily in ('ACEI', 'ARB') and currentMedFamily = 'CCB')
			and (latestAllergyThiazideCode is not null or latestCalcium > 2.9 or latestSodium < 130 or latestGoutCode is not null) then
			'<ul><li>Patient is prescribed an ACE Inhibitor (or ARB) and Calcium Channel Blocker has a contraindication to Thiazide-type diuretics (' +
				(case when latestAllergyThiazideCode is not null then latestAllergyThiazideCode + ' on ' + CONVERT(VARCHAR, latestAllergyThiazideCodeDate, 3) + '; ' else '' end) +
				(case when latestCalcium >2.9 then 'latest calcium ' +  Str(latestCalcium, 3, 0) + ' on ' + CONVERT(VARCHAR, latestCalciumDate, 3) + '; ' else '' end) +
				(case when latestSodium < 130 then 'latest sodium ' +  Str(latestSodium, 3, 0) + ' on ' + CONVERT(VARCHAR, latestSodiumDate, 3) + '; ' else '' end) +
				(case when latestGoutCode is not null then latestGoutCode + ' on ' + CONVERT(VARCHAR, latestGoutCodeDate, 3) + '; ' else '' end) +
			').</li>'
		when (currentMedFamily in ('ACEI', 'ARB')) 
			and (latestAllergyCCBcode is not null or latestAScode is not null or (latestMIcodeDate is not null or latestMIcodeDate > DATEADD(month, -1, @refdate)) or latestPorphyriaCode is not null) 
			and (latestAllergyThiazideCode is not null or latestCalcium > 2.9 or latestSodium < 130 or latestGoutCode is not null) then
			'<ul><li>Patient is prescribed an ACE Inhibitor (or ARB) and has contraindications to Calcium Channel Blockers (' +
				(case when latestAllergyCCBcode is not null then latestAllergyCCBcode + ' on ' + CONVERT(VARCHAR, latestAllergyCCBcodeDate, 3) + '; ' else '' end) +
				(case when latestAScode is not null then latestAScode + ' on ' + CONVERT(VARCHAR, latestAScodeDate, 3) + '; ' else '' end) +
				(case when latestMIcode is not null then latestMIcode + ' on ' + CONVERT(VARCHAR, latestMIcodeDate, 3) + '; ' else '' end) +
				(case when latestMIcodeDate > DATEADD(month, -1, @refdate) then latestMIcode + ' on ' + CONVERT(VARCHAR, latestMIcodeDate, 3) + '; ' else '' end) +
				(case when latestPorphyriaCode is not null then latestPorphyriaCode + ' on ' + CONVERT(VARCHAR, latestPorphyriaCodeDate, 3) + '; ' else '' end) +
			') and Thiazide-type Diuretics (' +
				(case when latestAllergyThiazideCode is not null then latestAllergyThiazideCode + ' on ' + CONVERT(VARCHAR, latestAllergyThiazideCodeDate, 3) + '; ' else '' end) +
				(case when latestCalcium >2.9 then 'latest calcium ' +  Str(latestCalcium, 3, 0) + ' on ' + CONVERT(VARCHAR, latestCalciumDate, 3) + '; ' else '' end) +
				(case when latestSodium < 130 then 'latest sodium ' +  Str(latestSodium, 3, 0) + ' on ' + CONVERT(VARCHAR, latestSodiumDate, 3) + '; ' else '' end) +
				(case when latestGoutCode is not null then latestGoutCode + ' on ' + CONVERT(VARCHAR, latestGoutCodeDate, 3) + '; ' else '' end) +
			').</li>'
		when (currentMedFamily in ('ACEI', 'ARB') and currentMedFamily = 'DIUR_THI') 
			and (latestAllergyCCBcode is not null or latestAScode is not null or (latestMIcodeDate is not null or latestMIcodeDate > DATEADD(month, -1, @refdate)) or latestPorphyriaCode is not null) then
			'<ul><li>Patient is prescribed an ACE Inhibitor (or ARB) and Thiazide-type Diuretic, but has contraindications to Calcium Channel Blockers (' +
				(case when latestAllergyCCBcode is not null then latestAllergyCCBcode + ' on ' + CONVERT(VARCHAR, latestAllergyCCBcodeDate, 3) + '; ' else '' end) +
				(case when latestAScode is not null then latestAScode + ' on ' + CONVERT(VARCHAR, latestAScodeDate, 3) + '; ' else '' end) +
				(case when latestMIcode is not null then latestMIcode + ' on ' + CONVERT(VARCHAR, latestMIcodeDate, 3) + '; ' else '' end) +
				(case when latestMIcodeDate > DATEADD(month, -1, @refdate) then latestMIcode + ' on ' + CONVERT(VARCHAR, latestMIcodeDate, 3) + '; ' else '' end) +
				(case when latestPorphyriaCode is not null then latestPorphyriaCode + ' on ' + CONVERT(VARCHAR, latestPorphyriaCodeDate, 3) + '; ' else '' end) +
			').</li>'
		when (currentMedFamily = 'CCB' and currentMedFamily = 'DIUR_THI')
			and ((latestAllergyACEIcode is not null and latestAllergyARBcode is not null) or latestMaxPotassium > 5.0) then
			'<ul><li>Patient is prescribed a Calcium Channel Blocker and Thiazide-type Diuretic, but has contraindications to ACE Inhibitors and ARBs (' +
				(case when latestAllergyACEIcode is not null then latestAllergyACEIcode + ' on ' + CONVERT(VARCHAR, latestAllergyACEIcodeDate, 3) + '; ' else '' end) +
				(case when latestAllergyARBcode is not null then latestAllergyARBcode + ' on ' + CONVERT(VARCHAR, latestAllergyARBcodeDate, 3) + '; ' else '' end) +
				(case when latestMaxPotassium > 5.0 then 'latest potassium ' +  Str(latestMaxPotassium, 3, 0) + ' on ' + CONVERT(VARCHAR, latestMaxPotassiumDate, 3) + '; ' else '' end) +
			').</li>'
		when (currentMedFamily = 'CCB') 
			and (latestAllergyThiazideCode is not null or latestCalcium > 2.9 or latestSodium < 130 or latestGoutCode is not null)
			and ((latestAllergyACEIcode is not null and latestAllergyARBcode is not null) or latestMaxPotassium > 5.0) then
			'<ul><li>Patient is prescribed a Calcium Channel Blocker but has contraindications to Thiazide-type Diuretics (' +
				(case when latestAllergyThiazideCode is not null then latestAllergyThiazideCode + ' on ' + CONVERT(VARCHAR, latestAllergyThiazideCodeDate, 3) + '; ' else '' end) +
				(case when latestCalcium > 2.9 then 'latest calcium ' +  Str(latestCalcium, 3, 0) + ' on ' + CONVERT(VARCHAR, latestCalciumDate, 3) + '; ' else '' end) +
				(case when latestSodium < 130 then 'latest sodium ' +  Str(latestSodium, 3, 0) + ' on ' + CONVERT(VARCHAR, latestSodiumDate, 3) + '; ' else '' end) +
				(case when latestGoutCode is not null then latestGoutCode + ' on ' + CONVERT(VARCHAR, latestGoutCodeDate, 3) + '; ' else '' end) +
			') and ACE Inhibitors and ARBs (' +
				(case when latestAllergyACEIcode is not null then latestAllergyACEIcode + ' on ' + CONVERT(VARCHAR, latestAllergyACEIcodeDate, 3) + '; ' else '' end) +
				(case when latestAllergyARBcode is not null then latestAllergyARBcode + ' on ' + CONVERT(VARCHAR, latestAllergyARBcodeDate, 3) + '; ' else '' end) +
				(case when latestMaxPotassium > 5.0 then 'latest potassium ' +  Str(latestMaxPotassium, 3, 0) + ' on ' + CONVERT(VARCHAR, latestMaxPotassiumDate, 3) + '; ' else '' end) +
			').</li>'
		when a.PatID not in (select PatID from #htnMeds)
			and ((latestAllergyACEIcode is not null and latestAllergyARBcode is not null) or latestMaxPotassium > 5.0)
			and (latestAllergyCCBcode is not null or latestAScode is not null or (latestMIcodeDate is not null or latestMIcodeDate > DATEADD(month, -1, @refdate)) or latestPorphyriaCode is not null)
			and (latestAllergyThiazideCode is not null or latestCalcium > 2.9 or latestSodium < 130 or latestGoutCode is not null) then
			'<ul><li>Patient is not on antihypertensive medication but has contraindications to ACE Inhibitors and ARBs (' +
				(case when latestAllergyACEIcode is not null then latestAllergyACEIcode + ' on ' + CONVERT(VARCHAR, latestAllergyACEIcodeDate, 3) + '; ' else '' end) +
				(case when latestAllergyARBcode is not null then latestAllergyARBcode + ' on ' + CONVERT(VARCHAR, latestAllergyARBcodeDate, 3) + '; ' else '' end) +
				(case when latestMaxPotassium > 5.0 then 'latest potassium ' +  Str(latestMaxPotassium, 3, 0) + ' on ' + CONVERT(VARCHAR, latestMaxPotassiumDate, 3) + '; ' else '' end) +
			') and Calcium Channel Blockers (' +
				(case when latestAllergyCCBcode is not null then latestAllergyCCBcode + ' on ' + CONVERT(VARCHAR, latestAllergyCCBcodeDate, 3) + '; ' else '' end) +
				(case when latestAScode is not null then latestAScode + ' on ' + CONVERT(VARCHAR, latestAScodeDate, 3) + '; ' else '' end) +
				(case when latestMIcode is not null then latestMIcode + ' on ' + CONVERT(VARCHAR, latestMIcodeDate, 3) + '; ' else '' end) +
				(case when latestMIcodeDate > DATEADD(month, -1, @refdate) then latestMIcode + ' on ' + CONVERT(VARCHAR, latestMIcodeDate, 3) + '; ' else '' end) +
				(case when latestPorphyriaCode is not null then latestPorphyriaCode + ' on ' + CONVERT(VARCHAR, latestPorphyriaCodeDate, 3) + '; ' else '' end) +
			') and Thiazide-type Diuretics (' +
				(case when latestAllergyThiazideCode is not null then latestAllergyThiazideCode + ' on ' + CONVERT(VARCHAR, latestAllergyThiazideCodeDate, 3) + '; ' else '' end) +
				(case when latestCalcium >2.9 then 'latest calcium ' +  Str(latestCalcium, 3, 0) + ' on ' + CONVERT(VARCHAR, latestCalciumDate, 3) + '; ' else '' end) +
				(case when latestSodium < 130 then 'latest sodium ' +  Str(latestSodium, 3, 0) + ' on ' + CONVERT(VARCHAR, latestSodiumDate, 3) + '; ' else '' end) +
				(case when latestGoutCode is not null then latestGoutCode + ' on ' + CONVERT(VARCHAR, latestGoutCodeDate, 3) + '; ' else '' end) +
			').</li>'	
	end +
	'<li>NICE recommends starting either Spironolactone, an Alpha Blocker, or a Beta Blocker.</li>' +
	case
		when 
			(currentMedFamily !='DIUR_POT' and latestAllergyPotSpareDiurCode is null and latestMaxPotassium < 4.6 and latestAddisonsCode is null)
			and (currentMedFamily !='ALPHA' and latestAllergyAlphaCode is null and latestPosturalHypoCode is null)
			and (currentMedFamily !='BB' and latestAllergyBBcode is null and latestAsthmaCode is null and latestPulseValue > 45 and latestPhaeoCode is null and latestHeartBlockCodeDate is null and latestSickSinusCodeDate is null)
		then '</li>Patient has no contra-indications to any of these medications.</li></ul>'
		when 
			(currentMedFamily = 'DIUR_POT' or latestAllergyPotSpareDiurCode is not null or latestMaxPotassium > 4.5 or latestAddisonsCode is not null)
			and (currentMedFamily !='ALPHA' and latestAllergyAlphaCode is null and latestPosturalHypoCode is null)
			and (currentMedFamily !='BB' and latestAllergyBBcode is null and latestAsthmaCode is null and latestPulseValue > 45 and latestPhaeoCode is null and latestHeartBlockCodeDate is null and latestSickSinusCodeDate is null)
		then '</li>Patient is already prescribed, or has a contra-indication to Spironolactone (' + 
			(case when currentMedFamily = 'DIUR_POT' then 'patient is prescribed ' + (select currentMedIngredient from #currentHTNmeds where currentMedFamily = 'DIUR_POT') else '' end) +
			(case when latestAllergyPotSpareDiurCode is not null then latestAllergyPotSpareDiurCode + ' on ' + CONVERT(VARCHAR, latestAllergyPotSpareDiurCodeDate, 3) + '; ' else '' end) +
			(case when latestMaxPotassium > 4.5 then 'latest potassium ' +  Str(latestMaxPotassium, 3, 0) + ' on ' + CONVERT(VARCHAR, latestMaxPotassiumDate, 3) + '; ' else '' end) +
			(case when latestAddisonsCode is not null then latestAddisonsCode + ' on ' + CONVERT(VARCHAR, latestAddisonsCodeDate, 3) + '; ' else '' end) +
			').</li></ul>'	
		when 
			(currentMedFamily = 'DIUR_POT' or latestAllergyPotSpareDiurCode is not null or latestMaxPotassium > 4.5 or latestAddisonsCode is not null)
			and (currentMedFamily ='ALPHA' or latestAllergyAlphaCode is not null or latestPosturalHypoCode is not null)
			and (currentMedFamily !='BB' and latestAllergyBBcode is null and latestAsthmaCode is null and latestPulseValue > 45 and latestPhaeoCode is null and latestHeartBlockCodeDate is null and latestSickSinusCodeDate is null)
		then '</li>Patient is already prescribed, or has a contra-indication to Spironolactone (' + 
			(case when currentMedFamily = 'DIUR_POT' then 'patient is prescribed ' + (select currentMedIngredient from #currentHTNmeds where currentMedFamily = 'DIUR_POT') else '' end) +
			(case when latestAllergyPotSpareDiurCode is not null then latestAllergyPotSpareDiurCode + ' on ' + CONVERT(VARCHAR, latestAllergyPotSpareDiurCodeDate, 3) + '; ' else '' end) +
			(case when latestMaxPotassium > 4.5 then 'latest potassium ' +  Str(latestMaxPotassium, 3, 0) + ' on ' + CONVERT(VARCHAR, latestMaxPotassiumDate, 3) + '; ' else '' end) +
			(case when latestAddisonsCode is not null then latestAddisonsCode + ' on ' + CONVERT(VARCHAR, latestAddisonsCodeDate, 3) + '; ' else '' end) +
			') and Alpha Blockers (' +
			(case when currentMedFamily = 'ALPHA' then 'patient is prescribed ' + (select currentMedIngredient from #currentHTNmeds where currentMedFamily = 'ALPHA') else '' end) +
			(case when latestAllergyAlphaCode is not null then latestAllergyAlphaCode + ' on ' + CONVERT(VARCHAR, latestAllergyAlphaCodeDate, 3) + '; ' else '' end) +
			(case when latestPosturalHypoCode is not null then latestPosturalHypoCode + ' on ' + CONVERT(VARCHAR, latestPosturalHypoCodeDate, 3) + '; ' else '' end) +
			').</li></ul>'	
		when 
			(currentMedFamily = 'DIUR_POT' or latestAllergyPotSpareDiurCode is not null or latestMaxPotassium > 4.5 or latestAddisonsCode is not null)
			and (currentMedFamily !='ALPHA' and latestAllergyAlphaCode is null and latestPosturalHypoCode is null)
			and (currentMedFamily ='BB' or latestAllergyBBcode is not null or latestAsthmaCode is not null or latestPulseValue < 46 or latestPhaeoCode is not null or latestHeartBlockCodeDate is not null or latestSickSinusCodeDate is not null)
		then '</li>Patient is already prescribed, or has a contra-indication to Spironolactone (' + 
			(case when currentMedFamily = 'DIUR_POT' then 'patient is prescribed ' + (select currentMedIngredient from #currentHTNmeds where currentMedFamily = 'DIUR_POT') else '' end) +
			(case when latestAllergyPotSpareDiurCode is not null then latestAllergyPotSpareDiurCode + ' on ' + CONVERT(VARCHAR, latestAllergyPotSpareDiurCodeDate, 3) + '; ' else '' end) +
			(case when latestMaxPotassium > 4.5 then 'latest potassium ' +  Str(latestMaxPotassium, 3, 0) + ' on ' + CONVERT(VARCHAR, latestMaxPotassiumDate, 3) + '; ' else '' end) +
			(case when latestAddisonsCode is not null then latestAddisonsCode + ' on ' + CONVERT(VARCHAR, latestAddisonsCodeDate, 3) + '; ' else '' end) +
			') and Beta Blockers (' +
			(case when currentMedFamily = 'BB' then 'patient is prescribed ' + (select currentMedIngredient from #currentHTNmeds where currentMedFamily = 'BB') else '' end) +
			(case when latestAllergyBBcode is not null then latestAllergyBBcode + ' on ' + CONVERT(VARCHAR, latestAllergyBBcodeDate, 3) + '; ' else '' end) +
			(case when latestAsthmaCode is not null then latestAsthmaCode + ' on ' + CONVERT(VARCHAR, latestAsthmaCodeDate, 3) + '; ' else '' end) +
			(case when latestPulseValue < 46 then 'latest pulse ' +  Str(latestPulseValue, 3, 0) + ' on ' + CONVERT(VARCHAR, latestPulseValue, 3) + '; ' else '' end) +
			(case when latestPhaeoCode is not null then latestPhaeoCode + ' on ' + CONVERT(VARCHAR, latestPhaeoCodeDate, 3) + '; ' else '' end) +
			(case when latestHeartBlockCode is not null then latestHeartBlockCode + ' on ' + CONVERT(VARCHAR, latestHeartBlockCodeDate, 3) + '; ' else '' end) +
			(case when latestSickSinusCode is not null then latestSickSinusCode + ' on ' + CONVERT(VARCHAR, latestSickSinusCodeDate, 3) + '; ' else '' end) +
			').</li></ul>'	
		when 
			(currentMedFamily != 'DIUR_POT' and latestAllergyPotSpareDiurCode is null and latestMaxPotassium < 4.6 and latestAddisonsCode is null)
			and (currentMedFamily ='ALPHA' or latestAllergyAlphaCode is not null or latestPosturalHypoCode is not null)
			and (currentMedFamily ='BB' or latestAllergyBBcode is not null or latestAsthmaCode is not null or latestPulseValue < 46 or latestPhaeoCode is not null or latestHeartBlockCodeDate is not null or latestSickSinusCodeDate is not null)
		then '</li>Patient is already prescribed, or has a contra-indication to Alpha Blockers (' + 
			(case when currentMedFamily = 'ALPHA' then 'patient is prescribed ' + (select currentMedIngredient from #currentHTNmeds where currentMedFamily = 'ALPHA') else '' end) +
			(case when latestAllergyAlphaCode is not null then latestAllergyAlphaCode + ' on ' + CONVERT(VARCHAR, latestAllergyAlphaCodeDate, 3) + '; ' else '' end) +
			(case when latestPosturalHypoCode is not null then latestPosturalHypoCode + ' on ' + CONVERT(VARCHAR, latestPosturalHypoCodeDate, 3) + '; ' else '' end) +
			') and Beta Blockers (' +
			(case when currentMedFamily = 'BB' then 'patient is prescribed ' + (select currentMedIngredient from #currentHTNmeds where currentMedFamily = 'BB') else '' end) +
			(case when latestAllergyBBcode is not null then latestAllergyBBcode + ' on ' + CONVERT(VARCHAR, latestAllergyBBcodeDate, 3) + '; ' else '' end) +
			(case when latestAsthmaCode is not null then latestAsthmaCode + ' on ' + CONVERT(VARCHAR, latestAsthmaCodeDate, 3) + '; ' else '' end) +
			(case when latestPulseValue < 46 then 'latest pulse ' +  Str(latestPulseValue, 3, 0) + ' on ' + CONVERT(VARCHAR, latestPulseDate, 3) + '; ' else '' end) +
			(case when latestPhaeoCode is not null then latestPhaeoCode + ' on ' + CONVERT(VARCHAR, latestPhaeoCodeDate, 3) + '; ' else '' end) +
			(case when latestHeartBlockCode is not null then latestHeartBlockCode + ' on ' + CONVERT(VARCHAR, latestHeartBlockCodeDate, 3) + '; ' else '' end) +
			(case when latestSickSinusCode is not null then latestSickSinusCode + ' on ' + CONVERT(VARCHAR, latestSickSinusCodeDate, 3) + '; ' else '' end) +
			').</li></ul>'	
		when 
			(currentMedFamily != 'DIUR_POT' and latestAllergyPotSpareDiurCode is null and latestMaxPotassium < 4.6 and latestAddisonsCode is null)
			and (currentMedFamily ='ALPHA' or latestAllergyAlphaCode is not null or latestPosturalHypoCode is not null)
			and (currentMedFamily !='BB' and latestAllergyBBcode is null and latestAsthmaCode is null and latestPulseValue > 45 and latestPhaeoCode is null and latestHeartBlockCodeDate is null and latestSickSinusCodeDate is null)
		then '</li>Patient has a contra-indication to Alpha Blockers (' +
			(case when currentMedFamily = 'ALPHA' then 'patient is prescribed ' + (select currentMedIngredient from #currentHTNmeds where currentMedFamily = 'ALPHA') else '' end) +
			(case when latestAllergyAlphaCode is not null then latestAllergyAlphaCode + ' on ' + CONVERT(VARCHAR, latestAllergyAlphaCodeDate, 3) + '; ' else '' end) +
			(case when latestPosturalHypoCode is not null then latestPosturalHypoCode + ' on ' + CONVERT(VARCHAR, latestPosturalHypoCodeDate, 3) + '; ' else '' end) +
			').</li></ul>'	
		when 
			(currentMedFamily != 'DIUR_POT' and latestAllergyPotSpareDiurCode is null and latestMaxPotassium < 4.6 and latestAddisonsCode is null)
			and (currentMedFamily !='ALPHA' and latestAllergyAlphaCode is null and latestPosturalHypoCode is null)
			and (currentMedFamily ='BB' or latestAllergyBBcode is not null or latestAsthmaCode is not null or latestPulseValue < 46 or latestPhaeoCode is not null or latestHeartBlockCodeDate is not null or latestSickSinusCodeDate is not null)
		then '</li>Patient has a contra-indication to Beta Blockers (' +
			(case when currentMedFamily = 'BB' then 'patient is prescribed ' + (select currentMedIngredient from #currentHTNmeds where currentMedFamily = 'BB') else '' end) +
			(case when latestAllergyBBcode is not null then latestAllergyBBcode + ' on ' + CONVERT(VARCHAR, latestAllergyBBcodeDate, 3) + '; ' else '' end) +
			(case when latestAsthmaCode is not null then latestAsthmaCode + ' on ' + CONVERT(VARCHAR, latestAsthmaCodeDate, 3) + '; ' else '' end) +
			(case when latestPulseValue < 46 then 'latest pulse ' +  Str(latestPulseValue, 3, 0) + ' on ' + CONVERT(VARCHAR, latestPulseDate, 3) + '; ' else '' end) +
			(case when latestPhaeoCode is not null then latestPhaeoCode + ' on ' + CONVERT(VARCHAR, latestPhaeoCodeDate, 3) + '; ' else '' end) +
			(case when latestHeartBlockCode is not null then latestHeartBlockCode + ' on ' + CONVERT(VARCHAR, latestHeartBlockCodeDate, 3) + '; ' else '' end) +
			(case when latestSickSinusCode is not null then latestSickSinusCode + ' on ' + CONVERT(VARCHAR, latestSickSinusCodeDate, 3) + '; ' else '' end) +
			').</li></ul>'	
	end as reasonText,
	1 as reasonNumber,
	3 as priority
from #impOppsData as a
	left outer join (select PatID, currentMedFamily, currentMedIngredient from #htnMeds) as b on b.PatID = a.PatID
where
	a.PatID in (select PatID from #eligiblePopulationAllData where bpMeasuredOK = 1 and bpControlledOk = 0)
	and
	(--at stage 3 (i.e. on an ACEI or ARB, CCB, and thiazide)
		(currentMedFamily in ('ACEI', 'ARB') and currentMedFamily = 'CCB' and currentMedFamily = 'DIUR_THI')
		or --on ACEI / ARB and CCB but CI to thiazide
		(
			(currentMedFamily in ('ACEI', 'ARB') and currentMedFamily = 'CCB')
			and (latestAllergyThiazideCode is not null or latestCalcium > 2.9 or latestSodium < 130 or latestGoutCode is not null)
		)
		or --on ACEI / ARB but CI to CCB and thiazide
		(
			(currentMedFamily in ('ACEI', 'ARB')) 
			and (latestAllergyCCBcode is not null or latestAScode is not null or (latestMIcodeDate is not null or latestMIcodeDate > DATEADD(month, -1, @refdate)) or latestPorphyriaCode is not null) 
			and (latestAllergyThiazideCode is not null or latestCalcium > 2.9 or latestSodium < 130 or latestGoutCode is not null)
		)
		or --on ACEI / ARB and thiazide but CI to CCB
		(
			(currentMedFamily in ('ACEI', 'ARB') and currentMedFamily = 'DIUR_THI') 
			and (latestAllergyCCBcode is not null or latestAScode is not null or (latestMIcodeDate is not null or latestMIcodeDate > DATEADD(month, -1, @refdate)) or latestPorphyriaCode is not null)
		)
		or --on CCB and thiazide but CI to ACEI / ARB
		(
			(currentMedFamily = 'CCB' and currentMedFamily = 'DIUR_THI') 
			and ((latestAllergyACEIcode is not null and latestAllergyARBcode is not null) or latestMaxPotassium > 5.0)
		)
		or --on CCB but CI to thiazide and ACEI / ARB
		(
			(currentMedFamily = 'CCB') 
			and (latestAllergyThiazideCode is not null or latestCalcium > 2.9 or latestSodium < 130 or latestGoutCode is not null)
			and ((latestAllergyACEIcode is not null and latestAllergyARBcode is not null) or latestMaxPotassium > 5.0)
		)
		or --not on htn meds but CI to ACEI / ARB and CCB and thiazide
		(
			a.PatID not in (select PatID from #htnMeds) 
			and ((latestAllergyACEIcode is not null and latestAllergyARBcode is not null) or latestMaxPotassium > 5.0)
			and (latestAllergyCCBcode is not null or latestAScode is not null or (latestMIcodeDate is not null or latestMIcodeDate > DATEADD(month, -1, @refdate)) or latestPorphyriaCode is not null)
			and (latestAllergyThiazideCode is not null or latestCalcium > 2.9 or latestSodium < 130 or latestGoutCode is not null)
		)
	)
	and 
	(
		(currentMedFamily !='DIUR_POT' and latestAllergyPotSpareDiurCode is null and latestMaxPotassium < 4.6 and latestAddisonsCode is null) --not already on a pot sparing diuretic and no CIs
		or
		(currentMedFamily != 'ALPHA' and latestAllergyAlphaCode is null and latestPosturalHypoCode is null)--not already on an Alpha and no CIs
		or
		(currentMedFamily !='BB' and latestAllergyBBcode is null and latestAsthmaCode is null and latestPulseValue > 45 and latestPhaeoCode is null and latestHeartBlockCodeDate is null and latestSickSinusCodeDate is null) --not already on BB and no CIs
	)
	
union


--increase current medication
select distinct a.PatID, 
--	case
--		when currentMedFamily = 'ACEI' and currentMedDose < currentMedMaxDose and latestMaxPotassium < 5.1 then 'ACE inhibitor'
--		when currentMedFamily = 'CCB' and currentMedDose < currentMedMaxDose then 'Calcium Channel Blocker'
--		when currentMedFamily = 'DIUR_THI' and currentMedDose < currentMedMaxDose then 'Thiazide-type Diuretic'
--		when currentMedFamily = 'ARB' and currentMedDose < currentMedMaxDose then 'Angiotension II Receptor Blocker'
--		when currentMedFamily = 'BB' and currentMedDose < currentMedMaxDose then 'Beta Blocker'
--		when currentMedFamily = 'DIUR_POT' and currentMedDose < currentMedMaxDose then 'Potassium-sparing Diuretic'
--		when currentMedFamily = 'ALPHA' and currentMedDose < currentMedMaxDose then 'Alpha Blocker'
--		when currentMedFamily = 'DIUR_LOOP' and currentMedDose < currentMedMaxDose then 'Loop Diuretic'
--	end 
	'<a href="' + BNF + '" target="_blank">' + currentMedIngredient + '</a>'  COLLATE Latin1_General_CI_AS as family, 
	'Increase' as start_or_inc, 
	'<ul><li>Patient is currently prescribed ' + currentMedIngredient COLLATE Latin1_General_CI_AS + ' ' + Str(currentMedDose, 3, 0) + ' mg per day. Max dose is ' + Str(currentMedMaxDose, 3, 0)+ ' mg per day <a href="' + BNF + '" target="_blank">BNF link</a>).</li></ul>' as reasonText,
	1 as reasonNumber,
	2 as priority
from #htnMeds as a
	left outer join (select PatID, age, bpMeasuredOK, bpControlledOk from #eligiblePopulationAllData) as b on b.PatID = a.PatID
	left outer join (select PatID, latestAllergyACEIcode, latestMaxPotassium from #impOppsData) as c on c.PatID = a.PatID
	left outer join (select Ingredient, BNF from drugIngredients) as d on d.Ingredient = a.currentMedIngredient
where
	a.PatID in (select PatID from #eligiblePopulationAllData where bpMeasuredOK = 1 and bpControlledOk = 0)
	and
	(
		(currentMedFamily = 'ACEI' and currentMedDose < currentMedMaxDose and latestMaxPotassium < 5.1)
		or
		(currentMedFamily = 'CCB' and currentMedDose < currentMedMaxDose)
		or
		(currentMedFamily = 'DIUR_THI' and currentMedDose < currentMedMaxDose)
		or
		(currentMedFamily = 'ARB' and currentMedDose < currentMedMaxDose)
		or
		(currentMedFamily = 'BB' and currentMedDose < currentMedMaxDose)
		or
		(currentMedFamily = 'DIUR_POT' and currentMedDose < currentMedMaxDose)
		or
		(currentMedFamily = 'ALPHA' and currentMedDose < currentMedMaxDose)
		or
		(currentMedFamily = 'DIUR_LOOP' and currentMedDose < currentMedMaxDose)	
	)

							---------------------------------------------------------------
							----------------------PT-LEVEL ACTIONS-------------------------
							---------------------------------------------------------------
									--TO RUN AS STORED PROCEDURE--
insert into [output.pingr.patActions](PatID, indicatorId, actionCat, reasonCat, reasonNumber, priority, actionText, supportingText)


									--TO TEST ON THE FLY--
--IF OBJECT_ID('tempdb..#patActions') IS NOT NULL DROP TABLE #patActions
--CREATE TABLE #patActions
--	(PatID int, indicatorId varchar(1000), actionCat varchar(1000), reasonCat varchar(1000), reasonNumber int, priority int, actionText varchar(1000), supportingText varchar(max));
--insert into #patActions


--CHECK REGISTERED
select a.PatID, 
	'ckd.treatment.bp' as indicatorId,
	'Registered?' as actionCat,
	'No contact' as reasonCat,
	1 as reasonNumber,
	2 as priority,
	'Check this patient is registered' as actionText, 
	'Reasoning' +
		'<ul><li>No contact with your practice in the last year.</ul>' + 
	'If <strong>not registered</strong> please add code <strong>92...</strong> [#92...] to their records.<br><br>' +
	'If <strong>dead</strong> please add code <strong>9134.</strong> [#9134.] to their records.<br><br>' +
	'Useful information' + 
		'<ul><li>' + 
			case 
					when dmPatient = 1 then (select text from regularText where [textId] = 'linkNiceBpMxCkdDm')
					when dmPatient = 0 then (select text from regularText where [textId] = 'linkNiceBpMxCkd') 
			end + '</li>' +
		'<li>'  + (select text from regularText where [textId] = 'linkBmjCkdBp') + '</li>' + 
		'<li>'  + (select text from regularText where [textId] = 'linkPilCkdBp') + '</li></ul>'
	as supportingText
from #impOppsData as a
left outer join (select PatID, dmPatient, protPatient from #eligiblePopulationAllData) as b on b.PatID = a.PatID
	where 
		noPrimCareContactInLastYear = 1
	
union

--MEASURE BP
select a.PatID, 
	'ckd.treatment.bp' as indicatorId,
	'Measure BP' as actionCat,
	case
		--No BP + no contact
		when noPrimCareContactInLastYear = 1 and a.PatID in (select PatID from #eligiblePopulationAllData where bpMeasuredOK = 0) then 'No BP + no contact' 
		--No BP + contact
		when noPrimCareContactInLastYear = 0 and a.PatID in (select PatID from #eligiblePopulationAllData where bpMeasuredOK = 0) then 'No BP + contact'
		--BP uncontrolled BUT second latest BP controlled (one-off high)
		when secondLatestBpControlled = 1 and a.PatID in (select PatID from #eligiblePopulationAllData where bpMeasuredOK = 1 and bpControlledOk = 0) then 'BP uncontrolled BUT second latest BP controlled (one-off high)'
		--BP uncontrolled + medication change after
		when latestMedOptimisationDate >= latestSbpDate and a.PatID in (select PatID from #eligiblePopulationAllData where bpMeasuredOK = 1 and bpControlledOk = 0) then 'BP uncontrolled + medication change after'
		--BP uncontrolled BUT near target
		when (((dmPatient = 1 or protPatient = 1) and	(b.latestSbp < 140 and b.latestDbp < 90)) or ((dmPatient = 0 and protPatient = 0) and (b.latestSbp < 150 and b.latestDbp < 100))) and a.PatID in (select PatID from #eligiblePopulationAllData where bpMeasuredOK = 1 and bpControlledOk = 0) then 'BP uncontrolled BUT near target'
	end as reasonCat,
	--No BP + no contact
	(case when noPrimCareContactInLastYear = 1 and a.PatID in (select PatID from #eligiblePopulationAllData where bpMeasuredOK = 0) then 1 else 0 end) +
	--No BP + contact
	(case when noPrimCareContactInLastYear = 0 and a.PatID in (select PatID from #eligiblePopulationAllData where bpMeasuredOK = 0) then 1 else 0 end) +
	--BP uncontrolled BUT second latest BP controlled (one-off high)
	(case when secondLatestBpControlled = 1 and a.PatID in (select PatID from #eligiblePopulationAllData where bpMeasuredOK = 1 and bpControlledOk = 0) then 1 else 0 end) +
	--BP uncontrolled + medication change after
	(case when latestMedOptimisationDate >= latestSbpDate and a.PatID in (select PatID from #eligiblePopulationAllData where bpMeasuredOK = 1 and bpControlledOk = 0) then 1 else 0 end) +
	--BP uncontrolled BUT near target
	(case when (((dmPatient = 1 or protPatient = 1) and	(b.latestSbp < 140 and b.latestDbp < 90)) or ((dmPatient = 0 and protPatient = 0) and (b.latestSbp < 150 and b.latestDbp < 100))) and a.PatID in (select PatID from #eligiblePopulationAllData where bpMeasuredOK = 1 and bpControlledOk = 0) then 1 else 0 end)
	as reasonNumber,
	2 as priority,
	'Measure this patient''s BP' as actionText, 
	'Reasoning' +
		(case
		--No BP
			when a.PatID in (select PatID from #eligiblePopulationAllData where bpMeasuredOK = 0) then '<ul><li>No BP reading since last April.</ul>'
		--Any BP
			else 
				'<ul><li>Last BP was <strong>uncontrolled</strong>: ' + 
					case 
						when ((dmPatient = 1 or protPatient = 1) and (latestSbp >= 130)) or ((dmPatient = 0 and protPatient = 0) and (latestSbp >= 140)) then '<strong>' + Str(latestSbp) + '</strong>'
						else Str(latestSbp)
					end
				+ '/' + 
					case 
						when ((dmPatient = 1 or protPatient = 1) and (latestDbp >= 80)) or ((dmPatient = 0 and protPatient = 0) and (latestDbp >= 90)) then '<strong>' + Str(latestDbp) + '</strong>'
						else Str(latestDbp)
					end
				+ ' on ' + CONVERT(VARCHAR, latestSbpDate, 3) + '.</li>' +
				'<li>Target: ' + b.bpTarget + ' - because patient has CKD' + 
					case 
						when dmPatient = 1 then ' and diabetes' 
						when protPatient = 1 then ' and ACR > 70 on ' + CONVERT(VARCHAR, latestAcrDate, 3)
						else '' 
					end + 
			' (' + (select text from regularText where [textId] = 'linkNiceBpTargetsCkd') COLLATE Latin1_General_CI_AS + ').</li>'
		end) +
		(case
		--BP uncontrolled BUT near target
			when (((dmPatient = 1 or protPatient = 1) and	(b.latestSbp < 140 and b.latestDbp < 90)) or ((dmPatient = 0 and protPatient = 0) and (b.latestSbp < 150 and b.latestDbp < 100))) and a.PatID in (select PatID from #eligiblePopulationAllData where bpMeasuredOK = 1 and bpControlledOk = 0) then
				'<li>This is only <strong>slightly (<10mmHg)</strong> over target. So it may be worth re-measuring their BP in case it has now come down.</li></ul>'
			else ''
		end) +
		(case 
		--BP uncontrolled BUT second latest BP controlled (one-off high)
			when secondLatestBpControlled = 1 and a.PatID in (select PatID from #eligiblePopulationAllData where bpMeasuredOK = 1 and bpControlledOk = 0) then
				'<li><strong>Previous BP</strong> was <strong>controlled</strong>: ' + Str(secondLatestSbp) + '/' + Str(secondLatestDbp) + ' on ' + CONVERT(VARCHAR, secondLatestSbpDate, 3) + '. So it may be worth re-measuring in case this was a one-off.</li>'
			else ''			
		end) +
		(case 
		--BP uncontrolled + medication change after
			when latestMedOptimisationDate >= latestSbpDate and a.PatID in (select PatID from #eligiblePopulationAllData where bpMeasuredOK = 1 and bpControlledOk = 0) then
				'<li><strong>' + latestMedOptimisationIngredient + '</strong> was <strong>' + latestMedOptimisation + '</strong> on <strong>' + CONVERT(VARCHAR, latestMedOptimisationDate, 3) + '</strong>.</li>' + '. So it may be worth re-measuring BP in case it has now come down.</li>'
			else ''
		end) +
		(case
		--No BP + no contact
			when noPrimCareContactInLastYear = 1 and a.PatID in (select PatID from #eligiblePopulationAllData where bpMeasuredOK = 0) then
				'Because they have <strong>not</strong> had contact with your practice in the last year, it may be best to:' +
					'<ul><li><strong>Telephone</strong> them. If so, please add code <strong>9Ot4. (CKD telephone invite)</strong> [#9Ot4.] to their records.</li>' +
					'<li>Send them a <strong>letter</strong>. If so, please add code <strong>9Ot0. (CKD 1st letter)</strong> [#9Ot0.] or <strong>9Ot1. (CKD 2nd letter)</strong> or <strong>9Ot2. (CKD 3rd letter)</strong> to their records.</li></ul>'
			else
		--Any contact
				'Because they <strong>have</strong> had contact with your practice in the last year, it may be possible to:' +
					'<ul><li>Measure their BP <strong>opportunistically</strong> next time they are seen.</li>' +
					'<li>Put a <strong>message on their prescription</strong> to make an appointment.</li>' +
					'<li><strong>Telephone</strong> them. If so, please add code <strong>9Ot4. (CKD telephone invite)</strong> [#9Ot4.] to their records.</li>' +
					'<li>Send them a <strong>letter</strong>. If so, please add code <strong>9Ot0. (CKD 1st letter)</strong> [#9Ot0.] or <strong>9Ot1. (CKD 2nd letter)</strong> or <strong>9Ot2. (CKD 3rd letter)</strong> to their records.</li></ul>'
		end) +
	'Useful information' + 
		'<ul><li>' + 
			case 
					when dmPatient = 1 then (select text from regularText where [textId] = 'linkNiceBpMxCkdDm')
					when dmPatient = 0 then (select text from regularText where [textId] = 'linkNiceBpMxCkd') 
			end + '</li>' +
		'<li>'  + (select text from regularText where [textId] = 'linkBmjCkdBp') + '</li>' + 
		'<li>'  + (select text from regularText where [textId] = 'linkPilCkdBp') + '</li></ul>'
	as supportingText
from #impOppsData as a
	left outer join (select PatID, latestSbp, latestDbp, latestSbpDate, bpTarget,  dmPatient, protPatient, latestAcrDate from #eligiblePopulationAllData) as b on b.PatID = a.PatID
where
	a.PatID in (select PatID from #eligiblePopulationAllData where bpMeasuredOK = 0)
	or 
	(
		a.PatID in (select PatID from #eligiblePopulationAllData where bpMeasuredOK = 1 and bpControlledOk = 0)
		and 
		(	
			(secondLatestBpControlled = 1)
			or
			(latestMedOptimisationDate >= latestSbpDate)
			or
			((dmPatient = 1 or protPatient = 1) and	(b.latestSbp < 140 and b.latestDbp < 90)) 
			or 
			((dmPatient = 0 and protPatient = 0) and (b.latestSbp < 150 and b.latestDbp < 100))
		)
			
	)
	
union


--MEDICATION SUGGESTION
select a.PatID, 
	'ckd.treatment.bp' as indicatorId,
	'Medication optimisation' as actionCat,
	start_or_inc + ' ' + family as reasonCat,
	reasonNumber as reasonNumber,
	priority as priority,
	start_or_inc + ' ' + family as actionText, 
	'Reasoning' +
		'<ul><li>Last BP was <strong>uncontrolled</strong>: ' + 
				case 
					when ((dmPatient = 1 or protPatient = 1) and (latestSbp >= 130)) or ((dmPatient = 0 and protPatient = 0) and (latestSbp >= 140)) then '<strong>' + Str(latestSbp) + '</strong>'
					else Str(latestSbp)
				end
			+ '/' + 
				case 
					when ((dmPatient = 1 or protPatient = 1) and (latestDbp >= 80)) or ((dmPatient = 0 and protPatient = 0) and (latestDbp >= 90)) then '<strong>' + Str(latestDbp) + '</strong>'
					else Str(latestDbp)
				end
			+ ' on ' + CONVERT(VARCHAR, latestSbpDate, 3) + '.</li>' +
			'<li>Target: ' + b.bpTarget + ' - because patient has CKD' + 
				case 
					when dmPatient = 1 then ' and diabetes' 
					when protPatient = 1 then ' and ACR > 70 on ' + CONVERT(VARCHAR, b.latestAcrDate, 3)
					else '' 
				end + 
		' (' + (select text from regularText where [textId] = 'linkNiceBpTargetsCkd') COLLATE Latin1_General_CI_AS + ').</li>'
	+ reasonText +
	'Useful information' + 
		'<ul><li>' + 
			case 
				when family like '%ACE inhibitor%' then (select text from regularText where [textId] = 'linkNiceAceiArbCkd')
				when family like '%ARB%' then (select text from regularText where [textId] = 'linkNiceAceiArbCkd')
				when family like '%Calcium Channel Blocker%' then (select text from regularText where [textId] = 'linkNiceCcbHtn')
				when family like '%Indapamide%' then (select text from regularText where [textId] = 'linkNiceThiazideHtn')
				when family like '%Spironolactone%' then (select text from regularText where [textId] = 'linkNiceSpiroHtn')
				when family like '%Alpha Blocker%' then (select text from regularText where [textId] = 'linkNiceAlphaHtn')
				when family like '%Beta Blocker%' then (select text from regularText where [textId] = 'linkNiceBbHtn')
				else ''
			end + '</li>' +
		'<ul><li>' + 
			case 
					when dmPatient = 1 then (select text from regularText where [textId] = 'linkNiceBpMxCkdDm')
					when dmPatient = 0 then (select text from regularText where [textId] = 'linkNiceBpMxCkd') 
			end + '</li>' +
		'<li>'  + (select text from regularText where [textId] = 'linkBmjCkdBp') + '</li>' + 
		'<li>'  + (select text from regularText where [textId] = 'linkPilCkdBp') + '</li></ul>' as supportingText
from #medSuggestion as a
	left outer join (select PatID, latestSbp, latestDbp, latestSbpDate, bpTarget, dmPatient, protPatient, latestAcrDate from #eligiblePopulationAllData) as b on b.PatID = a.PatID

union

--SUGGEST EXCLUDE
select a.PatID,
	'ckd.treatment.bp' as indicatorId,
	'Suggest exclude' as actionCat,
	case
		when (latestPalCodeDate > DATEADD(year, -1, @refdate)) and (latestPalPermExCodeDate is null or latestPalPermExCodeDate < latestPalCodeDate) then 'Palliative'
		when latestFrailCode is not null then 'Frail'
		when (latestHouseBedboundCodeDate is not null) and (latestHouseBedboundPermExCodeDate is null or latestHouseBedboundPermExCodeDate < latestHouseBedboundCodeDate) then 'House or bed bound'
		when (latestCkd3rdInviteCodeDate > DATEADD(year, -1, @achievedate)) or numberOfCkdInviteCodesThisFinancialYear > 2 then '3 invites'
--		when (select COUNT(*) from (select currentMedFamily from #currentHTNmeds) sub) > 3 and a.PatID in (select PatID from #eligiblePopulationAllData where bpMeasuredOK = 1 and bpControlledOk = 0) then 'Maximum medication'
		when a.PatID in (select PatID from #htnMeds) and a.PatID NOT in (select PatID from #medSuggestion) and a.PatID in (select PatID from #eligiblePopulationAllData where bpMeasuredOK = 1 and bpControlledOk = 0) then 'Maximum tolerated medication'
		else ''
	end as reasonCat,
	(case when (latestPalCodeDate > DATEADD(year, -1, @refdate)) and (latestPalPermExCodeDate is null or latestPalPermExCodeDate < latestPalCodeDate) 
	then 1 else 0 end) +
	(case when latestFrailCode is not null
	then 1 else 0 end) +
	(case when (latestHouseBedboundCodeDate is not null) and (latestHouseBedboundPermExCodeDate is null or latestHouseBedboundPermExCodeDate < latestHouseBedboundCodeDate)
	then 1 else 0 end) +
	(case when (latestCkd3rdInviteCodeDate > DATEADD(year, -1, @achievedate)) or numberOfCkdInviteCodesThisFinancialYear > 2 
	then 1 else 0 end) +
--	(case when (select COUNT(*) from (select currentMedFamily from #currentHTNmeds) sub) > 3 and a.PatID in (select PatID from #eligiblePopulationAllData where bpMeasuredOK = 1 and bpControlledOk = 0)
--	then 1 else 0 end) +
	(case when a.PatID in (select PatID from #htnMeds) and a.PatID NOT in (select PatID from #medSuggestion) and a.PatID in (select PatID from #eligiblePopulationAllData where bpMeasuredOK = 1 and bpControlledOk = 0)
	then 1 else 0 end)
	as reasonNumber,
	3 as priority,
	'Exclude this patient from CKD BP indicator using code(s): ' + 
	(case
		when 
			((latestPalCodeDate > DATEADD(year, -1, @refdate)) and (latestPalPermExCodeDate is null or latestPalPermExCodeDate < latestPalCodeDate))
			or
			(latestFrailCode is not null)
			or
			((latestHouseBedboundCodeDate is not null) and (latestHouseBedboundPermExCodeDate is null or latestHouseBedboundPermExCodeDate < latestHouseBedboundCodeDate))
		then '9hE1. (patient unsuitable) [9hE1.] '
		else ''
	end) +  
	(case
		when (latestCkd3rdInviteCodeDate > DATEADD(year, -1, @achievedate)) or numberOfCkdInviteCodesThisFinancialYear > 2 
		then '9hE0. (informed dissent) [9hE0.] '
		else ''
	end) +
--	(case
--		when (select COUNT(*) from (select currentMedFamily from #currentHTNmeds) sub) > 3 and a.PatID in (select PatID from #eligiblePopulationAllData where bpMeasuredOK = 1 and bpControlledOk = 0)
--		then '8BL0. (maximal therapy) [8BL0.] '
--		else ''
--	end) +
	(case
		when a.PatID in (select PatID from #htnMeds) and a.PatID NOT in (select PatID from #medSuggestion) and a.PatID in (select PatID from #eligiblePopulationAllData where bpMeasuredOK = 1 and bpControlledOk = 0) 
		then '8BL0. (maximal therapy) [8BL0.] '
		else ''
	end) as actionText,
	'Reasoning<ul>' +
		(case when (latestPalCodeDate > DATEADD(year, -1, @refdate)) and (latestPalPermExCodeDate is null or latestPalPermExCodeDate < latestPalCodeDate) 
		then '<li>Patient has code <strong> ''' + latestPalCode + '''</strong> on ' + CONVERT(VARCHAR, latestPalCodeDate, 3) + '.</li>' else '' end) +
		(case when latestFrailCode is not null
		then '<li>Patient has code <strong>''' + latestFrailCode + '''</strong> on ' + CONVERT(VARCHAR, latestFrailCodeDate, 3) + '.</li>' else '' end) +
		(case when (latestHouseBedboundCodeDate is not null) and (latestHouseBedboundPermExCodeDate is null or latestHouseBedboundPermExCodeDate < latestHouseBedboundCodeDate)
		then '<li>Patient has code <strong>''' + latestHouseBedboundCode + '''</strong> on ' + CONVERT(VARCHAR, latestHouseBedboundCodeDate, 3) + '.</li>' else '' end) +
		(case when (latestCkd3rdInviteCodeDate > DATEADD(year, -1, @achievedate)) or numberOfCkdInviteCodesThisFinancialYear > 2 
		then '<li>Patient has had 3 CKD invites since last April.</li>' else '' end) +
--		(case 
--			when (select COUNT(*) from (select currentMedFamily from #currentHTNmeds) sub) > 3 and a.PatID in (select PatID from #eligiblePopulationAllData where bpMeasuredOK = 1 and bpControlledOk = 0)
--			then 
--				'<li>Last BP was <strong>uncontrolled</strong>: ' + 
--						case 
--							when ((dmPatient = 1 or protPatient = 1) and (latestSbp >= 130)) or ((dmPatient = 0 and protPatient = 0) and (latestSbp >= 140)) then '<strong>' + Str(latestSbp) + '</strong>'
--							else Str(latestSbp)
--						end
--					+ '/' + 
--						case 
--							when ((dmPatient = 1 or protPatient = 1) and (latestDbp >= 80)) or ((dmPatient = 0 and protPatient = 0) and (latestDbp >= 90)) then '<strong>' + Str(latestDbp) + '</strong>'
--							else Str(latestDbp)
--						end
--					+ ' on ' + CONVERT(VARCHAR, latestSbpDate, 3) + '.</li>' +
--					'<li>Target: ' + bpTarget + ' - because patient has CKD' + 
--						case 
--							when dmPatient = 1 then ' and diabetes' 
--							when protPatient = 1 then ' and ACR > 70 on ' + CONVERT(VARCHAR, latestAcrDate, 3)
--							else '' 
--						end + 
--				' (' + (select text from regularText where [textId] = 'linkNiceBpTargetsCkd') COLLATE Latin1_General_CI_AS + ').</li>' +		
--				'<li><strong>And</strong> patient is prescribed <strong>4 or more</strong> classes of hypertensive medication.</li>' 
--			else '' 
--			end) +
		(case 
			when a.PatID in (select PatID from #htnMeds) and a.PatID NOT in (select PatID from #medSuggestion) and a.PatID in (select PatID from #eligiblePopulationAllData where bpMeasuredOK = 1 and bpControlledOk = 0)
			then 
				'<li>Last BP was <strong>uncontrolled</strong>: ' + 
						case 
							when ((dmPatient = 1 or protPatient = 1) and (latestSbp >= 130)) or ((dmPatient = 0 and protPatient = 0) and (latestSbp >= 140)) then '<strong>' + Str(latestSbp) + '</strong>'
							else Str(latestSbp)
						end
					+ '/' + 
						case 
							when ((dmPatient = 1 or protPatient = 1) and (latestDbp >= 80)) or ((dmPatient = 0 and protPatient = 0) and (latestDbp >= 90)) then '<strong>' + Str(latestDbp) + '</strong>'
							else Str(latestDbp)
						end
					+ ' on ' + CONVERT(VARCHAR, latestSbpDate, 3) + '.</li>' +
					'<li>Target: ' + bpTarget + ' - because patient has CKD' + 
						case 
							when dmPatient = 1 then ' and diabetes' 
							when protPatient = 1 then ' and ACR > 70 on ' + CONVERT(VARCHAR, latestAcrDate, 3)
							else '' 
						end + 
				' (' + (select text from regularText where [textId] = 'linkNiceBpTargetsCkd') COLLATE Latin1_General_CI_AS + ').</li>' +		
				'<li>Patient has contraindications to, or is taking all BP medications recommendeded by NICE.</li>' 
			else '' 
			end) +
	'Useful information' + 
		'<ul><li>' + (select text from regularText where [textId] = 'ExceptionReportingReasons') + '</li></ul>'
	as supportingText
from #impOppsData as a
	left outer join (select PatID, currentMedFamily from #currentHTNmeds) as b on b.PatID = a.PatID
	left outer join (select PatID, bpMeasuredOK, bpControlledOk, dmPatient, protPatient, latestSbp, latestDbp, latestSbpDate, bpTarget, latestAcrDate from #eligiblePopulationAllData) as c on c.PatID = a.PatID
where
	((latestPalCodeDate > DATEADD(year, -1, @refdate)) and (latestPalPermExCodeDate is null or latestPalPermExCodeDate < latestPalCodeDate))
	or (latestFrailCode is not null)
	or((latestHouseBedboundCodeDate is not null) and (latestHouseBedboundPermExCodeDate is null or latestHouseBedboundPermExCodeDate < latestHouseBedboundCodeDate))
	or((latestCkd3rdInviteCodeDate > DATEADD(year, -1, @achievedate)) or numberOfCkdInviteCodesThisFinancialYear > 2)
--	or((select COUNT(*) from (select currentMedFamily from #currentHTNmeds) sub) > 3 and a.PatID in (select PatID from #eligiblePopulationAllData where bpMeasuredOK = 1 and bpControlledOk = 0))
	or(a.PatID in (select PatID from #htnMeds) and a.PatID NOT in (select PatID from #medSuggestion) and a.PatID in (select PatID from #eligiblePopulationAllData where bpMeasuredOK = 1 and bpControlledOk = 0))

							---------------------------------------------------------------
							---------------SORT ORG-LEVEL ACTION PRIORITY ORDER------------
							---------------------------------------------------------------

--#reason proportions
IF OBJECT_ID('tempdb..#reasonProportions') IS NOT NULL DROP TABLE #reasonProportions
CREATE TABLE #reasonProportions
	(proportionId varchar(32), proportion float);
insert into #reasonProportions
values
--No BP + contact with practice
('noBpYesContact', 
	(select COUNT(*) from 
		(
				select a.PatID from #eligiblePopulationAllData as a
				left outer join (select PatID, noPrimCareContactInLastYear from #impOppsData) as b on b.PatID = a.PatID
				where denominator = 1 and bpMeasuredOK = 0 and noPrimCareContactInLastYear = 0
		) sub
	) /
	(select COUNT(*) from (select PatID from #eligiblePopulationAllData where denominator = 1) sub)
),
--Uncontrolled + within 10mmHg of target
('uncontrolledClose', 
	(select COUNT(*) from 
		(
			select PatID from #eligiblePopulationAllData 
				where 
					(
						((dmPatient = 1 or protPatient = 1) and (latestSbp < 140 and latestDbp < 90)) or 
						((dmPatient = 0 and protPatient = 0) and (latestSbp < 150 and latestDbp < 100))
					) 
					and 
					denominator = 1 and bpMeasuredOK = 1 and bpControlledOk = 0
		) sub
	)/
	(select COUNT(*) from (select PatID from #eligiblePopulationAllData where denominator = 1) sub)
),
--No optimisation after high reading (therapeutic inertia)
('rxInertia', 
	(select COUNT(*) from
		(
			select a.PatID from #eligiblePopulationAllData a
				left outer join (select PatID, latestMedOptimisationDate from #impOppsData) as b on b.PatID = a.PatID
				where denominator = 1 and bpMeasuredOK = 1 and bpControlledOk = 0
				and (latestMedOptimisationDate is null or (latestMedOptimisationDate < latestSbpDate))
		) sub
	)/
	(select COUNT(*) from (select PatID from #eligiblePopulationAllData where denominator = 1) sub)
),
--'measure' actions
('measureActions', 
	(select COUNT(*) from (select distinct PatID from [output.pingr.patActions] where indicatorId = 'ckd.treatment.bp' and actionCat = 'Measure BP') sub)/
	(select COUNT(*) from (select PatID from #eligiblePopulationAllData where denominator = 1) sub)
),
--uncontrolled
('uncontrolled', 
	(select COUNT(*) from (select PatID from #eligiblePopulationAllData where denominator = 1 and bpMeasuredOK = 1 and bpControlledOk = 0) sub
	)/
	(select COUNT(*) from (select PatID from #eligiblePopulationAllData where denominator = 1) sub)
)

							---------------------------------------------------------------
							----------------------ORG-LEVEL ACTIONS------------------------
							---------------------------------------------------------------

declare @noBpYesContactProportion float;
set @noBpYesContactProportion = (select proportion from #reasonProportions where proportionId = 'noBpYesContact');
declare @uncontrolledCloseProportion float;
set @uncontrolledCloseProportion = (select proportion from #reasonProportions where proportionId = 'uncontrolledClose');
declare @rxInertiaProportion float;
set @rxInertiaProportion = (select proportion from #reasonProportions where proportionId = 'rxInertia');
declare @measureActionsProportion float;
set @measureActionsProportion = (select proportion from #reasonProportions where proportionId = 'measureActions');
declare @uncontrolledProportion float;
set @uncontrolledProportion = (select proportion from #reasonProportions where proportionId = 'uncontrolled');

insert into [output.pingr.orgActions](indicatorId, actionText, proportion, supportingText)

--BP MACHINE IN WAITING ROOM
select 
	'ckd.treatment.bp' as indicatorId,
	'Put BP machine in your waiting room' as actionText,
	--No BP + contact with practice
	@noBpYesContactProportion as proportion,
	'Reasoning' +
		'<ul><li>' + STR(@noBpYesContactProportion) + 'of patients not meeting the CKD BP indicator because they have not had their BP measured <strong>BUT</strong> had contact with your practice in the last year.</li>' +
		'<li>With a BP machine in your waiting room, patients can take their own BP whilst they wait and give their readings to your receptionists.' +
	'Useful information' + 
		'<ul><li>'  + (select text from regularText where [textId] = 'linkBmjCkdBp') + '</li></ul>' as supportingText

union

--WORK WITH LOCAL PHARMACY
select 
	'ckd.treatment.bp' as indicatorId,
	'Work with your local pharmacy to enable them to take blood pressure readings' as actionText,
	--No BP + medication contact
	@noBpYesContactProportion as proportion,
	'Reasoning' +
		'<ul><li>' + STR(@noBpYesContactProportion) 
		+ 'of patients not meeting the CKD BP indicator because they have not had their BP measured <strong>BUT</strong> have had medication issued in the last year.</li>' +
		'<li>Pharmacies can take their blood pressure when they issue their medication and send the readings to you.' +
	'Useful information' + 
		'<ul><li>'  + (select text from regularText where [textId] = 'RpsGuidanceBp') + '</li></ul>' as supportingText
union

--INTRODUCE ABPM
select 
	'ckd.treatment.bp' as indicatorId,
	'Introduce an ambulatory BP monitoring service' as actionText,
	--Uncontrolled + within 10mmHg of target
	(@uncontrolledCloseProportion) as proportion,
	'Reasoning' +
		'<ul><li>' + STR(@uncontrolledCloseProportion)
		+ 'of patients not meeting the CKD BP indicator because they have uncontrolled BP <strong>but</strong> are within < 10 mmHg of their BP target.</li>' +
		'<li>Often high blood pressure readings taken in surgery are normal at home.</li>' +
		'<li>This would also follow NICE guidance for hypertension diagnosis.' +
	'Useful information' + 
		'<ul><li>'  + (select text from regularText where [textId] = 'linkBhsAbpm') + '</li>' +
		'<ul><li>'  + (select text from regularText where [textId] = 'linkPatientUkAbpm') + '</li>' +
		'<ul><li>'  + (select text from regularText where [textId] = 'linkNiceHtn') + '</li>' +
		'</ul>' 
		as supportingText

union

--ENCOURAGE BP WITH NURSE / AHP
select
	'ckd.treatment.bp' as indicatorId,
	'Encourage patients with CKD to see the nurse or AHP to measure their blood pressure' as actionText,
	--Uncontrolled + within 10mmHg of target
	(@uncontrolledCloseProportion) as proportion,
	'Reasoning' +
		'<ul><li>' + STR(@uncontrolledCloseProportion)
		+ 'of patients not meeting the CKD BP indicator because they have uncontrolled BP <strong>but</strong> are within < 10 mmHg of their BP target.</li>' +
		'<li>BP is generally lower when measured with other health professionals other than doctors.</li>' +
	'Useful information' + 
		'<ul><li>'  + (select text from regularText where textId = 'linkBjgpBpDoctorsHigher') + '</li>' +
		'</ul>' 
		as supportingText

union

--EDUCATIONAL SESSION
select 
	'ckd.treatment.bp' as indicatorId,
	'Hold an educational session for your practice staff on NICE hypertension guidelines' as actionText,
	--No optimisation after high reading (therapeutic inertia)
	(@rxInertiaProportion) as proportion,
	'Reasoning' +
		'<ul><li>' + STR(@rxInertiaProportion)
		+ 'of CKD patients with <strong>uncontrolled</strong> BP did not have their medication optimised after their latest reading.</li>' +
		'<li>This <strong>may</strong> indicate that staff are unaware of medication optimisation guidelines or the importance of BP control.</li>' +
	'Useful information' + 
		'<ul><li>'  + (select text from regularText where textId = 'niceBpPresentation') + '</li>' +
		'</ul>' 
		as supportingText

union

--PATHWAY PRINT-OUT
select
	'ckd.treatment.bp' as indicatorId,
	'Print a copy of NICE hypertension targets and medication pathway for each room in your practice' as actionText,
	--No optimisation after high reading (therapeutic inertia)
	(@rxInertiaProportion) as proportion,
	'Reasoning' +
		'<ul><li>' + 
				STR(@rxInertiaProportion)
		+ 'of CKD patients with <strong>uncontrolled</strong> BP did not have their medication optimised after their latest reading.</li>' +
		'<li>This <strong>may</strong> indicate that staff are unaware of medication optimisation guidelines or the importance of BP control.</li>' +
	'Useful information' + 
		'<ul><li>'  + (select text from regularText where textId = 'niceBpPathway') + '</li>' +
		'</ul>' 
		as supportingText

union

--ENCOURAGE HBPM
select
	'ckd.treatment.bp' as indicatorId,
	'Encourage patients with CKD to measure their blood pressure at home' as actionText,
	--'measure' actions
	(@measureActionsProportion) as proportion,
	'Reasoning' +
		'<ul><li>' + 
			STR(@measureActionsProportion)
		+ 'of CKD patients not meeting the CKD BP indicator have suggested ''measured'' actions (e.g. have not had their BP measured, or are just over their target).</li>' +
		'<li>This could be achieved by asking patients to measure their own BP.</li>' +
	'Useful information' + 
		'<ul><li>'  + (select text from regularText where textId = 'linkBhsHbpmProtocol') + '</li>' +
		'<ul><li>'  + (select text from regularText where textId = 'linkBhsHbpmHowToPatients') + '</li>' +
		'<ul><li>'  + (select text from regularText where textId = 'linkBhsHbpmPil') + '</li>' +
		'<ul><li>'  + (select text from regularText where textId = 'linkBhsHbpmDiary') + '</li>' +
		'<ul><li>'  + (select text from regularText where textId = 'linkBhsHbpmGuide') + '</li>' +
		'<ul><li>'  + (select text from regularText where textId = 'linkBhsHbpmCaseStudies') + '</li>' +
		'</ul>' 
		as supportingText

union

--VACCINATION CLINICS
select
	'ckd.treatment.bp' as indicatorId,
	'Take blood pressure readings during upcoming vaccination programmes e.g. flu, shingles, whooping cough.' as actionText,
	--'measure' actions
	(@measureActionsProportion) as proportion,
	'Reasoning' +
		'<ul><li>' + 
			STR(@measureActionsProportion)
		+ 'of CKD patients not meeting the CKD BP indicator have suggested ''measured'' actions (e.g. have not had their BP measured, or are just over their target).</li>' +
		'</ul>' 
		as supportingText

union

--LIFESTYLE
select
	'ckd.treatment.bp' as indicatorId,
	'Reinforce lifestyle advice to patients with CKD at every appointment' as actionText,
	--uncontrolled
	(@uncontrolledProportion) as proportion,
	'Reasoning' +
		'<ul><li>' + STR(@uncontrolledProportion) 
		+ 'of CKD patients not meeting the CKD BP indicator have uncontrolled blood pressure.</li>' +
		'<li>Advice on diet, exercise, alcohol reduction, weight loss, smoking cessation and exercise can help reduce blood pressure.</li>' +
	'Useful information' + 
		'<ul><li>'  + (select text from regularText where textId = 'DashDietSheet') + '</li>' +
		'<ul><li>'  + (select text from regularText where textId = 'HtnDietExSheet') + '</li>' +
		'<ul><li>'  + (select text from regularText where textId = 'BpUkDietSheet') + '</li>' +
		'<ul><li>'  + (select text from regularText where textId = 'BpExSheet') + '</li>' +
		'</ul>' 
		as supportingText

							---------------------------------------------------------------
							----------------------TEXT FILE OUTPUTS------------------------
							---------------------------------------------------------------
insert into [pingr.text] (indicatorId, textId, text)

values
--overview tab
('ckd.treatment.bp','name','CKD blood pressure control'), --overview table name
('ckd.treatment.bp','tabText','CKD BP'), --indicator tab text
('ckd.treatment.bp','description', --'show more' on overview tab
	'<strong>Definition:</strong>Patients on the CKD register with a BP recorded in the last 12 months (from last April) where the latest BP is 140/90 or less.<br>' + --Informatica doc
	'<strong>Why this is important:</strong>Cardiovascular disease is the biggest cause of death in CKD patients. The risk of major cardiovascular events can be reduced by about 1/6 per 5 mmHg reduction in systolic BP.<br>' +
	'<strong>Useful information:</strong>' +
	'<ul><li>'  + (select text from regularText where [textId] = 'linkBmjCkdBp') + '</li>' + 
	'<li>'  + (select text from regularText where [textId] = 'linkNiceBpTargetsCkd') + '</li>' +	
	'<li>'  + (select text from regularText where [textId] = 'linkNiceBpMxCkd') + '</li>' +	
	'<li>'  + (select text from regularText where [textId] = 'linkSsCkdAki') + '</li>' +	
	'<li>'  + (select text from regularText where [textId] = 'linkPilCkdBp') + '</li></ul>'),
--indicator tab
--summary text
('ckd.treatment.bp','tagline','of your patients on the CKD register have had a BP measurement in the 12 months (from last April) where the latest BP is <a href=''http://cks.nice.org.uk/chronic-kidney-disease-not-diabetic#!scenariorecommendation:5'' target=''_blank'' title="NICE BP targets in CKD">140/90 or less</a>.'),
('ckd.treatment.bp','positiveMessage','Well done! For tips on how to improve further, look through the recommended improvement actions on this page and for each patient.'),
--pt lists
('ckd.treatment.bp','valueId','SBP'),
('ckd.treatment.bp','valueName','Latest SBP'),
('ckd.treatment.bp','dateORvalue','value'),
('ckd.treatment.bp','tableTitle','All patients with improvement opportunities'),

--imp opp charts 
--based on actionCat

--registered?
('ckd.treatment.bp','opportunities.Registered?.name','Check registered'),
('ckd.treatment.bp','opportunities.Registered?.description','Patients who have not had contact with your practice in the last 12 months - are they still registered with you?'),
('ckd.treatment.bp','opportunities.Registered?.positionInBarChart','3'),

--Measure BP
('ckd.treatment.bp','opportunities.Measure BP.name','Measure BP'),
('ckd.treatment.bp','opportunities.Measure BP.description','Patients who may achieve the indicator by simply re-measuring their BP i.e. those without a BP reading, or with a one-off high reading, recent medication optimisation, or only slightly uncontrolled BP.'),
('ckd.treatment.bp','opportunities.Measure BP.positionInBarChart','1'),

--MEDICATION SUGGESTION
('ckd.treatment.bp','opportunities.Medication optimisation.name','Medication suggestion'),
('ckd.treatment.bp','opportunities.Medication optimisation.description','Patients with uncontrolled BP who are prescribed suboptimal medication.'),
('ckd.treatment.bp','opportunities.Medication optimisation.positionInBarChart',	'2'),

--SUGGEST EXCLUDE
('ckd.treatment.bp','opportunities.Suggest exclude.name','Suggest exclude'),
('ckd.treatment.bp','opportunities.Suggest exclude.description','Patients who may benefit from being excluded from this quality indicators.'),
('ckd.treatment.bp','opportunities.Suggest exclude.positionInBarChart',	'4')