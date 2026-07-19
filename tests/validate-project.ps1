$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$failures = [System.Collections.Generic.List[string]]::new()

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { $script:failures.Add($Message) }
}

function Read-ProjectFile {
    param([string]$RelativePath)
    $path = Join-Path $root $RelativePath
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "missing file: $RelativePath"
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        return Get-Content -LiteralPath $path -Raw -Encoding UTF8
    }
    return ''
}

$workflow = Read-ProjectFile '.github/workflows/bug-finder.yml'
$installer = Read-ProjectFile 'scripts/install-runtime.sh'
$poller = Read-ProjectFile 'scripts/poll-issues.sh'
$gate = Read-ProjectFile 'scripts/gate.sh'
$backlog = Read-ProjectFile 'docs/backlog.md'
$issueLog = Read-ProjectFile 'docs/issue-log.md'
$resolver = Read-ProjectFile 'scripts/resolve-repo.sh'

# src (this plugin's layout) -> dst (target repo's .claude/-relative layout)
$runtimeFiles = @(
    @{ src = 'runtime-version'; dst = '.claude/runtime-version' },
    @{ src = '.github/workflows/bug-finder.yml'; dst = '.github/workflows/bug-finder.yml' },
    @{ src = 'agents/pr-reviewer.md'; dst = '.claude/agents/pr-reviewer.md' },
    @{ src = 'scripts/ci-guard.sh'; dst = '.claude/scripts/ci-guard.sh' },
    @{ src = 'scripts/ci-pr-meta-check.sh'; dst = '.claude/scripts/ci-pr-meta-check.sh' },
    @{ src = 'docs/review-rubric.md'; dst = 'docs/review-rubric.md' }
)
foreach ($file in $runtimeFiles) {
    $pair = '"' + $file.src + ':' + $file.dst + '"'
    Assert-True ($installer.Contains($pair)) "installer does not deploy $($file.dst)"
}

Assert-True ($workflow -match 'actions/checkout@[0-9a-f]{40}') 'checkout action is not pinned to a full SHA'
Assert-True ($workflow -match 'persist-credentials:\s*false') 'checkout credentials are persisted'
Assert-True ($workflow -match 'timeout-minutes:\s*[1-9]') 'review job has no timeout'
Assert-True ($workflow -match 'head\.repo\.full_name == github\.repository') 'fork PRs are not excluded'
Assert-True ($workflow -match 'claude -p --tools ""') 'Claude reviewer tools are not disabled'
Assert-True ($workflow -match 'max_bytes=') 'review input has no size cap'

Assert-True ($poller.Contains('key="$REPO_SLUG#$num"')) 'issue poller does not use a repository-qualified key'
Assert-True ($backlog.Contains('owner/repo#issue')) 'backlog does not document the composite identity'
Assert-True ($issueLog.Contains('owner/repo#issue')) 'issue log does not document the composite identity'
Assert-True ($gate.Contains('gate: INCONCLUSIVE')) 'gate cannot report inconclusive verification'
Assert-True ($gate.Contains('exit 2')) 'inconclusive gate does not return a distinct failure code'
Assert-True ($resolver.Contains('git rev-parse --show-toplevel')) 'repository resolver does not auto-detect the Git root'
Assert-True ($resolver.Contains('VP_ACTIVE_REPO')) 'repository resolver does not support an explicit override'

foreach ($script in @('gate.sh', 'poll-issues.sh', 'repo-status.sh', 'find-bugs.sh', 'install-runtime.sh')) {
    $content = Read-ProjectFile "scripts/$script"
    Assert-True ($content.Contains('resolve_repo')) "$script bypasses shared repository resolution"
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error "FAIL: $_" -ErrorAction Continue }
    exit 1
}

Write-Output "PASS: project invariants validated ($($runtimeFiles.Count) runtime files checked)"
