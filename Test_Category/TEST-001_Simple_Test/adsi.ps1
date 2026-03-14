# ============================================================================
# TEST-001: Simple Test Check
# ============================================================================
# Category: Test_Category
# Severity: INFO
# Description: Simple test script to verify scan execution works
# ============================================================================

# Output test findings in the expected format
$findings = @(
    [PSCustomObject]@{
        CheckID           = "TEST-001"
        CheckName         = "Simple Test Check"
        Label             = "Test Finding 1"
        Name              = "TestUser1"
        SamAccountName    = "testuser1"
        DistinguishedName = "CN=TestUser1,OU=Users,DC=test,DC=local"
        Severity          = "INFO"
        RiskScore         = 1
        MITRE             = "T1078"
        Description       = "This is a test finding to verify scan execution"
    },
    [PSCustomObject]@{
        CheckID           = "TEST-001"
        CheckName         = "Simple Test Check"
        Label             = "Test Finding 2"
        Name              = "TestUser2"
        SamAccountName    = "testuser2"
        DistinguishedName = "CN=TestUser2,OU=Users,DC=test,DC=local"
        Severity          = "INFO"
        RiskScore         = 1
        MITRE             = "T1078"
        Description       = "This is another test finding"
    }
)

# Output findings (will be piped through ConvertTo-Json by executor)
$findings
