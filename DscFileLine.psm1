
class Reason {
    [DscProperty()]
    [string] $Code

    [DscProperty()]
    [string] $Phrase
}

[DscResource()]
class DscFileLine {

    # https://docs.microsoft.com/de-de/powershell/scripting/dsc/resources/authoringresourceclass?view=powershell-7.1
    [DscProperty(Key)]
    [string] $FilePath

    [DscProperty(Key)]
    [string] $ContainsLine

    [DscProperty()]
    [string] $DoesNotContainPattern

    [DscProperty(NotConfigurable)]
    [Reason[]] $reasons

    [DscProperty(NotConfigurable)]
    [string] $status = "success"

    # Gets the resource's current state.
    [DscFileLine] Get() {

        $currentState = [DscFileLine]::new()
        $this.reasons = @()
        $currentState.reasons = $this.reasons
        $currentState.ContainsLine = $this.ContainsLine
        $currentState.DoesNotContainPattern = $this.DoesNotContainPattern
        $result = TestTargetResource -FilePath $this.FilePath -ContainsLine $this.ContainsLine -DoesNotContainPattern $this.DoesNotContainPattern

        $Phrase = "Test has returned a unknown result"
        switch ($result) {
            $true { $Phrase = "Test has returned a true result" }
            $false { $Phrase = "Test has returned a false result" }
        }

        $this.reasons += @{
            Code   = 'DscFileLine:DscFileLine:Result'
            Phrase = $Phrase
        }

        return $currentState
    }

    # Sets the desired state of the resource.
    [void] Set() {
        SetTargetResource -FilePath $this.FilePath -ContainsLine $this.ContainsLine -DoesNotContainPattern $this.DoesNotContainPattern
    }

    # Tests if the resource is in the desired state.
    [bool] Test() {
        return TestTargetResource -FilePath $this.FilePath -ContainsLine $this.ContainsLine -DoesNotContainPattern $this.DoesNotContainPattern
    }
}

function SetTargetResource {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $FilePath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.String]
        $ContainsLine,

        [Parameter()]
        [System.String]
        $DoesNotContainPattern
    )

    Write-Verbose "Begin processing file."
    if(Select-String -Path $FilePath -Pattern $ContainsLine -SimpleMatch -Encoding UTF8 -Quiet) {
        Write-Verbose "Line is present in the file."
    } else {
        Add-Content -Path $FilePath -Value $ContainsLine -Encoding UTF8 -Force
        Write-Verbose "Line had not been present in the file. Adding at the end of the file."
    }

    # DoesNotContainPattern is optional
    if ($null -ne $DoesNotContainPattern) {
        # Set Text to File Content Except Lines Matching DoesNotContainPattern Regex
        Set-Content -Path $FilePath -Value (Get-Content -Path $FilePath | Select-String -Pattern $DoesNotContainPattern -NotMatch) -Encoding UTF8 -Force
    }
    Write-Verbose "End processing file."
}

function TestTargetResource {
    [OutputType([System.Boolean])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $FilePath,

        [Parameter()]
        [ValidateNotNull()]
        [System.String]
        $ContainsLine,

        [Parameter()]
        [System.String]
        $DoesNotContainPattern
    )

    Write-Verbose "Begin executing test script."
    if(Test-Path -Path $FilePath -PathType Leaf){
        Write-Verbose "Filepath does not point to a file"
        return $false
    }

    try {
        # Attempts to open File with Write Permission (without changing anything)
        [io.file]::OpenWrite($FilePath).Close()
    }
    catch {
        Write-Verbose "Filepath is not writeable with user context"
        return $false
    }

    Write-Verbose "End Test Configuration File."
    return $true
}
