# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0-rc.3] - 2025-11-07

### 🐛 Bug Fixes

* fix(ci): pass region parameter to setup-fly-test-env action (9dbef48)
* fix(ci): resolve shellcheck SC2002 warning exposed by corrected grep pattern (a3ff843)
* fix(ci): correct grep pattern to exclude .git directory without filtering .github (ab7be15)
* fix(ci): resolve region mismatch between volume and fly.toml configuration (ddd262e)
* fix: claude-marketplace extension (#11) (8be0ff4)

### 📚 Documentation

* docs: update CHANGELOG.md for v1.0.0-rc.2 (556910c)

### 🔧 Other Changes

* refactor(ci): remove paths-ignore filters from integration workflow (2b4e7ef)
* refactor(ci): optimize workflow triggers and scheduling for efficiency (b56181a)

### 📦 Installation

To use this version:

```bash
git clone https://github.com/pacphi/sindri.git
cd sindri
git checkout v1.0.0-rc.3
./scripts/vm-setup.sh --app-name my-sindri-dev
```

**Full Changelog**: https://github.com/pacphi/sindri/compare/v1.0.0-rc.2...v1.0.0-rc.3

## [1.0.0-rc.2] - 2025-11-04

### ✨ Features

* feat(nodejs-devtools): add research-swarm AI research orchestration tool (27b2ed6)
* feat(claude-marketplace): add authentication check before plugin installation (bfb8b8f)

### 🐛 Bug Fixes

* fix(claude-marketplace): verify marketplace config in status() before returning success (fb9f372)
* fix(ci): add comprehensive plugin installation testing for claude-marketplace extension (5c9dc22)
* fix: update jvm.sh.example extension - Java 25 is latest/current LTS release (504a392)

### 📚 Documentation

* docs: update CHANGELOG.md for v1.0.0-rc.1 (190f27e)

### 🔧 Other Changes

* Feature: UX Improvements (#9) (b41f184)

### 📦 Installation

To use this version:

```bash
git clone https://github.com/pacphi/sindri.git
cd sindri
git checkout v1.0.0-rc.2
./scripts/vm-setup.sh --app-name my-sindri-dev
```

**Full Changelog**: https://github.com/pacphi/sindri/compare/v1.0.0-rc.1...v1.0.0-rc.2

## [1.0.0-rc.1] - 2025-10-23

### ✨ Features

* feat: activate MOTD banner for SSH sessions (15cb617)
* feat(extensions): add registry resilience and comprehensive documentation (5bf94da)
* feat(ci,extensions): add timeouts and optimize CI diagnostics (96206f2)
* feat(jvm): add Java 24 LTS support and set as default (cf0c1f2)
* feat(extensions): migrate to manifest-based Extension API v1.0 system (0351cc1)
* feat(extensions): standardize SSH environment configuration for non-interactive sessions (fa1014e)
* feat!: rebrand to Sindri - AI-powered cloud development forge (79eef5c)
* feat: add Agentic Flow integration for multi-model AI cost optimization (2bc5870)
* feat: add cloud tools extension (cdccf49)

### 🐛 Bug Fixes

* fix(ci): make health check CI-mode aware to prevent deployment timeouts (fc19426)
* fix(nodejs): remove npm prefix configuration incompatible with NVM (1f768e4)
* fix(ci): resolve extension-manager path issues in integration-resilient workflow (5f5d399)
* fix(ci): add explicit filesystem sync to prevent 0-byte file issue in integration-resilient (ef0ccde)
* fix(ci): replace brittle grep check with comprehensive verification in integration-resilient (daf56ba)
* fix(ci): replace $$ with timestamp for consistent test file naming in integration-resilient (0f43359)
* fix(ci): use grep directly with literal string matching for persistence verification (5f8d9ff)
* fix(ci): use explicit bash invocation for SSH commands to prevent shell parsing errors (8053630)
* fix(ci): check for 'started' status instead of 'running' in readiness check (e3f08d3)
* fix(ci): activate extensions inside SSH session for combination tests (d08ef28)
* fix(ci): add missing app creation step in integration-resilient workflow (59c9172)
* fix(ci): consolidate FLY_API_TOKEN and improve validation (0a62d93)
* fix(php): resolve idempotency timeout issues in extension installation (b273473)
* fix(extensions): improve installation reliability and idempotency (009f536)
* fix(python): add timeouts and improved error handling for package installations (6bd9521)
* fix(ci): improve extension test command validation and CI mode handling (b64247d)
* fix(ci): improve machine lifecycle verification and error handling (18b8a5d)
* fix: add disable swtiches for false-positive shellcheck violations (d5914a8)
* fix(ci,extensions): optimize workflows and fix shell script robustness issues (51b53bd)
* fix(ci): optimize extension tests and fix workflow reliability issues (de721b7)
* fix(extension-manager): quote variable expansion in for loop glob (7619f4c)
* fix(extensions): complete call_extension_function implementation (eb90da7)
* fix(ci): extensions test workflow stability (36af60b)
* fix(extensions): ensure commands available in non-interactive SSH sessions for CI tests (394f95e)
* fix(ci): resolve extension test failures and improve workflow reliability (80c2894)

### 📚 Documentation

* docs: add release process and versioning guide (628d13b)
* docs: Add MOTD logo to README (db59dc4)
* docs: improve setup workflow and extension management documentation (f26f895)
* docs: remove premature release details (17fff57)
* docs: add extension tests workflow badge to README (cfb04de)
* docs: improve documentation structure and enhance extension system (72697ed)
* docs: Add Agentic Flow to README project description (d42be20)
* docs: update CHANGELOG.md for v1.0.0-beta.2 (dffe6e9)

### 📦 Dependencies

* ci(deps): bump github/codeql-action from 3 to 4 (fb2ec2c)

### 🔧 Other Changes

* refactor: update registry-retry.sh path references after relocation (41bd22f)
* ci: add fly.toml preparation step before deployment (cd2bb12)
* chore(infra): migrate to sjc region and improve CI reliability (b4a18c9)
* perf(ci): optimize extension tests with resource upgrades and reliability improvements (ce81a42)
* ci: optimize integration workflow with path filtering and remove debug logs (18d0418)
* perf(ci): optimize extension tests with CI_MODE support - 67% faster (06d193f)
* refactor: consolidate extension system and add AI tools integration (ea3dd47)

### 📦 Installation

To use this version:

```bash
git clone https://github.com/pacphi/sindri.git
cd sindri
git checkout v1.0.0-rc.1
./scripts/vm-setup.sh --app-name my-sindri-dev
```

**Full Changelog**: https://github.com/pacphi/sindri/compare/v1.0.0-beta.2...v1.0.0-rc.1

## [1.0.0-beta.2] - 2025-09-30

### ✨ Features

* feat: add Goalie research assistant integration (c281b3b)

### 🐛 Bug Fixes

* fix: resolve sed compatibility issue in prepare-fly-config.sh for Linux/macOS (e4718d1)
* fix: improve fly.toml management and cross-platform compatibility (751ff67)

### 📚 Documentation

* docs: update CHANGELOG.md for v1.0.0-beta.1 (d286242)

### 📦 Installation

To use this version:

```bash
git clone https://github.com/pacphi/claude-flow-on-fly.git
cd claude-flow-on-fly
git checkout v1.0.0-beta.2
./scripts/vm-setup.sh --app-name my-claude-dev
```

**Full Changelog**: https://github.com/pacphi/claude-flow-on-fly/compare/v1.0.0-beta.1...v1.0.0-beta.2

## [1.0.0-beta.1] - 2025-09-23

### 🐛 Bug Fixes

* fix: resolve volume persistence file content loss during machine restart (6cf371e)

### 📚 Documentation

* docs: update CHANGELOG.md for v1.0.0-alpha.1 (2315ac3)

### 🔧 Other Changes

* ci: improve integration workflow robustness and add CI troubleshooting docs (5e60c81)
* Beta features (#6) (f871f79)

### 📦 Installation

To use this version:

```bash
git clone https://github.com/pacphi/claude-flow-on-fly.git
cd claude-flow-on-fly
git checkout v1.0.0-beta.1
./scripts/vm-setup.sh --app-name my-claude-dev
```

**Full Changelog**: https://github.com/pacphi/claude-flow-on-fly/compare/v1.0.0-alpha.1...v1.0.0-beta.1

## [1.0.0-alpha.1] - 2025-09-22

### ✨ Features

* feat: implement comprehensive project automation and achieve 0 markdown violations (dd86801)
* feat: enhance new-project.sh with intelligent type detection and flexible configuration (d6807a5)

### 🐛 Bug Fixes

* fix: resolve AWK string escaping issue in release workflow changelog generation (5eaa038)
* fix: replace regex patterns with bash pattern matching in release workflow (f707917)
* fix: improve GitHub workflows security and shell script quality (d2c0a4b)
* fix: resolve all GitHub workflow validation failures (3b796ed)
* fix: resolve GitHub workflow failures and improve CI reliability (9c3eb6e)
* (fix) Paths for available scripts in show_environment_status() in vm-configure.sh (4fde63b)
* (fix) Adjust backup logic, whether vm-configure.sh is running on Fly.io VM, and add troubleshooting docs (9f4be32)
* (fix) Adjust package name for netcat installation (c263077)
* (fix) Documentation improvements (6a2ad8a)
* (fix) Parsing and output issues with suspend and resume scripts (033a670)
* (fix) Parsing and output issues with cost-monitor script (f0f8f84)
* (fix) Properly display machine lists, volume information, and app status when running the teardown command (fdeac74)
* (fix) Remove trailing whitespace from teardown script (1b66ff6)
* (fix) Make sure vm-configure.sh is available in workspace/scripts directory of VM (5737bf9)
* (fix) Volume cost calculation in teardown script (b5096dc)
* (fix) Reorder placeholder replacement in setup (45100f0)
* (fix) Refactor Docker image builds
  * Decompose Dockerfile embedded scripts and configuration into individual scripts and configuration in a docker directory
    which facilitates local image build testing \* Add placeholders to fly.toml (c4c5fd8)
* (fix) Update link to fly.toml in README (9d0ffc4)

### 📚 Documentation

### 📦 Dependencies

* docker(deps): bump ubuntu from 22.04 to 24.04 (e4167a1)
* ci(deps): bump softprops/action-gh-release from 1 to 2 (#5) (9a9b06c)
* ci(deps): bump actions/github-script from 7 to 8 (#4) (e23f4d2)

### 🔧 Other Changes

* Add option to configure a single extension (64c155e)
* Prune sections (f542e41)
* Improve documentation - consolidate, eliminate redundancies and address inaccuracies (e70d72d)
* Revise claim based on actual count of agents from Github repository (7bd00f2)
* Polish (c40d09f)
* Command reference link updated (d7e05ae)
* Remove trailing whitespace (1042de1)
* Reorganized and revised documentation (093cea1)
* Major infrastructure and tooling improvements (c25f2ae)
* Remove trailing whitespace (3138d65)
* Add capability to clone and/or fork Git repositories (06fb248)
* Fix issues wih agent-duplicates, agent-validate-all, and agent-find aliases - and adjust refs to cf
  (e.g. cf swarm -> cf-swarm) (25bf688)
* Remove trailing whitespace (4488faa)
* Add extension-manager - Simplify activation and deactivation of pre-install, install, and post-install user scripts (10edf9b)
* Enhance post-cleanup to account for 100+ tools across all ecosystems (0a194bc)
* More tweaks to aliases (691681d)
* Tweaks to aliases (f40b179)
* Update respository structure (89254b4)
* Revise section on Automated Setup (ebfd89d)
* Integrate turbo flow (#2) (f98f8f0)
* Add infrastructure tooling example to extensions (eeac728)
* Trim trailing whitespace (8cd519f)
* Add support for other languages/frameworks (5bb1ecb)
* Refactor workspace script generation to use external script files (b15622d)
* Update VM state handling to support suspended status and improve messaging (b3c9758)
* Refactor scripts with shared library system and extension support (9620ee9)
* Add LICENSE (46d7888)
* Move QUICKSTART.md and SETUP.md to docs directory - and fix all references in existing documentation (f5b2b22)
* Remove http service configuration (it's not required) (7d7a088)
* Remove npm/yarn, pip, github-actions configurations from Dependabot workflow - We don't have any need for these yet (caeac64)
* Add Dependabot Github workflow (5630df2)
* Add placeholders for cpus and cpu_kind in fly.toml
  * Make necessary updates to setup script and documentation (8f1856b)
* Add vm-teardown.sh script (64345b9)
* Add QUICKSTART.md
  * Emphasis on getting up and runnng fast and efficiently
  * Formatting updates across existing documentation (75489bb)

### 📦 Installation

To use this version:

```bash
git clone https://github.com/pacphi/claude-flow-on-fly.git
cd claude-flow-on-fly
git checkout v1.0.0-alpha.1
./scripts/vm-setup.sh --app-name my-claude-dev
```

**Full Changelog**: https://github.com/pacphi/claude-flow-on-fly/compare/2422242859bc120201554c7d2fb19d859b877665...v1.0.0-alpha.1

## [Unreleased]

### ✨ Added

* GitHub workflow automation for project validation
* Integration testing with ephemeral Fly.io deployments
* Automated release management with changelog generation
* Dependabot configuration for automated dependency updates
* Comprehensive issue templates for bug reports, feature requests, and questions
* Pull request template with detailed checklists
* Security scanning with Trivy and GitLeaks
* Markdown linting and documentation validation

### 🔧 Changed

* Enhanced project structure with `.github/` directory for automation
* Improved development workflow with automated validation

### 📚 Documentation

* Added workflow documentation and examples
* Created comprehensive templates for community contributions

## [Previous Releases]

_Previous releases and their changes will be documented here as they are tagged._

---

**Note**: This project follows semantic versioning. For a detailed list of changes between versions,
see the [GitHub releases page](https://github.com/pacphi/sindri/releases).
