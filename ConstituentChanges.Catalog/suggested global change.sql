truncate table USR_CHANGEDCONSTITUENTS;

set nocount on;
if object_id('tempdb..#TMP_TEST') is not null drop table #TMP_TEST;
create table #TMP_TEST
(
  CONSTITUENTID uniqueidentifier
 ,CHANGETYPE nvarchar(100)
)
declare @now datetime = getdate();
declare @since datetime = @now - 60;
declare @CONSTITUENTID uniqueidentifier;
declare @CHANGETYPE nvarchar(100);
declare @changeagentid uniqueidentifier;
declare @recordsprocessed float = 0.0;
declare @starttime datetime = getdate();
declare @elapsedseconds int = 0;
declare @recspersec int = 0;
declare @recordsremaining int = 0;
declare @ETAseconds int = 0;
declare @percentcomplete float = 0;

exec dbo.USP_CHANGEAGENT_GETORCREATECHANGEAGENT @CHANGEAGENTID OUTPUT;

insert into #TMP_TEST
exec dbo.USR_USP_CHANGED_CONSTITUENTS @since
declare @finishcount float = @@rowcount;

declare LOOPER cursor forward_only for select constituentid, changetype from #TMP_TEST;
open LOOPER
fetch next from LOOPER into @CONSTITUENTID, @CHANGETYPE
WHILE @@FETCH_STATUS <> -1
begin
  IF @@FETCH_STATUS <> -2
  begin
    declare @id uniqueidentifier = newid();
    exec dbo.USR_USP_RECORD_CONSTITUENT_CHANGE @ID output,@CONSTITUENTID,@CHANGETYPE,@CHANGEAGENTID;

    set @recordsprocessed = @recordsprocessed + 1.0;

    if cast(@recordsprocessed as int) % 1000 = 0
    begin
      set @now = getdate();
      set @elapsedseconds = datediff(ss,@starttime,@now);
      set @recspersec = case when @elapsedseconds > 0 then @recordsprocessed / @elapsedseconds else 0 end;
      set @recordsremaining = @finishcount - @recordsprocessed;
      set @ETAseconds = case when @recspersec > 0 then @recordsremaining / @recspersec else 0 end
      set @percentcomplete = round(@recordsprocessed*100.0 / @finishcount*1.0,2);

      print 'Processed '
        + ltrim(rtrim(str(@recordsprocessed,25,0)))
        + ' of '
        + ltrim(rtrim(str(@finishcount,25,0)))
        + ' records ['
        + convert(nvarchar(100),@percentcomplete) 
        + '%] in '
        + convert(nvarchar(100),@elapsedseconds)
        + ' seconds ['
        + convert(nvarchar(100),@recspersec)
        + ' records / second]'
        + ' ETA '
        + convert(nvarchar(100),@ETAseconds)
        + ' seconds ('
        + convert(nvarchar(20),DATEADD(ss,@ETAseconds,getdate()))
        + ')'
    end
  end
  fetch next from LOOPER into @CONSTITUENTID, @CHANGETYPE
end
CLOSE LOOPER;
DEALLOCATE LOOPER;

select * from USR_CHANGEDCONSTITUENTS