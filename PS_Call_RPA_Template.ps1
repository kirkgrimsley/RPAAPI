

        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Accept", 'application/json')
		
		# ------------------------------USER INPUT SECTION------------------------------
		# Specify environment and process name------------------------------------------
		# ----Environment should be uppercase "DEV" "UAT" "PROD"
		# ----processName is case sensitive
		# ----argumentsPassed should be True or False
		
		$RPAEnvironment = "DEV"
		$processName = "BOT_CashFlowQueueUploader"
		$argumentsPassed = "True"
		
		# ----------------------------END USER INPUT SECTION----------------------------

		switch ($RPAEnvironment) {
			"DEV" 	{$orchastratorURL = "https://dev-rpa"}
			"UAT" 	{$orchastratorURL = "https://uat-rpa"}
			"PROD" 	{$orchastratorURL = "https://rpa"}
			default {$orchastratorURL = "https://dev-rpa"}
		}
		
		$encodedPassword = 'NkIjMTQhYUs='	# Encrypted password
		$decodedPassword = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($encodedPassword))
		$rawcreds = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $rawcreds.Add("tenancyName", '')
        $rawcreds.Add("usernameOrEmailAddress", 'RestAPIBOT')
		$rawcreds.Add("password", $decodedPassword)

 
        $json = $rawcreds | ConvertTo-Json
        Write-Debug $json
 
        Invoke-RestMethod $orchastratorURL"/api/Account/Authenticate" -Headers $headers -Method POST -Body $json -ContentType "application/json" | Tee-Object -Variable result
        
        # This next bit is to take the token out of the response

        #write-Debug $result[0]
        $token = $result -join " "
        $token = $token.substring(9,$token.length-9-74)
        write-Debug $token
     
        $headers3 = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers3.Add("Accept", 'application/json')
        $headers3.Add("Authorization", 'Bearer ' + $token)

		# Getting list of RPA releases...
		
		$releaseJson = Invoke-RestMethod $orchastratorURL"/odata/Releases?" -Headers $headers3
		
		# Extracting just the ReleaseKey...
		
		$releaseKey = $releaseJson.Value | where { $_.ProcessKey -eq $processName } | select Key
		$releaseKey = ($releaseKey -replace '@{Key=','') -replace '}',''
	
        $startInfo = @{}
        $startInfo.Add("ReleaseKey", $releaseKey)
        $startInfo.Add("Strategy", 'JobsCount')
        $startInfo.Add("JobsCount", '1')
	    $startInfo.Add("Source", 'Manual')
		
		# If arguments needs to be passed 
		# --Format for Argument:
		# ----{argument1: value, argument2:value, etc}
		if ($argumentsPassed -eq 'True') {
			$startInfo.Add("InputArguments", '{PRODEnvironment: 1,Sponsor: "MS"}')
			}
			

        $processCall = @{}
        $processCall.Add("startInfo", $startInfo)
        $processCall = $processCall | ConvertTo-Json 

		# Starting job on Orchestrator...
		
 		Invoke-RestMethod $orchastratorURL"/odata/Jobs/UiPath.Server.Configuration.OData.StartJobs" -Headers $headers3 -Method POST -Body $ProcessCall -ContentType "application/json" | Tee-Object -Variable RPAkey