IF EXISTS(SELECT * FROM sys.objects WHERE Type = 'P' AND Name ='pingr.run-all') DROP PROCEDURE [pingr.run-all];

GO
CREATE PROCEDURE [pingr.run-all] @ReportDate VARCHAR(10)
AS
SET NOCOUNT ON --exclude row count results for call from R

							---------------------------------------------------------------
							--------------CREATE TABLES USED BY STORED PROCEDURES----------
							---------------------------------------------------------------
							--------------i.e.data unique to each indicator query----------
							---------------------------------------------------------------

--Pt-level data: improvement opportunity categories and actions
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[output.pingr.impOppCatsAndActions]') AND type in (N'U')) DROP TABLE [dbo].[output.pingr.impOppCatsAndActions]
CREATE TABLE [output.pingr.impOppCatsAndActions] (PatID int, indicatorId varchar(1000), impOppCat varchar(1000), action varchar(1000), short_action varchar(1000), long_action varchar(1000), reason varchar(1000), evidence varchar(1000))

--Pt-level data: Important codes
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[output.pingr.impCodes]') AND type in (N'U')) DROP TABLE [dbo].[output.pingr.impCodes]
CREATE TABLE [output.pingr.impCodes] (PatID int, date date, importantCode varchar(100))

--Quality indicator results
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[output.pingr.indicator]') AND type in (N'U')) DROP TABLE [dbo].[output.pingr.indicator]
CREATE TABLE [output.pingr.indicator] (indicatorId varchar(1000), practiceId varchar(1000), date date, numerator int, denominator int, target float)

--Patient-practice lookup table
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ptPractice]') AND type in (N'U')) DROP TABLE [dbo].[ptPractice]
CREATE TABLE [ptPractice] (PatID int, pracID varchar(1000))
insert into ptPractice
select patid, gpcode from patients

							---------------------------------------------------------------
							---------------------EXECUTE STORED PROCEDURES-----------------
							---------------------------------------------------------------

DECLARE	@return_value int

EXEC	@return_value = [dbo].[pingr.ckd.coding]
		@refdate = @ReportDate
IF @return_value != 0 
BEGIN
	SELECT 1001;
	RETURN;
END

EXEC	@return_value = [dbo].[pingr.ckd.undiagnosed]
		@refdate = @ReportDate
IF @return_value != 0 
BEGIN
	SELECT 1001;
	RETURN;
END

EXEC	@return_value = [dbo].[pingr.ckd.monitoring]
		@refdate = @ReportDate
IF @return_value != 0 
BEGIN
	SELECT 1001;
	RETURN;
END
							---------------------------------------------------------------
							---------CREATE AND POPULATE PATIENT-LEVEL DATA TABLES---------
							---------------------------------------------------------------
							--------------i.e. data common to all queries------------------
							---------------------------------------------------------------

--physiological measures
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[output.pingr.measures]') AND type in (N'U')) DROP TABLE [dbo].[output.pingr.measures]
CREATE TABLE [output.pingr.measures] (PatID int, date date, measure varchar(100), value float)
insert into [output.pingr.measures](PatID, date, measure, value)
select PatID, EntryDate as date,
	case
		when ReadCode in (select code from codeGroups where [group] = 'egfr') then 'eGFR'
		when ReadCode in (select code from codeGroups where [group] = 'acr') then 'ACR'
	end as measure,
CodeValue as value from SIR_ALL_Records
where ReadCode in (select code from codeGroups where [group] in ('egfr','acr'))
	and CodeValue is not NULL
	and PatID in (select distinct PatID from [dbo].[output.pingr.impOppCatsAndActions])

--Contacts
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[output.pingr.contacts]') AND type in (N'U')) DROP TABLE [dbo].[output.pingr.contacts]
CREATE TABLE [output.pingr.contacts] (PatID int, date date, event varchar(100))
	DECLARE	@FACE int;
	DECLARE	@TELE int;
	DECLARE	@REC int;
	DECLARE	@CON int;
	DECLARE	@MED int;
	DECLARE	@OTH int;
	set @TELE = 5;
	set @FACE = 4;
	set @CON = 3;
	set @MED = 2;
	set @REC = 1;
	set @OTH = 0;
insert into [output.pingr.contacts](PatID, date, event)
select PatID, date, 
	case
		when eventcode = 5 then 'Telephone contact'
		when eventcode = 4 then 'Face-to-face'
		when eventcode <=3 then 'Other contact'
		end as event from 
			(
				select PatID,
				max(
					case 
						when (ReadCode like 'ALLERGY%' OR ReadCode like 'EMIS' OR ReadCode like 'EGTON' OR ReadCode like 'CLEAT') then @CON
						when LEN(ReadCode) >= 8 then @MED
						when LEN(ReadCode) = 6 then @MED
						when ReadCode like '[ABCDEFGHIJKLMNOPQRSTUVWXYZ][ABCDEFGHIJKLMNOPQRSTUVWXYZ][ABCDEFGHIJKLMNOPQRSTUVWXYZ][ABCDEFGHIJKLMNOPQRSTUVWXYZ]___' THEN @MED
						when LEN(ReadCode) <=4 then @OTH
						when ReadCode like '[ABCDEFGHIJKLMNOPQRSTUVWXYZ]%' then @CON
						when ReadCode like '[abcdefghijklmnopqrstuvwxyz]%' then @MED
						when ReadCode like '0%' then @CON
						when ReadCode like '1%' then @CON
						when ReadCode like '2%' then @FACE
						when ReadCode like '3%' then @CON
						when ReadCode like '4%' then @REC
						when ReadCode like '5%' then @REC
						when ReadCode in ('6A2..','6A9..','6AA..','6AB..','662d.','662e.','66AS.','66AS0','66AT.','66BB.','66f0.','66YJ.','66YM.','661Q.','66480','6AH..','6A9..','66p0.','6A2..','66Ay.','66Az.','69DC.') then @FACE --annual review
						when ReadCode like '6A%' then @FACE --patient reviewed
						when ReadCode like '65%' then @FACE
						when ReadCode like '6%' then @CON
						when ReadCode like '7%' then @REC
						when ReadCode like '8B31[356]%' then @FACE
						when ReadCode like '8B3[3569ADEfilOqRxX]%' then @FACE
						when ReadCode like '8B3[168hHjklNSTUVy]%' then @MED
						when ReadCode like '8B4%' then @MED
						when ReadCode like '8B%' then @CON
						when ReadCode in ('8BS3.') then @FACE
						when ReadCode like '8H[1-3]%' then @REC
						when ReadCode like '8H[4-8]%' then @FACE
						when ReadCode like '8H9%' then @TELE
						when ReadCode like '8H[ABCDHKMPQRSTUVWYZpckenmojiklprs]%' then @CON
						when ReadCode like '8H[EFGIJLNOXdabgfhqtuvwxyz]%' then @REC
						when ReadCode like '8[^BH]%' then @CON
						when ReadCode like '94Z%' then @FACE
						when ReadCode like '9N1C%' then @FACE
						when ReadCode like '9N21%' then @FACE
						when ReadCode like '9N31%' then @TELE
						when ReadCode like '9N3G%' then @CON
						when ReadCode like '9N3A%' then @TELE
						when ReadCode like '9%' then @REC
						when ReadCode in ('9kF1.','9kR..','9HB5.') then @FACE --patient reviewed / annual review
						when ReadCode like '9H9%' then @FACE
						when ReadCode like '~%' then @CON
						when ReadCode like '$%' then @REC
						else @CON end
					) as eventcode,
					EntryDate as date from SIR_ALL_Records
					where PatID in (select distinct PatID from [dbo].[output.pingr.impOppCatsAndActions])
					group by EntryDate, PatID
			) sub

--Diagnoses
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[output.pingr.diagnoses]') AND type in (N'U')) DROP TABLE [dbo].[output.pingr.diagnoses]
CREATE TABLE [output.pingr.diagnoses] (PatID int, date date, diagnosis varchar(100), subcategory varchar(100))
insert into [output.pingr.diagnoses](PatID, date, diagnosis, subcategory)
select PatID, EntryDate as date,
	case
		when ReadCode in (select code from codeGroups where [group] in ('ckd35','ckdPermEx')) then 'CKD'
	end as diagnosis,
	case
		when ReadCode in ('1Z12.','K053.') then 'G3'
		when ReadCode in ('1Z13.','K054.') then 'G4'
		when ReadCode in ('1Z14.','K055.') then 'G5'
		when ReadCode in ('1Z15.') then 'G3a'
		when ReadCode in ('1Z16.') then 'G3b'
		when ReadCode in ('1Z1B.') then 'G3 A2/3'
		when ReadCode in ('1Z1C.') then 'G3 A1'
		when ReadCode in ('1Z1D.') then 'G3a A2/3'
		when ReadCode in ('1Z1E.', '1Z1T.') then 'G3a A1'
		when ReadCode in ('1Z1F.') then 'G3b A2/3'
		when ReadCode in ('1Z1G.', '1Z1X.') then 'G3b A1'
		when ReadCode in ('1Z1H.') then 'G4 A2/3'
		when ReadCode in ('1Z1J.', '1Z1a.') then 'G4 A1'
		when ReadCode in ('1Z1K.') then 'G5 A2/3'
		when ReadCode in ('1Z1L.', '1Z1d.') then 'G5 A1'
		when ReadCode in ('1Z1V.') then 'G3a A2'
		when ReadCode in ('1Z1W.') then 'G3a A3'
		when ReadCode in ('1Z1Y.') then 'G3b A2'
		when ReadCode in ('1Z1Z.') then 'G3b A2'
		when ReadCode in ('1Z1b.') then 'G4 A2'
		when ReadCode in ('1Z1c.') then 'G4 A3'
		when ReadCode in ('1Z1e.') then 'G5 A2'
		when ReadCode in ('1Z1f.') then 'G5 A3'
		when ReadCode in ('2126E') then 'CKD resolved'
		when ReadCode in ('1Z10.') then 'G1'
		when ReadCode in ('1Z11.') then 'G2'
		when ReadCode in ('1Z17.') then 'G1 A2/A3'
		when ReadCode in ('1Z18.', '1Z1M.') then 'G1 A1'
		when ReadCode in ('1Z19.') then 'G2 A2/A3'
		when ReadCode in ('1Z1A.', '1Z1Q.') then 'G2 A1'
		when ReadCode in ('1Z1N.') then 'G1 A2'
		when ReadCode in ('1Z1P.') then 'G1 A3'
		when ReadCode in ('1Z1R.') then 'G2 A2'
		when ReadCode in ('1Z1S.') then 'G2 A3'
		when ReadCode in ('K051.') then 'G1'
		when ReadCode in ('K052.') then 'G2'
	end as subcategory from SIR_ALL_Records
where ReadCode in (select code from codeGroups where [group] in ('ckd35','ckdPermEx'))
and PatID in (select distinct PatID from [dbo].[output.pingr.impOppCatsAndActions])

--Demographics
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[output.pingr.demographics]') AND type in (N'U')) DROP TABLE [dbo].[output.pingr.demographics]
CREATE TABLE [output.pingr.demographics] (PatID int, nhsNumber bigint, age int, sex varchar(100), pracID varchar(1000))
insert into [output.pingr.demographics]
select p.patid, n.nhsNumber, YEAR (@ReportDate) - year_of_birth as age, sex, gpcode from dbo.patients p
inner join patientsNHSNumbers n on n.patid = p.patid
where p.patid in (select distinct PatID from [dbo].[output.pingr.impOppCatsAndActions])

SELECT 0
RETURN