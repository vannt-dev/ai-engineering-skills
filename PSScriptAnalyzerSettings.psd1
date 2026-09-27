@{
    # an explicit settings file replaces repokeeper's default filter, so keep it here
    Severity     = @('Error', 'Warning')
    # the test tooling reports to the console and builds throwaway fixtures
    ExcludeRules = @('PSAvoidUsingWriteHost', 'PSUseShouldProcessForStateChangingFunctions')
}
