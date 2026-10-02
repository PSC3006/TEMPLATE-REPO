@{
    # Tests benoetigen Pester >= 4 (nicht das in Windows mitgelieferte Pester 3.4): Kompatibilitaetsregel fuer
    # Befehle daher ohne Profil; Syntax-Kompatibilitaet 5.1 bleibt aktiv.
    Severity            = @('Error', 'Warning', 'Information')
    IncludeDefaultRules = $true
    Rules               = @{
        PSUseCompatibleSyntax = @{
            Enable         = $true
            TargetVersions = @('5.1')
        }
    }
}
