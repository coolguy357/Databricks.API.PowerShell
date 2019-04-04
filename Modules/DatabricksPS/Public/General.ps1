﻿#requires -Version 3.0

Function Invoke-DatabricksApiRequest
{
	<#
			.SYNOPSIS
			Lists all jobs or returns a specific job for a given JobID.
			.DESCRIPTION
			Lists all jobs or returns a specific job for a given JobID. 
			Official API Documentation: https://docs.databricks.com/api/latest/jobs.html#list
			Official API Documentation: https://docs.databricks.com/api/latest/jobs.html#get
			.PARAMETER Method 
			The type of request you want to invoke. Will usually be GET or POST
			.PARAMETER EndPoint
			The API endpoint that you want to invoke. Please check the API reference for valid values. Example: "/2.0/jobs/list"
			.PARAMETER Body
			Some endpoints also support a body to supply additional information. This can be specified here. For POST requests, this is usually a JSON-string whereas for GET it is usually a hashtable which is then converted to URL parameters
			.EXAMPLE
			Invoke-DatabricksApiRequest -Method GET -EndPoint "/2.0/jobs/list"
	#>
	[CmdletBinding()]
	param 
	(	
		[Parameter(Mandatory = $true, Position = 1)] [string] [ValidateSet("DEFAULT", "DELETE", "GET", "HEAD", "MERGE", "OPTIONS", "PATCH", "POST", "PUT", "TRACE")] $Method,
		[Parameter(Mandatory = $true, Position = 2)] [string] $EndPoint,
		[Parameter(Mandatory = $true, Position = 3)] $Body
	)
	Test-Initialized	 

	Write-Verbose "Setting final ApiURL ..."
	$apiUrl = Get-ApiUrl -ApiEndpoint $EndPoint
	Write-Verbose "API Call: $Method $apiUrl"
	
	#Set headers
	Write-Verbose "Building Headers ..."
	$headers = Get-RequestHeader
	Write-Verbose "Headers: `n$($headers | Out-String)"
	
	if($Method -eq "GET")
	{	
		Write-Verbose "GET request - showing URL parameters as Key-Value pairs ..."
		Write-Verbose "Body: `n$($Body | Out-String)"
	}
	else
	{
		# for POST requests we have to convert the body to JSON
		Write-Verbose "Non-GET request - converting Body to JSON ..."
		$Body = $Body | ConvertTo-Json -Depth 20
		
		Write-Verbose "Body: `n$($Body)"
	}
	
	$result = Invoke-RestMethod -Uri $apiUrl -Method $Method -Headers $headers -Body $Body
	
	Write-Verbose "Response: $($result | ConvertTo-Json -Depth 10)"
	
	return $result
}

Function Set-DatabricksEnvironment 
{
	<#
			.SYNOPSIS
			Sets global module config variables AccessToken, CloudProvider and ApirRootUrl    
			.DESCRIPTION
			Sets global module config variables AccessToken, CloudProvider and ApirRootUrl    
			.PARAMETER PBIAPIUrl
			The url for the PBI API
			.PARAMETER AccessToken
			The AccessToken to use to access the Databricks API
			For example: dapi1234abcd32101691ded20b53a1326285
			.PARAMETER ApiRootUrl
			The URL of the API. 
			For Azure, this could be 'https://westeurope.azuredatabricks.net'
			For AWS, this could be 'https://abc-12345-xaz.cloud.databricks.com'
			.PARAMETER CloudProvider
			The CloudProvider where the Databricks workspace is hosted. Can either be 'Azure' or 'AWS'.
			If not provided, it is derived from the ApiRootUrl parameter and/or the type of authentication
			
			.EXAMPLE
			Set-DatabricksEnvironment -AccessToken "dapi1234abcd32101691ded20b53a1326285" -ApiRootUrl "https://abc-12345-xaz.cloud.databricks.com"
			.EXAMPLE
			Set-DatabricksEnvironment -AccessToken "dapi1234abcd32101691ded20b53a1326285" -ApiRootUrl "https://westeurope.azuredatabricks.net"
	#>
	[CmdletBinding()]
	param
	(
		[Parameter(ParameterSetName = "DatabricksApi", Mandatory = $true, Position = 1)] [string] $AccessToken,

		[Parameter(Mandatory = $true, Position = 2)] [string] $ApiRootUrl,
		[Parameter(Mandatory = $false, Position = 3)] [string] [ValidateSet("Azure","AWS")] $CloudProvider = $null
	)

	Write-Verbose "Setting [System.Net.ServicePointManager]::SecurityProtocol to [System.Net.SecurityProtocolType]::Tls12 ..."
	[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
	Write-Verbose "Done!"
	
	Clear-ScriptVariables

	#region check CloudProvider
	$paramToCheck = 'CloudProvider'
	Write-Verbose "Checking if Parameter -$paramToCheck was provided ..."
	if($CloudProvider)
	{
		Write-Verbose "Parameter -$paramToCheck provided! Setting global $paramToCheck ..."
		$script:dbCloudProvider = $CloudProvider
		Write-Verbose "Done!"

		Write-Warning "Parameter -$paramToCheck is deprecated! The value for -$paramToCheck will be derived from the ApiRootUrl automatically instead!"
	}
	#endregion

	#region check ApiRootUrl
	$paramToCheck = 'ApiRootUrl'
	Write-Verbose "Checking if Parameter -$paramToCheck was provided ..."
	if($ApiRootUrl -ne $null)
	{
		Write-Verbose "$paramToCheck provided! Setting global $paramToCheck ..."
		$script:dbApiRootUrl = $ApiRootUrl.Trim('/') + "/api"
		Write-Verbose "Done!"
	}
	else
	{
		Write-Warning "Parameter -$paramToCheck was not provided!"
	}

	Write-Verbose "Trying to derive $paramToCheck from ApiRootUrl ..."
	Write-Verbose "Checking if ApiRootUrl contains '.azuredatabricks.' ..."
	if($ApiRootUrl -ilike "*.azuredatabricks.*")
	{
		Write-Verbose "'.azuredatabricks.' found in ApiRootUrl - Setting CloudProvider to 'Azure' ..."
		$script:dbCloudProvider = "Azure"
	}
	else
	{
		Write-Verbose "'.azuredatabricks.' not found in ApiRootUrl - Setting CloudProvider to 'AWS' ..."
		$script:dbCloudProvider = "AWS"
	}
	Write-Verbose "Done!"
	#endregion

	#region Databricks API Key
	if($PSCmdlet.ParameterSetName -eq "DatabricksApi")
	{
		Write-Verbose "Using Databricks API authentication via API Token ..."
		$script:dbAuthenticationProvider = "DatabricksApi" 
			
		$script:dbAuthenticationHeader = @{
			"Authorization" = "Bearer $AccessToken"
		}
	}
	#endregion
	
	$script:dbInitialized = $true
}

Function Test-DatabricksEnvironment
{
	<#
			.SYNOPSIS
			Runs the most simple operation possible that should work on any Databricks environment - listing all items in DBFS under "/"
			.DESCRIPTION
			Runs the most simple operation possible that should work on any Databricks environment - listing all items in DBFS under "/"
			Official API Documentation: https://docs.databricks.com/api/latest/workspace.html#list
			.EXAMPLE
			Test-DatabricksEnvironment
	#>
	[CmdletBinding()]
	param ()

	$requestMethod = "GET"
	$apiEndpoint = "/2.0/dbfs/list"		

	Write-Verbose "Building Body/Parameters for final API call ..."
	#Set parameters
	$parameters = @{
		path = "/" 
	}
	
	$result = Invoke-DatabricksApiRequest -Method $requestMethod -EndPoint $apiEndpoint -Body $parameters

	return $result.files
}

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
# http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

