Template to provision a Nerdio Manager for WVD using an existing SQL DB (if you have restriction to create new SQL DB in your current subscription), for tests/demo purposes.

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmatiasma%2Farm-templates%2Fmaster%2FNerdioManagerForWVD%2Fazuredeploy.json" target="_blank">
  <img src="http://azuredeploy.net/deploybutton.png"/>
</a>

If you are using an Azure SQL DB, please set the SQL Server firewall settings as the image below:

<img src="https://raw.githubusercontent.com/matiasma/arm-templates/master/NerdioManagerForWVD/sql-firewall.PNG">

To provision an production environment, please use the Nerdio marketplace offer: 
https://azuremarketplace.microsoft.com/en-us/marketplace/apps/nerdio.nerdio_wvd_manager?tab=Overview
