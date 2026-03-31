// =============================================================================
// GitOps Pipeline — AWS Lambda (Jenkins + GitHub)
// =============================================================================
// Branches:
//   PR build      → PR validation stages only (quality gates)
//   develop       → quality gates + build + deploy dev
//   staging       → quality gates + build + deploy staging (1 approval)
//   main          → quality gates + build + deploy prod (2 approvals) + release
//
// Required Jenkins credentials:
//   github-token     : Secret Text  — GitHub Personal Access Token (repo scope)
//   aws-credentials  : AWS credentials — Access Key / Secret Key (or IAM Role)
//
// Required Jenkins plugins:
//   GitHub Branch Source, Pipeline, Credentials Binding,
//   Amazon Web Services SDK, GitHub (for githubNotify),
//   AnsiColor, Timestamper
// =============================================================================

pipeline {

    agent { label 'docker' }   // agent with Docker + Python + Node.js available

    options {
        buildDiscarder(logRotator(numToKeepStr: '20'))
        timeout(time: 45, unit: 'MINUTES')
        timestamps()
        ansiColor('xterm')
        disableConcurrentBuilds(abortPrevious: true)
        skipDefaultCheckout(false)
    }

    environment {
        AWS_REGION       = "${env.AWS_REGION        ?: 'eu-central-1'}"
        LAMBDA_FUNCTION  = "${env.LAMBDA_FUNCTION   ?: 'my-lambda-function'}"  // override per job
        GITHUB_REPO      = 'bahtiti/aws'
        GITHUB_CREDS_ID  = 'github-token'
        AWS_CREDS_ID     = 'aws-credentials'
    }

    // ── Notify GitHub: build started ──────────────────────────────────────────
    stages {

        // ══════════════════════════════════════════════════════════════════════
        //  SECTION 1 — PR VALIDATION  (runs only on Pull Requests)
        // ══════════════════════════════════════════════════════════════════════

        stage('PR: Conventional Commit Title') {
            when { changeRequest() }
            steps {
                script {
                    def title = env.CHANGE_TITLE ?: ''
                    sh(script: "bash jenkins/scripts/check-pr-title.sh \"${title.replace('"', '\\"')}\"")
                }
            }
        }

        stage('PR: Description Required') {
            when { changeRequest() }
            steps {
                withCredentials([string(credentialsId: env.GITHUB_CREDS_ID, variable: 'GITHUB_TOKEN')]) {
                    script {
                        def body = sh(
                            script: """
                                curl -sf \\
                                  -H "Authorization: token \$GITHUB_TOKEN" \\
                                  "https://api.github.com/repos/${GITHUB_REPO}/pulls/${env.CHANGE_ID}" \\
                                | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('body') or '')"
                            """,
                            returnStdout: true
                        ).trim()
                        if (body.length() < 20) {
                            error('PR description is missing or too short. Please fill in the PR template.')
                        }
                        echo "PR description length: ${body.length()} chars — OK"
                    }
                }
            }
        }

        stage('PR: Branch Promotion Policy') {
            when { changeRequest() }
            steps {
                script {
                    def base = env.CHANGE_TARGET ?: ''
                    def head = env.CHANGE_BRANCH ?: ''
                    def rules = [
                        'main':    ['staging', 'hotfix/'],
                        'staging': ['develop', 'hotfix/'],
                        'develop': ['feature/', 'feat/', 'fix/', 'chore/', 'docs/',
                                    'refactor/', 'perf/', 'ci/', 'test/', 'build/'],
                    ]
                    def allowed = rules[base]
                    if (allowed) {
                        boolean ok = allowed.any { prefix ->
                            head.startsWith(prefix) || head == prefix.replaceAll('/$', '')
                        }
                        if (!ok) {
                            error("Branch promotion policy violation.\n" +
                                  "  Target: ${base}\n" +
                                  "  Source: ${head}\n" +
                                  "  Allowed sources for '${base}': ${allowed.join(', ')}\n" +
                                  "  See GITOPS.md for the full hierarchy.")
                        }
                    }
                    echo "Branch promotion: ${head} → ${base} — ALLOWED"
                }
            }
        }

        // ══════════════════════════════════════════════════════════════════════
        //  SECTION 2 — QUALITY GATES  (runs on PRs AND branch builds)
        // ══════════════════════════════════════════════════════════════════════

        stage('Quality Gates') {
            parallel {

                stage('Lint: YAML') {
                    steps { sh 'bash jenkins/scripts/lint.sh yaml' }
                }

                stage('Lint: CloudFormation') {
                    steps { sh 'bash jenkins/scripts/lint.sh cfn' }
                }

                stage('Lint: Markdown') {
                    steps { sh 'bash jenkins/scripts/lint.sh markdown' }
                }

                stage('Security: Checkov (IaC)') {
                    steps { sh 'bash jenkins/scripts/security-scan.sh checkov' }
                    post {
                        always {
                            // Archive SARIF for review
                            archiveArtifacts(
                                artifacts: 'checkov.sarif',
                                allowEmptyArchive: true
                            )
                        }
                    }
                }

                stage('Security: TruffleHog (Secrets)') {
                    steps { sh 'bash jenkins/scripts/security-scan.sh trufflehog' }
                }

            } // end parallel
        } // end Quality Gates

        // ══════════════════════════════════════════════════════════════════════
        //  SECTION 3 — BUILD  (branch builds only, not PRs)
        // ══════════════════════════════════════════════════════════════════════

        stage('Build: Package Lambda') {
            when { not { changeRequest() } }
            steps {
                sh 'bash jenkins/scripts/deploy-lambda.sh build'
                archiveArtifacts artifacts: 'lambda-artifact.zip', fingerprint: true
            }
        }

        // ══════════════════════════════════════════════════════════════════════
        //  SECTION 4 — DEPLOY: DEV  (develop branch only)
        // ══════════════════════════════════════════════════════════════════════

        stage('Deploy → Dev') {
            when {
                allOf {
                    not { changeRequest() }
                    branch 'develop'
                }
            }
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: env.AWS_CREDS_ID]]) {
                    sh 'bash jenkins/scripts/deploy-lambda.sh deploy dev'
                }
            }
        }

        // ══════════════════════════════════════════════════════════════════════
        //  SECTION 5 — DEPLOY: STAGING  (staging branch, 1 manual approval)
        // ══════════════════════════════════════════════════════════════════════

        stage('Gate: Staging Approval') {
            when {
                allOf {
                    not { changeRequest() }
                    branch 'staging'
                }
            }
            steps {
                timeout(time: 24, unit: 'HOURS') {
                    script {
                        def approver = input(
                            message: 'Deploy to STAGING?',
                            ok: 'Approve & Deploy',
                            submitterParameter: 'APPROVER'
                        )
                        env.STAGING_APPROVER = approver
                        echo "Staging approved by: ${approver}"
                    }
                }
            }
        }

        stage('Deploy → Staging') {
            when {
                allOf {
                    not { changeRequest() }
                    branch 'staging'
                }
            }
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: env.AWS_CREDS_ID]]) {
                    sh 'bash jenkins/scripts/deploy-lambda.sh deploy staging'
                }
            }
        }

        // ══════════════════════════════════════════════════════════════════════
        //  SECTION 6 — DEPLOY: PRODUCTION  (main branch, 2 manual approvals)
        // ══════════════════════════════════════════════════════════════════════

        stage('Gate: Production Approval #1') {
            when {
                allOf {
                    not { changeRequest() }
                    branch 'main'
                }
            }
            steps {
                timeout(time: 24, unit: 'HOURS') {
                    script {
                        def approver = input(
                            message: 'PRODUCTION deployment — First approval required. Review the deploy plan.',
                            ok: 'I Approve',
                            submitterParameter: 'APPROVER'
                        )
                        env.PROD_APPROVER_1 = approver
                        echo "Production approval #1 by: ${approver}"
                    }
                }
            }
        }

        stage('Gate: Production Approval #2') {
            when {
                allOf {
                    not { changeRequest() }
                    branch 'main'
                }
            }
            steps {
                timeout(time: 24, unit: 'HOURS') {
                    script {
                        def approver = input(
                            message: "PRODUCTION deployment — Second approval required (must differ from: ${env.PROD_APPROVER_1}).",
                            ok: 'I Approve',
                            submitterParameter: 'APPROVER'
                        )
                        if (approver == env.PROD_APPROVER_1) {
                            error("Both approvals were by the same person (${approver}). A second, different reviewer is required.")
                        }
                        env.PROD_APPROVER_2 = approver
                        echo "Production approval #2 by: ${approver}"
                        echo "Approved by: ${env.PROD_APPROVER_1} and ${env.PROD_APPROVER_2}"
                    }
                }
            }
        }

        stage('Deploy → Production') {
            when {
                allOf {
                    not { changeRequest() }
                    branch 'main'
                }
            }
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                                  credentialsId: env.AWS_CREDS_ID]]) {
                    sh 'bash jenkins/scripts/deploy-lambda.sh deploy prod'
                }
            }
        }

        // ══════════════════════════════════════════════════════════════════════
        //  SECTION 7 — RELEASE  (main / staging / develop — semantic-release)
        // ══════════════════════════════════════════════════════════════════════

        stage('Release: Semantic Versioning & Tagging') {
            when {
                allOf {
                    not { changeRequest() }
                    anyOf {
                        branch 'main'
                        branch 'staging'
                        branch 'develop'
                    }
                    not { changelog '.*\\[skip ci\\].*' }
                }
            }
            steps {
                withCredentials([string(credentialsId: env.GITHUB_CREDS_ID, variable: 'GITHUB_TOKEN')]) {
                    sh 'bash jenkins/scripts/release.sh'
                }
            }
        }

    } // end stages

    // ── Post-build: report status back to GitHub ──────────────────────────────
    post {
        always {
            script {
                def result      = currentBuild.result ?: 'SUCCESS'
                def ghStatus    = (result == 'SUCCESS') ? 'SUCCESS' : 'FAILURE'
                def description = "${result} in ${currentBuild.durationString.replace(' and counting', '')}"

                try {
                    githubNotify(
                        context: 'Jenkins CI/CD',
                        status: ghStatus,
                        description: description,
                        credentialsId: env.GITHUB_CREDS_ID
                    )
                } catch (Exception e) {
                    echo "Warning: could not report status to GitHub: ${e.message}"
                }
            }
        }
        success {
            echo "Pipeline SUCCESS — ${currentBuild.displayName}"
        }
        failure {
            echo "Pipeline FAILED — ${currentBuild.displayName}. Check the stage logs above."
        }
        cleanup {
            cleanWs()
        }
    }

} // end pipeline
