
DECLARE @ProcName VARCHAR(100) = ''

SELECT 
  job_name = j.name, 
  s.step_name
FROM msdb.dbo.sysjobs AS j
INNER JOIN msdb.dbo.sysjobsteps AS s
ON j.job_id = s.job_id
WHERE s.command LIKE '%' + @ProcName + '%';


SELECT 
	o.name
	,o.*
 FROM syscomments AS c
 INNER JOIN sysobjects AS o
 ON c.id = o.id
 WHERE c.text LIKE '%' + @ProcName + '%';

