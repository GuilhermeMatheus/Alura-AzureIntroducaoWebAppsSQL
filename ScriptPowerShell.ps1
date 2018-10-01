# Fazendo as coisas corretamente com um app maneiro:
# https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-authenticate-service-principal#create-service-principal-with-password

$ErrorActionPreference = "Stop"

# Import-AzureRmContext -Path C:\CasaDoCodigoAutomacao\azureRmContext.json

$regiao = 'South Central US'
$nomeRG = 'ps-casadocodigo-rg'

$diretorioAplicacao = "C:\CasaDoCodigoAutomacao\LojaCasaDoCodigo"

$servidorSqlNome = 'ps-casadocodigo-sql-srv'
$servidorSqlAdminNome = 'Administrador'
$servidorSqlAdminSenha = 'Alura!123'
$servidorSqlAdminSenhaSegura = ConvertTo-SecureString $servidorSqlAdminSenha -AsPlainText -Force
$servidorSqlCredenciais = New-Object System.Management.Automation.PSCredential ($servidorSqlAdminNome, $servidorSqlAdminSenhaSegura)

$nomeBancoDeDados = 'ps-casadocodigo-sql-bd'
$nomeAppServicePlan = 'ps-casadocodigo-appserviceplan'
$nomeWebApp = 'pscasadocodigo'

$ipInicialServidorSQL = '177.139.156.225'
$ipFinalServidorSQL = '177.139.156.225'

# Cria um novo Resource Group
Write-Host "Criando ResourceGroup" -ForegroundColor Green
New-AzureRmResourceGroup `
	-Name $nomeRG `
	-Location $regiao

# Cria um novo SQL Server
Write-Host "Criando Sql Server" -ForegroundColor Green
New-AzureRmSqlServer `
	-ServerName $servidorSqlNome `
	-ResourceGroupName $nomeRG `
	-Location $regiao `
	-SqlAdministratorCredentials $servidorSqlCredenciais

# Cria o Banco de Dados
Write-Host "Criando Banco de Dados" -ForegroundColor Green
New-AzureRmSqlDatabase `
	-ResourceGroupName $nomeRG `
	-ServerName $servidorSqlNome `
	-DatabaseName $nomeBancoDeDados `
	-MaxSizeBytes 50GB `
	-RequestedServiceObjectiveName "S0"
	
# Criação de regra de firewall no servidor SQL
# para a(s) máquina(s) de administração 
Write-Host "Criando Regra de Firewall de administração" -ForegroundColor Green
New-AzureRmSqlServerFirewallRule `
	-ResourceGroupName $nomeRG `
	-ServerName $servidorSqlNome `
	-FirewallRuleName "MaquinaAdministracao" `
	-StartIpAddress $ipInicialServidorSQL `
	-EndIpAddress $ipFinalServidorSQL

# Criação de regra de firewall no servidor SQL
# para a as máquinas do Azure
Write-Host "Criando Regra de Firewall para o Azure" -ForegroundColor Green
New-AzureRmSqlServerFirewallRule `
	-ResourceGroupName $nomeRG `
	-ServerName $servidorSqlNome `
	-FirewallRuleName "AllowAllWindowsAzureIps" `
	-StartIpAddress '0.0.0.0' `
	-EndIpAddress '0.0.0.0'

# Criação do plano do serviço de aplicativo
Write-Host "Criando AppServicePlan" -ForegroundColor Green
New-AzureRmAppServicePlan `
	-Name $nomeAppServicePlan `
	-Location $regiao `
	-ResourceGroupName $nomeRG `
	-Tier 'S1'

# Criação da WebApp...
Write-Host "Criando WebApp" -ForegroundColor Green
New-AzureRmWebApp `
	-ResourceGroupName $nomeRG `
	-Name $nomeWebApp `
	-Location $regiao `
	-AppServicePlan $nomeAppServicePlan

Write-Host "Todos os recursos criados." -ForegroundColor Green

Write-Host "Criando conexão com Banco de Dados para execução do script." -ForegroundColor Green

$scriptSQL = Get-Content .\Scripts.sql

$servidorSqlFQDN = (Get-AzureRmSqlServer `
	-ServerName $servidorSqlNome `
	-ResourceGroupName $nomeRG `
	).FullyQualifiedDomainName

$connectionString =
	"Data Source=$servidorSqlFQDN;" +
	"Initial Catalog=$nomeBancoDeDados;" +
	"User ID=$servidorSqlAdminNome;" +
	"Password=$servidorSqlAdminSenha;"

$connection = new-object system.data.SqlClient.SQLConnection($connectionString)
$command = new-object system.data.sqlclient.sqlcommand($scriptSQL, $connection)
$connection.Open()

$adapter = New-Object System.Data.sqlclient.sqlDataAdapter $command
$dataset = New-Object System.Data.DataSet
$adapter.Fill($dataSet) | Out-Null

$connection.Close()

Write-Host "Scripts de banco executados com sucesso!" -ForegroundColor Green

Write-Host "Buscando profile de publicação da WebApp." -ForegroundColor Green

$xmlPublicacao = 
	[xml](Get-AzureRmWebAppPublishingProfile `
		-Name $nomeWebApp `
		-ResourceGroupName $nomeRG `
		-OutputFile null)

$username = $xmlPublicacao.SelectNodes("//publishProfile[@publishMethod=`"FTP`"]/@userName").value
$password = $xmlPublicacao.SelectNodes("//publishProfile[@publishMethod=`"FTP`"]/@userPWD").value
$url = $xmlPublicacao.SelectNodes("//publishProfile[@publishMethod=`"FTP`"]/@publishUrl").value

$networkCredential = New-Object System.Net.NetworkCredential($username,$password)

Set-Location $diretorioAplicacao

$diretorios =	
	Get-ChildItem -Directory -Recurse |
	Sort-Object {$_.FullName.Length}

$arquivos =
	Get-ChildItem -Path $diretorioAplicacao -Recurse |
	Where-Object {!($_.PSIsContainer)}

Write-Host "Criando diretórios da aplicação" -ForegroundColor Green

foreach ($diretorio in $diretorios)
{
	$relativepath = (Resolve-Path -Path $diretorio.FullName -Relative).Replace(".\", "").Replace('\', '/')
	$uri = New-Object System.Uri("$url/$relativepath")
	$ftprequest = [System.Net.FtpWebRequest]::Create($uri);
	$ftprequest.Method = [System.Net.WebRequestMethods+Ftp]::MakeDirectory
	$ftprequest.UseBinary = $true
  
	$ftprequest.Credentials = $networkCredential
	
	Write-Host ("Criando diretório: " + $uri.AbsoluteUri) -ForegroundColor Yellow  
	$response = $ftprequest.GetResponse();
	Write-Host Upload File Complete, status $response.StatusDescription

  	$response.Close();
}

Write-Host "Realizando upload dos arquivos" -ForegroundColor Green

$webclient = New-Object -TypeName System.Net.WebClient
$webclient.Credentials = $networkCredential

foreach ($arquivo in $arquivos)
{
    $relativepath = (Resolve-Path -Path $arquivo.FullName -Relative).Replace(".\", "").Replace('\', '/')
    $uri = New-Object System.Uri("$url/$relativepath")
    Write-Host ("Fazendo upload para: " + $uri.AbsoluteUri) -ForegroundColor Yellow
    $webclient.UploadFile($uri, $arquivo.FullName)
} 

$webclient.Dispose()

Write-Host "Atualizando ConnectionString" -ForegroundColor Green

Set-AzureRMWebApp `
	-Name $nomeWebApp `
	-ResourceGroupName $nomeRG `
	-ConnectionStrings @{
		Default = @{
			Type="SQLAzure";
			Value ="Server=tcp:$servidorSqlFQDN;" +
				"Database=$nomeBancoDeDados;" +
				"User ID=casaDoCodigoWebApp;" +
				"Password=SenhaAplicacao!;" +
				"Trusted_Connection=False;" +
				"Encrypt=True;"
			}
		}