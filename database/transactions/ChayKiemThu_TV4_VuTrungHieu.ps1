param(
 [string]$Server = '.\SQLEXPRESS',
 [ValidatePattern('^QLToaNha_TV4_Test[A-Za-z0-9_]*$')]
 [string]$Database = 'QLToaNha_TV4_Test_18Bang',
 [switch]$DongThoi
)
$ErrorActionPreference = 'Stop'
$sqlcmd = (Get-Command sqlcmd -ErrorAction Stop).Source
$work = Join-Path $PSScriptRoot ('KetQua_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Path $work | Out-Null
$log = Join-Path $work 'KetQua_SQLServer.txt'
function Run-Sql([string]$file, [string]$db = $Database) {
 $output = & $sqlcmd -S $Server -E -C -b -r 1 -d $db -i $file 2>&1
 $code = $LASTEXITCODE
 $output | Tee-Object -FilePath $log -Append | Write-Host
 if ($code -ne 0) { throw "Dung tai $file. Xem $log" }
}
function Save-Sql([string]$name,[string]$text) {
 $path=Join-Path $work $name
 [System.IO.File]::WriteAllText($path,$text,(New-Object System.Text.UTF8Encoding($true)))
 return $path
}
$guard = Save-Sql '00_Guard.sql' "IF DB_ID(N'$Database') IS NOT NULL THROW 59800,N'Database test da ton tai. Hay doi -Database sang ten moi.',1;"
Run-Sql $guard 'master'
# TV6 sửa: runner dùng nguồn TV3 chuẩn và cài TV5 trước TV4; NguonTV3 chỉ là bản sao lịch sử.
$dbRoot = Split-Path $PSScriptRoot -Parent
$schemaPath = Join-Path $dbRoot 'schema'
$triggersPath = Join-Path $dbRoot 'triggers'
foreach ($name in @('01_CreateSchema_TV3_NguyenThiLanAnh.sql','02_InsertSeedData_TV3_NguyenThiLanAnh.sql','03_Validate_TV3_NguyenThiLanAnh.sql')) {
 $source=Join-Path $schemaPath $name
 $text=[System.IO.File]::ReadAllText($source).Replace('QLToaNha_BCNF',$Database)
 $file=Save-Sql $name $text
 Run-Sql $file 'master'
}
Run-Sql (Join-Path $triggersPath '05_Phan5_Triggers_TV5_KhucTuanAnh.sql')
foreach ($name in @('02_KiemTraTuongThich_TV4_VuTrungHieu.sql','00_TaoKieuDuLieu_TV4_VuTrungHieu.sql',
 '03_Transactions_TV4_VuTrungHieu.sql','04_KiemThu_TV4_VuTrungHieu.sql','06_DoiChieuSeed_TV4_VuTrungHieu.sql')) {
 Run-Sql (Join-Path $PSScriptRoot $name)
}
if ($DongThoi) {
 $setup=Save-Sql 'Concurrent_Setup.sql' @'
INSERT dbo.VanPhong(MaVanPhong,MaToaNha,MaViTri,Tang,DienTich) VALUES('ZH_P3','ZH_TN','ZH_VT',1,20);
GO
CREATE OR ALTER TRIGGER dbo.Test_TV4_ChoDongThoi ON dbo.HopDongThue AFTER INSERT AS
BEGIN
 IF EXISTS(SELECT 1 FROM inserted WHERE MaVanPhong='ZH_P3') WAITFOR DELAY '00:00:03';
END;
GO
'@
 $call=Save-Sql 'Concurrent_Call.sql' @'
SET NOCOUNT ON;
DECLARE @P dbo.TT_DanhSachPhong;
INSERT @P VALUES('ZH_P3');
BEGIN TRY
 EXEC dbo.USP_Trx_KyHopDongThueMatBang 'ZH_CT','ZH_TN','20400101','20400131',@P;
 PRINT 'TV4_CONC_OK';
END TRY
BEGIN CATCH
 IF ERROR_NUMBER()<>51106 THROW;
 PRINT 'TV4_CONC_DUP';
END CATCH;
'@
 $cleanup=Save-Sql 'Concurrent_Cleanup.sql' @'
IF OBJECT_ID('dbo.Test_TV4_ChoDongThoi','TR') IS NOT NULL DROP TRIGGER dbo.Test_TV4_ChoDongThoi;
IF (SELECT COUNT(*) FROM dbo.HopDongThue WHERE MaVanPhong='ZH_P3')<>1
 THROW 59801,N'Khong dung mot dong thue phong khi test dong thoi.',1;
'@
 Run-Sql $setup
 try {
  $common=@('-S',$Server,'-E','-C','-b','-d',$Database,'-i',$call)
  $a=Start-Job -ScriptBlock { param($bin,$argsList) & $bin @argsList 2>&1; if($LASTEXITCODE -ne 0){throw 'SQL A failed'} } -ArgumentList $sqlcmd,$common
  $b=Start-Job -ScriptBlock { param($bin,$argsList) & $bin @argsList 2>&1; if($LASTEXITCODE -ne 0){throw 'SQL B failed'} } -ArgumentList $sqlcmd,$common
  $a,$b | Wait-Job | Out-Null
  $result=@(Receive-Job $a -ErrorAction Stop; Receive-Job $b -ErrorAction Stop)
  $result | Tee-Object -FilePath $log -Append | Write-Host
  $all=$result -join "`n"
  if(([regex]::Matches($all,'TV4_CONC_OK')).Count -ne 1 -or ([regex]::Matches($all,'TV4_CONC_DUP')).Count -ne 1) {
   throw 'Test dong thoi chua dat: can dung 1 OK va 1 DUP.'
  }
 } finally { Run-Sql $cleanup }
 Run-Sql (Join-Path $PSScriptRoot '05_KiemThu_DongThoi.sql')
}
Write-Host "Da chay xong. Bang chung thuc te nam tai $log"
