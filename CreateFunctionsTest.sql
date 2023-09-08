-- =============================================
-- Author:		<Jimrey Benos>
-- Create date: <8/9/2023>
-- Description:	<Test scalar function>
-- =============================================
-- a scalar function only return 1 value per function

CREATE FUNCTION Test.ufnMyname
(
	
)
RETURNS VARCHAR(255)
AS
BEGIN
	-- Declare the return variable here
	DECLARE @ufnMyname AS NVARCHAR(255);

	-- Add the T-SQL statements to compute the return value here
	SELECT @ufnMyname= 'Jimrey';

	-- Return the result of the function
	RETURN @ufnMyname;

END
GO

SELECT Test.ufnMyname() AS Name;