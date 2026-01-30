Set-StrictMode -Version Latest

Describe 'AGENTS.md source normalization' {
    BeforeAll {
        $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
        $scriptPath = Join-Path $script:repoRoot 'scripts\compose-agentsmd.ps1'
        . $scriptPath
    }

    It 'normalizes cached rule paths to GitHub sources' {
        $sourceInput = 'C:/Users/Origin/.agentsmd/cache/metyatech/agent-rules/abc123/rules/global/agent-rules-composition.md'
        $result = Convert-AgentsMdSourcePath -SourcePath $sourceInput -RepoRoot $script:repoRoot

        $result | Should -Be 'github:metyatech/agent-rules@abc123/rules/global/agent-rules-composition.md'
    }

    It 'normalizes repo-local absolute paths to relative paths' {
        $sourceInput = Join-Path $script:repoRoot 'agent-rules-local\local.md'
        $result = Convert-AgentsMdSourcePath -SourcePath $sourceInput -RepoRoot $script:repoRoot

        $result | Should -Be 'agent-rules-local/local.md'
    }

    It 'keeps relative paths intact' {
        $sourceInput = 'rules/global/agent-rules-composition.md'
        $result = Convert-AgentsMdSourcePath -SourcePath $sourceInput -RepoRoot $script:repoRoot

        $result | Should -Be 'rules/global/agent-rules-composition.md'
    }

    It 'fails on unknown absolute paths outside the repo' {
        { Convert-AgentsMdSourcePath -SourcePath 'C:\other\path\rule.md' -RepoRoot $script:repoRoot } | Should -Throw
    }

    It 'rewrites Source lines in AGENTS.md content' {
        $content = @(
            'Source: C:/Users/Origin/.agentsmd/cache/metyatech/agent-rules/abc123/rules/global/agent-rules-composition.md',
            '',
            '# Rules',
            '',
            'Source: C:/Users/Origin/.agentsmd/cache/metyatech/agent-rules/abc123/rules/global/another.md'
        ) -join "`r`n"

        $normalized = Convert-AgentsMdSourceContent -Content $content -RepoRoot $script:repoRoot

        $normalized.Content | Should -Match 'Source: github:metyatech/agent-rules@abc123/rules/global/agent-rules-composition.md'
        $normalized.Content | Should -Match 'Source: github:metyatech/agent-rules@abc123/rules/global/another.md'
    }
}
